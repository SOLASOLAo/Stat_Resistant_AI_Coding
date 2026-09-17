param([string]$RepoPath,[string]$RuntimePath,[string]$OutputPath,[string]$AssemblyPath,[string]$SfcPath,
      [string]$ExpectedItemPrefix='Ch1.L1.Station.',[switch]$ComponentFrames,[int]$ViewportHeight=572)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[ComponentModel.LicenseManager]::CurrentContext=New-Object ComponentModel.Design.DesigntimeLicenseContext
foreach($name in @('VisiWinNET.Embedded.Systems.dll','VisiWinNET.Embedded.Forms.dll','OpCon.HMI.Modulo.Shared.dll','OpCon.HMI.Modulo.Forms.dll','TeeChart.dll')){$null=[Reflection.Assembly]::LoadFrom((Join-Path $RuntimePath $name))}
if(-not $AssemblyPath){$AssemblyPath=Join-Path $OutputPath 'ForceTrace.Hmi.dll'}
if(-not $SfcPath){$SfcPath=Join-Path $RepoPath 'src/hmi/ForceTrace.Hmi/ForceTrace.sfc'}
$null=[Reflection.Assembly]::LoadFrom($AssemblyPath)
# The standalone fixture uses normal .NET probing beside its executable.
$fixtureAssembly=Join-Path $OutputPath 'ForceTrace.Hmi.dll'
if([IO.Path]::GetFullPath($AssemblyPath) -ine [IO.Path]::GetFullPath($fixtureAssembly)){Copy-Item -LiteralPath $AssemblyPath -Destination $fixtureAssembly}
$fixture=Join-Path $OutputPath 'ForceTraceFrameTests.exe'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" /nologo /codepage:65001 "/out:$fixture" "/r:$AssemblyPath" (Join-Path $RepoPath 'tests/hmi/ForceTraceFrameTests.cs')
if($LASTEXITCODE -ne 0){throw 'Frame test compilation failed.'}
& $fixture
if($LASTEXITCODE -ne 0){throw 'Frame / CSV tests failed.'}
$null=[Reflection.Assembly]::LoadFrom($fixture)
$null=[Reflection.Assembly]::LoadFrom('C:\Nexeed\Automation\CSV5_11\OpCon\VisiWinNET.SFCLoader.dll')
$loader=New-Object VisiWinNET.Smart.SFCLoader
$reader=New-Object Xml.XmlTextReader($SfcPath)
$loaderErrors=New-Object Collections.ArrayList
try{$root=$loader.Load($reader,(New-Object Collections.Hashtable),$null,$loaderErrors)}finally{$reader.Close()}
if($loaderErrors.Count){throw ($loaderErrors|Out-String)}
$view=$loader.Find('ForceTrace')
if($view -isnot [ForceTrace.Hmi.ForceTraceView]){throw 'Native view missing.'}
$bindings=[ordered]@{LeftTraceItem='HMIForceTraceLeft';MiddleTraceItem='HMIForceTraceMiddle';RightTraceItem='HMIForceTraceRight';StatisticsItem='HMIForceStatistics'}
if($ComponentFrames){$bindings=[ordered]@{LeftTraceItem='LeftFrame';MiddleTraceItem='MiddleFrame';RightTraceItem='RightFrame';StatisticsItem='StatisticsFrame'}}
foreach($key in @($bindings.Keys)){$bindings[$key]=$ExpectedItemPrefix+$bindings[$key];if($view.$key.Name -cne $bindings[$key]){throw "Incorrect $key : $($view.$key.Name)"};$property=[ComponentModel.TypeDescriptor]::GetProperties($view)[$key];if(-not $property.GetEditor([Drawing.Design.UITypeEditor])){throw "Native picker unavailable for $key"}}
$native=@($view.Controls|Where-Object {$_ -is [Bosch.OpCon.HMI.Modulo.Forms.Mod_Chart]})[0]
$line=$native.Axes[0].Channels[0].Line
$line.Add(0,1234);$view.RefreshSamples()
if($native.Visible -or $line.Count){throw 'Empty view retains demonstration data.'}
$adapter=New-Object ForceTrace.Hmi.ForceTraceFrames($view.Store)
$time=[DateTimeOffset]::Parse('2026-09-15T10:00:00Z')
$adapter.ObserveStatistics([ForceTraceFixture]::Statistics(1,1,2,$false),$true,0)
$adapter.ObserveTrace([ForceTraceFixture]::Trace(1,1,2,2001,668),$true,[ForceTrace.Hmi.TracePosition]::Left,$time)
$view.RefreshSamples()
$snapshot=$view.DisplayedSnapshot
if($snapshot.Samples.Count -ne 2001 -or $line.Count -ne 2001){throw 'Late-open native point count differs.'}
for($i=0;$i -lt $line.Count;$i++){if($line.XValues[$i] -ne $snapshot.Samples[$i].ElapsedSeconds -or $line.YValues[$i] -ne $snapshot.Samples[$i].ForceN){throw 'PLC-native coordinates differ.'}}
# Completed records are republished with a new sequence. Simulate torn arrivals
# between good heartbeats: the actual Mod_Chart must never become empty or rebuild.
$refreshTrace=[ForceTraceFixture]::Trace(1,1,2,2001,668)
for($refresh=0;$refresh -lt 50;$refresh++){
 $refreshTrace[0]++;[ForceTraceFixture]::TraceHash($refreshTrace)
 $tornTrace=[uint32[]]$refreshTrace.Clone();$tornTrace[30035]++
 $adapter.ObserveTrace($tornTrace,$true,[ForceTrace.Hmi.TracePosition]::Left,$time);$view.RefreshSamples()
 if(-not [Object]::ReferenceEquals($snapshot,$view.DisplayedSnapshot) -or $line.Count -ne 2001){throw 'Torn frame clears native chart.'}
 $adapter.ObserveTrace($refreshTrace,$true,[ForceTrace.Hmi.TracePosition]::Left,$time);$view.RefreshSamples()
 if(-not [Object]::ReferenceEquals($snapshot,$view.DisplayedSnapshot) -or $line.Count -ne 2001){throw 'Completed heartbeat rebuilds native chart.'}
}
$view.SaveDirectory=Join-Path $OutputPath 'csv'
foreach($range in @([ForceTrace.Hmi.TraceSaveRange]::Full,[ForceTrace.Hmi.TraceSaveRange]::AfterStable)){$file=$view.SaveDisplayedAsync($range).GetAwaiter().GetResult();if([IO.File]::ReadAllText($file) -cne [ForceTrace.Hmi.ForceTraceCsv]::ToCsv($snapshot,$range)){throw 'Saved snapshot differs.'}}
$translations=Get-Content -LiteralPath (Join-Path $RepoPath 'specs/hmi/force_trace_texts.json') -Raw -Encoding UTF8|ConvertFrom-Json
# Match the smaller runtime viewport, not only the taller designer canvas.
$view.Size=New-Object Drawing.Size(944,$ViewportHeight)
$bitmap=New-Object Drawing.Bitmap(944,$ViewportHeight)
try{
 foreach($language in @('1033','2052')){
  foreach($entry in $translations.texts.PSObject.Properties){if($entry.Name -in @('Disconnected','Capacity','NewCycle')){continue};$t=$view.GetLocalizedText($entry.Name);$t.TextGroup='';$t.Text=$entry.Value.$language}
  $view.RefreshSamples()
  $notes=@($view.Controls|Where-Object {$_.Name -eq 'SamplingNotes'})[0]
  if(-not $notes -or -not $notes.Text.Contains('6 ms') -or -not $notes.Text.Contains('1000 ms') -or -not $notes.Text.Contains('2500 N') -or -not $notes.Text.Contains('30 N')){throw 'Sampling rules are not bound to the displayed PLC record.'}
  $preferred=$notes.GetPreferredSize((New-Object Drawing.Size($notes.Width,0)))
  if($preferred.Height -gt $notes.Height){throw "Sampling rules clipped in language $language : $($preferred.Height) > $($notes.Height)"}
  if($notes.Bottom -gt $view.ClientSize.Height -or $notes.Right -gt $view.ClientSize.Width){throw 'Sampling rules extend beyond the exported view.'}
  $view.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,944,$ViewportHeight)));$bitmap.Save((Join-Path $OutputPath "preview-$language.png"),[Drawing.Imaging.ImageFormat]::Png)
 }
 # A retained force curve with no eligible statistics must show the specific
 # statistics message, while the description uses that position's parameters.
 $emptyStats=[ForceTraceFixture]::Statistics(1,1,4,$false);$emptyStats[0]=100;$emptyStats[7]=10
 $emptyStats[19]=0;$emptyStats[20]=9
 foreach($index in (22..26 + 32..37 + 39..58)){$emptyStats[$index]=0}
 $emptyStats[27]=[ForceTraceFixture]::Bits(2559);$emptyStats[28]=[ForceTraceFixture]::Bits(10);$emptyStats[60]=10
 [ForceTraceFixture]::StatsHash($emptyStats);$adapter.ObserveStatistics($emptyStats,$true,100);$view.RefreshSamples()
 if(-not $view.DisplayedSnapshot -or -not $notes.Text.Contains('10 ms') -or -not $notes.Text.Contains('2559 N')){throw 'Empty statistics hides retained curve or loses dynamic parameters.'}
 $view.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,944,$ViewportHeight)));$bitmap.Save((Join-Path $OutputPath 'preview-no-statistics.png'),[Drawing.Imaging.ImageFormat]::Png)
 $adapter.CheckTimeout(601);$view.RefreshSamples();if($view.DisplayedSnapshot -or $line.Count){throw 'Disconnected curve remains live.'}
 $view.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,944,$ViewportHeight)));$bitmap.Save((Join-Path $OutputPath 'preview-disconnected.png'),[Drawing.Imaging.ImageFormat]::Png)
 [ordered]@{scope='Offline native loader/Mod_Chart/PLC frame fixtures; no PLC connection';assembly=[Reflection.AssemblyName]::GetAssemblyName($AssemblyPath).FullName;points=2001;sfc_loader_errors=$loaderErrors.Count;native_item_pickers=4;bindings=$bindings;two_csv_ranges_match=$true;late_open_complete_curve=$true;refresh_cycles=50;torn_frame_keeps_chart=$true;completed_heartbeat_keeps_snapshot=$true;statistics_timeout_clears_chart=$true;sampling_rules_bilingual=$true;sampling_rules_use_record_parameters=$true;sampling_rules_inside_exported_view=$true;empty_statistics_keeps_force_curve=$true;runtime_language_switch=$false;output=$OutputPath}|ConvertTo-Json|Tee-Object -FilePath (Join-Path $OutputPath 'native-check.json')
}finally{$bitmap.Dispose();$root.Dispose()}
