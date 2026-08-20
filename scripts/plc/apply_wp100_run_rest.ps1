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
    [AllowNull()][string]$AllowedBaseline
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
  if ($null -eq $AllowedBaseline -or $current -ne $AllowedBaseline.Replace("`r`n", "`n")) {
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

function New-LinearSfcImplementation {
  param([Parameter(Mandatory)][object[]]$Steps)

  $nameGuid = '38391c6d-6d4a-42f8-8ee7-9f45e5adafa8'
  $commentGuid = '7d894980-aeea-405c-a0f6-e2b26429c58f'
  $falseGuid = '01580b27-6378-448b-8ecb-0e4b795b58d6'
  $numberGuid = 'bc882c11-1e91-4dd8-a6b8-2075724ed18b'
  $initialGuid = '6844a48e-46c2-4cc8-a185-a478f3b99cc0'
  $actionEnabledGuid = '62e1754b-7629-4e63-9cec-10ae0c536f1f'
  $actionGuid = '700a583f-b4d4-43e4-8c14-629c7cd3bec8'
  $transitionPriorityGuid = '8294df19-5962-4dee-a874-1051dabb0e3e'
  $nl = "`r`n"
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<body>${nl}  <SFC>${nl}")

  $previousTransitionId = $null
  $nextId = 0
  for ($index = 0; $index -lt $Steps.Count; $index++) {
    $step = $Steps[$index]
    $stepId = $nextId
    $nextId++
    $initialAttribute = if ($index -eq 0) { ' initialStep="true"' } else { '' }
    [void]$sb.Append("    <step localId=`"$stepId`"$initialAttribute name=`"$($step.Name)`">${nl}")
    [void]$sb.Append("      <position x=`"0`" y=`"0`" />${nl}")
    if ($null -eq $previousTransitionId) {
      [void]$sb.Append("      <connectionPointIn />${nl}")
    }
    else {
      [void]$sb.Append("      <connectionPointIn>${nl}        <connection refLocalId=`"$previousTransitionId`" />${nl}      </connectionPointIn>${nl}")
    }
    [void]$sb.Append("      <connectionPointOut formalParameter=`"sfc`" />${nl}")
    [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
    [void]$sb.Append("            <attribute guid=`"$nameGuid`">$(Escape-XmlText $step.Name)</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$commentGuid`">$(Escape-XmlText $step.Comment)</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$falseGuid`">FALSE</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$numberGuid`">0</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$initialGuid`">$(if ($index -eq 0) { 'TRUE' } else { 'FALSE' })</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$actionEnabledGuid`">TRUE</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$actionGuid`">_a$($step.Name)_active</attribute>${nl}")
    [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </step>${nl}")

    $expression = if ($index -eq ($Steps.Count - 1)) { '_retVal = JUMP9' } else { '_retVal = OK' }
    $inVariableId = $nextId
    $nextId++
    $transitionId = $nextId
    $nextId++
    [void]$sb.Append("    <inVariable localId=`"$inVariableId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointOut />${nl}      <expression>$expression</expression>${nl}    </inVariable>${nl}")
    [void]$sb.Append("    <transition localId=`"$transitionId`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$stepId`" formalParameter=`"sfc`" />${nl}      </connectionPointIn>${nl}      <condition>${nl}        <connectionPointIn>${nl}          <connection refLocalId=`"$inVariableId`" />${nl}        </connectionPointIn>${nl}      </condition>${nl}")
    [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
    [void]$sb.Append("            <attribute guid=`"$nameGuid`">$expression</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$falseGuid`">FALSE</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$numberGuid`">0</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$actionEnabledGuid`">FALSE</attribute>${nl}")
    [void]$sb.Append("            <attribute guid=`"$transitionPriorityGuid`">0</attribute>${nl}")
    [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </transition>${nl}")
    $previousTransitionId = $transitionId
  }

  $jumpId = $nextId
  [void]$sb.Append("    <jumpStep localId=`"$jumpId`" targetName=`"N999`">${nl}      <position x=`"0`" y=`"0`" />${nl}      <connectionPointIn>${nl}        <connection refLocalId=`"$previousTransitionId`" />${nl}      </connectionPointIn>${nl}")
  [void]$sb.Append("      <addData>${nl}        <data name=`"http://www.3s-software.com/plcopenxml/sfc/element`" handleUnknown=`"implementation`">${nl}          <attributes>${nl}")
  [void]$sb.Append("            <attribute guid=`"$nameGuid`">N999</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$commentGuid`">Not used</attribute>${nl}")
  [void]$sb.Append("            <attribute guid=`"$falseGuid`">FALSE</attribute>${nl}")
  [void]$sb.Append("          </attributes>${nl}        </data>${nl}      </addData>${nl}    </jumpStep>${nl}  </SFC>${nl}</body>")
  return $sb.ToString()
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
  [pscustomobject]@{ Name = 'N040'; Comment = 'Wait door closed' },
  [pscustomobject]@{ Name = 'N050'; Comment = 'Start Kistler / lower press' },
  [pscustomobject]@{ Name = 'N060'; Comment = 'Wait press lowered' },
  [pscustomobject]@{ Name = 'N070'; Comment = 'Wait press delay' },
  [pscustomobject]@{ Name = 'N080'; Comment = 'Start resistance test' },
  [pscustomobject]@{ Name = 'N090'; Comment = 'Read resistance result' },
  [pscustomobject]@{ Name = 'N100'; Comment = 'Raise press / stop Kistler' },
  [pscustomobject]@{ Name = 'N110'; Comment = 'Wait press raised' },
  [pscustomobject]@{ Name = 'N120'; Comment = 'Read Kistler result' },
  [pscustomobject]@{ Name = 'N130'; Comment = 'Open safety door' },
  [pscustomobject]@{ Name = 'N140'; Comment = 'Wait door open' },
  [pscustomobject]@{ Name = 'N999'; Comment = 'Finish run' }
)

$targetDeclaration = Get-SourceText 'SqS_Wp100_Run\declaration.st'
$targetImplementation = New-LinearSfcImplementation $steps
$runNode = Get-Node $runPath
$baselineDeclarationSha = 'e941ad68be1da946dd0c0851a4e883f715fb8dd3df1fb76ead9aa29624f74866'
$baselineImplementationSha = 'd5103f78bef8b7d93d20ac8ec9508899d23db63f578ac40df88b4bae4dce808d'
$currentDeclarationSha = Get-Sha256 $runNode.declaration
$currentImplementationSha = Get-Sha256 $runNode.implementation
$targetDeclarationSha = Get-Sha256 $targetDeclaration
$targetImplementationSha = Get-Sha256 $targetImplementation
if ($currentDeclarationSha -notin @($baselineDeclarationSha, $targetDeclarationSha)) {
  throw 'SqS_Wp100_Run declaration changed after audit; refusing overwrite.'
}
if ($currentImplementationSha -notin @($baselineImplementationSha, $targetImplementationSha)) {
  throw 'SqS_Wp100_Run SFC graph changed after audit; refusing overwrite.'
}

$allowedChildren = @('_aN000_active', '_aN010_active', '_aN020_active', '_aN030_active', '_aN040_active', '_aN050_active', '_aN060_active', '_aN070_active', '_aN080_active', '_aN090_active', '_aN100_active', '_aN110_active', '_aN120_active', '_aN130_active', '_aN140_active', '_aN999_active', 'OnChainFinish')
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

$actionStatus = [ordered]@{}
foreach ($step in $steps) {
  $allowed = if ($baselineActions.ContainsKey($step.Name)) { $baselineActions[$step.Name] } else { $null }
  $actionStatus[$step.Name] = Set-Action -Step $step.Name -SourceFile "SqS_Wp100_Run\actions\$($step.Name).st" -AllowedBaseline $allowed
}
$actionStatus.OnChainFinish = Set-Action -Step 'OnChainFinish' -SourceFile 'SqS_Wp100_Run\OnChainFinish.st' -AllowedBaseline $baselineActions.OnChainFinish

$runNode = Get-Node $runPath
$runNode.declaration = $targetDeclaration
$runNode.implementation = $targetImplementation
$null = Invoke-JsonRequest -Method Put -Uri $runUri -Body $runNode

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

$saveJob = Save-CurrentProject
[pscustomobject]@{
  project = $currentProject.path
  duts = $dutStatus
  actions = $actionStatus
  stepCount = $steps.Count
  declarationSha256 = $targetDeclarationSha
  implementationSha256 = $targetImplementationSha
  saveResult = $saveJob.jobResultInfo
} | ConvertTo-Json -Depth 8
