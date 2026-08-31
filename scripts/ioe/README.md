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

ASC is the only supported external electrical I/O exchange format. Convert an
ASC exported by the current station into the canonical reviewed CSV before
editing descriptions or building the Project Pack:

```powershell
pwsh -NoProfile -File .\scripts\ioe\Convert-CpStudioEplanIoAscToCsv.ps1 `
  -InputAsc <electrical-export.asc> `
  -OutputCsv .\specs\station010-eplan-io.csv -Force
```

The intake rejects any format other than the verified UTF-16LE-BOM, CRLF,
15-column ASC contract. It validates contiguous module/channel order, DI/DO
types and the `E`/`X` language columns. An empty `I/O designator` is preserved
as an inactive channel. CpStudio's exact generated
`_<normalized-device>_Channel_<address>` name is also normalized to inactive,
but only when both descriptions are empty; mismatched or described
placeholder-like names are rejected. Descriptions on an inactive channel are rejected.
Missing active English/Chinese descriptions are counted in the result so they
can be completed in the reviewed CSV. Because `X` is the Chinese column, text
without a CJK character is counted as missing Chinese even when it contains a
copied English label. AML, XML and OHD are intentionally not accepted.
When `-Force` replaces an existing canonical CSV, the complete
module/address/type key set must remain identical; a partial ASC or topology
change is rejected before the old CSV is touched. For a deliberate new
topology, write to a new CSV path and review it first.

`New-CpStudioEplanIoAsc.ps1` converts a reviewed CSV into the known
CpStudio/ePLAN ASC byte and column shape. It does not open or automate
CpStudio. The input columns are fixed:

```text
DeviceDesignator,Address,IoDesignator,Type,English,Chinese
```

- `Address` is the module channel number, such as `1` through `8`; it is not a
  PLC address such as `%IX0.0`.
- `Type` is `1` for DI and `2` for DO.
- `IoDesignator` is copied literally. A non-empty value makes the imported
  channel active; an empty value makes it inactive and clears its stored name
  and PLC variable reference. Never use generated `_..._Channel_N` placeholders
  for unused channels.
- CpStudio maps rows by occurrence order rather than by `Address`. Keep each
  module in one block, start at channel 1 and do not omit or reorder an
  intermediate channel. The generator rejects unsafe ordering.
- Output is UTF-16LE with BOM, CRLF and 15 TAB-separated columns. Station010's
  language configuration maps `E` to English and `X` to Chinese. Both columns
  are supplied to the importer; retain every existing description instead of
  relying on an empty field to preserve it.

For the integrated project, generate and verify the reviewed ASC through the
Project Pack:

```powershell
pwsh -NoProfile -File .\scripts\project\Build-CtrlXOpconProjectPack.ps1 `
  -Command Build -EngineeringRoot . -RequireReady -Json

pwsh -NoProfile -File .\scripts\project\Build-CtrlXOpconProjectPack.ps1 `
  -Command Check -EngineeringRoot . -RequireReady -Json
```

`Build` creates `generated/cpstudio-io-designators.asc` atomically. `Check`
regenerates it in a temporary directory and rejects any CSV, generator or ASC
drift. The generator can still be called directly for an isolated preview:

```powershell
pwsh -NoProfile -File .\scripts\ioe\New-CpStudioEplanIoAsc.ps1 `
  -InputCsv .\specs\station010-eplan-io.csv `
  -OutputAsc .\data\eplan\station010-eplan-io.asc
```

The full source contains all seven modules and all 56 channels in order:
38 active and 18 inactive. It was derived from the real Station010 CpStudio
ASC export and passed the official round trip on 2026-08-31:

1. Create a recoverable CpStudio checkpoint before the first import for a new
   station.
2. In `Peripherals > I/O`, run the official `Import I/O designators from
   ePLAN` command and select the generated ASC.
3. Confirm the active/inactive counts and the intended English/Chinese
   descriptions before saving.
4. Save, then run CpStudio's official `Write peripheral and I/O designators to
   the PLC IDE` and `Control plus Studio export` commands.
5. In PLE, run `Link I/O`, then Build. If Symbol/Post-export requires it, run a
   second CpStudio Export and a final Build.

After Export, Stage 1 automatically compares the reviewed CSV with the
configured CpStudio `BusConfig` when `project-pack.json` contains
`sources.ioDesignators` and `config/project.yaml` contains `paths.bus_config`.
A mismatch produces `IO_DESIGNATOR_EXPORT_MISMATCH` and blocks later stages.
The same read-only check can be run directly:

```powershell
pwsh -NoProfile -File .\scripts\ioe\Test-CpStudioEplanIoExport.ps1 `
  -InputCsv .\specs\station010-eplan-io.csv `
  -BusConfigPath ..\Station010\PublicConfig\BusConfig_Stat010_V5.11_CtrlX.yaml
```

The verified Station010 result was 38 active / 18 inactive channels, Export #2
`0 errors / 3 warnings`, and final PLE Build `0 errors / 0 warnings`. The two A1
Chinese descriptions propagated to HMI labels, EventRecorder and generated
message text. For another station, start from that station's own complete ASC
export; never copy Station010 or TrainingStation signal data.

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
