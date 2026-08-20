{attribute 'OPC.UA.DA.StructuredType':='1'}
TYPE Wp100KistlerResultStruct :
STRUCT
  /// TRUE after the MEASURE command has completed and the values below have been copied
  Valid     : BOOL;
  Ok        : BOOL;
  Nok       : BOOL;
  NoPass    : BOOL;
  ProgramNo : BYTE;
  Force     : REAL;
  Stroke    : REAL;
END_STRUCT
END_TYPE
