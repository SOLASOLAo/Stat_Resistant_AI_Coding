# Independent HMI parallel comparison

## Decision

The self-developed HMI is a separate Windows application under `src/hmi`.
It does not replace or patch the CpStudio/Nexeed HMI and it does not change the
PLC program. The operator closes one HMI before using the other, so the first
proof of concept does not implement a two-master control scheme.

The existing Nexeed client primarily uses the VisiWin CoDeSysV3/ARTI3 channel.
The new client deliberately uses the standard ctrlX OPC UA server on port 4840.
Both routes reach the same published PLC values.

## Why WPF for the first version

- The target is a Windows industrial IPC.
- .NET 8, WPF runtime and Visual Studio desktop tools are already installed.
- It keeps the first UI dependency surface small: the only direct third-party
  package is the official OPC Foundation client.
- It is close to the current Windows/VisiWin deployment model and therefore
  makes the leadership A/B comparison easier.

Cross-platform packaging can be reconsidered after the operator workflow and
OPC UA contract are stable.

## Data and control boundary

`IStationDataSource` exposes connect, disconnect, subscription events and one
semantic mode-request operation. It has no generic NodeId write method. Even though the generated Symbol XML
marks many values as `ReadWrite`, status, PLC outputs, internal Chain state and
physical I/O remain read-only by semantic policy.

The only implemented control operation is `RequestModeAsync`. Its private OPC
UA adapter can write exactly two OpCon inputs: `TokenRequest` and
`ModeIdRequest`. It uses APQ/IPC panel token 1, requires exact Token readback 1,
accepts only mode IDs 1, 3, 4 and 5, and waits for ModeId readback. Immediately
before writing, it performs a fresh server Read of the emergency-stop and
maintenance-door feedbacks; Change-over additionally reads and requires
`Station.Unit.IsEmpty`. Safety-door and combined-circuit values remain visible,
but are not duplicated as HMI mode-selection interlocks because the PLC
`OnModeRelease` logic remains authoritative. OPC UA write success alone is
never treated as PLC acceptance.

A real OPC UA connection starts as a read-only session. Mode buttons remain
disabled unless the operator explicitly checks **Enable operator mode requests
for this session** in the connection dialog; that choice is not persisted.
Offline demo mode enables the buttons so the workflow remains testable.

Heartbeat is deliberately not a periodic client toggle. The standard HMI
shows it is a PLC challenge that a remote-manual-function client answers by
writing FALSE. Because remote manual functions are not implemented yet,
Heartbeat is not in the write allowlist.

## Nexeed-like operator structure

The implementation copies the useful information hierarchy, not Nexeed's
closed-source controls or branded assets:

- persistent station/connection header;
- left operator-mode sidebar for Automatic, Manual, Homing and Change-over;
- top primary navigation for Overview, Events, I/O and Data;
- a shared Automatic/Homing/Change-over Start and Cycle Stop command bar;
- Automatic step-mode and next-step controls;
- a Station/Wp100 Unit navigator with the configured manual-function list;
- a hierarchical EtherCAT master/coupler/module/device tree with selected-node I/O detail;
- station, safety, fieldbus, Burster and Kistler diagnostic cards;
- persistent yellow bilingual operator-guidance bar driven by AutoInfoLine.

All four primary navigation destinations are usable. In Manual mode, Overview
becomes the Unit/manual-function workspace and reads every configured
function's authoritative `Release*` and `Running*` output. Its buttons execute
only in the offline demo; the real OPC UA adapter keeps Unit writes disabled.
Events subscribes the official 20-row `PublicEventList`. I/O shows the full
nine-slave EtherCAT topology as `Master -> EK1100 -> EL modules`, with Kistler
as a direct master child, and filters the 38 named DI/DO values by the selected
node. Data is split into `StationData` and `TypeData`; the DataSetManager
staging objects are intentionally excluded.

## Chain and manual-control contract

The generated Chain objects are monitored, never written directly. Automatic,
Homing and Change-over are operated through the common Station ModeHandler
interface. The screen now contains Start, Cycle Stop, Step Mode and Next Step
controls and demonstrates them offline. On a real connection they remain
disabled until the request-bit reset behavior, panel Token ownership and
failure cleanup have been accepted on the machine.

Unit selection is local HMI navigation. Each manual action displays its exact
PLC `Release<Name>` and `Running<Name>` values. Real manual execution remains
locked until the hold-to-run `Exec<Name>` behavior and the Unit Heartbeat
challenge/ack can guarantee `Exec=FALSE` on mouse-up, focus loss, disconnect
and process exit. The verified symbol and behavior contract is recorded in
[`self_hmi_nexeed_control_contract.md`](self_hmi_nexeed_control_contract.md).

The offline decoder currently proves active/cleared filtering and displays
event number, class, source and additional information. The real ctrlX complex
payload and the Nexeed event-number-to-bilingual-message catalog still require
read-only commissioning acceptance; the UI does not claim that placeholder
`Source · Event N` text is the final localized alarm message.

Kistler raw 200-byte input and output PDO areas are mapped in the PLC I/O
project but are not published by the current Application Symbol Configuration.
The HMI therefore shows the Unit's published semantic values: state, ready,
program, alarm/warning/no-pass, force and displacement. This requires no PLC
change and avoids inventing OPC UA paths for unpublished process-image bytes.

Disconnected, waiting, bad-quality and session-health timeout states mask the
live pages so old green indications cannot be mistaken for current PLC data.
The three-second timeout is refreshed by the OPC UA session keepalive rather
than by DataChange notifications, so an idle machine does not become stale.
Burster/Kistler colors decode the actual `OpconUnitState` values: Operational/Standby are
green, transitions are amber, Disabled/Unknown are red, and no data is gray.

## Data Layer addressing

The checked-in catalog stores each string identifier, for example:

```text
plc/app/Application/sym/Station/Extension/ModeId
```

and the namespace URI separately:

```text
http://www.boschrexroth.com/OpcUa/Datalayer
```

The OPC UA session resolves the namespace index dynamically. A numeric `ns=2`
is never persisted because ctrlX may assign another index after app or server
configuration changes.

## Security and offline use

- The username and password are entered at runtime and stay in process memory.
- Client PKI files live under `%LOCALAPPDATA%\Bpp.ResistantStation.Hmi\pki`.
- Automatic trust of an untrusted server certificate is a visible,
  commissioning-only checkbox and is not persisted.
- Operator mode requests are disabled by default for every real connection and
  require an explicit, non-persisted session checkbox.
- The dependency lock is restored once while Wi-Fi is available. Afterwards
  the engineering-cable workflow can build from the local NuGet cache.

No online PLC action was performed while creating this proof of concept.

## Live acceptance still required

Offline validation proves that every configured node exists in the current
Symbol XML and that the application builds and runs. One read-only real-device
session is still needed to confirm the ctrlX runtime representation of the
custom `PublicEventList` ExtensionObject and the nine-element EtherCAT arrays.
After that, one separately approved operator test can request each mode and
confirm Token/ModeId readback. This acceptance does not require a PLC program
change or a second simultaneously active HMI.

## Local acceptance

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\hmi\Test-HmiReadOnlyScaffold.ps1
```

The test resolves all catalog paths against the current Application Symbol
XML, proves that subscription nodes are read-only, proves that mode writes are
limited to TokenRequest and ModeIdRequest, and performs a locked Release build.
The separate `tests/hmi/Test-HmiDemoUi.ps1` smoke test invokes an operator mode
button and verifies Events, I/O, StationData and TypeData navigation.
