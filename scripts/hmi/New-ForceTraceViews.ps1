[CmdletBinding()]
param([Parameter(Mandatory)][string]$LeftTraceItem,[Parameter(Mandatory)][string]$MiddleTraceItem,
 [Parameter(Mandatory)][string]$RightTraceItem,[Parameter(Mandatory)][string]$StatisticsItem,
 [string]$TextGroup='Station',[string]$SaveDirectory='C:\OpconData\ForceTraces',[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(Test-Path -LiteralPath $OutputPath){throw 'Use a new output directory.'}
$view=[xml][IO.File]::ReadAllText((Join-Path $repo 'src/hmi/Bpp.ForceTrace/ForceTrace.sfc'))
$control=$view.SelectSingleNode('//*[local-name()="ForceTraceView"]')
foreach($name in @('LeftTraceItem','MiddleTraceItem','RightTraceItem','StatisticsItem')){
 $value=Get-Variable -Name $name -ValueOnly
 if([string]::IsNullOrWhiteSpace($value)){throw "Specify $name from the generated HMI item picker."}
 $control.SelectSingleNode("*[local-name()='property.$name']").SetAttribute('Name',$value)
}
$control.SetAttribute('TextGroup',$TextGroup);$control.SetAttribute('SaveDirectory',$SaveDirectory)
[void][IO.Directory]::CreateDirectory($OutputPath);$view.Save((Join-Path $OutputPath 'ForceTrace.sfc'))
[pscustomobject]@{Status='PREPARED';Output=$OutputPath;NativeLoaderVerificationRequired=$true;HiddenStartupRequired=$false}
