[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
# Hash verification only, including on a colleague's computer without Git/PLE.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($PackageRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$manifest = Get-Content -LiteralPath (Join-Path $root 'ARTIFACT-MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$declared = @($manifest.payload.files)
if ($declared.Count -ne $manifest.payload.fileCount) { throw 'Invalid manifest count.' }
$seen = @{}
$lines = @(foreach ($entry in ($declared | Sort-Object { $_.path })) {
    if ($entry.path -notmatch '^[A-Za-z0-9_./ -]+$' -or [IO.Path]::IsPathRooted($entry.path) -or
        @($entry.path.Split('/') | Where-Object { $_ -in @('','.','..') }).Count -or $seen.ContainsKey($entry.path)) { throw 'Unsafe or duplicate inventory path.' }
    $seen[$entry.path] = $true
    $path = Join-Path $root $entry.path
    $node = $path
    while ($node.Length -ge $root.Length) {
        if ((Get-Item -LiteralPath $node -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Package reparse point rejected.' }
        if ($node -eq $root) { break }
        $node = [IO.Path]::GetDirectoryName($node)
    }
    if ((Get-Item -LiteralPath $path).Length -ne $entry.length -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $entry.sha256) { throw "Package content changed: $($entry.path)" }
    "$($entry.path)|$($entry.length)|$($entry.sha256)"
})
$sha = [Security.Cryptography.SHA256]::Create()
try { $contentId = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n"))).Replace('-','') }
finally { $sha.Dispose() }
if ($contentId -cne $manifest.payload.contentId) { throw 'Payload contentId mismatch.' }
if (@(Get-ChildItem -LiteralPath $root -Force -Recurse -File).Count -ne $declared.Count + 1) { throw 'Unexpected or missing package files.' }
[pscustomobject]@{Status='VALID';Component=$manifest.component;Version=$manifest.version;ContentId=$contentId;Files=$declared.Count+1;ReleaseEligible=$manifest.releaseEligible;DeviceAccess=$false}
