/// Method is called for only one cycle if chain stops working by any given reason
METHOD PROTECTED OnChainFinish
VAR_INPUT
  Reason: OpconChainFinishReason;
END_VAR

// Call base method first, then reset every child execution owned by this chain.
SUPER^.OnChainFinish(Reason);

CASE Reason OF
  OpconChainFinishReason.ERROR,
  OpconChainFinishReason.CANCEL,
  OpconChainFinishReason.DONE:
    Wp100.SqS_Run.Execute := FALSE;

    IF ( _eventIndex <> 0 )
    THEN
      IF ( UnlockEvent(
           Class := OpconEventClass.SOFTERROR,
           Index := _eventIndex
         ) )
      THEN
        IF ( ClearEvent(
             Class := OpconEventClass.SOFTERROR,
             Index := _eventIndex
           ) )
        THEN
          _eventIndex := 0;
        END_IF
      END_IF
    END_IF

    _partSensorFaultMask := 0;

  ELSE
    ; // do nothing
END_CASE
