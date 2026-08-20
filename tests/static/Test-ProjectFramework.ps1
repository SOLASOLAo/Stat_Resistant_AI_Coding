[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

$requiredFiles = @(
    'TEAM_SETUP.md',
    'config/project.yaml',
    'config/quality-gates.yaml',
    'config/codex-mcp.toml.example',
    'specs/station.yaml',
    'specs/io.yaml',
    'specs/events.yaml',
    'specs/units/Wp100.yaml',
    'specs/chains/SqS_Wp100_Home.yaml',
    'specs/chains/SqS_Wp100_Run.yaml',
    'ai/ownership.yaml',
    'ai/hooks.yaml',
    'ai/graphical.yaml',
    'src/plc/common/FB_OperatorButton.st',
    'src/plc/common/FB_MainPressureControl.st',
    'src/plc/common/FB_MaintenanceDoorControl.st',
    'src/plc/project/Station010/Wp100ResistanceResultStruct.st',
    'src/plc/project/Station010/Wp100KistlerResultStruct.st',
    'src/plc/project/Station010/Wp100RunResultStruct.st',
    'src/plc/project/Station010/SqS_Wp100_Run/declaration.st',
    'src/plc/project/Station010/SqS_Wp100_Run/OnChainFinish.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N000.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N010.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N020.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N030.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N040.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N050.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N060.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N070.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N080.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N090.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N100.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N110.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N120.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N130.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N140.st',
    'src/plc/project/Station010/SqS_Wp100_Run/actions/N999.st',
    'catalog/units/NexeedKistlerForceStroke/V1.2/unit.yaml',
    'scripts/cpstudio/post_export_signal.bat',
    'scripts/cpstudio/write_export_request.ps1',
    'scripts/plc/export_plc_snapshot.py',
    'scripts/plc/verify_plc_snapshot.ps1',
    'scripts/plc/apply_wp100_run_rest.ps1',
    'scripts/plc/apply_wp100_run_sequence_rest.ps1',
    'scripts/ioe/ioe_ipc.ps1',
    'scripts/ioe/Install-EtherCatEsi.ps1',
    'scripts/setup/Test-TeamWorkstation.ps1'
)

$failures = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $repositoryRoot ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not [System.IO.File]::Exists($absolutePath)) {
        $failures.Add("Missing required file: $relativePath")
    }
}

foreach ($relativePath in @('../Station010_0708', '../Std')) {
    $absolutePath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $relativePath))
    if (-not [System.IO.Directory]::Exists($absolutePath)) {
        $failures.Add("Missing sibling workspace directory: $relativePath")
    }
}

foreach ($relativePath in @(
    'src/plc/common/FB_OperatorButton.st',
    'src/plc/common/FB_MainPressureControl.st',
    'src/plc/common/FB_MaintenanceDoorControl.st'
)) {
    $text = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot $relativePath))
    if (-not $text.Contains('(* ===== DECLARATION ===== *)')) {
        $failures.Add("Missing declaration marker: $relativePath")
    }
    if (-not $text.Contains('(* ===== IMPLEMENTATION ===== *)')) {
        $failures.Add("Missing implementation marker: $relativePath")
    }
}

$stSourceRoot = Join-Path $repositoryRoot 'src/plc'
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
    'scripts/cpstudio/write_export_request.ps1'
)
foreach ($relativePath in $postExportFiles) {
    $text = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot $relativePath))
    foreach ($forbiddenText in @('ctrlX-PLC-Engineering.exe', 'codesys-mcp-persistent', 'download_to_device')) {
        if ($text.Contains($forbiddenText)) {
            $failures.Add("Post-export hook contains forbidden launcher/online text '$forbiddenText': $relativePath")
        }
    }
}

$restAppliers = @(
    'scripts/plc/apply_wp100_run_rest.ps1',
    'scripts/plc/apply_wp100_run_sequence_rest.ps1'
)
foreach ($restApplier in $restAppliers) {
    $restApplierPath = Join-Path $repositoryRoot $restApplier
    $restApplierText = [System.IO.File]::ReadAllText($restApplierPath)
    foreach ($forbiddenText in @('connect_to_device', 'download_to_device', 'start_stop_application', 'write_variable')) {
        if ($restApplierText.Contains($forbiddenText)) {
            $failures.Add("PLC REST applier contains forbidden online operation '$forbiddenText': $restApplier")
        }
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

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output ("Project framework OK: {0} required files" -f $requiredFiles.Count)
