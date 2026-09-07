// Parallel branch 1: wait for pressing-cylinder WRKPOS.
_retVal := RUNNING;

IF ( _pressDownStarted )
THEN
  _retVal := CheckUnitDone(
    Wp100K102PressingCylinder.Unit,
    RepeatOnError := TRUE
  );

  IF ( _retVal = OK ) AND
     ( Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPos )
  THEN
    // Start total force waiting at confirmed press-down; N070 waits for
    // qualification or holds the latched fault on the following step.
    _unitResult := CheckPressForce(Phase := 2);
  ELSIF ( _retVal = OK )
  THEN
    _retVal := RUNNING;
  END_IF
END_IF
