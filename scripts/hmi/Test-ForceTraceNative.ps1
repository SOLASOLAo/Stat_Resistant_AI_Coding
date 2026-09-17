[CmdletBinding()]
param([string]$RuntimePath, [string]$OutputPath)
$ErrorActionPreference = 'Stop'
$traceRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $RuntimePath) { $RuntimePath = Join-Path $traceRepo '../Std/Hmi_V5_11' }
$runtimePath = [IO.Path]::GetFullPath($RuntimePath)
if (-not $OutputPath) { $OutputPath = Join-Path $traceRepo ('data/reports/hmi/force-trace-native-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')) }
$testOutput = [IO.Path]::GetFullPath($OutputPath)
$null = New-Item -ItemType Directory -Path $testOutput
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
$referenceNames = @('OpCon.HMI.Modulo.Shared.dll','OpCon.HMI.Modulo.Forms.dll',
  'VisiWinNET.Embedded.Forms.dll','VisiWinNET.Embedded.Systems.dll','TeeChart.dll')
$referenceArgs = @('/r:System.Windows.Forms.dll','/r:System.Drawing.dll','/r:System.Data.dll')
$referenceArgs += @($referenceNames | ForEach-Object { '/r:' + (Join-Path $runtimePath $_) })
& $compiler /nologo /target:library /codepage:65001 "/out:$testOutput\ForceTrace.Hmi.dll" @referenceArgs `
  (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/ForceTraceStore.cs') `
  (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/ForceTraceFrames.cs') `
  (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/ForceTraceSession.cs') `
  (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/ForceTraceView.cs') `
  (Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/AssemblyInfo.cs')
if ($LASTEXITCODE -ne 0) { throw 'Native view compilation failed.' }
# .NET Framework is required by the installed Modulo assemblies and resource loader.
& powershell.exe -NoProfile -File (Join-Path $traceRepo 'tests/hmi/Render-ForceTraceNative.ps1') `
  -RepoPath $traceRepo -RuntimePath $runtimePath -OutputPath $testOutput
if ($LASTEXITCODE -ne 0) { throw 'Native rendering or CSV check failed.' }
# CpStudio's native HMI add-on importer accepts a ZIP with the .had extension.
# Build only our assembly and descriptor. Installing it is a separate native action.
$descriptor = Join-Path $traceRepo 'src/hmi/ForceTrace.Hmi/AddonDesc.xml'
$description = [xml][IO.File]::ReadAllText($descriptor)
$assemblyName = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $testOutput 'ForceTrace.Hmi.dll'))
if ($description.HMIAddon.Assemblies.Assembly.assemblyInfo -cne $assemblyName.FullName) {
  throw 'Add-on descriptor and built assembly identity differ.'
}
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$package = Join-Path $testOutput 'ForceTrace.Hmi.had'
$zip = [IO.Compression.ZipFile]::Open($package, [IO.Compression.ZipArchiveMode]::Create)
try {
  $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $descriptor, 'AddonDesc.xml')
  $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $testOutput 'ForceTrace.Hmi.dll'), 'ForceTrace.Hmi.dll')
} finally { $zip.Dispose() }
[pscustomobject]@{package=$package;assembly=$assemblyName.FullName;installed=$false;plcAdapterConnected=$false} | ConvertTo-Json
