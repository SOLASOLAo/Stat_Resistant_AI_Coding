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
# Physical-position decisions must not regress to valve-dependent feedback,
# including Home and the force method, not only the three SqC prompt actions.
foreach ($file in Get-ChildItem (Join-Path $repositoryRoot 'src\plc') -Recurse -File -Filter '*.st') {
  if ([IO.File]::ReadAllText($file.FullName) -match '\.OutImm\.IsIn(?:Bas|Wrk)Pos\b') {
    $failures.Add("Physical position must use input feedback: $($file.FullName)")
  }
}
foreach ($relativePath in @('ai\hooks.yaml', 'specs\station.yaml', 'specs\units\Wp100.yaml', 'specs\chains\SqS_Wp100_Home.yaml')) {
  if ((Read-RepositoryText $relativePath) -match '\.OutImm\.IsIn(?:Bas|Wrk)Pos\b') {
    $failures.Add("Application position contract must use input feedback: $relativePath")
  }
}
foreach ($name in $expectedEnumNames) {
  if (-not $enumSpec.Contains("name: $name")) {
    $failures.Add("Enum specification is missing $name")
  }
  if (-not $allRunSource.Contains("AutoInfoLineEnum.$name")) {
    $failures.Add("Prepared Run source does not use $name")
  }
}

$waitActions = [ordered]@{
  N015 = [ordered]@{ Prompt = 'USER_INFO_MOVE_FIXTURE_LEFT'; True = '_100B603'; False = @('_100B601', '_100B602') }
  N045 = [ordered]@{ Prompt = 'USER_INFO_MOVE_FIXTURE_MIDDLE'; True = '_100B602'; False = @('_100B601', '_100B603') }
  N075 = [ordered]@{ Prompt = 'USER_INFO_MOVE_FIXTURE_RIGHT'; True = '_100B601'; False = @('_100B602', '_100B603') }
}
# Both operator-request lamps use the cyclic standard toggle, never a detached
# structure or a one-scan pulse. Keep their existing reset/output handshake.
foreach ($relativePath in @(
    'src\plc\project\Station010\SqS_Wp100_Run\actions\N020.st',
    'src\plc\project\Station010\SqS_Wp100_Home\actions\N010.st'
  )) {
  Assert-ContainsText -RelativePath $relativePath -Expected 'Blink500ms    := Root.RootNode.FlashBits.Toggle500ms'
  Assert-DoesNotContainText -RelativePath $relativePath -Forbidden 'FlashBits.Pulse500ms'
  Assert-ContainsText -RelativePath $relativePath -Expected 'Execute       := FALSE'
  Assert-ContainsText -RelativePath $relativePath -Expected 'BinIo._000P610 := _startButton.LampOn;'
}
foreach ($unit in @('Wp100K101SafetyDoor', 'Wp100K102PressingCylinder')) {
  Assert-ContainsText -RelativePath 'src\plc\project\Station010\SqS_Wp100_Run\actions\N010.st' -Expected "( $unit.Unit.OutImm.IsInBasPosIn )"
}
foreach ($entry in $waitActions.GetEnumerator()) {
  $relativePath = "src\plc\project\Station010\SqC_Wp100_Run\actions\$($entry.Key).st"
  foreach ($expected in @(
      '( Wp100K101SafetyDoor.Unit.OutImm.IsInBasPosIn )',
      '( Wp100K102PressingCylinder.Unit.OutImm.IsInBasPosIn )',
      "AutoInfoLineEnum.$($entry.Value.Prompt)",
      'AutoInfoLineEnum.USER_INFO_RETURN_SAFE_POSITION',
      'AutoInfoLineEnum.USER_INFO_LOAD_PART',
      '_retVal := CheckPartPresent();',
      "( Peripherals.BinIo.$($entry.Value.True) )"
    )) {
    Assert-ContainsText -RelativePath $relativePath -Expected $expected
  }
  foreach ($falseSignal in $entry.Value.False) {
    Assert-ContainsText -RelativePath $relativePath -Expected "NOT Peripherals.BinIo.$falseSignal"
  }
  Assert-DoesNotContainText -RelativePath $relativePath -Forbidden '.OutImm.IsInBasPos )'

  # Evaluate the actual ST signal terms for all eight input combinations in
  # both the caller wait and the atomic operation; do not model only the spec.
  $position = $entry.Value.Prompt.Replace('USER_INFO_MOVE_FIXTURE_', '')
  $atomic = Read-RepositoryText 'src\plc\project\Station010\SqS_Wp100_Run\actions\N010.st'
  $branch = [regex]::Match($atomic, "(?s)MeasurePsoEnum\.${position}:\s*_positionValid := (?<predicate>.*?);")
  foreach ($predicate in @((Read-RepositoryText $relativePath), $branch.Groups['predicate'].Value)) {
    $terms = [regex]::Matches($predicate, '\(\s*(?<not>NOT\s+)?Peripherals\.BinIo\.(?<signal>_100B60[123])\s*\)')
    if (($terms.Count -ne 3) -or (@($terms | ForEach-Object { $_.Groups['signal'].Value } | Sort-Object -Unique).Count -ne 3)) {
      $failures.Add("$position must check all three fixture inputs exactly once in SqC and SqS.")
      continue
    }
    for ($mask = 0; $mask -lt 8; $mask++) {
      $actual = $true
      foreach ($term in $terms) {
        $bit = [int]::Parse($term.Groups['signal'].Value.Substring(7)) - 1
        $value = ($mask -band (1 -shl $bit)) -ne 0
        if ($term.Groups['not'].Success) { $value = -not $value }
        $actual = $actual -and $value
      }
      $expectedBit = [int]::Parse($entry.Value.True.Substring(7)) - 1
      if ($actual -ne ($mask -eq (1 -shl $expectedBit))) {
        $failures.Add("$position fixture predicate is wrong for input mask $mask.")
      }
    }
  }
}

foreach ($step in @('N010', 'N040', 'N070')) {
  Assert-ContainsText `
    -RelativePath "src\plc\project\Station010\SqC_Wp100_Run\actions\$step.st" `
    -Expected 'AutoInfoLineEnum.USER_INFO_LOAD_PART'
}

foreach ($parallelAction in @('N050', 'N051', 'N060', 'N061', 'N065', 'N066', 'N100', 'N101', 'N110', 'N115', 'N120', 'N125')) {
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
