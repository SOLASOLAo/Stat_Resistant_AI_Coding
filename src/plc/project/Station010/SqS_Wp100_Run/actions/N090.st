// Wait for SINGLE_MEAS and copy the command result exactly once on DONE.
// Force loss wins over completion in the same PLC scan. A fault never resumes.
IF ( Result.Resistance.Valid )
THEN
  // Acceptance was already latched; normal unloading must not regrade it.
  _retVal := OK;
  RETURN;
END_IF
_retVal := CheckPressForce(Phase := 3);
IF ( _retVal <> OK )
THEN
  RETURN;
END_IF

IF ( NOT _bursterStarted )
THEN
  _retVal := RUNNING;
ELSE
  _unitResult := CheckUnitDone(
    Wp100A103ResistantDetector.Unit,
    RepeatOnError := FALSE
  );
  _retVal := _unitResult;

  IF ( _unitResult = OK ) AND
     ( NOT Result.Resistance.Valid )
  THEN
    Result.Resistance.Valid      := TRUE;
    Result.Resistance.OutOfLimit :=
      Wp100A103ResistantDetector.Unit.OutCmd.OutOfLimit;
    Result.Resistance.Value      :=
      Wp100A103ResistantDetector.Unit.OutCmd.Resistance;
    Result.Resistance.Temperature :=
      Wp100A103ResistantDetector.Unit.OutCmd.Temperature;

    // Grade once in Ohm, using this command's TypeData limits copied in N080.
    // OutOfLimit is an instrument range fault, separate from product tolerance.
    Result.Resistance.Ok :=
      ( NOT Result.Resistance.OutOfLimit ) AND
      ( Result.Resistance.Value >= Wp100A103ResistantDetector.Unit.ParCmd.LowerLimit ) AND
      ( Result.Resistance.Value <= Wp100A103ResistantDetector.Unit.ParCmd.UpperLimit );
    Station.ForceTraceAddon.Recorder.FreezeStatistics();
  END_IF
END_IF
