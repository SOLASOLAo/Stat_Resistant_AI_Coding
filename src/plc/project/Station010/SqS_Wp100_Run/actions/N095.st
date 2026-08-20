// Release both parallel finish branches after resistance measurement while
// Kistler MEASURE is still active.
_retVal  := RUNNING;
_retVal2 := RUNNING;

IF _kistlerStarted
   AND NOT Wp100A104Kistler.Unit.OutImm.MeasRunning
THEN
  // Propagate an unexpected Kistler command end/error through the Chain API.
  _unitResult := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );
END_IF

IF Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPos
   AND (Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY)
   AND _kistlerStarted
   AND Wp100A104Kistler.Unit.OutImm.MeasRunning
THEN
  _retVal := OK;
END_IF
