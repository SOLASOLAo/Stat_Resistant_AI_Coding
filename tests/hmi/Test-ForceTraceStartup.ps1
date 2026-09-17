param([Parameter(Mandatory)][string]$AssemblyPath, [Parameter(Mandatory)][string]$OutputPath, [string]$RuntimePath)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $RuntimePath) { $RuntimePath = Join-Path $repo '../Std/Hmi_V5_11' }
$runtime = [IO.Path]::GetFullPath($RuntimePath)
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
foreach ($name in @('VisiWinNET.Embedded.Systems.dll','VisiWinNET.Embedded.Forms.dll','OpCon.HMI.Modulo.Shared.dll','OpCon.HMI.Modulo.Forms.dll','TeeChart.dll')) {
  [void][Reflection.Assembly]::LoadFrom((Join-Path $runtime $name))
}
[void][Reflection.Assembly]::LoadFrom($AssemblyPath)
[void][Reflection.Assembly]::LoadFrom('C:\Nexeed\Automation\CSV5_11\OpCon\VisiWinNET.SFCLoader.dll')
$flags = [Reflection.BindingFlags]'Instance,NonPublic'
# No project or channel is started. The isolated test item cannot name a device.
$template = [xml][IO.File]::ReadAllText((Join-Path $repo 'src/hmi/Bpp.ForceTrace/ForceTraceStartup.sfc'))
$template.SelectSingleNode('//*[local-name()="ForceTraceStartupForm"]').SetAttribute('FrameItemName','Offline.NoDevice.ForceFrame')
$offlineTemplate = Join-Path $OutputPath 'ForceTraceStartup.Offline.sfc'
[void][IO.Directory]::CreateDirectory($OutputPath)
$template.Save($offlineTemplate)
$escapedPath = [Security.SecurityElement]::Escape($offlineTemplate)
$gui = '<SmartForms><SmartForm name="OfflineForceTraceStartup" file="' + $escapedPath + '" loadOnStartup="True" executeCode="False" /></SmartForms>'
$reader = New-Object Xml.XmlTextReader((New-Object IO.StringReader($gui)))
try {
  [void]$reader.MoveToContent()
  # Supply only a local project-directory fixture; do not start the native
  # project manager or any data system/channel merely to resolve this path.
  $systemInfo = [VisiWinNET.Forms.ProjectForms].Assembly.GetType('VisiWinNET.Forms.Internals.SystemInfo',$true)
  $systemInfo.GetField('m_ProjectPath',[Reflection.BindingFlags]'NonPublic,Static').SetValue($null,$OutputPath)
  # Load is gated by this flag in a normal ProjectForms.Initialize. Set only
  # that local fixture flag to test preloading without opening real channels.
  [VisiWinNET.Forms.ProjectForms].GetField('m_bInitialized',[Reflection.BindingFlags]'NonPublic,Static').SetValue($null,$true)
  # Exercise the installed runtime's own Gui.config preload path in this
  # isolated process. No product code uses reflection into the native runtime.
  $readGui = [VisiWinNET.Forms.ProjectForms].GetMethod('ReadGuiConfiguration',[Reflection.BindingFlags]'NonPublic,Static')
  $arguments = New-Object object[] 1
  $arguments[0] = $reader.PSObject.BaseObject
  try { [void]$readGui.Invoke($null,$arguments) }
  catch { throw $_.Exception.GetBaseException().ToString() }
} finally { $reader.Close() }
$loaded = @([VisiWinNET.Forms.ProjectForms]::LoadedForms | Where-Object { $_ -is [Bpp.ForceTrace.ForceTraceStartupForm] })
if ($loaded.Count -ne 1) { throw 'Native loadOnStartup did not preload exactly one form.' }
$startup = $loaded[0]
if ($startup -isnot [Bpp.ForceTrace.ForceTraceStartupForm] -or $startup.Visible) { throw 'Startup must be a loaded, hidden native SmartForm.' }
$session = $startup.GetType().GetField('session',$flags).GetValue($startup)
if ($null -eq $session -or -not $session.GetType().GetField('started',$flags).GetValue($session)) { throw 'Native preload did not start recording before the chart opened.' }
$adapter = $session.GetType().GetField('Frames',$flags).GetValue($session)
$store = $session.GetType().GetField('Store',$flags).GetValue($session)
$clock = $session.GetType().GetField('clock',$flags).GetValue($session)
$sequence = 0
$time = [DateTimeOffset]::Parse('2026-09-11T08:00:00Z')
function Send-Frame([uint32]$position,[uint32]$acquisition,[uint32]$state,[uint32]$elapsed,[single]$force) {
  $script:sequence++
  $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes($force),0)
  [uint32[]]$words = @($script:sequence,1,1,$acquisition,$position,$state,$elapsed,$bits,0,($script:sequence*100),1,42,0,$script:sequence)
  [uint32]$hash = 2166136261
  for ($i=0;$i -lt 12;$i++) { $hash = [uint32](([uint64]($hash -bxor $words[$i])*16777619) -band [uint64]4294967295) }
  $words[12] = $hash
  $adapter.Observe($words,$true,$time.AddMilliseconds($script:sequence*100),$clock.ElapsedMilliseconds)
}
$views = New-Object Collections.ArrayList
try {
  Send-Frame 0 0 0 0 0
  foreach ($position in 1..3) {
    Send-Frame $position $position 1 0 0
    Send-Frame $position $position 1 100 100
    Send-Frame $position $position 2 200 200
  }
  # Only now create the first chart, reproducing the reported late-open order.
  foreach ($opening in 1..2) {
    $view = New-Object Bpp.ForceTrace.ForceTraceView
    [void]$views.Add($view)
    $view.FrameItemName = 'Offline.NoDevice.ForceFrame'
    $view.GetType().GetMethod('OnLoad',$flags).Invoke($view,@([EventArgs]::Empty))
    if (-not [object]::ReferenceEquals($view.Store,$store)) { throw 'Chart owns a second recording store.' }
    foreach ($position in 1..3) {
      $view.SelectPosition([Bpp.ForceTrace.TracePosition]$position)
      $snapshot = $view.DisplayedSnapshot
      if ($null -eq $snapshot -or $snapshot.Samples.Count -ne 3 -or $snapshot.EndReason -ne 'Completed') { throw "Late-open/reopen lost position $position." }
    }
    $view.Dispose()
  }
  # The view's disposal must not stop the startup-owned session.
  if (-not $session.GetType().GetField('started',$flags).GetValue($session)) { throw 'Closing the view stopped background recording.' }
  $result = [ordered]@{scope='Native Gui.config preload with synthetic wire frames and local initialized/path fixtures; no project/channel/device started';nativeGuiPreload=$true;nativeHiddenStartup=$true;recordingStartedBeforeView=$true;positionsRecordedBeforeView=3;lateOpenAndReopenPreserveAllPositions=$true;singleSharedStore=$true;plcConnected=$false;assembly=$AssemblyPath;assemblySha256=(Get-FileHash -LiteralPath $AssemblyPath -Algorithm SHA256).Hash}
  $result | ConvertTo-Json -Depth 4 | Tee-Object -FilePath (Join-Path $OutputPath 'startup-check.json')
} finally {
  foreach ($view in $views) { $view.Dispose() }
  if ($startup) { $startup.Dispose() }
}
