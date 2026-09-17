(* Native CpStudio Peripheral facade. The inherited protocol implementation
   and its one-socket lifecycle are unchanged. *)
(* ===== OBJECT Burster2316Peripheral ===== *)
(* ===== DECLARATION ===== *)
FUNCTION_BLOCK Burster2316Peripheral EXTENDS FB_Wp100BursterSingleOwner IMPLEMENTS OC_OpconBaseCommonDef.IOpconPeripheral
(* ===== IMPLEMENTATION ===== *)
// All communication is performed by the inherited explicit command methods.

(* ===== OBJECT OnInitHierarchy ===== *)
(* ===== DECLARATION ===== *)
METHOD OnInitHierarchy
(* ===== IMPLEMENTATION ===== *)
// No bus image or child peripherals. Configuration is supplied by CpStudio.

(* ===== OBJECT UpdateInputs ===== *)
(* ===== DECLARATION ===== *)
METHOD UpdateInputs
VAR_INPUT
    Configuration : BOOL;
    OnlineChange : BOOL;
END_VAR
(* ===== IMPLEMENTATION ===== *)
// The explicit Channel command polls the one socket. Do not advance it twice.
// In particular, a configuration pulse must not replay a measurement.

(* ===== OBJECT UpdateOutputs ===== *)
(* ===== DECLARATION ===== *)
METHOD UpdateOutputs
(* ===== IMPLEMENTATION ===== *)
// No cyclic bus outputs; Channel commands own all socket writes.

(* ===== OBJECT Channel ===== *)
(* ===== DECLARATION ===== *)
PROPERTY Channel : OC_NexeedBursterResis2316Base.IBursterResis2316
(* ===== IMPLEMENTATION ===== *)

(* ===== OBJECT Channel/Get ===== *)
(* ===== DECLARATION ===== *)
VAR
END_VAR
(* ===== IMPLEMENTATION ===== *)
Channel := THIS^;
