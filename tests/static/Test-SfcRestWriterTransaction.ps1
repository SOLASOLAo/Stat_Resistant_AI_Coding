[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$BaseUri = 'http://mock-transaction/plc/engineering/api/v2'
$deviceRoot = "$BaseUri/devices/Device/Plc%20Logic"
$parentPath = 'Application/Test/Chain'
$actionPath = "$parentPath/_aN010_active"
$methodPath = "$parentPath/OnChainFinish"
$newActionPath = "$parentPath/_aN015_active"
$dataParentPath = 'Application/Test/Structs/Data'
$newDutPath = "$dataParentPath/TestResultStruct"

$global:SfcTxNodes = @{}
$global:SfcTxCalls = [Collections.Generic.List[object]]::new()
$global:SfcTxMutationCounter = 0
$global:SfcTxFailMutationNumber = 0
$global:SfcTxFailAfterApply = $false
$global:SfcTxRollbackMode = $false
$global:SfcTxFailRollbackPath = ''
$global:SfcTxJobCounter = 0

function Assert-True {
  param(
    [Parameter(Mandatory)][bool]$Condition,
    [Parameter(Mandatory)][string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Copy-JsonValue {
  param([Parameter(Mandatory)]$Value)

  return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}

function Copy-NodeMap {
  param([Parameter(Mandatory)][Collections.IDictionary]$Nodes)

  $copy = @{}
  foreach ($key in $Nodes.Keys) {
    $copy[$key] = Copy-JsonValue $Nodes[$key]
  }
  return $copy
}

function Get-Sha256 {
  param([AllowEmptyString()][string]$Text)

  $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString(
      $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized))
    ).Replace('-', '').ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
}

function ConvertTo-ApiUri {
  param([Parameter(Mandatory)][string]$Path)

  $uri = $deviceRoot
  foreach ($segment in ($Path -split '/')) {
    $uri += '/' + [Uri]::EscapeDataString($segment)
  }
  return $uri
}

function ConvertFrom-ApiUri {
  param([Parameter(Mandatory)][string]$Uri)

  $prefix = "$deviceRoot/"
  if (-not $Uri.StartsWith($prefix, [StringComparison]::Ordinal)) {
    return $null
  }
  return (($Uri.Substring($prefix.Length) -split '/') |
      ForEach-Object { [Uri]::UnescapeDataString($_) }) -join '/'
}

function New-NotFoundError {
  param([Parameter(Mandatory)][string]$Path)

  $errorObject = [InvalidOperationException]::new("Mock node does not exist: $Path")
  $errorObject.Data['StatusCode'] = 404
  return $errorObject
}

function Test-IsNotFoundError {
  param([Parameter(Mandatory)]$ErrorRecord)

  return ($ErrorRecord.Exception.Data.Contains('StatusCode') -and
          ([int]$ErrorRecord.Exception.Data['StatusCode'] -eq 404))
}

function Set-MockParentChild {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][bool]$Present
  )

  $parent = Get-ParentPath $Path
  if (-not $global:SfcTxNodes.ContainsKey($parent)) {
    return
  }
  $leaf = Get-LeafName $Path
  $children = [Collections.Generic.List[string]]::new()
  foreach ($child in @($global:SfcTxNodes[$parent].children)) {
    if ([string]$child -ne $leaf) {
      $children.Add([string]$child)
    }
  }
  if ($Present -and (-not $children.Contains($leaf))) {
    $children.Add($leaf)
  }
  $global:SfcTxNodes[$parent].children = $children.ToArray()
}

function Invoke-RestMethod {
  param(
    [Parameter(Mandatory)][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [AllowNull()][string]$ContentType,
    [AllowNull()]$Body
  )

  if (($Method -eq 'Get') -and $Uri.StartsWith("$BaseUri/jobs/", [StringComparison]::Ordinal)) {
    return [pscustomobject]@{ state = 'Done'; jobResultInfo = 'Mock save complete.' }
  }
  if (($Method -eq 'Post') -and ($Uri -eq "$BaseUri/jobs")) {
    $bodyJson = [Text.Encoding]::UTF8.GetString([byte[]]$Body)
    $global:SfcTxJobCounter++
    $global:SfcTxCalls.Add([pscustomobject]@{
        phase = if ($global:SfcTxRollbackMode) { 'rollback' } else { 'apply' }
        method = 'Post'
        path = 'ProjectJob/Save'
        bodyCanonicalJson = $bodyJson
      })
    return [pscustomobject]@{ id = "mock-save-$($global:SfcTxJobCounter)" }
  }

  $path = ConvertFrom-ApiUri $Uri
  if (($Method -eq 'Get') -and ($null -ne $path)) {
    if (-not $global:SfcTxNodes.ContainsKey($path)) {
      throw (New-NotFoundError $path)
    }
    return Copy-JsonValue $global:SfcTxNodes[$path]
  }

  if (($Method -in @('Put', 'Post', 'Delete')) -and ($null -ne $path)) {
    $phase = if ($global:SfcTxRollbackMode) { 'rollback' } else { 'apply' }
    if ($global:SfcTxRollbackMode -and
        ($path -eq $global:SfcTxFailRollbackPath)) {
      throw "Injected rollback failure: $path"
    }

    if (-not $global:SfcTxRollbackMode) {
      $global:SfcTxMutationCounter++
      $shouldFail = ($global:SfcTxFailMutationNumber -gt 0) -and
                    ($global:SfcTxMutationCounter -eq $global:SfcTxFailMutationNumber)
      if ($shouldFail -and (-not $global:SfcTxFailAfterApply)) {
        throw "Injected mutation failure before apply: $path"
      }
    }
    else {
      $shouldFail = $false
    }

    $bodyJson = $null
    if ($Method -eq 'Put') {
      $bodyJson = [Text.Encoding]::UTF8.GetString([byte[]]$Body)
      $global:SfcTxNodes[$path] = $bodyJson | ConvertFrom-Json
    }
    elseif ($Method -eq 'Post') {
      $bodyJson = [Text.Encoding]::UTF8.GetString([byte[]]$Body)
      $node = $bodyJson | ConvertFrom-Json
      $targetPath = "$path/$($node.name)"
      $global:SfcTxNodes[$targetPath] = $node
      Set-MockParentChild -Path $targetPath -Present $true
    }
    else {
      if (-not $global:SfcTxNodes.ContainsKey($path)) {
        throw (New-NotFoundError $path)
      }
      $global:SfcTxNodes.Remove($path)
      Set-MockParentChild -Path $path -Present $false
    }

    $global:SfcTxCalls.Add([pscustomobject]@{
        phase = $phase
        method = $Method
        path = $path
        bodyCanonicalJson = $bodyJson
      })
    if ($shouldFail -and $global:SfcTxFailAfterApply) {
      throw "Injected mutation failure after apply: $path"
    }
    return [pscustomobject]@{ status = 'ok' }
  }
  throw "Mock received an unexpected REST call: $Method $Uri"
}

. (Join-Path $repositoryRoot 'scripts\plc\SfcRestWriter.Transaction.ps1')

function Save-CurrentProject {
  $save = Get-SaveRequestDescriptor
  $job = Invoke-JsonTextRequest `
    -Method Post `
    -Uri $save.uri `
    -BodyCanonicalJson $save.bodyCanonicalJson
  return Invoke-RestMethod -Method Get -Uri "$BaseUri/jobs/$($job.id)"
}

$parentNode = [pscustomobject]@{
  name = 'Chain'
  elementType = 'POU'
  declaration = "FUNCTION_BLOCK Chain`n"
  implementation = '<body><SFC>old</SFC></body>'
  children = @('_aN010_active', 'OnChainFinish')
  serverOwnedToken = 'keep-parent-token'
}
$actionNode = [pscustomobject]@{
  name = '_aN010_active'
  elementType = 'Action'
  declaration = ''
  implementation = '// old action'
  children = @()
  serverOwnedToken = 'keep-action-token'
}
$methodNode = [pscustomobject]@{
  name = 'OnChainFinish'
  elementType = 'POUMethod'
  declaration = "METHOD PROTECTED OnChainFinish`n"
  implementation = '// old method'
  children = @()
  serverOwnedToken = 'keep-method-token'
}
$dataParentNode = [pscustomobject]@{
  name = 'Data'
  elementType = 'Folder'
  declaration = ''
  implementation = ''
  children = @()
  serverOwnedToken = 'keep-data-parent-token'
}
$initialNodes = @{
  $parentPath = $parentNode
  $actionPath = $actionNode
  $methodPath = $methodNode
  $dataParentPath = $dataParentNode
}
$global:SfcTxNodes = Copy-NodeMap $initialNodes

$script:CapturePreflight = $true
$script:PreflightObservations = [ordered]@{}
$script:WriteRequests = [Collections.Generic.List[object]]::new()
$script:PreservedDeclarations = [ordered]@{}
$script:AttemptedWriteRequests = [Collections.Generic.List[object]]::new()
Register-PreflightObservation -Path $parentPath -Node $global:SfcTxNodes[$parentPath]
Register-PreflightObservation -Path $actionPath -Node $global:SfcTxNodes[$actionPath]
Register-PreflightObservation -Path $methodPath -Node $global:SfcTxNodes[$methodPath]
Register-PreflightObservation -Path $newActionPath -Node $null
Register-PreflightObservation -Path $dataParentPath -Node $global:SfcTxNodes[$dataParentPath]
Register-PreflightObservation -Path $newDutPath -Node $null

# A repeated GET/registration must never replace the first immutable snapshot.
$immutableParentHash = $script:PreflightObservations[$parentPath].Fingerprint
$duplicateParent = Copy-JsonValue $parentNode
$duplicateParent.serverOwnedToken = 'concurrent-value-that-must-not-replace-snapshot'
Register-PreflightObservation -Path $parentPath -Node $duplicateParent
Assert-True `
  -Condition ($script:PreflightObservations[$parentPath].Fingerprint -eq $immutableParentHash) `
  -Message 'A later GET replaced the immutable preflight snapshot.'

$requestedAction = Copy-JsonValue $actionNode
$requestedAction.implementation = '// target action'
$requestedAction.serverOwnedToken = 'stale-body-value-must-be-ignored'
Add-WriteRequest `
  -Method Put `
  -Uri (ConvertTo-ApiUri $actionPath) `
  -Path $actionPath `
  -Kind 'update-action' `
  -Body $requestedAction `
  -BeforeFingerprint $immutableParentHash `
  -TargetSha256 (Get-Sha256 '// target action')

$requestedMethod = Copy-JsonValue $methodNode
$requestedMethod.implementation = '// target method'
Add-WriteRequest `
  -Method Put `
  -Uri (ConvertTo-ApiUri $methodPath) `
  -Path $methodPath `
  -Kind 'update-method-implementation' `
  -Body $requestedMethod `
  -BeforeFingerprint $script:PreflightObservations[$methodPath].Fingerprint `
  -TargetSha256 (Get-Sha256 ($methodNode.declaration + "`n// target method"))

$newActionBody = [ordered]@{
  name = '_aN015_active'
  elementType = 'Action'
  language = 'ST'
  implementation = '// new action'
}
Add-WriteRequest `
  -Method Post `
  -Uri (ConvertTo-ApiUri $parentPath) `
  -Path $newActionPath `
  -Kind 'create-action' `
  -Body $newActionBody `
  -BeforeFingerprint 'missing' `
  -TargetSha256 (Get-Sha256 '// new action')

$requestedGraph = Copy-JsonValue $parentNode
$requestedGraph.implementation = '<body><SFC>target</SFC></body>'
$requestedGraph.serverOwnedToken = 'stale-graph-value-must-be-ignored'
Add-WriteRequest `
  -Method Put `
  -Uri (ConvertTo-ApiUri $parentPath) `
  -Path $parentPath `
  -Kind 'update-sfc-graph' `
  -Body $requestedGraph `
  -BeforeFingerprint $immutableParentHash `
  -TargetSha256 (Get-Sha256 $requestedGraph.implementation)

$newDutBody = [ordered]@{
  name = 'TestResultStruct'
  elementType = 'DUT'
  language = 'ST'
  declaration = "TYPE TestResultStruct :`nSTRUCT`n  Value : DINT;`nEND_STRUCT`nEND_TYPE"
  textlistsupport = $false
}
Add-WriteRequest `
  -Method Post `
  -Uri (ConvertTo-ApiUri $dataParentPath) `
  -Path $newDutPath `
  -Kind 'create-ai-owned-dut' `
  -Body $newDutBody `
  -BeforeFingerprint 'missing' `
  -TargetSha256 (Get-Sha256 $newDutBody.declaration)

$plan = New-WriterPlan `
  -WriterName 'transaction-selftest.ps1' `
  -ProjectPath 'C:\mock\Station010.project' `
  -ProfileName 'ctrlX PLC 2.6.8' `
  -ChainPath $parentPath `
  -DeclarationExactSha256 (Get-ExactSha256 $parentNode.declaration)
$planSha256 = Get-PlanSha256 $plan
Assert-True -Condition ($plan.schemaVersion -eq 2) -Message 'Transaction plan schema was not upgraded.'
Assert-True -Condition (@($plan.operations).Count -eq 5) -Message 'Transaction plan did not retain every mutation.'
Assert-True -Condition ($null -ne $plan.saveRequest) -Message 'Save POST is missing from the hashed plan.'
Assert-True `
  -Condition ($dataParentPath -in @($plan.objects | ForEach-Object { $_.path })) `
  -Message 'DUT parent container snapshot is missing from the transaction plan.'

foreach ($operation in @($plan.operations)) {
  Assert-True `
    -Condition ((Get-ExactSha256 $operation.request.bodyCanonicalJson) -eq $operation.request.bodySha256) `
    -Message "Request body hash mismatch in plan: $($operation.path)"
}
Assert-True `
  -Condition ((Get-ExactSha256 $plan.saveRequest.bodyCanonicalJson) -eq $plan.saveRequest.bodySha256) `
  -Message 'Save POST body hash mismatch in plan.'

$actionPayload = $plan.operations[0].request.bodyCanonicalJson | ConvertFrom-Json
Assert-True -Condition ($actionPayload.implementation -eq '// target action') -Message 'Action payload omitted target implementation.'
Assert-True -Condition ($actionPayload.serverOwnedToken -eq 'keep-action-token') -Message 'Action payload can overwrite an untracked server field.'
$methodPayload = $plan.operations[1].request.bodyCanonicalJson | ConvertFrom-Json
Assert-True -Condition ($methodPayload.declaration -ceq $methodNode.declaration) -Message 'Method payload did not preserve its declaration exactly.'
Assert-True -Condition ($methodPayload.implementation -eq '// target method') -Message 'Method payload omitted target implementation.'
$postPayload = $plan.operations[2].request.bodyCanonicalJson | ConvertFrom-Json
Assert-True -Condition ($postPayload.name -eq '_aN015_active') -Message 'Action POST payload is incomplete.'
$graphPayload = $plan.operations[3].request.bodyCanonicalJson | ConvertFrom-Json
Assert-True -Condition ($graphPayload.implementation -eq '<body><SFC>target</SFC></body>') -Message 'Graph payload omitted target implementation.'
Assert-True -Condition ($graphPayload.serverOwnedToken -eq 'keep-parent-token') -Message 'Graph payload can overwrite an untracked server field.'
Assert-True -Condition ('_aN015_active' -in @($graphPayload.children)) -Message 'Graph payload did not materialize its planned child POST.'
$dutOperation = $plan.operations[4]
$dutPayload = $dutOperation.request.bodyCanonicalJson | ConvertFrom-Json
Assert-True -Condition ($dutOperation.kind -eq 'create-ai-owned-dut') -Message 'DUT POST is not represented as a typed mutation.'
Assert-True -Condition ($dutPayload.name -eq 'TestResultStruct') -Message 'DUT POST payload is incomplete.'
Assert-True -Condition ($dutOperation.rollback.method -eq 'Delete') -Message 'Created DUT has no rollback DELETE.'

$tamperedPlan = (ConvertTo-CanonicalJson $plan) | ConvertFrom-Json
$tamperedPlan.operations[1].request.bodyCanonicalJson += ' '
Assert-True `
  -Condition ((Get-PlanSha256 $tamperedPlan) -ne $planSha256) `
  -Message 'Plan SHA-256 does not cover the complete mutation payload.'

# Full-object second GET must catch drift in an otherwise untracked field.
$script:CapturePreflight = $false
$global:SfcTxNodes[$parentPath].serverOwnedToken = 'concurrent-drift'
$secondGetRejected = $false
try {
  Assert-PreflightSnapshotCurrent
}
catch {
  $secondGetRejected = $_.Exception.Message.Contains('Preflight object hash changed')
}
Assert-True -Condition $secondGetRejected -Message 'Second GET did not reject full-object drift.'
$global:SfcTxNodes = Copy-NodeMap $initialNodes
Assert-PreflightSnapshotCurrent

# Every actual mutation and Save POST must use the exact canonical JSON that
# was bound into the reviewed plan.
$global:SfcTxCalls.Clear()
$global:SfcTxMutationCounter = 0
Invoke-WriteRequests
$null = Save-CurrentProject
$applyCalls = @($global:SfcTxCalls | Where-Object { $_.phase -eq 'apply' })
Assert-True -Condition ($applyCalls.Count -eq 6) -Message 'Apply did not issue five mutations plus one Save POST.'
for ($index = 0; $index -lt 5; $index++) {
  Assert-True `
    -Condition ($applyCalls[$index].bodyCanonicalJson -ceq $plan.operations[$index].request.bodyCanonicalJson) `
    -Message "Actual request bytes differ from the hashed plan at operation $index."
}
Assert-True `
  -Condition ($applyCalls[5].bodyCanonicalJson -ceq $plan.saveRequest.bodyCanonicalJson) `
  -Message 'Actual Save POST bytes differ from the hashed plan.'

# Simulate a verification failure after every write and the first Save.  The
# rollback must restore graph, created child, Method and Action in reverse
# order, save the restoration, then re-read exact snapshots.
$global:SfcTxRollbackMode = $true
$rollback = Invoke-WriteRollback
$global:SfcTxRollbackMode = $false
Assert-True -Condition $rollback.Succeeded -Message "Full graph rollback failed: $($rollback.Errors -join ' | ')"
foreach ($path in $initialNodes.Keys) {
  Assert-True `
    -Condition ((ConvertTo-CanonicalJson $global:SfcTxNodes[$path]) -ceq (ConvertTo-CanonicalJson $initialNodes[$path])) `
    -Message "Rollback did not restore exact snapshot: $path"
}
Assert-True -Condition (-not $global:SfcTxNodes.ContainsKey($newActionPath)) -Message 'Rollback did not delete the created Action.'
Assert-True -Condition (-not $global:SfcTxNodes.ContainsKey($newDutPath)) -Message 'Rollback did not delete the created DUT.'
$rollbackDeviceCalls = @($global:SfcTxCalls | Where-Object { ($_.phase -eq 'rollback') -and ($_.path -ne 'ProjectJob/Save') })
Assert-True -Condition ($rollbackDeviceCalls[0].path -eq $newDutPath) -Message 'Rollback did not start with the last DUT mutation.'
Assert-True -Condition ($rollbackDeviceCalls[1].path -eq $parentPath) -Message 'Rollback did not reverse the graph after the DUT.'
Assert-True -Condition ($rollbackDeviceCalls[2].path -eq $newActionPath) -Message 'Rollback did not reverse the created Action after the graph.'

# Inject an HTTP failure after a POST was applied.  Because attempted requests
# are registered before sending, rollback must still delete that object and
# restore all earlier PUTs.
$global:SfcTxNodes = Copy-NodeMap $initialNodes
$global:SfcTxCalls.Clear()
$global:SfcTxMutationCounter = 0
$global:SfcTxFailMutationNumber = 3
$global:SfcTxFailAfterApply = $true
$postFailureSeen = $false
try {
  Invoke-WriteRequests
}
catch {
  $postFailureSeen = $_.Exception.Message.Contains('Injected mutation failure after apply')
}
Assert-True -Condition $postFailureSeen -Message 'Mid-transaction POST failure was not injected.'
$global:SfcTxRollbackMode = $true
$midRollback = Invoke-WriteRollback
$global:SfcTxRollbackMode = $false
Assert-True -Condition $midRollback.Succeeded -Message "Mid-transaction rollback failed: $($midRollback.Errors -join ' | ')"
Assert-True -Condition (-not $global:SfcTxNodes.ContainsKey($newActionPath)) -Message 'Failed POST target survived rollback.'
foreach ($path in $initialNodes.Keys) {
  Assert-True `
    -Condition ((ConvertTo-CanonicalJson $global:SfcTxNodes[$path]) -ceq (ConvertTo-CanonicalJson $initialNodes[$path])) `
    -Message "Mid-transaction rollback did not restore exact snapshot: $path"
}

# A rollback failure must never be reported as success or silently saved.
$global:SfcTxNodes = Copy-NodeMap $initialNodes
$global:SfcTxCalls.Clear()
$global:SfcTxMutationCounter = 0
$global:SfcTxFailMutationNumber = 3
$global:SfcTxFailAfterApply = $true
try {
  Invoke-WriteRequests
}
catch {
  # Expected injected write failure.
}
$global:SfcTxRollbackMode = $true
$global:SfcTxFailRollbackPath = $methodPath
$failedRollback = Invoke-WriteRollback
$global:SfcTxFailRollbackPath = ''
$global:SfcTxRollbackMode = $false
Assert-True -Condition (-not $failedRollback.Succeeded) -Message 'Injected rollback failure was reported as success.'
$failureMessage = New-TransactionFailureMessage `
  -OriginalError ([Management.Automation.ErrorRecord]::new(
      [InvalidOperationException]::new('original write failure'),
      'selftest',
      [Management.Automation.ErrorCategory]::InvalidOperation,
      $null
    )) `
  -RollbackResult $failedRollback
Assert-True -Condition $failureMessage.Contains('ROLLBACK FAILED') -Message 'Rollback failure is not prominent in the final error.'
$rollbackSaveCalls = @($global:SfcTxCalls | Where-Object { ($_.phase -eq 'rollback') -and ($_.path -eq 'ProjectJob/Save') })
Assert-True -Condition ($rollbackSaveCalls.Count -eq 0) -Message 'A failed rollback was persisted with Save.'

foreach ($writer in @(
    'scripts\plc\apply_wp100_run_rest.ps1',
    'scripts\plc\apply_wp100_run_sequence_rest.ps1'
  )) {
  $writerText = [IO.File]::ReadAllText((Join-Path $repositoryRoot $writer), [Text.Encoding]::UTF8)
  Assert-True -Condition $writerText.Contains("[ValidateSet('PlanOnly', 'Apply')][string]`$Mode = 'PlanOnly'") -Message "$writer no longer defaults to PlanOnly."
  Assert-True -Condition $writerText.Contains("SfcRestWriter.Transaction.ps1") -Message "$writer does not use the shared transaction guard."
  Assert-True -Condition $writerText.Contains('Invoke-WriteRollback') -Message "$writer does not invoke automatic rollback."
  Assert-True -Condition $writerText.Contains('Assert-PreflightSnapshotCurrent') -Message "$writer lost its second full GET/hash pass."
}

Write-Output 'SFC REST writer transaction coverage OK: canonical payload hash, immutable child/parent preflight, exact graph/method/Action/DUT requests, second GET, reverse rollback, mid-POST failure and rollback-failure reporting'
