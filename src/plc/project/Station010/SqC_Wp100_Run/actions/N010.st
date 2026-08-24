// A product must cover both fixture sensors before the left measurement.
_retVal := CheckPartPresent();

IF ( NOT Peripherals.BinIo._100B701 ) OR
   ( NOT Peripherals.BinIo._100B702 )
THEN
  Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_LOAD_PART;
END_IF
