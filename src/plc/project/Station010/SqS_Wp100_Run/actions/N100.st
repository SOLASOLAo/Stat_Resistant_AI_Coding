// Request Kistler measurement end and start pressing-cylinder BASPOS in the
// same PLC cycle. This is earlier than the required one-second stop limit.
IF Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPos
   AND (Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY)
THEN
  // ForceAct/StrokeAct are cyclic actual values. Capture them before the
  // upward motion unloads the part; command verdict is added in N120.
  Result.Kistler.NoPass    := Wp100A104Kistler.Unit.OutImm.NoPass;
  Result.Kistler.ProgramNo := Wp100A104Kistler.Unit.OutImm.ProgNo;
  Result.Kistler.Force     := Wp100A104Kistler.Unit.OutImm.ForceAct;
  Result.Kistler.Stroke    := Wp100A104Kistler.Unit.OutImm.StrokeAct;

  Wp100A104Kistler.Unit.ParImm.EndMeasurement := TRUE;

  Wp100K102PressingCylinder.Unit.ParCmd.PreStartCheck :=
    (Station.Unit.ModeSet <> StationMode.HOME);
  Wp100K102PressingCylinder.Unit.ParCmd.OutputPulsing :=
    (Station.Unit.ModeSet = StationMode.HOME);
  Wp100K102PressingCylinder.Unit.Command := BasMoveCmd.BASPOS;
  Wp100K102PressingCylinder.Unit.Execute := TRUE;

  _pressUpStarted := TRUE;
  _retVal := OK;
END_IF
