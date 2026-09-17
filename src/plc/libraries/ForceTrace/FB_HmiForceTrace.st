(* ===== OBJECT FB_HmiForceTrace ===== *)
(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_HmiForceTrace
VAR_INPUT
  Measuring : BOOL;
  QualityGood : BOOL;
  ForceN : REAL;
END_VAR
VAR_OUTPUT
  LeftFrame : ARRAY [0..30035] OF DWORD;
  MiddleFrame : ARRAY [0..30035] OF DWORD;
  RightFrame : ARRAY [0..30035] OF DWORD;
  StatisticsFrame : ARRAY [0..209] OF DWORD;
  Published : BOOL;
  PublishedPosition : UDINT;
  Cleared : BOOL;
  Qualified : BOOL;
  DataGood : BOOL;
  SampleTime : UDINT;
END_VAR
VAR
  _stats : FB_PressForceStatistics;
  _trace : ARRAY [1..3] OF T_HmiForceBuffer;
  _stat : ARRAY [1..3,0..63] OF DWORD;
  _payloadHash : ARRAY [1..3] OF UDINT;
  _frozen : ARRAY [1..3] OF BOOL;
  _configured : BOOL;
  _guardActive : BOOL;
  _clearPending : BOOL;
  _urgent : BOOL;
  _initialized : BOOL;
  _normalEndRequested : BOOL;
  _threshold : REAL;
  _limit : REAL;
  _window : UDINT;
  _timeout : UDINT;
  _samplePeriodMs : UDINT := 6;
  _maxGapMs : UDINT;
  _now : UDINT;
  _started : UDINT;
  _elapsed : UDINT;
  _lastSample : UDINT;
  _lastPublish : UDINT;
  _boot : UDINT;
  _cycle : UDINT;
  _acquisition : UDINT;
  _sequence : UDINT;
  _scan : UDINT;
  _sampledScan : UDINT;
  _position : UDINT;
  _state : UDINT;
  _hash : UDINT;
  _word : U_HmiForceWord;
  _p : DINT;
  _i : DINT;
  _j : DINT;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// MainTask caller. HMI timing never owns acquisition or process decisions.
_now := TIME_TO_UDINT(TIME());
_scan := _scan + 1;
Published := FALSE;
Cleared := _clearPending;
_clearPending := FALSE;
IF ( NOT _initialized )
THEN
  _initialized := TRUE;
  _boot := _now;
  _urgent := TRUE;
END_IF
IF ( _state = 1 )
THEN
  IF ( NOT _guardActive )
  THEN
    Sample(ValueN := ForceN, Healthy := QualityGood, AtWork := FALSE);
  ELSIF ( ( _now - _lastSample ) > _maxGapMs )
  THEN
    // Missing cyclic guard calls must not leave a stale TRUE for the next DONE.
    DataGood := FALSE;
    Qualified := FALSE;
  END_IF
  IF ( NOT QualityGood ) OR ( NOT ( ForceN = ForceN ) ) OR
     ( ABS(ForceN) > REAL#3.402823E38 )
  THEN
    Finish(Reason := 5, LastForceN := ForceN);
  ELSIF ( NOT Measuring )
  THEN
    IF ( _normalEndRequested )
    THEN
      Finish(Reason := 2, LastForceN := ForceN);
    ELSE
      Finish(Reason := 5, LastForceN := ForceN);
    END_IF
  END_IF
END_IF
IF ( _urgent ) OR ( ( _now - _lastPublish ) >= 100 ) OR ( Cleared )
THEN
  Publish();
END_IF

(* ===== OBJECT Configure ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC Configure
VAR_INPUT
  ThresholdN : REAL;
  LimitN : REAL;
  WindowMs : UDINT;
  TimeoutMs : UDINT;
  SamplePeriodMs : UDINT := 6;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// Once per position, before Kistler START. Changes take effect next position.
IF ( _state = 1 )
THEN
  RETURN;
END_IF
_threshold := ThresholdN;
_limit := LimitN;
_window := WindowMs;
_timeout := TimeoutMs;
_configured := ( SamplePeriodMs >= 1 ) AND ( SamplePeriodMs <= 1000 ) AND
               ( WindowMs > 0 ) AND ( WindowMs <= 60000 ) AND
               ( WindowMs <= SamplePeriodMs * 10000 );
IF ( _configured )
THEN
  _samplePeriodMs := SamplePeriodMs;
  // Millisecond timestamps: ceil(2.5 * nominal period), 15 ms at the 6 ms default.
  _maxGapMs := (_samplePeriodMs * 5 + 1) / 2;
END_IF

(* ===== OBJECT BeginCycle ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC BeginCycle
(* ===== IMPLEMENTATION ===== *)
_cycle := _cycle + 1;
IF ( _cycle = 0 )
THEN
  _cycle := 1;
END_IF
// Only Count is authoritative. Old payload beyond Count is never displayed.
FOR _p := 1 TO 3 DO
  FOR _i := 0 TO 31 DO
    _trace[_p][_i] := 0;
  END_FOR
  FOR _i := 0 TO 63 DO
    _stat[_p,_i] := 0;
  END_FOR
  _trace[_p][1] := DWORD#2;
  _trace[_p][3] := UDINT_TO_DWORD(_cycle);
  _trace[_p][5] := DINT_TO_DWORD(_p);
  _trace[_p][16] := UDINT_TO_DWORD(_samplePeriodMs);
  _payloadHash[_p] := UDINT#2166136261;
  _frozen[_p] := FALSE;
END_FOR
_position := 0;
_state := 0;
_configured := FALSE;
_guardActive := FALSE;
Qualified := FALSE;
DataGood := FALSE;
_normalEndRequested := FALSE;
_clearPending := TRUE;
_urgent := TRUE;

(* ===== OBJECT Start ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC Start
VAR_INPUT
  Position : UDINT;
  InitialForceN : REAL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
IF ( _state = 1 ) OR ( _cycle = 0 ) OR ( NOT _configured ) OR
   ( Position < 1 ) OR ( Position > 3 )
THEN
  RETURN;
END_IF
_acquisition := _acquisition + 1;
IF ( _acquisition = 0 )
THEN
  _acquisition := 1;
END_IF
_position := Position;
_started := TIME_TO_UDINT(TIME());
_lastSample := _started - _samplePeriodMs;
_sampledScan := _scan - 1;
_elapsed := 0;
_state := 1;
_guardActive := FALSE;
_normalEndRequested := FALSE;
_frozen[_position] := FALSE;
_payloadHash[_position] := UDINT#2166136261;
FOR _i := 6 TO 30 DO
  _trace[_position][_i] := 0;
END_FOR
FOR _i := 0 TO 63 DO
  _stat[_position,_i] := 0;
END_FOR
_trace[_position][4] := UDINT_TO_DWORD(_acquisition);
_word.Value := _threshold;
_trace[_position][12] := _word.Bits;
_word.Value := _limit;
_trace[_position][13] := _word.Bits;
_trace[_position][14] := UDINT_TO_DWORD(_window);
_trace[_position][15] := UDINT_TO_DWORD(_timeout);
_trace[_position][16] := UDINT_TO_DWORD(_samplePeriodMs);
_stats(Enabled := FALSE);
Sample(ValueN := InitialForceN, Healthy := TRUE, AtWork := FALSE);
_urgent := TRUE;

(* ===== OBJECT Evaluate ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC Evaluate : BOOL
VAR_INPUT
  ValueN : REAL;
  Healthy : BOOL;
  AtWork : BOOL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// The SFC guard samples immediately before START/DONE decisions; OnCall samples
// press-down/unloading. The MainTask scan counter prevents duplicate actions;
// millisecond clock rounding must not skip alternate task scans.
// Trace and statistics consume the SAME accepted PLC sample.
_guardActive := TRUE;
Sample(ValueN := ValueN, Healthy := Healthy, AtWork := AtWork);
Evaluate := ( _state = 1 ) AND ( DataGood ) AND ( Qualified ) AND
            ( Healthy ) AND ( AtWork ) AND ( ValueN > _threshold );

(* ===== OBJECT Sample ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE Sample
VAR_INPUT
  ValueN : REAL;
  Healthy : BOOL;
  AtWork : BOOL;
END_VAR
VAR
  good : BOOL;
  gap : BOOL;
  count : UDINT;
  offset : DINT;
  quality : DWORD;
END_VAR
(* ===== IMPLEMENTATION ===== *)
IF ( _state <> 1 )
THEN
  RETURN;
END_IF
_now := TIME_TO_UDINT(TIME());
good := ( Healthy ) AND ( ValueN = ValueN ) AND
        ( ABS(ValueN) <= REAL#3.402823E38 );
IF ( NOT good ) OR ( NOT AtWork ) OR ( ValueN <= _threshold )
THEN
  Qualified := FALSE;
  IF ( _guardActive ) AND ( NOT _frozen[_position] )
  THEN
    // Retain the last real window for the fault display before resetting it.
    CaptureStatistics();
    _stats(Enabled := FALSE);
  END_IF
END_IF
IF ( _sampledScan = _scan ) OR ( _now = _lastSample )
THEN
  IF ( NOT good )
  THEN
    DataGood := FALSE;
  END_IF
  RETURN;
END_IF
gap := ( ( _now - _lastSample ) > _maxGapMs );
_sampledScan := _scan;
_lastSample := _now;
SampleTime := _now;
IF ( _trace[_position][7] = 0 )
THEN
  // The actual first sampled value defines t=0 even across a millisecond tick.
  _started := _now;
END_IF
_elapsed := _now - _started;
DataGood := ( good ) AND ( NOT gap );
quality := BOOL_TO_DWORD(good);
IF ( gap )
THEN
  quality := DWORD#2;
END_IF
_trace[_position][17] := _trace[_position][17] + 1;
count := DWORD_TO_UDINT(_trace[_position][7]);
IF ( count < 10001 ) AND ( _elapsed <= 60000 )
THEN
  offset := 32 + UDINT_TO_DINT(count) * 3;
  _trace[_position][offset] := UDINT_TO_DWORD(_elapsed);
  _word.Value := ValueN;
  _trace[_position][offset+1] := _word.Bits;
  _trace[_position][offset+2] := quality;
  FOR _j := offset TO offset + 2 DO
    _payloadHash[_position] := ULINT_TO_UDINT(
      UDINT_TO_ULINT(_payloadHash[_position] XOR DWORD_TO_UDINT(_trace[_position][_j])) * ULINT#16777619);
  END_FOR
  _trace[_position][7] := UDINT_TO_DWORD(count + 1);
ELSE
  _trace[_position][8] := DWORD#1;
END_IF
IF ( _guardActive ) AND ( NOT _frozen[_position] )
THEN
  IF ( gap )
  THEN
    CaptureStatistics();
  END_IF
  _stats(Enabled := ( DataGood ) AND ( AtWork ), ForceN := ValueN,
    ThresholdN := _threshold, LimitN := _limit, WindowMs := _window, NowMs := _elapsed);
  Qualified := _stats.Qualified;
  IF ( Qualified ) AND ( _trace[_position][9] = 0 )
  THEN
    // 1-based stream number; retained capacity may already be exhausted.
    _trace[_position][9] := _trace[_position][17];
    _trace[_position][10] := UDINT_TO_DWORD(_elapsed);
    _urgent := TRUE;
  END_IF
END_IF
_word.Value := ValueN;
IF ( NOT _frozen[_position] )
THEN
  _stat[_position,5] := _word.Bits;
END_IF

(* ===== OBJECT CaptureStatistics ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE CaptureStatistics
VAR
  historical : BOOL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
IF ( _position = 0 ) OR ( _frozen[_position] )
THEN
  RETURN;
END_IF
historical := ( _stats.Count = 0 ) AND ( _stat[_position,3] > 0 );
_stat[_position,0] := UDINT_TO_DWORD(_position);
_stat[_position,1] := UDINT_TO_DWORD(_acquisition);
_stat[_position,2] := UDINT_TO_DWORD(_state);
_stat[_position,4] := ( BOOL_TO_DWORD(DataGood) ) OR
  ( SHL(BOOL_TO_DWORD(_stats.Full),1) ) OR ( SHL(BOOL_TO_DWORD(Qualified),2) ) OR
  ( SHL(BOOL_TO_DWORD(historical),4) );
IF ( NOT historical )
THEN
_stats.SnapshotBins();
_stat[_position,3] := UDINT_TO_DWORD(_stats.Count);
_word.Value := LREAL_TO_REAL(_stats.Mean);
_stat[_position,6] := _word.Bits;
_word.Value := LREAL_TO_REAL(_stats.Sigma);
_stat[_position,7] := _word.Bits;
_word.Value := LREAL_TO_REAL(_stats.ThreeSigma);
_stat[_position,8] := _word.Bits;
_word.Value := _stats.Minimum;
_stat[_position,9] := _word.Bits;
_stat[_position,20] := _word.Bits;
_word.Value := _stats.Maximum;
_stat[_position,10] := _word.Bits;
_stat[_position,16] := UDINT_TO_DWORD(_stats.FirstMs);
_stat[_position,17] := UDINT_TO_DWORD(_stats.LastMs);
_word.Value := _stats.BinWidth;
_stat[_position,21] := _word.Bits;
_stat[_position,22] := DWORD#20;
FOR _i := 0 TO 19 DO
  _stat[_position,23 + _i] := UDINT_TO_DWORD(_stats.Bins[_i]);
END_FOR
END_IF
_stat[_position,11] := _trace[_position][12];
_stat[_position,12] := _trace[_position][13];
_stat[_position,13] := _trace[_position][14];
_stat[_position,14] := _trace[_position][15];
_stat[_position,15] := UDINT_TO_DWORD(_elapsed);
_stat[_position,18] := _trace[_position][9];
_stat[_position,19] := _trace[_position][10];
_stat[_position,43] := _trace[_position][17];
_stat[_position,44] := _trace[_position][16];

(* ===== OBJECT FreezeStatistics ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC FreezeStatistics
(* ===== IMPLEMENTATION ===== *)
IF ( _position = 0 ) OR ( _frozen[_position] )
THEN
  RETURN;
END_IF
CaptureStatistics();
_frozen[_position] := TRUE;
_stat[_position,4] := _stat[_position,4] OR DWORD#8;
_guardActive := FALSE;
_urgent := TRUE;

(* ===== OBJECT RequestEnd ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC RequestEnd
(* ===== IMPLEMENTATION ===== *)
IF ( _state = 1 )
THEN
  _normalEndRequested := TRUE;
END_IF

(* ===== OBJECT Finish ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC Finish
VAR_INPUT
  Reason : UDINT;
  LastForceN : REAL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
IF ( _state <> 1 ) OR ( Reason < 2 ) OR ( Reason > 5 )
THEN
  RETURN;
END_IF
_elapsed := TIME_TO_UDINT(TIME()) - _started;
IF ( Reason <> 2 )
THEN
  Qualified := FALSE;
END_IF
IF ( Reason = 5 )
THEN
  DataGood := FALSE;
END_IF
// First terminal cause wins; cleanup cannot overwrite it.
FreezeStatistics();
_state := Reason;
_stat[_position,2] := UDINT_TO_DWORD(Reason);
IF ( Reason <> 2 )
THEN
  _stat[_position,4] := _stat[_position,4] AND NOT DWORD#4;
  _word.Value := LastForceN;
  _stat[_position,5] := _word.Bits;
END_IF
IF ( Reason = 5 )
THEN
  _stat[_position,4] := _stat[_position,4] AND NOT DWORD#1;
END_IF
_configured := FALSE;
_guardActive := FALSE;
_urgent := TRUE;

(* ===== OBJECT Publish ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE Publish
(* ===== IMPLEMENTATION ===== *)
_urgent := FALSE;
_lastPublish := _now;
_sequence := _sequence + 1;
IF ( _sequence = 0 )
THEN
  _sequence := 1;
END_IF
CaptureStatistics();
FOR _p := 1 TO 3 DO
  IF ( UDINT_TO_DINT(_position) = _p ) OR ( Cleared )
  THEN
    _trace[_p][0] := UDINT_TO_DWORD(_sequence);
    _trace[_p][2] := UDINT_TO_DWORD(_boot);
    IF ( UDINT_TO_DINT(_position) = _p )
    THEN
      _trace[_p][6] := UDINT_TO_DWORD(_state);
      _trace[_p][11] := UDINT_TO_DWORD(_elapsed);
    END_IF
    _hash := _payloadHash[_p];
    FOR _i := 0 TO 30 DO
      _hash := ULINT_TO_UDINT(UDINT_TO_ULINT(_hash XOR DWORD_TO_UDINT(_trace[_p][_i])) * ULINT#16777619);
    END_FOR
    _trace[_p][31] := UDINT_TO_DWORD(_hash);
    _trace[_p][30035] := _trace[_p][0];
    CASE _p OF
      1: LeftFrame := _trace[_p];
      2: MiddleFrame := _trace[_p];
      3: RightFrame := _trace[_p];
    END_CASE
  END_IF
END_FOR
StatisticsFrame[0] := UDINT_TO_DWORD(_sequence);
StatisticsFrame[1] := DWORD#2;
StatisticsFrame[2] := UDINT_TO_DWORD(_boot);
StatisticsFrame[3] := UDINT_TO_DWORD(_cycle);
StatisticsFrame[4] := UDINT_TO_DWORD(_position);
StatisticsFrame[5] := UDINT_TO_DWORD(_now);
StatisticsFrame[6] := DWORD#20;
StatisticsFrame[7] := UDINT_TO_DWORD(_samplePeriodMs);
FOR _p := 1 TO 3 DO
  FOR _i := 0 TO 63 DO
    StatisticsFrame[16 + (_p - 1) * 64 + _i] := _stat[_p,_i];
  END_FOR
END_FOR
_hash := UDINT#2166136261;
FOR _i := 0 TO 207 DO
  _hash := ULINT_TO_UDINT(UDINT_TO_ULINT(_hash XOR DWORD_TO_UDINT(StatisticsFrame[_i])) * ULINT#16777619);
END_FOR
StatisticsFrame[208] := UDINT_TO_DWORD(_hash);
StatisticsFrame[209] := StatisticsFrame[0];
PublishedPosition := _position;
Published := TRUE;
