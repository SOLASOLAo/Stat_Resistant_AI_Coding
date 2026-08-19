(*
  Canonical AI-owned POU source.
  Deploy only through PLC Engineering MCP and verify by readback + compile.
*)

(* ===== DECLARATION ===== *)
FUNCTION_BLOCK FB_MaintenanceDoorControl
VAR_INPUT
  /// Cyclic execution enable; normally Station OPERATIONAL and fieldbus OK
  xEnable             : BOOL;
  /// Raw Control On push-button request
  xControlOnRequest   : BOOL;
  /// Confirmed electrical Control On state; keeps both locks energized
  xControlOnOk        : BOOL;
  /// Feedback: maintenance door A is closed
  xDoorAClosed        : BOOL;
  /// Feedback: maintenance door B is closed
  xDoorBClosed        : BOOL;
  /// Feedback: maintenance-door safety relay is energized
  xMaintenanceRelayFeedback : BOOL;
  /// Maximum time for both lock feedbacks to become active
  tLockMonitoringTime : TIME := T#5S;
  /// Maximum delay from both doors closed to safety-relay feedback
  tRelayMonitoringTime : TIME := T#1S;
END_VAR
VAR_OUTPUT
  /// Command for maintenance door A lock
  xDoorLockAOn          : BOOL;
  /// Command for maintenance door B lock
  xDoorLockBOn          : BOOL;
  /// TRUE only when both maintenance-door closed feedbacks are active
  xAllDoorsClosed       : BOOL;
  /// Additional release for the main-pressure valve
  xMainPressureRelease  : BOOL;
  /// Latched aggregate maintenance-door interlock fault
  xFaultDoorNotLocked   : BOOL;
  /// Latched detail: maintenance door A closed feedback was missing
  xFaultDoorANotClosed  : BOOL;
  /// Latched detail: maintenance door B closed feedback was missing
  xFaultDoorBNotClosed  : BOOL;
  /// Latched detail: safety-relay feedback was missing after both doors closed
  xFaultRelayFeedbackMissing : BOOL;
END_VAR
VAR
  _timerDoorLock      : TON;
  _timerRelayFeedback : TON;
END_VAR

(* ===== IMPLEMENTATION ===== *)
// This FB contains no project BMKs. The caller connects the two lock
// outputs, two feedbacks and the standard ControlOn signals.
IF NOT xEnable
THEN
  _timerDoorLock(IN := FALSE, PT := tLockMonitoringTime);
  _timerRelayFeedback(IN := FALSE, PT := tRelayMonitoringTime);

  xDoorLockAOn         := FALSE;
  xDoorLockBOn         := FALSE;
  xAllDoorsClosed      := FALSE;
  xMainPressureRelease := FALSE;
  xFaultDoorNotLocked  := FALSE;
  xFaultDoorANotClosed := FALSE;
  xFaultDoorBNotClosed := FALSE;
  xFaultRelayFeedbackMissing := FALSE;
  RETURN;
END_IF

// Energize both locks while the operator presses Control On. Once the
// electrical Control On feedback is present, keep the locks energized after
// the momentary push-button is released.
xDoorLockAOn := xControlOnRequest OR xControlOnOk;
xDoorLockBOn := xControlOnRequest OR xControlOnOk;

xAllDoorsClosed := xDoorAClosed AND xDoorBClosed;

// Start one shared monitoring time as soon as both lock outputs are requested.
// A loss of either feedback while Control On remains active starts the same
// monitoring again.
_timerDoorLock(
  IN := xDoorLockAOn
        AND xDoorLockBOn
        AND NOT xAllDoorsClosed,
  PT := tLockMonitoringTime
);

IF _timerDoorLock.Q
THEN
  IF NOT xDoorAClosed
  THEN
    xFaultDoorANotClosed := TRUE;
  END_IF

  IF NOT xDoorBClosed
  THEN
    xFaultDoorBNotClosed := TRUE;
  END_IF
END_IF

// Once both door-closed inputs are present, the maintenance safety relay must
// confirm the electrical safety circuit within one second.
_timerRelayFeedback(
  IN := xDoorLockAOn
        AND xDoorLockBOn
        AND xAllDoorsClosed
        AND NOT xMaintenanceRelayFeedback,
  PT := tRelayMonitoringTime
);

IF _timerRelayFeedback.Q
THEN
  xFaultRelayFeedbackMissing := TRUE;
END_IF

// Keep the fault latched until the lock request has been removed. This gives
// the Station event the same deliberate Control Off/reset lifecycle as the
// main-pressure faults.
IF NOT xDoorLockAOn
   AND NOT xDoorLockBOn
THEN
  xFaultDoorANotClosed          := FALSE;
  xFaultDoorBNotClosed          := FALSE;
  xFaultRelayFeedbackMissing    := FALSE;
END_IF

xFaultDoorNotLocked := xFaultDoorANotClosed
                       OR xFaultDoorBNotClosed
                       OR xFaultRelayFeedbackMissing;

// Pressure is released only when both commanded locks and both independent
// closed feedbacks are present. A latched timeout requires Control Off before
// a new pressure-on attempt.
xMainPressureRelease := xDoorLockAOn
                        AND xDoorLockBOn
                        AND xAllDoorsClosed
                        AND xMaintenanceRelayFeedback
                        AND NOT xFaultDoorNotLocked;
