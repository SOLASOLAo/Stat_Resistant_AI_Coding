TYPE Wp100RunSequenceResultStruct :
STRUCT
  /// Result captured after the left-position atomic measurement
  Left   : Wp100RunResultStruct;
  /// Result captured after the middle-position atomic measurement
  Middle : Wp100RunResultStruct;
  /// Result captured after the right-position atomic measurement
  Right  : Wp100RunResultStruct;
END_STRUCT
END_TYPE
