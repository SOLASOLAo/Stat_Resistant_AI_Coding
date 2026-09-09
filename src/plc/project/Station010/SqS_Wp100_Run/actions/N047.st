// No range command was issued. Do not wait for a nonexistent command's DONE.
// Keep the existing step number and verify readiness before either start branch.
_retVal := RUNNING;

IF ( Wp100A103ResistantDetector.Unit.ExecState = OpconExecState.READY ) AND
   ( NOT Wp100A103ResistantDetector.Unit.Execute )
THEN
  _retVal := OK;
END_IF
