[CmdletBinding()]
param(
  [ValidateSet('PlanOnly','Apply')][string]$Mode='PlanOnly',
  [switch]$Integrate,
  [string]$ExpectedPlanSha256='',
  [string]$ReportPath='',
  [string]$BaseUri='http://localhost:9002/plc/engineering/api/v2'
)
# Native Peripheral/compiled-library owns this driver now. This compatibility
# entry point verifies the installed integration and cannot restore local FBs.
$ErrorActionPreference='Stop'
$result = & (Join-Path $PSScriptRoot '../../tests/static/Test-StationNativeBindings.ps1') -BaseUri $BaseUri -Scope Burster
$report = [ordered]@{mode=$Mode;phase='native-library';mutationCount=0;changedObjects=0;checks=$result;onlineOperations=$false}
$json=$report | ConvertTo-Json -Depth 10
if($ReportPath){[IO.File]::WriteAllText([IO.Path]::GetFullPath($ReportPath),$json,[Text.UTF8Encoding]::new($false))}
$json
