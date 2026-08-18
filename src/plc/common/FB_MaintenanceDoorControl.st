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
  /// Maximum time for both lock feedbacks to become active
  tLockMonitoringTime : TIME := T#5S;
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
  /// Latched fault: both maintenance doors were not locked in time
  xFaultDoorNotLocked   : BOOL;
END_VAR
VAR
  _timerDoorLock : TON;
END_VAR

(* ===== IMPLEMENTATION ===== *)
// This FB contains no project BMKs. The caller connects the two lock
// outputs, two feedbacks and the standard ControlOn signals.
IF NOT xEnable
THEN
  _timerDoorLock(IN := FALSE, PT := tLockMonitoringTime);

  xDoorLockAOn         := FALSE;
  xDoorLockBOn         := FALSE;
  xAllDoorsClosed      := FALSE;
  xMainPressureRelease := FALSE;
  xFaultDoorNotLocked  := FALSE;
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
  xFaultDoorNotLocked := TRUE;
END_IF

// Keep the fault latched until the lock request has been removed. This gives
// the Station event the same deliberate Control Off/reset lifecycle as the
// main-pressure faults.
IF NOT xDoorLockAOn
   AND NOT xDoorLockBOn
THEN
  xFaultDoorNotLocked := FALSE;
END_IF

// Pressure is released only when both commanded locks and both independent
// closed feedbacks are present. A latched timeout requires Control Off before
// a new pressure-on attempt.
xMainPressureRelease := xDoorLockAOn
                        AND xDoorLockBOn
                        AND xAllDoorsClosed
                        AND NOT xFaultDoorNotLocked;
