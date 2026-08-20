// Parallel branch 2: start Kistler MEASURE.
_retVal2 := RUNNING;

IF ( _kistlerStarted )
THEN
  _retVal2 := OK;

ELSIF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos ) AND
      ( Peripherals.BinIo._000K913_Y32 ) AND
      ( Peripherals.BinIo._000K912_Y32 ) AND
      ( Wp100A104Kistler.Unit.ExecState = OpconExecState.READY ) AND
      ( Wp100A104Kistler.Unit.OutImm.Ready )
THEN
  Wp100A104Kistler.Unit.ParImm.EndMeasurement := FALSE;
  Wp100A104Kistler.Unit.ParCmd.Measure.ProgNo :=
    Wp100A104Kistler.Unit.OutImm.ProgNo;

  IF ( Wp100A104Kistler.Unit.ParCmd.Measure.MeasuringTimeout <= T#0MS )
  THEN
    Wp100A104Kistler.Unit.ParCmd.Measure.MeasuringTimeout := T#30S;
  END_IF

  Wp100A104Kistler.Unit.Command := KistlerForceStrokeCmd.MEASURE;
  Wp100A104Kistler.Unit.Execute := TRUE;

  _kistlerStarted := TRUE;
  _retVal2 := OK;
END_IF
