[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('burster2316', 'kistler5867c', 'bpp-forcetrace', 'bpp-machinecommon', 'forcetrace', 'machinecommon')][string]$Component,
    [ValidateSet('Check', 'Build')][string]$Command = 'Check',
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '../..'),
    [string]$NativeArtifactsPath,
    [string]$ReleaseManifestPath
)

# Offline source packaging only. Never calls PLE, imports objects or runs payload scripts.
# Keep canonical source names/content unchanged until an independent native library build.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 required.' }
$repo = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Resolve-Contained([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or
        $Relative -notmatch '^[A-Za-z0-9_./-]+$' -or
        [IO.Path]::IsPathRooted($Relative) -or
        @($Relative.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count) {
        throw "Unsafe package path: $Relative"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    $prefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Package path escapes its root.'
    }
    # Reject Windows junctions/symlinks in both source and destination paths.
    $node = $full
    while ($node.Length -ge $Root.Length) {
        if (Test-Path -LiteralPath $node) {
            if ((Get-Item -Force -LiteralPath $node).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse point not allowed: $Relative"
            }
        }
        if ($node -eq $Root) { break }
        $node = [IO.Path]::GetDirectoryName($node)
    }
    return $full
}

function Read-TextBytes([string]$Relative) {
    $path = Resolve-Contained $repo $Relative
    $item = Get-Item -LiteralPath $path
    if ($item.PSIsContainer -or $item.Length -gt 1MB -or
        $item.Extension -notin @('.st', '.json', '.yaml', '.md', '.ps1', '.py', '.cs', '.xml', '.sfc', '.cpsds')) {
        throw "Not an allowed bounded text file: $Relative"
    }
    $bytes = [IO.File]::ReadAllBytes($path)
    $text = $utf8.GetString($bytes)
    if ($text.Contains([char]0)) { throw "Binary content rejected: $Relative" }
    return ,$bytes
}

function Assert-SameBytes([byte[]]$Expected, [byte[]]$Actual, [string]$Description) {
    if (-not [Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($Expected, $Actual)) {
        throw "Different content; do not overwrite this version: $Description"
    }
}

if ($ReleaseManifestPath) {
    # Independent native releases never read or update Station010's selection lock.
    & (Join-Path $PSScriptRoot 'Build-NativeComponentPackage.ps1') -Component $Component `
        -Command $Command -RepositoryRoot $repo -ReleaseManifestPath $ReleaseManifestPath
    return
}

$manifestPath = "components/$Component/component.json"
$manifestBytes = Read-TextBytes $manifestPath
$manifest = $utf8.GetString($manifestBytes) | ConvertFrom-Json -AsHashtable
$lockBytes = Read-TextBytes 'config/component-versions.json'
$lock = $utf8.GetString($lockBytes) | ConvertFrom-Json -AsHashtable
if ($manifest.schemaVersion -notin @(1,2) -or $lock.schemaVersion -notin @(1,2) -or
    $manifest.id -cne $Component -or $manifest.status -cne 'source-candidate' -or
    $manifest.version -notmatch '^0\.\d+\.\d+-rc\.[1-9]\d*$' -or
    $manifest.sourceRevision -notmatch '^[a-f0-9]{40}$' -or
    $manifest.releaseTag -cne "$Component-v$($manifest.version)") {
    throw 'Invalid source-candidate identity/version; stable release is a separate acceptance gate.'
}
$pin = $lock.components[$Component]
if ($null -eq $pin -or $pin.version -cne $manifest.version -or
    $pin.sourceRevision -cne $manifest.sourceRevision -or
    $pin.delivery -cne 'source-candidate' -or $pin.installedNativeLibrary -cne $false) {
    throw 'Component version differs from the source selection lock.'
}
$files = @($manifest.files)
if ($files.Count -lt 1 -or $files.Count -gt 80) { throw 'Invalid payload file count.' }
$payload = [ordered]@{}
foreach ($entry in $files) {
    if ($entry.role -notin @('driver', 'station-reference', 'source-specification', 'offline-test', 'hmi-source', 'plc-publisher', 'guide', 'tooling') -or
        $entry.path -notmatch '^(src/plc/|src/hmi/Bpp.ForceTrace/|specs/|tests/|catalog/|docs/|scripts/hmi/|scripts/components/)') {
        throw 'Payload must use explicit engineering text paths and roles.'
    }
    if ($payload.Contains($entry.path)) { throw 'Duplicate payload path.' }
    $payload[$entry.path] = Read-TextBytes $entry.path
}

# A recorded source commit is the version anchor, not the moving branch tip.
$sourcePaths = @($payload.Keys)
if ($manifest.schemaVersion -eq 2) {
    # The Git commit anchors provenance; it does not pretend to contain dirty
    # candidate bytes. Pin every actual source file and their combined digest.
    & git -C $repo cat-file -e ($manifest.sourceRevision + '^{commit}')
    if ($LASTEXITCODE -ne 0) { throw 'Source anchor commit missing.' }
    $lines = @(foreach ($entry in ($files | Sort-Object { $_.path })) {
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$payload[$entry.path]))
        if ($entry.sha256 -cne $hash) { throw "Component source drift: $($entry.path); review a new candidate snapshot." }
        "$($entry.path)|$($payload[$entry.path].Length)|$hash"
    })
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes(($lines -join "`n") + "`n")))
    if ($manifest.sourceSnapshot.sha256 -cne $digest -or $pin.sourceSnapshotSha256 -cne $digest) { throw 'Snapshot differs from the source selection lock.' }
    $sourceStatus = @(& git -C $repo status --porcelain=v1 --untracked-files=all -- $sourcePaths)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect source dirty state.' }
    $sourceDirty = $sourceStatus.Count -gt 0
    if ($sourceDirty -ne $manifest.sourceSnapshot.dirty) { throw 'Snapshot dirty provenance changed; review the candidate metadata.' }
} else {
$known = @(& git -C $repo ls-tree -r --name-only $manifest.sourceRevision -- $sourcePaths)
if ($LASTEXITCODE -ne 0 -or $known.Count -ne $sourcePaths.Count) {
    throw 'Source baseline missing or payload file not present in the recorded Git commit.'
}
foreach ($path in $sourcePaths) {
    if ($path -cnotin $known) { throw "Source not recorded in baseline: $path" }
}
& git -C $repo diff --quiet $manifest.sourceRevision -- $sourcePaths
if ($LASTEXITCODE -ne 0) { throw 'Component source drift: review a new version/baseline before packaging.' }
}
foreach ($path in $sourcePaths) {
    Assert-SameBytes $payload[$path] (Read-TextBytes $path) $path
}

$drivers = @($files | Where-Object role -eq 'driver')
if ($Component -eq 'burster2316') {
    if ($manifest.kind -cne 'plc-source-driver' -or $drivers.Count -ne 1 -or
        $manifest.nativeLibrary.status -notin @('not-built','consumer-build-failed')) { throw 'Burster source/native-library boundary invalid.' }
    $driver = $utf8.GetString($payload[$drivers[0].path])
    if ($driver -match '\b(Station|AiWp100|Peripherals)\.' -or
        $driver -match '\b(?:\d{1,3}\.){3}\d{1,3}\b' -or
        $driver -notmatch 'IMPLEMENTS IBursterResis2316' -or
        ([regex]::Matches($driver, ':\s*OpconTcpClientIpV4\s*;')).Count -ne 1) {
        throw 'Core must remain station-independent and retain one Nexeed-compatible TCP owner.'
    }
} elseif ($Component -eq 'kistler5867c' -and ($manifest.kind -cne 'standard-driver-integration-kit' -or $drivers.Count -ne 0 -or
          $manifest.nativeLibrary.status -cne 'not-applicable-standard-driver-retained')) {
    throw 'Kistler kit must not claim a replacement driver/library.'
} elseif ($Component -eq 'bpp-forcetrace') {
    if ($manifest.kind -cne 'native-hmi-addon' -or $drivers.Count -ne 0 -or
        $manifest.nativeLibrary.status -cne 'not-applicable-hmi-addon' -or -not $NativeArtifactsPath) { throw 'HMI kit requires its validated native artifact directory.' }
    $artifactRoot = [IO.Path]::GetFullPath($NativeArtifactsPath).TrimEnd([IO.Path]::DirectorySeparatorChar)
    foreach ($artifact in $manifest.nativeArtifacts) {
        if ($artifact.file -notin @('Bpp.ForceTrace.dll','Bpp.ForceTrace.had')) { throw 'Only own HMI binary artifacts are allowed.' }
        $path = Resolve-Contained $artifactRoot $artifact.file
        if ((Get-Item -LiteralPath $path).Length -gt 1MB -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $artifact.sha256) { throw 'Native artifact differs from the pinned tested binary.' }
        $payload[('native/' + $artifact.file)] = [IO.File]::ReadAllBytes($path)
    }
    if ($manifest.nativeArtifacts.Count -ne 2 -or $payload.Keys -cnotcontains 'native/Bpp.ForceTrace.dll' -or $payload.Keys -cnotcontains 'native/Bpp.ForceTrace.had') { throw 'HMI DLL and HAD must be delivered together.' }
    $nativeIdentity = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $artifactRoot 'Bpp.ForceTrace.dll'))
    if ($nativeIdentity.FullName -cne $manifest.nativeAssembly) { throw 'HMI assembly identity mismatch.' }
    $zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $artifactRoot 'Bpp.ForceTrace.had'))
    try {
        if ($zip.Entries.Count -ne 2 -or @($zip.Entries | Where-Object { $_.FullName -cnotin @('Bpp.ForceTrace.dll','AddonDesc.xml') -or $_.Length -gt 1MB }).Count) { throw 'HAD must contain only the own DLL and descriptor.' }
        foreach ($name in @('Bpp.ForceTrace.dll','AddonDesc.xml')) {
            $entry = $zip.GetEntry($name)
            if ($null -eq $entry) { throw 'Incomplete HAD.' }
            $stream = $entry.Open(); $memory = [IO.MemoryStream]::new()
            try { $stream.CopyTo($memory); $bytes = $memory.ToArray() } finally { $stream.Dispose(); $memory.Dispose() }
            $expected = if ($name -eq 'Bpp.ForceTrace.dll') { $payload['native/Bpp.ForceTrace.dll'] } else { $payload['src/hmi/Bpp.ForceTrace/AddonDesc.xml'] }
            Assert-SameBytes $expected $bytes "HAD/$name"
        }
    } finally { $zip.Dispose() }
}

$payload[$manifestPath] = $manifestBytes
$payload["components/$Component/README.md"] = Read-TextBytes "components/$Component/README.md"
$payload['components/README.md'] = Read-TextBytes 'components/README.md'
$inventory = [ordered]@{
    schemaVersion = 1
    component = $Component
    version = $manifest.version
    kind = $manifest.kind
    status = 'source-candidate'
    sourceRevision = $manifest.sourceRevision
    sourceSnapshot = if ($manifest.schemaVersion -eq 2) { $manifest.sourceSnapshot } else { $null }
    nativeLibrary = $manifest.nativeLibrary
    files = @($payload.Keys)
    validation = 'Packaging/source contracts only; no PLE compile, import, deployment or device execution.'
}
$payload['PACKAGE.json'] = $utf8.GetBytes(($inventory | ConvertTo-Json -Depth 20) + "`n")
$payload['README.md'] = $utf8.GetBytes("# $Component $($manifest.version)`n`nDevelopment candidate. Start with [component instructions](components/$Component/README.md).`n`nNo automatic installation, import or deployment is included. Artifact presence is not field acceptance.`n")
if ($manifest.schemaVersion -eq 2) {
    $entries = @(foreach ($path in ($payload.Keys | Sort-Object)) {
        [ordered]@{path=$path;length=$payload[$path].Length;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$payload[$path]))}
    })
    $contentLines = @($entries | ForEach-Object { "$($_.path)|$($_.length)|$($_.sha256)" })
    $contentId = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes(($contentLines -join "`n") + "`n")))
    $artifactManifest = [ordered]@{schemaVersion=1;component=$Component;version=$manifest.version;releaseEligible=$false;developmentSnapshot=$true;sourceCommit=$manifest.sourceRevision;sourceSnapshot=$manifest.sourceSnapshot;payload=[ordered]@{contentId=$contentId;fileCount=$entries.Count;files=$entries}}
    $payload['ARTIFACT-MANIFEST.json'] = $utf8.GetBytes(($artifactManifest | ConvertTo-Json -Depth 25) + "`n")
}
$packagePath = Resolve-Contained $repo "data/components/$Component-$($manifest.version)"

if (Test-Path -LiteralPath $packagePath) {
    if (-not (Test-Path -LiteralPath $packagePath -PathType Container)) { throw 'Package target is not a directory.' }
    $actualFiles = @(Get-ChildItem -LiteralPath $packagePath -Recurse -Force -File)
    if ($actualFiles.Count -ne $payload.Count) { throw 'Existing package incomplete or has unexpected files; never overwrite.' }
    foreach ($path in $payload.Keys) {
        $target = Resolve-Contained $packagePath $path
        Assert-SameBytes $payload[$path] ([IO.File]::ReadAllBytes($target)) $path
    }
    $status = 'UNCHANGED'
} elseif ($Command -eq 'Check') {
    $status = 'VALID'
} else {
    # CreateNew semantics: never merge into an existing/versioned output.
    $null = New-Item -ItemType Directory -Path $packagePath -ErrorAction Stop
    foreach ($path in $payload.Keys) {
        $target = Resolve-Contained $packagePath $path
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        $stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($payload[$path], 0, $payload[$path].Length) }
        finally { $stream.Dispose() }
        Assert-SameBytes $payload[$path] ([IO.File]::ReadAllBytes($target)) $path
    }
    $status = 'BUILT'
}
[pscustomobject]@{
    Status = $status
    Component = $Component
    Version = $manifest.version
    Files = $payload.Count
    Output = if ($Command -eq 'Build' -or $status -eq 'UNCHANGED') { $packagePath } else { $null }
    NativeLibrary = $manifest.nativeLibrary.status
    ContentId = if ($manifest.schemaVersion -eq 2) { $contentId } else { $null }
    OnlineAction = $false
}
