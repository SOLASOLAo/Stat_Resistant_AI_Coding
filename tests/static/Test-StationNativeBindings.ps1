[CmdletBinding()]
param(
  [ValidateSet('All','Burster')][string]$Scope='All',
  [string]$BaseUri='http://localhost:9002/plc/engineering/api/v2'
)
# Read-only live engineering contract; does not connect to a PLC or compile.
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$expected=[IO.Path]::GetFullPath((Join-Path $repo '../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project'))
$p=Invoke-RestMethod "$BaseUri/projects/current" -TimeoutSec 15
if($p.path -ine $expected -or $p.profileName -cne 'ctrlX PLC 2.6.8'){throw 'Wrong project/profile'}
$checks=[Collections.Generic.List[string]]::new()
function Node([string]$Path){
  $uri="$BaseUri/devices/Device/Plc%20Logic/"+(($Path -split '/' | ForEach-Object {[Uri]::EscapeDataString($_)}) -join '/')
  Invoke-RestMethod $uri -TimeoutSec 20
}
function Check([bool]$Value,[string]$Description){if(-not $Value){throw $Description};$checks.Add($Description)}
Check ((Node 'Application').isOnline -ceq $false) 'Application is offline'
$peripheral=Node 'Application/Peripherals/Peripherals'
Check ($peripheral.declaration -match '_Burster2316\s*:\s*Burster2316Peripheral\s*;') 'Native uniquely named Burster Peripheral generated'
$wp='Application/Station/Wp100/_this/Wp100Unit'
$binding=(Node "$wp/OnApplyParameters").implementation
Check ($binding -match 'iBursterResis2316\s*:=\s*(?:Peripherals\.)?_Burster2316\s*;') 'Standard Unit channel targets the sole Peripheral'
Check (-not $binding.Contains('AI_BURSTER_SINGLE_OWNER_BINDING')) 'No application override of generated channel'
$ai=(Node 'Application/Fbs/AiWp100').declaration
Check ($ai -notmatch '\bBurster\s*:') 'No duplicate AiWp100 driver instance'
$config=(Node 'Application/Peripherals/PeripheralRoot/OnApplyParameters').implementation
Check ($config -match '(?m)^\s*Peripherals\._Burster2316\.Hostname\s*:=\s*Station\.StationData\.BursterSetting\.HostName\s*;') 'Native Hostname comes from user-configurable StationData'
Check ($config -match '(?m)^\s*Peripherals\._Burster2316\.MeasurementTimeout\s*:=\s*DINT_TO_TIME\(30000\)\s*;') 'Native measurement timeout preserved'
$cyclic=(Node "$wp/OnCall").implementation
Check ($cyclic.Contains('Peripherals._Burster2316.RequestedProgramNo := Station.TypeData.Wp100.Burster.ProgramNo;')) 'Active TypeData program reaches the same driver'
$selector=(Node 'Application/Fbs/FB_Wp100BursterProgramSelect').implementation
Check ($selector.Contains('Peripherals._Burster2316.SelectProgram(') -and -not $selector.Contains('AiWp100.Burster.')) 'Selector delegates to the native single connection owner'
if($Scope -eq 'All'){
  $station=(Node 'Application/Station/_this/Station').declaration
  Check ($station -match 'ForceTrace\s*:\s*ForceTraceData;' -and $station -match 'ForceTraceAddon\s*:\s*ForceTraceAddon;') 'Native ForceTrace data and Add-on generated'
  Check ($station -notmatch '(?m)^\s*(MainPressureControl|MaintenanceDoorControl)\s*:') 'No duplicate pressure or door controller instances'
  $params=(Node 'Application/Station/_this/StationUnit/OnApplyParameters').implementation
  foreach($pair in @(@('rThresholdN','PressForceThreshold'),@('rLimitN','PressForce3SigmaLimit'),@('rWindowMs','PressForceStableTime'),@('rTimeoutMs','PressForceTimeout'))){
    Check ($params -match ('ForceTraceAddon\.ParCfg\.'+$pair[0]+'\s+REF= Station\.StationData\.'+$pair[1]+';')) ('Native StationData binding '+$pair[1])
  }
  $onCall=(Node 'Application/Station/_this/StationUnit/OnCall').implementation
  Check ($onCall.Contains('Station.ForceTraceQualityGood :=') -and $onCall.Contains('Station.ForceTraceMeasuring :=') -and $onCall -notmatch 'Recorder\s*\(') 'OnCall only updates bridges; native Add-on owns cyclic acquisition'
  $order=@('Station.MachineCommonDoor(', 'Station.PressureFeedbackSimulation(', 'Station.MachineCommonPressure(')
  Check ($onCall.IndexOf($order[0]) -ge 0 -and $onCall.IndexOf($order[0]) -lt $onCall.IndexOf($order[1]) -and $onCall.IndexOf($order[1]) -lt $onCall.IndexOf($order[2])) 'Door / previous valve feedback / pressure call order preserved'
  $force=(Node 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/CheckPressForce').implementation
  Check ($force.Contains('Station.ForceTraceAddon.Configured') -and $force.Contains('_stableMs := Station.ForceTraceAddon.ParCfg.rWindowMs;') -and $force.Contains('Station.ForceTraceAddon.Recorder.Evaluate(')) 'Force guard uses configured native references and recorder'
}
[pscustomobject]@{passed=$true;scope=$Scope;checks=@($checks);onlineOperations=$false;freshCompile=$false}
