[CmdletBinding()]
param(
  [ValidateSet('PlanOnly', 'Apply')][string]$Mode = 'PlanOnly',
  [string]$ExpectedPlanSha256 = '',
  [string]$CheckpointPath = '',
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2'
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$expectedProject = [IO.Path]::GetFullPath((Join-Path $repo '../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project'))
$target = 'Application/Station/_this/StationUnit/OnCall'
$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$script:CapturePreflight = $true
$script:PreflightObservations = [ordered]@{}
$script:WriteRequests = [Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot 'SfcRestWriter.Transaction.ps1')
function Get-Sha256([string]$Text) { Get-ExactSha256 ($Text.Replace("`r`n", "`n").Replace("`r", "`n")) }
function ConvertTo-ApiUri([string]$Path) {
  $deviceRoot + '/' + (($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}
function Test-IsNotFoundError($Record) {
  $Record.Exception.Response -and ([int]$Record.Exception.Response.StatusCode -eq 404)
}
function Get-Node([string]$Path) {
  $node = Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri $Path) -TimeoutSec 20
  Register-PreflightObservation -Path $Path -Node $node
  return $node
}
function Assert-Identity {
  $p = Invoke-RestMethod "$BaseUri/projects/current" -TimeoutSec 20
  if (([IO.Path]::GetFullPath($p.path) -ine $expectedProject) -or
      ($p.profileName -cne 'ctrlX PLC 2.6.8')) { throw 'Wrong project/profile.' }
  $a = Invoke-RestMethod (ConvertTo-ApiUri 'Application') -TimeoutSec 20
  if ($a.isOnline -cne $false) { throw 'Offline Application required.' }
  return $p
}
$project = Assert-Identity
$station = Get-Node 'Application/Station/_this/Station'
$structure = Get-Node 'Application/Station/_this/Structs/Common/HMIResistanceStruct'
if ($station.declaration -notmatch '(?m)^\s*HMIResistance\s*:\s*HMIResistanceStruct\s*;') {
  throw 'CpStudio must export Station.HMIResistance first.'
}
foreach ($position in @('Left', 'Middle', 'Right')) {
  foreach ($field in @(@{suffix='_mOhm';type='REAL'}, @{suffix='Valid';type='BOOL'}, @{suffix='Ok';type='BOOL'})) {
    $member = '_HmiResistance' + $position + $field.suffix
    if ($structure.declaration -notmatch ('(?m)^\s*' + [regex]::Escape($member) + '\s*:\s*' + $field.type + '\s*;')) {
      throw "Missing or changed CpStudio interface: $member"
    }
  }
}
$node = Get-Node $target
$source = [IO.File]::ReadAllText((Join-Path $repo 'src/plc/project/Station010/StationUnit/OnCall.HmiResistance.st')).Replace("`r`n", "`n")
$before = [string]$node.implementation
$begin = '// AI_HMI_RESISTANCE_BEGIN'
$end = '// AI_HMI_RESISTANCE_END'
$pattern = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end) + '(?:\r?\n|$)'
if (([regex]::Matches($source, [regex]::Escape($begin)).Count -ne 1) -or
    ([regex]::Matches($source, [regex]::Escape($end)).Count -ne 1)) { throw 'Malformed display source markers.' }
$blocks = [regex]::Matches($before, $pattern)
if (($blocks.Count -gt 1) -or
    ([regex]::Matches($before, [regex]::Escape($begin)).Count -ne $blocks.Count) -or
    ([regex]::Matches($before, [regex]::Escape($end)).Count -ne $blocks.Count)) {
  throw 'Ambiguous display markers; semantic review required.'
}
$after = if ($blocks.Count -eq 1) {
  $block = $blocks[0]
  $before.Substring(0, $block.Index) + $source.TrimEnd() + "`n" + $before.Substring($block.Index + $block.Length)
} else {
  if ($before -match 'Station\.HMIResistance\.') { throw 'Unmarked display assignments already exist.' }
  $before + "`n" + $source.TrimEnd() + "`n"
}
if ((Get-Sha256 $before) -ne (Get-Sha256 $after)) {
  Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $target) -Path $target -Kind 'update-implementation' `
    -Body @{implementation=$after} -TargetSha256 (Get-Sha256 $after)
}
$plan = New-WriterPlan -WriterName 'apply_hmi_resistance_rest.ps1' -ProjectPath $expectedProject `
  -ProfileName 'ctrlX PLC 2.6.8' -ChainPath $target -DeclarationExactSha256 (Get-ExactSha256 $node.declaration)
$planSha = Get-PlanSha256 $plan
if ($Mode -eq 'PlanOnly') {
  [pscustomobject]@{mode=$Mode;planSha256=$planSha;plan=$plan} | ConvertTo-Json -Depth 30
  return
}
if ([string]::IsNullOrWhiteSpace($ExpectedPlanSha256) -or ($ExpectedPlanSha256 -cne $planSha)) {
  throw 'Apply requires the matching fresh PlanOnly hash.'
}
if ($script:WriteRequests.Count -eq 0) {
  [pscustomobject]@{mode=$Mode;changedObjects=0;save='skipped'} | ConvertTo-Json
  return
}
if ((-not (Test-Path -LiteralPath $CheckpointPath -PathType Leaf)) -or
    ((Get-FileHash -LiteralPath $CheckpointPath).Hash -ne (Get-FileHash -LiteralPath $expectedProject).Hash)) {
  throw 'An exact verified project checkpoint is required.'
}
$script:CapturePreflight = $false
$null = Assert-Identity
Assert-PreflightSnapshotCurrent
function Assert-Readback {
  $readback = Get-NodeWithoutCapture $target
  if (($readback.declaration -cne $node.declaration) -or
      ((Get-Sha256 $readback.implementation) -ne (Get-Sha256 $after))) { throw 'OnCall readback differs.' }
  foreach ($path in @('Application/Station/_this/Station','Application/Station/_this/Structs/Common/HMIResistanceStruct')) {
    Assert-ObservationCurrent -Observation (Get-PreflightObservation $path) -Current (Get-NodeWithoutCapture $path) -Context 'Generated interface preserved'
  }
}
try {
  Invoke-WriteRequests
  Assert-Readback
} catch {
  $originalError = $_
  $rollback = Invoke-WriteRollback
  throw (New-TransactionFailureMessage -OriginalError $originalError -RollbackResult $rollback)
}
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
[pscustomobject]@{
  mode=$Mode;project=$project.path;planSha256=$planSha;changedObjects=1
  generatedInterfacesUnchanged=$true;implementationSha256=(Get-Sha256 $after);save=$save
} | ConvertTo-Json -Depth 8
