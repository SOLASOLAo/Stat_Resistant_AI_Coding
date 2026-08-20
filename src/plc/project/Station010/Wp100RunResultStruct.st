{attribute 'OPC.UA.DA.StructuredType':='1'}
TYPE Wp100RunResultStruct :
STRUCT
  /// Fixture position requested for this execution
  MeasurePos           : MeasurePsoEnum;
  /// TRUE after the requested position has passed the three-sensor one-hot check
  FixturePositionValid : BOOL;
  /// Burster resistance measurement result
  Resistance           : Wp100ResistanceResultStruct;
  /// Kistler force/stroke measurement result
  Kistler              : Wp100KistlerResultStruct;
END_STRUCT
END_TYPE
