/// v2.0.0 - PLC rolling 3-sigma qualification and latched measurement interlock.
METHOD PROTECTED CheckPressForce : DINT
VAR_INPUT
  /// 0 = reset at chain boundary; 1 = preflight; 2 = qualify; 3 = measuring
  Phase : USINT;
END_VAR
VAR_INST
  _waitLimit : TON;
  _timeoutMs : DINT;
  _stableMs : DINT;
  _thresholdN : REAL;
  _sigmaLimitN : REAL;
  _samplePeriodMs : DINT;
  _latched : BOOL;
  _fault : BOOL;
  _eventIndex : UDINT;
  _reason : STRING(24);
  _additionalInfo : STRING(63);
END_VAR
VAR
  forceN : REAL;
  forceAboveLimit : BOOL;
  qualified : BOOL;
  dataHealthy : BOOL;
END_VAR

CheckPressForce := RUNNING;

IF ( Phase = 0 )
THEN
  _waitLimit(IN := FALSE, PT := T#0MS);
  _pressDelay(IN := FALSE, PT := T#0MS);
  IF ( _eventIndex <> 0 )
  THEN
    // Cleanup is not a command-completion handshake: FALSE can mean an old
    // handle is already invalid. Always attempt both operations, then release
    // this execution's handle. An unlocked pending event remains acknowledgeable.
    UnlockEvent(Class := OpconEventClass.SOFTERROR, Index := _eventIndex);
    ClearEvent(Class := OpconEventClass.SOFTERROR, Index := _eventIndex);
  END_IF
  _eventIndex := 0;
  _fault := FALSE;
  _latched := FALSE;
  _reason := '';
  _additionalInfo := '';
  // Parameters are latched at preflight, after native references are configured.
  _timeoutMs := 0;
  _stableMs := 0;
  CheckPressForce := OK;
  RETURN;
END_IF

forceN := 0;
IF ( Station.ForceTraceAddon.Configured )
THEN
  forceN := Station.ForceTraceAddon.ParCfg.rForceN;
END_IF
forceAboveLimit := ( forceN > _thresholdN );
dataHealthy := ( Peripherals._000SA620_X1.BusInfo.BusOk ) AND
               ( Station.Unit.UnitState = OpconUnitState.OPERATIONAL ) AND
               ( Wp100A104Kistler.Unit.OutImm.MeasRunning ) AND
               ( Wp100A104Kistler.Unit.ExecState <> OpconExecState.ERROR ) AND
               ( NOT Wp100A104Kistler.Unit.OutImm.Alarm ) AND
               ( forceN = forceN ) AND ( ABS(forceN) <= REAL#3.402823E38 );

IF ( NOT _fault )
THEN
  IF ( Phase = 1 ) AND ( NOT _latched )
  THEN
    // Operator/fixture waiting can precede this call. Latch at Kistler start.
    IF ( Station.ForceTraceAddon.Configured )
    THEN
      _timeoutMs := Station.ForceTraceAddon.ParCfg.rTimeoutMs;
      _stableMs := Station.ForceTraceAddon.ParCfg.rWindowMs;
      _thresholdN := Station.ForceTraceAddon.ParCfg.rThresholdN;
      _sigmaLimitN := Station.ForceTraceAddon.ParCfg.rLimitN;
      _samplePeriodMs := Station.ForceTraceAddon.ParCfg.SamplePeriodMs;
      _latched := TRUE;
    END_IF
  END_IF
  IF ( NOT Station.ForceTraceAddon.Configured ) OR ( NOT _latched )
  THEN
    _reason := 'FORCE_NOT_CONFIGURED';
  ELSIF ( _stableMs <= 0 ) OR ( _stableMs > 60000 )
  THEN
    _reason := 'INVALID_STABLE_MS';
  ELSIF ( _timeoutMs <= _stableMs )
  THEN
    _reason := 'INVALID_TIMEOUT_MS';
  ELSIF ( NOT ( _thresholdN >= 0 ) ) OR ( _thresholdN > REAL#3.402823E38 )
  THEN
    _reason := 'INVALID_FORCE_THRESHOLD';
  ELSIF ( NOT ( _sigmaLimitN > 0 ) ) OR ( _sigmaLimitN > REAL#3.402823E38 )
  THEN
    _reason := 'INVALID_3SIGMA_LIMIT';
  ELSIF ( _samplePeriodMs < 1 ) OR ( _samplePeriodMs > 1000 )
  THEN
    _reason := 'INVALID_SAMPLE_PERIOD';
  ELSIF ( _stableMs > _samplePeriodMs * 10000 )
  THEN
    _reason := 'STAT_WINDOW_CAPACITY';
  ELSIF ( Phase = 1 )
  THEN
    // Preflight does not require MeasRunning. Values were latched only once.
    Station.ForceTraceAddon.Recorder.Configure(ThresholdN := _thresholdN, LimitN := _sigmaLimitN,
      WindowMs := DINT_TO_UDINT(_stableMs), TimeoutMs := DINT_TO_UDINT(_timeoutMs),
      SamplePeriodMs := DINT_TO_UDINT(_samplePeriodMs));
    CheckPressForce := OK;
    RETURN;
  ELSIF ( NOT dataHealthy )
  THEN
    _reason := 'FORCE_DATA_INVALID';
  ELSIF ( NOT Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPosIn )
  THEN
    _reason := 'PRESS_POSITION_LOST';
  ELSIF ( Phase = 2 ) OR ( Phase = 3 )
  THEN
    qualified := Station.ForceTraceAddon.Recorder.Evaluate(ValueN := forceN,
      Healthy := dataHealthy, AtWork := Wp100K102PressingCylinder.Unit.OutImm.IsInWrkPosIn);
    IF ( NOT Station.ForceTraceAddon.Recorder.DataGood )
    THEN
      _reason := 'FORCE_SAMPLE_INVALID';
    ELSIF ( Phase = 2 )
    THEN
      // Force bounce resets the statistical window, never the total timeout.
      _waitLimit(IN := TRUE, PT := DINT_TO_TIME(_timeoutMs));
      IF ( _waitLimit.Q )
      THEN
        _reason := 'FORCE_WAIT_TIMEOUT';
      ELSIF ( qualified )
      THEN
        CheckPressForce := OK;
      END_IF
    ELSIF ( NOT forceAboveLimit )
    THEN
      _reason := 'FORCE_LOST_DURING_MEAS';
    ELSIF ( NOT qualified )
    THEN
      _reason := 'FORCE_3SIGMA_UNSTABLE';
    ELSE
      _waitLimit(IN := FALSE, PT := T#0MS);
      CheckPressForce := OK;
    END_IF
  ELSE
    _reason := 'INVALID_FORCE_PHASE';
  END_IF

  IF ( _reason <> '' )
  THEN
    _fault := TRUE;
    // AI_HMI_FORCE_TRACE_BEGIN
    IF ( _reason = 'FORCE_DATA_INVALID' ) OR ( _reason = 'FORCE_SAMPLE_INVALID' )
    THEN
      Station.ForceTraceAddon.Recorder.Finish(Reason := 5, LastForceN := forceN);
    ELSE
      Station.ForceTraceAddon.Recorder.Finish(Reason := 4, LastForceN := forceN);
    END_IF
    // AI_HMI_FORCE_TRACE_END
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
  // Clear the request once measurement stops, including during a fault hold.
  // Preflight failures must not request END before START has been accepted.
  Wp100A104Kistler.Unit.ParImm.EndMeasurement :=
    ( _kistlerStarted ) AND
    ( Wp100A104Kistler.Unit.OutImm.MeasRunning ) AND
    ( Wp100A104Kistler.Unit.ExecState = OpconExecState.RUNNING );
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
