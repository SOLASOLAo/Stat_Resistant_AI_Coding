[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$folder = Join-Path $repo 'src/plc/project/Station010/SqS_Station_ChangeOverFile'
function Code([string]$name) {
  $text = [IO.File]::ReadAllText((Join-Path $folder ($name + '.st')))
  return [regex]::Replace($text, '(?m)//[^\r\n]*', '').Trim()
}
$entry = Code '_aN010_active'
$reset = Code '_reset'
$finish = Code '_aN999_active'
$conditionMatch = [regex]::Match($entry, '(?s)^IF\s+(?<condition>.*?)\s+THEN\s+(?<body>.*?)\s+END_IF$')
if (-not $conditionMatch.Success) { throw 'Entry must remain a single guarded request.' }
$condition = $conditionMatch.Groups['condition'].Value
if ($condition -notmatch "^\s*\(\s*Station\.Extension\.StationViewRequest\s*=\s*'[^']*'\s*\)(\s+(OR|AND)\s+\(\s*Station\.Extension\.StationViewRequest\s*=\s*'[^']*'\s*\))*\s*$") { throw 'Unsupported entry condition in this focused ST contract test.' }
# Execute the actual Boolean condition using equivalent ordinal string comparisons.
$expression = $condition.Replace('Station.Extension.StationViewRequest', '$request') -replace '=', '-ceq' -replace '\bOR\b', '-or' -replace '\bAND\b', '-and'
$accepts = [scriptblock]::Create('param([string]$request) ' + $expression)
foreach ($required in @("Station.Extension.StationViewRequest := 'ChgOvGuidanceView';",'Station.ChgOvGuidance.ParImm.CurrentStep := ChgOvGuidanceStepsEnum.SELECT_NEW_TYPE;','_retVal := OK;')) {
  if (-not $conditionMatch.Groups['body'].Value.Contains($required)) { throw "Entry behavior changed: $required" }
}
$cleanup = @([regex]::Matches($reset, "(?s)IF\s*\(\s*Station\.Extension\.(?<field>StationViewRequest|StationDialogRequest)\s*=\s*'(?<owner>[^']+)'\s*\)\s*THEN\s*Station\.Extension\.\k<field>\s*:=\s*'';\s*END_IF"))
if ($cleanup.Count -ne 2 -or ([regex]::Replace($reset, "(?s)IF\s*\(.*?END_IF", '')).Trim()) { throw 'Reset must contain only two guarded request releases.' }
function Reset-Requests($state) {
  foreach ($block in $cleanup) {
    $field = $block.Groups['field'].Value
    if ($state[$field] -ceq $block.Groups['owner'].Value) { $state[$field] = '' }
  }
}
if ($finish -notmatch '^_reset\(\);\s*_env\.ChainControl\s*:=\s*OpconChainControl\.DONE;$') { throw 'Normal completion must release requests before DONE.' }
$checks = 0
foreach ($case in @(@{request='';accept=$true},@{request='ChgOvGuidanceView';accept=$true},@{request='OtherView';accept=$false})) {
  if ((& $accepts $case.request) -cne $case.accept) { throw "Wrong entry behavior for '$($case.request)'." }
  $checks++
}
$state = @{StationViewRequest='';StationDialogRequest=''}
foreach ($cycle in 1..2) {
  if (-not (& $accepts $state.StationViewRequest)) { throw "Cycle $cycle cannot enter." }
  $state.StationViewRequest='ChgOvGuidanceView'
  $state.StationDialogRequest='DataFileDialog'
  # Existing N040 consumes the file result; N999 then releases the guidance view.
  $state.StationDialogRequest=''
  Reset-Requests $state
  if ($state.StationViewRequest -cne '' -or $state.StationDialogRequest -cne '') { throw "Cycle $cycle left a request behind." }
  $checks++
}
foreach ($termination in @('cancel','error')) {
  $state = @{StationViewRequest='ChgOvGuidanceView';StationDialogRequest='DataFileDialog'}
  Reset-Requests $state
  if (-not (& $accepts $state.StationViewRequest) -or $state.StationDialogRequest -cne '') { throw "$termination cannot retry." }
  $checks++
}
foreach ($state in @(@{StationViewRequest='OtherView';StationDialogRequest='DataFileDialog'},@{StationViewRequest='ChgOvGuidanceView';StationDialogRequest='OtherDialog'},@{StationViewRequest='OtherView';StationDialogRequest='OtherDialog'})) {
  $beforeView=$state.StationViewRequest; $beforeDialog=$state.StationDialogRequest
  Reset-Requests $state
  if ($beforeView -eq 'OtherView' -and $state.StationViewRequest -cne $beforeView) { throw 'Unrelated view was cleared.' }
  if ($beforeDialog -eq 'OtherDialog' -and $state.StationDialogRequest -cne $beforeDialog) { throw 'Unrelated dialog was cleared.' }
  $checks++
}
[pscustomobject]@{checks=$checks;twoConsecutiveCycles=$true;cancelAndErrorRetry=$true;retainedOwnViewAccepted=$true;unrelatedRequestsPreserved=$true;scope='Offline ST condition and lifecycle contract; not PLC runtime execution'} | ConvertTo-Json
