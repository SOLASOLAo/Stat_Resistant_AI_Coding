// Release both parallel start branches only after the selected Burster program
// has been acknowledged by the instrument.
// _retVal2 belongs to the second SFC branch defined by OpconSfcChain.
_retVal  := RUNNING;
_retVal2 := RUNNING;

CASE MeasurePos OF
  MeasurePsoEnum.LEFT:
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MEASURING_LEFT;

  MeasurePsoEnum.MIDDLE:
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MEASURING_MIDDLE;

  MeasurePsoEnum.RIGHT:
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_MEASURING_RIGHT;

  ELSE
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_TEXT_CLEAR;
END_CASE

IF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos ) AND
   ( Peripherals.BinIo._000K913_Y32 ) AND
   ( Peripherals.BinIo._000K912_Y32 ) AND
   ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos ) AND
   ( Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY ) AND
   ( Wp100A103ResistantDetector.Unit.ExecState = OpconExecState.READY ) AND
   ( Wp100A104Kistler.Unit.ExecState = OpconExecState.READY ) AND
   ( Wp100A104Kistler.Unit.OutImm.Ready )
THEN
  AiWp100.BursterProgramSelect(
    Execute := TRUE,
    ProgramNo := Station.TypeData.Wp100.Burster.ProgramNo
  );

  IF ( AiWp100.BursterProgramSelect.Done )
  THEN
    _retVal  := OK;
    _retVal2 := OK;
  ELSIF ( AiWp100.BursterProgramSelect.Error )
  THEN
    _retVal  := HAS_ERROR;
    _retVal2 := HAS_ERROR;
  END_IF
ELSE
  AiWp100.BursterProgramSelect(
    Execute := FALSE,
    ProgramNo := 0
  );
END_IF
