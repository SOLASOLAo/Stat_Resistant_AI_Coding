// Start the reusable atomic operation for the left fixture position.
IF ( Wp100.SqS_Run.ExecState = OpconExecState.READY )
THEN
  Wp100.SqS_Run.MeasurePos := MeasurePsoEnum.LEFT;
  Wp100.SqS_Run.Execute    := TRUE;
  _retVal                  := OK;
END_IF
