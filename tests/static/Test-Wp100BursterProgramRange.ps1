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
Assert-That ($selector -match '(?s)ELSIF \( _readBuffer\[0\] = 21 \)\s+THEN\s+ErrorCode := 6;\s+_timer\(IN := FALSE, PT := T#0S\);\s+_state := 190;') 'NAK must take error cleanup, not release the press.'
Assert-That ($selector -match '(?s)IF \( _readBuffer\[0\] = 6 \)\s+THEN\s+_timer\(IN := FALSE, PT := T#0S\);\s+_state := 50;') 'ACK must pass through EOT and close before Done.'

# These assertions inspect the deployed ST source, not a duplicate state-machine
# model. They protect async call ownership but do not simulate the OpCon library.
function Read-SelectorState([int]$State) {
  $block = [regex]::Match($selector, "(?ms)^  ${State}:\r?\n(?<body>.*?)(?=^  (?:[0-9]+:|ELSE)|^END_CASE)")
  Assert-That $block.Success "Missing selector state $State."
  $block.Groups['body'].Value
}
$initial = Read-SelectorState 0
foreach ($counter in @('_sendOffset', '_bytesWritten', '_bytesRead', '_readBuffer[0]', '_readBuffer[1]')) {
  Assert-That ($initial.Contains("$counter := 0;")) "New request retains stale $counter."
}
Assert-That ($initial.Contains('ErrorCode := 0;') -and $initial.Contains('OpconMemSet(ADR(LastSocketError)')) 'New explicit request must reset its own diagnostics.'
$open = Read-SelectorState 20
Assert-That ($open -match '(?s)ELSIF \( _socketResult = OK \) AND\s+\( _socket.IsOpen \).*?_state := 30;') 'Open requires both completed OK and IsOpen.'
Assert-That ($open -match '(?s)ELSIF \( _socketResult <> RUNNING \) OR\s+\( _timer.Q \).*?ErrorCode := 3;.*?_state := 195;') 'Pending or inconsistent Open must enter Reset, even when IsOpen is false.'
$write = Read-SelectorState 30
Assert-That ($write -match '(?s)ELSIF \( _socketResult = OK \).*?_sendOffset := _sendOffset \+ _bytesWritten;') 'Only a completed Write may advance its buffer.'
Assert-That ([regex]::Matches($write, '_sendOffset\s*:=').Count -eq 1) 'Write buffer must remain stable while RUNNING.'
$read = Read-SelectorState 40
Assert-That ($read -match '(?s)ELSIF \( _socketResult = OK \) AND\s+\( _bytesRead > 0 \).*?IF \( _readBuffer\[0\] = 6 \)') 'Bytes arriving before Read completes must not release ACK.'
$eot = Read-SelectorState 50
Assert-That ($eot -match '(?s)ELSIF \( _socketResult = OK \) AND\s+\( _bytesWritten = 1 \).*?_state := 60;') 'One EOT byte with Write still RUNNING must not start Close.'
$close = Read-SelectorState 60
Assert-That ($close -match '(?s)IF \( _socketResult = OK \) AND\s+\( NOT _socket.IsOpen \).*?_state := 65;') 'Every completed temporary Close must enter standard lifecycle Reset, including repeated selections.'
Assert-That ($close -notmatch 'Done\s*:= TRUE') 'Temporary Close alone is not a complete measuring-driver handoff.'
Assert-That ($close -match '(?s)ELSIF \( _socketResult <> RUNNING \) OR\s+\( _timer.Q \).*?ErrorCode := 9;.*?_state := 195;') 'Failed, inconsistent or timed-out Close must not release Done.'
$prepareReset = Read-SelectorState 65
$prepareClear = Read-SelectorState 66
Assert-That ($prepareReset -match '(?s)_closeResult := Peripherals\._Wp100A103ResistantInterface.Reset\(\);.*?IF \( _closeResult = OK \).*?_state := 66;') 'Each standard reconnect must finish its own Reset before clearing the previous lifecycle.'
Assert-That ($prepareClear -match '(?s)_closeResult := Peripherals\._Wp100A103ResistantInterface.ClearError\(\);.*?IF \( _closeResult = OK \).*?_state := 70;') 'Standard Open requires completed public ClearError, not just a ready Unit.'
foreach ($entry in @(@{ State = 65; Error = 12 }, @{ State = 66; Error = 13 })) {
  $preparation = Read-SelectorState $entry.State
  Assert-That ($preparation.Contains('_timer(IN := TRUE, PT := T#3S);')) 'Standard lifecycle preparation must be bounded.'
  Assert-That ($preparation -match "(?s)ELSIF \( _closeResult <> RUNNING \) OR\s+\( _timer.Q \).*?LastSocketError := Peripherals\._Wp100A103ResistantInterface.LastError;.*?ErrorCode := $($entry.Error);.*?_state := 187;") 'Failed preparation must latch its own error and finish standard cleanup, not open or release Done.'
}
# Protect the actual source path used by all positions, not a cached successful
# first selection. A closed handle is not valid input for another Close.
Assert-That ($prepareReset -notmatch '\.Close\(' -and $prepareClear -notmatch '\.Close\(') 'No second Close after standard Reset has closed the stream.'
$handoffEntryCount = [regex]::Matches($selector, '_state := 70;').Count
Assert-That ($handoffEntryCount -eq 1) 'Every reconnect must take Reset -> ClearError -> Open; repeated selections cannot bypass preparation.'
$reopen = Read-SelectorState 70
Assert-That ($reopen -match '(?s)_closeResult := Peripherals\._Wp100A103ResistantInterface\.Open\(\);.*?IF \( _closeResult = OK \).*?Done\s*:= TRUE;.*?_state := 100;') 'Done requires successful public Open of the standard measuring driver.'
Assert-That ($reopen.Contains('_timer(IN := TRUE, PT := T#35S);')) 'Standard reconnect must have a bounded pre-motion watchdog.'
Assert-That ($reopen -match '(?s)ELSIF \( _closeResult <> RUNNING \) OR\s+\( _timer.Q \).*?LastSocketError := Peripherals\._Wp100A103ResistantInterface.LastError;.*?ErrorCode := 11;.*?_state := 187;') 'Failed or pending timed-out standard Open must retain its error and reset that driver.'
$standardReset = Read-SelectorState 187
Assert-That ($standardReset -match '(?s)_closeResult := Peripherals\._Wp100A103ResistantInterface.Reset\(\);.*?IF \( _closeResult <> RUNNING \).*?_state := 195;') 'Completed standard Reset already closes its stream and must proceed directly to temporary cleanup.'
Assert-That ($standardReset -notmatch '\.Close\(|\.ClearError\(|_state := 185;') 'Do not close an invalid handle or clear the first error after standard Reset.'
Assert-That ($standardReset -notmatch '_socket\.|Done\s*:= TRUE|Busy\s*:= FALSE') 'Standard Reset cannot be replaced by temporary-socket Reset or release readiness.'
$standardResetTimeout = [regex]::Match($standardReset, '(?s)ELSIF \( _timer.Q \).*').Value
Assert-That ($standardResetTimeout -notmatch '_state\s*:=|Busy\s*:= FALSE') 'Pending standard Reset remains Busy after its diagnostic timeout.'
foreach ($state in @(65, 66, 70, 187)) {
  Assert-That ((Read-SelectorState $state) -notmatch 'MeasCmd\s*\(|\.Execute\s*:=|SET_RANGE|\.ParCfg\..*:=') "Handoff state $state must not trigger measuring, motion or configuration changes."
}
foreach ($match in [regex]::Matches($selector, '(?ms)^  (?<state>[0-9]+):\r?\n(?<body>.*?)(?=^  (?:[0-9]+:|ELSE)|^END_CASE)')) {
  if ($match.Groups['body'].Value -match 'Done\s*:= TRUE') {
    Assert-That ([int]$match.Groups['state'].Value -in @(70, 100)) 'Only completed standard Open and the success-hold state may report Done.'
  }
}
$reset = Read-SelectorState 195
Assert-That ($reset -match '(?s)_socketResult := _socket.Reset\(\);.*?IF \( _socketResult <> RUNNING \).*?Busy\s*:= FALSE;') 'Reset must be polled until its return value completes, irrespective of IsOpen.'
Assert-That ($reset -notmatch '_socket\.IsOpen|Done\s*:= TRUE') 'Reset must not skip pending Open cleanup or report selection success.'
$resetTimeout = [regex]::Match($reset, '(?s)ELSIF \( _timer.Q \).*').Value
Assert-That ($resetTimeout -and $resetTimeout -notmatch 'Busy\s*:= FALSE|_state\s*:=') 'Pending Reset timeout must retain Busy and keep polling.'
foreach ($state in @(185, 187, 190, 191, 195)) {
  $cleanup = Read-SelectorState $state
  $captures = [regex]::Matches($cleanup, 'LastSocketError\s*:=')
  $guarded = [regex]::Matches($cleanup, '(?s)\( ErrorCode = 0 \)\s+THEN\s+LastSocketError\s*:=')
  Assert-That ($captures.Count -eq $guarded.Count) "Cleanup $state must preserve the first error snapshot."
}
$cancel = $selector.Substring($selector.IndexOf('IF ( NOT Execute )'), $selector.IndexOf('CASE _state OF') - $selector.IndexOf('IF ( NOT Execute )'))
Assert-That ($cancel -match '(?s)\( _state = 60 \).*?_state := 191;.*?\( _socketResult = RUNNING \) OR\s+\( NOT _socket.IsOpen \).*?_state := 195;') 'Cancellation must continue pending Close or reset abandoned I/O, not start a conflicting method.'
Assert-That ($cancel -match '(?s)\( _state = 65 \) OR\s+\( _state = 66 \) OR\s+\( _state = 70 \)\s+THEN\s+_state := 187;') 'Cancellation during standard preparation or Open must reset the standard owner, not only the temporary socket.'
$pump = [IO.File]::ReadAllText((Join-Path $plc 'StationUnit/OnCall.BursterCleanup.st'))
Assert-That ($pump -match '(?s)IF \( NOT AiWp100.BursterProgramSelect.Execute \) AND\s+\( AiWp100.BursterProgramSelect.Busy \)\s+THEN\s+AiWp100.BursterProgramSelect\(\);\s+END_IF') 'One-cycle OnChainFinish needs a guarded cyclic cancellation pump.'
Assert-That ($pump -notmatch ':=|SINGLE_MEAS|MOVE_WRKPOS') 'Cancellation hook must not start selection, measurement or motion.'
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
Write-Output 'Burster source checks OK: numeric RCL frames 0..15, repeated-selection Reset/ClearError/Open path, no Close after standard Reset, bounded per-owner cleanup, first-error retention, cyclic cancellation, no range override, preserved grading/temperature/force checks and generated ownership. Source contracts only; Build and field acceptance remain required.'
