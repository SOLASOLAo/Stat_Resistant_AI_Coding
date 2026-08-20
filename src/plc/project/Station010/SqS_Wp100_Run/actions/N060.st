// Wait until the pressing cylinder reaches work/down position.
IF NOT _pressDownStarted
THEN
  _retVal := OK;
ELSE
  _retVal := CheckUnitDone(
    Wp100K102PressingCylinder.Unit,
    RepeatOnError := TRUE
  );
END_IF
