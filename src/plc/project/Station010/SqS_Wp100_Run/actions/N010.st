// The requested fixture position is valid only when exactly its own sensor is
// active. A move prompt is released only while the door and press are safe.
_retVal := RUNNING;

CASE MeasurePos OF
  MeasurePsoEnum.LEFT:
    _positionValid := ( Peripherals.BinIo._100B601 ) AND
                      ( NOT Peripherals.BinIo._100B602 ) AND
                      ( NOT Peripherals.BinIo._100B603 );

  MeasurePsoEnum.MIDDLE:
    _positionValid := ( NOT Peripherals.BinIo._100B601 ) AND
                      ( Peripherals.BinIo._100B602 ) AND
                      ( NOT Peripherals.BinIo._100B603 );

  MeasurePsoEnum.RIGHT:
    _positionValid := ( NOT Peripherals.BinIo._100B601 ) AND
                      ( NOT Peripherals.BinIo._100B602 ) AND
                      ( Peripherals.BinIo._100B603 );

  ELSE
    _positionValid := FALSE;
END_CASE

Result.FixturePositionValid := _positionValid;

IF ( Wp100K101SafetyDoor.Unit.OutImm.IsInBasPos ) AND
   ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos )
THEN
  CASE MeasurePos OF
    MeasurePsoEnum.LEFT:
      Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MOVE_FIXTURE_LEFT;

    MeasurePsoEnum.MIDDLE:
      Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MOVE_FIXTURE_MIDDLE;

    MeasurePsoEnum.RIGHT:
      Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MOVE_FIXTURE_RIGHT;

    ELSE
      Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_TEXT_CLEAR;
  END_CASE

  IF ( _positionValid )
  THEN
    _retVal := OK;
  END_IF
ELSE
  Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_RETURN_SAFE_POSITION;
END_IF
