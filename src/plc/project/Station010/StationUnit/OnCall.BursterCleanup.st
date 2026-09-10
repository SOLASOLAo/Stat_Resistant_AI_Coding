// AI_BURSTER_CANCEL_CLEANUP_BEGIN
// OnChainFinish runs once. Continue only an already requested cancellation;
// never start a program selection, measurement or motion from this hook.
IF ( NOT AiWp100.BursterProgramSelect.Execute ) AND
   ( AiWp100.BursterProgramSelect.Busy )
THEN
  AiWp100.BursterProgramSelect();
END_IF
// AI_BURSTER_CANCEL_CLEANUP_END
