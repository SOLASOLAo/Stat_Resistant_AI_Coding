// Release both parallel start branches only from one common machine state.
// _retVal2 belongs to the second SFC branch defined by OpconSfcChain.
_retVal  := RUNNING;
_retVal2 := RUNNING;

IF Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos
   AND Peripherals.BinIo._000K913_Y32
   AND Peripherals.BinIo._000K912_Y32
   AND Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos
   AND (Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY)
   AND (Wp100A104Kistler.Unit.ExecState = OpconExecState.READY)
   AND Wp100A104Kistler.Unit.OutImm.Ready
THEN
  _retVal := OK;
END_IF
