// Parallel branch 1: start pressing-cylinder BASPOS.
_retVal := RUNNING;

IF _pressUpStarted
THEN
  _retVal := OK;

ELSIF Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPos
      AND (Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY)
THEN
  Wp100K102PressingCylinder.Unit.ParCmd.PreStartCheck :=
    (Station.Unit.ModeSet <> StationMode.HOME);
  Wp100K102PressingCylinder.Unit.ParCmd.OutputPulsing :=
    (Station.Unit.ModeSet = StationMode.HOME);
  Wp100K102PressingCylinder.Unit.Command := BasMoveCmd.BASPOS;
  Wp100K102PressingCylinder.Unit.Execute := TRUE;

  _pressUpStarted := TRUE;
  _retVal := OK;
END_IF
