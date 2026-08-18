[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

$requiredFiles = @(
    'config/project.yaml',
    'config/quality-gates.yaml',
    'specs/station.yaml',
    'specs/io.yaml',
    'specs/events.yaml',
    'specs/units/Wp100.yaml',
    'specs/chains/SqS_Wp100_Home.yaml',
    'ai/ownership.yaml',
    'ai/hooks.yaml',
    'ai/graphical.yaml',
    'src/plc/common/FB_OperatorButton.st',
    'src/plc/common/FB_MainPressureControl.st',
    'src/plc/common/FB_MaintenanceDoorControl.st',
    'scripts/cpstudio/post_export_signal.bat',
    'scripts/cpstudio/write_export_request.ps1',
    'scripts/plc/export_plc_snapshot.py',
    'scripts/plc/verify_plc_snapshot.ps1',
    'scripts/ioe/ioe_ipc.ps1'
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

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output ("Project framework OK: {0} required files" -f $requiredFiles.Count)
