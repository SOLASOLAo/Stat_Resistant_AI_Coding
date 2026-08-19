[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$EsiPath,

    [Parameter(Mandatory = $true)]
    [string]$SearchTerm,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedName,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedVendor,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedDeviceId,

    [string]$ExpectedVersion,

    [string]$IoeExecutable = 'C:\ctrlXWORKS\ctrlXIOEngineering\IOE_V_0206\Studio\Common\ctrlX-IO-Engineering.exe',

    [string]$WatcherTemplate = "$env:APPDATA\npm\node_modules\codesys-mcp-persistent\dist\scripts\watcher.py",

    [ValidateRange(30, 300)]
    [int]$StartupTimeoutSeconds = 100,

    [ValidateRange(30, 300)]
    [int]$RepositoryTimeoutSeconds = 120,

    [switch]$KeepIoeOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$etherCatConverterGuid = '3992C588-7BDB-4A7C-908D-F444808D8CD2'
$ipcHelper = Join-Path $PSScriptRoot 'ioe_ipc.ps1'
$sessionPrefix = 'ioe-esi-'
$sessionSucceeded = $false
$ioeProcess = $null

function ConvertTo-PythonStringLiteral {
    param([Parameter(Mandatory = $true)][string]$Value)

    # A JSON string is also a valid Python string literal and safely preserves
    # spaces, backslashes and non-ASCII paths.
    return ($Value | ConvertTo-Json -Compress)
}

function Invoke-CheckedIoeScript {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [int]$TimeoutMs = 120000
    )

    $result = Invoke-IoeScript -code $Code -timeoutMs $TimeoutMs
    if (-not $result.success) {
        throw "IO Engineering script failed: $($result.error)`n$($result.output)"
    }
    return $result
}

function Get-IoeRepositoryDevices {
    param([Parameter(Mandatory = $true)][string]$NameFilter)

    $filterLiteral = ConvertTo-PythonStringLiteral $NameFilter
    $code = @"
import json
import scriptengine as se
source = se.device_repository.sources[0]
devices = se.device_repository.get_all_devices(name=$filterLiteral, source=source)
for device in devices:
    info = device.device_info
    device_id = device.device_id
    payload = {
        "name": info.name,
        "vendor": info.vendor,
        "type": device_id.type,
        "id": device_id.id,
        "version": device_id.version,
        "description": info.description,
        "order_number": info.order_number
    }
    print("DEVICE_JSON|" + json.dumps(payload))
print("SCRIPT_SUCCESS")
"@

    $result = Invoke-CheckedIoeScript -Code $code -TimeoutMs ($RepositoryTimeoutSeconds * 1000)
    $devices = @()
    foreach ($line in ($result.output -split "`r?`n")) {
        if ($line.StartsWith('DEVICE_JSON|', [System.StringComparison]::Ordinal)) {
            $devices += ($line.Substring('DEVICE_JSON|'.Length) | ConvertFrom-Json)
        }
    }
    return $devices
}

function Test-ExpectedDevice {
    param([Parameter(Mandatory = $true)]$Device)

    if ($Device.name -ne $ExpectedName -or
        $Device.vendor -ne $ExpectedVendor -or
        $Device.id -ne $ExpectedDeviceId) {
        return $false
    }
    if ($ExpectedVersion -and $Device.version -ne $ExpectedVersion) {
        return $false
    }
    return $true
}

function Wait-IoeRepositoryReady {
    $deadline = [DateTime]::UtcNow.AddSeconds($RepositoryTimeoutSeconds)
    do {
        $code = @'
import scriptengine as se
print("BACKGROUND_READY|%s" % se.system.background_loading_of_libraries_finished)
print("SCRIPT_SUCCESS")
'@
        $result = Invoke-CheckedIoeScript -Code $code -TimeoutMs 15000
        if ($result.output -match 'BACKGROUND_READY\|True') {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "IO Engineering device repository did not finish loading within $RepositoryTimeoutSeconds seconds."
}

$resolvedEsiPath = [System.IO.Path]::GetFullPath($EsiPath)
if (-not [System.IO.File]::Exists($resolvedEsiPath)) {
    throw "ESI file not found: $resolvedEsiPath"
}
if ([System.IO.Path]::GetExtension($resolvedEsiPath) -ne '.xml') {
    throw "EtherCAT ESI must be an XML file: $resolvedEsiPath"
}
foreach ($requiredFile in @($IoeExecutable, $WatcherTemplate, $ipcHelper)) {
    if (-not [System.IO.File]::Exists($requiredFile)) {
        throw "Required file not found: $requiredFile"
    }
}

$existingIoe = @(Get-Process -Name 'ctrlX-IO-Engineering' -ErrorAction SilentlyContinue)
if ($existingIoe.Count -gt 0) {
    $ids = ($existingIoe.Id -join ', ')
    throw "ctrlX IO Engineering is already running (PID: $ids). Close it before installing an ESI so this script does not start a competing profile instance."
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$sessionName = $sessionPrefix + [guid]::NewGuid().ToString('N')
$sessionDirectory = [System.IO.Path]::GetFullPath((Join-Path $tempRoot $sessionName))
if (-not $sessionDirectory.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not ([System.IO.Path]::GetFileName($sessionDirectory)).StartsWith($sessionPrefix, [System.StringComparison]::Ordinal)) {
    throw "Unsafe IOE session path: $sessionDirectory"
}

[System.IO.Directory]::CreateDirectory($sessionDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $sessionDirectory 'commands')) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $sessionDirectory 'results')) | Out-Null

$watcherPath = Join-Path $sessionDirectory 'watcher.py'
$watcherText = [System.IO.File]::ReadAllText($WatcherTemplate)
$escapedSessionDirectory = $sessionDirectory.Replace('\', '\\')
$watcherText = $watcherText.Replace('{IPC_BASE_DIR}', $escapedSessionDirectory)
[System.IO.File]::WriteAllText($watcherPath, $watcherText, (New-Object System.Text.UTF8Encoding $false))

try {
    $launcher = Start-Process `
        -FilePath $IoeExecutable `
        -ArgumentList ('--runscript="' + $watcherPath + '"') `
        -WorkingDirectory (Split-Path -Parent $IoeExecutable) `
        -WindowStyle Hidden `
        -PassThru

    $readyPath = Join-Path $sessionDirectory 'ready.signal'
    $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline -and -not [System.IO.File]::Exists($readyPath)) {
        Start-Sleep -Milliseconds 250
    }
    if (-not [System.IO.File]::Exists($readyPath)) {
        $errorPath = Join-Path $sessionDirectory 'watcher_error.txt'
        $watcherError = if ([System.IO.File]::Exists($errorPath)) {
            [System.IO.File]::ReadAllText($errorPath)
        }
        else {
            ''
        }
        throw "IO Engineering watcher did not become ready within $StartupTimeoutSeconds seconds. Launcher PID=$($launcher.Id). $watcherError"
    }

    $ready = [System.IO.File]::ReadAllText($readyPath) | ConvertFrom-Json
    $ioeProcess = Get-Process -Id ([int]$ready.pid) -ErrorAction Stop
    if ($ioeProcess.ProcessName -ne 'ctrlX-IO-Engineering') {
        throw "Watcher PID $($ready.pid) belongs to '$($ioeProcess.ProcessName)', not ctrlX IO Engineering."
    }

    . $ipcHelper
    $script:IOE_IPC_DIR = $sessionDirectory
    Wait-IoeRepositoryReady

    $before = @(Get-IoeRepositoryDevices -NameFilter $SearchTerm)
    $alreadyInstalled = @($before | Where-Object { Test-ExpectedDevice $_ })
    if ($alreadyInstalled.Count -gt 0) {
        Write-Output "EtherCAT ESI already installed and verified."
        $alreadyInstalled | Select-Object name, vendor, type, id, version, order_number
        $sessionSucceeded = $true
        return
    }

    if (-not $PSCmdlet.ShouldProcess($resolvedEsiPath, 'Import EtherCAT ESI into ctrlX IO Engineering System Repository')) {
        Write-Output 'ESI import skipped by WhatIf/Confirm.'
        $sessionSucceeded = $true
        return
    }

    $pathLiteral = ConvertTo-PythonStringLiteral $resolvedEsiPath
    $converterLiteral = ConvertTo-PythonStringLiteral $etherCatConverterGuid
    $importCode = @"
import json
import scriptengine as se
from System import Guid
source = se.device_repository.sources[0]
device_id = se.device_repository.import_device(
    path=$pathLiteral,
    source=source,
    converter_factory_guid=Guid($converterLiteral),
    save_device_cache=True)
device = se.device_repository.get_device(device_id)
if device is None:
    raise Exception("Imported DeviceId cannot be resolved from repository")
info = device.device_info
payload = {
    "name": info.name,
    "vendor": info.vendor,
    "type": device_id.type,
    "id": device_id.id,
    "version": device_id.version,
    "description": info.description,
    "order_number": info.order_number
}
print("IMPORTED_JSON|" + json.dumps(payload))
print("SCRIPT_SUCCESS")
"@
    $importResult = Invoke-CheckedIoeScript -Code $importCode -TimeoutMs ($RepositoryTimeoutSeconds * 1000)
    Write-Verbose $importResult.output

    $after = @(Get-IoeRepositoryDevices -NameFilter $SearchTerm)
    $verified = @($after | Where-Object { Test-ExpectedDevice $_ })
    if ($verified.Count -ne 1) {
        throw "ESI import completed, but expected exactly one '$ExpectedName' / '$ExpectedVendor' / '$ExpectedDeviceId' repository entry; found $($verified.Count)."
    }

    Write-Output "EtherCAT ESI imported and verified."
    $verified | Select-Object name, vendor, type, id, version, order_number
    $sessionSucceeded = $true
}
finally {
    if ($ioeProcess -and -not $KeepIoeOpen) {
        $terminatePath = Join-Path $sessionDirectory 'terminate.signal'
        [System.IO.File]::WriteAllText($terminatePath, 'terminate', (New-Object System.Text.UTF8Encoding $false))
        Start-Sleep -Milliseconds 300
        $ioeProcess.Refresh()
        if (-not $ioeProcess.HasExited) {
            $closeRequested = $ioeProcess.CloseMainWindow()
            if ($closeRequested) {
                $ioeProcess.WaitForExit(15000) | Out-Null
            }
        }
        $ioeProcess.Refresh()
        if (-not $ioeProcess.HasExited) {
            Write-Warning "The helper IO Engineering process is still running (PID $($ioeProcess.Id)); close it manually. Session: $sessionDirectory"
        }
    }

    $canDeleteSession = $sessionSucceeded -and -not $KeepIoeOpen
    if ($canDeleteSession -and (-not $ioeProcess -or $ioeProcess.HasExited)) {
        $resolvedSession = [System.IO.Path]::GetFullPath($sessionDirectory)
        if ($resolvedSession.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
            ([System.IO.Path]::GetFileName($resolvedSession)).StartsWith($sessionPrefix, [System.StringComparison]::Ordinal)) {
            [System.IO.Directory]::Delete($resolvedSession, $true)
        }
    }
    elseif (-not $sessionSucceeded) {
        Write-Warning "IOE diagnostic session retained at: $sessionDirectory"
    }
}
