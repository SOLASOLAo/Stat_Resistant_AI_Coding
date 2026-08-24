// Ask for the right fixture position only after both moving axes are safe.
_retVal := RUNNING;

IF ( Wp100K101SafetyDoor.Unit.OutImm.IsInBasPos ) AND
   ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos )
THEN
  Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MOVE_FIXTURE_RIGHT;

  IF ( NOT Peripherals.BinIo._100B601 ) AND
     ( NOT Peripherals.BinIo._100B602 ) AND
     ( Peripherals.BinIo._100B603 )
  THEN
    // Recheck both product sensors after the operator has moved the fixture.
    // This is the final release immediately before starting SqS_Wp100_Run.
    _retVal := CheckPartPresent();

    IF ( _retVal <> OK )
    THEN
      Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_LOAD_PART;
    END_IF
  END_IF
ELSE
  Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_RETURN_SAFE_POSITION;
END_IF
