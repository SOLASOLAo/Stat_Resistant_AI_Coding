// Wait for SET_RANGE and release Execute before the next Burster command.
_unitResult := CheckUnitDone(
  Wp100A103ResistantDetector.Unit,
  RepeatOnError := FALSE
);
_retVal := _unitResult;

IF ( _unitResult = OK )
THEN
  Wp100A103ResistantDetector.Unit.Execute := FALSE;
END_IF
