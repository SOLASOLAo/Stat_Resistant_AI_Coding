[CmdletBinding()]
param(
  [string]$BaseUri = 'http://localhost:9002/plc/engineering/api/v2',
  [string]$ExpectedProject = 'C:\A_Documents\A_Projects\A_Software\BPP_ResistantStation\Station010_0708\Plc\Stat010_V5.11_CtrlX_PLC.project'
)

$ErrorActionPreference = 'Stop'

$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$runPath = 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run'
$runUri = "$deviceRoot/$runPath"
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

  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant()
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

function Add-OrVerify-Dut {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$SourceFile
  )

  $declaration = Get-SourceText $SourceFile
  $path = "$dataStructPath/$Name"
  if (Test-NodeExists $path) {
    $existing = Get-Node $path
    if ($existing.elementType -ne 'DUT' -or $existing.declaration.Replace("`r`n", "`n") -ne $declaration) {
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

function Set-Action {
  param(
    [Parameter(Mandatory)][string]$Step,
    [Parameter(Mandatory)][string]$SourceFile,
    [AllowNull()][string[]]$AllowedBaselineSha256
  )

  $implementation = Get-SourceText $SourceFile
  $name = if ($Step -eq 'OnChainFinish') { 'OnChainFinish' } else { "_a${Step}_active" }
  $path = "$runPath/$name"

  if (-not (Test-NodeExists $path)) {
    if ($Step -eq 'OnChainFinish') {
      throw 'Generated OnChainFinish method is unexpectedly missing; refusing to invent its method metadata.'
    }
    $body = [ordered]@{
      name = $name
      elementType = 'Action'
      language = 'ST'
      implementation = $implementation
    }
    $null = Invoke-JsonRequest -Method Post -Uri $runUri -Body $body
    return 'created'
  }

  $node = Get-Node $path
  $current = if ($Step -eq 'OnChainFinish') {
    ($node.declaration.Replace("`r`n", "`n") + "`n" + $node.implementation.Replace("`r`n", "`n"))
  }
  else {
    $node.implementation.Replace("`r`n", "`n")
  }

  $target = if ($Step -eq 'OnChainFinish') { $implementation } else { $implementation }
  if ($current -eq $target) {
    return 'verified'
  }
  $currentSha256 = Get-Sha256 $current
  if ($null -eq $AllowedBaselineSha256 -or $currentSha256 -notin $AllowedBaselineSha256) {
    throw "Existing object has unrecognized edits: $path"
  }

  if ($Step -eq 'OnChainFinish') {
    $split = $implementation -split "`n`n", 2
    if ($split.Count -ne 2) {
      throw 'OnChainFinish source must contain declaration and implementation separated by one blank line.'
    }
    $node.declaration = $split[0] + "`n"
    $node.implementation = $split[1]
  }
  else {
    $node.implementation = $implementation
  }
  $null = Invoke-JsonRequest -Method Put -Uri (ConvertTo-ApiUri $path) -Body $node
  return 'updated'
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
    BranchGuid = '23bdaa98-72ec-41f7-817b-9dede5697086'
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
    [AllowEmptyString()][string]$SourceFormalParameter = '',
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
    $formal = if ([string]::IsNullOrEmpty($SourceFormalParameter)) { '' } else { " formalParameter=`"$SourceFormalParameter`"" }
    [void]$sb.Append("      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`"$formal />${nl}      </connectionPointIn>${nl}")
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
    [Parameter(Mandatory)][string]$Expression,
    [AllowEmptyString()][string]$SourceFormalParameter = 'sfc'
  )

  $nl = $Context.NewLine
  $sb = $Context.Builder
  $escapedExpression = Escape-XmlText $Expression
  $inVariableId = Get-NextSfcId $Context
  $transitionId = Get-NextSfcId $Context
  $formal = if ([string]::IsNullOrEmpty($SourceFormalParameter)) { '' } else { " formalParameter=`"$SourceFormalParameter`"" }
  [void]$sb.Append("    <inVariable localId=`"$inVariableId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointOut />${nl}      <expression>$escapedExpression</expression>${nl}    </inVariable>${nl}")
  [void]$sb.Append("    <transition localId=`"$transitionId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`"$formal />${nl}      </connectionPointIn>${nl}      <condition>${nl}        <connectionPointIn>${nl}          <connection refLocalId=`"$inVariableId`" />${nl}        </connectionPointIn>${nl}      </condition>${nl}")
  [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NameGuid)`">$escapedExpression</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.FalseGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.NumberGuid)`">0</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.ActionEnabledGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.TransitionPriorityGuid)`">0</attribute>${nl}")
  [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </transition>${nl}")
  return $transitionId
}

function Add-SfcSimultaneousDivergence {
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][int]$SourceId,
    [Parameter(Mandatory)][string]$Name
  )

  $id = Get-NextSfcId $Context
  $nl = $Context.NewLine
  $sb = $Context.Builder
  [void]$sb.Append("    <simultaneousDivergence name=`"`" localId=`"$id`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$SourceId`" />${nl}      </connectionPointIn>${nl}")
  [void]$sb.Append("      <connectionPointOut formalParameter=`"sfc`" />${nl}      <connectionPointOut formalParameter=`"sfc`" />${nl}")
  [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.FalseGuid)`">FALSE</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$($Context.BranchGuid)`">TRUE</attribute>${nl}")
  [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </simultaneousDivergence>${nl}")
  return $id
}

function Add-SfcSimultaneousConvergence {
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][int[]]$SourceIds
  )

  $id = Get-NextSfcId $Context
  $nl = $Context.NewLine
  $sb = $Context.Builder
  [void]$sb.Append("    <simultaneousConvergence localId=`"$id`">${nl}      <position x=`"0`" y=`"0`" />${nl}")
  foreach ($sourceId in $SourceIds) {
    [void]$sb.Append("      <connectionPointIn>${nl}        <connection refLocalId=`"$sourceId`" formalParameter=`"sfc`" />${nl}      </connectionPointIn>${nl}")
  }
  [void]$sb.Append("      <connectionPointOut />${nl}    </simultaneousConvergence>${nl}")
  return $id
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

function New-Wp100RunSfcImplementation {
  param([Parameter(Mandatory)][object[]]$Steps)

  $stepByName = @{}
  foreach ($step in $Steps) {
    $stepByName[$step.Name] = $step
  }

  $ctx = New-SfcContext
  $nl = $ctx.NewLine
  [void]$ctx.Builder.Append("<body>${nl}  <SFC>${nl}")

  $stepId = Add-SfcStep -Context $ctx -Step $stepByName.N000 -SourceId $null -Initial
  $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Expression '_retVal = OK'

  foreach ($name in @('N010', 'N020', 'N030', 'N040', 'N045')) {
    $stepId = Add-SfcStep -Context $ctx -Step $stepByName[$name] -SourceId $sourceId
    $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Expression '_retVal = OK'
  }

  $startSplitId = Add-SfcSimultaneousDivergence -Context $ctx -SourceId $sourceId -Name 'ParallelStart'

  $pressStartId = Add-SfcStep -Context $ctx -Step $stepByName.N050 -SourceId $startSplitId
  $pressStartTransitionId = Add-SfcTransition -Context $ctx -SourceId $pressStartId -Expression '_retVal = OK'
  $pressDownWaitId = Add-SfcStep -Context $ctx -Step $stepByName.N060 -SourceId $pressStartTransitionId

  $kistlerStartId = Add-SfcStep -Context $ctx -Step $stepByName.N051 -SourceId $startSplitId
  $kistlerStartTransitionId = Add-SfcTransition -Context $ctx -SourceId $kistlerStartId -Expression '_retVal2 = OK'
  $kistlerRunningWaitId = Add-SfcStep -Context $ctx -Step $stepByName.N061 -SourceId $kistlerStartTransitionId

  $startJoinId = Add-SfcSimultaneousConvergence -Context $ctx -SourceIds @($pressDownWaitId, $kistlerRunningWaitId)
  $sourceId = Add-SfcTransition -Context $ctx -SourceId $startJoinId -Expression '(_retVal = OK) AND (_retVal2 = OK)'

  foreach ($name in @('N070', 'N080', 'N090', 'N095')) {
    $stepId = Add-SfcStep -Context $ctx -Step $stepByName[$name] -SourceId $sourceId
    $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Expression '_retVal = OK'
  }

  $finishSplitId = Add-SfcSimultaneousDivergence -Context $ctx -SourceId $sourceId -Name 'ParallelFinish'

  $pressUpStartId = Add-SfcStep -Context $ctx -Step $stepByName.N100 -SourceId $finishSplitId
  $pressUpStartTransitionId = Add-SfcTransition -Context $ctx -SourceId $pressUpStartId -Expression '_retVal = OK'
  $pressUpWaitId = Add-SfcStep -Context $ctx -Step $stepByName.N110 -SourceId $pressUpStartTransitionId

  $kistlerStopId = Add-SfcStep -Context $ctx -Step $stepByName.N101 -SourceId $finishSplitId
  $kistlerStopTransitionId = Add-SfcTransition -Context $ctx -SourceId $kistlerStopId -Expression '_retVal2 = OK'
  $kistlerResultWaitId = Add-SfcStep -Context $ctx -Step $stepByName.N120 -SourceId $kistlerStopTransitionId

  $finishJoinId = Add-SfcSimultaneousConvergence -Context $ctx -SourceIds @($pressUpWaitId, $kistlerResultWaitId)
  $sourceId = Add-SfcTransition -Context $ctx -SourceId $finishJoinId -Expression '(_retVal = OK) AND (_retVal2 = OK)'

  foreach ($name in @('N130', 'N140')) {
    $stepId = Add-SfcStep -Context $ctx -Step $stepByName[$name] -SourceId $sourceId
    $sourceId = Add-SfcTransition -Context $ctx -SourceId $stepId -Expression '_retVal = OK'
  }

  $finishStepId = Add-SfcStep -Context $ctx -Step $stepByName.N999 -SourceId $sourceId
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
  [pscustomobject]@{ Name = 'N000'; Comment = 'Initialize run' },
  [pscustomobject]@{ Name = 'N010'; Comment = 'Check fixture position' },
  [pscustomobject]@{ Name = 'N020'; Comment = 'Wait start button' },
  [pscustomobject]@{ Name = 'N030'; Comment = 'Close safety door' },
  [pscustomobject]@{ Name = 'N040'; Comment = 'Wait safety feedback' },
  [pscustomobject]@{ Name = 'N045'; Comment = 'Check measure release' },
  [pscustomobject]@{ Name = 'N050'; Comment = 'Start press WRKPOS' },
  [pscustomobject]@{ Name = 'N060'; Comment = 'Wait press WRKPOS' },
  [pscustomobject]@{ Name = 'N051'; Comment = 'Start Kistler MEASURE' },
  [pscustomobject]@{ Name = 'N061'; Comment = 'Wait Kistler running' },
  [pscustomobject]@{ Name = 'N070'; Comment = 'Wait press delay' },
  [pscustomobject]@{ Name = 'N080'; Comment = 'Start resistance test' },
  [pscustomobject]@{ Name = 'N090'; Comment = 'Wait resistance result' },
  [pscustomobject]@{ Name = 'N095'; Comment = 'Check release ready' },
  [pscustomobject]@{ Name = 'N100'; Comment = 'Start press BASPOS' },
  [pscustomobject]@{ Name = 'N110'; Comment = 'Wait press BASPOS' },
  [pscustomobject]@{ Name = 'N101'; Comment = 'Stop Kistler MEASURE' },
  [pscustomobject]@{ Name = 'N120'; Comment = 'Wait Kistler result' },
  [pscustomobject]@{ Name = 'N130'; Comment = 'Open safety door' },
  [pscustomobject]@{ Name = 'N140'; Comment = 'Wait door open' },
  [pscustomobject]@{ Name = 'N999'; Comment = 'Finish run' }
)

$targetDeclaration = Get-SourceText 'SqS_Wp100_Run\declaration.st'
$targetImplementation = New-Wp100RunSfcImplementation $steps
$runNode = Get-Node $runPath
$baselineDeclarationSha = '269963a32c3e5decf6d1cfedfbe8d88b5575254c880461d947feabfec45b0a92'
$baselineImplementationSha = '8cf66075d60284a01c457a4b5d9d876ef8fcc7deef7361b9294834132e2d7cfd'
$currentDeclarationSha = Get-Sha256 $runNode.declaration
$currentImplementationSha = Get-Sha256 $runNode.implementation
$targetDeclarationSha = Get-Sha256 $targetDeclaration
$targetImplementationSha = Get-Sha256 $targetImplementation
$previousDeclarationSha = 'ddee296f091090f744b8879b6f53a69112c91b83f65c4ee4b4d44122cfc3ab0e'
if ($currentDeclarationSha -notin @($baselineDeclarationSha, $previousDeclarationSha, $targetDeclarationSha)) {
  throw 'SqS_Wp100_Run declaration changed after audit; refusing overwrite.'
}
if ($currentImplementationSha -notin @($baselineImplementationSha, $targetImplementationSha)) {
  throw 'SqS_Wp100_Run SFC graph changed after audit; refusing overwrite.'
}
$runNeedsUpdate = ($currentDeclarationSha -ne $targetDeclarationSha) -or
                  ($currentImplementationSha -ne $targetImplementationSha)

$allowedChildren = @('_aN000_active', '_aN010_active', '_aN020_active', '_aN030_active', '_aN040_active', '_aN045_active', '_aN050_active', '_aN051_active', '_aN060_active', '_aN061_active', '_aN070_active', '_aN080_active', '_aN090_active', '_aN095_active', '_aN100_active', '_aN101_active', '_aN110_active', '_aN120_active', '_aN130_active', '_aN140_active', '_aN999_active', 'OnChainFinish')
$unknownChildren = @($runNode.children | Where-Object { $_ -notin $allowedChildren })
if ($unknownChildren.Count -gt 0) {
  throw "SqS_Wp100_Run contains unrecognized child objects: $($unknownChildren -join ', ')"
}

$dutStatus = [ordered]@{}
$dutStatus.Wp100ResistanceResultStruct = Add-OrVerify-Dut 'Wp100ResistanceResultStruct' 'Wp100ResistanceResultStruct.st'
$dutStatus.Wp100KistlerResultStruct = Add-OrVerify-Dut 'Wp100KistlerResultStruct' 'Wp100KistlerResultStruct.st'
$dutStatus.Wp100RunResultStruct = Add-OrVerify-Dut 'Wp100RunResultStruct' 'Wp100RunResultStruct.st'

$baselineActions = @{
  N000 = "// Init step`n// Initialize variables, check references, no actions`n`n_retVal := OK;`n"
  N100 = "// Comment`n`n_retVal := OK;`n"
  N999 = "// Finish step`n// Finish chain, no actions, use OnChainFinish to reset variables`n`n_env.ChainControl := OpconChainControl.DONE;`n"
  OnChainFinish = "/// Method is called for only one cycle if chain stops working by any given reason`nMETHOD PROTECTED OnChainFinish`nVAR_INPUT`n  Reason: OpconChainFinishReason;`nEND_VAR`n`n// Call base method`nSUPER^.OnChainFinish(Reason);`n`nCASE Reason`nOF`n  OpconChainFinishReason.ERROR,`n  OpconChainFinishReason.CANCEL,`n  OpconChainFinishReason.DONE:`n    ;`n  ELSE`n    ; // do nothing`nEND_CASE`n"
}
$previousActionSha256 = @{
  # First compiled Run-chain version. These hashes allow a controlled upgrade
  # from the linear command pairs to explicit OpCon SFC parallel branches.
  N000 = @(
    'b12c8bd9dbf23705cb671cc30fb285419d4a9df51b39c7bb31368084dcd267c8',
    '5391b820cbeef4a35b031ce5378e422b81c843e6a75b990032be45aab3d17c8a'
  )
  N010 = 'bb5431cc40a495342738ad4b952ac7201915b8eb14b1a7a8765df903479ab7fa'
  N050 = @(
    '34c8f8ec24fff9711210bf7abfa80f089eb88e7b56d0f2128df91e5414735351',
    'fb9f8c9c60384a14ae3d75675adfdea8b08872517fc07962315d24a234b7aa61'
  )
  N051 = '264a3b87c12ba92ea7fde0f0852613df42854e76953550d0502cd2d7c6d7ade6'
  N060 = '8d9d82ed762360320b292aab0bef59b9118f12cafec66892e6ad4810e18782fd'
  N095 = 'ffdcd4639873d195b3408da069dd75942ae937468616636f5c1987ca29db0966'
  N100 = @(
    'cf66beec948b4918578d4d4e97d0ad819259ad41cdfcedbc8da7706064c9c4b9',
    'ea353652ad73156b0d4e9c7990ec4845f693192e4bf350890e5e8288ce3adff2'
  )
  N110 = '0df9515af6c65ddea589d839c400bb6e9a95f40acb94741f1bc8b2561ba9c813'
  N120 = '7dbaf6138936f5933e13c420b784736d5bce02292b742cd5b49bb00fce561e51'
}
$previousOnChainFinishSha256 = '638fa350677e14d0d0ce4706ff6bdcb2f8df50aea2ae21a6bd31119d7aaa60dc'

$actionStatus = [ordered]@{}
foreach ($step in $steps) {
  $allowedSha256 = @()
  if ($baselineActions.ContainsKey($step.Name)) {
    $allowedSha256 += Get-Sha256 $baselineActions[$step.Name]
  }
  if ($previousActionSha256.ContainsKey($step.Name)) {
    $allowedSha256 += @($previousActionSha256[$step.Name])
  }
  $actionStatus[$step.Name] = Set-Action -Step $step.Name -SourceFile "SqS_Wp100_Run\actions\$($step.Name).st" -AllowedBaselineSha256 $allowedSha256
}
$actionStatus.OnChainFinish = Set-Action -Step 'OnChainFinish' -SourceFile 'SqS_Wp100_Run\OnChainFinish.st' -AllowedBaselineSha256 @((Get-Sha256 $baselineActions.OnChainFinish), $previousOnChainFinishSha256)

if ($runNeedsUpdate) {
  $runNode = Get-Node $runPath
  $runNode.declaration = $targetDeclaration
  $runNode.implementation = $targetImplementation
  $null = Invoke-JsonRequest -Method Put -Uri $runUri -Body $runNode
}

$readback = Get-Node $runPath
if ((Get-Sha256 $readback.declaration) -ne $targetDeclarationSha) {
  throw 'SqS_Wp100_Run declaration readback differs after PUT.'
}
if ((Get-Sha256 $readback.implementation) -ne $targetImplementationSha) {
  throw 'SqS_Wp100_Run graph readback differs after PUT.'
}
$expectedChildren = @($allowedChildren | Sort-Object)
$actualChildren = @($readback.children | Sort-Object)
if (($expectedChildren -join "`n") -ne ($actualChildren -join "`n")) {
  throw "SqS_Wp100_Run child list mismatch after update: $($actualChildren -join ', ')"
}

$hasChanges = $runNeedsUpdate -or
              (@($dutStatus.Values | Where-Object { $_ -ne 'verified' }).Count -gt 0) -or
              (@($actionStatus.Values | Where-Object { $_ -ne 'verified' }).Count -gt 0)
$saveResult = if ($hasChanges) {
  (Save-CurrentProject).jobResultInfo
}
else {
  'No changes; save skipped.'
}
[pscustomobject]@{
  project = $currentProject.path
  duts = $dutStatus
  actions = $actionStatus
  stepCount = $steps.Count
  declarationSha256 = $targetDeclarationSha
  implementationSha256 = $targetImplementationSha
  saveResult = $saveResult
} | ConvertTo-Json -Depth 8
