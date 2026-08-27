[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Join-Path $PSScriptRoot '..\..'
}
$repositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)

$requiredFiles = @(
    'TEAM_SETUP.md',
    'config/project.yaml',
    'config/quality-gates.yaml',
    'config/codex-mcp.toml.example',
    'specs/station.yaml',
    'specs/io.yaml',
    'specs/events.yaml',
    'specs/hmi/auto_info_line.yaml',
    'specs/units/Wp100.yaml',
    'ai/ownership.yaml',
    'ai/hooks.yaml',
    'ai/graphical.yaml',
    'scripts/cpstudio/post_export_signal.bat',
    'scripts/cpstudio/write_export_request.ps1',
    'scripts/cpstudio/Invoke-PostExportAudit.ps1',
    'scripts/cpstudio/Invoke-PostExportEngineering.ps1',
    'scripts/cpstudio/New-PostExportRunnerEvidence.ps1',
    'scripts/cpstudio/New-EngineeringSemanticBaselineCandidate.ps1',
    'scripts/cpstudio/Invoke-OfflinePostExportCheck.ps1',
    'scripts/cpstudio/offline_mcp_build.cjs',
    'scripts/cpstudio/Run-OfflinePostExportCheck.cmd',
    'scripts/git/Get-ReadOnlyGitAudit.ps1',
    'scripts/plc/export_plc_snapshot.py',
    'scripts/plc/verify_plc_snapshot.ps1',
    'scripts/plc/SfcRestWriter.Transaction.ps1',
    'scripts/ioe/ioe_ipc.ps1',
    'scripts/setup/Test-TeamWorkstation.ps1',
    'tests/cpstudio/Test-PostExportQueue.ps1',
    'tests/cpstudio/Test-PostExportEngineering.ps1',
    'tests/cpstudio/Test-PostExportRunnerEvidence.ps1',
    'tests/cpstudio/Test-EngineeringSemanticBaselineCandidate.ps1',
    'docs/reviews/README.md',
    'tests/cpstudio/Test-OfflinePostExportCheck.ps1',
    'tests/static/Test-SfcRestWriterPlanOnly.ps1',
    'tests/static/Test-SfcRestWriterTransaction.ps1',
    'tests/static/Test-RunOperatorGuidance.ps1'
)

$failures = New-Object System.Collections.Generic.List[string]

function Get-ConfiguredValue {
    param(
        [string]$Path,
        [string]$Key
    )

    $pattern = '^\s*{0}:\s*(?<value>.+?)\s*$' -f [regex]::Escape($Key)
    $match = [System.IO.File]::ReadAllLines($Path) |
        Select-String -Pattern $pattern |
        Select-Object -First 1
    if (-not $match) {
        return $null
    }
    return $match.Matches[0].Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Resolve-ProjectPath {
    param([string]$ConfiguredPath)

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return [System.IO.Path]::GetFullPath($ConfiguredPath)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ConfiguredPath))
}

function ConvertTo-RepositoryRelativePath {
    param([string]$FullPath)

    return $FullPath.Substring($repositoryRoot.Length).TrimStart('\', '/').Replace('\', '/')
}

function Get-OwnershipRecords {
    param([string]$Path)

    $records = New-Object System.Collections.Generic.List[hashtable]
    $current = $null
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*-\s+path:\s*(?<value>.+?)\s*$') {
            if ($null -ne $current) {
                $records.Add($current)
            }
            $current = @{ path = $Matches['value'].Trim().Trim('"').Trim("'") }
            continue
        }
        if (($null -ne $current) -and
            ($line -match '^\s+(?<key>source|specification|apply_script|write_mode):\s*(?<value>.+?)\s*$')) {
            $current[$Matches['key']] = $Matches['value'].Trim().Trim('"').Trim("'")
        }
    }
    if ($null -ne $current) {
        $records.Add($current)
    }
    return $records
}

function Get-ChainSteps {
    param([string]$Path)

    $steps = [ordered]@{}
    $currentId = $null
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*-\s*\{\s*id:\s*(?<id>[^,}\s]+),\s*comment:\s*(?<comment>[^,}]+)') {
            $steps[$Matches['id'].Trim()] = $Matches['comment'].Trim()
            $currentId = $null
            continue
        }
        if ($line -match '^\s*-\s+id:\s*(?<id>\S+)\s*$') {
            $currentId = $Matches['id'].Trim()
            continue
        }
        if (($null -ne $currentId) -and ($line -match '^\s+comment:\s*(?<comment>.+?)\s*$')) {
            $steps[$currentId] = $Matches['comment'].Trim().Trim('"').Trim("'")
            $currentId = $null
        }
    }
    return $steps
}

function Get-GraphicalObjects {
    param([string]$Path)

    $objects = @{}
    $currentPath = $null
    $inStepComments = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*-\s+path:\s*(?<value>.+?)\s*$') {
            $currentPath = $Matches['value'].Trim().Trim('"').Trim("'")
            $objects[$currentPath] = [ordered]@{}
            $inStepComments = $false
            continue
        }
        if (($null -ne $currentPath) -and ($line -match '^\s{4}step_comments:\s*$')) {
            $inStepComments = $true
            continue
        }
        if ($inStepComments -and ($line -match '^\s{6}(?<id>[A-Za-z_][A-Za-z0-9_]*):\s*(?<comment>.+?)\s*$')) {
            $objects[$currentPath][$Matches['id']] = $Matches['comment'].Trim().Trim('"').Trim("'")
            continue
        }
        if ($inStepComments -and ($line -match '^\s{0,4}\S')) {
            $inStepComments = $false
        }
    }
    return $objects
}

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $repositoryRoot ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not [System.IO.File]::Exists($absolutePath)) {
        $failures.Add("Missing required file: $relativePath")
    }
}

$projectConfigPath = Join-Path $repositoryRoot 'config\project.yaml'
if ([System.IO.File]::Exists($projectConfigPath)) {
    foreach ($configKey in @('station_root', 'standard_library_root')) {
        $configuredPath = Get-ConfiguredValue $projectConfigPath $configKey
        if ([string]::IsNullOrWhiteSpace($configuredPath)) {
            $failures.Add("Missing path '$configKey' in config/project.yaml")
            continue
        }
        $absolutePath = Resolve-ProjectPath $configuredPath
        if (-not [System.IO.Directory]::Exists($absolutePath)) {
            $failures.Add("Configured directory does not exist: $configKey -> $configuredPath")
        }
    }
}

$ownershipPath = Join-Path $repositoryRoot 'ai\ownership.yaml'
$ownershipRecords = if ([System.IO.File]::Exists($ownershipPath)) {
    @(Get-OwnershipRecords $ownershipPath)
}
else {
    @()
}
$ownedSources = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($record in $ownershipRecords) {
    foreach ($key in @('source', 'specification', 'apply_script')) {
        if (-not $record.ContainsKey($key)) {
            continue
        }
        $relativePath = $record[$key].Replace('\', '/')
        $absolutePath = Join-Path $repositoryRoot ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not [System.IO.File]::Exists($absolutePath)) {
            $failures.Add("Ownership reference is missing: $($record.path) -> ${key}=$relativePath")
        }
        if ($key -eq 'source') {
            [void]$ownedSources.Add($relativePath)
        }
    }
}

$stSourceRoot = Join-Path $repositoryRoot 'src\plc'
if ([System.IO.Directory]::Exists($stSourceRoot)) {
    foreach ($file in Get-ChildItem -LiteralPath $stSourceRoot -Recurse -File -Filter '*.st') {
        $relativePath = ConvertTo-RepositoryRelativePath $file.FullName
        if (-not $ownedSources.Contains($relativePath)) {
            $failures.Add("PLC source is not declared in ai/ownership.yaml: $relativePath")
        }
    }
}

$graphicalPath = Join-Path $repositoryRoot 'ai\graphical.yaml'
$graphicalObjects = if ([System.IO.File]::Exists($graphicalPath)) {
    Get-GraphicalObjects $graphicalPath
}
else {
    @{}
}
foreach ($record in $ownershipRecords | Where-Object {
    $_.ContainsKey('specification') -and
    ($_.write_mode -in @('rest_composite', 'graphical_attributes'))
}) {
    $specPath = Join-Path $repositoryRoot ($record.specification -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not [System.IO.File]::Exists($specPath)) {
        continue
    }
    $specSteps = Get-ChainSteps $specPath
    if ($specSteps.Count -eq 0) {
        $failures.Add("Chain specification contains no identifiable steps: $($record.specification)")
        continue
    }
    if (-not $graphicalObjects.ContainsKey($record.path)) {
        $failures.Add("Chain has no graphical manifest entry: $($record.path)")
        continue
    }
    $graphicalSteps = $graphicalObjects[$record.path]
    foreach ($stepId in $specSteps.Keys) {
        if (-not $graphicalSteps.Contains($stepId)) {
            $failures.Add("Graphical manifest is missing step $stepId for $($record.path)")
        }
        elseif ($graphicalSteps[$stepId] -ne $specSteps[$stepId]) {
            $failures.Add("Step comment mismatch for $($record.path)/${stepId}: spec='$($specSteps[$stepId])', graphical='$($graphicalSteps[$stepId])'")
        }
    }
    foreach ($stepId in $graphicalSteps.Keys) {
        if (-not $specSteps.Contains($stepId)) {
            $failures.Add("Graphical manifest has an undeclared step $stepId for $($record.path)")
        }
    }

    if (($record.write_mode -eq 'rest_composite') -and $record.ContainsKey('source')) {
        $chainSourceRoot = Split-Path -Parent (Join-Path $repositoryRoot ($record.source -replace '/', [System.IO.Path]::DirectorySeparatorChar))
        foreach ($stepId in $specSteps.Keys) {
            $actionPath = Join-Path $chainSourceRoot ("actions\{0}.st" -f $stepId)
            if (-not [System.IO.File]::Exists($actionPath)) {
                $failures.Add("REST-composite chain step has no Action source: $($record.path)/$stepId")
                continue
            }
            $relativeActionPath = ConvertTo-RepositoryRelativePath $actionPath
            if (-not $ownedSources.Contains($relativeActionPath)) {
                $failures.Add("REST-composite Action source is not owned: $relativeActionPath")
            }
        }
    }
}

$qualityGatesPath = Join-Path $repositoryRoot 'config\quality-gates.yaml'
$baselineWarningCount = if ([System.IO.File]::Exists($qualityGatesPath)) {
    Get-ConfiguredValue $qualityGatesPath 'baseline_warning_count'
}
else {
    $null
}
if (($null -ne $baselineWarningCount) -and ($baselineWarningCount -notmatch '^\d+$')) {
    $failures.Add("baseline_warning_count must be a non-negative integer: $baselineWarningCount")
}
elseif ($null -ne $baselineWarningCount) {
    foreach ($specFile in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'specs\chains') -File -Filter '*.yaml') {
        $specText = [System.IO.File]::ReadAllText($specFile.FullName)
        if ($specText -notmatch '(?m)^\s+status:\s*implemented_offline_verified\s*$') {
            continue
        }
        $verificationMatch = [regex]::Match(
            $specText,
            '(?m)^\s+offline_(?:build|compile):\s*0 errors\s*/\s*(?<warnings>\d+) warnings\s*$'
        )
        if (-not $verificationMatch.Success) {
            $failures.Add("Verified chain specification has no parseable offline warning baseline: $(ConvertTo-RepositoryRelativePath $specFile.FullName)")
        }
        elseif ($verificationMatch.Groups['warnings'].Value -ne $baselineWarningCount) {
            $failures.Add("Chain warning baseline differs from config/quality-gates.yaml: $(ConvertTo-RepositoryRelativePath $specFile.FullName) has $($verificationMatch.Groups['warnings'].Value), expected $baselineWarningCount")
        }
    }
}

$commonSourceRoot = Join-Path $repositoryRoot 'src\plc\common'
foreach ($file in Get-ChildItem -LiteralPath $commonSourceRoot -File -Filter '*.st') {
    $relativePath = ConvertTo-RepositoryRelativePath $file.FullName
    $text = [System.IO.File]::ReadAllText($file.FullName)
    if (-not $text.Contains('(* ===== DECLARATION ===== *)')) {
        $failures.Add("Missing declaration marker: $relativePath")
    }
    if (-not $text.Contains('(* ===== IMPLEMENTATION ===== *)')) {
        $failures.Add("Missing implementation marker: $relativePath")
    }
}

$stFiles = Get-ChildItem -LiteralPath $stSourceRoot -Recurse -File -Filter '*.st'
foreach ($file in $stFiles) {
    $relativePath = $file.FullName.Substring($repositoryRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = [System.IO.File]::ReadAllLines($file.FullName)
    $text = [System.IO.File]::ReadAllText($file.FullName)

    # OpCon SetEvent AdditionalInfo is STRING(63). A longer literal is
    # truncated by the compiler and raises C0198.
    $setEventPattern = "SetEvent\s*\(\s*[^,]+,\s*[^,]+,\s*'((?:''|[^'])*)'"
    foreach ($match in [regex]::Matches($text, $setEventPattern, [Text.RegularExpressions.RegexOptions]::Singleline)) {
        $additionalInfo = $match.Groups[1].Value.Replace("''", "'")
        if ($additionalInfo.Length -gt 63) {
            $failures.Add("OpCon SetEvent AdditionalInfo exceeds STRING(63): ${relativePath} ($($additionalInfo.Length) characters)")
        }
    }

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        $lineNumber = $lineIndex + 1
        $trimmedLine = $line.TrimStart()

        if ($trimmedLine.StartsWith('//') -or
            $trimmedLine.StartsWith('(*') -or
            $trimmedLine.StartsWith('*')) {
            continue
        }

        if ($line -match '^\s*(AND|OR)\b') {
            $failures.Add("PLC ST logical operator must end the previous line: ${relativePath}:${lineNumber}")
        }

        if (($line -match '^\s*(IF|ELSIF)\s+') -and
            ($line -notmatch '^\s*(IF|ELSIF)\s+\(\s')) {
            $failures.Add("PLC ST condition must start with a spaced parenthesis: ${relativePath}:${lineNumber}")
        }

        if ($line -match '\b(AND|OR)\s*$') {
            $conditionFragment = $line.Trim()
            $conditionFragment = $conditionFragment -replace '^(IF|ELSIF)\s+', ''
            if ($conditionFragment.Contains(':=')) {
                $conditionFragment = $conditionFragment.Substring($conditionFragment.LastIndexOf(':=') + 2).Trim()
            }
            if ($conditionFragment -notmatch '^\(\s+.+\s+\)\s+(AND|OR)$') {
                $failures.Add("PLC ST logical operand must be parenthesized: ${relativePath}:${lineNumber}")
            }

            $nextCodeLine = $lineIndex + 1
            while (($nextCodeLine -lt $lines.Count) -and
                   [string]::IsNullOrWhiteSpace($lines[$nextCodeLine])) {
                $nextCodeLine++
            }
            if (($nextCodeLine -ge $lines.Count) -or
                ($lines[$nextCodeLine].TrimStart() -notmatch '^\(\s')) {
                $failures.Add("PLC ST continuation condition must be parenthesized: ${relativePath}:$($nextCodeLine + 1)")
            }
        }
    }
}

$postExportFiles = @(
    'scripts/cpstudio/post_export_signal.bat',
    'scripts/cpstudio/write_export_request.ps1',
    'scripts/cpstudio/Invoke-PostExportAudit.ps1',
    'scripts/cpstudio/Invoke-PostExportEngineering.ps1',
    'scripts/cpstudio/New-PostExportRunnerEvidence.ps1',
    'scripts/git/Get-ReadOnlyGitAudit.ps1'
)
foreach ($relativePath in $postExportFiles) {
    $text = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot $relativePath))
    foreach ($forbiddenText in @('ctrlX-PLC-Engineering.exe', 'codesys-mcp-persistent', 'download_to_device')) {
        if ($text.Contains($forbiddenText)) {
            $failures.Add("Post-export hook contains forbidden launcher/online text '$forbiddenText': $relativePath")
        }
    }
}

$postExportHookText = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot 'scripts/cpstudio/post_export_signal.bat'))
if ($postExportHookText.Contains('OfflinePostExportCheck')) {
    $failures.Add('CpStudio Post-export hook must not start the user-triggered offline Build checker.')
}

$offlineHelperPath = Join-Path $repositoryRoot 'scripts/cpstudio/offline_mcp_build.cjs'
$offlineHelperText = [System.IO.File]::ReadAllText($offlineHelperPath)
foreach ($forbiddenText in @('connect_to_device', 'download_to_device', 'start_stop_application', 'write_variable', 'save_project')) {
    if ($offlineHelperText.Contains($forbiddenText)) {
        $failures.Add("Offline Build helper contains forbidden operation '$forbiddenText'.")
    }
}
$offlineCheckerText = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot 'scripts/cpstudio/Invoke-OfflinePostExportCheck.ps1'))
foreach ($forbiddenText in @('Stop-Process', 'taskkill')) {
    if ($offlineCheckerText.Contains($forbiddenText)) {
        $failures.Add("Offline Build checker contains destructive process operation '$forbiddenText'.")
    }
}

$restAppliers = @(
    'scripts/plc/apply_wp100_run_rest.ps1',
    'scripts/plc/apply_wp100_run_sequence_rest.ps1'
)
$transactionGuardPath = Join-Path $repositoryRoot 'scripts/plc/SfcRestWriter.Transaction.ps1'
$transactionGuardText = [System.IO.File]::ReadAllText($transactionGuardPath)
foreach ($requiredText in @(
    'schemaVersion = 2',
    'declarationPolicy = ''read-only-preserve-exactly''',
    'bodyCanonicalJson = $_.BodyCanonicalJson',
    'finalSnapshotBodyCanonicalJson',
    'Assert-PreflightSnapshotCurrent',
    'Invoke-WriteRollback',
    'ROLLBACK FAILED',
    'POST parent does not have an existing immutable preflight snapshot',
    'function Assert-RequiredEnumItems',
    'CpStudio prerequisite is incomplete',
    'obsoleteDeletion = ''disabled'''
)) {
    if (-not $transactionGuardText.Contains($requiredText)) {
        $failures.Add("Shared PLC REST transaction guard is missing '$requiredText'.")
    }
}
foreach ($restApplier in $restAppliers) {
    $restApplierPath = Join-Path $repositoryRoot $restApplier
    $restApplierText = [System.IO.File]::ReadAllText($restApplierPath)
    foreach ($forbiddenText in @('connect_to_device', 'download_to_device', 'start_stop_application', 'write_variable')) {
        if ($restApplierText.Contains($forbiddenText)) {
            $failures.Add("PLC REST applier contains forbidden online operation '$forbiddenText': $restApplier")
        }
    }
    foreach ($requiredText in @(
        "[ValidateSet('PlanOnly', 'Apply')][string]`$Mode = 'PlanOnly'",
        'Apply requires -ExpectedPlanSha256 from a fresh PlanOnly run.',
        'Plan hash mismatch; refusing Apply',
        'Assert-PreflightSnapshotCurrent',
        '# Mutation phase begins only after the immutable plan/hash gate',
        'declarationTextUnchanged = $true',
        'SfcRestWriter.Transaction.ps1',
        'Invoke-WriteRollback',
        '$null = Get-Node $dataStructPath',
        'USER_INFO_MEASUREMENT_COMPLETE''; Index = 16',
        "-EnumName 'AutoInfoLineEnum'",
        "-Phase 'pre-save verification'",
        "-Phase 'post-save verification'"
    )) {
        if (-not $restApplierText.Contains($requiredText)) {
            $failures.Add("PLC REST applier is missing interface-preserving plan/apply guard '$requiredText': $restApplier")
        }
    }
    if ([regex]::IsMatch($restApplierText, '(?im)\.declaration\s*=')) {
        $failures.Add("PLC REST applier assigns an existing object's declaration instead of preserving it: $restApplier")
    }
    if ([regex]::IsMatch($restApplierText, '(?im)Invoke-RestMethod\s+-Method\s+Delete')) {
        $failures.Add("PLC REST applier performs obsolete-child deletion; deletion is disabled until a separate reviewed migration exists: $restApplier")
    }

    $planOnlyGateIndex = $restApplierText.LastIndexOf("if (`$Mode -eq 'PlanOnly')", [System.StringComparison]::Ordinal)
    $planHashGateIndex = $restApplierText.LastIndexOf('Plan hash mismatch; refusing Apply', [System.StringComparison]::Ordinal)
    $secondReadIndex = $restApplierText.LastIndexOf('Assert-PreflightSnapshotCurrent', [System.StringComparison]::Ordinal)
    $mutationIndex = $restApplierText.LastIndexOf('Invoke-WriteRequests', [System.StringComparison]::Ordinal)
    if (($planOnlyGateIndex -lt 0) -or
        ($planHashGateIndex -le $planOnlyGateIndex) -or
        ($secondReadIndex -le $planHashGateIndex) -or
        ($mutationIndex -le $secondReadIndex)) {
        $failures.Add("PLC REST applier mutation phase is not ordered after PlanOnly, plan-hash and second-read gates: $restApplier")
    }

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($restApplierPath, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        $failures.Add("PLC REST applier PowerShell parse error at line $($parseError.Extent.StartLineNumber): $($parseError.Message): $restApplier")
    }

    $restApplierLines = [System.IO.File]::ReadAllLines($restApplierPath)
    for ($lineIndex = 0; $lineIndex -lt $restApplierLines.Count; $lineIndex++) {
        $line = $restApplierLines[$lineIndex]
        if (($line.Contains('<transition ')) -and
            (-not $line.Contains(' name='))) {
            $failures.Add("PLCopenXML SFC transition is missing a name attribute: ${restApplier}:$($lineIndex + 1)")
        }
        if (($line.Contains('Add-SfcTransition -Context')) -and
            (-not $line.Contains(' -Name '))) {
            $failures.Add("SFC transition call is missing its internal name: ${restApplier}:$($lineIndex + 1)")
        }
    }
}

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($transactionGuardPath, [ref]$tokens, [ref]$parseErrors)
foreach ($parseError in @($parseErrors)) {
    $failures.Add("Shared PLC REST transaction guard parse error at line $($parseError.Extent.StartLineNumber): $($parseError.Message)")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output ("Project framework OK: {0} core files, {1} ownership records, {2} PLC sources" -f $requiredFiles.Count, $ownershipRecords.Count, $stFiles.Count)
