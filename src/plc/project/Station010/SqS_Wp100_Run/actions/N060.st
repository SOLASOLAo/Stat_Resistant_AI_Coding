// Parallel branch 1: wait for pressing-cylinder WRKPOS.
_retVal := RUNNING;

IF ( _pressDownStarted )
THEN
  _retVal := CheckUnitDone(
    Wp100K102PressingCylinder.Unit,
    RepeatOnError := TRUE
  );
END_IF
