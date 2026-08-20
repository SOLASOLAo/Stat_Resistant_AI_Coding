// Wait for Kistler MEASURE and copy its command and final cyclic values.
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
    Result.Kistler.NoPass    := Wp100A104Kistler.Unit.OutImm.NoPass;
    Result.Kistler.ProgramNo := Wp100A104Kistler.Unit.OutImm.ProgNo;
    Result.Kistler.Force     := Wp100A104Kistler.Unit.OutImm.ForceAct;
    Result.Kistler.Stroke    := Wp100A104Kistler.Unit.OutImm.StrokeAct;
  END_IF
END_IF
