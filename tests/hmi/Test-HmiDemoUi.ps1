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

    $modeDeadline = [DateTime]::UtcNow.AddSeconds(10)
    $automatic = $null
    do {
        $automatic = Find-ByName 'Switch to Automatic mode'
        if (($null -ne $automatic) -and $automatic.Current.IsEnabled) {
            break
        }

        Start-Sleep -Milliseconds 100
    } until ([DateTime]::UtcNow -ge $modeDeadline)

    if (($null -eq $automatic) -or (-not $automatic.Current.IsEnabled)) {
        throw 'The Automatic operator mode button is missing or disabled in demo mode.'
    }
    $automatic.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()

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

    foreach ($navigationName in @('Navigate IO', 'Navigate Data')) {
        $button = Find-ByName $navigationName
        if ($null -eq $button) {
            throw "Missing navigation button: $navigationName"
        }
        $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    }

    foreach ($tabPrefix in @('StationData /', 'TypeData /')) {
        if ($null -eq (Find-ByNamePrefix $tabPrefix)) {
            throw "Missing data tab prefix: $tabPrefix"
        }
    }

    Write-Host 'HMI demo UI OK: operator mode request and Events/I-O/Data navigation are reachable.'
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
