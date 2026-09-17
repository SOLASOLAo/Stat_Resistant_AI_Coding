# Offline timing-model and source-contract checks; not a PLC runtime simulation.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$chain = Join-Path $root 'src\plc\project\Station010\SqS_Wp100_Run'
$source = [IO.File]::ReadAllText((Join-Path $chain 'methods\CheckPressForce.st'))

function Assert-That([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

foreach ($fragment in @(
  'VAR_INST', 'forceN > _thresholdN', '_stableMs <= 0', '_timeoutMs <= _stableMs',
  "_reason := 'INVALID_STABLE_MS'",
  '_waitLimit(IN := TRUE, PT := DINT_TO_TIME(_timeoutMs))',
  'qualified := Station.ForceTraceAddon.Recorder.Evaluate(ValueN := forceN',
  'IF ( NOT _fault )', 'OpconEventClass.SOFTERROR', 'Lock := TRUE',
  'Wp100.EVENT_PRESS_FORCE_INVALID', '_additionalInfo : STRING(63)',
  'Result.Resistance.Valid := FALSE', 'Result.Resistance.Ok := FALSE',
  'Wp100A104Kistler.Unit.OutImm.MeasRunning', 'Wp100A104Kistler.Unit.ExecState <> OpconExecState.ERROR',
  '( forceN = forceN )', 'ABS(forceN) <= REAL#3.402823E38',
  'NOT Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPosIn',
  'Wp100A103ResistantDetector.Unit.Execute := FALSE'
)) {
  Assert-That ($source.Contains($fragment)) "Missing force contract: $fragment"
}
Assert-That ($source -notmatch 'BasMoveCmd\.BASPOS|PressingCylinder\.Unit\.(Command|Execute)\s*:=') 'Force fault must not command cylinder movement.'
Assert-That ($source.IndexOf('_fault := FALSE') -lt $source.IndexOf('forceN :=')) 'Latch reset must remain in the explicit reset branch.'
Assert-That (-not $source.Contains('T#2S')) 'Stable time must come from StationData, not a fixed delay.'
$stableRead = '_stableMs := Station.ForceTraceAddon.ParCfg.rWindowMs;'
Assert-That ([regex]::Matches($source, [regex]::Escape($stableRead)).Count -eq 1) 'Window must be latched once, only at preflight.'
$preflight = $source.Substring($source.IndexOf('IF ( Phase = 1 )'), $source.IndexOf('IF ( NOT Station.ForceTraceAddon.Configured )') - $source.IndexOf('IF ( Phase = 1 )'))
Assert-That ($preflight.Contains($stableRead)) 'Preflight must latch the active stable time before Kistler starts.'
Assert-That (-not $source.Substring($source.IndexOf('IF ( NOT Station.ForceTraceAddon.Configured )')).Contains(':= Station.ForceTraceAddon.ParCfg.rWindowMs')) 'A parameter edit during qualification or measurement must not alter this position.'

# Regression: an acknowledged/invalid event handle must not strand N000 in
# RUNNING. The two BOOL returns describe event operations, not SFC completion.
$reset = $source.Substring($source.IndexOf('IF ( Phase = 0 )'), $source.IndexOf('forceN :=') - $source.IndexOf('IF ( Phase = 0 )'))
$resetWithoutComments = [regex]::Replace($reset, '//[^\r\n]*', '')
Assert-That ($resetWithoutComments -match '(?s)IF \( _eventIndex <> 0 \)\s+THEN\s+UnlockEvent\(Class := OpconEventClass.SOFTERROR, Index := _eventIndex\);\s+ClearEvent\(Class := OpconEventClass.SOFTERROR, Index := _eventIndex\);\s+END_IF') 'Reset must attempt unlock AND clear without waiting on either BOOL.'
Assert-That ($reset.IndexOf('RETURN;') -gt $reset.IndexOf('CheckPressForce := OK;')) 'Reset may not return RUNNING before releasing its old handle.'
foreach ($fragment in @('_eventIndex := 0;', '_fault := FALSE;', "_reason := '';", "_additionalInfo := '';", '_timeoutMs := 0;', '_stableMs := 0;')) {
  Assert-That ($reset.Contains($fragment)) "Reset lost state cleanup: $fragment"
}
# Independent reset lifecycle model, not an implementation of the vendor API.
function Invoke-ForceResetModel($State, [bool]$UnlockResult, [bool]$ClearResult, [int]$ActiveTimeout, [int]$ActiveStableMs=2000) {
  if ($State.EventIndex -ne 0) {
    $State.Calls += @('UnlockEvent', 'ClearEvent')
    $State.EventResults = @($UnlockResult, $ClearResult)
  }
  $State.EventIndex=0; $State.Fault=$false; $State.Reason=''; $State.Timeout=$ActiveTimeout; $State.StableMs=$ActiveStableMs
  return 0
}
foreach ($unlockResult in @($false,$true)) {
  foreach ($clearResult in @($false,$true)) {
    $resetState=@{ EventIndex=2; Fault=$true; Reason='INVALID_TIMEOUT_MS'; Timeout=2000; StableMs=500; Calls=@() }
    Assert-That ((Invoke-ForceResetModel $resetState $unlockResult $clearResult 10000) -eq 0) 'Old event cleanup stranded N000.'
    Assert-That (($resetState.Calls -join ',') -eq 'UnlockEvent,ClearEvent') 'Both cleanup calls must run in order.'
    Assert-That ($resetState.EventIndex -eq 0 -and -not $resetState.Fault -and $resetState.Reason -eq '' -and $resetState.Timeout -eq 10000 -and $resetState.StableMs -eq 2000) 'New execution retained old fault or timing parameters.'
    $null=Invoke-ForceResetModel $resetState $unlockResult $clearResult 10000 3500
    Assert-That ($resetState.Calls.Count -eq 2) 'Repeated reset reused a released event handle.'
    Assert-That ($resetState.StableMs -eq 3500) 'The next position did not take the new stable-time setting.'
  }
}
$init = [IO.File]::ReadAllText((Join-Path $chain 'actions\N000.st'))
Assert-That ($init.Contains('_retVal := CheckPressForce(Phase := 0);')) 'N000 must finish through the shared reset boundary.'
foreach ($step in @('N070','N080','N090')) {
  $action = [IO.File]::ReadAllText((Join-Path $chain "actions\$step.st"))
  Assert-That ($action.Contains('CheckPressForce(')) "$step lost its force check."
  Assert-That (-not $action.Contains('Station.StationData.PressDelayTime')) "$step still accepts an unqualified fixed delay."
}
$start = [IO.File]::ReadAllText((Join-Path $chain 'actions\N080.st'))
Assert-That ($start.IndexOf('IF ( _bursterStarted )') -lt $start.IndexOf('Phase := 2')) 'An already-started single-step hold must use measurement monitoring.'
Assert-That ($start.IndexOf('Phase := 3') -lt $start.IndexOf('Phase := 2')) 'Single-step hold cannot use waiting/debounce logic.'
$finish = [IO.File]::ReadAllText((Join-Path $chain 'actions\N090.st'))
Assert-That ($finish.IndexOf('Phase := 3') -lt $finish.IndexOf('CheckUnitDone(')) 'Force failure must win over same-scan DONE.'
Assert-That ($finish.IndexOf('RETURN;', $finish.IndexOf('Phase := 3')) -lt $finish.IndexOf('Result.Resistance.Valid      := TRUE')) 'Fault must exit before accepting a result.'
$press = [IO.File]::ReadAllText((Join-Path $chain 'actions\N050.st'))
Assert-That ($press.IndexOf('OutImm.MeasRunning') -lt $press.IndexOf('BasMoveCmd.WRKPOS')) 'Kistler must be measuring before press-down.'
$writer = [IO.File]::ReadAllText((Join-Path $root 'scripts\plc\apply_wp100_run_rest.ps1'))
Assert-That ($writer.IndexOf('$runGraphStatus = if') -lt $writer.IndexOf('$forceMethodStatus = Set-Action')) 'Existing graph PUT must precede force-method POST; do not predict PLE child ordering.'
Assert-That (-not ($source + $press).Contains('.ErrorSet')) 'Kistler V1.2 has no ErrorSet member; use its supported ExecState.'

# END is a running-measurement request, not the chain's generic cancel signal.
$stopAction = [IO.File]::ReadAllText((Join-Path $chain 'actions\N101.st'))
$waitAction = [IO.File]::ReadAllText((Join-Path $chain 'actions\N120.st'))
$chainFinish = [IO.File]::ReadAllText((Join-Path $chain 'OnChainFinish.st'))
Assert-That ($chainFinish.Contains('_unitResult := CheckPressForce(Phase := 0);')) 'Chain finish must use the same non-blocking event cleanup.'
$endGate = 'Wp100A104Kistler.Unit.ParImm.EndMeasurement := ( _kistlerStarted ) AND ( Wp100A104Kistler.Unit.OutImm.MeasRunning ) AND ( Wp100A104Kistler.Unit.ExecState = OpconExecState.RUNNING );'
foreach ($body in @($source, $stopAction)) {
  Assert-That (([regex]::Replace($body, '\s+', ' ')).Contains($endGate)) 'END must be owned, measuring and RUNNING, with FALSE on subsequent stopped scans.'
}
Assert-That ($stopAction.IndexOf('ParImm.EndMeasurement :=') -lt $stopAction.IndexOf('IF ( NOT _kistlerStarted )')) 'Single-step repetition must refresh/clear END outside the one-shot branch.'
Assert-That ($waitAction -match '(?s)IF \( NOT Wp100A104Kistler.Unit.OutImm.MeasRunning \) OR\s+\( Wp100A104Kistler.Unit.ExecState <> OpconExecState.RUNNING \)\s+THEN\s+Wp100A104Kistler.Unit.ParImm.EndMeasurement := FALSE;') 'Result wait must clear END when measurement finishes or errors.'
Assert-That ($chainFinish.Contains('Wp100A104Kistler.Unit.ParImm.EndMeasurement := FALSE;')) 'Chain finish must reset END, including pre-start errors.'
Assert-That ($chainFinish.Contains('Wp100A104Kistler.Unit.Execute := FALSE;')) 'Chain finish must retain the standard falling-edge Cancel.'
foreach ($body in @($source, $stopAction, $waitAction, $chainFinish)) {
  Assert-That ($body -notmatch 'EndMeasurement\s*:=\s*TRUE') 'Unconditional END can create a second alarm before measurement starts.'
}
# Independent truth-table/lifecycle model, not a simulation of the vendor FB.
foreach ($sample in @(
  @($false,$false,'READY',$false), # Burster failure before Kistler start
  @($true,$false,'RUNNING',$false), # START sent; no measuring acknowledgement
  @($true,$true,'RUNNING',$true), # Normal stop or force fault while measuring
  @($true,$false,'RUNNING',$false), # Instrument stopped; result pending
  @($true,$false,'DONE',$false),
  @($true,$true,'ERROR',$false), # Stale running indication on device error
  @($true,$true,'CANCEL',$false),
  @($false,$true,'RUNNING',$false) # Not owned by this chain
)) {
  $end = $sample[0] -and $sample[1] -and $sample[2] -eq 'RUNNING'
  Assert-That ($end -eq $sample[3]) "END lifecycle case failed: $sample"
}


foreach ($fragment in @('IF ( Phase = 1 ) AND ( NOT _latched )', '_thresholdN := Station.ForceTraceAddon.ParCfg.rThresholdN', '_sigmaLimitN := Station.ForceTraceAddon.ParCfg.rLimitN', "_reason := 'INVALID_3SIGMA_LIMIT'", "_reason := 'FORCE_3SIGMA_UNSTABLE'", 'Peripherals._000SA620_X1.BusInfo.BusOk')) {Assert-That ($source.Contains($fragment)) "Missing v2 contract: $fragment"}
Assert-That (-not $source.Contains('_pressDelay(IN := forceAboveLimit')) 'Old stability timer is still active.'
Assert-That ($source.IndexOf('IF ( _waitLimit.Q )') -lt $source.IndexOf('ELSIF ( qualified )')) 'Total timeout must win over qualification in the same scan.'
Assert-That ($finish.Contains('Station.ForceTraceAddon.Recorder.FreezeStatistics();')) 'Resistance DONE must freeze its statistics.'
$stats=[IO.File]::ReadAllText((Join-Path $root 'src/plc/project/Station010/FB_PressForceStatistics.st'))
foreach($fragment in @('UDINT_TO_LREAL(Count - 1)', '( ThreeSigma < REAL_TO_LREAL(LimitN) )', '( ForceN <= ThresholdN )', '( ( NowMs - FirstMs ) >= WindowMs )')) {Assert-That ($stats.Contains($fragment)) "Missing statistical contract: $fragment"}
$recorder=[IO.File]::ReadAllText((Join-Path $root 'src/plc/project/Station010/FB_HmiForceTrace.st'))
Assert-That ($recorder.Contains('( _sampledScan = _scan )')) 'Sampling must follow MainTask scans instead of HMI timer or rounded milliseconds.'
Assert-That ($recorder.Contains('_trace[_position][9] := _trace[_position][17]')) 'First stable stream sample must be latched in PLC.'
Assert-That ($recorder.IndexOf('IF ( _guardActive ) AND ( NOT _frozen[_position] )', $recorder.IndexOf('count < 10001')) -gt $recorder.IndexOf('_trace[_position][8] := DWORD#1')) 'Statistics must continue after trace capacity.'
Write-Output 'PASS: force interlock source contracts, reset/END lifecycle truth tables, latched parameters, strict 3-sigma, fault-over-DONE and PLC scan ownership. Offline checks only.'
