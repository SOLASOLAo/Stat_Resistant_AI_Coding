# Offline timing-model and source-contract checks; not a PLC runtime simulation.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$chain = Join-Path $root 'src\plc\project\Station010\SqS_Wp100_Run'
$source = [IO.File]::ReadAllText((Join-Path $chain 'methods\CheckPressForce.st'))

function Assert-That([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

foreach ($fragment in @(
  'VAR_INST', 'forceN > REAL#2500.0', '_timeoutMs <= 2000',
  '_waitLimit(IN := TRUE, PT := DINT_TO_TIME(_timeoutMs))',
  '_pressDelay(IN := forceAboveLimit, PT := T#2S)',
  'IF ( NOT _fault )', 'OpconEventClass.SOFTERROR', 'Lock := TRUE',
  'Wp100.EVENT_PRESS_FORCE_INVALID', '_additionalInfo : STRING(63)',
  'Result.Resistance.Valid := FALSE', 'Result.Resistance.Ok := FALSE',
  'Wp100A104Kistler.Unit.OutImm.MeasRunning', 'Wp100A104Kistler.Unit.ExecState = OpconExecState.ERROR',
  'NOT ( forceN = forceN )', 'ABS(forceN) > REAL#3.402823E38',
  'NOT Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPosIn',
  'Wp100A103ResistantDetector.Unit.Execute := FALSE'
)) {
  Assert-That ($source.Contains($fragment)) "Missing force contract: $fragment"
}
Assert-That ($source -notmatch 'BasMoveCmd\.BASPOS|PressingCylinder\.Unit\.(Command|Execute)\s*:=') 'Force fault must not command cylinder movement.'
Assert-That ($source.IndexOf('_fault := FALSE') -lt $source.IndexOf('forceN :=')) 'Latch reset must remain in the explicit reset branch.'
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
Assert-That ($finish.IndexOf('RETURN;') -lt $finish.IndexOf('Result.Resistance.Valid')) 'Fault must exit before accepting a result.'
$press = [IO.File]::ReadAllText((Join-Path $chain 'actions\N050.st'))
Assert-That ($press.IndexOf('OutImm.MeasRunning') -lt $press.IndexOf('BasMoveCmd.WRKPOS')) 'Kistler must be measuring before press-down.'
$writer = [IO.File]::ReadAllText((Join-Path $root 'scripts\plc\apply_wp100_run_rest.ps1'))
Assert-That ($writer.IndexOf('$runGraphStatus = if') -lt $writer.IndexOf('$forceMethodStatus = Set-Action')) 'Existing graph PUT must precede force-method POST; do not predict PLE child ordering.'
Assert-That (-not ($source + $press).Contains('.ErrorSet')) 'Kistler V1.2 has no ErrorSet member; use its supported ExecState.'

# END is a running-measurement request, not the chain's generic cancel signal.
$stopAction = [IO.File]::ReadAllText((Join-Path $chain 'actions\N101.st'))
$waitAction = [IO.File]::ReadAllText((Join-Path $chain 'actions\N120.st'))
$chainFinish = [IO.File]::ReadAllText((Join-Path $chain 'OnChainFinish.st'))
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

# Small independent process model. Source assertions above tie its threshold,
# two timers, latched fault and call ordering to the implementation being built.
function New-ForceState([int]$Timeout = 10000) {
  return @{ Timeout=$Timeout; WaitStart=$null; StableStart=$null; Fault=''; Qualified=$false }
}
function Invoke-ForceSample($State, [int]$Ms, [double]$Force, [bool]$Measuring=$false, [bool]$Valid=$true) {
  if ($State.Fault) { return $false }
  if ($State.Timeout -le 2000) { $State.Fault='INVALID_TIMEOUT'; return $false }
  if (-not $Valid -or -not [double]::IsFinite($Force)) { $State.Fault='INVALID_DATA'; return $false }
  if ($Measuring) {
    if ($Force -le 2500) { $State.Fault='FORCE_LOST'; return $false }
    return $true
  }
  if ($null -eq $State.WaitStart) { $State.WaitStart=$Ms }
  if ($Force -gt 2500) {
    if ($null -eq $State.StableStart) { $State.StableStart=$Ms }
  } else { $State.StableStart=$null }
  $State.Qualified=($null -ne $State.StableStart -and $Ms-$State.StableStart -ge 2000)
  if ($Ms-$State.WaitStart -ge $State.Timeout -and -not $State.Qualified) {
    $State.Fault='WAIT_TIMEOUT'; return $false
  }
  return $State.Qualified
}

foreach ($position in @('LEFT','MIDDLE','RIGHT')) {
  $state=New-ForceState
  Assert-That (-not (Invoke-ForceSample $state 0 2501)) "$position released before stability."
  Assert-That (-not (Invoke-ForceSample $state 1999 2501)) "$position released at 1999 ms."
  Assert-That (Invoke-ForceSample $state 2000 2501) "$position did not release at 2000 ms."
  Assert-That (Invoke-ForceSample $state 2100 3000 $true) "$position rejected valid measurement."
  Assert-That (-not (Invoke-ForceSample $state 2200 2500 $true)) "$position accepted equality during measurement."
  Assert-That (-not (Invoke-ForceSample $state 2300 4000 $true)) "$position automatically recovered a latched fault."
}
$state=New-ForceState
$null=Invoke-ForceSample $state 0 3000
$null=Invoke-ForceSample $state 1900 2500
Assert-That (-not (Invoke-ForceSample $state 2000 3000)) 'A dip failed to reset stability.'
Assert-That (-not (Invoke-ForceSample $state 3999 3000)) 'Stability resumed from accumulated time.'
Assert-That (Invoke-ForceSample $state 4000 3000) 'Continuous requalification failed.'
$state=New-ForceState 5000
for ($ms=0; $ms -le 5000; $ms+=1000) { $null=Invoke-ForceSample $state $ms $(if ($ms%2000 -eq 0) {2500} else {3000}) }
Assert-That ($state.Fault -eq 'WAIT_TIMEOUT') 'Force bounce restarted the total diagnostic timer.'
foreach ($timeout in @(-1,0,1999,2000)) {
  Assert-That (-not (Invoke-ForceSample (New-ForceState $timeout) 0 3000)) 'Invalid timeout bypassed monitoring.'
}
foreach ($force in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)) {
  Assert-That (-not (Invoke-ForceSample (New-ForceState) 0 $force $true)) 'Non-finite force released measurement.'
}
Assert-That (-not (Invoke-ForceSample (New-ForceState) 0 3000 $true $false)) 'Invalid communication accepted stale force.'
Assert-That (Invoke-ForceSample (New-ForceState) 0 3000 $true) 'A clean new execution cannot be evaluated.'
Write-Output 'Wp100 force checks OK: three positions, strict threshold, continuous 2 s, total timeout, single-step start guard, first-fault latch, same-scan completion priority, invalid data and no press-up on fault. Timing model only; field acceptance remains required.'
