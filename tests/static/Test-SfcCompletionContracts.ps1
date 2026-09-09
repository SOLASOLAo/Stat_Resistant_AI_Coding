[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
[xml]$graph = Get-Content -LiteralPath (Join-Path $repo 'src/plc/project/Station010/SqM_Station_Home/implementation.sfc.xml') -Raw
$sfc = $graph.body.SFC
if ((@($sfc.step.name) -join ',') -cne 'N000,N100,N999') { throw 'Home must have only init, real subchain execution and finish.' }
$ids = @($sfc.ChildNodes | Where-Object NodeType -EQ Element | ForEach-Object { $_.GetAttribute('localId') })
if (@($ids | Sort-Object -Unique).Count -ne $ids.Count) { throw 'Duplicate native SFC localId.' }
if (($ids -join ',') -cne ((0..($ids.Count - 1)) -join ',')) { throw 'PLE renumbers native localIds on readback; emit contiguous IDs.' }
foreach ($reference in $sfc.SelectNodes('.//connection')) {
  if ($reference.refLocalId -notin $ids) { throw 'Dangling SFC connection after removing N110.' }
}
foreach ($step in $sfc.step) {
  $action = $step.SelectSingleNode(".//attribute[@guid='700a583f-b4d4-43e4-8c14-629c7cd3bec8']")
  if (($null -eq $action) -or ($action.InnerText -cne "_a$($step.name)_active")) {
    throw "Empty or wrong Home Action: $($step.name)"
  }
}
foreach ($transition in $sfc.transition) {
  if ([string]::IsNullOrWhiteSpace($transition.GetAttribute('name'))) { throw 'Native transition name is required on PUT.' }
}
$finish = $sfc.SelectSingleNode("step[@name='N999']")
$transition = $sfc.SelectSingleNode("transition[@localId='$($finish.connectionPointIn.connection.refLocalId)']")
$origin = $sfc.SelectSingleNode("step[@localId='$($transition.connectionPointIn.connection.refLocalId)']")
$conditionId = $transition.condition.connectionPointIn.connection.refLocalId
if (($origin.name -cne 'N100') -or
    ($sfc.SelectSingleNode("inVariable[@localId='$conditionId']/expression").InnerText -cne '_retVal = OK')) {
  throw 'Home must finish only through the existing N100 completion condition.'
}
$writer = Get-Content -LiteralPath (Join-Path $repo 'scripts/plc/apply_station_home_rest.ps1') -Raw
if (-not $writer.Contains("_aN100_active = 'a9187c877963ac019f5bd8c7bed6fc286c39f0b3c708af42e0f1c46e8919aa85'")) {
  throw 'The reviewed ExecuteSubChain completion Action hash must remain pinned.'
}
Write-Output 'SFC completion contracts OK: Home N110 absent, all steps bound, valid IDs, guarded N100-to-N999, named transitions and completion Action hash pinned.'
