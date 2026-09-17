[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GuiConfigPath,
    [Parameter(Mandatory)][string]$ViewPath,
    [Parameter(Mandatory)][string]$AssemblyPath,
    [Parameter(Mandatory)][string]$OutputPath
)
# Produce a reviewable local overlay after CpStudio HMI export. Never edits the
# export, Std, IPC or running applications. Apply the reviewed files separately.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = [IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::IsPathRooted($out) -and $out.StartsWith('\\')) { throw 'Use a local staging directory.' }
if (Test-Path -LiteralPath $out) { throw 'Use a new staging directory; existing output is never overwritten.' }
$gui = [xml][IO.File]::ReadAllText($GuiConfigPath)
$view = [xml][IO.File]::ReadAllText($ViewPath)
$controls = @($view.SelectNodes('//*[local-name()="ForceTraceView"]'))
if ($controls.Count -ne 1 -or [string]::IsNullOrWhiteSpace($controls[0].FrameItemName)) { throw 'Expected exactly one bound ForceTraceView.' }
$identity = [Reflection.AssemblyName]::GetAssemblyName($AssemblyPath)
if ($identity.Name -cne 'Bpp.ForceTrace' -or $identity.Version -ne [version]'0.1.0.2') { throw 'Expected validated Bpp.ForceTrace 0.1.0.2.' }
$references = @($gui.GuiConfiguration.References.Reference | Where-Object assembly -like 'Bpp.ForceTrace,*')
if ($references.Count -ne 1) { throw 'Expected exactly one existing native add-on reference.' }
$references[0].assembly = $identity.FullName
$startupName = 'BppForceTraceStartup'
if (@($gui.GuiConfiguration.SmartForms.SmartForm | Where-Object name -eq $startupName).Count) { throw 'Startup already configured; inspect the existing integration.' }
$relativeStartup = 'SmartForms\Bpp.ForceTrace\ForceTraceStartup.sfc'
$entry = $gui.CreateElement('SmartForm')
$entry.SetAttribute('name',$startupName)
$entry.SetAttribute('file',$relativeStartup)
$entry.SetAttribute('loadOnStartup','True')
$entry.SetAttribute('executeCode','False')
[void]$gui.GuiConfiguration.SmartForms.AppendChild($entry)
$startup = [xml][IO.File]::ReadAllText((Join-Path $repo 'src/hmi/Bpp.ForceTrace/ForceTraceStartup.sfc'))
$startup.SelectSingleNode('//*[local-name()="ForceTraceStartupForm"]').SetAttribute('FrameItemName',$controls[0].FrameItemName)
# Only a hidden SmartForm is preloaded; the existing SmartControl view is left
# unchanged because ProjectForms.Load cannot cast a SmartControl to SmartForm.
[void][IO.Directory]::CreateDirectory((Join-Path $out 'SmartForms/Bpp.ForceTrace'))
$settings = New-Object Xml.XmlWriterSettings
$settings.Indent = $true
$settings.Encoding = New-Object Text.UTF8Encoding($false)
foreach ($pair in @(@($gui,'OpCon.HMI.Modulo.Gui.config'),@($startup,$relativeStartup))) {
    $writer = [Xml.XmlWriter]::Create((Join-Path $out $pair[1]),$settings)
    try { $pair[0].Save($writer) } finally { $writer.Dispose() }
}
$receipt = [ordered]@{
    scope = 'Local candidate overlay only; not installed or deployed'
    assembly = $identity.FullName
    assemblySha256 = (Get-FileHash -LiteralPath $AssemblyPath -Algorithm SHA256).Hash
    inputGuiSha256 = (Get-FileHash -LiteralPath $GuiConfigPath -Algorithm SHA256).Hash
    viewSha256 = (Get-FileHash -LiteralPath $ViewPath -Algorithm SHA256).Hash
    frameItemName = $controls[0].FrameItemName
    startupName = $startupName
    files = @(Get-ChildItem -LiteralPath $out -File -Recurse | ForEach-Object {
        [ordered]@{path=$_.FullName.Substring($out.Length+1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    note = 'Install the matching add-on through CpStudio; re-export HMI, regenerate this overlay, review only the own reference/startup diff, then deploy as one approved HMI change. Never mix with the old DLL.'
}
$receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'OVERLAY.json') -Encoding UTF8
[pscustomobject]@{Status='STAGED';Output=$out;PlcChanged=$false;Installed=$false}
