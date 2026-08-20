// Wait until the safety door reaches base/open position.
IF ( NOT _safetyDoorOpenStarted )
THEN
  _retVal := OK;
ELSE
  _retVal := CheckUnitDone(
    Wp100K101SafetyDoor.Unit,
    RepeatOnError := TRUE
  );
END_IF
