[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$StationRoot,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot '..\..')).Path
}

if ([string]::IsNullOrWhiteSpace($StationRoot)) {
    $StationRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..\Station010')).Path
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$hmiRoot = Join-Path $ProjectRoot 'src\hmi'
$projectPath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Bpp.ResistantStation.Hmi.csproj'
$catalogPath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Configuration\station010.readonly.json'
$interfacePath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Services\IStationDataSource.cs'
$symbolPath = Join-Path $StationRoot 'Plc\Stat010_V5.11_CtrlX_PLC.Device.Application.xml'

foreach ($path in @($projectPath, $catalogPath, $interfacePath, $symbolPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Required HMI file is missing: $path"
}

$interfaceText = [System.IO.File]::ReadAllText($interfacePath)
Assert-True ($interfaceText -notmatch '(?i)\b(write|force|download|start_stop)\w*\s*\(') `
    'Phase-one IStationDataSource must not expose a write/force/download/start-stop method.'

$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi') -Filter '*.cs' -File -Recurse)
$forbiddenSource = @()
foreach ($sourceFile in $sourceFiles) {
    $sourceText = [System.IO.File]::ReadAllText($sourceFile.FullName)
    if (($sourceText -match '(?i)\.\s*(Write|WriteAsync|Call|CallAsync)\s*\(') -or
        ($sourceText -match '(?i)\b(force|download|start_stop)\w*\s*\(')) {
        $forbiddenSource += $sourceFile.FullName
    }
}
Assert-True ($forbiddenSource.Count -eq 0) `
    ("Phase-one HMI source contains a forbidden write/call/runtime-control surface:`n - " + ($forbiddenSource -join "`n - "))

$catalogText = [System.IO.File]::ReadAllText($catalogPath)
Assert-True ($catalogText -notmatch '(?i)"(user(name)?|password|secret|privateKey)"\s*:') `
    'The checked-in HMI catalog contains a credential field.'
Assert-True ($catalogText -notmatch '(?i)\bns\s*=\s*\d+') `
    'The HMI catalog must resolve namespace indexes from the namespace URI.'

$catalog = $catalogText | ConvertFrom-Json
Assert-True ($catalog.namespaceUri -eq 'http://www.boschrexroth.com/OpcUa/Datalayer') `
    'Unexpected ctrlX Data Layer namespace URI.'
Assert-True (@($catalog.nodes).Count -gt 0) 'The HMI node catalog is empty.'
Assert-True (@($catalog.nodes | Where-Object { $_.writeAllowed }).Count -eq 0) `
    'Phase-one HMI contains a write-enabled node.'
Assert-True (@($catalog.nodes.key | Sort-Object -Unique).Count -eq @($catalog.nodes).Count) `
    'HMI node keys must be unique.'
Assert-True (@($catalog.nodes.identifier | Sort-Object -Unique).Count -eq @($catalog.nodes).Count) `
    'HMI node identifiers must be unique.'

[xml]$symbolXml = [System.IO.File]::ReadAllText($symbolPath)
$typeMembers = @{}
foreach ($type in @($symbolXml.Symbolconfiguration.TypeList.TypeUserDef)) {
    $members = @{}
    foreach ($member in @($type.UserDefElement)) {
        $members[[string]$member.iecname] = [string]$member.type
    }
    $typeMembers[[string]$type.name] = $members
}

$applicationNode = @($symbolXml.Symbolconfiguration.NodeList.Node) |
    Where-Object { $_.name -eq 'Application' } |
    Select-Object -First 1
Assert-True ($null -ne $applicationNode) 'Application root is missing from Symbol Configuration.'

function Test-SymbolPath {
    param([string]$Identifier)

    $prefix = 'plc/app/Application/sym/'
    if (-not $Identifier.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
        return $false
    }

    $segments = $Identifier.Substring($prefix.Length).Split('/')
    $explicitNode = $applicationNode
    $currentType = [string]$applicationNode.type

    foreach ($segment in $segments) {
        $child = $null
        if ($null -ne $explicitNode) {
            $child = @($explicitNode.Node) |
                Where-Object { $_.name -eq $segment } |
                Select-Object -First 1
        }

        if ($null -ne $child) {
            $explicitNode = $child
            $currentType = [string]$child.type
            continue
        }

        if ([string]::IsNullOrWhiteSpace($currentType) -or -not $typeMembers.ContainsKey($currentType)) {
            return $false
        }

        $members = $typeMembers[$currentType]
        if (-not $members.ContainsKey($segment)) {
            return $false
        }

        $currentType = [string]$members[$segment]
        $explicitNode = $null
    }

    return $true
}

$missing = @()
foreach ($node in @($catalog.nodes | Where-Object { $_.enabled -ne $false })) {
    if (-not (Test-SymbolPath -Identifier ([string]$node.identifier))) {
        $missing += [string]$node.identifier
    }
}

Assert-True ($missing.Count -eq 0) `
    ("Configured OPC UA nodes are missing from the current Symbol export:`n - " + ($missing -join "`n - "))

if (-not $SkipBuild) {
    & dotnet build $projectPath --no-restore --configuration Release
    Assert-True ($LASTEXITCODE -eq 0) 'The self-developed HMI did not build successfully.'
}

Write-Host ("HMI read-only scaffold OK: {0} nodes, no write surface." -f @($catalog.nodes).Count)
