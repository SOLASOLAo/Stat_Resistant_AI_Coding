[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StationRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet('full', 'code-only', 'unknown')]
    [string]$ExportMode = 'unknown'
)

$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $PSCommandPath
$engineeringRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory '..\..'))
if (-not $StationRoot) {
    $StationRoot = Join-Path (Split-Path -Parent $engineeringRoot) 'Station010_0708'
}
$resolvedStationRoot = [System.IO.Path]::GetFullPath($StationRoot)

if (-not [System.IO.Directory]::Exists($resolvedStationRoot)) {
    throw "Station root does not exist: $resolvedStationRoot"
}

$requestDirectory = [System.IO.Path]::GetFullPath((Join-Path $engineeringRoot 'data\requests'))
$expectedDataRoot = [System.IO.Path]::GetFullPath((Join-Path $engineeringRoot 'data'))
if (-not $requestDirectory.StartsWith($expectedDataRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved request directory escaped the engineering data root: $requestDirectory"
}
[System.IO.Directory]::CreateDirectory($requestDirectory) | Out-Null

$plcProject = Join-Path $resolvedStationRoot 'Plc\Stat010_V5.11_CtrlX_PLC.project'
$request = [ordered]@{
    schemaVersion   = 1
    requestId       = [guid]::NewGuid().ToString()
    requestedAtUtc = [DateTime]::UtcNow.ToString('o')
    source          = 'CpStudio.PostExport'
    status          = 'pending'
    exportMode      = $ExportMode
    engineeringRoot = $engineeringRoot
    stationRoot     = $resolvedStationRoot
    plcProject      = $plcProject
}

$requestPath = Join-Path $requestDirectory 'export_request.json'
$temporaryPath = Join-Path $requestDirectory ('.export_request.{0}.tmp' -f $request.requestId)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText(
    $temporaryPath,
    (($request | ConvertTo-Json -Depth 4) + [Environment]::NewLine),
    $utf8NoBom
)

if ([System.IO.File]::Exists($requestPath)) {
    [System.IO.File]::Delete($requestPath)
}
[System.IO.File]::Move($temporaryPath, $requestPath)

Write-Output "CpStudio export request published: $requestPath"
