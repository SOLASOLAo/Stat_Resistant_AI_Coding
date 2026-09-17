[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputPath, [switch]$OnlyNewV2)
# An import fragment containing only the 18 own Text objects. Import into the
# selected HMI group through CpStudio, which owns destination IDs/placement.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell/.NET Framework for the CpStudio schema.' }
if (Test-Path -LiteralPath $OutputPath) { throw 'Use a new output file; existing fragments are preserved.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$spec = Get-Content -LiteralPath (Join-Path $repo 'specs/hmi/force_trace_texts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$template = New-Object Data.DataSet
[void]$template.ReadXml((Join-Path $repo 'src/hmi/Bpp.ForceTrace/NativeText.seed.cpsds'))
$result = $template.Copy()
$result.EnforceConstraints = $false
foreach ($name in @('HmiLogic','_Lng_HmiLogic','HmiTextData','MultiLanguageString','VarBaseData','ClipBoardTable')) { $result.Tables[$name].Clear() }
$index = 0
foreach ($entry in $spec.texts.PSObject.Properties) {
    if ($OnlyNewV2 -and $entry.Name -notin $spec.new_v2_keys) { continue }
    $guid = [Guid]::NewGuid(); $commentGuid = [Guid]::NewGuid(); $valueGuid = [Guid]::NewGuid()
    foreach ($name in @('HmiLogic','HmiTextData','MultiLanguageString','VarBaseData','ClipBoardTable')) {
        $row = $result.Tables[$name].NewRow()
        $row.ItemArray = $template.Tables[$name].Rows[0].ItemArray.Clone()
        $row.Guid = $guid
        if ($name -in @('HmiLogic','ClipBoardTable')) { $row.Name = 'ForceTrace' + $entry.Name; $row.Num = $index }
        if ($name -eq 'MultiLanguageString') { $row._Lng_Comment = $commentGuid; $row._Lng_Value = $valueGuid }
        $result.Tables[$name].Rows.Add($row)
    }
    foreach ($languageIndex in 0..1) {
        $row = $result.Tables['_Lng_HmiLogic'].NewRow()
        $row.ItemArray = $template.Tables['_Lng_HmiLogic'].Rows[$languageIndex].ItemArray.Clone()
        if ($languageIndex -eq 0) { $row.Guid = $commentGuid }
        else { $row.Guid = $valueGuid; $row.en_US = $entry.Value.'1033'; $row.zh_CN = $entry.Value.'2052' }
        $result.Tables['_Lng_HmiLogic'].Rows.Add($row)
    }
    if ($index -eq 0) { $result.Tables['LogicTable'].Rows[0].Root = $guid }
    $index++
}
$result.EnforceConstraints = $true
$result.WriteXml($OutputPath,[Data.XmlWriteMode]::WriteSchema)
$check = New-Object Data.DataSet
[void]$check.ReadXml($OutputPath)
if ($check.Tables['HmiLogic'].Rows.Count -ne $index -or $check.Tables['_Lng_HmiLogic'].Rows.Count -ne (2*$index)) { throw 'Native Text fragment round-trip failed.' }
[pscustomobject]@{Status='PREPARED';Texts=$index;Output=$OutputPath;NativeImportRequired=$true;ModelChanged=$false}
