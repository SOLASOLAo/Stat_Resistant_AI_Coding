// Application-specific Wp100 product-data checks.
// CpStudio owns the generated 0..8 enum checks below this merge area.
IF ( Station.TypeDataNew.Wp100.BursterLowerRange >
     Station.TypeDataNew.Wp100.BursterUpperRange )
THEN
  _onCheckDataMessage :=
    'Station.TypeDataNew.Wp100.BursterLowerRange > BursterUpperRange';
  RETURN;
END_IF

IF ( Station.TypeDataNew.Wp100.BursterLowerLimit >
     Station.TypeDataNew.Wp100.BursterUpperLimit )
THEN
  _onCheckDataMessage :=
    'Station.TypeDataNew.Wp100.BursterLowerLimit > BursterUpperLimit';
  RETURN;
END_IF
