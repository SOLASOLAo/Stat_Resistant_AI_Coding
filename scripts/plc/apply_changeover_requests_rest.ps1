[CmdletBinding()]
param(
  [ValidateSet('PlanOnly','Apply')][string]$Mode = 'PlanOnly',
  [string]$ExpectedPlanSha256 = '',
  [string]$CheckpointPath = '',
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2'
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$expectedProject = [IO.Path]::GetFullPath((Join-Path $repo '../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project'))
$chainPath = 'Application/Station/_this/Chains/Sub/SqS_Station_ChangeOverFile'
$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$script:CapturePreflight = $true
$script:PreflightObservations = [ordered]@{}
$script:WriteRequests = [Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot 'SfcRestWriter.Transaction.ps1')
function Normalize-Code([string]$Text) { $Text.Replace("`r`n","`n").Replace("`r","`n").TrimEnd() }
function Code-Hash([string]$Text) { Get-ExactSha256 (Normalize-Code $Text) }
function Get-Sha256([string]$Text) { Code-Hash $Text }
function Test-IsNotFoundError($Record) {
  $Record.Exception.Response -and ([int]$Record.Exception.Response.StatusCode -eq 404)
}
function ConvertTo-ApiUri([string]$Path) {
  $deviceRoot + '/' + (($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}
function Get-Node([string]$Path) {
  $node = Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri $Path) -TimeoutSec 20
  Register-PreflightObservation -Path $Path -Node $node
  return $node
}
function Assert-Identity {
  $project = Invoke-RestMethod "$BaseUri/projects/current" -TimeoutSec 20
  if ([IO.Path]::GetFullPath($project.path) -ine $expectedProject -or $project.profileName -cne 'ctrlX PLC 2.6.8') { throw 'Wrong project/profile.' }
  $application = Invoke-RestMethod (ConvertTo-ApiUri 'Application') -TimeoutSec 20
  if ($application.isOnline -cne $false) { throw 'Offline Application required. This writer never logs in or downloads.' }
  return $project
}
$project = Assert-Identity
$chain = Get-Node $chainPath
$reviewedBefore = @{
  _aN010_active = '6cc94e0c03a4d934adeb847f27858a51ead7367a349de5d21febf2c31e8b0758'
  _reset = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  _aN999_active = '64a7792ad6aff804f66d61568a4fc60be109a069a517e4cbe79ac39e7f61d90a'
}
$targets = @{}
$unchangedPaths = [Collections.Generic.List[string]]::new()
$unchangedPaths.Add($chainPath)
foreach ($child in $chain.children) {
  $path = $chainPath + '/' + $child
  $node = Get-Node $path
  if ($reviewedBefore.ContainsKey($child)) {
    $after = (Normalize-Code ([IO.File]::ReadAllText((Join-Path $repo ('src/plc/project/Station010/SqS_Station_ChangeOverFile/' + $child + '.st'))))) + "`n"
    $beforeHash = Code-Hash ([string]$node.implementation)
    $afterHash = Code-Hash $after
    if ($beforeHash -cne $reviewedBefore[$child] -and $beforeHash -cne $afterHash) { throw "Unreviewed changes in $child; reconcile before applying." }
    $targets[$path] = @{before=$node;after=$after}
    if ($beforeHash -cne $afterHash) {
      Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $path) -Path $path -Kind 'update-implementation' -Body @{implementation=$after} -TargetSha256 (Get-ExactSha256 $after)
    }
  } else { $unchangedPaths.Add($path) }
}
if ($targets.Count -ne 3) { throw 'The three reviewed implementation objects must already exist.' }
foreach ($name in @('OnChainCancel','OnChainError')) {
  $node = Get-NodeWithoutCapture ($chainPath + '/' + $name)
  if ($node.implementation -notmatch '(?m)^\s*_reset\(\);\s*$') { throw "Existing $name cleanup hook changed." }
}
$plan = New-WriterPlan -WriterName 'apply_changeover_requests_rest.ps1' -ProjectPath $expectedProject -ProfileName 'ctrlX PLC 2.6.8' -ChainPath $chainPath -DeclarationExactSha256 (Get-ExactSha256 ([string]$chain.declaration))
$planSha = Get-PlanSha256 $plan
if ($Mode -eq 'PlanOnly') { [pscustomobject]@{mode=$Mode;planSha256=$planSha;plan=$plan} | ConvertTo-Json -Depth 30; return }
if ([string]::IsNullOrWhiteSpace($ExpectedPlanSha256) -or $ExpectedPlanSha256 -cne $planSha) { throw 'Apply requires the matching fresh PlanOnly hash.' }
if ($script:WriteRequests.Count -eq 0) { [pscustomobject]@{mode=$Mode;changedObjects=0;save='skipped'} | ConvertTo-Json; return }
if (-not (Test-Path -LiteralPath $CheckpointPath -PathType Leaf) -or (Get-FileHash -LiteralPath $CheckpointPath).Hash -cne (Get-FileHash -LiteralPath $expectedProject).Hash) { throw 'An exact verified project checkpoint is required.' }
$script:CapturePreflight = $false
$null = Assert-Identity
Assert-PreflightSnapshotCurrent
function Assert-Readback {
  foreach ($path in $targets.Keys) {
    $actual = Get-NodeWithoutCapture $path
    if ([string]$actual.declaration -cne [string]$targets[$path].before.declaration -or (Code-Hash ([string]$actual.implementation)) -cne (Code-Hash $targets[$path].after)) { throw "Declaration or implementation readback differs: $path" }
  }
  foreach ($path in $unchangedPaths) { Assert-ObservationCurrent -Observation (Get-PreflightObservation $path) -Current (Get-NodeWithoutCapture $path) -Context 'Untouched SFC graph or child' }
}
try { Invoke-WriteRequests; Assert-Readback }
catch { $originalError = $_; $rollback = Invoke-WriteRollback; throw (New-TransactionFailureMessage -OriginalError $originalError -RollbackResult $rollback) }
$save = Invoke-JsonRequest -Method Post -Uri "$BaseUri/jobs" -Body @{jobType='ProjectJob';jobParameters=@{action='Save'}}
$jobId = if ($save.id) { $save.id } else { $save.jobId }
if (-not $jobId) { throw 'Save did not return a job id; inspect before retrying.' }
$deadline = [DateTime]::UtcNow.AddSeconds(45)
do {
  $save = Invoke-RestMethod "$BaseUri/jobs/$jobId" -TimeoutSec 10
  if ($save.state -eq 'Done') { break }
  if ($save.state -in @('Failed','Canceled')) { throw "Save failed: $($save.state)" }
  if ([DateTime]::UtcNow -gt $deadline) { throw "Save status unknown: $jobId" }
  Start-Sleep -Milliseconds 250
} while ($true)
Assert-Readback
[ordered]@{mode=$Mode;project=$project.path;planSha256=$planSha;changedObjects=$script:WriteRequests.Count;nativeGraphAndOtherChildrenUnchanged=$true;declarationsUnchanged=$true;save=$save} | ConvertTo-Json -Depth 8
