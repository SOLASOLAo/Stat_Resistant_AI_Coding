// N045 selected the instrument program; that program owns the measuring range.
// The single owner has no AutoRange override. Require its verified live
// connection/program, not only the standard Unit's cached READY state.
_retVal := RUNNING;

IF ( AiWp100.Burster.Connected ) AND
   ( AiWp100.Burster.SelectionVerified ) AND
   ( AiWp100.Burster.SelectedProgram = Station.TypeData.Wp100.Burster.ProgramNo ) AND
   ( AiWp100.Burster.Operation = 0 ) AND
   ( AiWp100.Burster.ErrorCode = 0 )
THEN
  _retVal := OK;
END_IF
