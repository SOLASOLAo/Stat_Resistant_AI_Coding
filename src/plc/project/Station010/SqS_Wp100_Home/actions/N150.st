// Finally return the safety door to base/open position. Skip the command
// when the door is already in base position.
IF ( Wp100K101SafetyDoor.Unit.OutImm.IsInBasPosIn )
THEN
  _safetyDoorHomeStarted := FALSE;
  _retVal := OK;

ELSIF ( Wp100K101SafetyDoor.Unit.ExecState = OpconExecState.READY ) AND
      ( _env.StepPulse )
THEN
  Wp100K101SafetyDoor.Unit.ParCmd.PreStartCheck :=
    ( Station.Unit.ModeSet <> StationMode.HOME );
  Wp100K101SafetyDoor.Unit.ParCmd.OutputPulsing :=
    ( Station.Unit.ModeSet = StationMode.HOME );

  Wp100K101SafetyDoor.Unit.Command := BasMoveCmd.BASPOS;
  Wp100K101SafetyDoor.Unit.Execute := TRUE;

  _safetyDoorHomeStarted := TRUE;
  _retVal := OK;
END_IF
