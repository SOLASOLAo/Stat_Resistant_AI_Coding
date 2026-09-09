// N045 selected the instrument program; that program owns the measuring range.
// CpStudio Peripheral AutoRange must be FALSE so SINGLE_MEAS preserves it.
// Wait here if the generated configuration still enables the driver override.
_retVal := RUNNING;

IF ( NOT Peripherals._Wp100A103ResistantInterface.ParCfg.UseAutoRange )
THEN
  _retVal := OK;
END_IF
