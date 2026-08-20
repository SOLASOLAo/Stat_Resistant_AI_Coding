{attribute 'OPC.UA.DA.StructuredType':='1'}
TYPE Wp100ResistanceResultStruct :
STRUCT
  /// TRUE after SINGLE_MEAS has completed and the values below have been copied
  Valid      : BOOL;
  OutOfLimit : BOOL;
  Ok         : BOOL;
  Value      : REAL;
  Temperature : REAL;
END_STRUCT
END_TYPE
