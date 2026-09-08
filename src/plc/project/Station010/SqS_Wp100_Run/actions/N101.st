// Parallel branch 2: latch cyclic Kistler values before pressure is released,
// then request the end of MEASURE.
_retVal2 := RUNNING;

// This action can repeat in single-step mode; never leave END set after stop.
Wp100A104Kistler.Unit.ParImm.EndMeasurement :=
  ( _kistlerStarted ) AND
  ( Wp100A104Kistler.Unit.OutImm.MeasRunning ) AND
  ( Wp100A104Kistler.Unit.ExecState = OpconExecState.RUNNING );

IF ( NOT _kistlerStarted )
THEN
  _retVal2 := OK;

ELSIF ( NOT _kistlerStopRequested )
THEN
  Result.Kistler.NoPass    := Wp100A104Kistler.Unit.OutImm.NoPass;
  Result.Kistler.ProgramNo := Wp100A104Kistler.Unit.OutImm.ProgNo;
  Result.Kistler.Force     := Wp100A104Kistler.Unit.OutImm.ForceAct;
  Result.Kistler.Stroke    := Wp100A104Kistler.Unit.OutImm.StrokeAct;

  _kistlerStopRequested := TRUE;
  _retVal2 := OK;

ELSE
  _retVal2 := OK;
END_IF
