[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$mockBaseUri = 'http://mock/plc/engineering/api/v2'
$mockProject = 'C:\mock\Station010.project'
$global:SfcWriterTestNodes = @{}
$global:SfcWriterTestMutations = [Collections.Generic.List[object]]::new()
$global:SfcWriterTestUseBaselineN000 = $true
$global:SfcWriterTestProjectGets = 0
$global:SfcWriterTestDriftBeforeSecondRead = $false
$global:SfcWriterTestSaveCompleted = $false
$global:SfcWriterTestPostSaveGets = [Collections.Generic.List[string]]::new()
$global:SfcWriterTestCorruptAfterSavePath = ''
$global:SfcWriterTestOmitEnumSymbol = ''

function Copy-JsonValue {
  param([Parameter(Mandatory)]$Value)
  return ($Value | ConvertTo-Json -Depth 50 | ConvertFrom-Json)
}

function Read-CanonicalText {
  param([Parameter(Mandatory)][string]$RelativePath)

  $path = Join-Path $sourceRoot $RelativePath
  return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Split-CanonicalMethod {
  param([Parameter(Mandatory)][string]$Source)

  $parts = $Source -split "`n`n", 2
  if ($parts.Count -ne 2) {
    throw 'Mock canonical method is malformed.'
  }
  return [pscustomobject]@{
    Declaration = $parts[0] + "`n"
    Implementation = $parts[1]
  }
}

function Split-CanonicalFunctionBlock {
  param([Parameter(Mandatory)][string]$Source)

  $match = [regex]::Match(
    $Source,
    '(?s)\(\* ===== DECLARATION ===== \*\)\s*(?<Declaration>.*?)\s*\(\* ===== IMPLEMENTATION ===== \*\)\s*(?<Implementation>.*)\z'
  )
  if (-not $match.Success) {
    throw 'Mock canonical Function Block is malformed.'
  }
  return [pscustomobject]@{
    Declaration = $match.Groups['Declaration'].Value.Trim() + "`n"
    Implementation = $match.Groups['Implementation'].Value.Trim() + "`n"
  }
}

function ConvertFrom-MockDeviceUri {
  param([Parameter(Mandatory)][string]$Uri)

  $prefix = "$mockBaseUri/devices/Device/Plc%20Logic/"
  if (-not $Uri.StartsWith($prefix, [StringComparison]::Ordinal)) {
    return $null
  }
  return (($Uri.Substring($prefix.Length) -split '/') |
      ForEach-Object { [Uri]::UnescapeDataString($_) }) -join '/'
}

function New-MockNode {
  param([Parameter(Mandatory)][string]$Path)

  $activeChainPath = if ($null -ne $runPath) { $runPath } else { $sequencePath }
  if ($Path -eq $activeChainPath) {
    $children = @($steps | ForEach-Object { "_a$($_.Name)_active" })
    if ($null -ne $sequencePath) {
      $children += 'CheckPartPresent'
    }
    $children += 'OnChainFinish'
    return [pscustomobject]@{
      name = ($activeChainPath -split '/')[-1]
      elementType = 'POU'
      declaration = $targetDeclaration
      implementation = $targetImplementation
      children = $children
    }
  }

  if ($Path -eq 'Application/Fbs') {
    return [pscustomobject]@{
      name = 'Fbs'
      elementType = 'Folder'
      declaration = ''
      implementation = ''
      children = @()
    }
  }

  if ($Path -in @(
      'Application/Fbs/FB_Wp100BursterProgramSelect',
      'Application/Fbs/AiWp100'
    )) {
    throw [IO.FileNotFoundException]::new("Mock node does not exist: $Path")
  }

  if (($null -ne $autoInfoLineEnumPaths) -and ($Path -eq $autoInfoLineEnumPaths[0])) {
    $enumItems = @(
      [pscustomobject]@{ Name = 'USER_INFO_TEXT_CLEAR'; Index = 0 },
      [pscustomobject]@{ Name = 'USER_INFO_LOAD_PART'; Index = 1 },
      [pscustomobject]@{ Name = 'USER_INFO_START_BUTTON'; Index = 2 },
      [pscustomobject]@{ Name = 'USER_INFO_SCAN_HOUSING'; Index = 3 }
    ) + @($requiredAutoInfoLineItems)
    $enumItems = @($enumItems | Where-Object { $_.Name -ne $global:SfcWriterTestOmitEnumSymbol })
    $declaration = "TYPE AutoInfoLineEnum :`n(`n" +
                   (($enumItems | ForEach-Object { "  $($_.Name) := $($_.Index)" }) -join ",`n") +
                   "`n);`nEND_TYPE`n"
    return [pscustomobject]@{
      name = 'AutoInfoLineEnum'
      elementType = 'DUT'
      declaration = $declaration
      implementation = ''
      children = @()
    }
  }

  if ($Path.StartsWith("$dataStructPath/", [StringComparison]::Ordinal)) {
    $name = ($Path -split '/')[-1]
    return [pscustomobject]@{
      name = $name
      elementType = 'DUT'
      declaration = Read-CanonicalText "$name.st"
      implementation = ''
      children = @()
    }
  }

  if (($null -ne $typeDataCheckPath) -and ($Path -eq $typeDataCheckPath)) {
    $applicationChecks = (Read-CanonicalText 'TypeDataSetManagerAddon\OnCheckData.ApplicationChecks.st').TrimEnd("`n")
    $implementation = @"
// Application specific data checks
$applicationChecks

////<OES_CODE MergeId="GeneratedDataCheck">
// Station.TypeDataNew.Wp100.Burster.UpperRange < 0
// Station.TypeDataNew.Wp100.Burster.UpperRange > 8
// Station.TypeDataNew.Wp100.Burster.LowerRange < 0
// Station.TypeDataNew.Wp100.Burster.LowerRange > 8
////</OES_CODE>
"@
    return [pscustomobject]@{
      name = 'OnCheckData'
      elementType = 'POUMethod'
      declaration = "METHOD PROTECTED OnCheckData`n"
      implementation = $implementation.Replace("`r`n", "`n").Replace("`r", "`n")
      children = @()
    }
  }

  if (-not $Path.StartsWith("$activeChainPath/", [StringComparison]::Ordinal)) {
    throw "Mock received an unexpected node path: $Path"
  }
  $name = ($Path -split '/')[-1]
  if ($name -eq 'OnChainFinish') {
    $relative = if ($null -ne $runPath) { 'SqS_Wp100_Run\OnChainFinish.st' } else { 'SqC_Wp100_Run\OnChainFinish.st' }
    $parts = Split-CanonicalMethod (Read-CanonicalText $relative)
    return [pscustomobject]@{
      name = $name
      elementType = 'POUMethod'
      declaration = $parts.Declaration
      implementation = $parts.Implementation
      children = @()
    }
  }
  if ($name -eq 'CheckPartPresent') {
    $parts = Split-CanonicalMethod (Read-CanonicalText 'SqC_Wp100_Run\methods\CheckPartPresent.st')
    return [pscustomobject]@{
      name = $name
      elementType = 'POUMethod'
      declaration = $parts.Declaration
      implementation = $parts.Implementation
      children = @()
    }
  }
  if ($name -notmatch '^_a(N\d{3})_active$') {
    throw "Mock received an unexpected child name: $name"
  }
  $step = $Matches[1]
  $relative = if ($null -ne $runPath) { "SqS_Wp100_Run\actions\$step.st" } else { "SqC_Wp100_Run\actions\$step.st" }
  $implementation = Read-CanonicalText $relative
  if (($null -ne $runPath) -and ($step -eq 'N000') -and $global:SfcWriterTestUseBaselineN000) {
    $implementation = $baselineActions.N000
  }
  return [pscustomobject]@{
    name = $name
    elementType = 'Action'
    declaration = ''
    implementation = $implementation
    children = @()
  }
}

function Invoke-RestMethod {
  param(
    [Parameter(Mandatory)][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [AllowNull()][string]$ContentType,
    [AllowNull()]$Body
  )

  if (($Method -eq 'Get') -and ($Uri -eq "$mockBaseUri/projects/current")) {
    $global:SfcWriterTestProjectGets++
    if (($global:SfcWriterTestProjectGets -eq 2) -and $global:SfcWriterTestDriftBeforeSecondRead) {
      $actionPath = 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/_aN000_active'
      $global:SfcWriterTestNodes[$actionPath].implementation = '// concurrent edit after plan creation'
      $global:SfcWriterTestDriftBeforeSecondRead = $false
    }
    return [pscustomobject]@{ path = $mockProject; profileName = 'ctrlX PLC 2.6.8' }
  }
  if (($Method -eq 'Get') -and ($Uri -eq "$mockBaseUri/jobs/mock-save")) {
    if (-not [string]::IsNullOrWhiteSpace($global:SfcWriterTestCorruptAfterSavePath)) {
      $global:SfcWriterTestNodes[$global:SfcWriterTestCorruptAfterSavePath].implementation = '// injected persistence-time corruption'
      $global:SfcWriterTestCorruptAfterSavePath = ''
    }
    $global:SfcWriterTestSaveCompleted = $true
    return [pscustomobject]@{ state = 'Done'; jobResultInfo = 'Mock save complete.' }
  }

  $path = ConvertFrom-MockDeviceUri $Uri
  if (($Method -eq 'Get') -and ($null -ne $path)) {
    if ($global:SfcWriterTestSaveCompleted) {
      $global:SfcWriterTestPostSaveGets.Add($path)
    }
    if (-not $global:SfcWriterTestNodes.ContainsKey($path)) {
      try {
        $global:SfcWriterTestNodes[$path] = New-MockNode $path
      }
      catch {
        if (($_.Exception -is [IO.FileNotFoundException]) -or
            ($_.Exception.InnerException -is [IO.FileNotFoundException])) {
          $notFound = [InvalidOperationException]::new("Mock node does not exist: $path")
          $notFound.Data['StatusCode'] = 404
          throw $notFound
        }
        throw
      }
    }
    return Copy-JsonValue $global:SfcWriterTestNodes[$path]
  }

  if (($Method -eq 'Put') -and ($null -ne $path)) {
    $json = [Text.Encoding]::UTF8.GetString([byte[]]$Body)
    $global:SfcWriterTestNodes[$path] = $json | ConvertFrom-Json
    $global:SfcWriterTestMutations.Add([pscustomobject]@{ method = $Method; path = $path })
    if ($path.EndsWith('/_aN000_active', [StringComparison]::Ordinal)) {
      $global:SfcWriterTestUseBaselineN000 = $false
    }
    return [pscustomobject]@{ status = 'ok' }
  }
  if (($Method -eq 'Post') -and ($null -ne $path)) {
    $json = [Text.Encoding]::UTF8.GetString([byte[]]$Body)
    $bodyNode = $json | ConvertFrom-Json
    if ($null -eq $bodyNode.PSObject.Properties['children']) {
      $bodyNode | Add-Member -NotePropertyName children -NotePropertyValue @()
    }
    $targetPath = "$path/$($bodyNode.name)"
    $global:SfcWriterTestNodes[$targetPath] = $bodyNode
    if (-not $global:SfcWriterTestNodes.ContainsKey($path)) {
      $global:SfcWriterTestNodes[$path] = New-MockNode $path
    }
    $parent = $global:SfcWriterTestNodes[$path]
    $parent.children = @($parent.children) + [string]$bodyNode.name
    $global:SfcWriterTestMutations.Add([pscustomobject]@{ method = $Method; path = $targetPath })
    return [pscustomobject]@{ status = 'ok' }
  }
  if (($Method -eq 'Delete') -and ($null -ne $path)) {
    if (-not $global:SfcWriterTestNodes.ContainsKey($path)) {
      $notFound = [InvalidOperationException]::new("Mock node does not exist: $path")
      $notFound.Data['StatusCode'] = 404
      throw $notFound
    }
    $null = $global:SfcWriterTestNodes.Remove($path)
    $separator = $path.LastIndexOf('/')
    $parentPath = $path.Substring(0, $separator)
    $leafName = $path.Substring($separator + 1)
    if ($global:SfcWriterTestNodes.ContainsKey($parentPath)) {
      $parent = $global:SfcWriterTestNodes[$parentPath]
      $parent.children = @($parent.children | Where-Object { $_ -ne $leafName })
    }
    $global:SfcWriterTestMutations.Add([pscustomobject]@{ method = $Method; path = $path })
    return [pscustomobject]@{ status = 'ok' }
  }
  if (($Method -eq 'Post') -and ($Uri -eq "$mockBaseUri/jobs")) {
    $global:SfcWriterTestMutations.Add([pscustomobject]@{ method = $Method; path = 'ProjectJob/Save' })
    return [pscustomobject]@{ id = 'mock-save' }
  }
  throw "Mock received an unexpected REST call: $Method $Uri"
}

function Invoke-Writer {
  param(
    [Parameter(Mandatory)][string]$Writer,
    [Parameter(Mandatory)][hashtable]$Arguments
  )

  $global:SfcWriterTestProjectGets = 0
  $global:SfcWriterTestSaveCompleted = $false
  $global:SfcWriterTestPostSaveGets.Clear()
  $output = @(& (Join-Path $repositoryRoot $Writer) @Arguments)
  return (($output -join [Environment]::NewLine) | ConvertFrom-Json)
}

$runWriter = 'scripts\plc\apply_wp100_run_rest.ps1'
$global:SfcWriterTestOmitEnumSymbol = 'USER_INFO_MEASURING_RIGHT'
$missingEnumRejected = $false
try {
  $null = Invoke-Writer -Writer $runWriter -Arguments @{
    BaseUri = $mockBaseUri
    ExpectedProject = $mockProject
  }
}
catch {
  $missingEnumRejected = $_.Exception.Message.Contains('CpStudio prerequisite is incomplete') -and
                         $_.Exception.Message.Contains('USER_INFO_MEASURING_RIGHT=13')
}
if (-not $missingEnumRejected) {
  throw 'PlanOnly did not clearly block a missing CpStudio AutoInfoLineEnum item.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Missing-enum PlanOnly performed a REST mutation.'
}
$global:SfcWriterTestNodes = @{}
$global:SfcWriterTestOmitEnumSymbol = ''

$defaultPlan = Invoke-Writer -Writer $runWriter -Arguments @{
  BaseUri = $mockBaseUri
  ExpectedProject = $mockProject
}
if ($defaultPlan.mode -ne 'PlanOnly') {
  throw 'The default REST writer mode is not PlanOnly.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Default PlanOnly performed a REST mutation.'
}
if (@($defaultPlan.plan.operations).Count -ne 3) {
  throw 'Mock PlanOnly did not report the two support-object creates and single Action update.'
}
if ((@($defaultPlan.plan.operations.kind) -join ',') -ne
    'create-ai-owned-function-block,create-ai-owned-gvl,update-action') {
  throw 'Mock PlanOnly reported unexpected operation kinds.'
}

$missingHashRejected = $false
try {
  $null = Invoke-Writer -Writer $runWriter -Arguments @{
    BaseUri = $mockBaseUri
    ExpectedProject = $mockProject
    Mode = 'Apply'
  }
}
catch {
  $missingHashRejected = $_.Exception.Message.Contains('Apply requires -ExpectedPlanSha256')
}
if (-not $missingHashRejected) {
  throw 'Apply without an explicit plan SHA-256 was not rejected.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Missing-hash Apply performed a REST mutation.'
}

$rejected = $false
try {
  $null = Invoke-Writer -Writer $runWriter -Arguments @{
    BaseUri = $mockBaseUri
    ExpectedProject = $mockProject
    Mode = 'Apply'
    ExpectedPlanSha256 = ('0' * 64)
  }
}
catch {
  $rejected = $_.Exception.Message.Contains('Plan hash mismatch')
}
if (-not $rejected) {
  throw 'Apply with the wrong plan SHA-256 was not rejected.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Rejected Apply performed a REST mutation.'
}

$global:SfcWriterTestDriftBeforeSecondRead = $true
$driftRejected = $false
try {
  $null = Invoke-Writer -Writer $runWriter -Arguments @{
    BaseUri = $mockBaseUri
    ExpectedProject = $mockProject
    Mode = 'Apply'
    ExpectedPlanSha256 = $defaultPlan.planSha256
  }
}
catch {
  $driftRejected = $_.Exception.Message.Contains('Preflight object hash changed')
}
if (-not $driftRejected) {
  throw 'Concurrent drift between plan and mutation was not rejected by the second GET/hash pass.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Drift-rejected Apply performed a REST mutation.'
}
$global:SfcWriterTestNodes = @{}
$global:SfcWriterTestUseBaselineN000 = $true

$apply = Invoke-Writer -Writer $runWriter -Arguments @{
  BaseUri = $mockBaseUri
  ExpectedProject = $mockProject
  Mode = 'Apply'
  ExpectedPlanSha256 = $defaultPlan.planSha256
}
if (($apply.mode -ne 'Apply') -or (-not $apply.declarationTextUnchanged)) {
  throw 'Authorized Apply did not report exact declaration preservation.'
}
if ($global:SfcWriterTestMutations.Count -ne 4) {
  throw "Authorized Apply produced an unexpected mutation count: $($global:SfcWriterTestMutations.Count)"
}
if (($global:SfcWriterTestMutations[0].method -ne 'Post') -or
    ($global:SfcWriterTestMutations[0].path -ne 'Application/Fbs/FB_Wp100BursterProgramSelect') -or
    ($global:SfcWriterTestMutations[1].method -ne 'Post') -or
    ($global:SfcWriterTestMutations[1].path -ne 'Application/Fbs/AiWp100') -or
    ($global:SfcWriterTestMutations[2].method -ne 'Put') -or
    (-not $global:SfcWriterTestMutations[2].path.EndsWith('/_aN000_active', [StringComparison]::Ordinal)) -or
    ($global:SfcWriterTestMutations[3].path -ne 'ProjectJob/Save')) {
  throw 'Authorized Apply did not create both support objects, update the Action, then Save.'
}
$postSaveGetSet = @($global:SfcWriterTestPostSaveGets | Sort-Object -Unique)
foreach ($requiredPostSavePath in @(
    'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run',
    'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/_aN000_active',
    'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/OnChainFinish',
    'Application/Station/_this/Addons/TypeDataSetManagerAddon/OnCheckData',
    'Application/Station/Wp100/_this/Structs/Data/Wp100ResistanceResultStruct',
    'Application/Station/Wp100/_this/Structs/Data/Wp100KistlerResultStruct',
    'Application/Station/Wp100/_this/Structs/Data/Wp100RunResultStruct',
    'Application/Fbs/FB_Wp100BursterProgramSelect',
    'Application/Fbs/AiWp100'
  )) {
  if ($requiredPostSavePath -notin $postSaveGetSet) {
    throw "Authorized Apply did not re-read a required target after Save: $requiredPostSavePath"
  }
}
if ($postSaveGetSet.Count -lt 28) {
  throw "Authorized Apply post-Save verification was not full-target (unique GET count=$($postSaveGetSet.Count))."
}

# A persistence-time rewrite after the Save job reports Done must fail the
# Apply and trigger the same exact rollback path as an ordinary REST failure.
$global:SfcWriterTestNodes = @{}
$global:SfcWriterTestMutations.Clear()
$global:SfcWriterTestUseBaselineN000 = $true
$failurePlan = Invoke-Writer -Writer $runWriter -Arguments @{
  BaseUri = $mockBaseUri
  ExpectedProject = $mockProject
}
$corruptPath = 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/_aN000_active'
$beforeCorruptNode = Copy-JsonValue $global:SfcWriterTestNodes[$corruptPath]
$global:SfcWriterTestCorruptAfterSavePath = $corruptPath
$postSaveFailureSeen = $false
try {
  $null = Invoke-Writer -Writer $runWriter -Arguments @{
    BaseUri = $mockBaseUri
    ExpectedProject = $mockProject
    Mode = 'Apply'
    ExpectedPlanSha256 = $failurePlan.planSha256
  }
}
catch {
  $postSaveFailureSeen = $_.Exception.Message.Contains('post-save verification') -and
                         $_.Exception.Message.Contains('Rollback succeeded')
}
if (-not $postSaveFailureSeen) {
  throw 'Persistence-time target corruption was not rejected and rolled back.'
}
foreach ($propertyName in @('name', 'elementType', 'declaration', 'implementation')) {
  if ([string]$global:SfcWriterTestNodes[$corruptPath].$propertyName -cne
      [string]$beforeCorruptNode.$propertyName) {
    throw "Post-Save verification failure did not restore the exact preflight Action field: $propertyName"
  }
}
if ((@($global:SfcWriterTestNodes[$corruptPath].children) -join "`n") -cne
    (@($beforeCorruptNode.children) -join "`n")) {
  throw 'Post-Save verification failure did not restore the exact preflight Action children.'
}
foreach ($rolledBackSupportPath in @(
    'Application/Fbs/FB_Wp100BursterProgramSelect',
    'Application/Fbs/AiWp100'
  )) {
  if ($global:SfcWriterTestNodes.ContainsKey($rolledBackSupportPath)) {
    throw "Post-Save verification failure did not delete created support object: $rolledBackSupportPath"
  }
}
if (@($global:SfcWriterTestNodes['Application/Fbs'].children).Count -ne 0) {
  throw 'Post-Save verification failure did not restore the Application/Fbs child list.'
}

$global:SfcWriterTestNodes = @{}
$global:SfcWriterTestMutations.Clear()
$global:SfcWriterTestUseBaselineN000 = $false
$sequencePlan = Invoke-Writer -Writer 'scripts\plc\apply_wp100_run_sequence_rest.ps1' -Arguments @{
  BaseUri = $mockBaseUri
  ExpectedProject = $mockProject
}
if (($sequencePlan.mode -ne 'PlanOnly') -or (@($sequencePlan.plan.operations).Count -ne 0)) {
  throw 'Sequence writer no-change PlanOnly result is invalid.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Sequence writer PlanOnly performed a REST mutation.'
}
$sequenceApply = Invoke-Writer -Writer 'scripts\plc\apply_wp100_run_sequence_rest.ps1' -Arguments @{
  BaseUri = $mockBaseUri
  ExpectedProject = $mockProject
  Mode = 'Apply'
  ExpectedPlanSha256 = $sequencePlan.planSha256
}
if (($sequenceApply.mode -ne 'Apply') -or (-not $sequenceApply.declarationTextUnchanged)) {
  throw 'Sequence no-change Apply did not complete exact readback verification.'
}
if ($global:SfcWriterTestMutations.Count -ne 0) {
  throw 'Sequence no-change Apply performed a REST mutation or Save.'
}

Write-Output 'SFC REST writer PlanOnly coverage OK: default mode, SHA/drift rejection, support-object POSTs, Action PUT, exact declaration preservation, post-Save full readback/fault rollback, and no-change sequence plan'
