[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Alias('ProjectRoot', 'RepositoryRoot')]
    [string]$EngineeringRoot,

    [Parameter(Mandatory = $false)]
    [switch]$SmokeTest,

    [Parameter(Mandatory = $false)]
    [switch]$NoBuild
)

$implementation = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\ctrlx-ai-coding\templates\ctrlx-opcon-project\scripts\workbench\Start-CtrlXOpconWorkbench.ps1'))
if (-not [System.IO.File]::Exists($implementation)) {
    throw "Engineering Console launcher implementation is missing: $implementation"
}

if (-not $EngineeringRoot) {
    $EngineeringRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

& $implementation `
    -EngineeringRoot $EngineeringRoot `
    -SmokeTest:$SmokeTest `
    -NoBuild:$NoBuild
