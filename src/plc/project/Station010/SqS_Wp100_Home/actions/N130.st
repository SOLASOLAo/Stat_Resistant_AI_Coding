// Return the pressing cylinder to base position. An already homed cylinder
// is skipped. Start only after the closed safety door and both safety-circuit
// feedbacks have been confirmed.
IF ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPosIn )
THEN
  _pressingCylinderHomeStarted := FALSE;
  _retVal := OK;

ELSIF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPosIn ) AND
      ( Peripherals.BinIo._000K913_Y32 ) AND
      ( Peripherals.BinIo._000K912_Y32 ) AND
      ( Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY ) AND
      ( _env.StepPulse )
THEN
  Wp100K102PressingCylinder.Unit.ParCmd.PreStartCheck :=
    ( Station.Unit.ModeSet <> StationMode.HOME );
  Wp100K102PressingCylinder.Unit.ParCmd.OutputPulsing :=
    ( Station.Unit.ModeSet = StationMode.HOME );

  Wp100K102PressingCylinder.Unit.Command := BasMoveCmd.BASPOS;
  Wp100K102PressingCylinder.Unit.Execute := TRUE;

  _pressingCylinderHomeStarted := TRUE;
  _retVal := OK;
END_IF
