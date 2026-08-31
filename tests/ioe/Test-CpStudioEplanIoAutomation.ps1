#requires -Version 7.0

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$generator = Join-Path $repositoryRoot 'scripts\ioe\New-CpStudioEplanIoAsc.ps1'
$exportChecker = Join-Path $repositoryRoot 'scripts\ioe\Test-CpStudioEplanIoExport.ps1'
$nameChainChecker = Join-Path $repositoryRoot 'scripts\ioe\Test-EthercatNameChain.ps1'
$fixture = Join-Path $PSScriptRoot 'fixtures\cpstudio-eplan-io.csv'
$stationIoSource = Join-Path $repositoryRoot 'specs\station010-eplan-io.csv'
$stationRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot '..\Station010'))
$ioStructPath = Join-Path $stationRoot 'Plc\Stat010_V5.11_CtrlX_IO.Struct.json'
$hmiConfigPath = Join-Path $stationRoot 'Hmi\config.xml'
$plcStructPath = Join-Path $stationRoot 'Plc\Stat010_V5.11_CtrlX_PLC.Struct.json'
$busConfigPath = Join-Path $stationRoot 'PublicConfig\BusConfig_Stat010_V5.11_CtrlX.yaml'
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
    Assert-True -Condition ($result.ActiveChannels -eq 2) -Message 'Generator reported an unexpected active-channel count.'
    Assert-True -Condition ($result.InactiveChannels -eq 0) -Message 'Generator reported an unexpected inactive-channel count.'

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

    $gapCsv = Join-Path $temporaryRoot 'gap.csv'
    $gapText = @'
DeviceDesignator,Address,IoDesignator,Type,English,Chinese
=100+TEST-A1,1,_TEST_INPUT_1,1,Input 1,
=100+TEST-A1,3,_TEST_INPUT_3,1,Input 3,
'@
    [System.IO.File]::WriteAllText($gapCsv, $gapText, [System.Text.UTF8Encoding]::new($false))
    $gapRejected = $false
    try {
        & $generator -InputCsv $gapCsv -OutputAsc (Join-Path $temporaryRoot 'gap.asc') | Out-Null
    }
    catch {
        $gapRejected = $_.Exception.Message.Contains('Address must be 2', [System.StringComparison]::Ordinal)
    }
    Assert-True -Condition $gapRejected -Message 'A channel-order gap was not rejected.'

    $whitespaceCsv = Join-Path $temporaryRoot 'whitespace.csv'
    $whitespaceText = @'
DeviceDesignator,Address,IoDesignator,Type,English,Chinese
=100+TEST-A1,1,   ,1,,
'@
    [System.IO.File]::WriteAllText($whitespaceCsv, $whitespaceText, [System.Text.UTF8Encoding]::new($false))
    $whitespaceOutput = Join-Path $temporaryRoot 'whitespace.asc'
    $whitespaceResult = & $generator -InputCsv $whitespaceCsv -OutputAsc $whitespaceOutput
    $whitespaceRows = [System.IO.File]::ReadAllLines($whitespaceOutput, [System.Text.Encoding]::Unicode)
    Assert-True -Condition ($whitespaceResult.InactiveChannels -eq 1) -Message 'Whitespace I/O designator was not counted as inactive.'
    Assert-True -Condition ([string]::IsNullOrEmpty($whitespaceRows[1].Split([char]"`t")[3])) `
        -Message 'Whitespace I/O designator was not normalized to an empty ASC field.'

    $stationOutputPath = Join-Path $temporaryRoot 'station010.asc'
    $stationResult = & $generator -InputCsv $stationIoSource -OutputAsc $stationOutputPath
    Assert-True -Condition ($stationResult.RowCount -eq 56) -Message 'Station010 ASC must contain 56 channels.'
    Assert-True -Condition ($stationResult.DigitalInputs -eq 32) -Message 'Station010 ASC must contain 32 digital inputs.'
    Assert-True -Condition ($stationResult.DigitalOutputs -eq 24) -Message 'Station010 ASC must contain 24 digital outputs.'
    Assert-True -Condition ($stationResult.ActiveChannels -eq 38) -Message 'Station010 ASC must contain 38 active channels.'
    Assert-True -Condition ($stationResult.InactiveChannels -eq 18) -Message 'Station010 ASC must contain 18 inactive channels.'

    $stationText = [System.IO.File]::ReadAllText($stationOutputPath, [System.Text.Encoding]::Unicode)
    $stationLines = @($stationText.Split(@("`r`n"), [System.StringSplitOptions]::RemoveEmptyEntries))
    Assert-True -Condition ($stationLines.Count -eq 57) -Message 'Station010 ASC must contain one header and 56 data rows.'
    $stationDataColumns = @($stationLines | Select-Object -Skip 1 | ForEach-Object { ,($_.Split([char]"`t")) })
    $writtenActiveCount = @($stationDataColumns | Where-Object { -not [string]::IsNullOrEmpty($_[3]) }).Count
    $writtenInactiveCount = @($stationDataColumns | Where-Object { [string]::IsNullOrEmpty($_[3]) }).Count
    $activeStationDataColumns = @($stationDataColumns | Where-Object { -not [string]::IsNullOrEmpty($_[3]) })
    Assert-True -Condition ($writtenActiveCount -eq 38) -Message 'Generated Station010 ASC does not contain 38 non-empty I/O designators.'
    Assert-True -Condition ($writtenInactiveCount -eq 18) -Message 'Generated Station010 ASC does not contain 18 empty I/O designators.'
    Assert-True -Condition (@($activeStationDataColumns | Where-Object { [string]::IsNullOrWhiteSpace($_[13]) }).Count -eq 0) `
        -Message 'Every active Station010 I/O designator must have an English description.'
    Assert-True -Condition (@($activeStationDataColumns | Where-Object { -not [regex]::IsMatch([string]$_[14], '[\p{IsCJKUnifiedIdeographs}]') }).Count -eq 0) `
        -Message 'Every active Station010 I/O designator must have a Chinese description.'
    $stationA1Channel1 = $stationLines[1].Split([char]"`t")
    $stationA1Channel2 = $stationLines[2].Split([char]"`t")
    $stationA1Channel3 = $stationLines[3].Split([char]"`t")
    Assert-True -Condition ($stationA1Channel1[14] -ceq '控制上电按钮') -Message 'Station010 A1 channel 1 Chinese description changed.'
    Assert-True -Condition ($stationA1Channel2[14] -ceq '控制下电按钮') -Message 'Station010 A1 channel 2 Chinese description changed.'
    Assert-True -Condition ([string]::IsNullOrEmpty($stationA1Channel3[3])) `
        -Message 'Station010 inactive channel must have an empty I/O designator.'
    $stationK911 = @($activeStationDataColumns | Where-Object { $_[3] -ceq '_000K911' })
    $stationK951 = @($activeStationDataColumns | Where-Object { $_[3] -ceq '_000K951' })
    Assert-True -Condition ($stationK911.Count -eq 1 -and $stationK911[0][13] -ceq 'Safety circuit relay power' -and $stationK911[0][14] -ceq '安全回路继电器电源') `
        -Message 'Station010 K911 bilingual description no longer matches the confirmed safety-circuit power function.'
    Assert-True -Condition ($stationK951.Count -eq 1 -and $stationK951[0][13] -ceq 'Switch Control On pulse' -and $stationK951[0][14] -ceq '控制上电使能脉冲') `
        -Message 'Station010 K951 bilingual description no longer matches the confirmed Switch Control On pulse function.'

    $exportCheck = & $exportChecker -InputCsv $stationIoSource -BusConfigPath $busConfigPath
    Assert-True -Condition ($exportCheck.passed -eq $true) -Message 'Station010 BusConfig does not match the reviewed I/O designator source.'
    Assert-True -Condition ($exportCheck.state -ceq 'MATCHED') -Message 'Station010 BusConfig export check did not return MATCHED.'
    Assert-True -Condition ($exportCheck.matchedChannels -eq 56) -Message 'Station010 BusConfig export check did not match all 56 channels.'
    Assert-True -Condition ($exportCheck.actual.activeChannels -eq 38 -and $exportCheck.actual.inactiveChannels -eq 18) `
        -Message 'Station010 BusConfig export check reported an unexpected active/inactive count.'

    $driftedBusConfigPath = Join-Path $temporaryRoot 'drifted-bus-config.yaml'
    $driftedBusConfig = [System.IO.File]::ReadAllText($busConfigPath)
    $driftedBusConfig = $driftedBusConfig.Replace('zh: 控制上电按钮', 'zh: 错误文本')
    $driftedBusConfig = [regex]::new("(?m)^        name: ''\r?$").Replace($driftedBusConfig, '        name: _UNEXPECTED_ACTIVE', 1)
    [System.IO.File]::WriteAllText($driftedBusConfigPath, $driftedBusConfig, [System.Text.UTF8Encoding]::new($false))
    $driftedExportCheck = & $exportChecker -InputCsv $stationIoSource -BusConfigPath $driftedBusConfigPath
    Assert-True -Condition ($driftedExportCheck.passed -eq $false) -Message 'BusConfig description/active-state drift was not rejected.'
    Assert-True -Condition ($driftedExportCheck.state -ceq 'MISMATCH') -Message 'Drifted BusConfig did not return MISMATCH.'
    Assert-True -Condition (@($driftedExportCheck.mismatches | Where-Object { $_.fields -contains 'Chinese' }).Count -eq 1) `
        -Message 'BusConfig Chinese-description drift was not reported.'
    Assert-True -Condition (@($driftedExportCheck.mismatches | Where-Object { $_.fields -contains 'IoDesignator' }).Count -eq 1) `
        -Message 'BusConfig inactive-channel drift was not reported.'

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

    Write-Output 'CpStudio ePLAN I/O automation tests passed: ordered ASC contract, Station010 38/18 channel state, and EtherCAT name chain.'
}
finally {
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    $systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTemporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        ([System.IO.Path]::GetFileName($resolvedTemporaryRoot)).StartsWith('cpstudio-eplan-io-', [System.StringComparison]::Ordinal)) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
