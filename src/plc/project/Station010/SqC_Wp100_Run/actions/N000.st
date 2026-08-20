// Initialize the three-position measurement sequence.
OpconMemSet(ADR(Result), 0, SIZEOF(Result));

Wp100.SqS_Run.Execute := FALSE;
_partSensorFaultMask  := 0;

_retVal := OK;
