[CmdletBinding()]
param(
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2',
  [string]$ExpectedProject = 'C:\A_Documents\A_Projects\A_Software\BPP_ResistantStation\Station010\Plc\Stat010_V5.11_CtrlX_PLC.project',
  [ValidateSet('PlanOnly', 'Apply')][string]$Mode = 'PlanOnly',
  [AllowEmptyString()][string]$ExpectedPlanSha256 = ''
)

$ErrorActionPreference = 'Stop'

$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$sequencePath = 'Application/Station/Wp100/_this/Chains/Cmd/SqC_Wp100_Run'
$sequenceUri = "$deviceRoot/$sequencePath"
$dataStructPath = 'Application/Station/Wp100/_this/Structs/Data'
$autoInfoLineEnumPaths = @(
  'Application/Station/_this/Enums/AutoInfoLineEnum',
  'Application/Station/Enums/AutoInfoLineEnum',
  'Application/Enums/AutoInfoLineEnum'
)
$requiredAutoInfoLineItems = @(
  [pscustomobject]@{ Name = 'USER_INFO_MOVE_FIXTURE_LEFT'; Index = 4 },
  [pscustomobject]@{ Name = 'USER_INFO_MOVE_FIXTURE_MIDDLE'; Index = 5 },
  [pscustomobject]@{ Name = 'USER_INFO_MOVE_FIXTURE_RIGHT'; Index = 6 },
  [pscustomobject]@{ Name = 'USER_INFO_PRESS_START_LEFT'; Index = 7 },
  [pscustomobject]@{ Name = 'USER_INFO_PRESS_START_MIDDLE'; Index = 8 },
  [pscustomobject]@{ Name = 'USER_INFO_PRESS_START_RIGHT'; Index = 9 },
  [pscustomobject]@{ Name = 'USER_INFO_CLOSING_SAFETY_DOOR'; Index = 10 },
  [pscustomobject]@{ Name = 'USER_INFO_MEASURING_LEFT'; Index = 11 },
  [pscustomobject]@{ Name = 'USER_INFO_MEASURING_MIDDLE'; Index = 12 },
  [pscustomobject]@{ Name = 'USER_INFO_MEASURING_RIGHT'; Index = 13 },
  [pscustomobject]@{ Name = 'USER_INFO_RETURN_SAFE_POSITION'; Index = 14 },
  [pscustomobject]@{ Name = 'USER_INFO_OPENING_SAFETY_DOOR'; Index = 15 },
  [pscustomobject]@{ Name = 'USER_INFO_MEASUREMENT_COMPLETE'; Index = 16 }
)
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\src\plc\project\Station010'))
$script:CapturePreflight = $true
$script:PreflightObservations = [ordered]@{}
$script:WriteRequests = [Collections.Generic.List[object]]::new()
$script:PreservedDeclarations = [ordered]@{}

. (Join-Path $PSScriptRoot 'SfcRestWriter.Transaction.ps1')

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
  $node = Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri $Path)
  Register-PreflightObservation -Path $Path -Node $node
  return $node
}

function Test-IsNotFoundError {
  param([Parameter(Mandatory)]$ErrorRecord)

  if ($ErrorRecord.Exception.Response -and ([int]$ErrorRecord.Exception.Response.StatusCode -eq 404)) {
    return $true
  }
  return ($ErrorRecord.Exception.Data.Contains('StatusCode') -and ([int]$ErrorRecord.Exception.Data['StatusCode'] -eq 404))
}

function Test-NodeExists {
  param([Parameter(Mandatory)][string]$Path)

  try {
    $null = Get-Node $Path
    return $true
  }
  catch {
    if (Test-IsNotFoundError $_) {
      Register-PreflightObservation -Path $Path -Node $null
      return $false
    }
    throw
  }
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

function Get-SfcRestReadbackImplementation {
  param([Parameter(Mandatory)][string]$Implementation)

  # The official PLE REST GET normalizes away the transition name attribute,
  # even though a PUT must provide it so the native VariableName is not NULL.
  return [regex]::Replace(
    $Implementation,
    '(<transition\s+localId="[^"]+")\s+name="[^"]+"',
    '$1'
  )
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

  # A DUT POST also mutates the Structs/Data parent's child collection.  Keep
  # that container in the immutable preflight set so the plan, second GET and
  # rollback verification cover the indirect parent mutation as well.
  $null = Get-Node $dataStructPath

  $body = [ordered]@{
    name = $Name
    elementType = 'DUT'
    declaration = $declaration
    textlistsupport = $false
  }
  Add-WriteRequest -Method Post `
    -Uri (ConvertTo-ApiUri $dataStructPath) `
    -Path $path `
    -Kind 'create-ai-owned-dut' `
    -Body $body `
    -BeforeFingerprint 'missing' `
    -TargetSha256 (Get-Sha256 $declaration)
  return 'planned-create'
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
    $parts = if ($ElementType -eq 'POUMethod') { Split-MethodSource $source } else { $null }
    if (($ElementType -eq 'POUMethod') -and
        ((Get-Sha256 ([string]$node.declaration)) -ne (Get-Sha256 $parts.Declaration))) {
      throw "Method declaration differs from its canonical interface; refusing to write: $path"
    }
    if ($ElementType -eq 'POUMethod') {
      $script:PreservedDeclarations[$path] = [string]$node.declaration
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
      $node.implementation = $parts.Implementation
    }
    Add-WriteRequest -Method Put `
      -Uri (ConvertTo-ApiUri $path) `
      -Path $path `
      -Kind $(if ($ElementType -eq 'Action') { 'update-action' } else { 'update-method-implementation' }) `
      -Body $node `
      -BeforeFingerprint $script:PreflightObservations[$path].Fingerprint `
      -TargetSha256 $targetSha256
    return 'planned-update'
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
    if ($Name -eq 'OnChainFinish') {
      throw 'Generated OnChainFinish method is unexpectedly missing; refusing to invent its method metadata.'
    }
    $parts = Split-MethodSource $source
    $body = [ordered]@{
      name = $Name
      elementType = 'POUMethod'
      language = 'ST'
      declaration = $parts.Declaration
      implementation = $parts.Implementation
    }
  }
  Add-WriteRequest -Method Post `
    -Uri $sequenceUri `
    -Path $path `
    -Kind $(if ($ElementType -eq 'Action') { 'create-action' } else { 'create-ai-owned-method' }) `
    -Body $body `
    -BeforeFingerprint 'missing' `
    -TargetSha256 $targetSha256
  return 'planned-create'
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
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Expression
  )

  $nl = $Context.NewLine
  $sb = $Context.Builder
  $escapedName = Escape-XmlText $Name
  $escapedExpression = Escape-XmlText $Expression
  $inVariableId = Get-NextSfcId $Context
  $transitionId = Get-NextSfcId $Context
  [void]$sb.Append("    <inVariable localId=`"$inVariableId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointOut />${nl}      <expression>$escapedExpression</expression>${nl}    </inVariable>${nl}")
  [void]$sb.Append("    <transition localId=`"$transitionId`" name=`"$escapedName`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`" formalParameter=`"sfc`" />${nl}      </connectionPointIn>${nl}      <condition>${nl}        <connectionPointIn>${nl}          <connection refLocalId=`"$inVariableId`" />${nl}        </connectionPointIn>${nl}      </condition>${nl}")
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
  $transitionName = "$($Steps[0].Name)__to__$($Steps[1].Name)"
  $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Name $transitionName -Expression '_retVal = OK'

  for ($index = 1; $index -lt ($Steps.Count - 1); $index++) {
    $stepId = Add-SfcStep -Context $ctx -Step $Steps[$index] -SourceId $sourceId
    $transitionName = "$($Steps[$index].Name)__to__$($Steps[$index + 1].Name)"
    $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Name $transitionName -Expression '_retVal = OK'
  }

  $finishStepId = Add-SfcStep -Context $ctx -Step $Steps[$Steps.Count - 1] -SourceId $sourceId
  $finishTransitionName = "$($Steps[$Steps.Count - 1].Name)__to__N999"
  $finishTransitionId = Add-SfcTransition -Context $ctx -SourceId $finishStepId -Name $finishTransitionName -Expression '_retVal = JUMP9'
  $null = Add-SfcJumpStep -Context $ctx -SourceId $finishTransitionId -TargetName 'N999'

  [void]$ctx.Builder.Append("  </SFC>${nl}</body>")
  return $ctx.Builder.ToString()
}

function Save-CurrentProject {
  $saveRequest = Get-SaveRequestDescriptor
  $job = Invoke-JsonTextRequest `
    -Method Post `
    -Uri $saveRequest.uri `
    -BodyCanonicalJson $saveRequest.bodyCanonicalJson
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

function Assert-Wp100RunSequenceTargets {
  param([Parameter(Mandatory)][string]$Phase)

  $null = Assert-RequiredEnumItems `
    -CandidatePaths @($autoInfoLineGate.Path) `
    -ExpectedItems $requiredAutoInfoLineItems `
    -EnumName 'AutoInfoLineEnum'
  $readback = Get-Node $sequencePath
  if (([string]$readback.declaration -cne $preservedSequenceDeclaration) -or
      ((Get-ExactSha256 ([string]$readback.declaration)) -ne $preservedSequenceDeclarationExactSha)) {
    throw "SqC_Wp100_Run declaration text/SHA changed during $Phase."
  }
  if ((Get-Sha256 $readback.implementation) -notin @($targetImplementationSha, $targetRestReadbackImplementationSha)) {
    throw "SqC_Wp100_Run graph readback differs during $Phase."
  }
  $actualChildren = @($readback.children | Sort-Object)
  $missingTargetChildren = @($targetChildren | Where-Object { $_ -notin $actualChildren })
  if ($missingTargetChildren.Count -gt 0) {
    throw "SqC_Wp100_Run required child list is incomplete during $Phase`: $($missingTargetChildren -join ', ')"
  }

  foreach ($step in $steps) {
    $name = "_a$($step.Name)_active"
    $node = Get-Node "$sequencePath/$name"
    $targetSha256 = Get-Sha256 (Get-SourceText "SqC_Wp100_Run\actions\$($step.Name).st")
    if ((Get-Sha256 (Get-ChildText $node)) -ne $targetSha256) {
      throw "SqC_Wp100_Run action readback differs during $Phase`: $name"
    }
  }
  foreach ($method in @('CheckPartPresent', 'OnChainFinish')) {
    $sourceFile = if ($method -eq 'CheckPartPresent') {
      'SqC_Wp100_Run\methods\CheckPartPresent.st'
    }
    else {
      'SqC_Wp100_Run\OnChainFinish.st'
    }
    $node = Get-Node "$sequencePath/$method"
    if ((Get-Sha256 (Get-ChildText $node)) -ne (Get-Sha256 (Get-SourceText $sourceFile))) {
      throw "SqC_Wp100_Run method readback differs during $Phase`: $method"
    }
    $methodPath = "$sequencePath/$method"
    if ($script:PreservedDeclarations.Contains($methodPath)) {
      $methodDeclarationOriginal = [string]$script:PreservedDeclarations[$methodPath]
      $methodDeclarationReadback = [string]$node.declaration
      if (($methodDeclarationReadback -cne $methodDeclarationOriginal) -or
          ((Get-ExactSha256 $methodDeclarationReadback) -ne (Get-ExactSha256 $methodDeclarationOriginal))) {
        throw "SqC_Wp100_Run method declaration text/SHA changed during $Phase`: $method"
      }
    }
  }

  $dutReadback = Get-Node "$dataStructPath/Wp100RunSequenceResultStruct"
  if (($dutReadback.elementType -ne 'DUT') -or
      ((Get-Sha256 ([string]$dutReadback.declaration)) -ne
       (Get-Sha256 (Get-SourceText 'Wp100RunSequenceResultStruct.st')))) {
    throw "AI-owned DUT readback differs during $Phase`: Wp100RunSequenceResultStruct"
  }
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
$autoInfoLineGate = Assert-RequiredEnumItems `
  -CandidatePaths $autoInfoLineEnumPaths `
  -ExpectedItems $requiredAutoInfoLineItems `
  -EnumName 'AutoInfoLineEnum'

$steps = @(
  [pscustomobject]@{ Name = 'N000'; Comment = 'Initialize measurement sequence' },
  [pscustomobject]@{ Name = 'N010'; Comment = 'Check part before LEFT' },
  [pscustomobject]@{ Name = 'N015'; Comment = 'Wait fixture LEFT' },
  [pscustomobject]@{ Name = 'N020'; Comment = 'Start LEFT measurement' },
  [pscustomobject]@{ Name = 'N030'; Comment = 'Wait LEFT measurement' },
  [pscustomobject]@{ Name = 'N040'; Comment = 'Check part before MIDDLE' },
  [pscustomobject]@{ Name = 'N045'; Comment = 'Wait fixture MIDDLE' },
  [pscustomobject]@{ Name = 'N050'; Comment = 'Start MIDDLE measurement' },
  [pscustomobject]@{ Name = 'N060'; Comment = 'Wait MIDDLE measurement' },
  [pscustomobject]@{ Name = 'N070'; Comment = 'Check part before RIGHT' },
  [pscustomobject]@{ Name = 'N075'; Comment = 'Wait fixture RIGHT' },
  [pscustomobject]@{ Name = 'N080'; Comment = 'Start RIGHT measurement' },
  [pscustomobject]@{ Name = 'N090'; Comment = 'Wait RIGHT measurement' },
  [pscustomobject]@{ Name = 'N999'; Comment = 'Finish measurement sequence' }
)

$targetDeclaration = Get-SourceText 'SqC_Wp100_Run\declaration.st'
$targetImplementation = New-LinearSfcImplementation $steps
$targetDeclarationSha = Get-Sha256 $targetDeclaration
$targetImplementationSha = Get-Sha256 $targetImplementation
$targetRestReadbackImplementationSha = Get-Sha256 (Get-SfcRestReadbackImplementation $targetImplementation)
$sequenceNode = Get-Node $sequencePath

$generatedDeclarationSha = 'dfb93c51ea220816248fad97c9b736c509b55f2861669fb5dfb5182ad538fefa'
$generatedImplementationSha = '387bcbe666d701dd8288fdada987befe69fc6e9872369af1f2f88750761955a8'
$preGuidanceImplementationSha = 'da58cd02d154073bcabd6f4e11554635566aa722530c040856864e4b1090cf16'
$preGuidanceRestReadbackImplementationSha = '32aa736b716e45c0583fb95ed7f447dcaf7e21a95fed5a2477fd6ed21baba5e2'
$currentDeclarationSha = Get-Sha256 $sequenceNode.declaration
$currentImplementationSha = Get-Sha256 $sequenceNode.implementation
if ($currentDeclarationSha -ne $targetDeclarationSha) {
  throw "SqC_Wp100_Run declaration differs from the canonical CpStudio interface (current=$currentDeclarationSha expected=$targetDeclarationSha); configure/export it in CpStudio before continuing."
}
$preservedSequenceDeclaration = [string]$sequenceNode.declaration
$preservedSequenceDeclarationExactSha = Get-ExactSha256 $preservedSequenceDeclaration
$script:PreservedDeclarations[$sequencePath] = $preservedSequenceDeclaration
if ($currentImplementationSha -notin @(
    $generatedImplementationSha,
    $preGuidanceImplementationSha,
    $preGuidanceRestReadbackImplementationSha,
    $targetImplementationSha,
    $targetRestReadbackImplementationSha
  )) {
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
$preStyleChildSha256 = @{
  # Compiled AI-owned source immediately before the condition-style migration.
  '_aN020_active' = 'c76fcb5f058b2af5d13c03be50462844f74ab484908af4b7c039e6c45b6bcfeb'
  '_aN030_active' = '233ffff662c5fcbf4e6143da84fb45ac2109ca003f7a12acef23cce759bbfdeb'
  '_aN050_active' = '8e110dba0742bef5f308b7c0f1306d49c0d2583fbe4d034c61814cf48f524df9'
  '_aN060_active' = '88ca6dbb3d18bc144d54394e70926fcff39f35c3e184c8cfa97003d27d0ab565'
  '_aN080_active' = 'aa67a8349d4c52e4f789fa90342faaff4cbda45991370f3362252c0adccb9651'
  '_aN090_active' = 'f5e6152c1a62670c8d1e501c2a41a7422fefa8ac0e19677403322578db701187'
  'CheckPartPresent' = '1af52305662585668f66d4335457e2d0df4cb5d2af9da4a8d9e0e87769572aa1'
  'OnChainFinish' = '5b5ee831390551b0b6f1d0e16277af5a7470961b825d73adae156ce643925ce8'
}
$preInnerSpaceChildSha256 = @{
  # Compiled intermediate source before spaces were added inside condition parentheses.
  '_aN020_active' = 'dc12657fcdaa9379dd9f16e721b5c6c8f49f25b2eb49cf3e606a078136c1c922'
  '_aN030_active' = '7b138ef5a295518d1f4016d59688e62723b24abee99af0947b505775806c392f'
  '_aN050_active' = 'f01303b6417651ebeaeec6d7d9b04e80fe8917cca03482972183f0f6c813875a'
  '_aN060_active' = '4913dad12273e38d0e1e101a2c613c3674bc5d004af23ccfa1daa84f654b50d6'
  '_aN080_active' = 'a715cfb5f5388eb1099e0d75d7fafef556d9d80f4e87a17a7cbd5c2d04116705'
  '_aN090_active' = 'acb43f7dab9d0bacf2d8bb19b6f7e53b20edc5edb364f7d43e163cbffacd317a'
  'CheckPartPresent' = 'cd496c2c988cf4198d4130db3175f2c0fa99e0ec55cfb68cac14745a4ae4b232'
  'OnChainFinish' = '08ba3e57bbed8f813919c78d91c3439426968da780858a4ea7ffb2a2b2cceb45'
}
$preC0198ChildSha256 = @{
  # Compiled source before SetEvent AdditionalInfo was limited to STRING(63).
  'CheckPartPresent' = '208214e0b882d4816bcf6c86ce4fa5b39b50765bdc10e274cdd3dbcf083a6f54'
}
$preGuidanceChildSha256 = @{
  # Current compiled Run sequence before operator guidance is added.
  '_aN000_active' = '5fb7bad100856aa9d5af35a2d1082cb2be913bd5b55ca20bb4633951111c95ec'
  '_aN010_active' = '303c4d44cd868150a051cb0ffefb36f487f8dca4d8a049c0161d75e4591acbe1'
  '_aN040_active' = '479d7c3925848816b654657b7027d78650263f94c61061bddc64ef60a01bc46f'
  '_aN070_active' = '555e4835c68ebb3f6c83f6ab9be1db4a123b5afe776a06f75f6aa5d5036603ba'
  '_aN999_active' = '5623553c37c8b509e93ec6e910aa2abde1e8d07c76fe21fb1312f48243b80dd8'
  'OnChainFinish' = '52599c4bd83965909566669bb79cbc9a29fa17269da17c4416e85c305cb3f8d2'
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
    $matchesGenerated = $generatedChildSha256.ContainsKey($childName) -and
                        ($childSha256 -eq $generatedChildSha256[$childName])
    $matchesPreStyle = $preStyleChildSha256.ContainsKey($childName) -and
                       ($childSha256 -eq $preStyleChildSha256[$childName])
    $matchesPreInnerSpace = $preInnerSpaceChildSha256.ContainsKey($childName) -and
                            ($childSha256 -eq $preInnerSpaceChildSha256[$childName])
    $matchesPreC0198 = $preC0198ChildSha256.ContainsKey($childName) -and
                       ($childSha256 -eq $preC0198ChildSha256[$childName])
    $matchesPreGuidance = $preGuidanceChildSha256.ContainsKey($childName) -and
                          ($childSha256 -eq $preGuidanceChildSha256[$childName])
    if (($childSha256 -ne $targetChildSha256) -and
        (-not $matchesGenerated) -and
        (-not $matchesPreStyle) -and
        (-not $matchesPreInnerSpace) -and
        (-not $matchesPreC0198) -and
        (-not $matchesPreGuidance)) {
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
  [string[]]$baseline = @()
  if ($generatedChildSha256.ContainsKey($name)) {
    $baseline += $generatedChildSha256[$name]
  }
  if ($preStyleChildSha256.ContainsKey($name)) {
    $baseline += $preStyleChildSha256[$name]
  }
  if ($preInnerSpaceChildSha256.ContainsKey($name)) {
    $baseline += $preInnerSpaceChildSha256[$name]
  }
  if ($preGuidanceChildSha256.ContainsKey($name)) {
    $baseline += $preGuidanceChildSha256[$name]
  }
  $childStatus[$step.Name] = Set-CodeChild -Name $name -ElementType Action -SourceFile "SqC_Wp100_Run\actions\$($step.Name).st" -AllowedBaselineSha256 $baseline
}
$childStatus.CheckPartPresent = Set-CodeChild -Name 'CheckPartPresent' -ElementType POUMethod -SourceFile 'SqC_Wp100_Run\methods\CheckPartPresent.st' -AllowedBaselineSha256 @($preStyleChildSha256.CheckPartPresent, $preInnerSpaceChildSha256.CheckPartPresent, $preC0198ChildSha256.CheckPartPresent)
$childStatus.OnChainFinish = Set-CodeChild -Name 'OnChainFinish' -ElementType POUMethod -SourceFile 'SqC_Wp100_Run\OnChainFinish.st' -AllowedBaselineSha256 @($generatedChildSha256.OnChainFinish, $preStyleChildSha256.OnChainFinish, $preInnerSpaceChildSha256.OnChainFinish, $preGuidanceChildSha256.OnChainFinish)

$parentChanged = ($currentImplementationSha -notin @($targetImplementationSha, $targetRestReadbackImplementationSha))
if ($parentChanged) {
  $sequenceNode = Get-Node $sequencePath
  $sequenceNode.implementation = $targetImplementation
  Add-WriteRequest -Method Put `
    -Uri $sequenceUri `
    -Path $sequencePath `
    -Kind 'update-sfc-graph' `
    -Body $sequenceNode `
    -BeforeFingerprint $script:PreflightObservations[$sequencePath].Fingerprint `
    -TargetSha256 $targetImplementationSha
}

$obsoleteChildren = @($generatedChildSha256.Keys | Where-Object { $_ -notin $targetChildren -and (Test-NodeExists "$sequencePath/$_") })
foreach ($childName in $obsoleteChildren) {
  $childStatus["retained-obsolete:$childName"] = 'retained-delete-disabled'
}

$plan = New-WriterPlan `
  -WriterName 'apply_wp100_run_sequence_rest.ps1' `
  -ProjectPath $currentProject.path `
  -ProfileName $currentProject.profileName `
  -ChainPath $sequencePath `
  -DeclarationExactSha256 $preservedSequenceDeclarationExactSha `
  -RetainedObsoleteChildren $obsoleteChildren
$planSha256 = Get-PlanSha256 $plan
$planResult = [ordered]@{
  mode = $Mode
  planSha256 = $planSha256
  plan = $plan
}
if ($Mode -eq 'PlanOnly') {
  $planResult | ConvertTo-Json -Depth 20
  return
}
if ([string]::IsNullOrWhiteSpace($ExpectedPlanSha256)) {
  throw 'Apply requires -ExpectedPlanSha256 from a fresh PlanOnly run.'
}
if (-not $ExpectedPlanSha256.Equals($planSha256, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Plan hash mismatch; refusing Apply (expected=$ExpectedPlanSha256 current=$planSha256)."
}

$script:CapturePreflight = $false
$projectBeforeWrite = Invoke-RestMethod -Method Get -Uri "$BaseUri/projects/current"
if ((-not ([IO.Path]::GetFullPath($projectBeforeWrite.path)).Equals($expectedResolved, [StringComparison]::OrdinalIgnoreCase)) -or
    ($projectBeforeWrite.profileName -ne 'ctrlX PLC 2.6.8')) {
  throw 'Active PLC project/profile changed between PlanOnly preflight and Apply.'
}
Assert-PreflightSnapshotCurrent

# Mutation phase begins only after the immutable plan/hash gate and complete
# second GET/hash pass have succeeded for every observed object.
try {
  Invoke-WriteRequests
  Assert-Wp100RunSequenceTargets -Phase 'pre-save verification'

$hasChanges = ($script:WriteRequests.Count -gt 0)
$saveResult = if ($hasChanges) {
  $result = (Save-CurrentProject).jobResultInfo
  # Saving is part of the transaction: re-read every graph, Action, Method and
  # DUT after the job completes so a persistence-time rewrite cannot pass as a
  # successful Apply.
  Assert-Wp100RunSequenceTargets -Phase 'post-save verification'
  $result
}
else {
  'No changes; save skipped.'
}
}
catch {
  $transactionError = $_
  $rollbackResult = Invoke-WriteRollback
  throw (New-TransactionFailureMessage -OriginalError $transactionError -RollbackResult $rollbackResult)
}

[pscustomobject]@{
  project = $currentProject.path
  dut = $dutStatus
  children = $childStatus
  stepCount = $steps.Count
  mode = $Mode
  planSha256 = $planSha256
  declarationExactSha256 = $preservedSequenceDeclarationExactSha
  declarationTextUnchanged = $true
  implementationSha256 = $targetImplementationSha
  restReadbackImplementationSha256 = $targetRestReadbackImplementationSha
  saveResult = $saveResult
} | ConvertTo-Json -Depth 8
