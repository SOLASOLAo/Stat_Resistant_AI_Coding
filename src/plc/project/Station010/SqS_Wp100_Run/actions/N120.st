// Parallel branch 2: wait for Kistler MEASURE and copy the final verdict.
_retVal2 := RUNNING;

IF NOT _kistlerStarted
THEN
  _retVal2 := OK;
ELSE
  _retVal2 := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );

  IF _retVal2 = OK
  THEN
    Result.Kistler.Valid     := TRUE;
    Result.Kistler.Ok        := Wp100A104Kistler.Unit.OutCmd.OK;
    Result.Kistler.Nok       := Wp100A104Kistler.Unit.OutCmd.Nok;
  END_IF
END_IF
