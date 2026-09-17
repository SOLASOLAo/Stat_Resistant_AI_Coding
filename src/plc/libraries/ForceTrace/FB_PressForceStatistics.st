(* ===== OBJECT FB_PressForceStatistics ===== *)
(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_PressForceStatistics
VAR_INPUT
  Enabled : BOOL;
  ForceN : REAL;
  ThresholdN : REAL;
  LimitN : REAL;
  WindowMs : UDINT;
  NowMs : UDINT;
END_VAR
VAR_OUTPUT
  Count : UDINT;
  Mean : LREAL;
  Sigma : LREAL;
  ThreeSigma : LREAL;
  Full : BOOL;
  Qualified : BOOL;
  FirstMs : UDINT;
  LastMs : UDINT;
  Minimum : REAL;
  Maximum : REAL;
  BinWidth : REAL;
  Bins : ARRAY [0..19] OF UDINT;
END_VAR
VAR
  _values : ARRAY [0..10001] OF REAL;
  _times : ARRAY [0..10001] OF UDINT;
  _head : UDINT;
  _index : UDINT;
  _next : UDINT;
  _i : UDINT;
  _bin : DINT;
  _m2 : LREAL;
  _delta : LREAL;
  _oldMean : LREAL;
  _value : LREAL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// One call per accepted PLC sample. Time-based rolling window, sample SD (n-1).
IF ( NOT Enabled ) OR ( NOT ( ForceN = ForceN ) ) OR
   ( ABS(ForceN) > REAL#3.402823E38 ) OR ( ForceN <= ThresholdN ) OR
   ( WindowMs = 0 ) OR ( WindowMs > 60000 ) OR ( LimitN <= 0 )
THEN
  Count := 0;
  _head := 0;
  Mean := 0;
  _m2 := 0;
  Sigma := 0;
  ThreeSigma := 0;
  Full := FALSE;
  Qualified := FALSE;
  FirstMs := 0;
  LastMs := 0;
  RETURN;
END_IF

// Keep one sample at/before the window start. This requires a complete time
// span, including when the window is not divisible by the PLC task period.
WHILE ( Count > 1 ) DO
  _next := (_head + 1) MOD 10002;
  IF ( ( NowMs - _times[_next] ) < WindowMs )
  THEN
    EXIT;
  END_IF
  _value := REAL_TO_LREAL(_values[_head]);
  _oldMean := Mean;
  Mean := (UDINT_TO_LREAL(Count) * Mean - _value) / UDINT_TO_LREAL(Count - 1);
  _m2 := _m2 - (_value - _oldMean) * (_value - Mean);
  Count := Count - 1;
  _head := _next;
END_WHILE
IF ( Count >= 10002 )
THEN
  // Configuration limits the window to 10000 nominal periods. Fail closed
  // if a faster actual caller exceeds the fixed statistics capacity.
  Count := 0;
  _head := 0;
  Mean := 0;
  _m2 := 0;
END_IF
_index := (_head + Count) MOD 10002;
_values[_index] := ForceN;
_times[_index] := NowMs;
Count := Count + 1;
_value := REAL_TO_LREAL(ForceN);
_delta := _value - Mean;
Mean := Mean + _delta / UDINT_TO_LREAL(Count);
_m2 := MAX(LREAL#0.0, _m2 + _delta * (_value - Mean));
FirstMs := _times[_head];
LastMs := NowMs;
Sigma := 0;
IF ( Count > 1 )
THEN
  Sigma := SQRT(_m2 / UDINT_TO_LREAL(Count - 1));
END_IF
ThreeSigma := LREAL#3.0 * Sigma;
Full := ( Count > 1 ) AND ( ( NowMs - FirstMs ) >= WindowMs );
Qualified := ( Full ) AND ( ThreeSigma < REAL_TO_LREAL(LimitN) );

(* ===== OBJECT SnapshotBins ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC SnapshotBins
(* ===== IMPLEMENTATION ===== *)
FOR _i := 0 TO 19 DO
  Bins[_i] := 0;
END_FOR
Minimum := 0;
Maximum := 0;
BinWidth := 0;
IF ( Count = 0 )
THEN
  RETURN;
END_IF
Minimum := _values[_head];
Maximum := Minimum;
FOR _i := 0 TO Count - 1 DO
  _index := (_head + _i) MOD 10002;
  Minimum := MIN(Minimum, _values[_index]);
  Maximum := MAX(Maximum, _values[_index]);
END_FOR
IF ( Maximum = Minimum )
THEN
  // Zero spread is displayed as a concentration marker, never a divided PDF.
  Bins[0] := Count;
  RETURN;
END_IF
BinWidth := LREAL_TO_REAL((REAL_TO_LREAL(Maximum) - REAL_TO_LREAL(Minimum)) / LREAL#20.0);
FOR _i := 0 TO Count - 1 DO
  _index := (_head + _i) MOD 10002;
  _value := (REAL_TO_LREAL(_values[_index]) - REAL_TO_LREAL(Minimum)) /
            (REAL_TO_LREAL(Maximum) - REAL_TO_LREAL(Minimum)) * LREAL#20.0;
  _bin := LIMIT(0, LREAL_TO_DINT(TRUNC(_value)), 19);
  Bins[_bin] := Bins[_bin] + 1;
END_FOR
