// Release both parallel finish branches after resistance measurement while
// Kistler MEASURE is still active.
_retVal  := RUNNING;
_retVal2 := RUNNING;
Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_RETURN_SAFE_POSITION;

IF ( _kistlerStarted ) AND
   ( NOT Wp100A104Kistler.Unit.OutImm.MeasRunning )
THEN
  // Propagate an unexpected Kistler command end/error through the Chain API.
  _unitResult := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );
  _retVal := _unitResult;
END_IF

IF ( Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPos ) AND
   ( Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY ) AND
   ( _kistlerStarted ) AND
   ( Wp100A104Kistler.Unit.OutImm.MeasRunning )
THEN
  _retVal := OK;
END_IF
