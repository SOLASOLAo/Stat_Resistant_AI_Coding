<#
.SYNOPSIS
Runs the read-only workstation acceptance checks documented in TEAM_SETUP.md.

.DESCRIPTION
Reads config/project.yaml to locate the current CpStudio, PLC and IO projects,
then checks the standard repository layout, pinned vendor tools, Node/npm,
codesys-mcp-persistent, the Codex MCP block, the ctrlX compatibility patch and
the project-specific Kistler 5867C ESI source/repository entry.
The script never starts an IDE, opens or saves a project, or contacts a PLC.

.PARAMETER RepositoryRoot
McpCoding repository root. The default is derived from this script location.

.PARAMETER SkipPatchCheck
Skips the external patch script's non-mutating -Check invocation. The result is
reported as a warning instead of a pass.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')),

    [Parameter(Mandatory = $false)]
    [string]$CpStudioExe = 'C:\Nexeed\Automation\CSV5_11\Bosch.Nexeed.Automation.CpStudio.exe',

    [Parameter(Mandatory = $false)]
    [string]$PlcEngineeringExe = 'C:\ctrlXWORKS\ctrlXPLCEngineering\PLE_V_0206\StudioPlc\Common\ctrlX-PLC-Engineering.exe',

    [Parameter(Mandatory = $false)]
    [string]$IoEngineeringExe = 'C:\ctrlXWORKS\ctrlXIOEngineering\IOE_V_0206\Studio\Common\ctrlX-IO-Engineering.exe',

    [Parameter(Mandatory = $false)]
    [string]$ManagedLibraries = 'C:\ProgramData\Rexroth\PLE-V-0206\0\Studio\Managed Libraries',

    [Parameter(Mandatory = $false)]
    [switch]$SkipPatchCheck
)

$ErrorActionPreference = 'Stop'
$results = New-Object System.Collections.Generic.List[object]

function Add-CheckResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [bool]$Required,
        [string]$Detail
    )

    $results.Add([pscustomobject]@{
        Status   = if ($Passed) { 'PASS' } elseif ($Required) { 'FAIL' } else { 'WARN' }
        Required = $Required
        Check    = $Name
        Detail   = $Detail
    })
}

function Get-ProjectConfigValue {
    param(
        [string]$ConfigPath,
        [string]$Key
    )

    $pattern = '^\s*{0}:\s*(?<value>.+?)\s*$' -f [regex]::Escape($Key)
    $match = [System.IO.File]::ReadAllLines($ConfigPath) |
        Select-String -Pattern $pattern |
        Select-Object -First 1

    if (-not $match) {
        throw "Missing '$Key' in $ConfigPath"
    }

    return $match.Matches[0].Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Resolve-RepositoryPath {
    param(
        [string]$BasePath,
        [string]$ConfiguredPath
    )

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return [System.IO.Path]::GetFullPath($ConfiguredPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $ConfiguredPath))
}

function Get-CommandVersion {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $resolved = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $resolved) {
        return $null
    }

    try {
        return ((& $Command @Arguments 2>$null) | Out-String).Trim()
    }
    catch {
        return $null
    }
}

function Get-GitOrigin {
    param(
        [string]$RepositoryPath
    )

    if (-not (Get-Command 'git' -ErrorAction SilentlyContinue)) {
        return $null
    }
    if (-not [System.IO.Directory]::Exists((Join-Path $RepositoryPath '.git'))) {
        return $null
    }

    try {
        return ((& git -C $RepositoryPath remote get-url origin 2>$null) | Out-String).Trim()
    }
    catch {
        return $null
    }
}

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$configPath = Join-Path $RepositoryRoot 'config\project.yaml'
Add-CheckResult 'AI repository root' ([System.IO.Directory]::Exists($RepositoryRoot)) $true $RepositoryRoot
Add-CheckResult 'Project configuration' ([System.IO.File]::Exists($configPath)) $true $configPath

if (-not [System.IO.File]::Exists($configPath)) {
    $results | Format-Table -AutoSize
    exit 1
}

$stationRoot = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'station_root')
$standardRoot = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'standard_library_root')
$cpstudioProject = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'cpstudio_project')
$plcProject = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'plc_project')
$ioProject = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'io_project')
$kistlerEsi = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'kistler_5867c_esi')
$kistlerQuickStart = Resolve-RepositoryPath $RepositoryRoot (Get-ProjectConfigValue $configPath 'kistler_5867c_quick_start')
$methodologyRoot = Join-Path $RepositoryRoot 'ctrlx-ai-coding'

Add-CheckResult 'Station directory' ([System.IO.Directory]::Exists($stationRoot)) $true $stationRoot
Add-CheckResult 'Standard library directory' ([System.IO.Directory]::Exists($standardRoot)) $true $standardRoot
Add-CheckResult 'CpStudio project' ([System.IO.File]::Exists($cpstudioProject)) $true $cpstudioProject
Add-CheckResult 'PLC project' ([System.IO.File]::Exists($plcProject)) $true $plcProject
Add-CheckResult 'IO project' ([System.IO.File]::Exists($ioProject)) $true $ioProject

$expectedKistlerEsiHash = '7AE6DF840A704DBBBC628A6DAFC9FA6BEE8BE3571C83C3F22874F422C11838FC'
$actualKistlerEsiHash = if ([System.IO.File]::Exists($kistlerEsi)) {
    (Get-FileHash -LiteralPath $kistlerEsi -Algorithm SHA256).Hash
}
else {
    $null
}
$kistlerRepositoryEntry = 'C:\ProgramData\Rexroth\IOE-V-0206\0\Studio\Devices\65\58A_0000E52F00000001\Revision%3D16%2300000001\device.xml'
Add-CheckResult 'Kistler 5867C ESI source' ([System.IO.File]::Exists($kistlerEsi)) $true $kistlerEsi
Add-CheckResult 'Kistler 5867C ESI SHA-256' ($actualKistlerEsiHash -eq $expectedKistlerEsiHash) $true ($(if ($actualKistlerEsiHash) { $actualKistlerEsiHash } else { 'source missing' }))
Add-CheckResult 'Kistler 5867C quick-start guide' ([System.IO.File]::Exists($kistlerQuickStart)) $true $kistlerQuickStart
Add-CheckResult 'Kistler 5867C IOE repository entry' ([System.IO.File]::Exists($kistlerRepositoryEntry)) $true $kistlerRepositoryEntry

$aiOrigin = Get-GitOrigin $RepositoryRoot
$stationOrigin = Get-GitOrigin $stationRoot
$methodologyOrigin = Get-GitOrigin $methodologyRoot
Add-CheckResult 'AI Git repository' ($aiOrigin -match 'Stat_Resistant_AI_Coding(?:\.git)?$') $true ($(if ($aiOrigin) { $aiOrigin } else { 'missing repository or origin' }))
Add-CheckResult 'Station Git repository' ($stationOrigin -match 'Stat_Resistant_Station010(?:\.git)?$') $true ($(if ($stationOrigin) { $stationOrigin } else { 'missing repository or origin' }))
Add-CheckResult 'ctrlx-ai-coding repository' ($methodologyOrigin -match 'ctrlx-ai-coding(?:\.git)?$') $true ($(if ($methodologyOrigin) { $methodologyOrigin } else { 'missing repository or origin' }))

Add-CheckResult 'CpStudio V5.11 executable' ([System.IO.File]::Exists($CpStudioExe)) $true $CpStudioExe
Add-CheckResult 'PLC Engineering executable' ([System.IO.File]::Exists($PlcEngineeringExe)) $true $PlcEngineeringExe
Add-CheckResult 'IO Engineering executable' ([System.IO.File]::Exists($IoEngineeringExe)) $true $IoEngineeringExe
Add-CheckResult 'PLE managed libraries' ([System.IO.Directory]::Exists($ManagedLibraries)) $true $ManagedLibraries

$gitVersion = Get-CommandVersion 'git' @('--version')
$nodeVersion = Get-CommandVersion 'node' @('--version')
$npmVersion = Get-CommandVersion 'npm' @('--version')
$mcpVersion = Get-CommandVersion 'codesys-mcp-persistent' @('--version')

Add-CheckResult 'Git command' ([bool]$gitVersion) $true ($(if ($gitVersion) { $gitVersion } else { 'not found' }))
Add-CheckResult 'Node.js command' ([bool]$nodeVersion) $true ($(if ($nodeVersion) { $nodeVersion } else { 'not found' }))
Add-CheckResult 'npm command' ([bool]$npmVersion) $true ($(if ($npmVersion) { $npmVersion } else { 'not found' }))
Add-CheckResult 'codesys-mcp-persistent 0.6.3' ($mcpVersion -eq '0.6.3') $true ($(if ($mcpVersion) { $mcpVersion } else { 'not found' }))

$codexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
$codexMcpConfigured = $false
if ([System.IO.File]::Exists($codexConfig)) {
    $codexText = [System.IO.File]::ReadAllText($codexConfig)
    $codexMcpConfigured = $codexText.Contains('[mcp_servers.codesys-persistent]') -and
        $codexText.Contains('ctrlX PLC 2.6.8') -and
        $codexText.Contains('persistent')
}
Add-CheckResult 'Codex MCP configuration' $codexMcpConfigured $true $codexConfig

if (-not $SkipPatchCheck) {
    $patchScript = Join-Path $methodologyRoot 'patches\codesys-mcp-persistent-crlf\apply-crlf-patch.ps1'
    if ([System.IO.File]::Exists($patchScript)) {
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $patchScript -Check *> $null
        $patchExitCode = $LASTEXITCODE
        Add-CheckResult 'ctrlX MCP compatibility patch' ($patchExitCode -eq 0) $true "exit code $patchExitCode"
    }
    else {
        Add-CheckResult 'ctrlX MCP compatibility patch' $false $true "missing: $patchScript"
    }
}
else {
    Add-CheckResult 'ctrlX MCP compatibility patch' $false $false 'skipped by parameter'
}

$results | Format-Table -AutoSize -Wrap

$failedRequired = @($results | Where-Object { $_.Required -and $_.Status -eq 'FAIL' })
if ($failedRequired.Count -gt 0) {
    Write-Error ("Workstation check failed: {0} required check(s)" -f $failedRequired.Count)
    exit 1
}

Write-Output ("Workstation check passed: {0} checks" -f $results.Count)
