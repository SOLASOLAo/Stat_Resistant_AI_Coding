// Reuse the same atomic operation for the middle fixture position.
IF Wp100.SqS_Run.ExecState = OpconExecState.READY
THEN
  Wp100.SqS_Run.MeasurePos := MeasurePsoEnum.MIDDLE;
  Wp100.SqS_Run.Execute    := TRUE;
  _retVal                  := OK;
END_IF
