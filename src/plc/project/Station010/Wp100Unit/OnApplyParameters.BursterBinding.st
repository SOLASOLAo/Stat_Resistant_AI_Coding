// AI_BURSTER_SINGLE_OWNER_BINDING_BEGIN
// The optional CpStudio channel MUST remain unassigned. This is the sole
// non-generated binding, using the same lifecycle as other child interfaces.
IF ( Reason = OpconApplyParReason.STARTUP ) OR
   ( Reason = OpconApplyParReason.CONFIGURATION ) OR
   ( Reason = OpconApplyParReason.ONLINE_CHANGE )
THEN
  AiWp100.Burster.Hostname := '192.168.0.103';
  AiWp100.Burster.MeasurementTimeout := T#30S;
  Wp100A103ResistantDetector.Unit.ParCfg.iBursterResis2316 := AiWp100.Burster;
END_IF
// AI_BURSTER_SINGLE_OWNER_BINDING_END
