[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Component,
    [ValidateSet('Check','Build')][string]$Command = 'Check',
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$ReleaseManifestPath
)
# Called by Build-DeviceComponent. Native release identity is independent of
# the application selection lock. Never installs, imports, or connects to a PLC.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 required.' }
$repo = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/')
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Resolve-PayloadPath([string]$Root, [string]$Relative) {
    if ($Relative -notmatch '^[A-Za-z0-9_./ -]+$' -or [IO.Path]::IsPathRooted($Relative) -or
        @($Relative.Split('/') | Where-Object { $_ -in @('','.','..','Std') }).Count) {
        throw "Unsafe or vendor payload path: $Relative"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $full.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes root.' }
    for ($node=$full; $node.Length -ge $Root.Length; $node=[IO.Path]::GetDirectoryName($node)) {
        if ((Test-Path -LiteralPath $node) -and ((Get-Item -LiteralPath $node -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Package paths must not traverse junctions or symlinks.'
        }
        if ($node -eq $Root) { break }
    }
    return $full
}
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }

if ($ReleaseManifestPath -notmatch '^components/releases/[A-Za-z0-9_./-]+\.json$') { throw 'Use a repository-relative independent release manifest.' }
$manifestFile = Resolve-PayloadPath $repo $ReleaseManifestPath
$manifest = Get-Content -Raw -LiteralPath $manifestFile -Encoding UTF8 | ConvertFrom-Json -AsHashtable
if ($manifest.schemaVersion -ne 3 -or $manifest.id -cne $Component -or
    $manifest.version -notmatch '^\d+\.\d+\.\d+\.\d+$' -or $manifest.revision -lt 1 -or
    $manifest.status -cne 'local-native-candidate' -or $manifest.company -cnotin @('BPP Internal Engineering','Internal Engineering') -or
    $manifest.sourceRevision -notmatch '^[a-f0-9]{40}$') { throw 'Invalid independent native candidate manifest.' }
if (($manifest.compatibility -join '|') -cne 'CpStudio V5.11|ctrlX PLC 2.6.8') { throw 'Compatibility must match the verified toolchain.' }
& git -C $repo cat-file -e ($manifest.sourceRevision + '^{commit}')
if ($LASTEXITCODE -ne 0) { throw 'Source anchor is not present.' }
$payload = [ordered]@{}
foreach ($entry in $manifest.files) {
    $source = Resolve-PayloadPath $repo $entry.source
    $null = Resolve-PayloadPath $repo $entry.path
    if ($payload.Contains($entry.path)) { throw 'Duplicate payload destination.' }
    if ([IO.Path]::GetExtension($source) -notin @('.st','.json','.yaml','.md','.ps1','.py','.cs','.xml','.sfc','.ood','.osd','.otd','.cpsp','.nxdc','.nxhc','.txt','.library','.compiled-library','.project','.had','.dll','.cpsds','.png')) {
        throw "Unreviewed payload extension: $($entry.source)"
    }
    if ((Get-Item -LiteralPath $source).Length -gt 40MB) { throw 'Unexpectedly large payload.' }
    $bytes = [IO.File]::ReadAllBytes($source)
    if ((Hash-Bytes $bytes) -cne $entry.sha256) { throw "Candidate source drift: $($entry.source)" }
    $payload[$entry.path] = $bytes
}
if ($payload.Count -eq 0 -or $payload.Count -gt 250) { throw 'Invalid candidate payload count.' }
foreach ($kind in @('library','consumer')) {
    $proof = $manifest.validation[$kind]
    if (-not $payload.Contains($proof.path)) { throw "Missing $kind evidence payload." }
    $report = $utf8.GetString($payload[$proof.path]) | ConvertFrom-Json -AsHashtable
    $checks = @($report.checks | Where-Object { $_.kind -ceq $kind -and $_.name -ceq $manifest.libraryName })
    if ($checks.Count -ne 1 -or -not $checks[0].freshCompile -or $checks[0].errorCount -ne 0 -or $report.onlineOperations) {
        throw "A fresh offline $kind compile is required."
    }
    $warnings = @($checks[0].messages | Where-Object { $_.severity.EndsWith('Warning') } | ForEach-Object text | Sort-Object)
    if (($warnings -join "`n") -cne (@($proof.warningSignatures | Sort-Object) -join "`n")) { throw 'Compile warnings differ from the reviewed signatures.' }
}
$cpProof = $manifest.validation.cpstudio
if (-not $payload.Contains($cpProof.path)) { throw 'Missing native CpStudio evidence.' }
$native = $utf8.GetString($payload[$cpProof.path]) | ConvertFrom-Json -AsHashtable
if (-not $native.passed -or -not $native.savedAndReopened -or -not $native.exported -or $native.physicalAcceptance) {
    throw 'Native insert/export/save/reopen evidence is required; field acceptance is separate.'
}
$payload['RELEASE.json'] = [IO.File]::ReadAllBytes($manifestFile)
$entries = @(foreach ($path in ($payload.Keys | Sort-Object)) {
    [ordered]@{path=$path;length=$payload[$path].Length;sha256=(Hash-Bytes $payload[$path])}
})
$lines = @($entries | ForEach-Object { "$($_.path)|$($_.length)|$($_.sha256)" })
$contentId = Hash-Bytes ($utf8.GetBytes(($lines -join "`n") + "`n"))
$inventory = [ordered]@{schemaVersion=1;component=$Component;version=$manifest.version;revision=$manifest.revision;
    releaseEligible=$false;developmentSnapshot=$true;sourceCommit=$manifest.sourceRevision;
    validation=$manifest.validation;payload=[ordered]@{contentId=$contentId;fileCount=$entries.Count;files=$entries}}
$payload['ARTIFACT-MANIFEST.json'] = $utf8.GetBytes(($inventory | ConvertTo-Json -Depth 30) + "`n")
$output = Resolve-PayloadPath $repo "data/components/native/$Component-$($manifest.version)-local-rev$($manifest.revision)"
$zipPath = $output + '.zip'
if (Test-Path -LiteralPath $output) {
    if (@(Get-ChildItem -LiteralPath $output -Force -Recurse -File).Count -ne $payload.Count) { throw 'Existing package differs; use a new revision.' }
    foreach ($path in $payload.Keys) {
        if ((Get-FileHash -LiteralPath (Resolve-PayloadPath $output $path) -Algorithm SHA256).Hash -cne (Hash-Bytes $payload[$path])) { throw 'Never overwrite a candidate revision.' }
    }
    $status = 'UNCHANGED'
} elseif ($Command -eq 'Check') { $status = 'VALID' }
else {
    if (Test-Path -LiteralPath $zipPath) { throw 'Candidate ZIP already exists.' }
    $null = New-Item -ItemType Directory -Path $output -ErrorAction Stop
    foreach ($path in $payload.Keys) {
        $target = Resolve-PayloadPath $output $path
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        $stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew)
        try { $stream.Write($payload[$path],0,$payload[$path].Length) } finally { $stream.Dispose() }
    }
    & (Join-Path $PSScriptRoot 'Test-ComponentPackage.ps1') -PackageRoot $output | Out-Null
    [IO.Compression.ZipFile]::CreateFromDirectory($output,$zipPath)
    $status = 'BUILT'
}
[pscustomobject]@{Status=$status;Component=$Component;Version=$manifest.version;Revision=$manifest.revision;
    ContentId=$contentId;Output=$output;Zip=$zipPath;SelectionLockChanged=$false;OnlineAction=$false}
