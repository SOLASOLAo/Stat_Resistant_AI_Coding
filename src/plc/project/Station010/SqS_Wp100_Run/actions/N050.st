// Start Kistler MEASURE and pressing-cylinder WRKPOS in the same PLC cycle.
IF Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos
   AND Peripherals.BinIo._000K913_Y32
   AND Peripherals.BinIo._000K912_Y32
   AND Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos
   AND (Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY)
   AND (Wp100A104Kistler.Unit.ExecState = OpconExecState.READY)
   AND Wp100A104Kistler.Unit.OutImm.Ready
THEN
  Wp100A104Kistler.Unit.ParImm.EndMeasurement := FALSE;
  Wp100A104Kistler.Unit.ParCmd.Measure.ProgNo :=
    Wp100A104Kistler.Unit.OutImm.ProgNo;
  IF Wp100A104Kistler.Unit.ParCmd.Measure.MeasuringTimeout <= T#0MS
  THEN
    Wp100A104Kistler.Unit.ParCmd.Measure.MeasuringTimeout := T#30S;
  END_IF
  Wp100A104Kistler.Unit.Command := KistlerForceStrokeCmd.MEASURE;
  Wp100A104Kistler.Unit.Execute := TRUE;

  Wp100K102PressingCylinder.Unit.ParCmd.PreStartCheck :=
    (Station.Unit.ModeSet <> StationMode.HOME);
  Wp100K102PressingCylinder.Unit.ParCmd.OutputPulsing :=
    (Station.Unit.ModeSet = StationMode.HOME);
  Wp100K102PressingCylinder.Unit.Command := BasMoveCmd.WRKPOS;
  Wp100K102PressingCylinder.Unit.Execute := TRUE;

  _kistlerStarted   := TRUE;
  _pressDownStarted := TRUE;
  _retVal := OK;
END_IF
