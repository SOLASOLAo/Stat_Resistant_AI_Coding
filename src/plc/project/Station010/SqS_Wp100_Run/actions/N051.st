// Branch 2: validate configuration, then start Kistler before press-down.
_retVal2 := CheckPressForce(Phase := 1);
IF ( _retVal2 <> OK )
THEN
  RETURN;
END_IF
_retVal2 := RUNNING;

IF ( _kistlerStarted )
THEN
  _retVal2 := OK;

ELSIF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPosIn ) AND
      ( Peripherals.BinIo._000K913_Y32 ) AND
      ( Peripherals.BinIo._000K912_Y32 ) AND
      ( Wp100A104Kistler.Unit.ExecState = OpconExecState.READY ) AND
      ( Wp100A104Kistler.Unit.OutImm.Ready ) AND
      ( NOT Wp100A104Kistler.Unit.OutImm.Alarm ) AND
      ( Wp100A104Kistler.Unit.OutImm.ProgNo = Station.TypeData.Wp100.KistlerProgramNo )
THEN
  Wp100A104Kistler.Unit.ParImm.EndMeasurement := FALSE;
  Wp100A104Kistler.Unit.ParCmd.Measure.ProgNo :=
    Station.TypeData.Wp100.KistlerProgramNo;

  // Keep a larger watchdog; reserve 30 s beyond force waiting for movement,
  // Burster and the end handshake. This is bounded, not an unlimited measure.
  IF ( Wp100A104Kistler.Unit.ParCmd.Measure.MeasuringTimeout <
       ( DINT_TO_TIME(Station.StationData.PressForceTimeout) + T#30S ) )
  THEN
    Wp100A104Kistler.Unit.ParCmd.Measure.MeasuringTimeout :=
      DINT_TO_TIME(Station.StationData.PressForceTimeout) + T#30S;
  END_IF

  Wp100A104Kistler.Unit.Command := KistlerForceStrokeCmd.MEASURE;
  Wp100A104Kistler.Unit.Execute := TRUE;

  _kistlerStarted := TRUE;
  _retVal2 := OK;
END_IF
