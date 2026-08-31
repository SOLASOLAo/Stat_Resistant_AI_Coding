# IO Engineering helpers

`ioe_ipc.ps1` drives the separately installed ctrlX IO Engineering 2.6.4
ScriptEngine. It must not be used to open the PLC project. Follow the shutdown
and modal-dialog rules documented in `AGENTS.md` and the shared IOE playbook.

`Install-EtherCatEsi.ps1` installs an EtherCAT ESI through the official IO
Engineering device-repository API. It uses a unique temporary IPC session,
does not open a project, verifies the exact device identity, and closes IOE
gracefully. Close any manually opened IO Engineering window before running it.

Station010 Kistler 5867C example:

```powershell
.\scripts\ioe\Install-EtherCatEsi.ps1 `
  -EsiPath '..\Technical Docs\5867c-maxymos-bl-fieldbus-descr-ec-pn-eip-25.1.0\EtherCAT\Kistler_Type_5867C_V1.xml' `
  -SearchTerm '5867' `
  -ExpectedName 'maXYmos BL 5867C' `
  -ExpectedVendor 'Kistler' `
  -ExpectedDeviceId '58A_0000E52F00000001' `
  -ExpectedVersion 'Revision=16#00000001'
```

The PLE device repository is not the EtherCAT ESI repository. On the verified
PLE 2.6.8 installation its REST endpoint has no EtherCAT converter plug-in;
install fieldbus XML only through IO Engineering.

## CpStudio ePLAN I/O designators and descriptions

`New-CpStudioEplanIoAsc.ps1` converts a reviewed CSV into the known
CpStudio/ePLAN ASC byte and column shape. It does not open or automate
CpStudio. The input columns are fixed:

```text
DeviceDesignator,Address,IoDesignator,Type,English,Chinese
```

- `Address` is the module channel number, such as `1` through `8`; it is not a
  PLC address such as `%IX0.0`.
- `Type` is `1` for DI and `2` for DO.
- `IoDesignator` is copied literally. The tool does not guess an ePLAN BMK from
  a PLC-safe name.
- Output is UTF-16LE with BOM, CRLF and 15 TAB-separated columns. Station010's
  language configuration maps `E` to English and `X` to Chinese; actual `X`
  import behavior remains part of the first CpStudio round-trip test.

Generate the Station010 A1 round-trip probe locally:

```powershell
pwsh -NoProfile -File .\scripts\ioe\New-CpStudioEplanIoAsc.ps1 `
  -InputCsv .\specs\station010-a1-eplan-roundtrip-probe.csv `
  -OutputAsc .\data\eplan\station010-a1-roundtrip-probe.asc
```

The probe contains all eight A1 channels, so the test does not depend on
unknown partial-module update behavior. Its `_000...` I/O designators are the
current CpStudio values, not a verified Station010 ePLAN export. Therefore the
first import is an isolated round-trip test only:

1. Use a recoverable CpStudio project copy/checkpoint, not the only working
   project.
2. In `Peripherals > I/O`, run the official `Import I/O designators from
   ePLAN` command and select the generated ASC.
3. Confirm A1 still has exactly eight channels; only the expected English and
   Chinese descriptions may change. If names or unused channels change, close
   without saving and stop.
4. Save, then run CpStudio's official `Write peripheral and I/O designators to
   the PLC IDE` and `Control plus Studio export` commands.
5. In PLE, run `Link I/O`, then Build. Do a second CpStudio Export only when the
   normal Symbol/Post-export check requests it.

After one real Station010 ePLAN export is available, use its exact
`IoDesignator` values as the production CSV source. Never copy the
TrainingStation signal data; that file established only the ASC byte/column
format.

`Test-EthercatNameChain.ps1` is a read-only guard for the separate EtherCAT
master naming rule. Copy the actual name shown in the ctrlX Web UI into the
mandatory `TargetMasterName` parameter. It must equal the IOE internal master
name, while CpStudio/HMI uses its ECAD name:

```powershell
pwsh -NoProfile -File .\scripts\ioe\Test-EthercatNameChain.ps1 `
  -TargetMasterName '_000SA620_X1'
```

For the current Station010 this validates:

```text
ctrlX Web / IOE / PLE: _000SA620_X1
CpStudio / HMI BMK:    =000+S-A620-X1
```

`Read fieldbus config from the PLC IDE` reads the topology/path. It does not
replace existing CpStudio DIDO designators and cannot repair a mismatched
ctrlX Web EtherCAT master name.
