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

## Read-only boundary

`IStationDataSource` exposes connect, disconnect and subscription events only.
It intentionally has no write method. Even though the generated Symbol XML
marks many values as `ReadWrite`, status and PLC outputs remain read-only by
semantic policy.

Phase 2 will introduce a separate command interface only after the read-only
screen has been accepted. That interface will have an explicit allowlist for
OpCon request inputs and must reproduce Token, Heartbeat, pulse and readback
semantics. It will never expose arbitrary NodeId writes.

## Nexeed-like operator structure

The implementation copies the useful information hierarchy, not Nexeed's
closed-source controls or branded assets:

- persistent station/connection header;
- read-only Automatic, Manual, Homing and Change-over mode strip;
- left navigation for Overview, Manual, Events, I/O and Data;
- station, safety, fieldbus, Burster and Kistler diagnostic cards;
- persistent yellow bilingual operator-guidance bar driven by AutoInfoLine.

All five navigation destinations are usable in the prototype. Manual is a
read-only Unit overview, I/O and Data expose the current diagnostic contract,
and Events is deliberately marked incomplete until `PublicEventList` is
decoded. An empty placeholder is never presented as "no active alarm".

Disconnected, waiting and bad-quality states mask the live pages so stale
green indications cannot be mistaken for current PLC data. Burster/Kistler
colors decode the actual `OpconUnitState` values: Operational/Standby are
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
- The dependency lock is restored once while Wi-Fi is available. Afterwards
  the engineering-cable workflow can build from the local NuGet cache.

No online PLC action was performed while creating this proof of concept.

## Local acceptance

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\hmi\Test-HmiReadOnlyScaffold.ps1
```

The test resolves all catalog paths against the current Application Symbol
XML, scans every HMI C# source for write/call/runtime-control surfaces, and
performs a locked Release build. Offline visual review starts with `--demo`.
