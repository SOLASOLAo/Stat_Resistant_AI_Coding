# BPP self-developed HMI

This directory contains the independent Windows HMI proof of concept. It is
deliberately outside `Station010/Hmi`: CpStudio continues to own and generate
the Nexeed HMI, while this application consumes the already-published ctrlX
OPC UA symbols without changing the PLC project.

## Current scope

- .NET 8 WPF desktop application with a Nexeed-like information hierarchy.
- Real OPC UA subscription through port 4840.
- Namespace indexes are resolved from the ctrlX Data Layer namespace URI at
  runtime; no `ns=2` assumption is stored.
- Offline demo source for UI development without a PLC or network.
- 94 reviewed read-only subscriptions, including the nine-slave EtherCAT
  topology, 38 named DI/DO values, PublicEventList, StationData, TypeData and
  Kistler semantic force/displacement data.
- StationData and TypeData are separate tabs; `StationDataNew` and
  `TypeDataNew` staging structures are not shown.
- Automatic, Manual, Homing and Change-over are operator buttons. Their only
  write path is a semantic allowlist for `TokenRequest` and `ModeIdRequest`,
  with Token/ModeId readback and safety prechecks. Real connections default to
  read-only; the operator must explicitly enable mode requests for that session.
- No generic write, physical I/O write, Heartbeat write, FORCE, download or
  PLC start/stop operation exists.
- OPC UA keepalive reconnect and a three-second session-health timeout mask;
  unchanged process values do not become stale merely because no DataChange is sent.
- Username/password stay in memory and are never written to configuration.

## Build

Restore once while normal network access is available. The committed package
lock then allows the same package graph to be restored from the local cache
when the engineering cable disables Wi-Fi.

```powershell
cd src/hmi
dotnet restore Bpp.ResistantStation.Hmi.sln --locked-mode
dotnet build Bpp.ResistantStation.Hmi.sln --no-restore
```

Run the UI in offline demo mode:

```powershell
dotnet run --project .\Bpp.ResistantStation.Hmi\Bpp.ResistantStation.Hmi.csproj -- --demo
```

For a real connection, close the Nexeed HMI control client first, enter the
ctrlX OPC UA user at runtime, and select **Connect PLC**. The commissioning-only
certificate and session-mode checkboxes are intentionally not persisted. Leave
mode requests unchecked during the first read-only acceptance.

Repeatable local acceptance:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ..\..\tests\hmi\Test-HmiReadOnlyScaffold.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ..\..\tests\hmi\Test-HmiDemoUi.ps1
```

The first real-device session should remain read-only until PublicEventList
and EtherCAT array decoding are observed. Mode switching is then a separate,
explicitly approved operator acceptance step; it does not alter the PLC code.
