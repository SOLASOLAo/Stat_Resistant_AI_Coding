// Wait for the middle atomic operation and retain its result before reuse.
_retVal := CheckSubChainDone(Wp100.SqS_Run);

IF _retVal = OK
THEN
  Result.Middle := Wp100.SqS_Run.Result;
END_IF
