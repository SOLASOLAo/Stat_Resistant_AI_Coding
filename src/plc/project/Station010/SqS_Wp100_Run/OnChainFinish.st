/// Method is called for only one cycle if chain stops working by any given reason
METHOD PROTECTED OnChainFinish
VAR_INPUT
  Reason: OpconChainFinishReason;
END_VAR

// Call base method
SUPER^.OnChainFinish(Reason);

// A cancelled/finished SFC no longer calls its active action. Reset every
// request owned by this chain and leave the stored Result available to caller.
_startButton(
  Execute       := FALSE,
  ButtonPressed := FALSE,
  Blink500ms    := FALSE
);
BinIo._000P610 := _startButton.LampOn;

_pressDelay(IN := FALSE, PT := T#0MS);

Wp100K101SafetyDoor.Unit.Execute       := FALSE;
Wp100K102PressingCylinder.Unit.Execute := FALSE;
Wp100A103ResistantDetector.Unit.Execute := FALSE;
Wp100A104Kistler.Unit.ParImm.EndMeasurement := TRUE;
Wp100A104Kistler.Unit.Execute := FALSE;

_positionValid          := FALSE;
_safetyDoorCloseStarted := FALSE;
_pressDownStarted       := FALSE;
_kistlerStarted         := FALSE;
_bursterStarted         := FALSE;
_pressUpStarted         := FALSE;
_safetyDoorOpenStarted  := FALSE;

CASE Reason
OF
  OpconChainFinishReason.ERROR,
  OpconChainFinishReason.CANCEL,
  OpconChainFinishReason.DONE:
    ;
  ELSE
    ; // do nothing
END_CASE
