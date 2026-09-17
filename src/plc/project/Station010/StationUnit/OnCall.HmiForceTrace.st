// AI_HMI_FORCE_TRACE_BEGIN
// The native Add-on records once in OnCallEnter, immediately after this hook.
Station.ForceTraceMeasuring := Wp100A104Kistler.Unit.OutImm.MeasRunning;
Station.ForceTraceQualityGood :=
  ( Peripherals._000SA620_X1.BusInfo.BusOk ) AND
  ( UnitState = OpconUnitState.OPERATIONAL ) AND
  ( NOT Wp100A104Kistler.Unit.OutImm.Alarm ) AND
  ( Wp100A104Kistler.Unit.ExecState <> OpconExecState.ERROR );
// AI_HMI_FORCE_TRACE_END
