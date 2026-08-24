[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$failures = [Collections.Generic.List[string]]::new()

function Read-RepositoryText {
  param([Parameter(Mandatory)][string]$RelativePath)

  $path = Join-Path $repositoryRoot $RelativePath
  if (-not [IO.File]::Exists($path)) {
    $failures.Add("Missing guidance artifact: $RelativePath")
    return ''
  }
  return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
}

function Assert-ContainsText {
  param(
    [Parameter(Mandatory)][string]$RelativePath,
    [Parameter(Mandatory)][string]$Expected
  )

  $text = Read-RepositoryText $RelativePath
  if (-not $text.Contains($Expected)) {
    $failures.Add("Missing '$Expected' in $RelativePath")
  }
}

function Assert-DoesNotContainText {
  param(
    [Parameter(Mandatory)][string]$RelativePath,
    [Parameter(Mandatory)][string]$Forbidden
  )

  $text = Read-RepositoryText $RelativePath
  if ($text.Contains($Forbidden)) {
    $failures.Add("Unexpected '$Forbidden' in $RelativePath")
  }
}

$enumSpecPath = 'specs\hmi\auto_info_line.yaml'
$enumSpec = Read-RepositoryText $enumSpecPath
$indices = @([regex]::Matches($enumSpec, '(?m)^\s+- index:\s*(?<index>\d+)\s*$') |
    ForEach-Object { [int]$_.Groups['index'].Value })
if (($indices -join ',') -ne ((0..16) -join ',')) {
  $failures.Add("AutoInfoLineEnum indices must remain append-only and contiguous 0..16; found $($indices -join ',')")
}

$expectedEnumNames = @(
  'USER_INFO_MOVE_FIXTURE_LEFT',
  'USER_INFO_MOVE_FIXTURE_MIDDLE',
  'USER_INFO_MOVE_FIXTURE_RIGHT',
  'USER_INFO_PRESS_START_LEFT',
  'USER_INFO_PRESS_START_MIDDLE',
  'USER_INFO_PRESS_START_RIGHT',
  'USER_INFO_CLOSING_SAFETY_DOOR',
  'USER_INFO_MEASURING_LEFT',
  'USER_INFO_MEASURING_MIDDLE',
  'USER_INFO_MEASURING_RIGHT',
  'USER_INFO_RETURN_SAFE_POSITION',
  'USER_INFO_OPENING_SAFETY_DOOR',
  'USER_INFO_MEASUREMENT_COMPLETE'
)
$allRunSource = @(
  Get-ChildItem (Join-Path $repositoryRoot 'src\plc\project\Station010\SqC_Wp100_Run') -Recurse -File -Filter '*.st'
  Get-ChildItem (Join-Path $repositoryRoot 'src\plc\project\Station010\SqS_Wp100_Run') -Recurse -File -Filter '*.st'
) | ForEach-Object { [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8) }
$allRunSource = $allRunSource -join "`n"
foreach ($name in $expectedEnumNames) {
  if (-not $enumSpec.Contains("name: $name")) {
    $failures.Add("Enum specification is missing $name")
  }
  if (-not $allRunSource.Contains("AutoInfoLineEnum.$name")) {
    $failures.Add("Prepared Run source does not use $name")
  }
}

$waitActions = [ordered]@{
  N015 = [ordered]@{ Prompt = 'USER_INFO_MOVE_FIXTURE_LEFT'; True = '_100B601'; False = @('_100B602', '_100B603') }
  N045 = [ordered]@{ Prompt = 'USER_INFO_MOVE_FIXTURE_MIDDLE'; True = '_100B602'; False = @('_100B601', '_100B603') }
  N075 = [ordered]@{ Prompt = 'USER_INFO_MOVE_FIXTURE_RIGHT'; True = '_100B603'; False = @('_100B601', '_100B602') }
}
foreach ($entry in $waitActions.GetEnumerator()) {
  $relativePath = "src\plc\project\Station010\SqC_Wp100_Run\actions\$($entry.Key).st"
  foreach ($expected in @(
      'Wp100K101SafetyDoor.Unit.OutImm.IsInBasPos',
      'Wp100K102PressingCylinder.Unit.OutImm.IsInBasPos',
      "AutoInfoLineEnum.$($entry.Value.Prompt)",
      'AutoInfoLineEnum.USER_INFO_RETURN_SAFE_POSITION',
      'AutoInfoLineEnum.USER_INFO_LOAD_PART',
      '_retVal := CheckPartPresent();',
      $entry.Value.True
    )) {
    Assert-ContainsText -RelativePath $relativePath -Expected $expected
  }
  foreach ($falseSignal in $entry.Value.False) {
    Assert-ContainsText -RelativePath $relativePath -Expected "NOT Peripherals.BinIo.$falseSignal"
  }
}

foreach ($step in @('N010', 'N040', 'N070')) {
  Assert-ContainsText `
    -RelativePath "src\plc\project\Station010\SqC_Wp100_Run\actions\$step.st" `
    -Expected 'AutoInfoLineEnum.USER_INFO_LOAD_PART'
}

foreach ($parallelAction in @('N050', 'N051', 'N060', 'N061', 'N100', 'N101', 'N110', 'N120')) {
  Assert-DoesNotContainText `
    -RelativePath "src\plc\project\Station010\SqS_Wp100_Run\actions\$parallelAction.st" `
    -Forbidden '_AutoInfoline'
}

Assert-ContainsText -RelativePath 'src\plc\project\Station010\SqS_Wp100_Run\actions\N095.st' -Expected '_retVal := _unitResult;'
Assert-ContainsText -RelativePath 'src\plc\project\Station010\SqC_Wp100_Run\OnChainFinish.st' -Expected 'Reason <> OpconChainFinishReason.DONE'
Assert-ContainsText -RelativePath 'src\plc\project\Station010\SqC_Wp100_Run\actions\N999.st' -Expected 'USER_INFO_MEASUREMENT_COMPLETE'
Assert-ContainsText -RelativePath 'src\plc\project\Station010\SqS_Wp100_Run\OnChainFinish.st' -Expected 'OpconChainFinishReason.CANCEL:'

$sequenceWriterPath = 'scripts\plc\apply_wp100_run_sequence_rest.ps1'
foreach ($step in @('N015', 'N045', 'N075')) {
  Assert-ContainsText -RelativePath $sequenceWriterPath -Expected "Name = '$step'"
  Assert-ContainsText -RelativePath 'ai\ownership.yaml' -Expected "SqC_Wp100_Run/_a${step}_active"
}
foreach ($manifest in @('ai\graphical.yaml', 'ai\ownership.yaml')) {
  Assert-ContainsText -RelativePath $manifest -Expected 'apply_status: applied_offline_verified'
  Assert-DoesNotContainText -RelativePath $manifest -Forbidden 'blocked_pending_cpstudio_enum_export'
}
foreach ($specification in @('specs\chains\SqC_Wp100_Run.yaml', 'specs\chains\SqS_Wp100_Run.yaml')) {
  Assert-ContainsText -RelativePath $specification -Expected 'status: applied_offline_verified'
  Assert-DoesNotContainText -RelativePath $specification -Forbidden 'not_applied'
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Output 'Run operator guidance OK: append-only enum contract, safe one-hot waits, final product recheck, single-writer branches, cleanup, and applied/readback manifests'
