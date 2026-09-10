(*
  Canonical AI-owned POU source.
  Deploy only through PLC Engineering and verify by readback + Clean Build.
*)

(* ===== DECLARATION ===== *)
/// Selects a RESISTOMAT 2316 measuring program without competing for TCP port 5555.
(* Version: V1.0.0 *)
FUNCTION_BLOCK FB_Wp100BursterProgramSelect
VAR_INPUT
  Execute   : BOOL;
  ProgramNo : INT;
END_VAR
VAR_OUTPUT
  Busy            : BOOL;
  Done            : BOOL;
  Error           : BOOL;
  ErrorCode       : DINT;
  LastSocketError : OpconDeviceError;
END_VAR
VAR
  _socket             : OpconTcpClientIpV4;
  _timer              : TON;
  _state              : USINT;
  _requestedProgramNo : INT;
  _sendFrame          : STRING(31);
  _sendLength         : UDINT;
  _sendOffset         : UDINT;
  _bytesWritten       : UDINT;
  _bytesRead          : UDINT;
  _readBuffer         : ARRAY[0..1] OF BYTE;
  _eot                : BYTE := 4;
  _connectTimedOut    : BOOL;
  _readTimedOut       : BOOL;
  _closeResult        : DINT;
  _socketResult       : DINT;
END_VAR

(* ===== IMPLEMENTATION ===== *)
// ErrorCode: 1=invalid program, 2=standard driver close failed,
// 3=open failed/timeout, 4=write failed/timeout, 5=read failed/timeout,
// 6=NAK, 7=invalid response, 8=EOT failed/timeout,
// 9=close failed/timeout, 10=reset/clear-error failed/timeout,
// 11=standard driver reopen failed/timeout, 12=standard driver reset failed.
// OpCon methods remain pending until their RETURN VALUE leaves RUNNING.
// StationUnit.OnCall continues cancellation cleanup while Execute=FALSE/Busy.
IF ( NOT Execute )
THEN
  Done := FALSE;
  IF ( _state = 0 ) OR
     ( _state = 100 ) OR
     ( _state = 200 )
  THEN
    _state := 0;
    Busy := FALSE;
    Error := FALSE;
    RETURN;
  END_IF

  IF ( _state < 180 )
  THEN
    _timer(IN := FALSE, PT := T#0S);
    IF ( _state = 10 )
    THEN
      _state := 185; // Finish the standard driver's pending Close.
    ELSIF ( _state = 60 )
    THEN
      _state := 191; // Continue Close even if IsOpen is already FALSE.
    ELSIF ( _state = 70 )
    THEN
      _state := 187; // Abort standard Open before cleanup can close it.
    ELSIF ( _socketResult = RUNNING ) OR
          ( NOT _socket.IsOpen )
    THEN
      _state := 195; // Abort a pending method with Reset, not another I/O call.
    ELSE
      _bytesWritten := 0;
      _state := 190;
    END_IF
  END_IF
END_IF

CASE _state OF
  0:
    Busy      := TRUE;
    Done      := FALSE;
    Error     := FALSE;
    ErrorCode := 0;
    OpconMemSet(ADR(LastSocketError), 0, SIZEOF(LastSocketError));
    _sendFrame := '';
    _sendLength := 0;
    _sendOffset := 0;
    _bytesWritten := 0;
    _bytesRead := 0;
    _readBuffer[0] := 0;
    _readBuffer[1] := 0;
    _connectTimedOut := FALSE;
    _readTimedOut := FALSE;
    _socketResult := OK;
    _closeResult := OK;
    _timer(IN := FALSE, PT := T#0S);

    IF ( ProgramNo < 0 ) OR
       ( ProgramNo > 15 )
    THEN
      ErrorCode := 1;
      _state := 195;
    ELSE
      _requestedProgramNo := ProgramNo;
      _state := 5;
    END_IF

  5:
    // An explicit new request may recover a previous library error.
    _socketResult := _socket.ClearError();
    _timer(IN := TRUE, PT := T#3S);
    IF ( _socketResult = OK )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 6;
    ELSIF ( _socketResult < OK ) OR
          ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 10;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  6:
    _socketResult := _socket.Reset();
    _timer(IN := TRUE, PT := T#3S);
    IF ( _socketResult = OK )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 10;
    ELSIF ( _socketResult < OK )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 10;
      Busy := FALSE;
      _state := 200;
    ELSIF ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 10;
      _state := 195; // Keep polling the same Reset; never open after timeout.
    END_IF

  10:
    // The Nexeed driver owns the normal measuring connection. Close it first.
    _closeResult := Peripherals._Wp100A103ResistantInterface.Close();
    _timer(IN := TRUE, PT := T#2S);

    IF ( _closeResult = OK )
    THEN
      // Manual section 8.15.11: P1 is a numeric placeholder (0..15),
      // not a literal P prefix. Program zero is sent as *RCL 0.
      _sendFrame := CONCAT(
        '$040000sr$02*RCL ',
        INT_TO_STRING(_requestedProgramNo)
      );
      _sendFrame  := CONCAT(_sendFrame, '$0A$03$0D');
      _sendLength := TO_UDINT(LEN(_sendFrame));
      _sendOffset := 0;
      _timer(IN := FALSE, PT := T#0S);
      _state := 20;
    ELSIF ( _closeResult <> RUNNING ) OR
          ( _timer.Q )
    THEN
      LastSocketError := Peripherals._Wp100A103ResistantInterface.LastError;
      ErrorCode := 2;
      _timer(IN := FALSE, PT := T#0S);
      IF ( _closeResult = RUNNING )
      THEN
        _state := 185;
      ELSE
        _state := 195;
      END_IF
    END_IF

  20:
    _socket.ConnectTimeout := T#2S;
    _socket.WriteTimeout   := T#2S;
    _socket.ReadTimeout    := T#2S;
    _socketResult := _socket.Open(
      rHostname := Peripherals._Wp100A103ResistantInterface.ParCfg.Hostname,
      PortNo := 5555,
      rConnectTimeout := _connectTimedOut
    );
    _timer(IN := TRUE, PT := T#3S);

    IF ( _socketResult < OK ) OR
       ( _connectTimedOut )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 3;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    ELSIF ( _socketResult = OK ) AND
          ( _socket.IsOpen )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 30;
    ELSIF ( _socketResult <> RUNNING ) OR
          ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 3;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  30:
    _socketResult := _socket.Write(
      pData := ADR(_sendFrame) + _sendOffset,
      DataLen := _sendLength - _sendOffset,
      rBytesWritten := _bytesWritten
    );
    _timer(IN := TRUE, PT := T#2S);
    IF ( _socketResult < OK )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 4;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    ELSIF ( _socketResult = OK )
    THEN
      // Do not advance the buffer while Write is still using its arguments.
      IF ( _bytesWritten > ( _sendLength - _sendOffset ) )
      THEN
        ErrorCode := 7;
        _timer(IN := FALSE, PT := T#0S);
        _state := 195;
      ELSE
        _sendOffset := _sendOffset + _bytesWritten;
        _bytesWritten := 0;
        IF ( _sendOffset = _sendLength )
        THEN
          _timer(IN := FALSE, PT := T#0S);
          _state := 40;
        END_IF
      END_IF
    END_IF
    IF ( _state = 30 ) AND
       ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 4;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  40:
    _socketResult := _socket.Read(
      pData := ADR(_readBuffer),
      DataLen := SIZEOF(_readBuffer),
      rBytesRead := _bytesRead,
      rReadTimeout := _readTimedOut
    );
    _timer(IN := TRUE, PT := T#3S);

    IF ( _socketResult < OK ) OR
       ( _readTimedOut )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 5;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    ELSIF ( _socketResult = OK ) AND
          ( _bytesRead > 0 )
    THEN
      IF ( _readBuffer[0] = 6 )
      THEN
        _timer(IN := FALSE, PT := T#0S);
        _state := 50;
      ELSIF ( _readBuffer[0] = 21 )
      THEN
        ErrorCode := 6;
        _timer(IN := FALSE, PT := T#0S);
        _state := 190;
      ELSE
        ErrorCode := 7;
        _timer(IN := FALSE, PT := T#0S);
        _state := 190;
      END_IF
    ELSIF ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 5;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  50:
    // The 2316 manual requires EOT before the TCP connection is closed.
    _socketResult := _socket.Write(
      pData := ADR(_eot),
      DataLen := 1,
      rBytesWritten := _bytesWritten
    );
    _timer(IN := TRUE, PT := T#2S);

    IF ( _socketResult < OK )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 8;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    ELSIF ( _socketResult = OK ) AND
          ( _bytesWritten = 1 )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 60;
    ELSIF ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 8;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  60:
    _socketResult := _socket.Close();
    _timer(IN := TRUE, PT := T#3S);
    IF ( _socketResult = OK ) AND
       ( NOT _socket.IsOpen )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 70;
    ELSIF ( _socketResult <> RUNNING ) OR
          ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 9;
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  70:
    // Closing the temporary socket does NOT reopen the standard measuring
    // driver. Its Unit can still report READY while that driver is CLOSED.
    // Complete the public peripheral Open before handing ownership back.
    // Neither Unit Execute nor MeasCmd may start during this handoff.
    _closeResult := Peripherals._Wp100A103ResistantInterface.Open();
    _timer(IN := TRUE, PT := T#35S);
    IF ( _closeResult = OK )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      Busy  := FALSE;
      Done  := TRUE;
      Error := FALSE;
      _state := 100;
    ELSIF ( _closeResult <> RUNNING ) OR
          ( _timer.Q )
    THEN
      LastSocketError := Peripherals._Wp100A103ResistantInterface.LastError;
      ErrorCode := 11;
      _timer(IN := FALSE, PT := T#0S);
      _state := 187;
    END_IF

  100:
    Busy  := FALSE;
    Done  := TRUE;
    Error := FALSE;

  185:
    // A timed-out/cancelled standard Close must still finish its own method.
    // Never use the temporary socket while this driver is still closing.
    _closeResult := Peripherals._Wp100A103ResistantInterface.Close();
    _timer(IN := TRUE, PT := T#2S);
    IF ( _closeResult <> RUNNING )
    THEN
      IF ( _closeResult < OK ) AND
         ( ErrorCode = 0 )
      THEN
        LastSocketError := Peripherals._Wp100A103ResistantInterface.LastError;
        ErrorCode := 2;
      END_IF
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    ELSIF ( _timer.Q ) AND
          ( ErrorCode = 0 )
    THEN
      LastSocketError := Peripherals._Wp100A103ResistantInterface.LastError;
      ErrorCode := 2;
    END_IF

  187:
    // The standard peripheral, not the temporary socket, owns pending Open.
    // Reset it to completion before calling Close; never retry selection.
    _closeResult := Peripherals._Wp100A103ResistantInterface.Reset();
    _timer(IN := TRUE, PT := T#3S);
    IF ( _closeResult <> RUNNING )
    THEN
      IF ( _closeResult < OK ) AND
         ( ErrorCode = 0 )
      THEN
        LastSocketError := Peripherals._Wp100A103ResistantInterface.LastError;
        ErrorCode := 12;
      END_IF
      _timer(IN := FALSE, PT := T#0S);
      _state := 185;
    ELSIF ( _timer.Q ) AND
          ( ErrorCode = 0 )
    THEN
      LastSocketError := Peripherals._Wp100A103ResistantInterface.LastError;
      ErrorCode := 12;
      // Stay Busy and keep polling the same pending Reset.
    END_IF

  190:
    // Best-effort EOT only when no other temporary-socket method is pending.
    IF ( _socket.IsOpen )
    THEN
      _socketResult := _socket.Write(
        pData := ADR(_eot),
        DataLen := 1,
        rBytesWritten := _bytesWritten
      );
      _timer(IN := TRUE, PT := T#1S);

      IF ( _socketResult = OK ) AND
         ( _bytesWritten = 1 )
      THEN
        _timer(IN := FALSE, PT := T#0S);
        _state := 191;
      ELSIF ( _socketResult < OK ) OR
            ( _timer.Q )
      THEN
        IF ( ErrorCode = 0 )
        THEN
          LastSocketError := _socket.LastError;
          ErrorCode := 8;
        END_IF
        _timer(IN := FALSE, PT := T#0S);
        _state := 195;
      END_IF
    ELSE
      _state := 195;
    END_IF

  191:
    _socketResult := _socket.Close();
    _timer(IN := TRUE, PT := T#3S);
    IF ( _socketResult = OK )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    ELSIF ( _socketResult < OK ) OR
          ( _timer.Q )
    THEN
      IF ( ErrorCode = 0 )
      THEN
        LastSocketError := _socket.LastError;
        ErrorCode := 9;
      END_IF
      _timer(IN := FALSE, PT := T#0S);
      _state := 195;
    END_IF

  195:
    // Reset also handles an Open/Read/Write that never reached IsOpen/OK.
    // Preserve the FIRST error; Reset may clear the library's LastError.
    _socketResult := _socket.Reset();
    _timer(IN := TRUE, PT := T#3S);
    IF ( _socketResult <> RUNNING )
    THEN
      IF ( _socketResult < OK ) AND
         ( ErrorCode = 0 )
      THEN
        LastSocketError := _socket.LastError;
        ErrorCode := 10;
      END_IF
      _timer(IN := FALSE, PT := T#0S);
      Busy  := FALSE;
      Done  := FALSE;
      IF ( Execute ) AND
         ( ErrorCode <> 0 )
      THEN
        _state := 200;
      ELSE
        _state := 0;
      END_IF
    ELSIF ( _timer.Q ) AND
          ( ErrorCode = 0 )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 10;
      // Report the fault, but keep Busy and poll Reset until it really ends.
    END_IF

  200:
    Busy  := FALSE;
    Done  := FALSE;
    Error := TRUE;

  ELSE
    ErrorCode := 7;
    Busy := TRUE;
    _timer(IN := FALSE, PT := T#0S);
    _state := 195;
END_CASE

IF ( ErrorCode <> 0 )
THEN
  Error := TRUE;
  Done := FALSE;
END_IF
