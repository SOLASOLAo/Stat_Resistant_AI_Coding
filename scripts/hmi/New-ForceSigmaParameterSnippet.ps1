[CmdletBinding()]
param([Parameter(Mandatory)][string]$SeedPath,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw 'Output already exists.' }
$data = New-Object Data.DataSet
[void]$data.ReadXml((Resolve-Path -LiteralPath $SeedPath).Path)
if ($data.Tables['ClipBoardTable'].Rows[0].Name -ne 'PressForceThreshold') { throw 'Expected native pressure threshold seed.' }
$data.EnforceConstraints = $false
$map = @{}
$tables = @('TypesLogic','VariablesLogic','_Lng_TypesLogic','_Lng_VariablesLogic','RealData','VarBaseData','MultiLanguageString','ClipBoardTable')
foreach ($table in $tables) {
    foreach ($row in $data.Tables[$table].Rows) {
        $key = [string]$row.Guid
        if (-not $map.ContainsKey($key)) { $map[$key] = [Guid]::NewGuid() }
    }
}
foreach ($table in $data.Tables) {
    if ($table.TableName -notin ($tables + @('LogicTable'))) { continue }
    foreach ($row in $table.Rows) {
        foreach ($column in $table.Columns) {
            $old = [string]$row[$column.ColumnName]
            if ($map.ContainsKey($old)) { $row[$column.ColumnName] = $map[$old] }
        }
        if ($table.Columns.Contains('Name') -and $row.Name -eq 'PressForceThreshold') { $row.Name = 'PressForce3SigmaLimit' }
        if ($table.TableName -eq 'RealData') { $row.Value = 0 }
        if ($table.TableName -eq '_Lng_TypesLogic' -and $row.en_US -eq 'Pressure qualification threshold') {
            $row.en_US = 'Pressure 3-sigma limit'; $row.zh_CN = '压力3σ标准值'
        }
    }
}
$data.EnforceConstraints = $true
$data.WriteXml([IO.Path]::GetFullPath($OutputPath),[Data.XmlWriteMode]::WriteSchema)
$check = New-Object Data.DataSet
[void]$check.ReadXml([IO.Path]::GetFullPath($OutputPath))
if ($check.Tables['ClipBoardTable'].Rows[0].Name -ne 'PressForce3SigmaLimit') { throw 'Native round-trip failed.' }
[pscustomobject]@{Parameter='PressForce3SigmaLimit';InitialValue=0;NativeImportRequired=$true;Output=$OutputPath}
