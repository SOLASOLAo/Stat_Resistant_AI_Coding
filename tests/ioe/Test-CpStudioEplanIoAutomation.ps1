#requires -Version 7.0

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$generator = Join-Path $repositoryRoot 'scripts\ioe\New-CpStudioEplanIoAsc.ps1'
$nameChainChecker = Join-Path $repositoryRoot 'scripts\ioe\Test-EthercatNameChain.ps1'
$fixture = Join-Path $PSScriptRoot 'fixtures\cpstudio-eplan-io.csv'
$stationRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot '..\Station010'))
$ioStructPath = Join-Path $stationRoot 'Plc\Stat010_V5.11_CtrlX_IO.Struct.json'
$hmiConfigPath = Join-Path $stationRoot 'Hmi\config.xml'
$plcStructPath = Join-Path $stationRoot 'Plc\Stat010_V5.11_CtrlX_PLC.Struct.json'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cpstudio-eplan-io-' + [guid]::NewGuid().ToString('N'))

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-NameChainRejected {
    param(
        [Parameter(Mandatory = $true)][string]$IoStruct,
        [Parameter(Mandatory = $true)][string]$HmiConfig,
        [Parameter(Mandatory = $true)][string]$PlcStruct,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $rejected = $false
    try {
        & $nameChainChecker `
            -IoStructPath $IoStruct `
            -HmiConfigPath $HmiConfig `
            -PlcStructPath $PlcStruct `
            -TargetMasterName '_000SA620_X1' | Out-Null
    }
    catch {
        $rejected = $_.Exception.Message.Contains('name-chain validation failed', [System.StringComparison]::Ordinal)
    }
    Assert-True -Condition $rejected -Message "$Description was not rejected."
}

try {
    [System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
    $outputPath = Join-Path $temporaryRoot 'fixture.asc'
    $result = & $generator -InputCsv $fixture -OutputAsc $outputPath

    Assert-True -Condition ([System.IO.File]::Exists($outputPath)) -Message 'Generator did not create the ASC file.'
    Assert-True -Condition ($result.RowCount -eq 2) -Message 'Generator reported an unexpected row count.'
    Assert-True -Condition ($result.DigitalInputs -eq 1) -Message 'Generator reported an unexpected DI count.'
    Assert-True -Condition ($result.DigitalOutputs -eq 1) -Message 'Generator reported an unexpected DO count.'

    $bytes = [System.IO.File]::ReadAllBytes($outputPath)
    Assert-True -Condition ($bytes.Length -gt 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) `
        -Message 'ASC is not UTF-16LE with a BOM.'

    $text = [System.IO.File]::ReadAllText($outputPath, [System.Text.Encoding]::Unicode)
    Assert-True -Condition ($text.EndsWith("`r`n", [System.StringComparison]::Ordinal)) `
        -Message 'ASC does not end with CRLF.'
    Assert-True -Condition (-not [regex]::IsMatch($text, '(?<!\r)\n')) -Message 'ASC contains a bare LF.'

    $lines = @($text.Split(@("`r`n"), [System.StringSplitOptions]::RemoveEmptyEntries))
    Assert-True -Condition ($lines.Count -eq 3) -Message 'ASC must contain one header and two data rows.'
    foreach ($line in $lines) {
        Assert-True -Condition ($line.Split([char]"`t").Count -eq 15) -Message 'Every ASC row must contain exactly 15 columns.'
    }

    $header = $lines[0].Split([char]"`t")
    Assert-True -Condition ($header[0] -ceq 'Device designator') -Message 'Unexpected ASC first header.'
    Assert-True -Condition ($header[13] -ceq 'E' -and $header[14] -ceq 'X') -Message 'ASC language headers must be E and X.'

    $firstRow = $lines[1].Split([char]"`t")
    Assert-True -Condition ($firstRow[0] -ceq '=100+TEST-A1') -Message 'Device designator changed during conversion.'
    Assert-True -Condition ($firstRow[1] -ceq '1') -Message 'Channel address changed during conversion.'
    Assert-True -Condition ($firstRow[3] -ceq '_TEST_INPUT') -Message 'I/O designator changed during conversion.'
    Assert-True -Condition ($firstRow[4] -ceq '1') -Message 'I/O type changed during conversion.'
    Assert-True -Condition ($firstRow[13] -ceq 'Test input') -Message 'English description changed during conversion.'
    Assert-True -Condition ($firstRow[14] -ceq '测试输入') -Message 'Chinese description changed during conversion.'

    $duplicateCsv = Join-Path $temporaryRoot 'duplicate.csv'
    $duplicateText = @'
DeviceDesignator,Address,IoDesignator,Type,English,Chinese
=100+TEST-A1,1,_TEST_INPUT,1,Test input,测试输入
=100+TEST-A1,1,_TEST_INPUT_2,1,Duplicate,重复
'@
    [System.IO.File]::WriteAllText($duplicateCsv, $duplicateText, [System.Text.UTF8Encoding]::new($false))
    $duplicateRejected = $false
    try {
        & $generator -InputCsv $duplicateCsv -OutputAsc (Join-Path $temporaryRoot 'duplicate.asc') | Out-Null
    }
    catch {
        $duplicateRejected = $_.Exception.Message.Contains('duplicates DeviceDesignator', [System.StringComparison]::Ordinal)
    }
    Assert-True -Condition $duplicateRejected -Message 'Duplicate module/channel input was not rejected.'

    $nameChainJson = (& $nameChainChecker -TargetMasterName '_000SA620_X1' | Out-String).Trim()
    $nameChain = $nameChainJson | ConvertFrom-Json
    Assert-True -Condition ($nameChain.passed -eq $true) -Message 'Station010 EtherCAT name chain did not pass.'
    Assert-True -Condition ($nameChain.internalMasterName -ceq '_000SA620_X1') -Message 'Unexpected IOE EtherCAT master name.'
    Assert-True -Condition ($nameChain.ecadMasterName -ceq '=000+S-A620-X1') -Message 'Unexpected EtherCAT ECAD name.'

    $targetMismatchRejected = $false
    try {
        & $nameChainChecker -TargetMasterName 'deliberate-mismatch' | Out-Null
    }
    catch {
        $targetMismatchRejected = $_.Exception.Message.Contains('name-chain validation failed', [System.StringComparison]::Ordinal)
    }
    Assert-True -Condition $targetMismatchRejected -Message 'A mismatched ctrlX Web EtherCAT master name was not rejected.'

    $hmiText = [System.IO.File]::ReadAllText($hmiConfigPath)
    Assert-True -Condition ($hmiText.Contains('name="=000+S-A620-X1"', [System.StringComparison]::Ordinal)) `
        -Message 'Station010 HMI fixture no longer contains the expected BusDiag name.'
    Assert-True -Condition ($hmiText.Contains('variable="Ch1.L1.Peripherals._000SA620_X1"', [System.StringComparison]::Ordinal)) `
        -Message 'Station010 HMI fixture no longer contains the expected BusDiag variable.'

    $wrongHmiNamePath = Join-Path $temporaryRoot 'wrong-hmi-name.xml'
    [System.IO.File]::WriteAllText(
        $wrongHmiNamePath,
        $hmiText.Replace('name="=000+S-A620-X1"', 'name="=WRONG-MASTER"'),
        [System.Text.UTF8Encoding]::new($false)
    )
    Assert-NameChainRejected -IoStruct $ioStructPath -HmiConfig $wrongHmiNamePath -PlcStruct $plcStructPath `
        -Description 'A mismatched HMI BusDiag name'

    $wrongHmiVariablePath = Join-Path $temporaryRoot 'wrong-hmi-variable.xml'
    [System.IO.File]::WriteAllText(
        $wrongHmiVariablePath,
        $hmiText.Replace('variable="Ch1.L1.Peripherals._000SA620_X1"', 'variable="Wrong.Path._000SA620_X1"'),
        [System.Text.UTF8Encoding]::new($false)
    )
    Assert-NameChainRejected -IoStruct $ioStructPath -HmiConfig $wrongHmiVariablePath -PlcStruct $plcStructPath `
        -Description 'An incorrect HMI BusDiag variable path'

    $plcText = [System.IO.File]::ReadAllText($plcStructPath)
    $plcMasterText = '"Name": "ethercat_master_instances_000SA620_X1"'
    Assert-True -Condition ($plcText.Contains($plcMasterText, [System.StringComparison]::Ordinal)) `
        -Message 'Station010 PLC fixture no longer contains the expected EtherCAT master object.'
    $missingPlcMasterPath = Join-Path $temporaryRoot 'missing-plc-master.json'
    [System.IO.File]::WriteAllText(
        $missingPlcMasterPath,
        $plcText.Replace($plcMasterText, '"Name": "ethercat_master_instances_REMOVED"'),
        [System.Text.UTF8Encoding]::new($false)
    )
    Assert-NameChainRejected -IoStruct $ioStructPath -HmiConfig $hmiConfigPath -PlcStruct $missingPlcMasterPath `
        -Description 'A missing PLE EtherCAT master object'

    Write-Output 'CpStudio ePLAN I/O automation tests passed: ASC contract and Station010 EtherCAT name chain.'
}
finally {
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    $systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTemporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        ([System.IO.Path]::GetFileName($resolvedTemporaryRoot)).StartsWith('cpstudio-eplan-io-', [System.StringComparison]::Ordinal)) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
