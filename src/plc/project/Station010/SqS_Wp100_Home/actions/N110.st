// If the pressing cylinder is not in base position, first close the
// safety door (work position). If either condition is already fulfilled,
// this command is skipped.
IF ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPosIn ) OR
   ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPosIn )
THEN
  _safetyDoorCloseStarted := FALSE;
  _retVal := OK;

ELSIF ( Wp100K101SafetyDoor.Unit.ExecState = OpconExecState.READY ) AND
      ( _env.StepPulse )
THEN
  Wp100K101SafetyDoor.Unit.ParCmd.PreStartCheck :=
    ( Station.Unit.ModeSet <> StationMode.HOME );
  Wp100K101SafetyDoor.Unit.ParCmd.OutputPulsing :=
    ( Station.Unit.ModeSet = StationMode.HOME );

  Wp100K101SafetyDoor.Unit.Command := BasMoveCmd.WRKPOS;
  Wp100K101SafetyDoor.Unit.Execute := TRUE;

  _safetyDoorCloseStarted := TRUE;
  _retVal := OK;
END_IF
