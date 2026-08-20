// Door motion is complete only after the closed-position signal and both
// safety-circuit feedback signals have been confirmed.
IF ( _safetyDoorCloseStarted )
THEN
  _unitResult := CheckUnitDone(
    Wp100K101SafetyDoor.Unit,
    RepeatOnError := TRUE
  );
ELSE
  _unitResult := OK;
END_IF

IF ( _unitResult <> OK )
THEN
  _retVal := _unitResult;
ELSIF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos ) AND
      ( Peripherals.BinIo._000K913_Y32 ) AND
      ( Peripherals.BinIo._000K912_Y32 )
THEN
  _retVal := OK;
END_IF
