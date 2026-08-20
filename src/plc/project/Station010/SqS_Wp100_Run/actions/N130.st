// Open the safety door only after the pressing cylinder is confirmed up.
IF ( Wp100K101SafetyDoor.Unit.OutImm.IsInBasPos )
THEN
  _safetyDoorOpenStarted := FALSE;
  _retVal := OK;

ELSIF ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos ) AND
      ( Wp100K101SafetyDoor.Unit.ExecState = OpconExecState.READY )
THEN
  Wp100K101SafetyDoor.Unit.ParCmd.PreStartCheck :=
    ( Station.Unit.ModeSet <> StationMode.HOME );
  Wp100K101SafetyDoor.Unit.ParCmd.OutputPulsing :=
    ( Station.Unit.ModeSet = StationMode.HOME );
  Wp100K101SafetyDoor.Unit.Command := BasMoveCmd.BASPOS;
  Wp100K101SafetyDoor.Unit.Execute := TRUE;

  _safetyDoorOpenStarted := TRUE;
  _retVal := OK;
END_IF
