[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SnapshotDirectory,

    [Parameter(Mandatory = $false)]
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
$snapshotRoot = [System.IO.Path]::GetFullPath($SnapshotDirectory)
$manifestPath = Join-Path $snapshotRoot 'manifest.json'
$markerPath = Join-Path $snapshotRoot '.plc-snapshot-root'

if (-not [System.IO.File]::Exists($markerPath)) {
    throw "Snapshot marker is missing: $markerPath"
}
if ([System.IO.File]::ReadAllText($markerPath).Trim() -ne 'plc-text-snapshot-v1') {
    throw "Snapshot marker is invalid: $markerPath"
}
if (-not [System.IO.File]::Exists($manifestPath)) {
    throw "Snapshot manifest is missing: $manifestPath"
}

$manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
if ($manifest.formatVersion -ne 1) {
    throw "Unsupported snapshot formatVersion: $($manifest.formatVersion)"
}

$seenPaths = @{}
$seenFiles = @{}
$failures = New-Object System.Collections.Generic.List[string]
foreach ($object in @($manifest.objects)) {
    $relativePath = [string]$object.file
    if (-not $relativePath.StartsWith('objects/') -or -not $relativePath.EndsWith('.st')) {
        $failures.Add("Invalid object file path: $relativePath")
        continue
    }
    if ($seenPaths.ContainsKey([string]$object.path)) {
        $failures.Add("Duplicate object path: $($object.path)")
    }
    if ($seenFiles.ContainsKey($relativePath)) {
        $failures.Add("Duplicate object file: $relativePath")
    }
    $seenPaths[[string]$object.path] = $true
    $seenFiles[$relativePath] = $true

    $absolutePath = Join-Path $snapshotRoot ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not [System.IO.File]::Exists($absolutePath)) {
        $failures.Add("Missing object file: $relativePath")
        continue
    }
    $actualHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$object.sha256).ToLowerInvariant()) {
        $failures.Add("SHA256 mismatch: $relativePath")
    }
}

if ([int]$manifest.objectCount -ne @($manifest.objects).Count) {
    $failures.Add("objectCount does not match manifest objects")
}

$actualFiles = Get-ChildItem -LiteralPath (Join-Path $snapshotRoot 'objects') -File -Filter '*.st'
foreach ($file in $actualFiles) {
    $relativePath = 'objects/' + $file.Name
    if (-not $seenFiles.ContainsKey($relativePath)) {
        $failures.Add("Untracked snapshot file: $relativePath")
    }
}

if ($ProjectPath) {
    $resolvedProject = [System.IO.Path]::GetFullPath($ProjectPath)
    $projectHash = (Get-FileHash -LiteralPath $resolvedProject -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($projectHash -ne ([string]$manifest.sourceProjectSha256).ToLowerInvariant()) {
        $failures.Add("Source project SHA256 does not match: $resolvedProject")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output ("Snapshot OK: {0} objects; project={1}" -f $manifest.objectCount, $manifest.sourceProject)

