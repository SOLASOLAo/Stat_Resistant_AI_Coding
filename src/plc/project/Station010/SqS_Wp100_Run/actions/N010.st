// The requested fixture position is valid only when exactly its own sensor is
// active. The pressing cylinder must also be in its safe/base position.
CASE MeasurePos OF
  MeasurePsoEnum.LEFT:
    _positionValid := Peripherals.BinIo._100B601
                      AND NOT Peripherals.BinIo._100B602
                      AND NOT Peripherals.BinIo._100B603;

  MeasurePsoEnum.MIDDLE:
    _positionValid := NOT Peripherals.BinIo._100B601
                      AND Peripherals.BinIo._100B602
                      AND NOT Peripherals.BinIo._100B603;

  MeasurePsoEnum.RIGHT:
    _positionValid := NOT Peripherals.BinIo._100B601
                      AND NOT Peripherals.BinIo._100B602
                      AND Peripherals.BinIo._100B603;
END_CASE

Result.FixturePositionValid := _positionValid;

IF _positionValid
   AND Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos
THEN
  _retVal := OK;
END_IF
