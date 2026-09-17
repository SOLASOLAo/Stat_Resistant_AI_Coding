(* ===== OBJECT ForceTraceAddon ===== *)
(* ===== DECLARATION ===== *)
FUNCTION_BLOCK ForceTraceAddon EXTENDS OC_OpconBase.OpconAddonBase
VAR_INPUT
  ParCfg : ForceTraceParCfg;
END_VAR
VAR_OUTPUT
  Recorder : FB_HmiForceTrace;
  Configured : BOOL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// OpCon owns cyclic dispatch before chains and child units (NxBase >= 1.0.100).

(* ===== OBJECT OnCallEnter ===== *)
(* ===== DECLARATION ===== *)
METHOD PROTECTED OnCallEnter
(* ===== IMPLEMENTATION ===== *)
SUPER^.OnCallEnter();
Configured := ( __ISVALIDREF(ParCfg.rData) ) AND
              ( __ISVALIDREF(ParCfg.rForceN) ) AND
              ( __ISVALIDREF(ParCfg.rQualityGood) ) AND
              ( __ISVALIDREF(ParCfg.rMeasuring) ) AND
              ( __ISVALIDREF(ParCfg.rThresholdN) ) AND
              ( __ISVALIDREF(ParCfg.rLimitN) ) AND
              ( __ISVALIDREF(ParCfg.rWindowMs) ) AND
              ( __ISVALIDREF(ParCfg.rTimeoutMs) );
IF ( NOT Configured )
THEN
  Recorder(Measuring := FALSE, QualityGood := FALSE, ForceN := 0);
  RETURN;
END_IF
Recorder(Measuring := ParCfg.rMeasuring, QualityGood := ParCfg.rQualityGood,
         ForceN := ParCfg.rForceN);
IF ( Recorder.Published )
THEN
  ParCfg.rData.StatisticsFrame := Recorder.StatisticsFrame;
  IF ( Recorder.Cleared ) OR ( Recorder.PublishedPosition = 1 )
  THEN
    ParCfg.rData.LeftFrame := Recorder.LeftFrame;
  END_IF
  IF ( Recorder.Cleared ) OR ( Recorder.PublishedPosition = 2 )
  THEN
    ParCfg.rData.MiddleFrame := Recorder.MiddleFrame;
  END_IF
  IF ( Recorder.Cleared ) OR ( Recorder.PublishedPosition = 3 )
  THEN
    ParCfg.rData.RightFrame := Recorder.RightFrame;
  END_IF
END_IF

(* ===== OBJECT PreparePosition ===== *)
(* ===== DECLARATION ===== *)
METHOD PUBLIC PreparePosition : BOOL
(* ===== IMPLEMENTATION ===== *)
PreparePosition := FALSE;
IF ( NOT Configured )
THEN
  RETURN;
END_IF
Recorder.Configure(ThresholdN := ParCfg.rThresholdN, LimitN := ParCfg.rLimitN,
  WindowMs := DINT_TO_UDINT(ParCfg.rWindowMs),
  TimeoutMs := DINT_TO_UDINT(ParCfg.rTimeoutMs),
  SamplePeriodMs := DINT_TO_UDINT(ParCfg.SamplePeriodMs));
PreparePosition := ( ParCfg.rThresholdN >= 0 ) AND
                   ( ParCfg.rThresholdN <= REAL#3.402823E38 ) AND
                   ( ParCfg.rLimitN > 0 ) AND
                   ( ParCfg.rLimitN <= REAL#3.402823E38 ) AND
                   ( ParCfg.rWindowMs > 0 ) AND
                   ( ParCfg.rWindowMs <= 60000 ) AND
                   ( ParCfg.SamplePeriodMs >= 1 ) AND
                   ( ParCfg.SamplePeriodMs <= 1000 ) AND
                   ( ParCfg.rWindowMs <= ParCfg.SamplePeriodMs * 10000 ) AND
                   ( ParCfg.rTimeoutMs > ParCfg.rWindowMs );
