[CmdletBinding()]
param([string]$OutputPath)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $OutputPath) { $OutputPath=Join-Path $repo ('data/reports/hmi/force-trace-restore-test-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')) }
if (Test-Path -LiteralPath $OutputPath) { throw 'Use a new test directory.' }
$hmi=Join-Path $OutputPath 'Hmi'
[void][IO.Directory]::CreateDirectory($hmi)
$source=Join-Path $repo '../Station010/Hmi'
$guiPath=Join-Path $hmi 'OpCon.HMI.Modulo.Gui.config'
$gui=[xml][IO.File]::ReadAllText((Join-Path $source 'OpCon.HMI.Modulo.Gui.config'))
foreach($entry in @($gui.GuiConfiguration.SmartForms.SmartForm|Where-Object name -eq 'BppForceTraceStartup')) { [void]$gui.GuiConfiguration.SmartForms.RemoveChild($entry) }
$gui.Save($guiPath)
$freshGui=[IO.File]::ReadAllBytes($guiPath)
$view=@($gui.GuiConfiguration.SmartForms.SmartForm|Where-Object name -eq 'ForceTrace')[0].file
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName((Join-Path $hmi $view)))
Copy-Item -LiteralPath (Join-Path $source $view) -Destination (Join-Path $hmi $view)
$viewHash=(Get-FileHash -LiteralPath (Join-Path $hmi $view)).Hash
$restore=Join-Path $repo 'scripts/hmi/Restore-ForceTraceStartup.ps1'
$reportRoot=Join-Path $OutputPath 'repairs'
$startup=Join-Path $hmi 'SmartForms/Bpp.ForceTrace/ForceTraceStartup.sfc'
function Assert-Ready {
    $after=[xml][IO.File]::ReadAllText($guiPath)
    $entries=@($after.GuiConfiguration.SmartForms.SmartForm|Where-Object name -eq 'BppForceTraceStartup')
    if ($entries.Count -ne 1 -or $entries[0].loadOnStartup -cne 'True' -or -not(Test-Path -LiteralPath $startup)) { throw 'Background startup is not ready.' }
    [void]$after.GuiConfiguration.SmartForms.RemoveChild($entries[0])
    if ($after.OuterXml -cne $gui.OuterXml) { throw 'Unrelated native GUI configuration changed.' }
    if ((Get-FileHash -LiteralPath (Join-Path $hmi $view)).Hash -cne $viewHash) { throw 'Curve view or its binding changed.' }
}
$first=& $restore -HmiPath $hmi -ReportRoot $reportRoot
Assert-Ready
$hash=(Get-FileHash -LiteralPath $guiPath).Hash
$second=& $restore -HmiPath $hmi -ReportRoot $reportRoot
if ($second.status -ne 'ALREADY_READY' -or (Get-FileHash -LiteralPath $guiPath).Hash -cne $hash) { throw 'Second run is not byte-idempotent.' }
# Reproduce the reported regression: a native generation replaces Gui.config.
[IO.File]::WriteAllBytes($guiPath,$freshGui)
$reexport=& $restore -HmiPath $hmi -ReportRoot $reportRoot
Assert-Ready
if ($reexport.changedFiles.Count -ne 1) { throw 'Existing startup form was unnecessarily rewritten.' }
# The Smart designer may also remove the unlisted startup file.
Remove-Item -LiteralPath $startup
$missingFile=& $restore -HmiPath $hmi -ReportRoot $reportRoot
Assert-Ready
if ((Get-FileHash -LiteralPath $guiPath).Hash -cne $hash) { throw 'Restoring a missing form changed a valid GUI file.' }
$result=[ordered]@{status='PASS';scope='Isolated local HMI copies only; no PLC, HMI runtime or IPC';initialMissingStartupRestored=$true;nativeReexportRestored=$true;missingFileRestored=$true;idempotent=$true;unrelatedGuiAndViewUnchanged=$true;testHmi=$hmi}
$result|ConvertTo-Json|Tee-Object -FilePath (Join-Path $OutputPath 'restore-check.json')
