// Request operator acknowledgement with the illuminated start button.
_startButton(
  Execute       := TRUE,
  ButtonPressed := BinIo._000S610,
  Blink500ms    := Root.RootNode.FlashBits.Toggle500ms
);

IF ( _startButton.Done )
THEN
  _retVal := OK;

  // Complete the Unit-style Execute handshake immediately so the same
  // instance is initialized before this SFC step can be entered again.
  _startButton(
    Execute       := FALSE,
    ButtonPressed := FALSE,
    Blink500ms    := FALSE
  );
END_IF

BinIo._000P610 := _startButton.LampOn;
