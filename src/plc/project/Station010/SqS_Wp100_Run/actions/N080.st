// Recheck force at the start edge; a step transition is not a retained permit.
IF ( _bursterStarted )
THEN
  // Also cover a single-step hold after the start request: do not retrigger.
  _retVal := CheckPressForce(Phase := 3);
  RETURN;
END_IF
_retVal := CheckPressForce(Phase := 2);
IF ( _retVal <> OK )
THEN
  RETURN;
END_IF
_retVal := RUNNING;

// Start one Burster resistance measurement after force qualification.
IF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPosIn ) AND
   ( Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPosIn ) AND
   ( Peripherals.BinIo._000K913_Y32 ) AND
   ( Peripherals.BinIo._000K912_Y32 ) AND
   ( Wp100A103ResistantDetector.Unit.ExecState = OpconExecState.READY )
THEN
  Wp100A103ResistantDetector.Unit.ParCmd.UpperLimit :=
    Station.TypeData.Wp100.Burster.UpperLimit;
  Wp100A103ResistantDetector.Unit.ParCmd.LowerLimit :=
    Station.TypeData.Wp100.Burster.LowerLimit;
  Wp100A103ResistantDetector.Unit.ParCmd.ReadTemperature :=
    Station.TypeData.Wp100.Burster.ReadTemperature;

  Wp100A103ResistantDetector.Unit.Command :=
    BursterResis2316Cmd.SINGLE_MEAS;
  Wp100A103ResistantDetector.Unit.Execute := TRUE;

  _bursterStarted := TRUE;
  _retVal := OK;
END_IF
