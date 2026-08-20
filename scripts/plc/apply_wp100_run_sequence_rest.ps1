[CmdletBinding()]
param(
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2',
  [string]$ExpectedProject = 'C:\A_Documents\A_Projects\A_Software\BPP_ResistantStation\Station010_0708\Plc\Stat010_V5.11_CtrlX_PLC.project'
)

$ErrorActionPreference = 'Stop'

$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$sequencePath = 'Application/Station/Wp100/_this/Chains/Cmd/SqC_Wp100_Run'
$sequenceUri = "$deviceRoot/$sequencePath"
$dataStructPath = 'Application/Station/Wp100/_this/Structs/Data'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\src\plc\project\Station010'))

function ConvertTo-ApiUri {
  param([Parameter(Mandatory)][string]$Path)

  $uri = $deviceRoot
  foreach ($segment in ($Path -split '/')) {
    $uri += '/' + [Uri]::EscapeDataString($segment)
  }
  return $uri
}

function Get-Node {
  param([Parameter(Mandatory)][string]$Path)
  return Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri $Path)
}

function Test-NodeExists {
  param([Parameter(Mandatory)][string]$Path)

  try {
    $null = Get-Node $Path
    return $true
  }
  catch {
    if ($_.Exception.Response -and ([int]$_.Exception.Response.StatusCode -eq 404)) {
      return $false
    }
    throw
  }
}

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory)][ValidateSet('Post', 'Put')][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)]$Body
  )

  $json = $Body | ConvertTo-Json -Depth 40
  return Invoke-RestMethod -Method $Method -Uri $Uri -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json))
}

function Get-Sha256 {
  param([AllowEmptyString()][string]$Text)

  $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized))).Replace('-', '').ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
}

function Get-SourceText {
  param([Parameter(Mandatory)][string]$RelativePath)

  $path = Join-Path $sourceRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Canonical source is missing: $path"
  }
  return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Split-MethodSource {
  param([Parameter(Mandatory)][string]$Source)

  $split = $Source -split "`n`n", 2
  if ($split.Count -ne 2) {
    throw 'Method source must contain declaration and implementation separated by one blank line.'
  }
  return [pscustomobject]@{
    Declaration = $split[0] + "`n"
    Implementation = $split[1]
  }
}

function Get-ChildText {
  param([Parameter(Mandatory)]$Node)

  if ($Node.elementType -eq 'POUMethod') {
    return $Node.declaration.Replace("`r`n", "`n") + "`n" + $Node.implementation.Replace("`r`n", "`n")
  }
  return $Node.implementation.Replace("`r`n", "`n")
}

function Add-OrVerify-Dut {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$SourceFile
  )

  $declaration = Get-SourceText $SourceFile
  $path = "$dataStructPath/$Name"
  if (Test-NodeExists $path) {
    $existing = Get-Node $path
    if ($existing.elementType -ne 'DUT' -or (Get-Sha256 $existing.declaration) -ne (Get-Sha256 $declaration)) {
      throw "Existing DUT differs from canonical AI source: $path"
    }
    return 'verified'
  }

  $body = [ordered]@{
    name = $Name
    elementType = 'DUT'
    declaration = $declaration
    textlistsupport = $false
  }
  $null = Invoke-JsonRequest -Method Post -Uri (ConvertTo-ApiUri $dataStructPath) -Body $body
  return 'created'
}

function Set-CodeChild {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ValidateSet('Action', 'POUMethod')][string]$ElementType,
    [Parameter(Mandatory)][string]$SourceFile,
    [AllowNull()][string[]]$AllowedBaselineSha256
  )

  $source = Get-SourceText $SourceFile
  $path = "$sequencePath/$Name"
  $targetSha256 = Get-Sha256 $source

  if (Test-NodeExists $path) {
    $node = Get-Node $path
    if ($node.elementType -ne $ElementType) {
      throw "Unexpected child type at ${path}: $($node.elementType)"
    }
    $currentSha256 = Get-Sha256 (Get-ChildText $node)
    if ($currentSha256 -eq $targetSha256) {
      return 'verified'
    }
    if ($null -eq $AllowedBaselineSha256 -or $currentSha256 -notin $AllowedBaselineSha256) {
      throw "Existing object has unrecognized edits: $path"
    }

    if ($ElementType -eq 'Action') {
      $node.implementation = $source
    }
    else {
      $parts = Split-MethodSource $source
      $node.declaration = $parts.Declaration
      $node.implementation = $parts.Implementation
    }
    $null = Invoke-JsonRequest -Method Put -Uri (ConvertTo-ApiUri $path) -Body $node
    return 'updated'
  }

  if ($ElementType -eq 'Action') {
    $body = [ordered]@{
      name = $Name
      elementType = 'Action'
      language = 'ST'
      implementation = $source
    }
  }
  else {
    $parts = Split-MethodSource $source
    $body = [ordered]@{
      name = $Name
      elementType = 'POUMethod'
      language = 'ST'
      declaration = $parts.Declaration
      implementation = $parts.Implementation
    }
  }
  $null = Invoke-JsonRequest -Method Post -Uri $sequenceUri -Body $body
  return 'created'
}

function Escape-XmlText {
  param([Parameter(Mandatory)][string]$Text)
  return [Security.SecurityElement]::Escape($Text)
}

function New-SfcContext {
  return @{
    Builder = New-Object Text.StringBuilder
    NextId = 0
    NewLine = "`r`n"
    NameGuid = '38391c6d-6d4a-42f8-8ee7-9f45e5adafa8'
    CommentGuid = '7d894980-aeea-405c-a0f6-e2b26429c58f'
    FalseGuid = '01580b27-6378-448b-8ecb-0e4b795b58d6'
    NumberGuid = 'bc882c11-1e91-4dd8-a6b8-2075724ed18b'
    InitialGuid = '6844a48e-46c2-4cc8-a185-a478f3b99cc0'
    ActionEnabledGuid = '62e1754b-7629-4e63-9cec-10ae0c536f1f'
    ActionGuid = '700a583f-b4d4-43e4-8c14-629c7cd3bec8'
    TransitionPriorityGuid = '8294df19-5962-4dee-a874-1051dabb0e3e'
  }
}

function Get-NextSfcId {
  param([Parameter(Mandatory)][hashtable]$Context)

  $id = [int]$Context.NextId
  $Context.NextId = $id + 1
  return $id
}

function Add-SfcStep {
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)]$Step,
    [AllowNull()]$SourceId,
    [switch]$Initial
  )

  $id = Get-NextSfcId $Context
  $nl = $Context.NewLine
  $sb = $Context.Builder
  $initialAttribute = if ($Initial) { ' initialStep="true"' } else { '' }
  [void]$sb.Append("    <step localId=`"$id`"$initialAttribute name=`"$($Step.Name)`">${nl}")
  [void]$sb.Append("      <position x=`"0`" y=`"0`" />${nl}")
  if ($null -eq $SourceId) {
    [void]$sb.Append("      <connectionPointIn />${nl}")
  }
  else {
    [void]$sb.Append("      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`" />${nl}      </connectionPointIn>${nl}")
  }
  [void]$sb.Append("      <connectionPointOut formalParameter=`"sfc`" />${nl}")
  [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NameGuid)`">$(Escape-XmlText $Step.Name)</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.CommentGuid)`">$(Escape-XmlText $Step.Comment)</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.FalseGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NumberGuid)`">0</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.InitialGuid)`">$(if ($Initial) { 'TRUE' } else { 'FALSE' })</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.ActionEnabledGuid)`">TRUE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.ActionGuid)`">_a$($Step.Name)_active</attribute>${nl}")
  [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </step>${nl}")
  return $id
}

function Add-SfcTransition {
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][int]$SourceId,
    [Parameter(Mandatory)][string]$Expression
  )

  $nl = $Context.NewLine
  $sb = $Context.Builder
  $escapedExpression = Escape-XmlText $Expression
  $inVariableId = Get-NextSfcId $Context
  $transitionId = Get-NextSfcId $Context
  [void]$sb.Append("    <inVariable localId=`"$inVariableId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointOut />${nl}      <expression>$escapedExpression</expression>${nl}    </inVariable>${nl}")
  [void]$sb.Append("    <transition localId=`"$transitionId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`" formalParameter=`"sfc`" />${nl}      </connectionPointIn>${nl}      <condition>${nl}        <connectionPointIn>${nl}          <connection refLocalId=`"$inVariableId`" />${nl}        </connectionPointIn>${nl}      </condition>${nl}")
  [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NameGuid)`">$escapedExpression</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.FalseGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NumberGuid)`">0</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.ActionEnabledGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.TransitionPriorityGuid)`">0</attribute>${nl}")
  [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </transition>${nl}")
  return $transitionId
}

function Add-SfcJumpStep {
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][int]$SourceId,
    [Parameter(Mandatory)][string]$TargetName
  )

  $id = Get-NextSfcId $Context
  $nl = $Context.NewLine
  $sb = $Context.Builder
  [void]$sb.Append("    <jumpStep localId=`"$id`" targetName=`"$TargetName`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`" />${nl}      </connectionPointIn>${nl}")
  [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NameGuid)`">$(Escape-XmlText $TargetName)</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.CommentGuid)`">Not used</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.FalseGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </jumpStep>${nl}")
  return $id
}

function New-LinearSfcImplementation {
  param([Parameter(Mandatory)][object[]]$Steps)

  $ctx = New-SfcContext
  $nl = $ctx.NewLine
  [void]$ctx.Builder.Append("<body>${nl}  <SFC>${nl}")

  $stepId = Add-SfcStep -Context $ctx -Step $Steps[0] -SourceId $null -Initial
  $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Expression '_retVal = OK'

  for ($index = 1; $index -lt ($Steps.Count - 1); $index++) {
    $stepId = Add-SfcStep -Context $ctx -Step $Steps[$index] -SourceId $sourceId
    $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Expression '_retVal = OK'
  }

  $finishStepId = Add-SfcStep -Context $ctx -Step $Steps[$Steps.Count - 1] -SourceId $sourceId
  $finishTransitionId = Add-SfcTransition -Context $ctx -SourceId $finishStepId -Expression '_retVal = JUMP9'
  $null = Add-SfcJumpStep -Context $ctx -SourceId $finishTransitionId -TargetName 'N999'

  [void]$ctx.Builder.Append("  </SFC>${nl}</body>")
  return $ctx.Builder.ToString()
}

function Save-CurrentProject {
  $body = [ordered]@{
    jobType = 'ProjectJob'
    jobParameters = [ordered]@{ action = 'Save' }
  }
  $job = Invoke-JsonRequest -Method Post -Uri "$BaseUri/jobs" -Body $body
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  do {
    $state = Invoke-RestMethod -Method Get -Uri "$BaseUri/jobs/$($job.id)"
    if ($state.state -eq 'Done') {
      return $state
    }
    if ($state.state -in @('Failed', 'Canceled')) {
      throw "PLC Engineering save job failed: $($state.jobResultInfo)"
    }
    Start-Sleep -Milliseconds 200
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Timed out waiting for PLC Engineering save job $($job.id)"
}

$currentProject = Invoke-RestMethod -Method Get -Uri "$BaseUri/projects/current"
$expectedResolved = [IO.Path]::GetFullPath($ExpectedProject)
$currentResolved = [IO.Path]::GetFullPath($currentProject.path)
if (-not $currentResolved.Equals($expectedResolved, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Wrong project is open in PLC Engineering. Expected '$expectedResolved', got '$currentResolved'."
}
if ($currentProject.profileName -ne 'ctrlX PLC 2.6.8') {
  throw "Unexpected PLC profile '$($currentProject.profileName)'."
}

$steps = @(
  [pscustomobject]@{ Name = 'N000'; Comment = 'Initialize measurement sequence' },
  [pscustomobject]@{ Name = 'N010'; Comment = 'Check part before LEFT' },
  [pscustomobject]@{ Name = 'N020'; Comment = 'Start LEFT measurement' },
  [pscustomobject]@{ Name = 'N030'; Comment = 'Wait LEFT measurement' },
  [pscustomobject]@{ Name = 'N040'; Comment = 'Check part before MIDDLE' },
  [pscustomobject]@{ Name = 'N050'; Comment = 'Start MIDDLE measurement' },
  [pscustomobject]@{ Name = 'N060'; Comment = 'Wait MIDDLE measurement' },
  [pscustomobject]@{ Name = 'N070'; Comment = 'Check part before RIGHT' },
  [pscustomobject]@{ Name = 'N080'; Comment = 'Start RIGHT measurement' },
  [pscustomobject]@{ Name = 'N090'; Comment = 'Wait RIGHT measurement' },
  [pscustomobject]@{ Name = 'N999'; Comment = 'Finish measurement sequence' }
)

$targetDeclaration = Get-SourceText 'SqC_Wp100_Run\declaration.st'
$targetImplementation = New-LinearSfcImplementation $steps
$targetDeclarationSha = Get-Sha256 $targetDeclaration
$targetImplementationSha = Get-Sha256 $targetImplementation
$sequenceNode = Get-Node $sequencePath

$generatedDeclarationSha = 'dfb93c51ea220816248fad97c9b736c509b55f2861669fb5dfb5182ad538fefa'
$generatedImplementationSha = '387bcbe666d701dd8288fdada987befe69fc6e9872369af1f2f88750761955a8'
$currentDeclarationSha = Get-Sha256 $sequenceNode.declaration
$currentImplementationSha = Get-Sha256 $sequenceNode.implementation
if ($currentDeclarationSha -notin @($generatedDeclarationSha, $targetDeclarationSha)) {
  throw 'SqC_Wp100_Run declaration changed after audit; refusing overwrite.'
}
if ($currentImplementationSha -notin @($generatedImplementationSha, $targetImplementationSha)) {
  throw 'SqC_Wp100_Run SFC graph changed after audit; refusing overwrite.'
}

$targetActions = @($steps | ForEach-Object { "_a$($_.Name)_active" })
$targetChildren = @($targetActions + 'CheckPartPresent' + 'OnChainFinish')
$generatedChildSha256 = @{
  '_aN000_active' = 'd24f12d3349c0395ad002d53c31fead7c3424ad77b914663e4de086569890bda'
  '_aN010_active' = '5dddfc774f24ebdd86eafc2d374b97f2e6a1987548e40dad7c3f319897e06f46'
  '_aN050_active' = '6437e540fd9f092ed42caa24f687e566a6aaaf1003f3df0d49581d5684c04437'
  '_aN055_active' = '6437e540fd9f092ed42caa24f687e566a6aaaf1003f3df0d49581d5684c04437'
  '_aN060_active' = '6437e540fd9f092ed42caa24f687e566a6aaaf1003f3df0d49581d5684c04437'
  '_aN061_active' = '72d1c6414df37737374234bebccb0a45ca1f48bb0cd9210abc91fa867d717000'
  '_aN062_active' = 'b4e1f50873b52119e91252788f9a265482328491e3e3f018745746fe856ed960'
  '_aN110_active' = '2e5182805aff7e1b212a79657d7e507573bdf02850112e62e1b7b0d601f25875'
  '_aN120_active' = 'd80026cb035120b1e8215585d28c0b3a1b93eb9a410fc9ec88e612f47bbd5646'
  '_aN130_active' = 'ce660a39de24c48b65dcb85f9cbe1dc64a5dabd9159ec302853c0ee9ddab0d8a'
  '_aN140_active' = '7daa11325a35bfeef4bf7baf9b736c2227c393c5656cdb8c042769dc057febf2'
  '_aN990_active' = '2c629c5be9c5e4efbfad5e7ea14de7e60c8710f7999704acaa39756ae7917313'
  '_aN999_active' = 'fb3d682ce50170e284577e437f284a803aadece69f17de737a40c9529ea303cc'
  'OnChainFinish' = '0448d415d8dd45baab6ad0099d75817b1d2ee1f364cac768a4872469a0ff2318'
}
$knownChildren = @($targetChildren + $generatedChildSha256.Keys | Sort-Object -Unique)
$unknownChildren = @($sequenceNode.children | Where-Object { $_ -notin $knownChildren })
if ($unknownChildren.Count -gt 0) {
  throw "SqC_Wp100_Run contains unrecognized child objects: $($unknownChildren -join ', ')"
}

# Complete preflight before the first write, including generated objects that
# will be removed after their old graph references have been replaced.
foreach ($childName in $sequenceNode.children) {
  $child = Get-Node "$sequencePath/$childName"
  $childSha256 = Get-Sha256 (Get-ChildText $child)
  if ($childName -in $targetChildren) {
    $sourceFile = switch ($childName) {
      'CheckPartPresent' { 'SqC_Wp100_Run\methods\CheckPartPresent.st' }
      'OnChainFinish' { 'SqC_Wp100_Run\OnChainFinish.st' }
      default { "SqC_Wp100_Run\actions\$($childName.Substring(2, 4)).st" }
    }
    $targetChildSha256 = Get-Sha256 (Get-SourceText $sourceFile)
    if (($childSha256 -ne $targetChildSha256) -and
        (-not $generatedChildSha256.ContainsKey($childName) -or $childSha256 -ne $generatedChildSha256[$childName])) {
      throw "SqC_Wp100_Run child changed after audit: $childName"
    }
  }
  elseif (-not $generatedChildSha256.ContainsKey($childName) -or $childSha256 -ne $generatedChildSha256[$childName]) {
    throw "Generated child cannot be safely removed: $childName"
  }
}

$dutStatus = Add-OrVerify-Dut 'Wp100RunSequenceResultStruct' 'Wp100RunSequenceResultStruct.st'
$childStatus = [ordered]@{}
foreach ($step in $steps) {
  $name = "_a$($step.Name)_active"
  $baseline = if ($generatedChildSha256.ContainsKey($name)) { @($generatedChildSha256[$name]) } else { @() }
  $childStatus[$step.Name] = Set-CodeChild -Name $name -ElementType Action -SourceFile "SqC_Wp100_Run\actions\$($step.Name).st" -AllowedBaselineSha256 $baseline
}
$childStatus.CheckPartPresent = Set-CodeChild -Name 'CheckPartPresent' -ElementType POUMethod -SourceFile 'SqC_Wp100_Run\methods\CheckPartPresent.st' -AllowedBaselineSha256 @()
$childStatus.OnChainFinish = Set-CodeChild -Name 'OnChainFinish' -ElementType POUMethod -SourceFile 'SqC_Wp100_Run\OnChainFinish.st' -AllowedBaselineSha256 @($generatedChildSha256.OnChainFinish)

$parentChanged = ($currentDeclarationSha -ne $targetDeclarationSha) -or
                 ($currentImplementationSha -ne $targetImplementationSha)
if ($parentChanged) {
  $sequenceNode = Get-Node $sequencePath
  $sequenceNode.declaration = $targetDeclaration
  $sequenceNode.implementation = $targetImplementation
  $null = Invoke-JsonRequest -Method Put -Uri $sequenceUri -Body $sequenceNode
}

$obsoleteChildren = @($generatedChildSha256.Keys | Where-Object { $_ -notin $targetChildren -and (Test-NodeExists "$sequencePath/$_") })
foreach ($childName in $obsoleteChildren) {
  $null = Invoke-RestMethod -Method Delete -Uri (ConvertTo-ApiUri "$sequencePath/$childName")
  $childStatus["removed:$childName"] = 'removed'
}

$readback = Get-Node $sequencePath
if ((Get-Sha256 $readback.declaration) -ne $targetDeclarationSha) {
  throw 'SqC_Wp100_Run declaration readback differs after PUT.'
}
if ((Get-Sha256 $readback.implementation) -ne $targetImplementationSha) {
  throw 'SqC_Wp100_Run graph readback differs after PUT.'
}
$expectedChildren = @($targetChildren | Sort-Object)
$actualChildren = @($readback.children | Sort-Object)
if (($expectedChildren -join "`n") -ne ($actualChildren -join "`n")) {
  throw "SqC_Wp100_Run child list mismatch after update: $($actualChildren -join ', ')"
}

foreach ($step in $steps) {
  $name = "_a$($step.Name)_active"
  $node = Get-Node "$sequencePath/$name"
  $targetSha256 = Get-Sha256 (Get-SourceText "SqC_Wp100_Run\actions\$($step.Name).st")
  if ((Get-Sha256 (Get-ChildText $node)) -ne $targetSha256) {
    throw "SqC_Wp100_Run action readback differs: $name"
  }
}
foreach ($method in @('CheckPartPresent', 'OnChainFinish')) {
  $sourceFile = if ($method -eq 'CheckPartPresent') { 'SqC_Wp100_Run\methods\CheckPartPresent.st' } else { 'SqC_Wp100_Run\OnChainFinish.st' }
  $node = Get-Node "$sequencePath/$method"
  if ((Get-Sha256 (Get-ChildText $node)) -ne (Get-Sha256 (Get-SourceText $sourceFile))) {
    throw "SqC_Wp100_Run method readback differs: $method"
  }
}

$hasChanges = ($dutStatus -ne 'verified') -or
              $parentChanged -or
              ($obsoleteChildren.Count -gt 0) -or
              (@($childStatus.Values | Where-Object { $_ -ne 'verified' }).Count -gt 0)
$saveResult = if ($hasChanges) {
  (Save-CurrentProject).jobResultInfo
}
else {
  'No changes; save skipped.'
}

[pscustomobject]@{
  project = $currentProject.path
  dut = $dutStatus
  children = $childStatus
  stepCount = $steps.Count
  declarationSha256 = $targetDeclarationSha
  implementationSha256 = $targetImplementationSha
  saveResult = $saveResult
} | ConvertTo-Json -Depth 8
