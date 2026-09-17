param([string]$OutputPath, [string]$AssemblyPath, [string]$RuntimePath, [string]$StationRoot)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell for native .NET Framework controls.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $StationRoot) { $StationRoot = Join-Path $repo '../Station010' }
if (-not $RuntimePath) { $RuntimePath = Join-Path $repo '../Std/Hmi_V5_11' }
$station = [IO.Path]::GetFullPath($StationRoot)
$runtime = [IO.Path]::GetFullPath($RuntimePath)
if (-not $OutputPath) { $OutputPath = Join-Path $repo ('data/reports/hmi/localization-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
[void][IO.Directory]::CreateDirectory($OutputPath)
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[ComponentModel.LicenseManager]::CurrentContext = New-Object ComponentModel.Design.DesigntimeLicenseContext
foreach ($name in @('VisiWinNET.Embedded.Systems.dll','VisiWinNET.Embedded.Forms.dll','OpCon.HMI.Modulo.Shared.dll','OpCon.HMI.Modulo.Forms.dll','TeeChart.dll')) {
    [void][Reflection.Assembly]::LoadFrom((Join-Path $runtime $name))
}
if (-not $AssemblyPath) { $AssemblyPath = Join-Path $runtime 'Addons/Bpp.ForceTrace/Bpp.ForceTrace.dll' }
[void][Reflection.Assembly]::LoadFrom($AssemblyPath)
[void][Reflection.Assembly]::LoadFrom('C:\Nexeed\Automation\CSV5_11\OpCon\VisiWinNET.SFCLoader.dll')
Add-Type @'
using System;
using System.ComponentModel;
public sealed class OfflineHmiSite : ISite {
    public OfflineHmiSite(IComponent c) { Component = c; }
    public IComponent Component { get; private set; }
    public IContainer Container { get { return null; } }
    public bool DesignMode { get { return true; } }
    public string Name { get; set; }
    public object GetService(Type t) { return null; }
}
'@
$languages = @{}
foreach ($lcid in @('1033','2052')) { $languages[$lcid] = [xml][IO.File]::ReadAllText((Join-Path $station "Hmi/OpCon.HMI.Modulo.$lcid.lng")) }
function Caption([string]$lcid, [string]$group, [string]$key) {
    $nodes = @($languages[$lcid].SelectNodes('//Group[@Name="' + $group + '"]/Texts/Text[@Name="' + $key + '"]'))
    if ($nodes.Count -ne 1 -or -not $nodes[0].GetAttribute('Text')) { throw "Missing or ambiguous $lcid $group.$key" }
    return $nodes[0].GetAttribute('Text')
}
$specs = @((Get-Content (Join-Path $repo 'specs/hmi/resistance_texts.json') -Raw -Encoding UTF8 | ConvertFrom-Json), (Get-Content (Join-Path $repo 'specs/hmi/force_trace_texts.json') -Raw -Encoding UTF8 | ConvertFrom-Json))
$resourceChecks = 0
foreach ($spec in $specs) {
    foreach ($entry in $spec.texts.PSObject.Properties) {
        $key = if ($entry.Name -like 'Resistance*') { $entry.Name } else { 'ForceTrace' + $entry.Name }
        foreach ($lcid in @('1033','2052')) {
            if ((Caption $lcid 'Station' $key) -cne $entry.Value.$lcid) { throw "Export differs from specification: $lcid $key" }
            $resourceChecks++
        }
    }
}
function Load-Page([string]$name) {
    $loader = New-Object VisiWinNET.Smart.SFCLoader
    $reader = New-Object Xml.XmlTextReader((Join-Path $station ('Hmi/SmartForms/17ad895f-b172-4b13-8b11-8fde8b79013f/' + $name + '.sfc')))
    $errors = New-Object Collections.ArrayList
    try { $view = $loader.Load($reader, (New-Object Collections.Hashtable), $null, $errors) } finally { $reader.Close() }
    if ($errors.Count) { throw ($errors | Out-String) }
    $view.Site = New-Object OfflineHmiSite($view)
    return @{loader=$loader;view=$view}
}
function Assert-Fits([string]$text, [Drawing.Font]$font, [int]$width) {
    $size = [Windows.Forms.TextRenderer]::MeasureText($text,$font,[Drawing.Size]::Empty,[Windows.Forms.TextFormatFlags]'NoPadding,NoPrefix,SingleLine')
    if ($size.Width -gt $width) { throw "Caption exceeds available width: $text ($($size.Width) > $width)" }
}
function Save-Preview($view, [string]$name) {
    $bitmap = New-Object Drawing.Bitmap($view.Width,$view.Height)
    try { $view.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0,0,$view.Width,$view.Height))); $bitmap.Save((Join-Path $OutputPath $name),[Drawing.Imaging.ImageFormat]::Png) }
    finally { $bitmap.Dispose() }
}
$resistance = Load-Page 'UserDefined'
$resistanceControls = @{}
$resistanceTextBindings = @{}
foreach ($position in @('Left','Middle','Right')) {
    foreach ($kind in @('Value','Pending','Status')) {
        $id = 'AI_Resistance' + $position + $kind
        $resistanceControls[$id] = $resistance.loader.Find($id)
        if ($null -eq $resistanceControls[$id]) { throw "Missing native resistance control: $id" }
    }
    # Preserve actual resource references before the offline language simulation replaces them.
    $valueText = $resistanceControls['AI_Resistance' + $position + 'Value'].Label.Text
    $pendingText = $resistanceControls['AI_Resistance' + $position + 'Pending'].LocalizedText
    $resistanceTextBindings[$position] = @{
        valueGroup=$valueText.TextGroup; valueKey=$valueText.Text
        pendingGroup=$pendingText.TextGroup; pendingKey=$pendingText.Text
    }
}
$tracePage = Load-Page 'ForceTrace'
$trace = $tracePage.loader.Find('ForceTrace')
$flags = [Reflection.BindingFlags]'Instance,NonPublic'
function Trace-Field([string]$name) { return $trace.GetType().GetField($name,$flags) }
function Set-TraceField([string]$name, $value) { (Trace-Field $name).SetValue($trace,$value) }
$status = (Trace-Field 'status').GetValue($trace)
$buttons = (Trace-Field 'positions').GetValue($trace)
$saveButton = (Trace-Field 'saveButton').GetValue($trace)
$chart = (Trace-Field 'chart').GetValue($trace)
$stateChecks = 0
$resistanceSequence = @()
try {
    foreach ($lcid in @('2052','1033','2052')) {
        foreach ($position in @('Left','Middle','Right')) {
            $value = $resistanceControls['AI_Resistance' + $position + 'Value']
            $pending = $resistanceControls['AI_Resistance' + $position + 'Pending']
            $state = $resistanceControls['AI_Resistance' + $position + 'Status']
            $textBinding = $resistanceTextBindings[$position]
            # In-memory rendering only. Project bindings remain untouched.
            $value.Label.Text.TextGroup = ''; $value.Label.Text.Text = Caption $lcid $textBinding.valueGroup $textBinding.valueKey
            $pending.LocalizedText.TextGroup = ''; $pending.LocalizedText.Text = Caption $lcid $textBinding.pendingGroup $textBinding.pendingKey
            Assert-Fits $value.Label.Text.DisplayText $value.Label.Font ([int]($value.Width * $value.Label.SizeRatio))
            Assert-Fits $pending.LocalizedText.DisplayText $pending.Font $pending.Width
            $value.Visible = $false; $state.Visible = $false; $pending.Visible = $true
        }
        Save-Preview $resistance.view ('resistance-pending-' + $lcid + '.png')
        foreach ($position in @('Left','Middle','Right')) {
            $resistanceControls['AI_Resistance' + $position + 'Pending'].Visible = $false
            $resistanceControls['AI_Resistance' + $position + 'Value'].Visible = $true
            $state = $resistanceControls['AI_Resistance' + $position + 'Status']
            $state.Visible = $true
            $state.LocalizedText.TextGroup = ''; $state.LocalizedText.Text = Caption $lcid 'NexeedStateAddon' $(if($position -eq 'Middle'){'Nok'}else{'Ok'})
            $resistanceSequence += [ordered]@{language=$lcid;fixturePosition=$position;completedCaption=$resistanceControls['AI_Resistance' + $position + 'Value'].Label.Text.DisplayText;result=$state.LocalizedText.DisplayText}
            Save-Preview $resistance.view ('resistance-after-' + $position + '-' + $lcid + '.png')
        }
        Save-Preview $resistance.view ('resistance-result-' + $lcid + '.png')
    }
    $time = [DateTimeOffset]::Parse('2026-09-11T07:00:00Z')
    foreach ($stateName in @('NoData','Running','Completed','Cancelled','ProcessFault','InvalidData','Disconnected','Capacity','NewCycle','Saving','Saved','SaveFailed')) {
        $trace.Store.BeginCycle('language-' + $stateName)
        if ($stateName -ne 'NoData') {
            $trace.Store.Start([Bpp.ForceTrace.TracePosition]::Left,$time,100)
            $null = $trace.Store.Observe($time.AddMilliseconds(100),0.1,200,[Bpp.ForceTrace.SampleQuality]::Good,0.1)
            if ($stateName -notin @('Running','Saving','Saved','SaveFailed')) { $trace.Store.End([Enum]::Parse([Bpp.ForceTrace.TraceEndReason],$stateName)) }
        }
        $trace.RefreshSamples()
        # Emulate completed asynchronous UI state without calling a live HMI or file dialog.
        Set-TraceField 'saving' ($stateName -eq 'Saving')
        Set-TraceField 'saveFailed' ($stateName -eq 'SaveFailed')
        Set-TraceField 'savedPath' $(if($stateName -eq 'Saved'){'test.csv'}else{$null})
        foreach ($lcid in @('2052','1033','2052')) {
            foreach ($entry in $specs[1].texts.PSObject.Properties) {
                $text = $trace.GetLocalizedText($entry.Name)
                $text.TextGroup = ''
                $text.Text = Caption $lcid 'Station' ('ForceTrace' + $entry.Name)
            }
            # No RefreshSamples/ApplyTexts call here: the existing native text event must update all captions.
            $expectedStatus = Caption $lcid 'Station' ('ForceTrace' + $stateName)
            if($stateName -eq 'Saved'){ $expectedStatus += '  test.csv' }
            if ($status.Text -cne $expectedStatus) { throw "Stale $stateName caption after $lcid event: $($status.Text)" }
            for($i=0;$i -lt 3;$i++) {
                $key=@('Left','Middle','Right')[$i]
                if($buttons[$i].Text -cne (Caption $lcid 'Station' ('ForceTrace'+$key))){throw 'Stale position caption'}
                Assert-Fits $buttons[$i].Text $buttons[$i].Font ($buttons[$i].Width-12)
            }
            $saveKey=if($stateName -eq 'Saving'){'Saving'}else{'Save'}
            if($saveButton.Text -cne (Caption $lcid 'Station' ('ForceTrace'+$saveKey)) -or $chart.XAxis.Title -cne (Caption $lcid 'Station' 'ForceTraceTimeAxis') -or $chart.Axes[0].Title -cne (Caption $lcid 'Station' 'ForceTraceForceAxis')){throw 'Stale button or axis caption'}
            Assert-Fits $saveButton.Text $saveButton.Font ($saveButton.Width-12)
            Assert-Fits $status.Text $status.Font $status.Width
            $stateChecks++
            if($stateName -in @('NoData','Completed','Disconnected','SaveFailed')){Save-Preview $trace ('force-' + $stateName + '-' + $lcid + '.png')}
        }
    }
    $connectionField = $trace.GetType().GetField('session',$flags)
    if ($null -eq $connectionField) { $connectionField = Trace-Field 'frameItem' }
    if($null -ne $connectionField.GetValue($trace)){throw 'Offline render attached a runtime session.'}
    [ordered]@{scope='Offline native controls with actual exported translations and simulated display states';exportedTextChecks=$resourceChecks;dynamicCaptionChecks=$stateChecks;sequence=@('zh','en','zh');resistanceTextBindings=$resistanceTextBindings;resistanceSequence=$resistanceSequence;nativeTextChangeHandlersVerified=$true;captionWidthsFit=$true;runtimeLanguageManagerVerified=$false;plcConnected=$false;assembly=$AssemblyPath} |
        ConvertTo-Json -Depth 5 | Tee-Object -FilePath (Join-Path $OutputPath 'localization-check.json')
} finally { $resistance.view.Dispose(); $tracePage.view.Dispose() }
