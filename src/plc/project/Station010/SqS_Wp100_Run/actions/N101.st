// Parallel branch 2: latch cyclic Kistler values before pressure is released,
// then request the end of MEASURE.
_retVal2 := RUNNING;

IF NOT _kistlerStarted
THEN
  _retVal2 := OK;

ELSIF NOT _kistlerStopRequested
THEN
  Result.Kistler.NoPass    := Wp100A104Kistler.Unit.OutImm.NoPass;
  Result.Kistler.ProgramNo := Wp100A104Kistler.Unit.OutImm.ProgNo;
  Result.Kistler.Force     := Wp100A104Kistler.Unit.OutImm.ForceAct;
  Result.Kistler.Stroke    := Wp100A104Kistler.Unit.OutImm.StrokeAct;

  Wp100A104Kistler.Unit.ParImm.EndMeasurement := TRUE;
  _kistlerStopRequested := TRUE;
  _retVal2 := OK;

ELSE
  _retVal2 := OK;
END_IF
