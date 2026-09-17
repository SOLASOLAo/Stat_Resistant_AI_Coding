(* ===== DECLARATION ===== *)
PROGRAM PLC_PRG
VAR
  Driver : Burster2316.Burster2316Peripheral;
  Channel : OC_NexeedBursterResis2316Base.IBursterResis2316;
  Peripheral : OC_OpconBaseCommonDef.IOpconPeripheral;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// The body is inert. This consumer does not open a connection or start a test.
Driver(Hostname := '', RequestedProgramNo := 0, MeasurementTimeout := T#30S);
Channel := Driver.Channel;
Peripheral := Driver;
Peripheral.OnInitHierarchy();
Peripheral.UpdateInputs(Configuration := FALSE, OnlineChange := FALSE);
Peripheral.UpdateOutputs();
