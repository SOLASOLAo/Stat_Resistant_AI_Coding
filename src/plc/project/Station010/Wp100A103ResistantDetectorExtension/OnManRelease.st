// The instrument program owns range/compensation. Do not offer a manual
// SET_RANGE command which this driver deliberately does not implement.
ReleaseSetRange := CommonManRelease AND FALSE;
ReleaseStartMeas := CommonManRelease AND TRUE;
