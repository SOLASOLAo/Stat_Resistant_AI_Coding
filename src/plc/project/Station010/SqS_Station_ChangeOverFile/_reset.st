// Release only the HMI requests used by this changeover chain.
IF ( Station.Extension.StationDialogRequest = 'DataFileDialog' )
THEN
  Station.Extension.StationDialogRequest := '';
END_IF

IF ( Station.Extension.StationViewRequest = 'ChgOvGuidanceView' )
THEN
  Station.Extension.StationViewRequest := '';
END_IF
