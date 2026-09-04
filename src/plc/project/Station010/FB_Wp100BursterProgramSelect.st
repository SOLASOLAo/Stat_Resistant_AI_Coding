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
// 3=open timeout, 4=write timeout, 5=read timeout,
// 6=NAK received, 7=unexpected response, 8=EOT timeout.
IF ( NOT Execute )
THEN
  IF ( _socket.IsOpen )
  THEN
    _bytesWritten := 0;
    _socketResult := _socket.Write(
      pData := ADR(_eot),
      DataLen := 1,
      rBytesWritten := _bytesWritten
    );
    _socketResult := _socket.Close();
  END_IF

  _timer(IN := FALSE, PT := T#0S);
  _state    := 0;
  Busy      := FALSE;
  Done      := FALSE;
  Error     := FALSE;
  ErrorCode := 0;
  RETURN;
END_IF

CASE _state OF
  0:
    Busy      := TRUE;
    Done      := FALSE;
    Error     := FALSE;
    ErrorCode := 0;

    IF ( ProgramNo < 0 ) OR
       ( ProgramNo > 15 )
    THEN
      ErrorCode := 1;
      _state := 190;
    ELSE
      _requestedProgramNo := ProgramNo;
      _timer(IN := FALSE, PT := T#0S);
      _state := 10;
    END_IF

  10:
    // The Nexeed driver owns the normal measuring connection. Close it first.
    _closeResult := Peripherals._Wp100A103ResistantInterface.Close();
    _timer(IN := TRUE, PT := T#2S);

    IF ( _closeResult = OK )
    THEN
      _sendFrame := CONCAT(
        '$040000sr$02*RCL P',
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
      ErrorCode := 2;
      _state := 190;
    END_IF

  20:
    _socket.ConnectTimeout := T#2S;
    _socket.WriteTimeout   := T#2S;
    _socket.ReadTimeout    := T#2S;
    _connectTimedOut := FALSE;
    _socketResult := _socket.Open(
      rHostname := Peripherals._Wp100A103ResistantInterface.ParCfg.Hostname,
      PortNo := 5555,
      rConnectTimeout := _connectTimedOut
    );
    _timer(IN := TRUE, PT := T#3S);

    IF ( _socket.IsOpen )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 30;
    ELSIF ( _connectTimedOut ) OR
          ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 3;
      _state := 190;
    END_IF

  30:
    _bytesWritten := 0;
    _socketResult := _socket.Write(
      pData := ADR(_sendFrame) + _sendOffset,
      DataLen := _sendLength - _sendOffset,
      rBytesWritten := _bytesWritten
    );
    _sendOffset := _sendOffset + _bytesWritten;
    _timer(IN := TRUE, PT := T#2S);

    IF ( _sendOffset >= _sendLength )
    THEN
      _readBuffer[0] := 0;
      _readBuffer[1] := 0;
      _timer(IN := FALSE, PT := T#0S);
      _state := 40;
    ELSIF ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 4;
      _state := 190;
    END_IF

  40:
    _bytesRead := 0;
    _readTimedOut := FALSE;
    _socketResult := _socket.Read(
      pData := ADR(_readBuffer),
      DataLen := SIZEOF(_readBuffer),
      rBytesRead := _bytesRead,
      rReadTimeout := _readTimedOut
    );
    _timer(IN := TRUE, PT := T#3S);

    IF ( _bytesRead > 0 )
    THEN
      IF ( _readBuffer[0] = 6 )
      THEN
        _timer(IN := FALSE, PT := T#0S);
        _state := 50;
      ELSIF ( _readBuffer[0] = 21 )
      THEN
        ErrorCode := 6;
        _state := 190;
      ELSE
        ErrorCode := 7;
        _state := 190;
      END_IF
    ELSIF ( _readTimedOut ) OR
          ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 5;
      _state := 190;
    END_IF

  50:
    // The 2316 manual requires EOT before the TCP connection is closed.
    _bytesWritten := 0;
    _socketResult := _socket.Write(
      pData := ADR(_eot),
      DataLen := 1,
      rBytesWritten := _bytesWritten
    );
    _timer(IN := TRUE, PT := T#2S);

    IF ( _bytesWritten = 1 )
    THEN
      _timer(IN := FALSE, PT := T#0S);
      _state := 60;
    ELSIF ( _timer.Q )
    THEN
      LastSocketError := _socket.LastError;
      ErrorCode := 8;
      _state := 190;
    END_IF

  60:
    _socketResult := _socket.Close();

    IF ( NOT _socket.IsOpen )
    THEN
      Busy  := FALSE;
      Done  := TRUE;
      Error := FALSE;
      _state := 100;
    END_IF

  100:
    Busy  := FALSE;
    Done  := TRUE;
    Error := FALSE;

  190:
    // Error is reported only after best-effort EOT and socket close.
    IF ( _socket.IsOpen )
    THEN
      _bytesWritten := 0;
      _socketResult := _socket.Write(
        pData := ADR(_eot),
        DataLen := 1,
        rBytesWritten := _bytesWritten
      );
      _timer(IN := TRUE, PT := T#1S);

      IF ( _bytesWritten = 1 ) OR
         ( _timer.Q )
      THEN
        _timer(IN := FALSE, PT := T#0S);
        _state := 195;
      END_IF
    ELSE
      _state := 195;
    END_IF

  195:
    IF ( _socket.IsOpen )
    THEN
      _socketResult := _socket.Close();
    END_IF

    IF ( NOT _socket.IsOpen )
    THEN
      LastSocketError := _socket.LastError;
      Busy  := FALSE;
      Done  := FALSE;
      Error := TRUE;
      _state := 200;
    END_IF

  200:
    Busy  := FALSE;
    Done  := FALSE;
    Error := TRUE;

  ELSE
    ErrorCode := 7;
    _state := 190;
END_CASE
