(* ===== DECLARATION ===== *)
PROGRAM PLC_PRG
VAR
  Recorder : ForceTrace.FB_HmiForceTrace;
  Statistics : ForceTrace.FB_PressForceStatistics;
  TraceData : ForceTrace.ForceTraceData;
  Addon : ForceTrace.ForceTraceAddon;
  ForceN : REAL := 2500;
  QualityGood : BOOL := TRUE;
  Measuring : BOOL;
  ThresholdN : REAL := 2500;
  LimitN : REAL := 0;
  WindowMs : DINT := 1000;
  TimeoutMs : DINT := 30000;
  SamplePeriodMs : DINT := 6; // Must match the calling PLC task, not an HMI timer.
END_VAR
(* ===== IMPLEMENTATION ===== *)
// In CpStudio these references are generated from its variable selectors.
Addon.ParCfg.rData REF= TraceData;
Addon.ParCfg.rForceN REF= ForceN;
Addon.ParCfg.rQualityGood REF= QualityGood;
Addon.ParCfg.rMeasuring REF= Measuring;
Addon.ParCfg.rThresholdN REF= ThresholdN;
Addon.ParCfg.rLimitN REF= LimitN;
Addon.ParCfg.rWindowMs REF= WindowMs;
Addon.ParCfg.rTimeoutMs REF= TimeoutMs;
Addon.ParCfg.SamplePeriodMs := SamplePeriodMs;
// Addon lifecycle is called by the OpCon hierarchy in the native reference.
// Standalone PLC consumers can call Recorder and Statistics independently.
Recorder(Measuring := FALSE, QualityGood := QualityGood, ForceN := ForceN);
Recorder.Configure(ThresholdN := ThresholdN, LimitN := LimitN,
  WindowMs := DINT_TO_UDINT(WindowMs), TimeoutMs := DINT_TO_UDINT(TimeoutMs),
  SamplePeriodMs := DINT_TO_UDINT(SamplePeriodMs));
