[CmdletBinding()]
param(
  [ValidateSet('PlanOnly','Apply')][string]$Mode = 'PlanOnly',
  [string]$ExpectedPlanSha256 = '',
  [string]$CheckpointPath = '',
  [switch]$AllowReviewedReplacement,
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2'
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$expectedProject = [IO.Path]::GetFullPath((Join-Path $repo '../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project'))
$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$script:CapturePreflight = $true
$script:PreflightObservations = [ordered]@{}
$script:WriteRequests = [Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot 'SfcRestWriter.Transaction.ps1')
$targets = [ordered]@{}
function Normalize([string]$Text) { $Text.Replace("`r`n","`n").Replace("`r","`n").TrimEnd() + "`n" }
function Get-Sha256([string]$Text) { Get-ExactSha256 (Normalize $Text) }
function ConvertTo-ApiUri([string]$Path) {
  $deviceRoot + '/' + (($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}
function Test-IsNotFoundError($Record) {
  $Record.Exception.Response -and ([int]$Record.Exception.Response.StatusCode -eq 404)
}
function Get-Node([string]$Path) {
  try { $node = Invoke-RestMethod (ConvertTo-ApiUri $Path) -TimeoutSec 20 }
  catch { if (Test-IsNotFoundError $_) { $node = $null } else { throw } }
  Register-PreflightObservation -Path $Path -Node $node
  return $node
}
function Read-Source([string]$Path) {
  Normalize ([IO.File]::ReadAllText((Join-Path $repo "src/plc/project/Station010/$Path")))
}
function Assert-Identity {
  $p = Invoke-RestMethod "$BaseUri/projects/current" -TimeoutSec 15
  if (([IO.Path]::GetFullPath($p.path) -ine $expectedProject) -or ($p.profileName -cne 'ctrlX PLC 2.6.8')) {
    throw 'Wrong project/profile.'
  }
  if ((Invoke-RestMethod (ConvertTo-ApiUri 'Application') -TimeoutSec 15).isOnline -cne $false) {
    throw 'Offline Application required.'
  }
  return $p
}
$hookPattern = '(?ms)^ *// AI_HMI_FORCE_TRACE_BEGIN\r?\n.*?^ *// AI_HMI_FORCE_TRACE_END(?:\r?\n|$)'
function Remove-TraceHook([string]$Text) {
  $matches = [regex]::Matches($Text,$hookPattern)
  if (($matches.Count -gt 1) -or
      ([regex]::Matches($Text,'AI_HMI_FORCE_TRACE_BEGIN').Count -ne $matches.Count) -or
      ([regex]::Matches($Text,'AI_HMI_FORCE_TRACE_END').Count -ne $matches.Count)) { throw 'Ambiguous trace hook.' }
  [regex]::Replace($Text,$hookPattern,'')
}
function Add-HookTarget([string]$Path,[string]$Source,[switch]$Method) {
  $node = Get-Node $Path
  if ($null -eq $node) { throw "Missing generated hook target: $Path" }
  $implementation = Read-Source $Source
  if ($Method) {
    $parts = $implementation -split "`n`n",2
    if (($parts.Count -ne 2) -or ((Get-Sha256 $node.declaration) -cne (Get-Sha256 $parts[0]))) {
      throw "Generated declaration changed: $Path"
    }
    $implementation = $parts[1]
  }
  if ((Normalize (Remove-TraceHook $node.implementation)) -cne (Normalize (Remove-TraceHook $implementation))) {
    throw "Non-logger source differs; refusing to change process logic: $Path"
  }
  $targets[$Path] = @{declaration=$node.declaration;implementation=$implementation}
  if ((Get-Sha256 $node.implementation) -cne (Get-Sha256 $implementation)) {
    Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $Path) -Path $Path -Kind 'merge-force-observation-hook' `
      -Body @{implementation=$implementation} -TargetSha256 (Get-Sha256 $implementation)
  }
}
function Save-CurrentProject {
  $null = Assert-Identity
  $saveJob = Invoke-JsonRequest -Method Post -Uri "$BaseUri/jobs" -Body @{jobType='ProjectJob';jobParameters=@{action='Save'}}
  $saveId = if ($saveJob.id) { $saveJob.id } else { $saveJob.jobId }
  if (-not $saveId) { throw 'Save job missing; inspect before retrying.' }
  $saveDeadline = [DateTime]::UtcNow.AddSeconds(45)
  do {
    $saveJob = Invoke-RestMethod "$BaseUri/jobs/$saveId" -TimeoutSec 10
    if ($saveJob.state -eq 'Done') { return $saveJob }
    if ($saveJob.state -in @('Failed','Canceled') -or [DateTime]::UtcNow -gt $saveDeadline) { throw "Save not confirmed: $saveId" }
    Start-Sleep -Milliseconds 250
  } while ($true)
}
$project = Assert-Identity
$station = Get-Node 'Application/Station/_this/Station'
if ($station.declaration -notmatch '(?m)^\s*ForceTraceAddon\s*:\s*ForceTraceAddon;' -or
    $station.declaration -notmatch '(?m)^\s*ForceTrace\s*:\s*ForceTraceData;') {
  throw 'CpStudio must generate the native ForceTrace object before application hook integration.'
}
# The compiled-library owns recorder/statistics implementations and cyclic dispatch.
# Never recreate AiForceTrace or application-local FB copies here.
$publisherMissing = $false
$onCallPath = 'Application/Station/_this/StationUnit/OnCall'
$onCall = Get-Node $onCallPath
if (-not $publisherMissing) {
$sub = 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run'
$parent = 'Application/Station/Wp100/_this/Chains/Cmd/SqC_Wp100_Run'
Add-HookTarget "$parent/_aN000_active" 'SqC_Wp100_Run/actions/N000.st'
Add-HookTarget "$parent/OnChainFinish" 'SqC_Wp100_Run/OnChainFinish.st' -Method
Add-HookTarget "$sub/_aN050_active" 'SqS_Wp100_Run/actions/N050.st'
Add-HookTarget "$sub/_aN101_active" 'SqS_Wp100_Run/actions/N101.st'
# Full AI-owned process changes are applied by apply_wp100_run_rest.ps1.
Add-HookTarget "$sub/OnChainFinish" 'SqS_Wp100_Run/OnChainFinish.st' -Method
$fragment = Read-Source 'StationUnit/OnCall.HmiForceTrace.st'
$null = Remove-TraceHook $onCall.implementation
$after = if ([regex]::IsMatch($onCall.implementation,$hookPattern)) {
  [regex]::Replace($onCall.implementation,$hookPattern,$fragment)
} else { (Normalize $onCall.implementation) + "`n" + $fragment }
$targets[$onCallPath] = @{declaration=$onCall.declaration;implementation=$after}
if ((Get-Sha256 $onCall.implementation) -cne (Get-Sha256 $after)) {
  Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $onCallPath) -Path $onCallPath -Kind 'publish-force-frame' `
    -Body @{implementation=$after} -TargetSha256 (Get-Sha256 $after)
}
}
$plan = New-WriterPlan -WriterName 'apply_hmi_force_trace_rest.ps1' -ProjectPath $expectedProject `
  -ProfileName 'ctrlX PLC 2.6.8' -ChainPath $onCallPath -DeclarationExactSha256 (Get-ExactSha256 $station.declaration)
$planSha = Get-PlanSha256 $plan
if ($Mode -eq 'PlanOnly') { [pscustomobject]@{mode=$Mode;phase=$(if($publisherMissing){'prepare-publisher'}else{'connect-hooks'});planSha256=$planSha;plan=$plan} | ConvertTo-Json -Depth 40; return }
if ($ExpectedPlanSha256 -cne $planSha) { throw 'Apply requires the matching fresh plan hash.' }
if ($script:WriteRequests.Count -eq 0) { [pscustomobject]@{mode=$Mode;changedObjects=0;save='skipped'} | ConvertTo-Json; return }
if ((-not (Test-Path -LiteralPath $CheckpointPath -PathType Leaf)) -or
    ((Get-FileHash -LiteralPath $CheckpointPath).Hash -ne (Get-FileHash -LiteralPath $expectedProject).Hash)) {
  throw 'An exact saved project checkpoint is required.'
}
$script:CapturePreflight = $false
$null = Assert-Identity
Assert-PreflightSnapshotCurrent
function Assert-Readback {
  foreach ($path in $targets.Keys) {
    $n = Get-NodeWithoutCapture $path
    if (((Get-Sha256 $n.declaration) -cne (Get-Sha256 $targets[$path].declaration)) -or
        ((Get-Sha256 $n.implementation) -cne (Get-Sha256 $targets[$path].implementation))) { throw "Readback differs: $path" }
  }
  Assert-ObservationCurrent -Observation (Get-PreflightObservation 'Application/Station/_this/Station') `
    -Current (Get-NodeWithoutCapture 'Application/Station/_this/Station') -Context 'CpStudio interface preserved'
}
try { Invoke-WriteRequests; Assert-Readback }
catch { $originalError=$_; $rollback=Invoke-WriteRollback; throw (New-TransactionFailureMessage -OriginalError $originalError -RollbackResult $rollback) }
$job = Invoke-JsonRequest -Method Post -Uri "$BaseUri/jobs" -Body @{jobType='ProjectJob';jobParameters=@{action='Save'}}
$jobId = if ($job.id) { $job.id } else { $job.jobId }
if (-not $jobId) { throw 'Save job missing; inspect before retrying.' }
$deadline = [DateTime]::UtcNow.AddSeconds(45)
do {
  $job = Invoke-RestMethod "$BaseUri/jobs/$jobId" -TimeoutSec 10
  if ($job.state -eq 'Done') { break }
  if (($job.state -in @('Failed','Canceled')) -or ([DateTime]::UtcNow -gt $deadline)) { throw "Save not confirmed: $jobId / $($job.state)" }
  Start-Sleep -Milliseconds 250
} while ($true)
Assert-Readback
[pscustomobject]@{mode=$Mode;changedObjects=$script:WriteRequests.Count;planSha256=$planSha;save=$job.state;offline=$true} | ConvertTo-Json
