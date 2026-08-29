[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot '..\..')).Path
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$hmiProjectRoot = Join-Path $ProjectRoot 'src\hmi\Bpp.ResistantStation.Hmi'
$projectPath = Join-Path $hmiProjectRoot 'Bpp.ResistantStation.Hmi.csproj'
$appPath = Join-Path $hmiProjectRoot 'App.xaml.cs'
$mainWindowPath = Join-Path $hmiProjectRoot 'MainWindow.xaml'
$viewModelPath = Join-Path $hmiProjectRoot 'ViewModels\MainViewModel.cs'
$settingsPath = Join-Path $hmiProjectRoot 'Configuration\HmiSettings.cs'
$mockSourcePath = Join-Path $hmiProjectRoot 'Services\MockStationDataSource.cs'
$realSourcePath = Join-Path $hmiProjectRoot 'Services\OpcUaReadOnlyDataSource.cs'
$projectText = [System.IO.File]::ReadAllText($projectPath)
$appText = [System.IO.File]::ReadAllText($appPath)
$mainWindowText = [System.IO.File]::ReadAllText($mainWindowPath)
$viewModelText = [System.IO.File]::ReadAllText($viewModelPath)
$settingsText = [System.IO.File]::ReadAllText($settingsPath)
$mockSourceText = [System.IO.File]::ReadAllText($mockSourcePath)
$realSourceText = [System.IO.File]::ReadAllText($realSourcePath)
$configPaths = @(
    (Join-Path $hmiProjectRoot 'Configuration\station010.hmi.json'),
    (Join-Path $hmiProjectRoot 'Configuration\example-cell.hmi.json'))

Assert-True ($appText -match '--config') 'The HMI executable is missing the --config entry point.'
Assert-True ($projectText -match 'Configuration\\\*\.hmi\.json') 'The build must copy every project-pack HMI configuration.'
Assert-True ($viewModelText -notmatch 'SelectedNodeIsKistler|Slave\.Index:\s*9') 'Fieldbus rendering still depends on the Station010 Kistler slave index.'
Assert-True ($viewModelText -notmatch 'SqC_Wp100|SqS_Station_ChangeOverFile') 'Visible mode/Chain labels must come from configuration, not Station010 source code.'
Assert-True ($viewModelText -match 'CreateManualUnits\(HmiSettings settings\)') 'Manual Units must be constructed from the selected HMI configuration.'
Assert-True ($mainWindowText -notmatch 'Station010|Wp100|Kistler|Burster|A740|A741|A742|A743') 'The reusable HMI shell contains Station010-specific visible text.'
Assert-True ($settingsText -match 'Fieldbus slave indexes must be contiguous and start at 1') 'Fieldbus validation must enforce the array-compatible 1..N slave indexes.'
Assert-True ($settingsText -match 'belongs to a cyclic parent chain') 'Fieldbus validation must reject self/cyclic parent relationships.'
Assert-True ($settingsText -match 'Fieldbus channel node keys') 'Fieldbus validation must reject duplicate channel node keys.'
Assert-True ($settingsText -match 'UnmappedMemberHandling\s*=\s*JsonUnmappedMemberHandling\.Disallow') 'Unknown HMI configuration fields must fail closed.'
$modeSettingsText = $settingsText.Substring($settingsText.IndexOf('public sealed class ModeControlSettings', [System.StringComparison]::Ordinal))
Assert-True ($modeSettingsText -match '(?m)^\s*public bool Enabled \{ get; init; \}\s*$') 'Real mode control must default to disabled.'
Assert-True ($settingsText -match 'RequestTimeoutMs must be between 250 and 60000 ms') 'Mode request timeout must be bounded.'
Assert-True ($mockSourceText -match '_autoInfoIndexes') 'The DEMO AutoInfoLine must be derived from the selected configuration.'
Assert-True ($mockSourceText -notmatch '0\s*=>\s*4|1\s*=>\s*10|2\s*=>\s*12|_\s*=>\s*16') 'The reusable DEMO still contains a Station010 AutoInfoLine sequence.'
Assert-True ($mockSourceText -match '_modeRequestsEnabled\s*=\s*options\.EnableModeRequests') 'DEMO mode switching must remain available for project-pack UI tests.'
Assert-True ($realSourceText -match '_modeRequestsEnabled\s*=\s*settings\.ModeControl\.Enabled\s*&&\s*options\.EnableModeRequests') 'Real OPC mode writes must remain behind both configuration and session gates.'

foreach ($configPath in $configPaths) {
    Assert-True (Test-Path -LiteralPath $configPath -PathType Leaf) "Missing HMI configuration: $configPath"
    $config = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
    Assert-True ($config.schemaVersion -eq 2) "Unexpected schemaVersion in $configPath"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$config.brand.productName)) "Brand productName is missing in $configPath"
    Assert-True (@($config.overviewCards).Count -gt 0) "Overview cards are missing in $configPath"
    Assert-True (@($config.modeControl.modes).Count -eq 4) "The four OpCon operator modes must be described in $configPath"

    $nodeKeys = @{}
    foreach ($node in @($config.nodes)) {
        Assert-True (-not $nodeKeys.ContainsKey([string]$node.key)) "Duplicate node key '$($node.key)' in $configPath"
        $nodeKeys[[string]$node.key] = $true
    }

    foreach ($card in @($config.overviewCards)) {
        Assert-True ($nodeKeys.ContainsKey([string]$card.nodeKey)) "Overview card '$($card.key)' has a dangling nodeKey in $configPath"
    }

    foreach ($unit in @($config.manualUnits)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$unit.stateNodeKey)) {
            Assert-True ($nodeKeys.ContainsKey([string]$unit.stateNodeKey)) "Manual Unit '$($unit.key)' has a dangling stateNodeKey in $configPath"
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$unit.secondaryStateNodeKey)) {
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$unit.stateNodeKey)) "Manual Unit '$($unit.key)' has a secondary state without a primary state."
            Assert-True ($nodeKeys.ContainsKey([string]$unit.secondaryStateNodeKey)) "Manual Unit '$($unit.key)' has a dangling secondaryStateNodeKey in $configPath"
        }
        foreach ($action in @($unit.actions)) {
            Assert-True ($nodeKeys.ContainsKey([string]$action.releaseNodeKey)) "Manual action '$($unit.key).$($action.key)' has a dangling releaseNodeKey."
            Assert-True ($nodeKeys.ContainsKey([string]$action.runningNodeKey)) "Manual action '$($unit.key).$($action.key)' has a dangling runningNodeKey."
        }
        foreach ($field in @($unit.fields | Where-Object { $null -ne $_ })) {
            Assert-True ($nodeKeys.ContainsKey([string]$field.nodeKey)) "Manual Unit '$($unit.key)' has a dangling field nodeKey."
        }
    }

    $slaves = @($config.fieldbus.slaves)
    $expectedIndexes = @(1..$slaves.Count)
    $actualIndexes = @($slaves | ForEach-Object { [int]$_.index } | Sort-Object)
    Assert-True ((Compare-Object $expectedIndexes $actualIndexes).Count -eq 0) "Fieldbus slave indexes are not contiguous 1..N in $configPath"
    foreach ($slave in $slaves) {
        Assert-True (@('coupler', 'module', 'device').Contains([string]$slave.role)) "Fieldbus slave '$($slave.index)' has no supported role in $configPath"
    }
    $channelNodeKeys = @($config.fieldbus.channels | ForEach-Object { [string]$_.nodeKey })
    Assert-True (@($channelNodeKeys | Sort-Object -Unique).Count -eq $channelNodeKeys.Count) "Fieldbus channel node keys are not unique in $configPath"
    foreach ($channel in @($config.fieldbus.channels)) {
        Assert-True ($nodeKeys.ContainsKey([string]$channel.nodeKey)) "Fieldbus channel '$($channel.slaveIndex)/$($channel.channel)' has a dangling nodeKey."
    }
}

$stationConfig = [System.IO.File]::ReadAllText($configPaths[0]) | ConvertFrom-Json
$semanticSlave = @($stationConfig.fieldbus.slaves |
    Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.deviceDataGroup) } |
    Select-Object -First 1)
Assert-True ($semanticSlave.Count -eq 1) 'Station010 must identify its semantic EtherCAT device by configuration.'
$semanticPrefix = [string]$semanticSlave[0].deviceDataGroup
$semanticRows = @($stationConfig.nodes | Where-Object {
        ($_.category -eq 'device-data') -and
        (($_.group -eq $semanticPrefix) -or
         ([string]$_.group).StartsWith("$semanticPrefix -", [System.StringComparison]::Ordinal))
    })
Assert-True ($semanticRows.Count -gt 0) 'The configured semantic fieldbus device does not resolve any device-data rows.'

$overviewNodeKeys = @($stationConfig.overviewCards | ForEach-Object { [string]$_.nodeKey })
foreach ($expectedOverviewNode in @(
        'FixtureLeft',
        'FixtureMiddle',
        'FixtureRight',
        'ProductSensorA',
        'ProductSensorB',
        'EmergencyCircuitOk',
        'MaintenanceCircuitOk',
        'SafetyDoorCircuitOk',
        'AllSafetyCircuitsOk')) {
    Assert-True ($overviewNodeKeys -contains $expectedOverviewNode) "Station010 Overview is missing diagnostic signal: $expectedOverviewNode"
}

foreach ($unitKey in @('Wp100K101SafetyDoor', 'Wp100K102PressingCylinder')) {
    $unit = @($stationConfig.manualUnits | Where-Object key -eq $unitKey | Select-Object -First 1)
    Assert-True ($unit.Count -eq 1) "Station010 manual Unit is missing: $unitKey"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$unit[0].secondaryStateNodeKey)) "$unitKey must use both configured position signals."
    foreach ($stateKey in @('10', '01', '00', '11')) {
        Assert-True ($null -ne $unit[0].stateValueMap.$stateKey) "$unitKey has no configured display for input state $stateKey."
    }
}

$exampleText = [System.IO.File]::ReadAllText($configPaths[1])
Assert-True ($exampleText -notmatch 'Station010|Wp100|Kistler|Burster') 'ExampleCell leaks Station010-specific names.'
$exampleConfig = $exampleText | ConvertFrom-Json
Assert-True (-not [bool]$exampleConfig.modeControl.enabled) 'ExampleCell must keep real mode writes disabled by default.'

if (-not $SkipBuild) {
    $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        'generic-hmi-contract-{0}-{1}' -f $PID, [guid]::NewGuid().ToString('N'))
    try {
        & dotnet build $projectPath --no-restore --configuration Release --output $outputRoot
        Assert-True ($LASTEXITCODE -eq 0) 'The generic HMI Release build failed.'
        $exePath = Join-Path $outputRoot 'Bpp.ResistantStation.Hmi.exe'
        foreach ($configPath in $configPaths) {
            $process = Start-Process -FilePath $exePath -ArgumentList @('--validate-config', '--config', $configPath) -PassThru -Wait
            Assert-True ($process.ExitCode -eq 0) "The HMI rejected configuration: $configPath"
        }

        $invalidConfig = [System.IO.File]::ReadAllText($configPaths[1]) | ConvertFrom-Json
        $invalidConfig.modeControl | Add-Member -NotePropertyName 'enabld' -NotePropertyValue $true
        $invalidConfigPath = Join-Path $outputRoot 'unknown-field.hmi.json'
        [System.IO.File]::WriteAllText(
            $invalidConfigPath,
            (($invalidConfig | ConvertTo-Json -Depth 64) + [Environment]::NewLine),
            [System.Text.UTF8Encoding]::new($false))
        $invalidProcess = Start-Process -FilePath $exePath -ArgumentList @('--validate-config', '--config', $invalidConfigPath) -PassThru -Wait
        Assert-True ($invalidProcess.ExitCode -ne 0) 'The HMI accepted an unknown mode-control field.'

        $invalidConfig.modeControl.PSObject.Properties.Remove('enabld')
        $invalidConfig.modeControl.requestTimeoutMs = 0
        [System.IO.File]::WriteAllText(
            $invalidConfigPath,
            (($invalidConfig | ConvertTo-Json -Depth 64) + [Environment]::NewLine),
            [System.Text.UTF8Encoding]::new($false))
        $invalidProcess = Start-Process -FilePath $exePath -ArgumentList @('--validate-config', '--config', $invalidConfigPath) -PassThru -Wait
        Assert-True ($invalidProcess.ExitCode -ne 0) 'The HMI accepted an unsafe mode request timeout.'

        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
        $demoProcess = Start-Process -FilePath $exePath -ArgumentList @('--demo', '--config', $configPaths[1]) -PassThru
        try {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                Start-Sleep -Milliseconds 100
                $demoProcess.Refresh()
            } until (($demoProcess.MainWindowHandle -ne 0) -or ([DateTime]::UtcNow -ge $deadline))
            Assert-True ($demoProcess.MainWindowHandle -ne 0) 'The ExampleCell DEMO window did not open.'

            $window = [System.Windows.Automation.AutomationElement]::FromHandle($demoProcess.MainWindowHandle)
            function Find-ExampleElementByName {
                param([string]$Name)
                $condition = [System.Windows.Automation.PropertyCondition]::new(
                    [System.Windows.Automation.AutomationElement]::NameProperty,
                    $Name)
                return $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            }

            function Wait-ExampleElementByName {
                param([string]$Name, [bool]$Enabled = $false, [int]$TimeoutSeconds = 8)
                $waitDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
                do {
                    $element = Find-ExampleElementByName $Name
                    if (($null -ne $element) -and ((-not $Enabled) -or $element.Current.IsEnabled)) {
                        return $element
                    }
                    Start-Sleep -Milliseconds 75
                } until ([DateTime]::UtcNow -ge $waitDeadline)
                throw "Timed out waiting for ExampleCell UI element: $Name"
            }

            function Wait-ExampleElementContaining {
                param([string]$Fragment, [int]$TimeoutSeconds = 8)
                $waitDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
                do {
                    $elements = $window.FindAll(
                        [System.Windows.Automation.TreeScope]::Descendants,
                        [System.Windows.Automation.Condition]::TrueCondition)
                    $match = $elements |
                        Where-Object { $_.Current.Name.IndexOf($Fragment, [System.StringComparison]::Ordinal) -ge 0 } |
                        Select-Object -First 1
                    if ($null -ne $match) {
                        return $match
                    }
                    Start-Sleep -Milliseconds 75
                } until ([DateTime]::UtcNow -ge $waitDeadline)
                throw "Timed out waiting for ExampleCell UI text containing: $Fragment"
            }

            $manualButton = Wait-ExampleElementByName -Name 'Switch to Manual mode' -Enabled $true
            $manualButton.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            $null = Wait-ExampleElementByName -Name 'Manual Unit tree'
            $null = Wait-ExampleElementContaining -Fragment 'Fixture clamp'
        }
        finally {
            if (($null -ne $demoProcess) -and (-not $demoProcess.HasExited)) {
                try {
                    $demoWindow = [System.Windows.Automation.AutomationElement]::FromHandle($demoProcess.MainWindowHandle)
                    if ($null -ne $demoWindow) {
                        $demoWindow.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern).Close()
                        $demoProcess.WaitForExit(3000) | Out-Null
                    }
                }
                catch {
                    # The process may close between the UI Automation calls.
                }
            }
            if (($null -ne $demoProcess) -and (-not $demoProcess.HasExited)) {
                Stop-Process -Id $demoProcess.Id
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $outputRoot -PathType Container) {
            [System.IO.Directory]::Delete($outputRoot, $true)
        }
    }
}

Write-Host 'Generic HMI configuration OK: both configs load; ExampleCell DEMO switches to Manual and shows Fixture clamp.'
