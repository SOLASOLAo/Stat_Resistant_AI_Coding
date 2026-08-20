// Parallel branch 1: wait for pressing-cylinder BASPOS.
_retVal := RUNNING;

IF ( _pressUpStarted )
THEN
  _retVal := CheckUnitDone(
    Wp100K102PressingCylinder.Unit,
    RepeatOnError := TRUE
  );
END_IF
