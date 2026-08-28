[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Start', 'Stop', 'Status', 'Logs')]
    [string]$Command = 'Status',

    [Parameter(Mandatory = $false)]
    [Alias('ProjectRoot', 'RepositoryRoot')]
    [string]$EngineeringRoot,

    [Parameter(Mandatory = $false)]
    [switch]$DevelopmentProcess
)

$implementation = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\ctrlx-ai-coding\templates\ctrlx-opcon-project\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1'))
if (-not [System.IO.File]::Exists($implementation)) {
    throw "Runner Host implementation is missing: $implementation"
}

if (-not $EngineeringRoot) {
    $EngineeringRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

& $implementation `
    -Command $Command `
    -EngineeringRoot $EngineeringRoot `
    -DevelopmentProcess:$DevelopmentProcess `
    -WhatIf:$WhatIfPreference
