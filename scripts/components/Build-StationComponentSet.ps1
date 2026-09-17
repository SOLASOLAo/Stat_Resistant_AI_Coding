[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$NativeArtifactsPath,
    [Parameter(Mandatory)][string]$DestinationRoot
)
# A local, non-deploying colleague bundle using the existing component builder.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 required.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$destination = [IO.Path]::GetFullPath($DestinationRoot)
$allowed = [IO.Path]::GetFullPath((Join-Path $repo 'data/components')) + [IO.Path]::DirectorySeparatorChar
if (-not $destination.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($destination) -notmatch '^station010-set-[A-Za-z0-9.-]+$') { throw 'Use a new station010-set-* directory inside local data/components.' }
if (Test-Path -LiteralPath $destination) { throw 'Existing set is frozen; verify it or choose a new candidate destination.' }
$node = [IO.Path]::GetDirectoryName($destination)
while ($node.Length -ge $repo.Length) {
    if ((Test-Path -LiteralPath $node) -and ((Get-Item -LiteralPath $node).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Reparse-point destination rejected.' }
    if ($node -eq $repo) { break }
    $node = [IO.Path]::GetDirectoryName($node)
}
$lockPath = Join-Path $repo 'config/component-versions.json'
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
# The Station integration layer has its own version. Core packages stay frozen.
$referencePath = Join-Path $repo 'components/station010/reference.json'
if ((Get-FileHash -LiteralPath $referencePath).Hash -cne $lock.stationSet.referenceSha256) { throw 'Station reference manifest differs from the reviewed selection lock.' }
$reference = Get-Content -LiteralPath $referencePath -Raw | ConvertFrom-Json
if ($reference.schemaVersion -ne 1 -or $reference.version -cne $lock.stationSet.version -or
    $reference.guide -cne $lock.stationReference.guide) { throw 'Station reference version or guide mismatch.' }
$station = [IO.Path]::GetFullPath((Join-Path $repo '../Station010'))
$targets = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$referenceFiles = @()
foreach ($entry in $reference.files) {
    foreach ($relative in @($entry.path,$entry.target)) {
        if ($relative -notmatch '^[A-Za-z0-9_./-]+$' -or
            @($relative.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count) { throw 'Unsafe Station reference path.' }
    }
    if (-not $targets.Add($entry.target)) { throw 'Duplicate Station reference target.' }
    $base = switch ($entry.root) {
        'sidecar' { $repo }
        'station' {
            if ($entry.path -cne 'Hmi/SmartForms/17ad895f-b172-4b13-8b11-8fde8b79013f/UserDefined.sfc') { throw 'Only the reviewed own Station view is allowed from the Station export.' }
            $station
        }
        default { throw 'Unknown Station reference source root.' }
    }
    $source = [IO.Path]::GetFullPath((Join-Path $base $entry.path))
    $node = $source
    while ($node.Length -ge $base.Length) {
        if ((Get-Item -Force -LiteralPath $node).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse-point source rejected.' }
        if ($node -eq $base) { break }
        $node = [IO.Path]::GetDirectoryName($node)
    }
    $file = Get-Item -LiteralPath $source
    if ($file.PSIsContainer -or $file.Length -gt 1MB -or
        $file.Extension -notin @('.st','.xml','.json','.yaml','.md','.ps1','.sfc','.cpsds')) { throw 'Station reference must be bounded reviewed text; no native PLC library or full project.' }
    if ($file.Length -ne $entry.length -or (Get-FileHash -LiteralPath $source).Hash -cne $entry.sha256) { throw "Station reference drift: $($entry.path)" }
    $referenceFiles += [pscustomobject]@{entry=$entry;source=$source}
}
$grading = Get-Content -LiteralPath (Join-Path $repo $reference.gradingEvidence) -Raw | ConvertFrom-Json
if ($grading.after.projectSha256 -cne $lock.stationReference.plcProjectSha256 -or
    $grading.after.symbolSha256 -cne $lock.stationReference.symbolSha256 -or
    -not $grading.readbackMatches -or -not $grading.compile.completionObserved -or $grading.compile.errors -ne 0) { throw 'Prior Station grading evidence does not cover the locked export.' }
$packages = @()
foreach ($id in @('burster2316','kistler5867c','bpp-forcetrace')) {
    $result = & (Join-Path $PSScriptRoot 'Build-DeviceComponent.ps1') -Component $id -Command Build -NativeArtifactsPath $NativeArtifactsPath
    $verified = & (Join-Path $PSScriptRoot 'Test-ComponentPackage.ps1') -PackageRoot $result.Output
    if ($verified.ContentId -cne $result.ContentId) { throw 'Component changed after build.' }
    $packages += [pscustomobject]@{id=$id;result=$result;verified=$verified}
}
# Read only the existing Station export to produce its separate reference overlay.
foreach ($pair in @(
    @('Plc/Stat010_V5.11_CtrlX_PLC.project',$lock.stationReference.plcProjectSha256),
    @('Plc/Stat010_V5.11_CtrlX_PLC.Device.Application.xml',$lock.stationReference.symbolSha256),
    @('Hmi/OpCon.HMI.Modulo.Gui.config',$lock.stationReference.startupGuiSha256),
    @('Hmi/SmartForms/17ad895f-b172-4b13-8b11-8fde8b79013f/ForceTrace.sfc',$lock.stationReference.forceTraceViewSha256)
)) {
    if ((Get-FileHash -LiteralPath (Join-Path $station $pair[0])).Hash -cne $pair[1]) { throw 'Station reference changed; reconcile the selection lock first.' }
}
[void][IO.Directory]::CreateDirectory($destination)
foreach ($package in $packages) {
    $base = $package.result.Output
    $folder = Join-Path $destination ('packages/' + [IO.Path]::GetFileName($base))
    foreach ($file in Get-ChildItem -LiteralPath $base -File -Recurse) {
        $relative = $file.FullName.Substring($base.Length+1)
        $target = Join-Path $folder $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::Copy($file.FullName,$target,$false)
    }
    [void](& (Join-Path $PSScriptRoot 'Test-ComponentPackage.ps1') -PackageRoot $folder)
}
[void][IO.Directory]::CreateDirectory((Join-Path $destination 'Station010-reference'))
[IO.File]::Copy($lockPath,(Join-Path $destination 'Station010-reference/component-versions.json'),$false)
[IO.File]::Copy($referencePath,(Join-Path $destination 'Station010-reference/reference.json'),$false)
foreach ($item in $referenceFiles) {
    $target = Join-Path $destination ('Station010-reference/' + $item.entry.target)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
    [IO.File]::Copy($item.source,$target,$false)
    if ((Get-FileHash -LiteralPath $target).Hash -cne $item.entry.sha256) { throw 'Station reference changed during copy.' }
}
[IO.File]::Copy((Join-Path $repo $reference.guide),(Join-Path $destination 'README.md'),$false)
# Reuse the frozen verifier template; the combination inventory is already ordered.
# NLS (Windows PowerShell) and ICU (PowerShell 7) sort '-' and 's' differently.
# Generate this one ordering adaptation; retain every path/count/hash/reparse check.
$verifySource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Test-ComponentPackage.ps1'))
$legacyOrder = '($declared | Sort-Object { $_.path })'
if ([regex]::Matches($verifySource,[regex]::Escape($legacyOrder)).Count -ne 1) { throw 'Verifier template changed; review the combination ordering adaptation.' }
$verifySource = $verifySource.Replace($legacyOrder,'$declared')
[IO.File]::WriteAllText((Join-Path $destination 'Verify.ps1'),$verifySource,[Text.UTF8Encoding]::new($false))
[void](& (Join-Path $repo 'scripts/hmi/New-ForceTraceStartupOverlay.ps1') -GuiConfigPath (Join-Path $station 'Hmi/OpCon.HMI.Modulo.Gui.config') -ViewPath (Join-Path $station 'Hmi/SmartForms/17ad895f-b172-4b13-8b11-8fde8b79013f/ForceTrace.sfc') -AssemblyPath (Join-Path $NativeArtifactsPath 'Bpp.ForceTrace.dll') -OutputPath (Join-Path $destination 'Station010-reference/startup-overlay'))
# Reviewed project text deltas are pinned above. No credential-bearing VWN,
# Engineering_Data, security/config files, vendor DLLs or encrypted PLC project.
$set = [ordered]@{
    kind='Station010 local development component set'
    componentVersions=@($packages | ForEach-Object { [ordered]@{id=$_.id;version=$_.result.Version;contentId=$_.result.ContentId;nativeLibrary=$_.result.NativeLibrary} })
    sourceCommit=$lock.components.burster2316.sourceRevision
    sourceState='Dirty snapshots explicitly pinned per component'
    stationSetVersion=$lock.stationSet.version
    stationReferenceManifestSha256=$lock.stationSet.referenceSha256
    stationSourceRevision=$reference.sourceRevision
    stationSourceSnapshot='Uncommitted source pinned by reference.json file hashes; not a release commit'
    rootVerifierOrdering='Hash the declared inventory order; frozen verifier template with only re-sorting removed for Windows PowerShell 5 / PowerShell 7 portability'
    stationReference=$lock.stationReference
    newPlcCompile=$false
    priorPlcCompile=[ordered]@{evidence='Station010-reference/evidence/resistance-grading.json';requestedAtUtc=$grading.compile.requestedAtUtc;projectSha256=$grading.after.projectSha256;errors=$grading.compile.errors;warnings=$grading.compile.warnings;scope='Earlier fresh Station F11 with exact matching saved project; not an independent library consumer build'}
    nativeBursterConsumer='Previously failed; no failed compiled-library included; current Station010 PLE preserved'
    hmiEvidence=('packages/bpp-forcetrace-' + $lock.components.'bpp-forcetrace'.version + '/specs/hmi/force_trace_build_evidence.json')
    packagingValidation='Station010-reference/evidence/packaging-validation.json'
    deployment=$false
    githubChange=$false
}
$set | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $destination 'BUILD-EVIDENCE.json') -Encoding utf8
$entries = @(Get-ChildItem -LiteralPath $destination -File -Recurse | ForEach-Object {
    [ordered]@{path=$_.FullName.Substring($destination.Length+1).Replace('\','/');length=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
} | Sort-Object { $_.path })
$lines = @($entries | ForEach-Object { "$($_.path)|$($_.length)|$($_.sha256)" })
$contentId = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($lines -join "`n")+"`n")))
$manifest = [ordered]@{schemaVersion=1;component='station010-component-set';version=$lock.stationSet.version;releaseEligible=$false;developmentSnapshot=$true;payload=[ordered]@{contentId=$contentId;fileCount=$entries.Count;files=$entries}}
$manifest | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $destination 'ARTIFACT-MANIFEST.json') -Encoding utf8
$verified = & (Join-Path $PSScriptRoot 'Test-ComponentPackage.ps1') -PackageRoot $destination
# Verify the delivered entry point on both supported receiving shells.
[void](& (Join-Path $destination 'Verify.ps1') -PackageRoot $destination)
$windowsPowerShell = Join-Path $env:WINDIR 'SysWOW64/WindowsPowerShell/v1.0/powershell.exe'
$receiverCheck = & $windowsPowerShell -NoProfile -NonInteractive -File (Join-Path $destination 'Verify.ps1') -PackageRoot $destination 2>&1
if ($LASTEXITCODE -ne 0) { throw ('Windows PowerShell receiver verification failed: ' + ($receiverCheck -join "`n")) }
[pscustomobject]@{Status=$verified.Status;Output=$destination;ContentId=$contentId;Files=$verified.Files;Installed=$false;Deployed=$false}
