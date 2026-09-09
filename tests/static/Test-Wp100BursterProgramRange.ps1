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
Assert-That ($select -match '(?s)ELSIF \( AiWp100.BursterProgramSelect.Error \).*?Station\._AutoInfoline := AutoInfoLineEnum.USER_INFO_TEXT_CLEAR;\s+_retVal\s*:= HAS_ERROR;\s+_retVal2\s*:= HAS_ERROR;') 'Program rejection must clear the measuring prompt and block both branches.'

# Decode the actual ST frame literals, not a duplicate implementation. This is
# byte-level source regression against manual 8.15.11, not instrument acceptance.
$selector = [IO.File]::ReadAllText((Join-Path $plc 'FB_Wp100BursterProgramSelect.st'))
$prefixMatch = [regex]::Match($selector, "(?s)_sendFrame := CONCAT\(\s*'(?<literal>[^']*)',\s*INT_TO_STRING\(_requestedProgramNo\)\s*\);")
$suffixMatch = [regex]::Match($selector, "_sendFrame\s*:= CONCAT\(_sendFrame, '(?<literal>[^']*)'\);")
Assert-That ($prefixMatch.Success -and $suffixMatch.Success) 'Program frame construction was not found exactly as reviewed.'
function Decode-StHexLiteral([string]$Literal) {
  [regex]::Replace($Literal, '\$([0-9A-Fa-f]{2})', {
    param($Match)
    [string][char][Convert]::ToInt32($Match.Groups[1].Value, 16)
  })
}
$prefix = Decode-StHexLiteral $prefixMatch.Groups['literal'].Value
$suffix = Decode-StHexLiteral $suffixMatch.Groups['literal'].Value
foreach ($programNo in 0..15) {
  $actual = [Text.Encoding]::ASCII.GetBytes($prefix + [string]$programNo + $suffix)
  [byte[]]$expected = @(4) + [Text.Encoding]::ASCII.GetBytes('0000sr') + @(2) +
    [Text.Encoding]::ASCII.GetBytes("*RCL $programNo") + @(10, 3, 13)
  Assert-That ([Convert]::ToHexString($actual) -ceq [Convert]::ToHexString($expected)) "Invalid program $programNo frame; manual P1 is a numeric placeholder."
}
Assert-That ($selector.Contains('( ProgramNo < 0 )') -and $selector.Contains('( ProgramNo > 15 )')) 'Keep 0..15 program validation.'
Assert-That ($selector -match '(?s)ELSIF \( _readBuffer\[0\] = 21 \)\s+THEN\s+ErrorCode := 6;\s+_state := 190;') 'NAK must take error cleanup, not release the press.'
Assert-That ($selector -match '(?s)IF \( _readBuffer\[0\] = 6 \)\s+THEN\s+_timer\(IN := FALSE, PT := T#0S\);\s+_state := 50;') 'ACK must pass through EOT and close before Done.'
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
Write-Output 'Burster source checks OK: numeric RCL frames 0..15, NAK blocks both branches and clears measuring prompt, ACK first, no SET_RANGE/range writes, AutoRange-off gate, idle readiness, preserved grading/temperature/force checks and generated ownership. Build and field acceptance remain required.'
