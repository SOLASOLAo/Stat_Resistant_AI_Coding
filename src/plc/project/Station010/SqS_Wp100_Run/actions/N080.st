// Start one Burster resistance measurement after the press delay.
IF Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos
   AND Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPos
   AND Peripherals.BinIo._000K913_Y32
   AND Peripherals.BinIo._000K912_Y32
   AND (Wp100A103ResistantDetector.Unit.ExecState = OpconExecState.READY)
THEN
  Wp100A103ResistantDetector.Unit.Command :=
    BursterResis2316Cmd.SINGLE_MEAS;
  Wp100A103ResistantDetector.Unit.Execute := TRUE;

  _bursterStarted := TRUE;
  _retVal := OK;
END_IF
