// Parallel branch 2: wait for Kistler MEASURE and copy the final verdict.
_retVal2 := RUNNING;

// END belongs only to the running measurement, not to result collection.
IF ( NOT Wp100A104Kistler.Unit.OutImm.MeasRunning ) OR
   ( Wp100A104Kistler.Unit.ExecState <> OpconExecState.RUNNING )
THEN
  Wp100A104Kistler.Unit.ParImm.EndMeasurement := FALSE;
END_IF

IF ( NOT _kistlerStarted )
THEN
  _retVal2 := OK;
ELSE
  _retVal2 := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );

  IF ( _retVal2 = OK )
  THEN
    Result.Kistler.Valid     := TRUE;
    Result.Kistler.Ok        := Wp100A104Kistler.Unit.OutCmd.OK;
    Result.Kistler.Nok       := Wp100A104Kistler.Unit.OutCmd.Nok;
  END_IF
END_IF
