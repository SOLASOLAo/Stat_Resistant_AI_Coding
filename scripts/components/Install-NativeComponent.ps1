[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [Parameter(Mandatory)][string]$PrjExtRoot
)
# Copy only the candidate's own PrjExt overlay. No IDE, Std or device actions.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath($PackageRoot).TrimEnd('\','/')
$target = [IO.Path]::GetFullPath($PrjExtRoot).TrimEnd('\','/')
if ([IO.Path]::GetFileName($target) -cne 'PrjExt' -or $target -match '(?i)[\\/](Std|Station010)([\\/]|$)') {
    throw 'Use an isolated reference PrjExt directory.'
}
& (Join-Path $PSScriptRoot 'Test-ComponentPackage.ps1') -PackageRoot $package | Out-Null
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $package 'ARTIFACT-MANIFEST.json') | ConvertFrom-Json
$files = @($manifest.payload.files | Where-Object path -like 'PrjExt/*')
if (-not $files.Count) { throw 'No own CpStudio object payload.' }
$operations = @(foreach ($entry in $files) {
    $relative = $entry.path.Substring(7)
    if ($relative -notmatch '^(Objects|Peripherals)/(Bpp[A-Za-z0-9]+|ForceTrace|MachineCommon|Burster2316)/') { throw 'Not an owned component object.' }
    $destination = [IO.Path]::GetFullPath((Join-Path $target $relative))
    if (-not $destination.StartsWith($target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escapes PrjExt.' }
    for ($node=$destination; $node; $node=[IO.Path]::GetDirectoryName($node)) {
        if ((Test-Path -LiteralPath $node) -and ((Get-Item -Force -LiteralPath $node).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Target traverses a junction or symlink.' }
    }
    $exists = Test-Path -LiteralPath $destination
    if ($exists -and (Get-FileHash -LiteralPath $destination).Hash -cne $entry.sha256) { throw "Existing candidate differs: $relative. Use a fresh reference." }
    [pscustomobject]@{Source=(Join-Path $package $entry.path);Target=$destination;Sha256=$entry.sha256;Exists=$exists}
})
foreach ($operation in $operations) {
    if (-not $operation.Exists) {
        $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($operation.Target))
        [IO.File]::Copy($operation.Source,$operation.Target,$false)
    }
    if ((Get-FileHash -LiteralPath $operation.Target).Hash -cne $operation.Sha256) { throw 'Installed file readback differs.' }
}
[pscustomobject]@{Component=$manifest.component;Copied=@($operations | Where-Object {-not $_.Exists}).Count;
    Verified=$operations.Count;PrjExt=$target;StdChanged=$false;DeviceAccess=$false}
