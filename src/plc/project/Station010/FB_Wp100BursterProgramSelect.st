(*
  Canonical AI-owned POU. Same-owner adapter for the existing SFC API.
  No socket here: all protocol operations belong to AiWp100.Burster.
*)
(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_Wp100BursterProgramSelect
VAR_INPUT
  Execute : BOOL;
  ProgramNo : INT;
END_VAR
VAR_OUTPUT
  Busy : BOOL;
  Done : BOOL;
  Error : BOOL;
  ErrorCode : DINT;
  LastSocketError : OpconDeviceError;
END_VAR
VAR
  _state : USINT; // 0=idle, 10=Open, 20=select, 90=cancel, 100=done, 200=error
  _requestedProgramNo : INT;
  _ret : DINT;
END_VAR

(* ===== IMPLEMENTATION ===== *)
// Only N045 (with the standard Unit READY/Execute=FALSE) starts selection.
// Resetting the adapter AFTER Done must not close a later Unit measurement.
IF ( NOT Execute )
THEN
  Done := FALSE;
  IF ( _state = 0 ) OR ( _state = 100 ) OR ( _state = 200 )
  THEN
    _state := 0;
    Busy := FALSE;
    Error := FALSE;
    RETURN;
  END_IF
  _state := 90;
END_IF

IF ( Execute ) AND
   ( ( _state = 10 ) OR ( _state = 20 ) ) AND
   ( ProgramNo <> _requestedProgramNo )
THEN
  IF ( ErrorCode = 0 ) THEN ErrorCode := 1503; END_IF
  Error := TRUE;
  _state := 90;
END_IF

CASE _state OF
  0:
    Busy := TRUE;
    Done := FALSE;
    Error := FALSE;
    ErrorCode := 0;
    _ret := RUNNING;
    OpconMemSet(ADR(LastSocketError), 0, SIZEOF(LastSocketError));
    IF ( ProgramNo < 0 ) OR ( ProgramNo > 15 )
    THEN
      ErrorCode := 1501;
      Error := TRUE;
      Busy := FALSE;
      _state := 200;
    ELSE
      _requestedProgramNo := ProgramNo;
      _state := 10;
    END_IF
  10:
    _ret := AiWp100.Burster.Open();
    IF ( _ret = OK ) THEN _state := 20; END_IF
  20:
    _ret := AiWp100.Burster.SelectProgram(ProgramNo := _requestedProgramNo);
    IF ( _ret = OK )
    THEN
      Busy := FALSE;
      Done := TRUE;
      _state := 100;
    END_IF
  90:
    // Continue only cancellation of our Open/Select call. If the Unit already
    // owns a measurement/error-clear, never replace it with a second Reset.
    IF ( AiWp100.Burster.Operation = 0 ) OR
       ( AiWp100.Burster.Operation = 1 ) OR
       ( AiWp100.Burster.Operation = 2 ) OR
       ( AiWp100.Burster.Operation = 9 )
    THEN
      _ret := AiWp100.Burster.Reset();
      IF ( _ret <> RUNNING )
      THEN
        IF ( _ret < OK )
        THEN
          IF ( ErrorCode = 0 )
          THEN
            ErrorCode := AiWp100.Burster.ErrorCode;
            IF ( ErrorCode = 0 ) THEN ErrorCode := 1502; END_IF
            LastSocketError := AiWp100.Burster.LastError;
          END_IF
          Error := TRUE;
        END_IF
        Busy := FALSE;
        IF ( Error ) THEN _state := 200; ELSE _state := 0; END_IF
      END_IF
    ELSE
      IF ( ErrorCode = 0 ) THEN ErrorCode := 1502; END_IF
      Error := TRUE;
      Busy := FALSE;
      _state := 200;
    END_IF
  100:
    ; // Hold Done until Execute falls; never recall the program here.
  200:
    ; // Preserve first fault until Execute falls; no automatic reconnect.
END_CASE

IF ( ( _state = 10 ) OR ( _state = 20 ) ) AND
   ( _ret < OK )
THEN
  IF ( ErrorCode = 0 )
  THEN
    ErrorCode := AiWp100.Burster.ErrorCode;
    IF ( ErrorCode = 0 ) THEN ErrorCode := 1502; END_IF
    LastSocketError := AiWp100.Burster.LastError;
  END_IF
  Error := TRUE;
  Done := FALSE;
  Busy := TRUE;
  _state := 90; // Continue the pending owner's cleanup even after SFC stops.
END_IF
