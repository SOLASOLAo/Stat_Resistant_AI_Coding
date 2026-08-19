# Kistler maXYmos BL 5867C EtherCAT integration

## Confirmed hardware and data contract

| Item | Value |
|---|---|
| Hardware | Kistler maXYmos BL `5867C001` |
| Serial number | `6575138` |
| Fieldbus | EtherCAT |
| Byte order | Little-Endian |
| Vendor ID | `0x0000058A` / `1418` |
| Product code | `0x0000E52F` / `58671` |
| Revision | `0x00000001` |
| Cyclic input | 200 bytes (`Inputs0`) |
| Cyclic output | 200 bytes (`Outputs0`) |

The fieldbus setting on the physical device is selected under
`Setup → Global Setup → Fieldbus`. No controller connection or device setting
change was made during the repository integration.

## External assets

The original files remain outside Git under the sibling `Technical Docs/`
directory:

- `5867c-maxymos-bl-fieldbus-descr-ec-pn-eip-25.1.0/EtherCAT/Kistler_Type_5867C_V1.xml`
  - SHA-256: `7AE6DF840A704DBBBC628A6DAFC9FA6BEE8BE3571C83C3F22874F422C11838FC`
- `maXYmos BL type 5867C quick start guide .pdf`
  - SHA-256: `ACE06C6B09E01F1058D5B43ED6E3F5F7D4F627E7E7FCA0B9989EF7F17D052AAC`

The exact relative paths are recorded in `config/project.yaml` and checked by
`scripts/setup/Test-TeamWorkstation.ps1`.

## OpCon objects

The read-only `Std` contains the required application interface:

- Unit: `NexeedKistlerForceStroke V1.2`;
- required Unit port: `KistlerForceStrokeChannel` / `IKistlerForceStroke`;
- Peripheral: `NexeedEcKistlerMaxymosBl V2.0.7.0`;
- provided Peripheral channel: `ForceStroke Channel` /
  `IKistlerForceStroke`.

The integration deliberately keeps two names with different responsibilities:

- actual EtherCAT hardware: IOE node `_100A104`, described by the supplied ESI
  as `maXYmos BL 5867C`;
- OpCon compatibility adapter automatically selected by CpStudio:
  `Kistler MaXYmos BL5867B TL5877B0` /
  `NexeedEcKistlerMaxymosBl V2.0.7.0`.

The standard adapter title is a legacy library label, not the detected hardware
model. Do not rename or fork it merely to correct the title: CpStudio uses this
standard object during automatic matching and `Std` must remain read-only. Its
BL EtherCAT identity is vendor `1418`, product `58671`, revision `1`, exactly
the same identity as the supplied 5867C ESI. The legacy ESI in the standard
Peripheral package also exposes 200 input and 200 output bytes, but its display
name is stale (`5877A`) and its Sync Manager control bytes are from the older
device generation. The supplied 5867C ESI is therefore the authoritative IO
device description; the legacy-named standard Peripheral remains the OpCon
PLC/channel adapter.

## Supported integration path

1. Close manually opened ctrlX IO Engineering windows.
2. Run `scripts/ioe/Install-EtherCatEsi.ps1` with the exact identity shown in
   `scripts/ioe/README.md`.
3. Open `Stat010_V5.11_CtrlX_IO.project` only with ctrlX IO Engineering 2.6.4.
   Add `maXYmos BL 5867C` below `_000SA620_X1` as a sibling of `_000SK010`,
   name the project node `_100A104`, then save and close the IO project.
4. In CpStudio, use the command that reads/imports the ctrlX IDE EtherCAT IO
   configuration from the IO project in the same Station project directory.
   CpStudio then automatically matches `_100A104` to the legacy-named standard
   Peripheral `Kistler MaXYmos BL5867B TL5877B0`; do not manually drag that
   Peripheral from the toolbox.
5. Add the Kistler force/stroke Unit below `Wp100` and bind its
   `IKistlerForceStroke` port to the Peripheral channel. The port must not be
   left empty even though the OOD marks it optional.
6. Export from CpStudio, then perform the standard Git diff, PLC text snapshot,
   IO mapping/Symbol Configuration audit and offline compile closure.

PLE 2.6.8 exposes a device-repository REST endpoint, but that installation has
no EtherCAT XML converter plug-in and correctly rejects this ESI with diagnosis
`The type '{3992c588-7bdb-4a7c-908d-f444808d8cd2}' could not be found.` This is
a tool boundary, not a malformed ESI. EtherCAT XML belongs in the IO Engineering
repository; the PLC project receives the configured fieldbus nodes from the IO
integration flow.

## Current verification status (2026-08-19)

- IOE System Repository initially contained no Kistler/maXYmos/5867 entry.
- The supplied ESI was imported through the official IOE ScriptEngine
  `device_repository.import_device` EtherCAT converter.
- Repository readback returns exactly one device:
  `maXYmos BL 5867C`, Kistler, type `65`, ID
  `58A_0000E52F00000001`, version `Revision=16#00000001`.
- The reusable installer passed an idempotency test: a second run detected the
  exact existing identity, performed no import, closed IOE and removed its
  temporary session.
- The controlled IO project now contains `_100A104` below
  `_000SA620_X1`, as a sibling of `_000SK010`. A save/close/reopen readback
  returned exactly type `65`, ID `58A_0000E52F00000001`, version
  `Revision=16#00000001`.
- CpStudio one-click IO import succeeded. `_100A104` was automatically matched
  to `Kistler MaXYmos BL5867B TL5877B0`; the legacy title is therefore retained
  exactly as supplied by the standard object package.
- The same CpStudio batch renamed the Burster object and TCP Peripheral from
  `Wp100K103...` to `Wp100A103...`. The first export failed because generated
  declarations already used the new name while `PeripheralRoot`,
  `OnInitHierarchy`, `OnApplyParameters` and Symbol Configuration still held
  old references. The references were migrated through the official PLC REST
  API, the validated `CommonManRelease AND TRUE` implementation was preserved,
  and the obsolete POU was removed.
- The unavailable old Symbol Configuration entries were removed with the
  official `UnSelectAll` followed by `Select` using a snapshot of all current
  valid selections. `PublishMarkedMethodsJob` and
  `DeclarationsJob/AddAllInstancePaths` both then completed successfully.
- IOE 2.6.4 cannot serialize this device's 400-byte PDO mapping as one REST
  device response. The response is truncated by a critical
  `The stream is currently in use by a previous operation on the stream`
  object, which makes CpStudio's "write I/O designators to PLC IDE" action fail
  near `ioMapping[350].subChannels[2].address`. This is an IOE REST defect for
  the large PDO, not an invalid BMK or ESI.
- The verified offline workaround is fully interface-based: IOE
  `ExportEthercatConfigJob` exports the master, PLE
  `ImportOfflineFieldbusConfigJob` imports it below `Realtime_Data` with
  `keepExisting=true`, and the persistent MCP connector mapping API binds the
  400 parent byte channels. The mapping contract is:
  - input bytes 0..19 -> `_input.Ctrl[0..19]`;
  - input bytes 20..199 -> `_input.Data[0..179]`;
  - output bytes 0..19 -> `_output.Ctrl[0..19]`;
  - output bytes 20..199 -> `_output.Data[0..179]`.
- Final readback is 400 bound channels, zero mismatches. The deterministic PLC
  snapshot contains 234 objects and source-project SHA-256
  `f1348397a4f29506390b97e1f7185774e3756aa0b2fdc1701889d49b8b123747`.
  Offline compilation is `0 errors / 7 warnings`.
- `NexeedKistlerForceStroke` is now generated below `Wp100` as
  `Wp100A104Kistler` (instance ID 8), and its `IKistlerForceStroke` channel is
  bound to `_100A104`. On the PLC side, all eight manual functions retain the
  Mode Handler gate and are enabled with `CommonManRelease AND TRUE`.
  CpStudio's HMI condition-analysis tree still contains its generated
  `Constant FALSE` values; those eight model-level conditions must be changed
  in CpStudio and re-exported rather than patched directly in generated XML.
  Post-change PLC readback remains 400/400 bound PDO bytes with zero mismatches;
  offline compilation remains `0 errors / 7 warnings`.
- The verified generated batch is pushed as Station010 commit `17c63e5`; the
  reusable large-PDO/batch-mapping compatibility patch is pushed as
  `ctrlx-ai-coding` commit `924ca25`.

All IO and PLC changes used the respective official IDE interfaces. No physical
controller was connected, downloaded, started, stopped, written or forced.
