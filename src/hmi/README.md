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
- Strictly read-only data-source contract. No write, FORCE, download or runtime
  operation exists in this phase.
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
certificate checkbox is intentionally not persisted.
