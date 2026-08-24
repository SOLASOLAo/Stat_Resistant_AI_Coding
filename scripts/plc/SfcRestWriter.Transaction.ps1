# Shared transaction guard for the Station010 SFC REST writers.
#
# This file is dot-sourced by the concrete writers.  It deliberately contains
# no project paths, BMKs, chain names or process logic.  Every mutation is
# frozen as canonical JSON during PlanOnly, bound into the plan SHA-256, sent
# byte-for-byte during Apply, and paired with a verified rollback operation.

$script:AttemptedWriteRequests = [Collections.Generic.List[object]]::new()

function Get-ExactSha256 {
  param([AllowEmptyString()][string]$Text)

  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString(
      $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
    ).Replace('-', '').ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
}

function ConvertTo-CanonicalValue {
  param([AllowNull()]$Value)

  if ($null -eq $Value) {
    return $null
  }
  if (($Value -is [string]) -or
      ($Value -is [char]) -or
      ($Value -is [bool]) -or
      ($Value -is [byte]) -or
      ($Value -is [sbyte]) -or
      ($Value -is [int16]) -or
      ($Value -is [uint16]) -or
      ($Value -is [int32]) -or
      ($Value -is [uint32]) -or
      ($Value -is [int64]) -or
      ($Value -is [uint64]) -or
      ($Value -is [single]) -or
      ($Value -is [double]) -or
      ($Value -is [decimal])) {
    return $Value
  }
  if ($Value -is [datetime]) {
    return $Value.ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
  }
  if ($Value -is [Collections.IDictionary]) {
    $result = [ordered]@{}
    foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
      $result[$key] = ConvertTo-CanonicalValue $Value[$key]
    }
    return $result
  }
  if (($Value -is [Collections.IEnumerable]) -and (-not ($Value -is [string]))) {
    [object[]]$items = @($Value | ForEach-Object { ConvertTo-CanonicalValue $_ })
    return ,$items
  }

  $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @('NoteProperty', 'Property') })
  if ($properties.Count -gt 0) {
    $result = [ordered]@{}
    foreach ($property in @($properties | Sort-Object Name -CaseSensitive)) {
      $result[$property.Name] = ConvertTo-CanonicalValue $property.Value
    }
    return $result
  }
  return [string]$Value
}

function ConvertTo-CanonicalJson {
  param([AllowNull()]$Value)

  # -InputObject is intentional: piping a one-item or empty top-level array to
  # ConvertTo-Json collapses it to a scalar or no output in Windows PowerShell
  # 5.1.  Request bodies are objects today, but the canonicalizer itself must
  # remain structurally correct for every value included in a future plan.
  $canonicalValue = ConvertTo-CanonicalValue $Value
  return ConvertTo-Json -InputObject $canonicalValue -Depth 100 -Compress
}

function Copy-CanonicalJsonValue {
  param([Parameter(Mandatory)][string]$Json)

  return $Json | ConvertFrom-Json
}

function Set-JsonProperty {
  param(
    [Parameter(Mandatory)]$Object,
    [Parameter(Mandatory)][string]$Name,
    [AllowNull()]$Value
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
  else {
    $property.Value = $Value
  }
}

function Get-NodeFingerprint {
  param([AllowNull()]$Node)

  if ($null -eq $Node) {
    return 'missing'
  }
  return Get-ExactSha256 (ConvertTo-CanonicalJson $Node)
}

function Register-PreflightObservation {
  param(
    [Parameter(Mandatory)][string]$Path,
    [AllowNull()]$Node
  )

  if ((-not $script:CapturePreflight) -or $script:PreflightObservations.Contains($Path)) {
    return
  }

  $snapshotJson = if ($null -eq $Node) { $null } else { ConvertTo-CanonicalJson $Node }
  $script:PreflightObservations[$Path] = [pscustomobject]@{
    Path = $Path
    Exists = ($null -ne $Node)
    Fingerprint = if ($null -eq $Node) { 'missing' } else { Get-ExactSha256 $snapshotJson }
    SnapshotCanonicalJson = $snapshotJson
    Declaration = if ($null -eq $Node) { $null } else { [string]$Node.declaration }
    DeclarationExactSha256 = if ($null -eq $Node) { $null } else { Get-ExactSha256 ([string]$Node.declaration) }
    ImplementationSha256 = if ($null -eq $Node) { $null } else { Get-Sha256 ([string]$Node.implementation) }
  }
}

function Get-PreflightObservation {
  param([Parameter(Mandatory)][string]$Path)

  if (-not $script:PreflightObservations.Contains($Path)) {
    throw "No immutable preflight snapshot exists for: $Path"
  }
  return $script:PreflightObservations[$Path]
}

function Get-PreflightSnapshotNode {
  param([Parameter(Mandatory)][string]$Path)

  $observation = Get-PreflightObservation $Path
  if (-not $observation.Exists) {
    return $null
  }
  return Copy-CanonicalJsonValue $observation.SnapshotCanonicalJson
}

function Get-ParentPath {
  param([Parameter(Mandatory)][string]$Path)

  $lastSeparator = $Path.LastIndexOf('/')
  if ($lastSeparator -lt 1) {
    return ''
  }
  return $Path.Substring(0, $lastSeparator)
}

function Get-LeafName {
  param([Parameter(Mandatory)][string]$Path)

  return $Path.Substring($Path.LastIndexOf('/') + 1)
}

function New-FrozenPutBody {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Kind,
    [Parameter(Mandatory)]$RequestedBody
  )

  $snapshot = Get-PreflightSnapshotNode $Path
  if ($null -eq $snapshot) {
    throw "PUT target was missing during preflight: $Path"
  }

  # Every current writer mutation changes implementation only.  Start from the
  # immutable full snapshot so a later GET can never leak an unreviewed field
  # into the request body.
  Set-JsonProperty -Object $snapshot -Name implementation -Value ([string]$RequestedBody.implementation)

  $expectedBeforeWrite = Get-PreflightSnapshotNode $Path
  if ($Kind -eq 'update-sfc-graph') {
    # Child POSTs precede the graph PUT.  Their exact leaf names and order are
    # already part of the plan, so materialize the parent's expected child list
    # now instead of rebuilding the PUT body from a live, unhashed GET.
    $createdChildren = @($script:WriteRequests |
        Where-Object {
          ($_.Method -eq 'Post') -and
          ((Get-ParentPath $_.Path) -eq $Path)
        } |
        ForEach-Object { Get-LeafName $_.Path })
    if ($createdChildren.Count -gt 0) {
      $finalChildren = [Collections.Generic.List[string]]::new()
      foreach ($child in @($expectedBeforeWrite.children)) {
        if (-not $finalChildren.Contains([string]$child)) {
          $finalChildren.Add([string]$child)
        }
      }
      foreach ($child in $createdChildren) {
        if (-not $finalChildren.Contains([string]$child)) {
          $finalChildren.Add([string]$child)
        }
      }
      Set-JsonProperty -Object $expectedBeforeWrite -Name children -Value $finalChildren.ToArray()
      Set-JsonProperty -Object $snapshot -Name children -Value $finalChildren.ToArray()
    }
  }

  return [pscustomobject]@{
    Body = $snapshot
    ExpectedBeforeWriteBody = $expectedBeforeWrite
    ExpectedBeforeWriteFingerprint = Get-NodeFingerprint $expectedBeforeWrite
  }
}

function Add-WriteRequest {
  param(
    [Parameter(Mandatory)][ValidateSet('Post', 'Put')][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Kind,
    [Parameter(Mandatory)]$Body,
    [AllowEmptyString()][string]$BeforeFingerprint = '',
    [Parameter(Mandatory)][string]$TargetSha256
  )

  $observation = Get-PreflightObservation $Path
  if (($Method -eq 'Post') -and $observation.Exists) {
    throw "POST target already existed during preflight: $Path"
  }
  if ($Method -eq 'Post') {
    $parentPath = Get-ParentPath $Path
    if ([string]::IsNullOrWhiteSpace($parentPath) -or
        (-not $script:PreflightObservations.Contains($parentPath)) -or
        (-not $script:PreflightObservations[$parentPath].Exists)) {
      throw "POST parent does not have an existing immutable preflight snapshot: $parentPath"
    }
  }
  if (($Method -eq 'Put') -and (-not $observation.Exists)) {
    throw "PUT target was missing during preflight: $Path"
  }

  $frozen = if ($Method -eq 'Put') {
    New-FrozenPutBody -Path $Path -Kind $Kind -RequestedBody $Body
  }
  else {
    [pscustomobject]@{
      Body = $Body
      ExpectedBeforeWriteBody = $null
      ExpectedBeforeWriteFingerprint = 'missing'
    }
  }
  $bodyJson = ConvertTo-CanonicalJson $frozen.Body
  $rollbackBodyJson = if ($observation.Exists) {
    if (($Method -eq 'Put') -and ($Kind -eq 'update-sfc-graph')) {
      # First detach the target graph while retaining children created earlier
      # in the same transaction.  After those POSTs are reversed, rollback
      # performs a final exact-snapshot reconciliation.
      ConvertTo-CanonicalJson $frozen.ExpectedBeforeWriteBody
    }
    else {
      $observation.SnapshotCanonicalJson
    }
  }
  else {
    $null
  }

  $script:WriteRequests.Add([pscustomobject]@{
      Method = $Method
      Uri = $Uri
      Path = $Path
      Kind = $Kind
      BodyCanonicalJson = $bodyJson
      BodySha256 = Get-ExactSha256 $bodyJson
      BeforeFingerprint = $BeforeFingerprint
      ExpectedBeforeWriteFingerprint = $frozen.ExpectedBeforeWriteFingerprint
      TargetSha256 = $TargetSha256
      RollbackMethod = if ($observation.Exists) { 'Put' } else { 'Delete' }
      RollbackUri = ConvertTo-ApiUri $Path
      RollbackBodyCanonicalJson = $rollbackBodyJson
      RollbackBodySha256 = if ($observation.Exists) { Get-ExactSha256 $rollbackBodyJson } else { $null }
      FinalRollbackBodyCanonicalJson = if ($observation.Exists) { $observation.SnapshotCanonicalJson } else { $null }
      FinalRollbackBodySha256 = if ($observation.Exists) { Get-ExactSha256 $observation.SnapshotCanonicalJson } else { $null }
    })
}

function Invoke-JsonTextRequest {
  param(
    [Parameter(Mandatory)][ValidateSet('Post', 'Put')][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)][string]$BodyCanonicalJson
  )

  return Invoke-RestMethod `
    -Method $Method `
    -Uri $Uri `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([Text.Encoding]::UTF8.GetBytes($BodyCanonicalJson))
}

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory)][ValidateSet('Post', 'Put')][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)]$Body
  )

  return Invoke-JsonTextRequest -Method $Method -Uri $Uri -BodyCanonicalJson (ConvertTo-CanonicalJson $Body)
}

function Get-SaveRequestDescriptor {
  $body = [ordered]@{
    jobType = 'ProjectJob'
    jobParameters = [ordered]@{ action = 'Save' }
  }
  $bodyJson = ConvertTo-CanonicalJson $body
  return [pscustomobject]@{
    method = 'Post'
    uri = "$BaseUri/jobs"
    contentType = 'application/json; charset=utf-8'
    bodyCanonicalJson = $bodyJson
    bodySha256 = Get-ExactSha256 $bodyJson
  }
}

function New-WriterPlan {
  param(
    [Parameter(Mandatory)][string]$WriterName,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$ProfileName,
    [Parameter(Mandatory)][string]$ChainPath,
    [Parameter(Mandatory)][string]$DeclarationExactSha256,
    [AllowNull()][string[]]$RetainedObsoleteChildren
  )

  $objects = @($script:PreflightObservations.Values |
      Sort-Object Path |
      ForEach-Object {
        [ordered]@{
          path = $_.Path
          exists = $_.Exists
          snapshotSha256 = $_.Fingerprint
          declarationExactSha256 = $_.DeclarationExactSha256
        }
      })
  $operations = @($script:WriteRequests | ForEach-Object {
      [ordered]@{
        method = $_.Method
        kind = $_.Kind
        path = $_.Path
        request = [ordered]@{
          uri = $_.Uri
          contentType = 'application/json; charset=utf-8'
          bodyCanonicalJson = $_.BodyCanonicalJson
          bodySha256 = $_.BodySha256
        }
        expectedBeforeWriteFingerprint = $_.ExpectedBeforeWriteFingerprint
        targetSha256 = $_.TargetSha256
        rollback = [ordered]@{
          method = $_.RollbackMethod
          uri = $_.RollbackUri
          bodyCanonicalJson = $_.RollbackBodyCanonicalJson
          bodySha256 = $_.RollbackBodySha256
          finalSnapshotBodyCanonicalJson = $_.FinalRollbackBodyCanonicalJson
          finalSnapshotBodySha256 = $_.FinalRollbackBodySha256
        }
      }
    })
  $saveRequest = if ($operations.Count -gt 0) { Get-SaveRequestDescriptor } else { $null }
  return [ordered]@{
    schemaVersion = 2
    writer = $WriterName
    expectedProject = $ProjectPath
    profileName = $ProfileName
    chainPath = $ChainPath
    declarationPolicy = 'read-only-preserve-exactly'
    declarationExactSha256 = $DeclarationExactSha256
    objects = $objects
    operations = $operations
    saveRequest = $saveRequest
    savePlanned = ($operations.Count -gt 0)
    obsoleteDeletion = 'disabled'
    retainedObsoleteChildren = @($RetainedObsoleteChildren | Sort-Object)
  }
}

function Get-PlanSha256 {
  param([Parameter(Mandatory)]$Plan)

  return Get-ExactSha256 (ConvertTo-CanonicalJson $Plan)
}

function Get-NodeWithoutCapture {
  param([Parameter(Mandatory)][string]$Path)

  return Invoke-RestMethod -Method Get -Uri (ConvertTo-ApiUri $Path)
}

function Get-NodeOrNullWithoutCapture {
  param([Parameter(Mandatory)][string]$Path)

  try {
    return Get-NodeWithoutCapture $Path
  }
  catch {
    if (Test-IsNotFoundError $_) {
      return $null
    }
    throw
  }
}

function Assert-ObservationCurrent {
  param(
    [Parameter(Mandatory)]$Observation,
    [AllowNull()]$Current,
    [Parameter(Mandatory)][string]$Context
  )

  $exists = ($null -ne $Current)
  if ($exists -ne $Observation.Exists) {
    throw "$Context object existence changed: $($Observation.Path)"
  }
  $currentFingerprint = Get-NodeFingerprint $Current
  if ($currentFingerprint -ne $Observation.Fingerprint) {
    throw "$Context object hash changed: $($Observation.Path)"
  }
  if ($Observation.Exists -and
      ([string]$Current.declaration -cne [string]$Observation.Declaration)) {
    throw "$Context declaration text changed: $($Observation.Path)"
  }
}

function Assert-PreflightSnapshotCurrent {
  foreach ($observation in @($script:PreflightObservations.Values | Sort-Object Path)) {
    Assert-ObservationCurrent `
      -Observation $observation `
      -Current (Get-NodeOrNullWithoutCapture $observation.Path) `
      -Context 'Preflight'
  }
}

function Assert-RequiredEnumItems {
  param(
    [Parameter(Mandatory)][string[]]$CandidatePaths,
    [Parameter(Mandatory)][object[]]$ExpectedItems,
    [Parameter(Mandatory)][string]$EnumName
  )

  $enumNode = $null
  $resolvedPath = ''
  foreach ($candidatePath in $CandidatePaths) {
    try {
      $enumNode = Get-Node $candidatePath
      $resolvedPath = $candidatePath
      break
    }
    catch {
      if (-not (Test-IsNotFoundError $_)) {
        throw "Cannot read CpStudio enum '$EnumName' from PLE REST at '$candidatePath': $($_.Exception.Message)"
      }
    }
  }
  if ($null -eq $enumNode) {
    throw "CpStudio prerequisite is missing: PLE REST cannot find '$EnumName' at any expected generated path ($($CandidatePaths -join ', ')). Save and export the enum from CpStudio before running PlanOnly or Apply."
  }

  # PLE versions differ in how much enum metadata they expose.  The complete
  # canonical node covers declaration, implementation and structured members.
  # Symbols are always mandatory; explicit numeric assignments are validated
  # whenever this REST surface exposes them.
  $surface = ConvertTo-CanonicalJson $enumNode
  $declaration = [string]$enumNode.declaration
  $firstExpectedName = [string]$ExpectedItems[0].Name
  $symbolSurface = if ([regex]::IsMatch(
      $declaration,
      '(?<![A-Za-z0-9_])' + [regex]::Escape($firstExpectedName) + '(?![A-Za-z0-9_])'
    )) {
    $declaration
  }
  else {
    $surface
  }
  $missing = [Collections.Generic.List[string]]::new()
  $indexErrors = [Collections.Generic.List[string]]::new()
  $previousPosition = -1
  foreach ($item in $ExpectedItems) {
    $name = [string]$item.Name
    $expectedIndex = [int]$item.Index
    $symbolPattern = '(?<![A-Za-z0-9_])' + [regex]::Escape($name) + '(?![A-Za-z0-9_])'
    $symbolMatch = [regex]::Match($symbolSurface, $symbolPattern)
    if (-not $symbolMatch.Success) {
      $missing.Add("$name=$expectedIndex")
      continue
    }
    if ($symbolMatch.Index -le $previousPosition) {
      $indexErrors.Add("$name is out of append-only order")
    }
    $previousPosition = $symbolMatch.Index

    $assignmentPattern = '(?m)(?<![A-Za-z0-9_])' + [regex]::Escape($name) +
                         '(?![A-Za-z0-9_])\s*(?::=|=)\s*(-?\d+)'
    $assignment = [regex]::Match($declaration, $assignmentPattern)
    if ($assignment.Success -and ([int]$assignment.Groups[1].Value -ne $expectedIndex)) {
      $indexErrors.Add("$name expected index $expectedIndex but REST exposes $($assignment.Groups[1].Value)")
    }
  }
  if ($missing.Count -gt 0) {
    throw "CpStudio prerequisite is incomplete: '$EnumName' is missing required exported item(s): $($missing -join ', '). Append indices 4..16 in CpStudio, Save, then Export before PlanOnly or Apply."
  }
  if ($indexErrors.Count -gt 0) {
    throw "CpStudio prerequisite is invalid: '$EnumName' item order/index mismatch: $($indexErrors -join '; '). Existing indices are append-only and must not be renumbered."
  }

  return [pscustomobject]@{
    Path = $resolvedPath
    ItemCount = $ExpectedItems.Count
    IndexValidation = if ([regex]::IsMatch($declaration, '(?::=|=)\s*-?\d+')) {
      'explicit assignments checked where exposed'
    }
    else {
      'REST did not expose numeric assignments; symbol presence/order checked'
    }
  }
}

function Assert-WriteRequestPrecondition {
  param([Parameter(Mandatory)]$Request)

  $current = Get-NodeOrNullWithoutCapture $Request.Path
  $currentFingerprint = Get-NodeFingerprint $current
  if ($currentFingerprint -ne $Request.ExpectedBeforeWriteFingerprint) {
    throw "Write precondition changed immediately before $($Request.Method): $($Request.Path)"
  }
}

function Invoke-WriteRequests {
  $script:AttemptedWriteRequests.Clear()
  foreach ($request in $script:WriteRequests) {
    Assert-WriteRequestPrecondition $request

    # Register before sending: an HTTP error can still arrive after the server
    # accepted a mutation, so rollback must treat every attempted request as
    # potentially applied.
    $script:AttemptedWriteRequests.Add($request)
    $null = Invoke-JsonTextRequest `
      -Method $request.Method `
      -Uri $request.Uri `
      -BodyCanonicalJson $request.BodyCanonicalJson
  }
}

function Assert-RollbackSnapshotsRestored {
  param([Parameter(Mandatory)][object[]]$Requests)

  $paths = [Collections.Generic.List[string]]::new()
  foreach ($request in $Requests) {
    if (-not $paths.Contains([string]$request.Path)) {
      $paths.Add([string]$request.Path)
    }
    if ($request.Method -eq 'Post') {
      $parentPath = Get-ParentPath $request.Path
      if ($script:PreflightObservations.Contains($parentPath) -and
          (-not $paths.Contains($parentPath))) {
        $paths.Add($parentPath)
      }
    }
  }
  $paths = @($paths | Sort-Object -Unique)
  foreach ($path in $paths) {
    $observation = Get-PreflightObservation $path
    Assert-ObservationCurrent `
      -Observation $observation `
      -Current (Get-NodeOrNullWithoutCapture $path) `
      -Context 'Rollback'
  }
}

function Invoke-WriteRollback {
  $attempted = @($script:AttemptedWriteRequests)
  if ($attempted.Count -eq 0) {
    return [pscustomobject]@{
      Succeeded = $true
      AttemptedCount = 0
      RestoredCount = 0
      SaveResult = 'No writer mutation was attempted; rollback was not required.'
      Errors = @()
    }
  }

  $errors = [Collections.Generic.List[string]]::new()
  $restored = 0
  for ($index = $attempted.Count - 1; $index -ge 0; $index--) {
    $request = $attempted[$index]
    try {
      if ($request.RollbackMethod -eq 'Put') {
        $null = Invoke-JsonTextRequest `
          -Method Put `
          -Uri $request.RollbackUri `
          -BodyCanonicalJson $request.RollbackBodyCanonicalJson
      }
      else {
        try {
          $null = Invoke-RestMethod -Method Delete -Uri $request.RollbackUri
        }
        catch {
          if (-not (Test-IsNotFoundError $_)) {
            throw
          }
        }
      }
      $restored++
    }
    catch {
      $errors.Add("$($request.RollbackMethod) $($request.Path): $($_.Exception.Message)")
    }
  }

  # Reconcile every originally existing target to its exact immutable
  # snapshot after created children have been deleted.  This second pass is
  # necessary for parent SFC objects whose staged rollback body intentionally
  # retained transaction-created children until their reverse-order DELETE.
  if ($errors.Count -eq 0) {
    $existingTargets = @($attempted |
        Where-Object { $_.RollbackMethod -eq 'Put' } |
        Sort-Object Path -Unique)
    foreach ($request in $existingTargets) {
      try {
        $null = Invoke-JsonTextRequest `
          -Method Put `
          -Uri $request.RollbackUri `
          -BodyCanonicalJson $request.FinalRollbackBodyCanonicalJson
      }
      catch {
        $errors.Add("final snapshot Put $($request.Path): $($_.Exception.Message)")
      }
    }
  }

  if ($errors.Count -eq 0) {
    try {
      Assert-RollbackSnapshotsRestored -Requests $attempted
    }
    catch {
      $errors.Add("readback before rollback save: $($_.Exception.Message)")
    }
  }

  $saveResult = 'Rollback save was skipped because restoration/readback failed.'
  if ($errors.Count -eq 0) {
    try {
      $saveResult = (Save-CurrentProject).jobResultInfo
      Assert-RollbackSnapshotsRestored -Requests $attempted
    }
    catch {
      $errors.Add("rollback save/readback: $($_.Exception.Message)")
    }
  }

  return [pscustomobject]@{
    Succeeded = ($errors.Count -eq 0)
    AttemptedCount = $attempted.Count
    RestoredCount = $restored
    SaveResult = $saveResult
    Errors = @($errors)
  }
}

function New-TransactionFailureMessage {
  param(
    [Parameter(Mandatory)]$OriginalError,
    [Parameter(Mandatory)]$RollbackResult
  )

  $originalMessage = $OriginalError.Exception.Message
  if ($RollbackResult.Succeeded) {
    return "REST writer transaction failed: $originalMessage Rollback succeeded and every attempted object was restored and verified."
  }
  return "REST writer transaction failed: $originalMessage ROLLBACK FAILED: $($RollbackResult.Errors -join ' | ')"
}
