/// v1.0.0 - One-position force qualification and latched measurement interlock.
METHOD PROTECTED CheckPressForce : DINT
VAR_INPUT
  /// 0 = reset at chain boundary; 1 = preflight; 2 = qualify; 3 = measuring
  Phase : USINT;
END_VAR
VAR_INST
  _waitLimit : TON;
  _timeoutMs : DINT;
  _fault : BOOL;
  _eventIndex : UDINT;
  _reason : STRING(24);
  _additionalInfo : STRING(63);
END_VAR
VAR
  forceN : REAL;
  forceAboveLimit : BOOL;
END_VAR

CheckPressForce := RUNNING;

IF ( Phase = 0 )
THEN
  _waitLimit(IN := FALSE, PT := T#0MS);
  _pressDelay(IN := FALSE, PT := T#0MS);
  IF ( _eventIndex <> 0 )
  THEN
    IF ( NOT UnlockEvent(Class := OpconEventClass.SOFTERROR, Index := _eventIndex) )
    THEN
      RETURN;
    END_IF
    IF ( NOT ClearEvent(Class := OpconEventClass.SOFTERROR, Index := _eventIndex) )
    THEN
      RETURN;
    END_IF
  END_IF
  _eventIndex := 0;
  _fault := FALSE;
  _reason := '';
  _additionalInfo := '';
  // Freeze the active dataset value for this position, not the shadow dataset.
  _timeoutMs := Station.StationData.PressForceTimeout;
  CheckPressForce := OK;
  RETURN;
END_IF

forceN := Wp100A104Kistler.Unit.OutImm.ForceAct;
forceAboveLimit := ( forceN > REAL#2500.0 );

IF ( NOT _fault )
THEN
  IF ( Phase = 1 )
  THEN
    // Operator/fixture waiting can precede this call. Latch at Kistler start.
    _timeoutMs := Station.StationData.PressForceTimeout;
  END_IF
  IF ( _timeoutMs <= 2000 )
  THEN
    _reason := 'INVALID_TIMEOUT_MS';
  ELSIF ( Phase = 1 )
  THEN
    // Preflight runs before Kistler START; it does not require MeasRunning.
    CheckPressForce := OK;
    RETURN;
  ELSIF ( NOT Wp100A104Kistler.Unit.OutImm.MeasRunning ) OR
        ( Wp100A104Kistler.Unit.ExecState = OpconExecState.ERROR ) OR
        ( Wp100A104Kistler.Unit.OutImm.Alarm ) OR
        ( NOT ( forceN = forceN ) ) OR
        ( ABS(forceN) > REAL#3.402823E38 )
  THEN
    _reason := 'FORCE_DATA_INVALID';
  ELSIF ( NOT Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPosIn )
  THEN
    _reason := 'PRESS_POSITION_LOST';
  ELSIF ( Phase = 2 )
  THEN
    // Total wait never restarts on force bounce; only the 2 s TON restarts.
    _waitLimit(IN := TRUE, PT := DINT_TO_TIME(_timeoutMs));
    _pressDelay(IN := forceAboveLimit, PT := T#2S);
    IF ( _waitLimit.Q ) AND
       ( NOT _pressDelay.Q )
    THEN
      _reason := 'FORCE_WAIT_TIMEOUT';
    ELSIF ( _pressDelay.Q )
    THEN
      CheckPressForce := OK;
    END_IF
  ELSIF ( Phase = 3 )
  THEN
    // No debounce here: <=2500 N invalidates the current resistance result.
    _waitLimit(IN := FALSE, PT := T#0MS);
    _pressDelay(IN := FALSE, PT := T#0MS);
    IF ( NOT forceAboveLimit )
    THEN
      _reason := 'FORCE_LOST_DURING_MEAS';
    ELSE
      CheckPressForce := OK;
    END_IF
  ELSE
    _reason := 'INVALID_FORCE_PHASE';
  END_IF

  IF ( _reason <> '' )
  THEN
    _fault := TRUE;
    CASE Result.MeasurePos OF
      MeasurePsoEnum.LEFT:   _additionalInfo := 'LEFT ';
      MeasurePsoEnum.MIDDLE: _additionalInfo := 'MIDDLE ';
      MeasurePsoEnum.RIGHT:  _additionalInfo := 'RIGHT ';
    ELSE
      _additionalInfo := 'UNKNOWN_POS ';
    END_CASE
    _additionalInfo := CONCAT(_additionalInfo, _reason);
    _additionalInfo := CONCAT(_additionalInfo, ' F=');
    _additionalInfo := CONCAT(_additionalInfo, REAL_TO_STRING(forceN));
    _additionalInfo := CONCAT(_additionalInfo, ' N');
  END_IF
END_IF

IF ( _fault )
THEN
  CheckPressForce := RUNNING;
  Result.Resistance.Valid := FALSE;
  Result.Resistance.Ok := FALSE;
  Result.Kistler.Valid := FALSE;
  Result.Kistler.Ok := FALSE;

  // Finish/cancel instruments while holding the SFC; NEVER request BASPOS here.
  // Standard safety, ControlOn and device-error handling remain authoritative.
  Wp100A103ResistantDetector.Unit.Execute := FALSE;
  Wp100A104Kistler.Unit.ParImm.EndMeasurement := TRUE;
  IF ( Wp100A104Kistler.Unit.ExecState = OpconExecState.DONE ) OR
     ( Wp100A104Kistler.Unit.ExecState = OpconExecState.ERROR ) OR
     ( Wp100A104Kistler.Unit.ExecState = OpconExecState.READY )
  THEN
    Wp100A104Kistler.Unit.Execute := FALSE;
  END_IF
  IF ( _eventIndex = 0 )
  THEN
    _eventIndex := SetEvent(
      OpconEventClass.SOFTERROR,
      Wp100.EVENT_PRESS_FORCE_INVALID,
      _additionalInfo,
      Lock := TRUE
    );
  END_IF
END_IF
