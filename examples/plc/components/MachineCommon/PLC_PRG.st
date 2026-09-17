(* ===== DECLARATION ===== *)
PROGRAM PLC_PRG
VAR
  Button : MachineCommon.FB_OperatorButton;
  Pressure : MachineCommon.FB_MainPressureControl;
  Doors : MachineCommon.FB_MaintenanceDoorControl;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// Offline consumer: no I/O mapping or physical outputs.
Button(Execute := FALSE, ButtonPressed := FALSE, Blink500ms := FALSE);
Pressure(xMonitoringEnabled := FALSE, xControlOnOk := FALSE,
  xValveRelease := FALSE, xPressureLow := TRUE, xPressureHigh := FALSE);
Doors(xEnable := FALSE, xControlOnRequest := FALSE, xControlOnOk := FALSE,
  xDoorAClosed := FALSE, xDoorBClosed := FALSE,
  xMaintenanceRelayFeedback := FALSE);
