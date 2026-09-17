(* One file contains the AI-owned FB and its methods. No generated interfaces.
   Ethernet protocol: BA_2316_EN sections 7.3, 8.10, 8.12, 8.13.3, 8.15.11.
   Bind only after CpStudio has removed the old Peripheral and its Unit binding.
   OBJECT markers are consumed by apply_burster_single_owner_rest.ps1. *)

(* ===== OBJECT FB_Wp100BursterSingleOwner ===== *)
(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_Wp100BursterSingleOwner IMPLEMENTS IBursterResis2316
VAR_INPUT
  Hostname : STRING(255);
  RequestedProgramNo : INT;
  MeasurementTimeout : TIME := T#30S;
END_VAR
VAR_OUTPUT
  Connected : BOOL;
  SelectionVerified : BOOL;
  SelectedProgram : INT := -1;
  ResultValid : BOOL;
  ErrorCode : DINT;
  LastSocketError : OpconDeviceError;
  LastCommand : STRING(95);
  LastResponse : STRING(127);
  Operation : USINT;
  Phase : UINT;
  CleanupBlocked : BOOL;
  MeasurementStarts : UDINT;
END_VAR
VAR
  _socket : OpconTcpClientIpV4;
  _host : STRING(255);
  _ioKind : USINT; // 1=Open, 2=Write, 3=Read, 4=Close, 5=ClearError
  _ioResult : DINT;
  _ioPointer : POINTER TO BYTE;
  _ioLength : UDINT;
  _ioCount : UDINT;
  _ioTimedOut : BOOL;
  _exchangeState : USINT;
  _rxPhase : USINT;
  _rxByte : BYTE;
  _rxCount : UINT;
  _tx : STRING(127);
  _txOffset : UDINT;
  _txLength : UDINT;
  _query : BOOL;
  _nak : BOOL;
  _exchangeTimer : TON;
  _operationTimer : TON;
  _cleanupTimer : TON;
  _measureTimer : TON;
  _pollTimer : TON;
  _program : INT;
  _measProgram : INT;
  _measPrep : USINT; // 0=none, 1=Open, 2=SelectProgram, same socket owner
  _setting : BursterResis2316BaseSetting;
  _result : BursterResis2316BaseResult;
  _measTimeout : TIME;
  _measureMayRun : BOOL;
  _cleanupPhase : USINT;
  _cleanupError : BOOL;
  _eot : BYTE := 4;
  _value : REAL;
  _reg : UINT;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// Intentionally inert. Methods are the only communication entry points.

(* ===== OBJECT Fail ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE Fail : DINT
VAR_INPUT Code : DINT; END_VAR
(* ===== IMPLEMENTATION ===== *)
// Retain the first cause across cancellation and subsequent cleanup errors.
IF ( ErrorCode = 0 )
THEN
  ErrorCode := Code;
  LastSocketError := _socket.LastError;
  IF ( LastSocketError.Number = 0 )
  THEN
    // Use the already exported ctrlX communication-error table for local
    // protocol faults; preserve a real transport error unchanged when present.
    LastSocketError.ObjectID := OpconObjectIdFromString('A4680002-013E-11E1-8619-000423132FC8');
    LastSocketError.Number := -35; // Unexpected communication error.
    IF ( Code = 1301 ) THEN LastSocketError.Number := -50; END_IF
    LastSocketError.NativeErrCode := Code;
    LastSocketError.AddText := CONCAT('B2316 E=', DINT_TO_STRING(Code));
    LastSocketError.AddText := CONCAT(LastSocketError.AddText, CONCAT(' CMD=', LEFT(LastCommand, 35)));
  END_IF
END_IF
SelectionVerified := FALSE;
ResultValid := FALSE;
Fail := HAS_ERROR;

(* ===== OBJECT PollIo ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE PollIo : DINT
(* ===== IMPLEMENTATION ===== *)
// The same buffer, length and host are used until this call is terminal.
CASE _ioKind OF
  1:
    _ioResult := _socket.Open(rHostname := _host, PortNo := 5555,
      rConnectTimeout := _ioTimedOut);
  2:
    _ioResult := _socket.Write(pData := _ioPointer, DataLen := _ioLength,
      rBytesWritten := _ioCount);
  3:
    _ioResult := _socket.Read(pData := _ioPointer, DataLen := _ioLength,
      rBytesRead := _ioCount, rReadTimeout := _ioTimedOut);
  4:
    _ioResult := _socket.Close();
  5:
    _ioResult := _socket.ClearError();
  ELSE
    PollIo := HAS_ERROR;
    RETURN;
END_CASE
Connected := _socket.IsOpen;
PollIo := _ioResult;
IF ( _ioResult <> RUNNING )
THEN
  _ioKind := 0;
  IF ( _ioTimedOut ) OR
     ( _ioResult < OK )
  THEN
    PollIo := Fail(Code := 1010);
  END_IF
END_IF

(* ===== OBJECT Exchange ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE Exchange : DINT
VAR_INPUT
  CommandText : STRING(95);
  Query : BOOL;
END_VAR
VAR
  n : UINT;
  _ret : DINT;
END_VAR
(* ===== IMPLEMENTATION ===== *)
Exchange := RUNNING;
IF ( _exchangeState = 0 )
THEN
  IF ( NOT _socket.IsOpen ) OR
     ( _ioKind <> 0 ) OR
     ( LEN(CommandText) = 0 )
  THEN
    Exchange := Fail(Code := 1020);
    RETURN;
  END_IF
  LastCommand := CommandText;
  LastResponse := '';
  _query := Query;
  _nak := FALSE;
  _tx := CONCAT('$040000sr$02', CommandText);
  _tx := CONCAT(_tx, '$0A$03$0D');
  _txLength := TO_UDINT(LEN(_tx));
  _txOffset := 0;
  _rxCount := 0;
  _rxPhase := 0;
  _exchangeTimer(IN := FALSE, PT := T#3S);
  _exchangeState := 10;
END_IF
IF ( _exchangeState = 199 )
THEN
  Exchange := HAS_ERROR;
  RETURN;
END_IF
_exchangeTimer(IN := TRUE, PT := T#3S);
// At most 16 byte-completions per scan; no blocking socket or unbounded loop.
FOR n := 1 TO 16 DO
  CASE _exchangeState OF
    10, 30:
      IF ( _ioKind = 0 )
      THEN
        _ioKind := 2;
        _ioPointer := ADR(_tx) + _txOffset;
        _ioLength := _txLength - _txOffset;
        _ioCount := 0;
        _ioTimedOut := FALSE;
      END_IF
      _ret := PollIo();
      IF ( _ret = RUNNING ) THEN EXIT; END_IF
      IF ( _ret < OK ) OR
         ( _ioCount > _ioLength )
      THEN
        Exchange := Fail(Code := 1021);
        _exchangeState := 199;
        RETURN;
      END_IF
      _txOffset := _txOffset + _ioCount;
      IF ( _txOffset = _txLength )
      THEN
        _exchangeState := _exchangeState + 10;
      END_IF
      IF ( _ioCount = 0 ) THEN EXIT; END_IF

    20, 40:
      // Read exactly one byte. This works with any TCP fragmentation and
      // cannot consume bytes belonging to a later response.
      IF ( _ioKind = 0 )
      THEN
        _ioKind := 3;
        _ioPointer := ADR(_rxByte);
        _ioLength := 1;
        _ioCount := 0;
        _ioTimedOut := FALSE;
      END_IF
      _ret := PollIo();
      IF ( _ret = RUNNING ) THEN EXIT; END_IF
      IF ( _ret < OK ) OR
         ( _ioCount > 1 )
      THEN
        Exchange := Fail(Code := 1022);
        _exchangeState := 199;
        RETURN;
      END_IF
      IF ( _ioCount = 0 ) THEN EXIT; END_IF
      IF ( _exchangeState = 20 )
      THEN
        IF ( _rxCount = 0 )
        THEN
          IF ( _rxByte <> 6 ) AND
             ( _rxByte <> 21 )
          THEN
            Exchange := Fail(Code := 1023);
            _exchangeState := 199;
            RETURN;
          END_IF
          _nak := (_rxByte = 21);
          _rxCount := 1;
        ELSE
          IF ( _rxByte <> 13 ) OR
             ( _nak )
          THEN
            Exchange := Fail(Code := 1024);
            _exchangeState := 199;
            RETURN;
          END_IF
          IF ( NOT _query )
          THEN
            _exchangeState := 0;
            _exchangeTimer(IN := FALSE, PT := T#3S);
            Exchange := OK;
            RETURN;
          END_IF
          _tx := '$040000po$05$0D';
          _txOffset := 0;
          _txLength := TO_UDINT(LEN(_tx));
          _rxCount := 0;
          _exchangeState := 30;
        END_IF
      ELSE
        CASE _rxPhase OF
          0:
            IF ( _rxByte = 2 ) THEN _rxPhase := 1;
            ELSE _rxPhase := 99; END_IF
          1:
            IF ( _rxByte = 3 )
            THEN
              IF ( _rxCount < 2 )
              THEN
                _rxPhase := 99;
              ELSIF ( LastResponse[_rxCount - 2] <> 13 ) OR
                    ( LastResponse[_rxCount - 1] <> 10 )
              THEN
                _rxPhase := 99;
              ELSE
                LastResponse[_rxCount - 2] := 0;
                _rxPhase := 2;
              END_IF
            ELSIF ( _rxCount >= 127 ) OR
                  ( ( _rxByte < 32 ) AND ( _rxByte <> 13 ) AND ( _rxByte <> 10 ) ) OR
                  ( _rxByte > 126 )
            THEN
              _rxPhase := 99;
            ELSE
              LastResponse[_rxCount] := _rxByte;
              _rxCount := _rxCount + 1;
              LastResponse[_rxCount] := 0;
            END_IF
          2:
            // Manual Ethernet examples allow ETX CR EOT CR or ETX EOT CR.
            IF ( _rxByte = 13 ) THEN _rxPhase := 3;
            ELSIF ( _rxByte = 4 ) THEN _rxPhase := 4;
            ELSE _rxPhase := 99; END_IF
          3:
            IF ( _rxByte = 4 ) THEN _rxPhase := 4;
            ELSE _rxPhase := 99; END_IF
          4:
            IF ( _rxByte = 13 )
            THEN
              _exchangeState := 0;
              _exchangeTimer(IN := FALSE, PT := T#3S);
              Exchange := OK;
              RETURN;
            ELSE
              _rxPhase := 99;
            END_IF
        END_CASE
        IF ( _rxPhase = 99 )
        THEN
          Exchange := Fail(Code := 1025);
          _exchangeState := 199;
          RETURN;
        END_IF
      END_IF
  END_CASE
END_FOR
IF ( _exchangeTimer.Q )
THEN
  // Do not replace a pending Read/Write with another I/O operation.
  Exchange := Fail(Code := 1026);
  _exchangeState := 199;
END_IF

(* ===== OBJECT ParseNumber ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE ParseNumber : BOOL
VAR_INPUT TextValue : STRING(127); Kind : USINT; END_VAR
VAR
  p : INT;
  start : INT;
  digits : INT;
  exponentDigits : INT;
  numeric : STRING(63);
  suffix : STRING(63);
  scale : REAL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// Kind 0=unsigned register/program, 1=resistance, 2=temperature.
// Validate the complete grammar BEFORE STRING_TO_REAL (which accepts junk).
ParseNumber := FALSE;
_value := 0.0;
_reg := 0;
p := 0;
WHILE ( TextValue[p] = 32 ) AND ( p < 127 ) DO p := p + 1; END_WHILE
start := p;
IF ( Kind <> 0 ) AND
   ( ( TextValue[p] = 43 ) OR ( TextValue[p] = 45 ) )
THEN
  p := p + 1;
END_IF
digits := 0;
WHILE ( p < 127 ) AND ( TextValue[p] >= 48 ) AND ( TextValue[p] <= 57 ) DO
  digits := digits + 1;
  p := p + 1;
END_WHILE
IF ( Kind <> 0 ) AND ( TextValue[p] = 46 )
THEN
  p := p + 1;
  WHILE ( p < 127 ) AND ( TextValue[p] >= 48 ) AND ( TextValue[p] <= 57 ) DO
    digits := digits + 1;
    p := p + 1;
  END_WHILE
END_IF
IF ( digits = 0 ) THEN RETURN; END_IF
IF ( Kind <> 0 ) AND
   ( ( TextValue[p] = 69 ) OR ( TextValue[p] = 101 ) )
THEN
  p := p + 1;
  IF ( TextValue[p] = 43 ) OR ( TextValue[p] = 45 ) THEN p := p + 1; END_IF
  exponentDigits := 0;
  WHILE ( p < 127 ) AND ( TextValue[p] >= 48 ) AND ( TextValue[p] <= 57 ) DO
    exponentDigits := exponentDigits + 1;
    p := p + 1;
  END_WHILE
  IF ( exponentDigits = 0 ) OR ( exponentDigits > 2 ) THEN RETURN; END_IF
END_IF
IF ( ( p - start ) > 63 ) THEN RETURN; END_IF
numeric := MID(TextValue, TO_INT(p - start), TO_INT(start + 1));
WHILE ( TextValue[p] = 32 ) AND ( p < 127 ) DO p := p + 1; END_WHILE
IF ( ( LEN(TextValue) - p ) > 63 ) THEN RETURN; END_IF
suffix := RIGHT(TextValue, TO_INT(LEN(TextValue) - p));
// Remove trailing spaces, not arbitrary unparsed content.
WHILE ( LEN(suffix) > 0 ) DO
  IF ( suffix[LEN(suffix) - 1] <> 32 ) THEN EXIT; END_IF
  suffix[LEN(suffix) - 1] := 0;
END_WHILE
IF ( Kind = 0 )
THEN
  IF ( suffix <> '' ) OR ( digits > 5 ) THEN RETURN; END_IF
  IF ( STRING_TO_UDINT(numeric) > 32767 ) THEN RETURN; END_IF
  _reg := STRING_TO_UINT(numeric);
  _value := UINT_TO_REAL(_reg);
  ParseNumber := TRUE;
  RETURN;
END_IF
// Accept only documented units; reject length-normalized Ohm/m etc.
IF ( Kind = 1 )
THEN
  p := FIND(suffix, ',');
  IF ( p > 0 )
  THEN
    IF ( RIGHT(suffix, 1) <> '<' ) AND
       ( RIGHT(suffix, 1) <> '=' ) AND
       ( RIGHT(suffix, 1) <> '>' )
    THEN RETURN; END_IF
    // Comparator is optional; only a single marker and optional spaces.
    FOR start := p TO ( LEN(suffix) - 2 ) DO
      IF ( suffix[start] <> 32 ) THEN RETURN; END_IF
    END_FOR
    suffix[p - 1] := 0;
    WHILE ( LEN(suffix) > 0 ) DO
      IF ( suffix[LEN(suffix) - 1] <> 32 ) THEN EXIT; END_IF
      suffix[LEN(suffix) - 1] := 0;
    END_WHILE
  END_IF
  IF ( suffix = 'OHM' ) THEN scale := 1.0;
  ELSIF ( suffix = 'MOHM' ) THEN scale := 0.001;
  ELSIF ( suffix = 'KOHM' ) THEN scale := 1000.0;
  ELSE RETURN; END_IF
ELSE
  IF ( suffix <> 'CEL' ) THEN RETURN; END_IF
  scale := 1.0;
END_IF
_value := STRING_TO_REAL(numeric) * scale;
// Reject NaN, infinity and implausible protocol values. Never turn overflow
// or an unrecognized response into a valid resistance of zero.
IF ( NOT ( _value >= -1000000.0 ) ) OR
   ( NOT ( _value <= 1000000.0 ) )
THEN RETURN; END_IF
IF ( Kind = 1 ) AND ( _value < 0.0 ) THEN RETURN; END_IF
IF ( Kind = 2 ) AND ( ( _value < -273.15 ) OR ( _value > 2000.0 ) ) THEN RETURN; END_IF
ParseNumber := TRUE;

(* ===== OBJECT Open ===== *)
(* ===== DECLARATION ===== *)
METHOD Open : DINT
VAR _ret : DINT; END_VAR
(* ===== IMPLEMENTATION ===== *)
Open := RUNNING;
IF ( ErrorCode <> 0 ) OR ( CleanupBlocked )
THEN Open := HAS_ERROR; RETURN; END_IF
IF ( ( Operation <> 0 ) AND ( Operation <> 1 ) )
THEN Open := Fail(Code := 1001); RETURN; END_IF
IF ( Operation = 0 )
THEN
  IF ( Connected ) AND ( _socket.IsOpen ) AND ( Hostname = _host )
  THEN Open := OK; RETURN; END_IF
  IF ( LEN(Hostname) = 0 ) OR ( _socket.IsOpen )
  THEN Open := Fail(Code := 1002); RETURN; END_IF
  Operation := 1;
  Phase := 0;
  _host := Hostname;
  SelectionVerified := FALSE;
  _socket.ConnectTimeout := T#2S;
  _socket.WriteTimeout := T#2S;
  _socket.ReadTimeout := T#2S;
  _operationTimer(IN := FALSE, PT := T#5S);
END_IF
_operationTimer(IN := TRUE, PT := T#5S);
CASE Phase OF
  0:
    IF ( _ioKind = 0 ) THEN _ioKind := 1; _ioTimedOut := FALSE; END_IF
    _ret := PollIo();
    IF ( _ret < OK ) THEN Open := HAS_ERROR; RETURN; END_IF
    IF ( _ret = OK )
    THEN
      IF ( NOT Connected ) THEN Open := Fail(Code := 1003); RETURN; END_IF
      Phase := 10;
    END_IF
  10:
    _ret := Exchange(CommandText := '*IDN?', Query := TRUE);
    IF ( _ret < OK ) THEN Open := HAS_ERROR; RETURN; END_IF
    IF ( _ret = OK )
    THEN
      IF ( LEFT(LastResponse, 16) <> 'RESISTOMAT 2316,' ) AND
         ( LEFT(LastResponse, 15) <> 'RESISTOMAT2316,' )
      THEN Open := Fail(Code := 1004); RETURN; END_IF
      Operation := 0;
      Phase := 0;
      _operationTimer(IN := FALSE, PT := T#5S);
      Open := OK;
      RETURN;
    END_IF
END_CASE
IF ( _operationTimer.Q ) THEN Open := Fail(Code := 1005); END_IF

(* ===== OBJECT SelectProgram ===== *)
(* ===== DECLARATION ===== *)
METHOD SelectProgram : DINT
VAR_INPUT ProgramNo : INT; END_VAR
VAR _ret : DINT; END_VAR
(* ===== IMPLEMENTATION ===== *)
SelectProgram := RUNNING;
IF ( ErrorCode <> 0 ) OR ( CleanupBlocked )
THEN SelectProgram := HAS_ERROR; RETURN; END_IF
IF ( ( Operation <> 0 ) AND ( Operation <> 2 ) )
THEN SelectProgram := Fail(Code := 1101); RETURN; END_IF
IF ( Operation = 0 )
THEN
  IF ( ProgramNo < 0 ) OR ( ProgramNo > 15 ) OR
     ( NOT _socket.IsOpen ) OR ( Hostname <> _host )
  THEN SelectProgram := Fail(Code := 1102); RETURN; END_IF
  Operation := 2;
  Phase := 0;
  _program := ProgramNo;
  SelectionVerified := FALSE;
  ResultValid := FALSE;
  _operationTimer(IN := FALSE, PT := T#10S);
END_IF
IF ( ProgramNo <> _program )
THEN SelectProgram := Fail(Code := 1103); RETURN; END_IF
_operationTimer(IN := TRUE, PT := T#10S);
CASE Phase OF
  0:
    _ret := Exchange(CommandText := CONCAT('*RCL ', INT_TO_STRING(_program)), Query := FALSE);
    IF ( _ret = OK ) THEN Phase := 10; END_IF
  10:
    _ret := Exchange(CommandText := '*RCL?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN SelectProgram := Fail(Code := 1104); RETURN; END_IF
      IF ( _reg <> INT_TO_UINT(_program) )
      THEN SelectProgram := Fail(Code := 1105); RETURN; END_IF
      Phase := 20;
    END_IF
  20:
    _ret := Exchange(CommandText := 'SYST:ERR?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      // Exact zero-status forms only; the installed instrument quotes the text.
      // Keep nonzero codes, partial responses and trailing garbage blocked.
      IF ( LastResponse <> '0, NO ERROR' ) AND
         ( LastResponse <> '0,NO ERROR' ) AND
         ( LastResponse <> '0, "NO ERROR"' ) AND
         ( LastResponse <> '0,"NO ERROR"' )
      THEN SelectProgram := Fail(Code := 1106); RETURN; END_IF
      SelectedProgram := _program;
      SelectionVerified := TRUE;
      Operation := 0;
      Phase := 0;
      _operationTimer(IN := FALSE, PT := T#10S);
      SelectProgram := OK;
      RETURN;
    END_IF
END_CASE
IF ( _ret < OK ) THEN SelectProgram := HAS_ERROR; END_IF
IF ( _operationTimer.Q ) THEN SelectProgram := Fail(Code := 1107); END_IF

(* ===== OBJECT MeasCmd ===== *)
(* ===== DECLARATION ===== *)
METHOD MeasCmd : DINT
VAR_INPUT
  CmdSetting : OC_NexeedBursterResis2316Base.BursterResis2316BaseSetting;
  rResult : REFERENCE TO OC_NexeedBursterResis2316Base.BursterResis2316BaseResult;
END_VAR
VAR _ret : DINT; END_VAR
(* ===== IMPLEMENTATION ===== *)
MeasCmd := RUNNING;
IF ( ErrorCode <> 0 ) OR ( CleanupBlocked )
THEN MeasCmd := HAS_ERROR; RETURN; END_IF
IF ( ( _measPrep = 0 ) AND ( Operation <> 0 ) AND ( Operation <> 3 ) ) OR
   ( ( _measPrep = 1 ) AND ( Operation <> 0 ) AND ( Operation <> 1 ) ) OR
   ( ( _measPrep = 2 ) AND ( Operation <> 0 ) AND ( Operation <> 2 ) )
THEN MeasCmd := Fail(Code := 1201); RETURN; END_IF
IF ( NOT __ISVALIDREF(rResult) )
THEN MeasCmd := Fail(Code := 1202); RETURN; END_IF
IF ( Operation = 0 ) AND ( _measPrep = 0 )
THEN
  IF ( RequestedProgramNo < 0 ) OR ( RequestedProgramNo > 15 ) OR
     ( MeasurementTimeout < T#1S ) OR
     ( MeasurementTimeout > T#120S )
  THEN MeasCmd := Fail(Code := 1203); RETURN; END_IF
  // Standard Unit manual SINGLE_MEAS also uses this entry point. It must not
  // depend on an earlier automatic N045 selection or a still-open stream.
  _measPrep := 1;
  _measProgram := RequestedProgramNo;
  ResultValid := FALSE;
  _setting := CmdSetting;
  _measTimeout := MeasurementTimeout;
  _result.OutOfLimit := TRUE;
  _result.Resistance := 0.0;
  _result.Temperature := 0.0;
  rResult := _result;
  _measureTimer(IN := FALSE, PT := _measTimeout);
  _pollTimer(IN := FALSE, PT := T#50MS);
END_IF
_measureTimer(IN := TRUE, PT := _measTimeout);
IF ( _measureTimer.Q ) THEN MeasCmd := Fail(Code := 1211); RETURN; END_IF
IF ( RequestedProgramNo <> _measProgram )
THEN MeasCmd := Fail(Code := 1212); RETURN; END_IF
CASE _measPrep OF
  1:
    _ret := Open();
    IF ( _ret < OK ) THEN MeasCmd := HAS_ERROR; RETURN; END_IF
    IF ( _ret = OK ) THEN _measPrep := 2; END_IF
    RETURN;
  2:
    IF ( NOT SelectionVerified ) OR ( SelectedProgram <> _measProgram ) OR
       ( Operation = 2 )
    THEN
      _ret := SelectProgram(ProgramNo := _measProgram);
      IF ( _ret < OK ) THEN MeasCmd := HAS_ERROR; RETURN; END_IF
      IF ( _ret = RUNNING ) THEN RETURN; END_IF
    END_IF
    _measPrep := 0;
    Operation := 3;
    Phase := 0;
END_CASE
CASE Phase OF
  0:
    // N045's verified selection is reused, not recalled a second time under
    // load. Fresh readback still rejects an instrument-side program change.
    _ret := Exchange(CommandText := '*RCL?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN MeasCmd := Fail(Code := 1213); RETURN; END_IF
      IF ( _reg <> INT_TO_UINT(_measProgram) )
      THEN MeasCmd := Fail(Code := 1213); RETURN; END_IF
      Phase := 1;
    END_IF
  1:
    _ret := Exchange(CommandText := 'S:O:C?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN MeasCmd := Fail(Code := 1204); RETURN; END_IF
      IF ( ( _reg AND 16 ) <> 0 )
      THEN MeasCmd := Fail(Code := 1205); RETURN; END_IF
      IF ( ( _reg AND 256 ) <> 0 ) THEN Phase := 5; ELSE Phase := 10; END_IF
    END_IF
  5:
    // Drain one previously unread value. It never becomes this result.
    _ret := Exchange(CommandText := 'FETC?', Query := TRUE);
    IF ( _ret = OK ) THEN Phase := 6; END_IF
  6:
    _ret := Exchange(CommandText := 'S:O:C?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN MeasCmd := Fail(Code := 1204); RETURN; END_IF
      IF ( ( _reg AND 272 ) <> 0 )
      THEN MeasCmd := Fail(Code := 1206); RETURN; END_IF
      Phase := 10;
    END_IF
  10:
    _ret := Exchange(CommandText := 'INIT:CONT 0', Query := FALSE);
    IF ( _ret = OK ) THEN Phase := 20; END_IF
  20:
    // Set before the first write: even a lost ACK can mean INIT executed.
    _measureMayRun := TRUE;
    _ret := Exchange(CommandText := 'INIT', Query := FALSE);
    IF ( _ret = OK )
    THEN
      MeasurementStarts := MeasurementStarts + 1;
      Phase := 30;
    END_IF
  30:
    _ret := Exchange(CommandText := 'S:O:C?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN MeasCmd := Fail(Code := 1204); RETURN; END_IF
      IF ( ( _reg AND 256 ) <> 0 ) AND ( ( _reg AND 16 ) = 0 )
      THEN
        _measureMayRun := FALSE;
        Phase := 40;
      ELSE
        _pollTimer(IN := FALSE, PT := T#50MS);
        Phase := 35;
      END_IF
    END_IF
  35:
    _pollTimer(IN := TRUE, PT := T#50MS);
    IF ( _pollTimer.Q ) THEN Phase := 30; END_IF
  40:
    _ret := Exchange(CommandText := 'S:Q:C?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN MeasCmd := Fail(Code := 1207); RETURN; END_IF
      IF ( ( _reg AND 512 ) <> 0 ) OR
         ( _setting.ReadTemperature AND ( ( _reg AND 16 ) <> 0 ) )
      THEN MeasCmd := Fail(Code := 1208); RETURN; END_IF
      Phase := 50;
    END_IF
  50:
    _ret := Exchange(CommandText := 'FETC?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 1) )
      THEN MeasCmd := Fail(Code := 1209); RETURN; END_IF
      _result.Resistance := _value;
      IF ( _setting.ReadTemperature ) THEN Phase := 60; ELSE Phase := 70; END_IF
    END_IF
  60:
    _ret := Exchange(CommandText := 'SENS:TCOM:TEMP?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 2) )
      THEN MeasCmd := Fail(Code := 1210); RETURN; END_IF
      _result.Temperature := _value;
      Phase := 70;
    END_IF
  70:
    _result.OutOfLimit := FALSE;
    rResult := _result;
    ResultValid := TRUE;
    Operation := 0;
    Phase := 0;
    _measureTimer(IN := FALSE, PT := _measTimeout);
    MeasCmd := OK;
    RETURN;
END_CASE
IF ( _ret < OK ) THEN MeasCmd := HAS_ERROR; END_IF
IF ( _measureTimer.Q ) THEN MeasCmd := Fail(Code := 1211); END_IF

(* ===== OBJECT SetRangeCmd ===== *)
(* ===== DECLARATION ===== *)
METHOD SetRangeCmd : DINT
VAR_INPUT CmdSetting : OC_NexeedBursterResis2316Base.BursterResis2316BaseSetting; END_VAR
(* ===== IMPLEMENTATION ===== *)
// Deliberate Station010 scope: the instrument program owns range/compensation.
// A manual SET_RANGE is rejected, never acknowledged without doing the work.
SetRangeCmd := Fail(Code := 1301);

(* ===== OBJECT Cleanup ===== *)
(* ===== DECLARATION ===== *)
METHOD PRIVATE Cleanup : DINT
VAR _ret : DINT; END_VAR
(* ===== IMPLEMENTATION ===== *)
Cleanup := RUNNING;
SelectionVerified := FALSE;
ResultValid := FALSE;
IF ( CleanupBlocked ) THEN Cleanup := HAS_ERROR; RETURN; END_IF
IF ( Operation <> 9 )
THEN
  _measPrep := 0;
  Operation := 9;
  Phase := 0;
  _cleanupPhase := 0;
  _cleanupError := FALSE;
  _cleanupTimer(IN := FALSE, PT := T#10S);
END_IF

_cleanupTimer(IN := TRUE, PT := T#10S);
IF ( _cleanupTimer.Q )
THEN
  // Also covers early returns while draining a pending I/O call.
  CleanupBlocked := TRUE;
  Cleanup := Fail(Code := 1402);
  RETURN;
END_IF
CASE _cleanupPhase OF
  0:
    IF ( _exchangeState <> 0 ) AND ( _exchangeState <> 199 )
    THEN
      // Drain the WHOLE response, not just the pending byte. Otherwise a
      // cancellation status query could consume the previous reply.
      _ret := Exchange(CommandText := LastCommand, Query := _query);
      IF ( _ret = RUNNING ) THEN RETURN; END_IF
      IF ( _ret < OK ) THEN _cleanupError := TRUE; END_IF
    END_IF
    // Finish, not abandon, the exact underlying pending call.
    IF ( _ioKind <> 0 )
    THEN
      _ret := PollIo();
      IF ( _ret = RUNNING ) THEN RETURN; END_IF
      IF ( _ret < OK ) THEN _cleanupError := TRUE; END_IF
    END_IF
    IF ( _exchangeState = 199 ) THEN _cleanupError := TRUE; END_IF
    _exchangeState := 0;
    _exchangeTimer(IN := FALSE, PT := T#3S);
    IF ( _socket.IsOpen ) AND ( _measureMayRun ) AND ( NOT _cleanupError )
    THEN _cleanupPhase := 10;
    ELSE _cleanupPhase := 30; END_IF
  10:
    _ret := Exchange(CommandText := 'S:O:C?', Query := TRUE);
    IF ( _ret = OK )
    THEN
      IF ( NOT ParseNumber(TextValue := LastResponse, Kind := 0) )
      THEN
        _cleanupError := TRUE;
        _cleanupPhase := 30;
      ELSIF ( ( _reg AND 16 ) <> 0 )
      THEN _cleanupPhase := 20;
      ELSE _measureMayRun := FALSE; _cleanupPhase := 30; END_IF
    ELSIF ( _ret < OK )
    THEN
      _cleanupError := TRUE;
      _cleanupPhase := 25;
    END_IF
  20:
    _ret := Exchange(CommandText := 'ABOR', Query := FALSE);
    IF ( _ret = OK )
    THEN _measureMayRun := FALSE; _cleanupPhase := 30;
    ELSIF ( _ret < OK )
    THEN _cleanupError := TRUE; _cleanupPhase := 25; END_IF
  25:
    IF ( _ioKind <> 0 )
    THEN
      _ret := PollIo();
      IF ( _ret = RUNNING ) THEN RETURN; END_IF
    END_IF
    _cleanupPhase := 30;
  30:
    IF ( NOT _socket.IsOpen )
    THEN _cleanupPhase := 50;
    ELSE
      _ioKind := 2;
      _ioPointer := ADR(_eot);
      _ioLength := 1;
      _ioCount := 0;
      _ioTimedOut := FALSE;
      _cleanupPhase := 35;
    END_IF
  35:
    _ret := PollIo();
    IF ( _ret = OK ) AND ( _ioCount = 0 )
    THEN _cleanupPhase := 30;
    ELSIF ( _ret <> RUNNING )
    THEN
      IF ( _ret < OK ) OR ( _ioCount <> 1 ) THEN _cleanupError := TRUE; END_IF
      _cleanupPhase := 40;
    END_IF
  40:
    // IsOpen guards only starting Close, never completion of a pending Close.
    IF ( NOT _socket.IsOpen ) THEN _cleanupPhase := 50;
    ELSE _ioKind := 4; _ioTimedOut := FALSE; _cleanupPhase := 45; END_IF
  45:
    _ret := PollIo();
    IF ( _ret <> RUNNING )
    THEN
      IF ( _ret < OK ) OR ( _socket.IsOpen ) THEN _cleanupError := TRUE; END_IF
      _cleanupPhase := 50;
    END_IF
  50:
    Connected := _socket.IsOpen;
    _exchangeState := 0;
    _exchangeTimer(IN := FALSE, PT := T#3S);
    _cleanupTimer(IN := FALSE, PT := T#10S);
    _measureTimer(IN := FALSE, PT := _measTimeout);
    Operation := 0;
    Phase := 0;
    IF ( _cleanupError ) OR ( Connected ) OR ( _measureMayRun )
    THEN Cleanup := Fail(Code := 1401);
    ELSE Cleanup := OK; END_IF
    RETURN;
END_CASE

(* ===== OBJECT Close ===== *)
(* ===== DECLARATION ===== *)
METHOD Close : DINT
(* ===== IMPLEMENTATION ===== *)
Close := Cleanup();

(* ===== OBJECT Reset ===== *)
(* ===== DECLARATION ===== *)
METHOD Reset : DINT
(* ===== IMPLEMENTATION ===== *)
Reset := Cleanup();

(* ===== OBJECT ClearError ===== *)
(* ===== DECLARATION ===== *)
METHOD ClearError : DINT
VAR
  _ret : DINT;
  _currentSocketError : OpconDeviceError;
END_VAR
(* ===== IMPLEMENTATION ===== *)
ClearError := RUNNING;
IF ( CleanupBlocked ) THEN ClearError := HAS_ERROR; RETURN; END_IF
IF ( Operation <> 10 )
THEN
  _ret := Cleanup();
  IF ( _ret <> OK ) THEN ClearError := _ret; RETURN; END_IF
  Operation := 10;
  _operationTimer(IN := FALSE, PT := T#5S);
  // Do not invoke the library's ClearError after every successful Close.
  _currentSocketError := _socket.LastError;
  IF ( _currentSocketError.Number = 0 )
  THEN
    ErrorCode := 0;
    OpconMemSet(ADR(LastSocketError), 0, SIZEOF(LastSocketError));
    Operation := 0;
    ClearError := OK;
    RETURN;
  END_IF
  _ioKind := 5;
  _ioTimedOut := FALSE;
END_IF
_operationTimer(IN := TRUE, PT := T#5S);
_ret := PollIo();
IF ( _ret = OK )
THEN
  ErrorCode := 0;
  OpconMemSet(ADR(LastSocketError), 0, SIZEOF(LastSocketError));
  Operation := 0;
  _operationTimer(IN := FALSE, PT := T#5S);
  ClearError := OK;
ELSIF ( _ret < OK )
THEN
  ClearError := HAS_ERROR;
  Operation := 0;
ELSIF ( _operationTimer.Q )
THEN
  CleanupBlocked := TRUE;
  ClearError := Fail(Code := 1403);
END_IF

(* ===== OBJECT LastError ===== *)
(* ===== DECLARATION ===== *)
PROPERTY LastError : OC_OpconBaseCommonDef.OpconDeviceError
(* ===== IMPLEMENTATION ===== *)

(* ===== OBJECT LastError/Get ===== *)
(* ===== DECLARATION ===== *)
VAR
END_VAR
(* ===== IMPLEMENTATION ===== *)
LastError := LastSocketError;
