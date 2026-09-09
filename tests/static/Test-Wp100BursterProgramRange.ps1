# Offline source-contract checks; not instrument/PLC runtime acceptance.
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$plc = Join-Path $repo 'src\plc\project\Station010'
$chain = Join-Path $plc 'SqS_Wp100_Run\actions'
function Assert-That([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}
function Read-Step([string]$Step) {
  [IO.File]::ReadAllText((Join-Path $chain "$Step.st"))
}
$select = Read-Step 'N045'
$range = Read-Step 'N046'
$ready = Read-Step 'N047'
$measure = Read-Step 'N080'
$checks = [IO.File]::ReadAllText((Join-Path $plc 'TypeDataSetManagerAddon\OnCheckData.ApplicationChecks.st'))
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $plc 'SqS_Wp100_Run') -Recurse -Filter '*.st') {
  $source = [IO.File]::ReadAllText($file.FullName)
  Assert-That ($source -notmatch 'BursterResis2316Cmd\.SET_RANGE|\.ParCmd\.(UpperRange|LowerRange)\s*:=') "Automatic range override remains in $($file.Name)."
  Assert-That ($source -notmatch 'UseAutoRange\s*:=') 'Generated AutoRange configuration must not be overwritten from application code.'
}
Assert-That ($select.Contains('ProgramNo := Station.TypeData.Wp100.Burster.ProgramNo')) 'Program must still come from active TypeData.'
Assert-That ($select.Contains('IF ( AiWp100.BursterProgramSelect.Done )')) 'Instrument program acknowledgement is required.'
Assert-That ($range -match '(?s)_retVal := RUNNING;\s+IF \( NOT Peripherals\._Wp100A103ResistantInterface\.ParCfg\.UseAutoRange \)\s+THEN\s+_retVal := OK;\s+END_IF') 'AutoRange override must block at the preparation step.'
Assert-That ($ready -match '(?s)_retVal := RUNNING;\s+IF \( Wp100A103ResistantDetector.Unit.ExecState = OpconExecState.READY \) AND\s+\( NOT Wp100A103ResistantDetector.Unit.Execute \)\s+THEN\s+_retVal := OK;\s+END_IF') 'An idle standard Unit is required before the start branches.'
Assert-That ($ready -notmatch 'CheckUnitDone\s*\(') 'Do not wait for DONE of an unissued command.'
foreach ($field in @('UpperLimit','LowerLimit','ReadTemperature')) {
  Assert-That ($measure -match "(?s)\.ParCmd\.$field\s*:=\s*Station\.TypeData\.Wp100\.Burster\.$field;") "Lost active TypeData $field."
}
Assert-That ($measure.Contains('BursterResis2316Cmd.SINGLE_MEAS')) 'Single measurement must remain the standard Unit command.'
$forceCheckIndex = $measure.IndexOf('CheckPressForce(Phase := 2)')
Assert-That ($forceCheckIndex -ge 0 -and $forceCheckIndex -lt $measure.IndexOf('BursterResis2316Cmd.SINGLE_MEAS')) 'Force qualification must precede resistance measurement.'
Assert-That ($checks -notmatch 'Burster\.(UpperRange|LowerRange)') 'Unused ranges must not enter the application plausibility check.'
Assert-That ($checks.Contains('Burster.LowerLimit >')) 'Keep result-limit ordering validation.'
Assert-That ($checks.Contains('Burster.ProgramNo < 0') -and $checks.Contains('Burster.ProgramNo > 15')) 'Keep program number validation.'
$process = Get-Content -Raw (Join-Path $repo 'specs\processes\SqS_Wp100_Run.process.json') | ConvertFrom-Json
$writer = [IO.File]::ReadAllText((Join-Path $repo 'scripts\plc\apply_wp100_run_rest.ps1'))
foreach ($step in @('N046','N047')) {
  $comment = ($process.steps | Where-Object id -eq $step).comment
  Assert-That ($comment -and $writer.Contains("Name = '$step'; Comment = '$comment'")) 'Process and SFC step descriptions differ.'
}
Write-Output 'Burster program-range source checks OK: ACK first, no SET_RANGE/range writes, AutoRange-off gate, idle readiness, preserved grading/temperature/force checks and generated ownership. Build and field acceptance remain required.'
