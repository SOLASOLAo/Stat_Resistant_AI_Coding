// Wait for SINGLE_MEAS and copy the command result exactly once on DONE.
// Force loss wins over completion in the same PLC scan. A fault never resumes.
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

  IF ( _unitResult = OK )
  THEN
    Result.Resistance.Valid      := TRUE;
    Result.Resistance.OutOfLimit :=
      Wp100A103ResistantDetector.Unit.OutCmd.OutOfLimit;
    Result.Resistance.Ok         :=
      Wp100A103ResistantDetector.Unit.OutCmd.ResistOk;
    Result.Resistance.Value      :=
      Wp100A103ResistantDetector.Unit.OutCmd.Resistance;
    Result.Resistance.Temperature :=
      Wp100A103ResistantDetector.Unit.OutCmd.Temperature;
  END_IF
END_IF
