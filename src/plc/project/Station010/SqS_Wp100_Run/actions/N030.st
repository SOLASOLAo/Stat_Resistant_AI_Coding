// Close the safety door. A door already in work/closed position is accepted;
// otherwise the maintenance-door safety relay must be healthy before motion.
IF Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos
THEN
  _safetyDoorCloseStarted := FALSE;
  _retVal := OK;

ELSIF Peripherals.BinIo._000K981_Y32
      AND Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos
      AND (Wp100K101SafetyDoor.Unit.ExecState = OpconExecState.READY)
THEN
  Wp100K101SafetyDoor.Unit.ParCmd.PreStartCheck :=
    (Station.Unit.ModeSet <> StationMode.HOME);
  Wp100K101SafetyDoor.Unit.ParCmd.OutputPulsing :=
    (Station.Unit.ModeSet = StationMode.HOME);
  Wp100K101SafetyDoor.Unit.Command := BasMoveCmd.WRKPOS;
  Wp100K101SafetyDoor.Unit.Execute := TRUE;

  _safetyDoorCloseStarted := TRUE;
  _retVal := OK;
END_IF
