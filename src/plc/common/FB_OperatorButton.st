(*
  Canonical AI-owned POU source.
  Deploy only through PLC Engineering MCP and verify by readback + compile.
*)

(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_OperatorButton
VAR_INPUT
  /// TRUE while the SFC step is requesting an operator acknowledgement
  Execute       : BOOL;
  /// Physical push-button signal
  ButtonPressed : BOOL;
  /// Shared 500 ms flash pulse, for example Station.FlashBits.Pulse500ms
  Blink500ms    : BOOL;
END_VAR
VAR_OUTPUT
  /// Latched completion; remains TRUE until Execute becomes FALSE
  Done          : BOOL;
  /// Command for the illuminated push-button lamp
  LampOn        : BOOL;
END_VAR

(* ===== IMPLEMENTATION ===== *)
// Execute follows the same lifecycle used by OpCon commands:
// FALSE ends the request and restores the initial state.
IF ( NOT Execute )
THEN
  Done   := FALSE;
  LampOn := FALSE;
  RETURN;
END_IF

// While waiting, flash the lamp. A detected button signal completes the
// request and switches the lamp off in the same PLC cycle.
IF ( NOT Done )
THEN
  IF ( ButtonPressed )
  THEN
    Done   := TRUE;
    LampOn := FALSE;
  ELSE
    LampOn := Blink500ms;
  END_IF
ELSE
  LampOn := FALSE;
END_IF
