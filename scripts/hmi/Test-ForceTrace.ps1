[CmdletBinding()]
param([string]$OutputPath)
$ErrorActionPreference='Stop'
$traceRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(-not $OutputPath){$OutputPath=Join-Path $traceRepo ('data/reports/hmi/force-v2-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))}
$testOutput=[IO.Path]::GetFullPath($OutputPath)
$null=New-Item -ItemType Directory -Path $testOutput
$exe=Join-Path $testOutput 'ForceTraceFrameTests.exe'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" /nologo /codepage:65001 "/out:$exe" `
 (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/ForceTraceStore.cs') `
 (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/ForceTraceFrames.cs') `
 (Join-Path $traceRepo 'tests/hmi/ForceTraceFrameTests.cs')
if($LASTEXITCODE -ne 0){throw 'Frame test compilation failed.'}
& $exe
if($LASTEXITCODE -ne 0){throw 'Frame tests failed.'}
