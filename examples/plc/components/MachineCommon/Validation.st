(* ===== DECLARATION ===== *)
PROGRAM PLC_PRG
VAR
  Button : MachineCommon.FB_OperatorButton;
  Pressure : MachineCommon.FB_MainPressureControl;
  Doors : MachineCommon.FB_MaintenanceDoorControl;
  WaitTimer : TON;
  Stage : INT;
  PassedChecks : INT;
  FailedMask : DWORD;
  Done : BOOL;
  CheckNow : BOOL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// Simulation-only fixture: no I/O mappings, network connections or physical outputs.
WaitTimer(IN := ( Stage = 5 ) OR ( Stage = 9 ) OR ( Stage = 12 ) OR ( Stage = 15 ), PT := T#120MS);
CASE Stage OF
0:
  Button(Execute := FALSE, ButtonPressed := FALSE, Blink500ms := FALSE);
  IF ( NOT Button.Done AND NOT Button.LampOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 0);
  END_IF
  Stage := 1;
1:
  Button(Execute := TRUE, ButtonPressed := FALSE, Blink500ms := TRUE);
  IF ( NOT Button.Done AND Button.LampOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 1);
  END_IF
  Stage := 2;
2:
  Button(Execute := TRUE, ButtonPressed := TRUE, Blink500ms := TRUE);
  IF ( Button.Done AND NOT Button.LampOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 2);
  END_IF
  Stage := 3;
3:
  Button(Execute := TRUE, ButtonPressed := FALSE, Blink500ms := FALSE);
  IF ( Button.Done AND NOT Button.LampOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 3);
  END_IF
  Stage := 4;
4:
  Button(Execute := FALSE);
  Pressure(xMonitoringEnabled := TRUE, xControlOnOk := TRUE, xValveRelease := TRUE, xPressureLow := TRUE, xPressureHigh := FALSE, tMonitoringTime := T#50MS);
  IF ( NOT Button.Done AND Pressure.xValveOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 4);
  END_IF
  Stage := 5;
5:
  Pressure(xPressureLow := FALSE, xPressureHigh := FALSE);
  IF ( WaitTimer.Q ) THEN
    IF ( Pressure.xFaultPressureNotHigher AND NOT Pressure.xValveOn ) THEN
      PassedChecks := PassedChecks + 1;
    ELSE
      FailedMask := FailedMask OR SHL(DWORD#1, 5);
    END_IF
    Stage := 6;
  END_IF
6:
  Pressure(xControlOnOk := FALSE, xPressureLow := TRUE, xPressureHigh := FALSE);
  IF ( NOT Pressure.xFaultPressureNotHigher AND NOT Pressure.xFaultPressureNotLower ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 6);
  END_IF
  Stage := 7;
7:
  Pressure(xControlOnOk := TRUE, xValveRelease := TRUE, xPressureLow := TRUE, xPressureHigh := FALSE);
  IF ( Pressure.xValveOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 7);
  END_IF
  Stage := 8;
8:
  Pressure(xPressureLow := FALSE, xPressureHigh := TRUE);
  IF ( Pressure.xPressureReady ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 8);
  END_IF
  Stage := 9;
9:
  Pressure(xControlOnOk := FALSE, xPressureLow := FALSE, xPressureHigh := TRUE);
  IF ( WaitTimer.Q ) THEN
    IF ( Pressure.xFaultPressureNotLower AND NOT Pressure.xValveOn ) THEN
      PassedChecks := PassedChecks + 1;
    ELSE
      FailedMask := FailedMask OR SHL(DWORD#1, 9);
    END_IF
    Stage := 10;
  END_IF
10:
  Pressure(xPressureLow := TRUE, xPressureHigh := FALSE);
  IF ( NOT Pressure.xFaultPressureNotLower ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 10);
  END_IF
  Stage := 11;
11:
  Doors(xEnable := TRUE, xControlOnRequest := TRUE, xControlOnOk := FALSE, xDoorAClosed := FALSE, xDoorBClosed := TRUE, xMaintenanceRelayFeedback := FALSE, tLockMonitoringTime := T#50MS, tRelayMonitoringTime := T#50MS);
  IF ( Doors.xDoorLockAOn AND Doors.xDoorLockBOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 11);
  END_IF
  Stage := 12;
12:
  Doors();
  IF ( WaitTimer.Q ) THEN
    IF ( Doors.xFaultDoorANotClosed AND Doors.xFaultDoorNotLocked AND NOT Doors.xFaultDoorBNotClosed AND NOT Doors.xMainPressureRelease ) THEN
      PassedChecks := PassedChecks + 1;
    ELSE
      FailedMask := FailedMask OR SHL(DWORD#1, 12);
    END_IF
    Stage := 13;
  END_IF
13:
  Doors(xControlOnRequest := FALSE);
  IF ( NOT Doors.xFaultDoorNotLocked AND NOT Doors.xDoorLockAOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 13);
  END_IF
  Stage := 14;
14:
  Doors(xControlOnRequest := TRUE, xDoorAClosed := TRUE, xDoorBClosed := TRUE, xMaintenanceRelayFeedback := FALSE);
  IF ( NOT Doors.xMainPressureRelease ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 14);
  END_IF
  Stage := 15;
15:
  Doors();
  IF ( WaitTimer.Q ) THEN
    IF ( Doors.xFaultRelayFeedbackMissing AND Doors.xFaultDoorNotLocked AND NOT Doors.xMainPressureRelease ) THEN
      PassedChecks := PassedChecks + 1;
    ELSE
      FailedMask := FailedMask OR SHL(DWORD#1, 15);
    END_IF
    Stage := 16;
  END_IF
16:
  Doors(xControlOnRequest := FALSE);
  IF ( NOT Doors.xFaultDoorNotLocked AND NOT Doors.xFaultRelayFeedbackMissing ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 16);
  END_IF
  Stage := 17;
17:
  Doors(xControlOnRequest := TRUE, xMaintenanceRelayFeedback := TRUE);
  IF ( Doors.xMainPressureRelease ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 17);
  END_IF
  Stage := 18;
18:
  Doors(xEnable := FALSE);
  Pressure(xMonitoringEnabled := FALSE);
  IF ( NOT Doors.xMainPressureRelease AND NOT Doors.xDoorLockAOn AND NOT Pressure.xValveOn ) THEN
    PassedChecks := PassedChecks + 1;
  ELSE
    FailedMask := FailedMask OR SHL(DWORD#1, 18);
  END_IF
  Stage := 19;
19:
  Done := TRUE;
END_CASE
