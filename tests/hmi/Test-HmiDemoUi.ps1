[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot '..\..')).Path
}

$exePath = Join-Path $ProjectRoot 'src\hmi\Bpp.ResistantStation.Hmi\bin\Release\net8.0-windows\Bpp.ResistantStation.Hmi.exe'
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw "Build the Release HMI before running the UI smoke test: $exePath"
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$process = Start-Process -FilePath $exePath -ArgumentList '--demo' -PassThru
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    } until (($process.MainWindowHandle -ne 0) -or ([DateTime]::UtcNow -ge $deadline))

    if ($process.MainWindowHandle -eq 0) {
        throw 'The HMI demo window did not open.'
    }

    $window = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
    function Find-ByName {
        param([string]$Name)
        $condition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::NameProperty,
            $Name)
        return $window.FindFirst(
            [System.Windows.Automation.TreeScope]::Descendants,
            $condition)
    }

    function Find-ByNamePrefix {
        param([string]$Prefix)
        $elements = $window.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition)
        return $elements |
            Where-Object { $_.Current.Name.StartsWith($Prefix, [System.StringComparison]::Ordinal) } |
            Select-Object -First 1
    }

    function Find-ByNameContains {
        param([string]$Fragment)
        $elements = $window.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition)
        return $elements |
            Where-Object {
                $_.Current.Name.IndexOf($Fragment, [System.StringComparison]::Ordinal) -ge 0
            } |
            Select-Object -First 1
    }

    function Wait-ByName {
        param(
            [string]$Name,
            [object]$Enabled = $null,
            [int]$TimeoutSeconds = 5
        )

        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        do {
            $element = Find-ByName $Name
            if (($null -ne $element) -and
                (($null -eq $Enabled) -or ($element.Current.IsEnabled -eq [bool]$Enabled))) {
                return $element
            }

            Start-Sleep -Milliseconds 75
        } until ([DateTime]::UtcNow -ge $deadline)

        $state = if ($null -eq $Enabled) { 'present' } elseif ($Enabled) { 'enabled' } else { 'disabled' }
        throw "Timed out waiting for '$Name' to become $state."
    }

    function Invoke-ByName {
        param(
            [string]$Name,
            [int]$TimeoutSeconds = 5
        )

        $element = Wait-ByName -Name $Name -Enabled $true -TimeoutSeconds $TimeoutSeconds
        $element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    }

    function Test-ChainStartStop {
        param([string]$ModeAutomationName)

        Invoke-ByName $ModeAutomationName
        Invoke-ByName 'Start active mode Chain'
        $null = Wait-ByName -Name 'Stop active mode Chain' -Enabled $true
        Invoke-ByName 'Stop active mode Chain'
        $null = Wait-ByName -Name 'Start active mode Chain' -Enabled $true
    }

    # Automatic Chain supports Start/Stop and the separate step-mode/step-pulse controls.
    Invoke-ByName -Name 'Switch to Automatic mode' -TimeoutSeconds 10
    Invoke-ByName 'Start active mode Chain'
    $null = Wait-ByName -Name 'Stop active mode Chain' -Enabled $true
    Invoke-ByName 'Toggle automatic step mode'
    $null = Wait-ByName -Name 'Advance one automatic step' -Enabled $true
    Invoke-ByName 'Advance one automatic step'
    Invoke-ByName 'Stop active mode Chain'
    $null = Wait-ByName -Name 'Start active mode Chain' -Enabled $true

    # Homing and Change-over use the same semantic active-Chain command surface.
    Test-ChainStartStop 'Switch to Homing mode'
    Test-ChainStartStop 'Switch to Change-over mode'

    # Manual mode exposes CpStudio Unit/function structure in DEMO only.
    Invoke-ByName 'Switch to Manual mode'
    Invoke-ByName 'Navigate Manual'
    $null = Wait-ByName -Name 'Manual Unit tree'
    if ($null -eq (Find-ByNameContains 'Safety door')) {
        throw 'The Manual Unit tree does not expose the safety-door Unit.'
    }
    if ($null -eq (Find-ByNameContains 'Kistler maXYmos 5867C')) {
        throw 'The Manual Unit tree does not expose the Kistler Unit.'
    }

    $manualAction = Find-ByNameContains 'Move to base position'
    if (($null -eq $manualAction) -or (-not $manualAction.Current.IsEnabled)) {
        throw 'The selected safety-door manual action is missing or not released in DEMO.'
    }
    $manualAction.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    $manualActionName = $manualAction.Current.Name
    # WPF UI Automation may return from Invoke only after the short 750 ms DEMO
    # press has released; verify that the semantic action completes and is usable again.
    $null = Wait-ByName -Name $manualActionName -Enabled $true -TimeoutSeconds 3

    $eventsButton = Find-ByName 'Navigate Events'
    if ($null -eq $eventsButton) {
        throw 'Missing navigation button: Navigate Events'
    }
    $eventsButton.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()

    $eventDeadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        $activeDemoEvent = Find-ByNameContains 'Event 60'
        if ($null -ne $activeDemoEvent) {
            break
        }
        Start-Sleep -Milliseconds 100
    } until ([DateTime]::UtcNow -ge $eventDeadline)
    if ($null -eq $activeDemoEvent) {
        throw 'The decoded active demo event is not visible.'
    }
    if ($null -ne (Find-ByNameContains 'Event 61')) {
        throw 'A cleared demo event was incorrectly displayed as active.'
    }

    Invoke-ByName 'Navigate IO'
    $null = Wait-ByName -Name 'EtherCAT hierarchical topology'
    foreach ($topologyName in @(
            'EtherCAT Master',
            'EK1100',
            'Kistler force/displacement monitor')) {
        if ($null -eq (Find-ByNameContains $topologyName)) {
            throw "Missing EtherCAT topology node: $topologyName"
        }
    }

    Invoke-ByName 'Navigate Data'

    foreach ($tabPrefix in @('StationData /', 'TypeData /')) {
        if ($null -eq (Find-ByNamePrefix $tabPrefix)) {
            throw "Missing data tab prefix: $tabPrefix"
        }
    }

    Write-Host 'HMI demo UI OK: Automatic/Homing/Change-over Chain controls, automatic step mode, Unit manual DEMO, hierarchical EtherCAT topology and Events/Data are reachable.'
}
finally {
    if (-not $process.HasExited) {
        $window = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
        if ($null -ne $window) {
            $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern).Close()
            $process.WaitForExit(3000) | Out-Null
        }
    }

    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id
    }
}
