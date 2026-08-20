// Wait for the right atomic operation and retain its result before reuse.
_retVal := CheckSubChainDone(Wp100.SqS_Run);

IF ( _retVal = OK )
THEN
  Result.Right := Wp100.SqS_Run.Result;
END_IF
