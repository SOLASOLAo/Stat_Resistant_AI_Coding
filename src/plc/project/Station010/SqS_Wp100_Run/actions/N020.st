// Request operator acknowledgement with the illuminated start button.
CASE MeasurePos OF
  MeasurePsoEnum.LEFT:
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_PRESS_START_LEFT;

  MeasurePsoEnum.MIDDLE:
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_PRESS_START_MIDDLE;

  MeasurePsoEnum.RIGHT:
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_PRESS_START_RIGHT;

  ELSE
    Station._AutoInfoline := AutoInfoLineEnum.USER_INFO_TEXT_CLEAR;
END_CASE

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
