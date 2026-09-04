// Application-specific Wp100 product-data checks.
// CpStudio owns the generated 0..8 enum checks below this merge area.
IF ( Station.TypeDataNew.Wp100.Burster.LowerRange >
     Station.TypeDataNew.Wp100.Burster.UpperRange )
THEN
  _onCheckDataMessage :=
    'Station.TypeDataNew.Wp100.Burster.LowerRange > Burster.UpperRange';
  RETURN;
END_IF

IF ( Station.TypeDataNew.Wp100.Burster.LowerLimit >
     Station.TypeDataNew.Wp100.Burster.UpperLimit )
THEN
  _onCheckDataMessage :=
    'Station.TypeDataNew.Wp100.Burster.LowerLimit > Burster.UpperLimit';
  RETURN;
END_IF

IF ( Station.TypeDataNew.Wp100.Burster.ProgramNo < 0 ) OR
   ( Station.TypeDataNew.Wp100.Burster.ProgramNo > 15 )
THEN
  _onCheckDataMessage :=
    'Station.TypeDataNew.Wp100.Burster.ProgramNo must be 0..15';
  RETURN;
END_IF
