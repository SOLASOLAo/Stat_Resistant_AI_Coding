// Request operator acknowledgement with the illuminated start button.
_startButton(
  Execute       := TRUE,
  ButtonPressed := BinIo._000S610,
  Blink500ms    := FlashBits.Pulse500ms
);

IF ( _startButton.Done )
THEN
  _retVal := OK;
  _startButton(
    Execute       := FALSE,
    ButtonPressed := FALSE,
    Blink500ms    := FALSE
  );
END_IF

BinIo._000P610 := _startButton.LampOn;
