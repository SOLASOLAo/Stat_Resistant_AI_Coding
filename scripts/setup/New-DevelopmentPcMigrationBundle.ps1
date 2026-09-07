<#
.SYNOPSIS
Creates the minimal OneDrive transfer bundle for a new development computer.

.DESCRIPTION
Records the three Git revisions, archives the current encrypted PLC project,
and optionally packages Std/Technical Docs. Plaintext connection credentials,
licenses, user profiles, IDE state and Git data are excluded.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepositoryRoot,
    [string]$OneDriveRoot,
    [string]$BundleName = ('BPP_ResistantStation_DevPC_{0}' -f (Get-Date -Format 'yyyy-MM-dd_HHmmss')),
    [switch]$SkipCompanyAssets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string]$Repository, [string[]]$Arguments)
    $result = & git -C $Repository @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed for $Repository`n$($result -join [Environment]::NewLine)"
    }
    (($result | Out-String).Trim())
}

function New-Archive {
    param([string]$Archive, [string[]]$InputPaths)
    Push-Location $WorkspaceRoot
    try {
        & $SevenZip a -t7z -mx=1 -mmt=on -y -bd -bso0 -bsp0 $Archive @InputPaths
        if ($LASTEXITCODE -ne 0) { throw "7-Zip failed to create $Archive" }
        & $SevenZip t -bd -bso0 -bsp0 $Archive
        if ($LASTEXITCODE -ne 0) { throw "7-Zip validation failed for $Archive" }
    }
    finally {
        Pop-Location
    }
}

if (-not $RepositoryRoot) { $RepositoryRoot = Join-Path $PSScriptRoot '..\..' }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$WorkspaceRoot = [IO.Directory]::GetParent($RepositoryRoot).FullName
if (-not $OneDriveRoot) { $OneDriveRoot = $env:OneDriveCommercial }
if (-not $OneDriveRoot -or -not (Test-Path -LiteralPath $OneDriveRoot -PathType Container)) {
    throw 'Company OneDrive is unavailable. Pass -OneDriveRoot explicitly.'
}

$blocking = @(Get-CimInstance Win32_Process | Where-Object {
    ($_.Name -match 'CpStudio|ctrlX-PLC-Engineering|ctrlX-IO-Engineering') -or
    ($_.ExecutablePath -match 'CpStudio|ctrlXPLCEngineering|ctrlXIOEngineering')
})
if ($blocking) {
    throw "Close CpStudio, PLC Engineering and IO Engineering first: $($blocking.Name -join ', ')"
}

$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
$StationRoot = Join-Path $WorkspaceRoot 'Station010'
$StdRoot = Join-Path $WorkspaceRoot 'Std'
$DocsRoot = Join-Path $WorkspaceRoot 'Technical Docs'
$MethodRoot = Join-Path $RepositoryRoot 'ctrlx-ai-coding'
$PlcProject = Join-Path $StationRoot 'Plc\Stat010_V5.11_CtrlX_PLC.project'
foreach ($path in @($SevenZip, $StationRoot, $StdRoot, $DocsRoot, $MethodRoot, $PlcProject)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required source missing: $path" }
}

$OneDriveRoot = [IO.Path]::GetFullPath($OneDriveRoot)
$DestinationParent = Join-Path $OneDriveRoot 'ProjectMigration\BPP_ResistantStation'
$Destination = Join-Path $DestinationParent $BundleName
if (Test-Path -LiteralPath $Destination) { throw "Destination already exists: $Destination" }
if (-not $PSCmdlet.ShouldProcess($Destination, 'Create development-PC migration bundle')) { return }

$TempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$StagingRoot = Join-Path $TempRoot ('bpp-devpc-migration-' + [guid]::NewGuid().ToString('N'))
$Bundle = Join-Path $StagingRoot $BundleName

try {
    [IO.Directory]::CreateDirectory($Bundle) | Out-Null

    $repoSources = @(
        @('McpCoding', $RepositoryRoot),
        @('Station010', $StationRoot),
        @('ctrlx-ai-coding', $MethodRoot)
    )
    $repositories = foreach ($repo in $repoSources) {
        if (-not (Test-Path -LiteralPath (Join-Path $repo[1] '.git'))) {
            throw "Git repository missing: $($repo[1])"
        }
        $dirty = Invoke-Git $repo[1] @('status', '--porcelain=v1')
        [ordered]@{
            name = $repo[0]
            origin = Invoke-Git $repo[1] @('remote', 'get-url', 'origin')
            branch = Invoke-Git $repo[1] @('branch', '--show-current')
            commit = Invoke-Git $repo[1] @('rev-parse', 'HEAD')
            dirtyPaths = @($dirty -split "`r?`n" | Where-Object { $_ })
        }
    }

    New-Archive (Join-Path $Bundle 'Station010_CurrentPlcProject.7z') `
        @('Station010\Plc\Stat010_V5.11_CtrlX_PLC.project')

    if (-not $SkipCompanyAssets) {
        $assets = @('Std', 'Technical Docs')
        $assets += @(Get-ChildItem -LiteralPath $WorkspaceRoot -File | Where-Object {
            ($_.Name -like 'Asc*.asc') -or
            ($_.Name -in @(
                'CODEX_VERIFIED_CONTROL_PRODUCTIZATION_PLAN.md',
                'mhs-research-cn.html',
                'owen2_ip_assignment.csv'
            ))
        } | ForEach-Object Name)
        New-Archive (Join-Path $Bundle 'BPP_CompanyAssets.7z') $assets
    }

    $plcInfo = Get-Item -LiteralPath $PlcProject
    $manifest = [ordered]@{
        schemaVersion = 1
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        sourceWorkspace = $WorkspaceRoot
        destination = $Destination
        repositories = @($repositories)
        currentPlcProject = [ordered]@{
            relativePath = 'Station010\Plc\Stat010_V5.11_CtrlX_PLC.project'
            length = $plcInfo.Length
            sha256 = (Get-FileHash -LiteralPath $PlcProject -Algorithm SHA256).Hash
        }
        archives = @(Get-ChildItem -LiteralPath $Bundle -Filter '*.7z' | Sort-Object Name | ForEach-Object {
            [ordered]@{
                name = $_.Name
                length = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        })
        excluded = @(
            'plaintext DataSetAccess/HMI/Target credentials',
            'License workflow and software license stores',
            'Git metadata, IDE locks/caches/user files, logs, bin and obj',
            'Codex/Git user configuration, Runner state and HMI IPC datasets'
        )
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Bundle 'migration-manifest.json') -Encoding utf8NoBOM

    $rows = $repositories | ForEach-Object {
        "| $($_.name) | ``$($_.origin)`` | ``$($_.branch)`` | ``$($_.commit)`` |"
    }
    @"
# Restore this project on a new development PC

OneDrive is transfer-only. Fully download this folder, verify
`SHA256SUMS.txt`, then restore into a normal local workspace.

| Directory | Origin | Branch | Pinned commit |
|---|---|---|---|
$($rows -join "`n")

1. Clone the three repositories and checkout the pinned commits. Keep
   `Station010`, `Std` and `McpCoding` as siblings, with `ctrlx-ai-coding`
   inside `McpCoding`. Do not copy `.git` through OneDrive.
2. Extract `BPP_CompanyAssets.7z` into the workspace root when present.
3. Extract `Station010_CurrentPlcProject.7z` into the workspace root last.
   Its extracted PLC project SHA-256 must be:
   `$($manifest.currentPlcProject.sha256)`
4. Re-enter machine-local HMI/DataSetAccess/Target settings with the official
   tools. Do not restore License workflow, IDE cache or lock files.
5. Follow `McpCoding/TEAM_SETUP.md` and run the workstation/static/Post-export
   checks before opening a physical PLC connection or downloading.
"@ | Set-Content -LiteralPath (Join-Path $Bundle 'RESTORE_FIRST.md') -Encoding utf8NoBOM

    $checksums = Get-ChildItem -LiteralPath $Bundle -File | Sort-Object Name | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name
    }
    $checksums | Set-Content -LiteralPath (Join-Path $Bundle 'SHA256SUMS.txt') -Encoding utf8NoBOM

    [IO.Directory]::CreateDirectory($DestinationParent) | Out-Null
    Copy-Item -LiteralPath $Bundle -Destination $DestinationParent -Recurse
    foreach ($line in $checksums) {
        $expected, $name = $line -split '\s{2}', 2
        $actual = (Get-FileHash -LiteralPath (Join-Path $Destination $name) -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw "OneDrive local-copy hash mismatch: $name" }
    }

    [pscustomobject]@{
        Status = 'READY_FOR_ONEDRIVE_SYNC'
        Destination = $Destination
        Files = (Get-ChildItem -LiteralPath $Destination -File).Count
        Bytes = (Get-ChildItem -LiteralPath $Destination -File | Measure-Object Length -Sum).Sum
        NextStep = 'Wait for the OneDrive green check before using the new PC.'
    }
}
finally {
    $resolved = [IO.Path]::GetFullPath($StagingRoot)
    if ($resolved.StartsWith($TempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
