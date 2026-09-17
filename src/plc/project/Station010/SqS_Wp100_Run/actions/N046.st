// N045 selected the instrument program; that program owns the measuring range.
// The single owner has no AutoRange override. Require its verified live
// connection/program, not only the standard Unit's cached READY state.
_retVal := RUNNING;

IF ( Peripherals._Burster2316.Connected ) AND
   ( Peripherals._Burster2316.SelectionVerified ) AND
   ( Peripherals._Burster2316.SelectedProgram = Station.TypeData.Wp100.Burster.ProgramNo ) AND
   ( Peripherals._Burster2316.Operation = 0 ) AND
   ( Peripherals._Burster2316.ErrorCode = 0 )
THEN
  _retVal := OK;
END_IF
