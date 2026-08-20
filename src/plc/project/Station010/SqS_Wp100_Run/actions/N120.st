// Wait for Kistler MEASURE and add its final command verdict. The cyclic
// force/stroke values were already latched at the start of upward motion.
IF NOT _kistlerStarted
THEN
  _retVal := OK;
ELSE
  _unitResult := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );
  _retVal := _unitResult;

  IF _unitResult = OK
  THEN
    Result.Kistler.Valid     := TRUE;
    Result.Kistler.Ok        := Wp100A104Kistler.Unit.OutCmd.OK;
    Result.Kistler.Nok       := Wp100A104Kistler.Unit.OutCmd.Nok;
  END_IF
END_IF
