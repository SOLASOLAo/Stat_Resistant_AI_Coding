// Wait until the pressing cylinder reaches base/up position.
IF NOT _pressUpStarted
THEN
  _retVal := OK;
ELSE
  _retVal := CheckUnitDone(
    Wp100K102PressingCylinder.Unit,
    RepeatOnError := TRUE
  );
END_IF
