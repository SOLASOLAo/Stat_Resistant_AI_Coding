TYPE ForceTraceParCfg :
STRUCT
  rData : REFERENCE TO ForceTraceData;
  rForceN : REFERENCE TO REAL;
  rQualityGood : REFERENCE TO BOOL;
  rMeasuring : REFERENCE TO BOOL;
  rThresholdN : REFERENCE TO REAL;
  rLimitN : REFERENCE TO REAL;
  rWindowMs : REFERENCE TO DINT;
  rTimeoutMs : REFERENCE TO DINT;
  // Actual cyclic caller period; configuration only, does not change the task.
  SamplePeriodMs : DINT := 6;
END_STRUCT
END_TYPE
