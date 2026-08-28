#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sharedTest = Join-Path $root 'ctrlx-ai-coding\templates\ctrlx-opcon-project\tests\cpstudio\Test-ApprovePostExportBaselines.ps1'
$approvalScript = Join-Path $root 'scripts\cpstudio\Approve-PostExportBaselines.ps1'
& $sharedTest -ApprovalScript $approvalScript
