(*
  Canonical AI-owned POU source.
  Deploy only through PLC Engineering MCP and verify by readback + compile.
*)

(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_PressureFeedbackSimulation
VAR_INPUT
  /// Enable the virtual feedback only while the Station and I/O bus are valid
  xEnable        : BOOL;
  /// Sustained electrical state from ControlOn.OutImm.IsCtrlOn
  xControlOn     : BOOL;
  /// Delay before changing to the pressure state requested by Control On/Off
  tSwitchDelay   : TIME := T#1S;
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
// virtual inputs outside the valid application/I/O state and re-synchronize
// to the current ControlOn state when monitoring becomes valid again.
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

// Initialization is not a Control On/Off transition. Adopt the current safe
// state immediately so Control On cannot occur before a virtual LOW exists.
IF ( NOT _initialized )
THEN
  xPressureLow  := ( NOT xControlOn );
  xPressureHigh := ( xControlOn );
  _initialized  := TRUE;
END_IF

// Keep the previous stable state during the delay, then switch LOW/HIGH in
// one PLC cycle. The outputs can therefore never both be TRUE.
_timerToHigh(
  IN := ( xControlOn ) AND
        ( NOT xPressureHigh ),
  PT := tSwitchDelay
);

_timerToLow(
  IN := ( NOT xControlOn ) AND
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

xTransitionActive := ( ( xControlOn ) AND ( NOT xPressureHigh ) ) OR
                     ( ( NOT xControlOn ) AND ( NOT xPressureLow ) );
