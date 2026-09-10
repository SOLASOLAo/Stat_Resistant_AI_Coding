/// Select the configured MP before requiring the instrument's measuring-ready bit.
METHOD PROTECTED CheckKistlerProgram : DINT
VAR_INPUT
  Reset : BOOL;
END_VAR
VAR_INST
  _started : BOOL;
  _done : BOOL;
  _programNo : BYTE;
END_VAR
VAR
  commandResult : DINT;
END_VAR

CheckKistlerProgram := RUNNING;

IF ( Reset )
THEN
  // Unit cancellation is owned by OnChainFinish, not this state reset.
  _started := FALSE;
  _done := FALSE;
  _programNo := 0;
  CheckKistlerProgram := OK;
  RETURN;
END_IF

IF ( NOT _started )
THEN
  IF ( Wp100A104Kistler.Unit.ExecState = OpconExecState.READY ) AND
     ( NOT Wp100A104Kistler.Unit.Execute ) AND
     ( NOT Wp100A104Kistler.Unit.OutImm.MeasRunning )
  THEN
    _programNo := Station.TypeData.Wp100.KistlerProgramNo;
    Wp100A104Kistler.Unit.ParCmd.SetProgram.ProgNo := _programNo;
    // Stage both automatic command parameters before either command can run.
    Wp100A104Kistler.Unit.ParCmd.Measure.ProgNo := _programNo;
    _started := TRUE;

    IF ( Wp100A104Kistler.Unit.OutImm.ProgNo = _programNo ) AND
       ( Wp100A104Kistler.Unit.OutImm.Ready ) AND
       ( NOT Wp100A104Kistler.Unit.OutImm.Alarm )
    THEN
      // Already selected and healthy: no needless Auto/program handshake.
      // Recheck every completion guard below on the next scan.
      _done := TRUE;
    ELSE
      // A different/unready MP still needs the standard command and its ACK.
      // Never manufacture Ready or clear an instrument alarm here.
      Wp100A104Kistler.Unit.Command := KistlerForceStrokeCmd.SET_PROGRAM;
      Wp100A104Kistler.Unit.Execute := TRUE;
    END_IF
  END_IF
  RETURN;
END_IF

IF ( NOT _done )
THEN
  commandResult := CheckUnitDone(
    Wp100A104Kistler.Unit,
    RepeatOnError := FALSE
  );
  IF ( commandResult <> OK )
  THEN
    CheckKistlerProgram := commandResult;
    RETURN;
  END_IF
  // Do not call CheckUnitDone again in READY: it would reissue the command.
  _done := TRUE;
END_IF

IF ( Wp100A104Kistler.Unit.ExecState = OpconExecState.READY ) AND
   ( NOT Wp100A104Kistler.Unit.Execute ) AND
   ( Wp100A104Kistler.Unit.OutImm.ProgNo = _programNo ) AND
   ( Station.TypeData.Wp100.KistlerProgramNo = _programNo ) AND
   ( Wp100A104Kistler.Unit.OutImm.Ready ) AND
   ( NOT Wp100A104Kistler.Unit.OutImm.Alarm ) AND
   ( NOT Wp100A104Kistler.Unit.OutImm.MeasRunning )
THEN
  CheckKistlerProgram := OK;
END_IF
