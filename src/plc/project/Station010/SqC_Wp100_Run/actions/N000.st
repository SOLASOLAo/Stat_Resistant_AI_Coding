// Initialize the three-position measurement sequence.
OpconMemSet(ADR(Result), 0, SIZEOF(Result));
// AI_HMI_FORCE_TRACE_BEGIN
Station.ForceTraceAddon.Recorder.BeginCycle();
// AI_HMI_FORCE_TRACE_END

Wp100.SqS_Run.Execute := FALSE;
_partSensorFaultMask  := 0;
Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_TEXT_CLEAR;

_retVal := OK;
