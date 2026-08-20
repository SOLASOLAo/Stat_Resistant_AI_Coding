FUNCTION_BLOCK SqC_Wp100_Run EXTENDS OpconSfcChain
////<OES_INFO Mode="Merge" Areas="1/1" />
////<OES_CODE MergeId="Declaration">{{{
VAR_INPUT
  rUnit : REFERENCE TO Wp100Unit;
END_VAR
////<END_OES_CODE>}}}

VAR_OUTPUT
  /// Results of the completed left, middle and right atomic measurements
  Result : Wp100RunSequenceResultStruct;
END_VAR

VAR
  /// Handle of the locked product-detection soft error
  _eventIndex          : UDINT;
  /// Bit 0 = _100B701 missing, bit 1 = _100B702 missing
  _partSensorFaultMask : BYTE;
END_VAR
