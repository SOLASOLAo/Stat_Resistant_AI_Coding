// Branch 1 waits for Kistler OPERATE/START before applying any press load.
_retVal := RUNNING;

IF ( _pressDownStarted )
THEN
  _retVal := OK;

ELSIF ( Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPosIn ) AND
      ( Peripherals.BinIo._000K913_Y32 ) AND
      ( Peripherals.BinIo._000K912_Y32 ) AND
      ( _kistlerStarted ) AND
      ( Wp100A104Kistler.Unit.OutImm.MeasRunning ) AND
      ( Wp100A104Kistler.Unit.ExecState <> OpconExecState.ERROR ) AND
      ( NOT Wp100A104Kistler.Unit.OutImm.Alarm ) AND
      ( Wp100A104Kistler.Unit.OutImm.ProgNo = Station.TypeData.Wp100.KistlerProgramNo ) AND
      ( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPosIn ) AND
      ( Wp100K102PressingCylinder.Unit.ExecState = OpconExecState.READY )
THEN
  // AI_HMI_FORCE_TRACE_BEGIN
  // Latch PLC elapsed-time origin and force after Kistler acknowledgement.
  CASE MeasurePos OF
    MeasurePsoEnum.LEFT:
      Station.ForceTraceAddon.Recorder.Start(Position := 1,
        InitialForceN := Wp100A104Kistler.Unit.OutImm.ForceAct);
    MeasurePsoEnum.MIDDLE:
      Station.ForceTraceAddon.Recorder.Start(Position := 2,
        InitialForceN := Wp100A104Kistler.Unit.OutImm.ForceAct);
    MeasurePsoEnum.RIGHT:
      Station.ForceTraceAddon.Recorder.Start(Position := 3,
        InitialForceN := Wp100A104Kistler.Unit.OutImm.ForceAct);
  END_CASE
  // AI_HMI_FORCE_TRACE_END
  Wp100K102PressingCylinder.Unit.ParCmd.PreStartCheck :=
    ( Station.Unit.ModeSet <> StationMode.HOME );
  Wp100K102PressingCylinder.Unit.ParCmd.OutputPulsing :=
    ( Station.Unit.ModeSet = StationMode.HOME );
  Wp100K102PressingCylinder.Unit.Command := BasMoveCmd.WRKPOS;
  Wp100K102PressingCylinder.Unit.Execute := TRUE;

  _pressDownStarted := TRUE;
  _retVal := OK;
END_IF
