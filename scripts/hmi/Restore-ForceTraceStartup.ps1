[CmdletBinding()]
param(
    [string]$HmiPath = (Join-Path $PSScriptRoot '../../../Station010/Hmi'),
    [string]$AssemblyPath = (Join-Path $PSScriptRoot '../../../Std/Hmi_V5_11/Addons/Bpp.ForceTrace/Bpp.ForceTrace.dll'),
    [string]$ReportRoot = (Join-Path $PSScriptRoot '../../data/reports/hmi/force-trace-startup-repair')
)
# Legacy v1 only: restore this add-on's startup files after native HMI generation. No PLE,
# runtime, Std or IPC writes. An already-correct export is left byte-identical.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$hmi = [IO.Path]::GetFullPath($HmiPath)
if ($hmi.StartsWith('\\')) { throw 'Only a local HMI export may be repaired.' }
$guiPath = Join-Path $hmi 'OpCon.HMI.Modulo.Gui.config'
$gui = [xml][IO.File]::ReadAllText($guiPath)
$views = @($gui.GuiConfiguration.SmartForms.SmartForm | Where-Object name -eq 'ForceTrace')
if ($views.Count -ne 1) { throw 'Expected one ForceTrace view in the native export.' }
$viewPath = [IO.Path]::GetFullPath((Join-Path $hmi $views[0].file))
if (-not $viewPath.StartsWith($hmi.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'View escapes HMI directory.' }
$view = [xml][IO.File]::ReadAllText($viewPath)
$controls = @($view.SelectNodes('//*[local-name()="ForceTraceView"]'))
if ($controls.Count -eq 1 -and $controls[0].SelectSingleNode('*[local-name()="property.StatisticsItem"]')) {
    # V2 acquisition lives in the PLC. Never restore a v1 HMI recorder over it.
    return [pscustomobject]@{status='NOT_REQUIRED_PLC_BUFFERED';hmi=$hmi;changedFiles=@()}
}
if ($controls.Count -ne 1 -or [string]::IsNullOrWhiteSpace($controls[0].FrameItemName)) { throw 'Expected one bound force recorder view.' }
$identity = [Reflection.AssemblyName]::GetAssemblyName($AssemblyPath)
$references = @($gui.GuiConfiguration.References.Reference | Where-Object assembly -like 'Bpp.ForceTrace,*')
if ($identity.Name -cne 'Bpp.ForceTrace' -or $identity.Version -ne [version]'0.1.0.2' -or
    $references.Count -ne 1 -or $references[0].assembly -cne $identity.FullName) { throw 'Native export and installed 0.1.0.2 add-on must match.' }
$relativeStartup = 'SmartForms\Bpp.ForceTrace\ForceTraceStartup.sfc'
$startupPath = Join-Path $hmi $relativeStartup
$entries = @($gui.GuiConfiguration.SmartForms.SmartForm | Where-Object name -eq 'BppForceTraceStartup')
if ($entries.Count -gt 1) { throw 'Duplicate startup entries; manual review required.' }
if ($entries.Count -eq 1 -and ($entries[0].file -cne $relativeStartup -or
    $entries[0].loadOnStartup -cne 'True' -or $entries[0].executeCode -cne 'False')) { throw 'Unrecognized startup configuration; refusing overwrite.' }
$template = [xml][IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../src/hmi/Bpp.ForceTrace/ForceTraceStartup.sfc'))
$template.SelectSingleNode('//*[local-name()="ForceTraceStartupForm"]').SetAttribute('FrameItemName',$controls[0].FrameItemName)
if (Test-Path -LiteralPath $startupPath) {
    $existing = [xml][IO.File]::ReadAllText($startupPath)
    if ($existing.OuterXml -cne $template.OuterXml) { throw 'Startup form differs from its bound template; refusing overwrite.' }
    if ($entries.Count -eq 1) { return [pscustomobject]@{status='ALREADY_READY';hmi=$hmi;changedFiles=@()} }
}
$report = Join-Path ([IO.Path]::GetFullPath($ReportRoot)) ((Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[void][IO.Directory]::CreateDirectory($report)
$beforeHash = (Get-FileHash -LiteralPath $guiPath -Algorithm SHA256).Hash
Copy-Item -LiteralPath $guiPath -Destination (Join-Path $report 'Gui.config.before')
# Generate from the latest export, never from an older full HMI snapshot.
if ($entries.Count -eq 1) { [void]$gui.GuiConfiguration.SmartForms.RemoveChild($entries[0]) }
$inputGui = Join-Path $report 'Gui.config.input'
$gui.Save($inputGui)
$overlay = Join-Path $report 'overlay'
[void](& (Join-Path $PSScriptRoot 'New-ForceTraceStartupOverlay.ps1') -GuiConfigPath $inputGui -ViewPath $viewPath -AssemblyPath $AssemblyPath -OutputPath $overlay)
if ((Get-FileHash -LiteralPath $guiPath -Algorithm SHA256).Hash -cne $beforeHash) { throw 'HMI export changed during staging; retry after generation completes.' }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($startupPath))
$changed = @()
if (-not (Test-Path -LiteralPath $startupPath)) {
    Copy-Item -LiteralPath (Join-Path $overlay $relativeStartup) -Destination $startupPath
    $changed += $relativeStartup
}
# Publish the configuration last, after the referenced startup form exists.
if ($entries.Count -eq 0) {
    Copy-Item -LiteralPath (Join-Path $overlay 'OpCon.HMI.Modulo.Gui.config') -Destination $guiPath
    $changed += 'OpCon.HMI.Modulo.Gui.config'
}
$receipt = [ordered]@{status='RESTORED';hmi=$hmi;frameItemName=[string]$controls[0].FrameItemName;changedFiles=$changed;beforeGuiSha256=$beforeHash;afterGuiSha256=(Get-FileHash -LiteralPath $guiPath -Algorithm SHA256).Hash;startupSha256=(Get-FileHash -LiteralPath $startupPath -Algorithm SHA256).Hash;plcChanged=$false;ipcDeployed=$false;report=$report}
$receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $report 'repair.json') -Encoding utf8
[pscustomobject]$receipt
