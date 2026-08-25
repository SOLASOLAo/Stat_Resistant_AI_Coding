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
$catalogPath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Configuration\station010.hmi.json'
$interfacePath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Services\IStationDataSource.cs'
$windowPath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\MainWindow.xaml'
$connectionDialogPath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\ConnectionDialog.xaml'
$viewModelPath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\ViewModels\MainViewModel.cs'
$mockSourcePath = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Services\MockStationDataSource.cs'
$symbolPath = Join-Path $StationRoot 'Plc\Stat010_V5.11_CtrlX_PLC.Device.Application.xml'

foreach ($path in @(
        $projectPath,
        $catalogPath,
        $interfacePath,
        $windowPath,
        $connectionDialogPath,
        $viewModelPath,
        $mockSourcePath,
        $symbolPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Required HMI file is missing: $path"
}

$interfaceText = [System.IO.File]::ReadAllText($interfacePath)
Assert-True ($interfaceText -notmatch '(?i)\b(write|force|download|start_stop)\w*\s*\(') `
    'IStationDataSource must not expose a generic write/force/download/start-stop method.'

$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi') -Filter '*.cs' -File -Recurse)
$forbiddenSource = @()
$modeControlSource = Join-Path $hmiRoot 'Bpp.ResistantStation.Hmi\Services\OpcUaReadOnlyDataSource.cs'
foreach ($sourceFile in $sourceFiles) {
    $sourceText = [System.IO.File]::ReadAllText($sourceFile.FullName)
    $containsWrite = $sourceText -match '(?i)\.\s*(Write|WriteAsync|Call|CallAsync)\s*\('
    if ((($containsWrite) -and ($sourceFile.FullName -ne $modeControlSource)) -or
        ($sourceText -match '(?i)\b(force|download|start_stop)\w*\s*\(')) {
        $forbiddenSource += $sourceFile.FullName
    }
}
Assert-True ($forbiddenSource.Count -eq 0) `
    ("HMI source contains a write outside the semantic mode adapter or another forbidden control surface:`n - " + ($forbiddenSource -join "`n - "))

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
    'Subscription catalog contains a write-enabled node.'
Assert-True (@($catalog.nodes.key | Sort-Object -Unique).Count -eq @($catalog.nodes).Count) `
    'HMI node keys must be unique.'
Assert-True (@($catalog.nodes.identifier | Sort-Object -Unique).Count -eq @($catalog.nodes).Count) `
    'HMI node identifiers must be unique.'

$nodeKeys = @{}
foreach ($node in @($catalog.nodes)) {
    $nodeKeys[[string]$node.key] = $true
}

Assert-True (@($catalog.fieldbus.slaves).Count -eq 9) `
    'EtherCAT topology must contain the current nine slaves.'
Assert-True ((Compare-Object @(1..9) @($catalog.fieldbus.slaves.index)).Count -eq 0) `
    'EtherCAT slave indexes must be exactly 1 through 9.'
Assert-True (@($catalog.fieldbus.channels).Count -eq 38) `
    'Digital I/O catalog must contain the 38 named channels.'
Assert-True (@($catalog.fieldbus.channels | Where-Object { $_.direction -eq 'DI' }).Count -eq 24) `
    'Digital I/O catalog must contain 24 named inputs.'
Assert-True (@($catalog.fieldbus.channels | Where-Object { $_.direction -eq 'DO' }).Count -eq 14) `
    'Digital I/O catalog must contain 14 named outputs.'

$missingChannelNodes = @($catalog.fieldbus.channels |
    Where-Object { -not $nodeKeys.ContainsKey([string]$_.nodeKey) } |
    ForEach-Object { [string]$_.nodeKey })
Assert-True ($missingChannelNodes.Count -eq 0) `
    ("I/O channels reference missing subscription nodes:`n - " + ($missingChannelNodes -join "`n - "))

foreach ($legacyBmk in @('_000B085A_LOW', '_000B085A_HIGH')) {
    $legacyChannel = @($catalog.fieldbus.channels |
        Where-Object { $_.bmk -eq $legacyBmk } |
        Select-Object -First 1)
    Assert-True (($legacyChannel.Count -eq 1) -and
        ($legacyChannel[0].wiringStatus -eq 'legacy/unwired')) `
        "$legacyBmk must remain visibly marked as legacy/unwired."
}

Assert-True (@($catalog.nodes | Where-Object { $_.category -eq 'station-data' }).Count -eq 13) `
    'Data page must contain the current 13 StationData leaves.'
Assert-True (@($catalog.nodes | Where-Object { $_.category -eq 'type-data' }).Count -eq 8) `
    'Data page must contain the current eight TypeData values.'
Assert-True (@($catalog.nodes | Where-Object {
        $_.identifier -eq 'plc/app/Application/sym/Station/EventList/PublicEventList'
    }).Count -eq 1) `
    'PublicEventList root subscription is missing.'
Assert-True (@($catalog.nodes | Where-Object {
        $_.identifier -like '*/Peripherals/_100A104/*'
    }).Count -eq 0) `
    'Kistler raw PDO data is not published and must not be represented by an invented NodeId.'
Assert-True (($catalog.nodes | Where-Object key -eq 'ConfiguredSlaves').dataType -eq 'UInt32') `
    'ConfiguredSlaves must match the current UDINT symbol type.'
Assert-True (($catalog.nodes | Where-Object key -eq 'DetectedSlaves').dataType -eq 'UInt32') `
    'DetectedSlaves must match the current UDINT symbol type.'
Assert-True (($catalog.nodes | Where-Object key -eq 'KistlerProgram').dataType -eq 'Byte') `
    'Kistler program number must match the current BYTE symbol type.'

$expectedUnitDetailNodes = @(
    'BursterUpperRange',
    'BursterLowerRange',
    'BursterUpperLimit',
    'BursterLowerLimit',
    'BursterReadTemperature',
    'BursterResistOk',
    'BursterOutOfLimit',
    'BursterResistance',
    'BursterTemperature',
    'KistlerProgramRequest',
    'KistlerMeasuringTimeout',
    'KistlerEndMeasurement',
    'KistlerScreenLocked',
    'KistlerReady',
    'KistlerSignal1',
    'KistlerSignal2',
    'KistlerNoPass',
    'KistlerWarning',
    'KistlerAlarm',
    'KistlerOk',
    'KistlerNok',
    'KistlerProgram',
    'KistlerForce',
    'KistlerStroke')
$missingUnitDetailNodes = @($expectedUnitDetailNodes |
    Where-Object { -not $nodeKeys.ContainsKey($_) })
Assert-True ($missingUnitDetailNodes.Count -eq 0) `
    ("Burster/Kistler Unit detail nodes are missing:`n - " + ($missingUnitDetailNodes -join "`n - "))
Assert-True (@($catalog.nodes | Where-Object { $_.category -eq 'device-data' }).Count -eq 24) `
    'Device data must contain the 24 Nexeed-visible Burster/Kistler parameter, status and result nodes.'

$expectedModes = @(1, 3, 4, 5)
Assert-True (@($catalog.modeControl.allowedModeIds).Count -eq 4) `
    'Mode allowlist must contain exactly four operator modes.'
Assert-True ((Compare-Object $expectedModes @($catalog.modeControl.allowedModeIds)).Count -eq 0) `
    'Mode allowlist must be exactly Automatic=1, Manual=3, Home=4, Changeover=5.'
Assert-True ($catalog.modeControl.panelToken -eq 1) `
    'The APQ/IPC single-HMI demonstration must use panel token 1.'
Assert-True ($catalog.modeControl.tokenRequestIdentifier -eq 'plc/app/Application/sym/Station/Extension/TokenRequest') `
    'Unexpected TokenRequest write target.'
Assert-True ($catalog.modeControl.modeIdRequestIdentifier -eq 'plc/app/Application/sym/Station/Extension/ModeIdRequest') `
    'Unexpected ModeIdRequest write target.'

$modeSourceText = [System.IO.File]::ReadAllText($modeControlSource)
Assert-True ($modeSourceText -match 'public\s+bool\s+SupportsStationCommands\s*=>\s*false\s*;') `
    'The real OPC UA adapter must keep Station Start/Stop/Step commands disabled.'
Assert-True ($modeSourceText -match 'public\s+bool\s+SupportsManualFunctions\s*=>\s*false\s*;') `
    'The real OPC UA adapter must keep Unit manual functions disabled.'
Assert-True ($modeSourceText -match 'WriteAllowlistedByteAsync') `
    'Semantic mode adapter is missing its private allowlisted write method.'
Assert-True ($modeSourceText -notmatch '(?i)BinIo|TokenChangeResponse|plc/app/[^\r\n''"]*/(?:Start|Stop|Step|Heartbeat)') `
    'Semantic mode adapter references a prohibited physical/manual/runtime command target.'
Assert-True ($modeSourceText -notmatch 'byte\.MaxValue') `
    'Single-panel mode requests must require exact panel-token readback, not token 255.'
Assert-True ($modeSourceText -match 'ReadCurrentValuesAsync') `
    'Mode prerequisites and readback must use fresh OPC UA Read requests.'
Assert-True ($modeSourceText -match '_modeRequestsEnabled') `
    'Real OPC UA sessions must have a separate mode-request enable gate.'
Assert-True ($modeSourceText -notmatch '"SafetyDoorCircuitOk"|"AllSafetyCircuitsOk"') `
    'HMI mode selection must not add safety-door/all-circuit prerequisites beyond PLC mode release.'
$stationCommandMethod = [regex]::Match(
    $modeSourceText,
    '(?s)public\s+Task<ControlRequestResult>\s+RequestStationCommandAsync\s*\(.*?\n\s*}\s*\n\s*public\s+Task<ControlRequestResult>\s+SetManualFunctionAsync')
Assert-True ($stationCommandMethod.Success) `
    'The real adapter Station command rejection method is missing.'
Assert-True ($stationCommandMethod.Value -notmatch '(?i)Write|CallAsync|NodeId|_session') `
    'The real Station command method must reject without touching the OPC UA session.'

$manualFunctionMethod = [regex]::Match(
    $modeSourceText,
    '(?s)public\s+Task<ControlRequestResult>\s+SetManualFunctionAsync\s*\(.*?\n\s*}\s*\n\s*public\s+async\s+Task\s+DisconnectAsync')
Assert-True ($manualFunctionMethod.Success) `
    'The real adapter manual-function rejection method is missing.'
Assert-True ($manualFunctionMethod.Value -notmatch '(?i)Write|CallAsync|NodeId|_session') `
    'The real Unit manual-function method must reject without touching the OPC UA session.'

$allowlistMethod = [regex]::Match(
    $modeSourceText,
    '(?s)private\s+async\s+Task\s+WriteAllowlistedByteAsync\s*\(.*?\n\s*}\s*\n\s*private\s+async')
Assert-True ($allowlistMethod.Success) 'The private OPC UA write allowlist method is missing.'
Assert-True ($allowlistMethod.Value -match 'TokenRequestIdentifier') `
    'TokenRequest must remain in the real write allowlist.'
Assert-True ($allowlistMethod.Value -match 'ModeIdRequestIdentifier') `
    'ModeIdRequest must remain in the real write allowlist.'
Assert-True ($allowlistMethod.Value -notmatch '(?i)EtherCAT|fieldbus|BinIo|Heartbeat|Exec[A-Z]|Start|Stop|Step') `
    'The real write allowlist must not include EtherCAT, Chain, heartbeat or Unit Exec targets.'

$allowlistedWriteReferences = [regex]::Matches(
    $modeSourceText,
    '\bWriteAllowlistedByteAsync\s*\(')
Assert-True ($allowlistedWriteReferences.Count -eq 3) `
    'The real adapter must have exactly two allowlisted write invocations plus the helper declaration.'
$semanticWrites = [regex]::Matches(
    $modeSourceText,
    '(?i)\.\s*(Write|WriteAsync|Call|CallAsync)\s*\(')
Assert-True ($semanticWrites.Count -eq 1) `
    'The semantic OPC UA adapter must contain exactly one guarded protocol write call.'

$mockSourceText = [System.IO.File]::ReadAllText($mockSourcePath)
Assert-True ($mockSourceText -match 'public\s+bool\s+SupportsStationCommands\s*=>\s*IsConnected\s*;') `
    'Offline DEMO must expose simulated Station Chain commands.'
Assert-True ($mockSourceText -match 'public\s+bool\s+SupportsManualFunctions\s*=>\s*IsConnected\s*;') `
    'Offline DEMO must expose simulated Unit manual functions.'
foreach ($command in @('Start', 'Stop', 'EnableStepMode', 'DisableStepMode', 'StepPulse')) {
    Assert-True ($mockSourceText -match "StationCommand\.$command") `
        "Offline DEMO is missing Station command simulation: $command"
}
Assert-True ($mockSourceText -match 'SetManualFunctionAsync') `
    'Offline DEMO is missing its simulated Unit manual-function handler.'

$windowText = [System.IO.File]::ReadAllText($windowPath)
Assert-True ($windowText -notmatch '<Setter\s+Property="IsHitTestVisible"\s+Value="False"') `
    'Operator mode buttons must remain clickable by mouse and touch.'
Assert-True ($windowText -notmatch 'READ ONLY /') `
    'The HMI header must not claim read-only operation after mode requests are enabled.'
Assert-True ($windowText -match 'x:Name="ModeSidebar"') `
    'Automatic, Manual, Homing and Change-over require a dedicated mode sidebar.'
Assert-True ($windowText -match 'x:Name="PrimaryTopNavigation"') `
    'Overview, Events, I/O and Data require a dedicated top navigation bar.'
Assert-True ($windowText -notmatch 'AutomationProperties\.Name="Navigate Manual"') `
    'Manual must be the Manual-mode Overview, not a fifth primary page.'
foreach ($automationName in @(
        'Navigate Overview',
        'Navigate Events',
        'Navigate IO',
        'Navigate Data',
        'Switch to Automatic mode',
        'Switch to Manual mode',
        'Switch to Homing mode',
        'Switch to Change-over mode',
        'Start active mode Chain',
        'Stop active mode Chain',
        'Toggle automatic step mode',
        'Advance one automatic step',
        'Manual Unit tree',
        'EtherCAT hierarchical topology')) {
    $expectedAutomation = 'AutomationProperties.Name="{0}"' -f $automationName
    Assert-True ($windowText -match [regex]::Escape($expectedAutomation)) `
        "The operator UI is missing its automation surface: $automationName"
}
Assert-True ($windowText -match 'ItemsSource="{Binding EtherCatTopology}"') `
    'The I/O page must render the hierarchical EtherCAT topology, not only a flat slave grid.'
Assert-True ($windowText -match 'ItemsSource="{Binding ManualUnits}"') `
    'The Manual page must render the CpStudio Unit list.'
Assert-True ($windowText -match 'Click="OnManualFunctionClick"') `
    'The Manual page is missing its semantic Unit-function DEMO handler.'
Assert-True ($windowText -match 'Selected Unit parameters and live values') `
    'The Manual page is missing its device-specific parameter/status/result panel.'

$connectionDialogText = [System.IO.File]::ReadAllText($connectionDialogPath)
Assert-True ($connectionDialogText -match 'x:Name="EnableModeRequestsInput"') `
    'Real connections need an explicit session-only mode-request checkbox.'
Assert-True ($connectionDialogText -match 'EnableModeRequestsInput[\s\S]*?IsChecked="False"') `
    'Real connections must default to read-only mode requests disabled.'

$viewModelText = [System.IO.File]::ReadAllText($viewModelPath)
Assert-True ($viewModelText -match '_badNodes\.Count\s*>\s*0') `
    'Bad OPC UA quality must mask old live values.'

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
    # Build into an isolated temporary output so the check remains usable while an
    # operator has the normal Release DEMO executable open for visual comparison.
    $isolatedBuildOutput = Join-Path (
        [System.IO.Path]::GetTempPath()) (
        'Bpp.ResistantStation.Hmi.contract-{0}-{1}' -f $PID, [guid]::NewGuid().ToString('N'))
    try {
        & dotnet build $projectPath --no-restore --configuration Release --output $isolatedBuildOutput
        Assert-True ($LASTEXITCODE -eq 0) 'The self-developed HMI did not build successfully.'
    }
    finally {
        if (Test-Path -LiteralPath $isolatedBuildOutput -PathType Container) {
            [System.IO.Directory]::Delete($isolatedBuildOutput, $true)
        }
    }
}

Write-Host ("HMI contract OK: {0} read-only nodes; mode writes limited to TokenRequest and ModeIdRequest." -f @($catalog.nodes).Count)
