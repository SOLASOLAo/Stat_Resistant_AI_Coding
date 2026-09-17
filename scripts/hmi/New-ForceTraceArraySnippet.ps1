[CmdletBinding()]
param([Parameter(Mandatory)][string]$SeedPath, [Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw 'Output already exists.' }
$seed = New-Object Data.DataSet
[void]$seed.ReadXml((Resolve-Path -LiteralPath $SeedPath).Path)
if ($seed.Tables['ArrayData'].Rows.Count -ne 1 -or $seed.Tables['ArrayData'].Rows[0].Type -ne 23) { throw 'Expected native DWORD array seed.' }
$result = $seed.Copy()
$result.EnforceConstraints = $false
$tables = @('VariablesLogic','_Lng_VariablesLogic','ArrayData','VarBaseData','BooleanData','OpcUaAccessPropertyData','ClipBoardTable')
foreach ($table in $tables) { $result.Tables[$table].Clear() }
$names = @('HMIForceTraceLeft','HMIForceTraceMiddle','HMIForceTraceRight','HMIForceStatistics')
for ($index=0; $index -lt $names.Count; $index++) {
    $map = @{}
    foreach ($table in $tables) {
        foreach ($row in $seed.Tables[$table].Rows) {
            $old = [string]$row.Guid
            if (-not $map.ContainsKey($old)) { $map[$old] = [Guid]::NewGuid() }
        }
    }
    $rootGuid = $map[[string]$seed.Tables['ArrayData'].Rows[0].Guid]
    foreach ($table in $tables) {
        foreach ($original in $seed.Tables[$table].Rows) {
            $row = $result.Tables[$table].NewRow()
            $row.ItemArray = $original.ItemArray.Clone()
            foreach ($column in $result.Tables[$table].Columns) {
                $old = [string]$row[$column.ColumnName]
                if ($map.ContainsKey($old)) { $row[$column.ColumnName] = $map[$old] }
            }
            if ($table -eq 'ClipBoardTable' -or ($table -eq 'VariablesLogic' -and $row.Guid -eq $rootGuid)) {
                $row.Name = $names[$index]; $row.Num = $index
            }
            if ($table -eq 'ArrayData') { $row.MaxLim = $(if ($index -eq 3) {209} else {30035}) }
            $result.Tables[$table].Rows.Add($row)
        }
    }
    if ($index -eq 0) { $result.Tables['LogicTable'].Rows[0].Root = $rootGuid }
}
$result.EnforceConstraints = $true
$result.WriteXml([IO.Path]::GetFullPath($OutputPath), [Data.XmlWriteMode]::WriteSchema)
$check = New-Object Data.DataSet
[void]$check.ReadXml([IO.Path]::GetFullPath($OutputPath))
if ($check.Tables['ArrayData'].Rows.Count -ne 4) { throw 'Fragment round-trip failed.' }
[pscustomobject]@{Arrays=$names;NativeImportRequired=$true;Output=$OutputPath}
