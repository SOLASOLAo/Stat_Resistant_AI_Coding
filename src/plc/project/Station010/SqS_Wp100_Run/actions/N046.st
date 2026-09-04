// Apply the active product's Burster range before motion starts.
_retVal := RUNNING;

IF ( Wp100A103ResistantDetector.Unit.ExecState = OpconExecState.READY )
THEN
  Wp100A103ResistantDetector.Unit.ParCmd.UpperRange :=
    TO_INT(
      Station.TypeData.Wp100.Burster.UpperRange
    );
  Wp100A103ResistantDetector.Unit.ParCmd.LowerRange :=
    TO_INT(
      Station.TypeData.Wp100.Burster.LowerRange
    );

  Wp100A103ResistantDetector.Unit.Command :=
    BursterResis2316Cmd.SET_RANGE;
  Wp100A103ResistantDetector.Unit.Execute := TRUE;

  _retVal := OK;
END_IF
