# Source contracts and an independent lifecycle model, not a PLC/device test.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$chain = Join-Path $root 'src\plc\project\Station010\SqS_Wp100_Run'
function Read-Source([string]$Path) { [IO.File]::ReadAllText((Join-Path $chain $Path)) }
function Assert-That([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$method = Read-Source 'methods\CheckKistlerProgram.st'
$issue = $method.Substring($method.IndexOf('IF ( NOT _started )'), $method.IndexOf('IF ( NOT _done )') - $method.IndexOf('IF ( NOT _started )'))
Assert-That ($issue.Contains('KistlerForceStrokeCmd.SET_PROGRAM')) 'Missing standard program-selection command.'
Assert-That ($issue.Contains('_programNo := Station.TypeData.Wp100.KistlerProgramNo;')) 'Program must come from active TypeData.'
Assert-That ($issue.Contains('ParCmd.SetProgram.ProgNo := _programNo;')) 'Wrong command parameter block.'
Assert-That ($issue.Contains('ParCmd.Measure.ProgNo := _programNo;')) 'Both automatic program parameters must be staged together.'
Assert-That ($issue.IndexOf('ParCmd.Measure.ProgNo := _programNo;') -lt $issue.IndexOf('KistlerForceStrokeCmd.SET_PROGRAM')) 'Measurement program must be staged before selection.'
Assert-That ($issue -match '(?s)IF \( Wp100A104Kistler.Unit.OutImm.ProgNo = _programNo \) AND\s+\( Wp100A104Kistler.Unit.OutImm.Ready \) AND\s+\( NOT Wp100A104Kistler.Unit.OutImm.Alarm \).*?_done := TRUE;\s+ELSE.*?KistlerForceStrokeCmd.SET_PROGRAM') 'Skip selection only for an already matching, ready, alarm-free MP; otherwise request selection.'
Assert-That ($issue.Contains('NOT Wp100A104Kistler.Unit.Execute') -and $issue.Contains('NOT Wp100A104Kistler.Unit.OutImm.MeasRunning')) 'Cannot select while a command/measurement is active.'
foreach ($part in @('VAR_INST','RepeatOnError := FALSE','_done := TRUE;','OutImm.ProgNo = _programNo','KistlerProgramNo = _programNo','NOT Wp100A104Kistler.Unit.OutImm.Alarm','NOT Wp100A104Kistler.Unit.OutImm.MeasRunning')) {
  Assert-That ($method.Contains($part)) "Missing selection contract: $part"
}
Assert-That ($method -notmatch 'BasMoveCmd|KistlerForceStrokeCmd.MEASURE|OutImm\.\w+\s*:=|ErrorReset\s*:=') 'Selection must not move, measure or override feedback/alarms.'
foreach ($file in @('actions\N000.st','OnChainFinish.st')) {
  Assert-That ((Read-Source $file).Contains('CheckKistlerProgram(Reset := TRUE)')) "Missing explicit lifecycle reset: $file"
}
$gate = Read-Source 'actions\N045.st'
Assert-That ($gate.IndexOf('CheckKistlerProgram(Reset := FALSE)') -lt $gate.IndexOf('Execute := TRUE')) 'Kistler must be confirmed before Burster selection.'
Assert-That ($gate -match '(?s)IF \( _retVal <> OK \).*?RETURN;.*?_retVal := RUNNING;\s+_retVal2 := RUNNING;') 'Both branches must wait for both program selections.'
foreach ($file in @('actions\N050.st','actions\N051.st')) {
  $action = Read-Source $file
  foreach ($guard in @('OutImm.IsInWrkPosIn','_000K913_Y32','_000K912_Y32','NOT Wp100A104Kistler.Unit.OutImm.Alarm','OutImm.ProgNo = Station.TypeData.Wp100.KistlerProgramNo')) {
    Assert-That ($action.Contains($guard)) "Missing start interlock in ${file}: $guard"
  }
}

# A small independent model tests the request/DONE/READY handshake, including
# the vendor CheckUnitDone READY reissue hazard. Actual library/device behavior
# still requires a fresh PLE build and supervised commissioning.
function Tick($State, [string]$Exec, [bool]$Ready, [bool]$Alarm, [bool]$Measuring, [int]$Actual, [int]$Requested, [bool]$Reset = $false) {
  if ($Reset) { $State.Started=$false; $State.Done=$false; $State.Program=0; return $true }
  if (-not $State.Started) {
    if ($Exec -eq 'READY' -and -not $State.Execute -and -not $Measuring) {
      $State.Program=$Requested; $State.MeasureProgram=$Requested; $State.Started=$true
      if ($Actual -eq $Requested -and $Ready -and -not $Alarm) { $State.Done=$true }
      else { $State.Execute=$true; $State.Requests++ }
    }
    return $false
  }
  if (-not $State.Done) {
    if ($Exec -ne 'DONE') { return $false }
    $State.Execute=$false; $State.Done=$true
  }
  return ($Exec -eq 'READY' -and -not $State.Execute -and $Actual -eq $State.Program -and $Requested -eq $State.Program -and $Ready -and -not $Alarm -and -not $Measuring)
}
$state=@{Started=$false; Done=$false; Program=0; Execute=$false; Requests=0}
Assert-That (-not (Tick $state 'READY' $false $true $false 0 1)) 'Inactive MP cannot release motion.'
Assert-That ($state.Requests -eq 1 -and $state.Program -eq 1) 'Inactive MP must allow exactly one standard SET_PROGRAM request.'
foreach ($exec in @('RUNNING','ERROR','DONE')) { Assert-That (-not (Tick $state $exec $true $false $false 1 1)) 'Only completed READY can release.' }
foreach ($case in @(
  @{Ready=$false; Alarm=$false; Measuring=$false; Actual=1; Requested=1},
  @{Ready=$true; Alarm=$true; Measuring=$false; Actual=1; Requested=1},
  @{Ready=$true; Alarm=$false; Measuring=$true; Actual=1; Requested=1},
  @{Ready=$true; Alarm=$false; Measuring=$false; Actual=0; Requested=1},
  @{Ready=$true; Alarm=$false; Measuring=$false; Actual=1; Requested=2}
)) {
  Assert-That (-not (Tick $state 'READY' @case)) 'Unconfirmed/alarmed/changed MP released motion.'
}
1..3 | ForEach-Object { Assert-That (Tick $state 'READY' $true $false $false 1 1) 'Stable valid acknowledgement must release.' }
Assert-That ($state.Requests -eq 1) 'DONE must be latched; repeated checks must not reissue SET_PROGRAM.'
$null=Tick $state 'READY' $false $true $false 0 1 $true
Assert-That (-not $state.Started -and -not $state.Done) 'Cancel/new execution must reset selection state.'
$null=Tick $state 'READY' $false $true $false 0 1
Assert-That ($state.Requests -eq 2) 'A new execution must select again.'

# Already-selected MP must not re-enter the failing Auto/program handshake.
$healthy=@{Started=$false; Done=$false; Program=0; MeasureProgram=0; Execute=$false; Requests=0}
Assert-That (-not (Tick $healthy 'READY' $true $false $false 1 1)) 'Confirm feedback again on the next scan.'
Assert-That ($healthy.Requests -eq 0 -and -not $healthy.Execute -and $healthy.Program -eq 1 -and $healthy.MeasureProgram -eq 1) 'Healthy MP must stage both parameters without issuing a command.'
Assert-That (Tick $healthy 'READY' $true $false $false 1 1) 'Matching healthy MP should release without SET_PROGRAM.'
Assert-That (-not (Tick $healthy 'READY' $true $true $false 1 1)) 'A later alarm must still block the already-selected path.'
Assert-That (-not (Tick $healthy 'READY' $true $false $false 0 1)) 'A later MP change must still block the already-selected path.'
Assert-That (-not (Tick $healthy 'READY' $true $false $false 1 2)) 'Changed active TypeData must not release the old confirmation.'
foreach ($invalid in @(
  @{Ready=$true; Alarm=$false; Actual=0},
  @{Ready=$false; Alarm=$false; Actual=1},
  @{Ready=$true; Alarm=$true; Actual=1}
)) {
  $pending=@{Started=$false; Done=$false; Program=0; Execute=$false; Requests=0}
  Assert-That (-not (Tick $pending 'READY' -Ready $invalid.Ready -Alarm $invalid.Alarm -Measuring $false -Actual $invalid.Actual -Requested 1)) 'Unconfirmed MP must not release.'
  Assert-That ($pending.Requests -eq 1 -and $pending.Execute -and -not $pending.Done) 'Unconfirmed MP must use the standard command, not the skip path.'
}
foreach ($busy in @(
  @{Exec='RUNNING'; Measuring=$false; Execute=$false},
  @{Exec='ERROR'; Measuring=$false; Execute=$false},
  @{Exec='READY'; Measuring=$true; Execute=$false},
  @{Exec='READY'; Measuring=$false; Execute=$true}
)) {
  $pending=@{Started=$false; Done=$false; Program=0; Execute=$busy.Execute; Requests=0}
  Assert-That (-not (Tick $pending $busy.Exec $true $false $busy.Measuring 1 1)) 'Busy or failed Unit must not release.'
  Assert-That (-not $pending.Started -and $pending.Requests -eq 0) 'Never change a busy Unit command.'
}
Write-Output 'PASS: Kistler program source contracts and lifecycle model; no PLC runtime/device execution.'
