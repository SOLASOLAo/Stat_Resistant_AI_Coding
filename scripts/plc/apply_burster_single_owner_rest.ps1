[CmdletBinding()]
param(
  [ValidateSet('PlanOnly', 'Apply')][string]$Mode = 'PlanOnly',
  [switch]$Integrate,
  [string]$ExpectedPlanSha256 = '',
  [string]$ReportPath = '',
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2'
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$expectedProject = [IO.Path]::GetFullPath((Join-Path $repo '../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project'))
$target = 'Application/Fbs/FB_Wp100BursterSingleOwner'
$source = Join-Path $repo 'src/plc/project/Station010/FB_Wp100BursterSingleOwner.st'
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
  try { $n = Invoke-RestMethod (ConvertTo-ApiUri $Path) }
  catch { if (Test-IsNotFoundError $_) { $n = $null } else { throw } }
  Register-PreflightObservation -Path $Path -Node $n
  return $n
}
function Assert-Identity {
  $p = Invoke-RestMethod "$BaseUri/projects/current"
  if (([IO.Path]::GetFullPath($p.path) -ine $expectedProject) -or
      ($p.profileName -cne 'ctrlX PLC 2.6.8')) { throw 'Wrong project/profile.' }
  $a = Invoke-RestMethod (ConvertTo-ApiUri 'Application')
  if ($a.isOnline -cne $false) { throw 'Offline Application required.' }
  return $p
}
function Save-CurrentProject {
  $j = Invoke-JsonRequest -Method Post -Uri "$BaseUri/jobs" -Body @{
    jobType='ProjectJob'; jobParameters=@{action='Save'}
  }
  $jobId = if ($j.id) { $j.id } else { $j.jobId }
  if (-not $jobId) { throw 'Save did not return job id.' }
  $deadline = [DateTime]::UtcNow.AddSeconds(45)
  do {
    $j = Invoke-RestMethod "$BaseUri/jobs/$jobId"
    if ($j.state -eq 'Done') {
      return $j
    }
    if ($j.state -in @('Failed', 'Canceled')) { throw ($j | ConvertTo-Json -Depth 10) }
    if ([DateTime]::UtcNow -gt $deadline) { throw "Save still pending: $jobId" }
    Start-Sleep -Milliseconds 250
  } while ($true)
}
$p = Assert-Identity
$null = Get-Node 'Application/Fbs'
$text = [IO.File]::ReadAllText($source).Replace("`r`n", "`n")
$parts = [regex]::Matches($text, '(?s)\(\* ===== OBJECT (?<name>[\w/]+) ===== \*\)\s*\(\* ===== DECLARATION ===== \*\)\s*(?<d>.*?)\s*\(\* ===== IMPLEMENTATION ===== \*\)\s*(?<i>.*?)(?=\(\* ===== OBJECT |\z)')
if ($parts.Count -ne 15) { throw "Expected FB, 12 methods and LastError/Get; got $($parts.Count)." }
$stubHashes = @{
  ClearError='44f9f3fa17aa32e3b65cebe9702e476020c54b281eeee2ecae96b579418f5bae'
  Reset='7c83738f85a1590ac122cbe6008c3bb8ca2838e1c54c84a09296dcd0ba6fe77d'
  Close='ca2c417118d2516b4d1aaae52102e28947e9f1ea33f805e090f0900409114814'
  MeasCmd='275e92934b220261c4714ddf060fb96e40e09236e801db6f7782967d1682df28'
  Open='3658e8669b0b63e565183c978f1b6e6fea656b2b149ca2a548149c968cd2b74b'
  SetRangeCmd='c57e8656309877eaf308d9b3c92bd9322b11ee6049c58a0991bac2bf2862e6eb'
  LastError='e81dce4eac6e749ba29a332cc0dccfaba073afb41da657249090194b7ba89372'
  'LastError/Get'='12da470dc9bc29800c2710c63901ea036f300b59697111e80f81ed53c2ce49e1'
}
# Exact prior offline candidate written by this writer; never accept user edits.
$reviewedCandidates = @{
  FB_Wp100BursterSingleOwner=@{d='26440745afbe3ca735390965fbb6f1c9fbd1730aae08c197c5307f68b6d4b15f';i='46260616542543fc0a2cb2e4061a1390e4e2a5e178f98f17662698b792789073'}
  Fail=@{d='693c3e6cafc264c84b8ed2b3818005c26a5518dc3511db1d286b33a2a2dc5cc5';i='1096b19fe61626e8f42a1986128099c2133360cea1944d1f2b229cb88d322d3a'}
  Exchange=@{d='4d366dc8983f8c4e10478bd10242acd2c5be9febccdc1a2036cee80f8f0ffcd2';i='e90f9205f9d9b9d3d95407613c73b917bb1f9d32e682ea5ed93211687762fb24'}
  Open=@{d='b81014e910655a7286586733b1cfe21c57115901e6cf7164b90e82c7e6020844';i='3e0c283c0642109b1b43fac54faef175ae52ae09e57b13487420556694cef6e3'}
  SelectProgram=@{d='9ab14d2b708cf8a225da4b1e500940cd40152f4e65c5f05295071b2341151c23';i='4b48944c1cdba88642af6c9f3a60dc5b240bed85398d5cf7ed1af05360a1fd85'}
  MeasCmd=@{d='6c99c471c0e8079d79367902c574ae157e9896532e6cc4d567120383ddda0f4f';i='995959d030db45ed6b4757b284a68d9944715f553d65f685ec61d5ee6b5bd485'}
  Cleanup=@{d='73c95667fce95da1720e3d16ab39333942f54f2ff453b1156096bba38846f8e6';i='a9198f9afb6f3c9271da4813ebe4fa5cc85026e2a0a89f4154762910c5790db4'}
  ClearError=@{d='12c0d3f5e7c1e444e5dc7f91c34643e8857f34191164e8ab245b9c1a4e331bc5';i='203f637e2d4fd190cf5e983b38af377809ca51e0cc5ac70b2c4e50a331c67d3d'}
  ParseNumber=@{d='5a82fa5f002ccb3eab4572fb1a1b3806ef9b3adb414d4242bbb88817973fdf5f';i='ad643b9672c2c4eb6f8b75ed3d8c6adf792050606c2795b82d7c887b9b2e9d1c'}
}
$targets = [ordered]@{}
$shellOnly = ($null -eq (Get-Node $target))
foreach ($part in $parts) {
  $name = $part.Groups['name'].Value
  $path = if ($name -eq 'FB_Wp100BursterSingleOwner') { $target } else { "$target/$name" }
  # PLE auto-creates public interface stubs when IMPLEMENTS is declared.
  # Freeze their real definitions in a second plan, never guess their hashes.
  if ($shellOnly -and ($path -ne $target)) { continue }
  if ($targets.Contains($path)) { throw 'Duplicate source object.' }
  $d = $part.Groups['d'].Value.Trim() + "`n"
  $i = $part.Groups['i'].Value.Trim() + "`n"
  $kind = if ($path -eq $target) { 'POU' } elseif ($name -eq 'LastError') { 'POUProperty' } elseif ($name -eq 'LastError/Get') { 'POUPropertyGet' } else { 'POUMethod' }
  if ($kind -eq 'POUProperty') { $i = '' }
  $targets[$path] = @{ declaration=$d; implementation=$i; elementType=$kind }
  $n = Get-Node $path
  if ($null -eq $n) {
    if ($name -eq 'LastError/Get') { throw 'Expected PLE-generated property getter is missing.' }
    $body = @{name=$name; elementType=$kind; language='ST'; declaration=$d; implementation=$i}
    Add-WriteRequest -Method Post -Uri (ConvertTo-ApiUri (Get-ParentPath $path)) -Path $path `
      -Kind 'create-ai-single-owner' -Body $body -BeforeFingerprint 'missing' -TargetSha256 (Get-Sha256 ($d+$i))
  } else {
    $isReviewedStub = $stubHashes.ContainsKey($name) -and
      ((Get-Sha256 $n.declaration) -ceq $stubHashes[$name]) -and
      ([string]::IsNullOrWhiteSpace([string]$n.implementation))
    $isReviewedCandidate = $reviewedCandidates.ContainsKey($name) -and
      ((Get-Sha256 $n.declaration) -ceq $reviewedCandidates[$name].d) -and
      ((Get-Sha256 ([string]$n.implementation)) -ceq $reviewedCandidates[$name].i)
    if (($n.elementType -cne $kind) -or
        (((Get-Sha256 $n.declaration) -cne (Get-Sha256 $d)) -and (-not $isReviewedStub) -and (-not $isReviewedCandidate))) {
      throw "Unexpected declaration/type; no overwrite allowed: $path"
    }
    if (((Get-Sha256 ([string]$n.implementation)) -cne (Get-Sha256 $i)) -or
        ((Get-Sha256 $n.declaration) -cne (Get-Sha256 $d))) {
      # Reviewed candidates are recorded explicitly, never trust arbitrary current text.
      $approved = @((Get-Sha256 ''), (Get-Sha256 "`n"))
      if ((-not $isReviewedStub) -and (-not $isReviewedCandidate) -and ((Get-Sha256 ([string]$n.implementation)) -notin $approved)) {
        throw "Unreviewed existing implementation: $path"
      }
      Set-JsonProperty -Object $n -Name implementation -Value $i
      $n.declaration = $d
      Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $path) -Path $path `
        -Kind 'update-ai-owned-full-object' -Body $n -BeforeFingerprint $script:PreflightObservations[$path].Fingerprint `
        -TargetSha256 (Get-Sha256 ($d+$i))
    }
  }
}
function Read-Canonical([string]$RelativePath) {
  [IO.File]::ReadAllText((Join-Path $repo "src/plc/project/Station010/$RelativePath")).Replace("`r`n", "`n").TrimEnd() + "`n"
}
function Add-ReviewedIntegrationTarget {
  param([string]$Path, [string]$Declaration, [string]$Implementation,
    [string]$ElementType, [string]$BeforeD, [string]$BeforeI, [switch]$FullObject)
  $n = Get-Node $Path
  if (($null -eq $n) -or ($n.elementType -cne $ElementType)) { throw "Missing/wrong integration target: $Path" }
  $targets[$Path] = @{declaration=$Declaration; implementation=$Implementation; elementType=$ElementType}
  if (((Get-Sha256 $n.declaration) -ceq (Get-Sha256 $Declaration)) -and
      ((Get-Sha256 ([string]$n.implementation)) -ceq (Get-Sha256 $Implementation))) { return }
  if (((Get-Sha256 $n.declaration) -cne $BeforeD) -or
      ((Get-Sha256 ([string]$n.implementation)) -cne $BeforeI)) { throw "Unreviewed integration edits: $Path" }
  if ((-not $FullObject) -and ([string]$n.declaration -cne $Declaration)) { throw "Mixed declaration write forbidden: $Path" }
  if ($FullObject) { Set-JsonProperty -Object $n -Name declaration -Value $Declaration }
  Set-JsonProperty -Object $n -Name implementation -Value $Implementation
  $kind = if ($FullObject) { 'update-ai-owned-full-object' } else { 'update-reviewed-implementation' }
  Add-WriteRequest -Method Put -Uri (ConvertTo-ApiUri $Path) -Path $Path -Kind $kind -Body $n `
    -BeforeFingerprint $script:PreflightObservations[$Path].Fingerprint -TargetSha256 (Get-Sha256 ($Declaration+$Implementation))
}
function Merge-IntegrationHook([string]$Current, [string]$Hook, [string]$Marker) {
  $pattern = '(?s)// ' + $Marker + '_BEGIN\r?\n.*?// ' + $Marker + '_END'
  $matches = [regex]::Matches($Current, $pattern)
  if ($matches.Count -gt 1) { throw "Duplicate $Marker hook." }
  if ($matches.Count -eq 1) {
    if ($matches[0].Value.Replace("`r`n", "`n").TrimEnd() -cne $Hook.TrimEnd()) { throw "Unreviewed $Marker hook edit." }
    return $Current
  }
  if ($Current.Contains($Marker) -or $Current.Contains('AiWp100.Burster')) { throw "Unrecognized $Marker binding/configuration." }
  return $Current.TrimEnd() + "`n`n" + $Hook
}
if ($Integrate) {
  if ($shellOnly) { throw 'Compile the complete staged driver before integration.' }
  # CpStudio owns model removal. Never override an active generated binding.
  foreach ($path in @('Application/Peripherals/Peripherals', 'Application/Peripherals/PeripheralRoot',
      'Application/Peripherals/PeripheralRoot/OnInitHierarchy', 'Application/Peripherals/PeripheralRoot/OnApplyParameters')) {
    $n = Get-Node $path
    if (($null -eq $n) -or (($n.declaration + $n.implementation) -match '(?i)IpBurster2316|_Wp100A103ResistantInterface')) {
      throw "CpStudio old Peripheral still present or unreadable: $path"
    }
  }
  $wpUnit = 'Application/Station/Wp100/_this/Wp100Unit'
  $applyPath = "$wpUnit/OnApplyParameters"
  $applyNode = Get-Node $applyPath
  $generated = [regex]::Matches($applyNode.implementation, '(?s)////<OES_CODE[^>]*>.*?////<END_OES_CODE>[^\n]*')
  if (($generated.Count -ne 3) -or (($generated.Value -join "`n") -match '(?i)iBursterResis2316|ResistantInterface')) {
    throw 'Expected unbound generated child configuration; CpStudio must clear the port first.'
  }
  $selectorSource = Read-Canonical 'FB_Wp100BursterProgramSelect.st'
  $selectorParts = [regex]::Match($selectorSource, '(?s)\(\* ===== DECLARATION ===== \*\)\s*(?<d>.*?)\s*\(\* ===== IMPLEMENTATION ===== \*\)\s*(?<i>.*)\z')
  if (-not $selectorParts.Success) { throw 'Missing selector source markers.' }
  Add-ReviewedIntegrationTarget -Path 'Application/Fbs/FB_Wp100BursterProgramSelect' -ElementType POU -FullObject `
    -Declaration ($selectorParts.Groups['d'].Value.Trim()+"`n") -Implementation ($selectorParts.Groups['i'].Value.Trim()+"`n") `
    -BeforeD '21bca5879b752b9eeaad23348b5f0c741a301e6b3be98b1ae1d06ee52027ff09' -BeforeI '4e10703b0b6eb9f0b2bdc1b1c7296a8958ca28a7079acfa2a037a20a1ec38c8e'
  Add-ReviewedIntegrationTarget -Path 'Application/Fbs/AiWp100' -ElementType GVL -FullObject `
    -Declaration (Read-Canonical 'AiWp100.gvl.st') -Implementation '' `
    -BeforeD '8ed552f674b856fee0e91c9a5ea79e473f8735839b92fe12b373790fa32a99db' -BeforeI (Get-Sha256 '')
  $n046Path = 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/_aN046_active'
  $n046 = Get-Node $n046Path
  Add-ReviewedIntegrationTarget -Path $n046Path -ElementType Action -Declaration ([string]$n046.declaration) `
    -Implementation (Read-Canonical 'SqS_Wp100_Run/actions/N046.st') -BeforeD (Get-Sha256 '') `
    -BeforeI '8f7ff89f6211d4611f14ee5675741d328e7e52e461d413b2e26144ec1fc35451'
  $manualPath = 'Application/Station/Wp100/Wp100A103ResistantDetector/Wp100A103ResistantDetectorExtension/OnManRelease'
  $manual = Get-Node $manualPath
  Add-ReviewedIntegrationTarget -Path $manualPath -ElementType POUMethod -Declaration $manual.declaration `
    -Implementation (Read-Canonical 'Wp100A103ResistantDetectorExtension/OnManRelease.st') `
    -BeforeD 'd9a23ecc9605d28b6870f3953068074e1ecf9332eab31bfb97e5f27ef42eb6c0' -BeforeI '495e8c689a369e5eed1d33a9b727e0fe02b7d0df0e75060d54fed930a25b336f'
  foreach ($hook in @(
    @{method='OnApplyParameters';file='OnApplyParameters.BursterBinding.st';marker='AI_BURSTER_SINGLE_OWNER_BINDING'},
    @{method='OnCall';file='OnCall.BursterConfiguration.st';marker='AI_BURSTER_SINGLE_OWNER_CONFIGURATION'})) {
    $path = "$wpUnit/$($hook.method)"
    $n = Get-Node $path
    $merged = Merge-IntegrationHook $n.implementation (Read-Canonical "Wp100Unit/$($hook.file)") $hook.marker
    Add-ReviewedIntegrationTarget -Path $path -ElementType POUMethod -Declaration $n.declaration -Implementation $merged `
      -BeforeD (Get-Sha256 $n.declaration) -BeforeI (Get-Sha256 $n.implementation)
  }
}
$plan = New-WriterPlan -WriterName 'apply_burster_single_owner_rest.ps1' `
  -ProjectPath $p.path -ProfileName $p.profileName -ChainPath $target `
  -DeclarationExactSha256 (Get-ExactSha256 $targets[$target].declaration)
$plan.declarationPolicy = 'ai-owned-reviewed-full-object'
$plan.integration = [bool]$Integrate
$hash = Get-PlanSha256 $plan
$result = [ordered]@{ mode=$Mode; shellOnly=$shellOnly; planSha256=$hash; objectCount=$targets.Count; mutationCount=$script:WriteRequests.Count; plan=$plan }
if ($Mode -eq 'Apply') {
  if ($ExpectedPlanSha256 -cne $hash) { throw 'Fresh PlanOnly SHA required.' }
  $null = Assert-Identity
  $script:CapturePreflight = $false
  Assert-PreflightSnapshotCurrent
  $startingHash = (Get-FileHash -LiteralPath $expectedProject -Algorithm SHA256).Hash.ToLowerInvariant()
  $checkpoint = Join-Path $repo "data/checkpoints/plc/$startingHash.project"
  if (-not (Test-Path -LiteralPath $checkpoint)) {
    $null = New-Item -ItemType Directory -Path (Split-Path $checkpoint) -Force
    Copy-Item -LiteralPath $expectedProject -Destination $checkpoint
  }
  if ((Get-FileHash -LiteralPath $checkpoint -Algorithm SHA256).Hash -ine $startingHash) { throw 'Checkpoint mismatch.' }
  function Assert-Targets {
    foreach ($path in $targets.Keys) {
      $n = Get-NodeWithoutCapture $path
      $t = $targets[$path]
      if (($n.elementType -cne $t.elementType) -or
          ((Get-Sha256 $n.declaration) -cne (Get-Sha256 $t.declaration)) -or
          ((Get-Sha256 ([string]$n.implementation)) -cne (Get-Sha256 $t.implementation))) {
        throw "Readback mismatch: $path"
      }
    }
  }
  try {
    Invoke-WriteRequests
    Assert-Targets
    if ($script:WriteRequests.Count -gt 0) { $null = Save-CurrentProject }
    Assert-Targets
  } catch {
    $original = $_
    $rollback = Invoke-WriteRollback
    throw (New-TransactionFailureMessage -OriginalError $original -RollbackResult $rollback)
  }
  $result.Remove('plan')
  $result.checkpoint = $checkpoint
  $result.readback = 'all objects match after Save'
  $result.projectSha256 = (Get-FileHash -LiteralPath $expectedProject -Algorithm SHA256).Hash.ToLowerInvariant()
  $result.bindingWrites = [bool]$Integrate
  $result.runtimeOperations = $false
}
$json = $result | ConvertTo-Json -Depth 100
if ($ReportPath) {
  $resolved = [IO.Path]::GetFullPath($ReportPath)
  $null = New-Item -ItemType Directory -Path (Split-Path $resolved) -Force
  [IO.File]::WriteAllText($resolved, $json, [Text.UTF8Encoding]::new($false))
}
$json
