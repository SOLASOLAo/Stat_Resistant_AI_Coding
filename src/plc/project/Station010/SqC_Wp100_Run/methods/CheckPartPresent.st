/// Checks both fixture product-detection signals and manages one detailed,
/// locked soft error while the product is incomplete or absent.
METHOD PROTECTED CheckPartPresent : DINT
VAR
  missingMask : BYTE;
END_VAR

CheckPartPresent := RUNNING;
missingMask      := 0;

IF ( NOT Peripherals.BinIo._100B701 )
THEN
  missingMask := missingMask + 1;
END_IF

IF ( NOT Peripherals.BinIo._100B702 )
THEN
  missingMask := missingMask + 2;
END_IF

IF ( missingMask = 0 )
THEN
  // Do not release the SFC step until the previous locked event is removed.
  IF ( _eventIndex = 0 )
  THEN
    _partSensorFaultMask := 0;
    CheckPartPresent     := OK;
  ELSIF ( UnlockEvent(
          Class := OpconEventClass.SOFTERROR,
          Index := _eventIndex
        ) )
  THEN
    IF ( ClearEvent(
         Class := OpconEventClass.SOFTERROR,
         Index := _eventIndex
       ) )
    THEN
      _eventIndex          := 0;
      _partSensorFaultMask := 0;
      CheckPartPresent     := OK;
    END_IF
  END_IF
ELSE
  // If the failed combination changes, replace the event so AdditionalInfo
  // always identifies the signal state currently blocking the measurement.
  IF ( _eventIndex <> 0 ) AND
     ( _partSensorFaultMask <> missingMask )
  THEN
    IF ( UnlockEvent(
         Class := OpconEventClass.SOFTERROR,
         Index := _eventIndex
       ) )
    THEN
      IF ( ClearEvent(
           Class := OpconEventClass.SOFTERROR,
           Index := _eventIndex
         ) )
      THEN
        _eventIndex := 0;
      END_IF
    END_IF
  END_IF

  IF ( _eventIndex = 0 )
  THEN
    CASE missingMask OF
      1:
        _eventIndex := SetEvent(
          OpconEventClass.SOFTERROR,
          Wp100.EVENT_PART_DETECT_SENSOR,
          '_100B701=FALSE: fixture product-detect sensor 1 is missing',
          Lock := TRUE
        );

      2:
        _eventIndex := SetEvent(
          OpconEventClass.SOFTERROR,
          Wp100.EVENT_PART_DETECT_SENSOR,
          '_100B702=FALSE: fixture product-detect sensor 2 is missing',
          Lock := TRUE
        );

      3:
        _eventIndex := SetEvent(
          OpconEventClass.SOFTERROR,
          Wp100.EVENT_PART_DETECT_SENSOR,
          '_100B701=FALSE; _100B702=FALSE: both fixture sensors missing',
          Lock := TRUE
        );
    END_CASE

    IF ( _eventIndex <> 0 )
    THEN
      _partSensorFaultMask := missingMask;
    END_IF
  END_IF
END_IF
