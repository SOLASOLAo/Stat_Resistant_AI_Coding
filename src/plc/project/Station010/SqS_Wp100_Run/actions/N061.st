// Parallel branch 2: keep MEASURE active and wait for Kistler measuring state.
_retVal2 := RUNNING;

IF _kistlerStarted
THEN
  _retVal2 := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );

  IF Wp100A104Kistler.Unit.OutImm.MeasRunning
  THEN
    _retVal2 := OK;
  END_IF
END_IF
