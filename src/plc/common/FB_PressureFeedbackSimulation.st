(*
  Canonical AI-owned POU source.
  Deploy only through PLC Engineering MCP and verify by readback + compile.
*)

(* ===== DECLARATION ===== *)
(* Version: V1.0.0 *)
FUNCTION_BLOCK FB_PressureFeedbackSimulation
VAR_INPUT
  /// Enable the virtual feedback only while the Station and I/O bus are valid
  xEnable       : BOOL;
  /// Final application command that is written to the master air valve
  xValveCommand : BOOL;
  /// Delay before changing to the pressure state requested by the valve
  tSwitchDelay  : TIME := T#1S;
END_VAR
VAR_OUTPUT
  /// Virtual replacement for the unwired low-pressure switch
  xPressureLow      : BOOL;
  /// Virtual replacement for the unwired high-pressure switch
  xPressureHigh     : BOOL;
  /// TRUE while the one-second virtual pressure transition is running
  xTransitionActive : BOOL;
END_VAR
VAR
  _timerToHigh : TON;
  _timerToLow  : TON;
  _initialized : BOOL;
END_VAR

(* ===== IMPLEMENTATION ===== *)
// The physical pressure inputs are intentionally unwired. Disable both
// virtual inputs outside the valid application/I/O state. On a new enable,
// initialize to the safe depressurized state before evaluating the valve.
IF ( NOT xEnable )
THEN
  _timerToHigh(IN := FALSE, PT := tSwitchDelay);
  _timerToLow(IN := FALSE, PT := tSwitchDelay);

  xPressureLow      := FALSE;
  xPressureHigh     := FALSE;
  xTransitionActive := FALSE;
  _initialized      := FALSE;
  RETURN;
END_IF

// Initialization is not a valve transition. Always provide virtual LOW first
// so the main-pressure controller can safely issue its initial valve command.
IF ( NOT _initialized )
THEN
  xPressureLow  := TRUE;
  xPressureHigh := FALSE;
  _initialized  := TRUE;
END_IF

// Keep the previous stable state during the delay, then switch LOW/HIGH in
// one PLC cycle. The outputs can therefore never both be TRUE.
_timerToHigh(
  IN := ( xValveCommand ) AND
        ( NOT xPressureHigh ),
  PT := tSwitchDelay
);

_timerToLow(
  IN := ( NOT xValveCommand ) AND
        ( NOT xPressureLow ),
  PT := tSwitchDelay
);

IF ( _timerToHigh.Q )
THEN
  xPressureHigh := TRUE;
  xPressureLow  := FALSE;
ELSIF ( _timerToLow.Q )
THEN
  xPressureLow  := TRUE;
  xPressureHigh := FALSE;
END_IF

xTransitionActive := ( ( xValveCommand ) AND ( NOT xPressureHigh ) ) OR
                     ( ( NOT xValveCommand ) AND ( NOT xPressureLow ) );
