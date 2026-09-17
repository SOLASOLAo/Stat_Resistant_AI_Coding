[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$builder = Join-Path $repo 'scripts/components/Build-DeviceComponent.ps1'
$utf8 = [Text.UTF8Encoding]::new($false)
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('Bpp-ComponentTest-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixture
$checks = 0
function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $caught = $false
    try { & $Action | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        $caught = $true
    }
    Assert-That $caught "Expected rejection: $Pattern"
}
function Save-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), $utf8)
}
try {
    # Only bounded, declared text fixtures; no Station, PLE, sockets or native library files.
    $paths = @('components/README.md', 'config/component-versions.json')
    foreach ($id in @('burster2316', 'kistler5867c')) {
        $manifest = Get-Content -LiteralPath (Join-Path $repo "components/$id/component.json") -Raw | ConvertFrom-Json
        $paths += @("components/$id/component.json", "components/$id/README.md")
        $paths += @($manifest.files.path)
    }
    foreach ($path in ($paths | Sort-Object -Unique)) {
        $target = Join-Path $fixture $path
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::Copy((Join-Path $repo $path), $target)
    }
    & git -C $fixture init --quiet
    if ($LASTEXITCODE) { throw 'Fixture Git init failed.' }
    & git -C $fixture -c core.autocrlf=false add -- $paths
    if ($LASTEXITCODE) { throw 'Fixture Git staging failed.' }
    & git -C $fixture -c user.name=ComponentTest -c user.email=component-test@example.invalid -c core.hooksPath=NUL -c commit.gpgsign=false commit --quiet -m 'Offline fixture'
    if ($LASTEXITCODE) { throw 'Fixture Git commit failed.' }
    $revision = (& git -C $fixture rev-parse HEAD).Trim()
    $lockPath = Join-Path $fixture 'config/component-versions.json'
    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json -AsHashtable
    foreach ($id in @('burster2316', 'kistler5867c')) {
        $path = Join-Path $fixture "components/$id/component.json"
        $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        # Retain the original commit-only schema regression separately from
        # the new explicit dirty-snapshot checks below.
        $manifest.schemaVersion = 1
        $manifest.version = '0.1.0-rc.1'
        $manifest.releaseTag = "$id-v0.1.0-rc.1"
        $manifest.sourceRevision = $revision
        Save-Json $path $manifest
        $lock.components[$id].sourceRevision = $revision
        $lock.components[$id].version = '0.1.0-rc.1'
    }
    Save-Json $lockPath $lock
    foreach ($id in @('burster2316', 'kistler5867c')) {
        $result = & $builder -Component $id -RepositoryRoot $fixture
        Assert-That ($result.Status -eq 'VALID' -and -not $result.OnlineAction) 'Read-only check failed.'
    }
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $fixture 'data'))) 'Check must not create output.'

    $manifestPath = Join-Path $fixture 'components/burster2316/component.json'
    $originalManifest = [IO.File]::ReadAllText($manifestPath)
    $manifest = $originalManifest | ConvertFrom-Json -AsHashtable
    $manifest.version = '0.1.0-rc.2'
    $manifest.releaseTag = 'burster2316-v0.1.0-rc.2'
    Save-Json $manifestPath $manifest
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'selection lock'
    [IO.File]::WriteAllText($manifestPath, $originalManifest, $utf8)

    $manifest = $originalManifest | ConvertFrom-Json -AsHashtable
    $manifest.files[0].path = 'src/plc/../../../outside.st'
    Save-Json $manifestPath $manifest
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'Unsafe package path'
    [IO.File]::WriteAllText($manifestPath, $originalManifest, $utf8)

    $manifest = $originalManifest | ConvertFrom-Json -AsHashtable
    $manifest.files += $manifest.files[0]
    Save-Json $manifestPath $manifest
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'Duplicate payload'
    [IO.File]::WriteAllText($manifestPath, $originalManifest, $utf8)

    $manifest = $originalManifest | ConvertFrom-Json -AsHashtable
    $manifest.nativeLibrary.status = 'compiled'
    Save-Json $manifestPath $manifest
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'native-library boundary'
    [IO.File]::WriteAllText($manifestPath, $originalManifest, $utf8)

    $driverPath = Join-Path $fixture 'src/plc/project/Station010/FB_Wp100BursterSingleOwner.st'
    $driverBytes = [IO.File]::ReadAllBytes($driverPath)
    [IO.File]::AppendAllText($driverPath, "`n// changed candidate`n", $utf8)
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'source drift'
    [IO.File]::WriteAllBytes($driverPath, $driverBytes)

    foreach ($id in @('burster2316', 'kistler5867c')) {
        $result = & $builder -Component $id -Command Build -RepositoryRoot $fixture
        Assert-That ($result.Status -eq 'BUILT') 'First build should create a new package.'
        $again = & $builder -Component $id -Command Build -RepositoryRoot $fixture
        Assert-That ($again.Status -eq 'UNCHANGED') 'Identical version must be reusable without overwrite.'
        $files = @(Get-ChildItem -LiteralPath $result.Output -Recurse -File)
        Assert-That ($files.Count -eq $result.Files) 'Package inventory/count mismatch.'
        Assert-That (@($files | Where-Object Extension -in @('.project', '.library', '.compiled-library', '.pdf', '.zip')).Count -eq 0) 'Prohibited binary/vendor file in package.'
    }
    $output = Join-Path $fixture 'data/components/burster2316-0.1.0-rc.1'
    $readme = Join-Path $output 'README.md'
    [IO.File]::AppendAllText($readme, "`nmodified package`n", $utf8)
    $changed = [IO.File]::ReadAllText($readme)
    Expect-Failure { & $builder -Component burster2316 -Command Build -RepositoryRoot $fixture } 'Different content'
    Assert-That ([IO.File]::ReadAllText($readme) -ceq $changed) 'Existing package must not be overwritten.'
    [IO.File]::WriteAllText((Join-Path $output 'unexpected.txt'), 'fixture only', $utf8)
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'unexpected files'

    # A development snapshot is explicit and bounded: it accepts reviewed
    # dirty bytes, rejects any further drift, and verifies offline without Git.
    [IO.File]::WriteAllBytes($driverPath, $driverBytes)
    $manifest = $originalManifest | ConvertFrom-Json -AsHashtable
    $manifest.schemaVersion = 2
    $manifest.version = '0.1.0-rc.2'
    $manifest.releaseTag = 'burster2316-v0.1.0-rc.2'
    [IO.File]::AppendAllText($driverPath, "`n// reviewed development snapshot`n", $utf8)
    $lines = @(foreach ($entry in ($manifest.files | Sort-Object { $_.path })) {
        $file = Join-Path $fixture $entry.path
        $entry.sha256 = (Get-FileHash -LiteralPath $file).Hash
        "$($entry.path)|$((Get-Item -LiteralPath $file).Length)|$($entry.sha256)"
    })
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes(($lines -join "`n")+"`n")))
    $manifest.sourceSnapshot = @{sha256=$digest;dirty=$true}
    $lock.components.burster2316.version = $manifest.version
    $lock.components.burster2316.sourceSnapshotSha256 = $digest
    Save-Json $manifestPath $manifest
    Save-Json $lockPath $lock
    $candidate = & $builder -Component burster2316 -Command Build -RepositoryRoot $fixture
    Assert-That ($candidate.Status -eq 'BUILT' -and $candidate.ContentId.Length -eq 64) 'Dirty candidate was not bound to a payload digest.'
    $verify = Join-Path $repo 'scripts/components/Test-ComponentPackage.ps1'
    Assert-That ((& $verify -PackageRoot $candidate.Output).ContentId -ceq $candidate.ContentId) 'Standalone recipient verification failed.'
    [IO.File]::AppendAllText($driverPath, "`n// unreviewed extra change`n", $utf8)
    Expect-Failure { & $builder -Component burster2316 -RepositoryRoot $fixture } 'source drift'
    $candidateFile = Join-Path $candidate.Output 'src/plc/project/Station010/FB_Wp100BursterSingleOwner.st'
    [IO.File]::AppendAllText($candidateFile,"`n// changed after packaging`n",$utf8)
    Expect-Failure { & $verify -PackageRoot $candidate.Output } 'Package content changed'
    Write-Output "PASS: $checks component packaging checks; no PLE or device access."
} finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolvedFixture) -notmatch '^Bpp-ComponentTest-[a-f0-9]{32}$') {
        throw 'Refusing cleanup outside the exact temporary test fixture.'
    }
    if (Test-Path -LiteralPath $resolvedFixture) { Remove-Item -LiteralPath $resolvedFixture -Recurse -Force }
}
