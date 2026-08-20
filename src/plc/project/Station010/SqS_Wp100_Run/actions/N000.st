// Initialize one execution and retain no result from the previous part.
OpconMemSet(ADR(Result), 0, SIZEOF(Result));

Result.MeasurePos        := MeasurePos;
_positionValid           := FALSE;
_safetyDoorCloseStarted  := FALSE;
_pressDownStarted        := FALSE;
_kistlerStarted          := FALSE;
_kistlerStopRequested    := FALSE;
_bursterStarted          := FALSE;
_pressUpStarted          := FALSE;
_safetyDoorOpenStarted   := FALSE;
_unitResult              := 0;
_pressDelay(IN := FALSE, PT := T#0MS);

_retVal := OK;
