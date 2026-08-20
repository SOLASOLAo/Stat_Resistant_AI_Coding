// Parallel branch 1: start pressing-cylinder WRKPOS.
_retVal := RUNNING;

IF _pressDownStarted
THEN
  _retVal := OK;

ELSIF Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos
      AND Peripherals.BinIo._000K913_Y32
      AND Peripherals.BinIo._000K912_Y32
      AND Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos
      AND (Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY)
THEN
  Wp100K102PressingCylinder.Unit.ParCmd.PreStartCheck :=
    (Station.Unit.ModeSet <> StationMode.HOME);
  Wp100K102PressingCylinder.Unit.ParCmd.OutputPulsing :=
    (Station.Unit.ModeSet = StationMode.HOME);
  Wp100K102PressingCylinder.Unit.Command := BasMoveCmd.WRKPOS;
  Wp100K102PressingCylinder.Unit.Execute := TRUE;

  _pressDownStarted := TRUE;
  _retVal := OK;
END_IF
