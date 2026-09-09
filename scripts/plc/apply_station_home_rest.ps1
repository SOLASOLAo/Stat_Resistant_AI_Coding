[CmdletBinding()]
param(
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2',
  [string]$ExpectedProject = 'C:\A_Documents\A_Projects\A_Software\BPP_ResistantStation\Station010\Plc\Stat010_V5.11_CtrlX_PLC.project',
  [ValidateSet('PlanOnly', 'Apply')][string]$Mode = 'PlanOnly',
  [string]$ExpectedPlanSha256 = ''
)

# Remove the audited empty N110 only. N100 ExecuteSubChain already waits for
# Station.SqS_Homing DONE. Preserve all generated declarations and child code.
$ErrorActionPreference = 'Stop'
$chainPath = 'Application/Station/_this/Chains/Mode/SqM_Station_Home'
$script:CapturePreflight = $true
$script:PreflightObservations = [ordered]@{}
$script:WriteRequests = [Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot 'SfcRestWriter.Transaction.ps1')

function Get-Sha256 {
  param([AllowEmptyString()][string]$Text)
  return Get-ExactSha256 ($Text.Replace("`r`n", "`n").Replace("`r", "`n"))
}
function ConvertTo-ApiUri {
  param([string]$Path)
  return "$BaseUri/devices/Device/Plc%20Logic/" + (($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}
function Get-Node {
  param([string]$Path)
  $node = Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri $Path)
  Register-PreflightObservation -Path $Path -Node $node
  return $node
}
function Test-IsNotFoundError {
  param($ErrorRecord)
  return ($null -ne $ErrorRecord.Exception.Response) -and ([int]$ErrorRecord.Exception.Response.StatusCode -eq 404)
}
function Get-SfcRestReadbackImplementation {
  param([string]$Implementation)
  return [regex]::Replace($Implementation, '(<transition\b[^>]*?)\s+name="[^"]*"', '$1')
}
function Assert-Project {
  $project = Invoke-RestMethod -Method Get -Uri "$BaseUri/projects/current"
  if ((-not ([IO.Path]::GetFullPath($project.path)).Equals([IO.Path]::GetFullPath($ExpectedProject), [StringComparison]::OrdinalIgnoreCase)) -or
      ($project.profileName -ne 'ctrlX PLC 2.6.8')) {
    throw 'Unexpected active PLE project/profile.'
  }
  if ($Mode -eq 'Apply') {
    $application = Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri 'Application')
    if ($application.isOnline -cne $false) { throw 'Apply requires an explicitly offline Application.' }
  }
  return $project
}
function Save-CurrentProject {
  $save = Get-SaveRequestDescriptor
  $job = Invoke-JsonTextRequest -Method Post -Uri $save.uri -BodyCanonicalJson $save.bodyCanonicalJson
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  do {
    $state = Invoke-RestMethod -Method Get -Uri "$BaseUri/jobs/$($job.id)"
    if ($state.state -eq 'Done') { return $state }
    if ($state.state -in @('Failed', 'Canceled')) { throw "Save failed: $($state.jobResultInfo)" }
    Start-Sleep -Milliseconds 200
  } while ([DateTime]::UtcNow -lt $deadline)
  throw 'Save timed out.'
}
function Assert-Targets {
  $actual = Get-Node $chainPath
  $expected = Get-PreflightSnapshotNode $chainPath
  $expected.implementation = $actual.implementation
  if ((Get-NodeFingerprint $expected) -ne (Get-NodeFingerprint $actual)) {
    throw 'Home declaration, children or object metadata changed.'
  }
  if ((Get-Sha256 (Get-SfcRestReadbackImplementation $actual.implementation)) -ne $targetReadbackSha) {
    $difference = Compare-Object ((Get-SfcRestReadbackImplementation $target) -split "`r?`n") ((Get-SfcRestReadbackImplementation $actual.implementation) -split "`r?`n") | Select-Object -First 5
    throw "Home SFC graph readback differs: $($difference | ConvertTo-Json -Compress)"
  }
  foreach ($child in $parent.children) {
    $path = "$chainPath/$child"
    if ((Get-NodeFingerprint (Get-Node $path)) -ne (Get-PreflightObservation $path).Fingerprint) {
      throw "Preserved Home child changed: $child"
    }
  }
}

$project = Assert-Project
$parent = Get-Node $chainPath
if (($parent.elementType -ne 'POU') -or ($parent.language -ne 'SFC')) { throw 'Expected Home SFC POU.' }
$requiredActions = @{
  _aN000_active = 'a9488e4ec7587f4a1daad4c782e8c13bd27dddccb978f92b9141eaae9ed9ed3b'
  _aN100_active = 'a9187c877963ac019f5bd8c7bed6fc286c39f0b3c708af42e0f1c46e8919aa85'
  _aN999_active = '64a7792ad6aff804f66d61568a4fc60be109a069a517e4cbe79ac39e7f61d90a'
}
foreach ($child in $parent.children) { $null = Get-Node "$chainPath/$child" }
foreach ($name in $requiredActions.Keys) {
  $action = Get-PreflightSnapshotNode "$chainPath/$name"
  if (($action.elementType -ne 'Action') -or ((Get-Sha256 $action.implementation) -ne $requiredActions[$name])) {
    throw "Home prerequisite Action changed after review: $name"
  }
}
$targetPath = Join-Path $PSScriptRoot '../../src/plc/project/Station010/SqM_Station_Home/implementation.sfc.xml'
$target = [IO.File]::ReadAllText($targetPath).TrimEnd("`r", "`n")
$targetReadbackSha = Get-Sha256 (Get-SfcRestReadbackImplementation $target)
$currentSha = Get-Sha256 (Get-SfcRestReadbackImplementation $parent.implementation)
$baselineSha = 'd57ae8dbbf2ead29dd68c080b01a3990c146fb4a3e2d1dc5892a0b3a03065f4c'
if ($currentSha -notin @($baselineSha, $targetReadbackSha)) { throw 'Home graph changed after review; refusing overwrite.' }
if ($currentSha -ne $targetReadbackSha) {
  $body = Get-PreflightSnapshotNode $chainPath
  $body.implementation = $target
  Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $chainPath) -Path $chainPath -Kind 'update-sfc-graph' -Body $body -BeforeFingerprint (Get-PreflightObservation $chainPath).Fingerprint -TargetSha256 (Get-Sha256 $target)
}
$plan = New-WriterPlan -WriterName 'apply_station_home_rest.ps1' -ProjectPath $project.path -ProfileName $project.profileName -ChainPath $chainPath -DeclarationExactSha256 (Get-ExactSha256 $parent.declaration)
$planSha = Get-PlanSha256 $plan
if ($Mode -eq 'PlanOnly') {
  [pscustomobject]@{ mode = $Mode; planSha256 = $planSha; plan = $plan } | ConvertTo-Json -Depth 30
  return
}
if ([string]::IsNullOrWhiteSpace($ExpectedPlanSha256) -or ($ExpectedPlanSha256 -ne $planSha)) { throw 'Apply requires the matching fresh PlanOnly SHA-256.' }
$script:CapturePreflight = $false
$null = Assert-Project
Assert-PreflightSnapshotCurrent
try {
  Invoke-WriteRequests
  Assert-Targets
  if ($script:WriteRequests.Count -gt 0) { $null = Save-CurrentProject; Assert-Targets }
}
catch {
  $failure = $_
  $rollback = Invoke-WriteRollback
  throw (New-TransactionFailureMessage -OriginalError $failure -RollbackResult $rollback)
}
[pscustomobject]@{
  mode = $Mode; planSha256 = $planSha; operationCount = $script:WriteRequests.Count
  stepCount = 3; declarationTextUnchanged = $true; allChildrenUnchanged = $true
  restReadbackImplementationSha256 = $targetReadbackSha; compiled = $false; downloaded = $false
} | ConvertTo-Json
