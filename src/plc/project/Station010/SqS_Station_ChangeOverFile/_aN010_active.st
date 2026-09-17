// Show user guidance view. A retained request for this same view is reusable.
// A request for another view must still be handled by its owner.
IF ( Station.Extension.StationViewRequest = '' ) OR
   ( Station.Extension.StationViewRequest = 'ChgOvGuidanceView' )
THEN
  Station.Extension.StationViewRequest := 'ChgOvGuidanceView';

  OpconMemSet(ADR(Station.ChgOvGuidance.ParImm), 0, SIZEOF(Station.ChgOvGuidance.ParImm));
  Station.ChgOvGuidance.ParImm.CurrentStep := ChgOvGuidanceStepsEnum.SELECT_NEW_TYPE;

  _retVal := OK;
END_IF
