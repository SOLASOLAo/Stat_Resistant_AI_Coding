// AI_HMI_RESISTANCE_BEGIN
// Publish retained parent-chain results, including while the sequence is idle.
// N000 clears the parent result; only display values are converted from Ohm.
Station.HMIResistance._HmiResistanceLeftValid := Wp100.SqC_Run.Result.Left.Resistance.Valid;
Station.HMIResistance._HmiResistanceLeftOk :=
  ( Wp100.SqC_Run.Result.Left.Resistance.Valid ) AND
  ( Wp100.SqC_Run.Result.Left.Resistance.Ok );
Station.HMIResistance._HmiResistanceLeft_mOhm := 0.0;
IF ( Wp100.SqC_Run.Result.Left.Resistance.Valid )
THEN
  Station.HMIResistance._HmiResistanceLeft_mOhm := Wp100.SqC_Run.Result.Left.Resistance.Value * 1000.0;
END_IF

Station.HMIResistance._HmiResistanceMiddleValid := Wp100.SqC_Run.Result.Middle.Resistance.Valid;
Station.HMIResistance._HmiResistanceMiddleOk :=
  ( Wp100.SqC_Run.Result.Middle.Resistance.Valid ) AND
  ( Wp100.SqC_Run.Result.Middle.Resistance.Ok );
Station.HMIResistance._HmiResistanceMiddle_mOhm := 0.0;
IF ( Wp100.SqC_Run.Result.Middle.Resistance.Valid )
THEN
  Station.HMIResistance._HmiResistanceMiddle_mOhm := Wp100.SqC_Run.Result.Middle.Resistance.Value * 1000.0;
END_IF

Station.HMIResistance._HmiResistanceRightValid := Wp100.SqC_Run.Result.Right.Resistance.Valid;
Station.HMIResistance._HmiResistanceRightOk :=
  ( Wp100.SqC_Run.Result.Right.Resistance.Valid ) AND
  ( Wp100.SqC_Run.Result.Right.Resistance.Ok );
Station.HMIResistance._HmiResistanceRight_mOhm := 0.0;
IF ( Wp100.SqC_Run.Result.Right.Resistance.Valid )
THEN
  Station.HMIResistance._HmiResistanceRight_mOhm := Wp100.SqC_Run.Result.Right.Resistance.Value * 1000.0;
END_IF
// AI_HMI_RESISTANCE_END
