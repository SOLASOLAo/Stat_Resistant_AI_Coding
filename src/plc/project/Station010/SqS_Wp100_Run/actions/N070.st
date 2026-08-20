// StationData.PressDelayTime is interpreted as milliseconds.
IF ( Station.StationData.PressDelayTime <= 0 )
THEN
  _pressDelay(IN := FALSE, PT := T#0MS);
  _retVal := OK;
ELSE
  _pressDelay(
    IN := TRUE,
    PT := DINT_TO_TIME(Station.StationData.PressDelayTime)
  );

  IF ( _pressDelay.Q )
  THEN
    _pressDelay(
      IN := FALSE,
      PT := DINT_TO_TIME(Station.StationData.PressDelayTime)
    );
    _retVal := OK;
  END_IF
END_IF
