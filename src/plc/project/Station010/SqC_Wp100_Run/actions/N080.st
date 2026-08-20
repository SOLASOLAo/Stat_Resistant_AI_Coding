// Reuse the same atomic operation for the right fixture position.
IF Wp100.SqS_Run.ExecState = OpconExecState.READY
THEN
  Wp100.SqS_Run.MeasurePos := MeasurePsoEnum.RIGHT;
  Wp100.SqS_Run.Execute    := TRUE;
  _retVal                  := OK;
END_IF
