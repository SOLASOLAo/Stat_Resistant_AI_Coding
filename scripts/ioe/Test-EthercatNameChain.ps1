#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$IoStructPath = (Join-Path $PSScriptRoot '..\..\..\Station010\Plc\Stat010_V5.11_CtrlX_IO.Struct.json'),

    [string]$HmiConfigPath = (Join-Path $PSScriptRoot '..\..\..\Station010\Hmi\config.xml'),

    [string]$PlcStructPath = (Join-Path $PSScriptRoot '..\..\..\Station010\Plc\Stat010_V5.11_CtrlX_PLC.Struct.json'),

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetMasterName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (-not [System.IO.File]::Exists($resolved)) {
        throw "$Label not found: $resolved"
    }
    return $resolved
}

function Get-StructuralNodes {
    param([Parameter(Mandatory = $true)]$Root)

    $pending = [System.Collections.Generic.Queue[object]]::new()
    $pending.Enqueue($Root)
    while ($pending.Count -gt 0) {
        $node = $pending.Dequeue()
        Write-Output $node

        $itemsProperty = $node.PSObject.Properties['StructuralItems']
        if ($null -eq $itemsProperty -or $null -eq $itemsProperty.Value) {
            continue
        }
        foreach ($child in @($itemsProperty.Value)) {
            if ($null -ne $child) {
                $pending.Enqueue($child)
            }
        }
    }
}

$resolvedIoStructPath = Resolve-ExistingFile -Path $IoStructPath -Label 'IO structure snapshot'
$resolvedHmiConfigPath = Resolve-ExistingFile -Path $HmiConfigPath -Label 'HMI configuration'
$resolvedPlcStructPath = Resolve-ExistingFile -Path $PlcStructPath -Label 'PLC structure snapshot'

$ioRoot = [System.IO.File]::ReadAllText($resolvedIoStructPath) | ConvertFrom-Json -Depth 100
$masters = @(Get-StructuralNodes -Root $ioRoot | Where-Object { [long]$_.Type -eq 64 })
if ($masters.Count -ne 1) {
    throw "Expected exactly one EtherCAT master (Type=64) in '$resolvedIoStructPath'; found $($masters.Count)."
}

$master = $masters[0]
$internalName = [string]$master.Name
$ecadName = [string]$master.EcadId
if ([string]::IsNullOrWhiteSpace($internalName)) {
    throw "EtherCAT master in '$resolvedIoStructPath' has no internal Name."
}
if ([string]::IsNullOrWhiteSpace($ecadName)) {
    throw "EtherCAT master '$internalName' in '$resolvedIoStructPath' has no EcadId."
}

$xmlSettings = [System.Xml.XmlReaderSettings]::new()
$xmlSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
$xmlReader = [System.Xml.XmlReader]::Create($resolvedHmiConfigPath, $xmlSettings)
try {
    $hmiDocument = [System.Xml.XmlDocument]::new()
    $hmiDocument.Load($xmlReader)
}
finally {
    $xmlReader.Dispose()
}

$busDiagNodes = @($hmiDocument.SelectNodes('//*[local-name()="BusDiag"]'))
if ($busDiagNodes.Count -ne 1) {
    throw "Expected exactly one HMI BusDiag in '$resolvedHmiConfigPath'; found $($busDiagNodes.Count)."
}

$busDiag = $busDiagNodes[0]
$hmiName = [string]$busDiag.GetAttribute('name')
$hmiVariable = [string]$busDiag.GetAttribute('variable')
$expectedHmiVariable = "Ch1.L1.Peripherals.$internalName"
$expectedPlcObject = "ethercat_master_instances$internalName"

$plcRoot = [System.IO.File]::ReadAllText($resolvedPlcStructPath) | ConvertFrom-Json -Depth 100
$plcObjectCount = @(Get-StructuralNodes -Root $plcRoot | Where-Object {
        $nameProperty = $_.PSObject.Properties['Name']
        ($null -ne $nameProperty) -and ([string]$nameProperty.Value -ceq $expectedPlcObject)
    }).Count

$hmiNameMatches = $hmiName -ceq $ecadName
$hmiVariableMatches = $hmiVariable -ceq $expectedHmiVariable
$plcObjectMatches = $plcObjectCount -eq 1
$targetMatches = $TargetMasterName -ceq $internalName
$passed = $hmiNameMatches -and $hmiVariableMatches -and $plcObjectMatches -and $targetMatches

$result = [ordered]@{
    passed = $passed
    internalMasterName = $internalName
    ecadMasterName = $ecadName
    hmiBusDiagName = $hmiName
    hmiBusDiagVariable = $hmiVariable
    plcMasterObject = $expectedPlcObject
    plcMasterObjectCount = $plcObjectCount
    targetMasterName = $TargetMasterName
    checks = [ordered]@{
        hmiNameMatchesEcadId = $hmiNameMatches
        hmiVariableMatchesExpectedPath = $hmiVariableMatches
        plcObjectExistsExactlyOnce = $plcObjectMatches
        targetNameMatchesInternalName = $targetMatches
    }
}

Write-Output ($result | ConvertTo-Json -Depth 4 -Compress)
if (-not $passed) {
    throw 'EtherCAT name-chain validation failed. See the JSON result above.'
}
