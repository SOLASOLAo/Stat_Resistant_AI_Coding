[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$validator = Join-Path $PSScriptRoot 'Test-ProjectFramework.ps1'
$temporaryBase = Join-Path ([System.IO.Path]::GetTempPath()) ('ctrlx-framework-selftest-' + [guid]::NewGuid().ToString('N'))
$temporaryRoot = Join-Path $temporaryBase 'McpCoding'

function Invoke-Validator {
    param([int]$ExpectedExitCode)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -File $validator -RepositoryRoot $temporaryRoot 1>$null 2>$null
    $actualExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($actualExitCode -ne $ExpectedExitCode) {
        throw "Expected validator exit code $ExpectedExitCode but received $actualExitCode"
    }
}

try {
    [System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $temporaryBase 'Station010')) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $temporaryBase 'Std')) | Out-Null

    foreach ($directory in @('config', 'specs', 'ai', 'src', 'scripts')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $directory) -Destination $temporaryRoot -Recurse
    }
    [System.IO.Directory]::CreateDirectory((Join-Path $temporaryRoot 'tests')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'tests\cpstudio') -Destination (Join-Path $temporaryRoot 'tests') -Recurse
    [System.IO.Directory]::CreateDirectory((Join-Path $temporaryRoot 'tests\static')) | Out-Null
    foreach ($staticTest in @(
        'Test-RunOperatorGuidance.ps1',
        'Test-SfcRestWriterPlanOnly.ps1',
        'Test-SfcRestWriterTransaction.ps1'
    )) {
        Copy-Item `
            -LiteralPath (Join-Path $sourceRoot "tests\static\$staticTest") `
            -Destination (Join-Path $temporaryRoot 'tests\static')
    }
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'TEAM_SETUP.md') -Destination $temporaryRoot

    Invoke-Validator 0

    $graphicalPath = Join-Path $temporaryRoot 'ai\graphical.yaml'
    $graphicalText = [System.IO.File]::ReadAllText($graphicalPath)
    $expectedComment = '      N045: Check measure release'
    if (-not $graphicalText.Contains($expectedComment)) {
        throw 'Self-test fixture no longer contains the expected N045 comment'
    }
    [System.IO.File]::WriteAllText(
        $graphicalPath,
        $graphicalText.Replace($expectedComment, '      N045: Deliberate mismatch'),
        (New-Object System.Text.UTF8Encoding $false)
    )
    Invoke-Validator 1
    [System.IO.File]::WriteAllText($graphicalPath, $graphicalText, (New-Object System.Text.UTF8Encoding $false))

    $actionPath = Join-Path $temporaryRoot 'src\plc\project\Station010\SqS_Wp100_Run\actions\N045.st'
    $missingPath = $actionPath + '.missing'
    Move-Item -LiteralPath $actionPath -Destination $missingPath
    Invoke-Validator 1
    Move-Item -LiteralPath $missingPath -Destination $actionPath

    Invoke-Validator 0
    Write-Output 'Project framework self-test passed: baseline, comment mismatch, and missing Action cases'
}
finally {
    $resolvedBase = [System.IO.Path]::GetFullPath($temporaryBase)
    $expectedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedBase.StartsWith($expectedTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        ([System.IO.Path]::GetFileName($resolvedBase)).StartsWith('ctrlx-framework-selftest-', [System.StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}
