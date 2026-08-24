[CmdletBinding()]
param(
    [string] $TargetIp = '192.168.0.51',
    [string] $OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $diagnosisDirectory = Join-Path $desktop 'DiagnosisFiles'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $diagnosisDirectory "ctrlx-license-diagnostic-$stamp.txt"
}

function Test-TcpPortFast {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Address,

        [Parameter(Mandatory = $true)]
        [int] $Port,

        [int] $TimeoutMs = 3000
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $client.BeginConnect($Address, $Port, $null, $null)
        if (-not $result.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return [pscustomobject]@{
                Port = $Port
                Open = $false
                Detail = "timeout after ${TimeoutMs} ms"
            }
        }

        $client.EndConnect($result)
        return [pscustomobject]@{
            Port = $Port
            Open = $true
            Detail = 'TCP connection established'
        }
    }
    catch {
        return [pscustomobject]@{
            Port = $Port
            Open = $false
            Detail = $_.Exception.GetBaseException().Message
        }
    }
    finally {
        $client.Close()
    }
}

$lines = New-Object System.Collections.Generic.List[string]
function Add-ReportLine {
    param([string] $Text = '')
    $lines.Add($Text)
}

Add-ReportLine 'ctrlX Nexeed License Server diagnostic'
Add-ReportLine "Captured: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Add-ReportLine "PC time zone: $((Get-TimeZone).Id)"
Add-ReportLine "Target: $TargetIp"
Add-ReportLine ''

Add-ReportLine '[Adapters]'
$adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceIndex, Status, LinkSpeed, MediaConnectionState
Add-ReportLine (($adapters | Format-Table -AutoSize | Out-String).TrimEnd())
Add-ReportLine ''

Add-ReportLine '[IPv4 addresses]'
$addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -match 'Ethernet|Wi-Fi' } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState
Add-ReportLine (($addresses | Format-Table -AutoSize | Out-String).TrimEnd())
Add-ReportLine ''

Add-ReportLine '[Route selected for target]'
try {
    $route = Find-NetRoute -RemoteIPAddress $TargetIp -ErrorAction Stop
    Add-ReportLine (($route |
        Select-Object InterfaceAlias, InterfaceIndex, IPAddress, DestinationPrefix, NextHop |
        Format-List |
        Out-String).TrimEnd())
}
catch {
    Add-ReportLine "No route: $($_.Exception.GetBaseException().Message)"
}
Add-ReportLine ''

Add-ReportLine '[TCP probes]'
$httpsProbe = Test-TcpPortFast -Address $TargetIp -Port 443
$licenseProbe = Test-TcpPortFast -Address $TargetIp -Port 61863
Add-ReportLine (($httpsProbe, $licenseProbe | Format-Table -AutoSize | Out-String).TrimEnd())
Add-ReportLine ''

Add-ReportLine '[Neighbor entry]'
$neighbor = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $TargetIp } |
    Select-Object InterfaceAlias, IPAddress, LinkLayerAddress, State
if ($null -eq $neighbor) {
    Add-ReportLine 'No IPv4 neighbor entry found.'
}
else {
    Add-ReportLine (($neighbor | Format-Table -AutoSize | Out-String).TrimEnd())
}
Add-ReportLine ''

Add-ReportLine '[Interpretation]'
if (-not $httpsProbe.Open) {
    Add-ReportLine 'FAIL: TCP 443 is closed/unreachable. Check cable, target IP, PC IPv4 address, and ctrlX interface.'
}
elseif (-not $licenseProbe.Open) {
    Add-ReportLine 'OBSERVED: ctrlX HTTPS is reachable, but Nexeed License Server TCP 61863 is not listening/reachable.'
    Add-ReportLine 'Port state alone is not the root cause. Inspect ctrlX Diagnostics > Logbook for app startup or crash errors.'
}
else {
    Add-ReportLine 'NETWORK PATH OK: TCP 443 and Nexeed TCP 61863 are reachable.'
    Add-ReportLine 'Next: compare PC/ctrlX date and time, then inspect certificate/service errors in the ctrlX Logbook.'
}

Add-ReportLine ''
Add-ReportLine 'No PLC download, runtime command, variable write, FORCE, or network-setting change was performed.'

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$lines | Out-File -LiteralPath $OutputPath -Encoding utf8
$lines | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host "Report saved: $OutputPath" -ForegroundColor Green
