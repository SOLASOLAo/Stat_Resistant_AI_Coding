FUNCTION_BLOCK SqS_Wp100_Run EXTENDS OpconSfcChain
////<OES_INFO Mode="Merge" Areas="1/1" />
////<OES_CODE MergeId="Declaration">{{{
VAR_INPUT
  rUnit : REFERENCE TO Wp100Unit;
END_VAR
////<END_OES_CODE>}}}

VAR_OUTPUT
  /// Result remains valid after DONE and is cleared when the next execution starts
  Result : Wp100RunResultStruct;
END_VAR

VAR
  /// Position request latched from Wp100.MeasurePos at the beginning of one execution
  _measurePosLatched     : MeasurePsoEnum;
  _positionValid         : BOOL;
  _startButton           : FB_OperatorButton;
  _safetyDoorCloseStarted : BOOL;
  _pressDownStarted      : BOOL;
  _kistlerStarted        : BOOL;
  _bursterStarted        : BOOL;
  _pressUpStarted        : BOOL;
  _safetyDoorOpenStarted : BOOL;
  _pressDelay            : TON;
  _unitResult            : DINT;
END_VAR
