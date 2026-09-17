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

# Protocol byte/framing tests live in test_burster_single_owner_protocol.py.
# This contract now checks the integrated call path, not the removed handoff.
$selector = [IO.File]::ReadAllText((Join-Path $plc 'FB_Wp100BursterProgramSelect.st'))
$owner = [IO.File]::ReadAllText((Join-Path $repo 'src/plc/libraries/Burster2316/FB_Wp100BursterSingleOwner.st'))
$gvl = [IO.File]::ReadAllText((Join-Path $plc 'AiWp100.gvl.st'))
Assert-That ($selector -notmatch 'OpconTcpClientIpV4|AiWp100\.Burster\.') 'Selector must not have a second TCP owner or old driver calls.'
Assert-That ($selector.Contains('Peripherals._Burster2316.Open()') -and $selector.Contains('Peripherals._Burster2316.SelectProgram(ProgramNo := _requestedProgramNo)')) 'SFC must delegate Open and program selection to the shared owner.'
Assert-That ($gvl -notmatch '\bBurster\s*:') 'Do not recreate the old single-owner instance alongside the native Peripheral.'
Assert-That ([regex]::Matches($owner + $selector, '\w+\s*:\s*OpconTcpClientIpV4\s*;').Count -eq 1) 'Exactly one socket is allowed across selector and driver.'
Assert-That ($selector.Contains('( ProgramNo < 0 )') -and $selector.Contains('( ProgramNo > 15 )')) 'Keep 0..15 program validation.'
Assert-That ($selector.Contains('ProgramNo <> _requestedProgramNo')) 'Changing a program during selection must cancel instead of releasing stale Done.'
$resetPrefix = $selector.Substring($selector.IndexOf('IF ( NOT Execute )'), $selector.IndexOf('CASE _state OF') - $selector.IndexOf('IF ( NOT Execute )'))
Assert-That ($resetPrefix.Contains('( _state = 100 )') -and $resetPrefix.Contains('RETURN;') -and $resetPrefix -notmatch '\.Reset\(') 'Clearing selector Done must not cancel a later Unit measurement.'
Assert-That ($selector.Contains('_state := 90; // Continue the pending owner')) 'A first error must retain Busy while pending I/O is cleaned up.'
Assert-That ($selector.Contains('IF ( ErrorCode = 0 )')) 'Cancellation must preserve the first fault.'
Assert-That ($owner -match 'IMPLEMENTS (?:\w+\.)?IBursterResis2316' -and $owner.Contains('RequestedProgramNo <> _measProgram')) 'Manual/automatic must share the standard interface and reject mid-command program changes.'
Assert-That ($owner.Contains("CommandText := '*RCL?', Query := TRUE") -and $owner.Contains('SelectedProgram <> _measProgram')) 'Manual entry needs selection and fresh program readback.'
$binding = [IO.File]::ReadAllText((Join-Path $plc 'Wp100Unit/OnApplyParameters.BursterBinding.st'))
$configuration = [IO.File]::ReadAllText((Join-Path $plc 'Wp100Unit/OnCall.BursterConfiguration.st'))
$manual = [IO.File]::ReadAllText((Join-Path $plc 'Wp100A103ResistantDetectorExtension/OnManRelease.st'))
Assert-That ($binding -notmatch ':=') 'The retired application binding must not override the generated channel.'
$nativePeripheral=[IO.File]::ReadAllText((Join-Path $repo 'src/cpstudio/components/Burster2316/V0.1/Burster2316.ood'))
Assert-That ($nativePeripheral.Contains('structRef="Burster2316Peripheral"') -and $nativePeripheral.Contains('<Type name="IBursterResis2316"')) 'Native Peripheral must expose the standard channel using a unique driver type.'
Assert-That ($binding -notmatch 'OES_CODE|\.Open\(|\.MeasCmd\(') 'Binding fragment must not edit generated regions or start communication.'
Assert-That ($configuration.Contains('Peripherals._Burster2316.RequestedProgramNo := Station.TypeData.Wp100.Burster.ProgramNo;')) 'Manual program must come from active TypeData.'
Assert-That ($configuration -notmatch '\.(Open|SelectProgram|MeasCmd|Reset)\(') 'Cyclic configuration cannot start any operation.'
Assert-That ($manual.Contains('ReleaseSetRange := CommonManRelease AND FALSE;') -and $manual.Contains('ReleaseStartMeas := CommonManRelease AND TRUE;')) 'Reject unsupported manual range but retain the existing common measurement release.'
$pump = [IO.File]::ReadAllText((Join-Path $plc 'StationUnit/OnCall.BursterCleanup.st'))
Assert-That ($pump -match '(?s)IF \( NOT AiWp100.BursterProgramSelect.Execute \) AND\s+\( AiWp100.BursterProgramSelect.Busy \)\s+THEN\s+AiWp100.BursterProgramSelect\(\);\s+END_IF') 'One-cycle OnChainFinish needs a guarded cyclic cancellation pump.'
Assert-That ($pump -notmatch ':=|SINGLE_MEAS|MOVE_WRKPOS') 'Cancellation hook must not start selection, measurement or motion.'
foreach ($guard in @('Peripherals._Burster2316.Connected', 'Peripherals._Burster2316.SelectionVerified',
    'Peripherals._Burster2316.SelectedProgram = Station.TypeData.Wp100.Burster.ProgramNo',
    'Peripherals._Burster2316.Operation = 0', 'Peripherals._Burster2316.ErrorCode = 0')) {
  Assert-That ($range.Contains("( $guard )")) "N046 missing guard: $guard"
}
Assert-That ($range -notmatch 'AiWp100\.Burster\.|UseAutoRange') 'The removed driver and automatic range override must not remain in N046.'
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

# Execute the actual N090 boolean expression with REAL-sized values. This tests
# tolerance boundaries independently of the closed standard Unit implementation.
$capture = Read-Step 'N090'
Assert-That ($capture -match '(?s)IF \( _unitResult = OK \) AND\s+\( NOT Result\.Resistance\.Valid \)\s+THEN') 'Capture only the first successful completion; a step hold must not regrade.'
Assert-That ($capture -match '(?s)CheckPressForce\(Phase := 3\);\s+IF \( _retVal <> OK \)\s+THEN\s+RETURN;') 'Force faults must win before result capture.'
$gradeMatch = [regex]::Match($capture, '(?s)Result\.Resistance\.Ok\s*:=\s*(.*?);')
Assert-That ($gradeMatch.Success) 'Missing explicit per-measurement grading.'
$gradeExpression = $gradeMatch.Groups[1].Value
Assert-That ($gradeExpression -notmatch 'Station\.TypeData|OutCmd\.ResistOk|1000') 'Grade against this command and raw Ohm, without re-reading TypeData or the display value.'
$gradeExpression = $gradeExpression.Replace('Result.Resistance.OutOfLimit', '$OutOfLimit').
  Replace('Result.Resistance.Value', '$Value').
  Replace('Wp100A103ResistantDetector.Unit.ParCmd.LowerLimit', '$Lower').
  Replace('Wp100A103ResistantDetector.Unit.ParCmd.UpperLimit', '$Upper')
$gradeExpression = $gradeExpression -replace '\bAND\b', '-and' -replace '\bNOT\b', '-not' -replace '>=', '-ge' -replace '<=', '-le'
$grade = [scriptblock]::Create('param([single]$Value,[single]$Lower,[single]$Upper,[bool]$OutOfLimit) [bool](' + $gradeExpression + ')')
$gradeCases = @(
  @('below lower', 0.000999, 0.001, 0.002, $false, $false),
  @('equal lower', 0.001, 0.001, 0.002, $false, $true),
  @('inside', 0.0015, 0.001, 0.002, $false, $true),
  @('equal upper', 0.002, 0.001, 0.002, $false, $true),
  @('above upper', 0.002001, 0.001, 0.002, $false, $false),
  @('range fault', 0.0015, 0.001, 0.002, $true, $false),
  @('reversed limits', 0.0015, 0.002, 0.001, $false, $false),
  @('equal limits match', 0.001, 0.001, 0.001, $false, $true),
  @('equal limits mismatch', 0.001001, 0.001, 0.001, $false, $false),
  @('NaN value', [single]::NaN, 0.001, 0.002, $false, $false),
  @('NaN lower', 0.0015, [single]::NaN, 0.002, $false, $false),
  @('NaN upper', 0.0015, 0.001, [single]::NaN, $false, $false)
)
foreach ($case in $gradeCases) {
  $actual = & $grade $case[1] $case[2] $case[3] $case[4]
  Assert-That ($actual -eq $case[5]) "Wrong resistance grade: $($case[0])."
}
Write-Output "Resistance grading: $($gradeCases.Count) raw-Ohm boundary/range/invalid-value cases passed; completion and force gates retained."

$process = Get-Content -Raw (Join-Path $repo 'specs\processes\SqS_Wp100_Run.process.json') | ConvertFrom-Json
$writer = [IO.File]::ReadAllText((Join-Path $repo 'scripts\plc\apply_wp100_run_rest.ps1'))
foreach ($step in @('N046','N047')) {
  $comment = ($process.steps | Where-Object id -eq $step).comment
  Assert-That ($comment -and $writer.Contains("Name = '$step'; Comment = '$comment'")) 'Process and SFC step descriptions differ.'
}
Write-Output 'Burster source checks OK: one owner, manual/automatic program selection, verified readiness, cancellation isolation, no range override, preserved grading/temperature/force and generated ownership. Source contracts only; fresh Build and field acceptance remain separate.'
