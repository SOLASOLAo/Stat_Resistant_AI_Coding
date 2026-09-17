param([Parameter(Mandatory)][string]$RuntimePath,
      [Parameter(Mandatory)][string]$SfcPath,
      [Parameter(Mandatory)][string]$ExpectedItemPrefix,
      [Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[ComponentModel.LicenseManager]::CurrentContext=New-Object ComponentModel.Design.DesigntimeLicenseContext
foreach($name in @('VisiWinNET.Embedded.Systems.dll','VisiWinNET.Embedded.Forms.dll','OpCon.HMI.Modulo.Shared.dll','OpCon.HMI.Modulo.Forms.dll','TeeChart.dll')) {
    $null=[Reflection.Assembly]::LoadFrom((Join-Path $RuntimePath $name))
}
$null=[Reflection.Assembly]::LoadFrom('C:\Nexeed\Automation\CSV5_11\OpCon\VisiWinNET.SFCLoader.dll')
$loader=New-Object VisiWinNET.Smart.SFCLoader
$reader=New-Object Xml.XmlTextReader($SfcPath)
$errors=New-Object Collections.ArrayList
try { $form=$loader.Load($reader,(New-Object Collections.Hashtable),$null,$errors) } finally { $reader.Close() }
if($errors.Count){throw ($errors|Out-String)}
$bindings=New-Object Collections.Generic.List[string]
function Read-ControlBindings($Control) {
    foreach($property in $Control.GetType().GetProperties()) {
        if($property.Name -like '*Item*') {
            $value=$property.GetValue($Control,$null)
            if($null -ne $value -and $value.PSObject.Properties['Name'] -and $value.Name -like 'Ch1.*') {
                if(-not $value.Name.StartsWith($ExpectedItemPrefix)){throw "Unexpected native binding: $($value.Name)"}
                $bindings.Add($value.Name)
            }
        }
    }
    foreach($child in $Control.Controls){ Read-ControlBindings $child }
}
try {
    Read-ControlBindings $form
    if($bindings.Count -eq 0){throw 'No native variable bindings found'}
    [ordered]@{nativeLoader=$true;errors=$errors.Count;bindings=@($bindings);passed=$true;
        sfcSha256=(Get-FileHash -LiteralPath $SfcPath).Hash;physicalAcceptance=$false} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
} finally { $form.Dispose() }
