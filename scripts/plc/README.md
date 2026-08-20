# PLC Engineering helpers

- `export_plc_snapshot.py` runs inside the active PLC Engineering IronPython
  ScriptEngine and exports deterministic Application text objects.
- `verify_plc_snapshot.ps1` validates the snapshot manifest and optional source
  project hash.
- `apply_wp100_run_rest.ps1` applies the AI-owned `SqS_Wp100_Run` declaration,
  SFC graph, Action/cleanup implementations and result DUTs through the active
  PLC Engineering official REST extension. It verifies the CpStudio skeleton
  hashes before first application and performs exact readback on every rerun.

The exporter uses `se.projects.primary`; it never opens a second project,
saves, compiles or performs online operations.

The Run-chain applier saves only through PLC Engineering `ProjectJob`; it does
not connect to a controller, download, start the application or write runtime
variables. Run it only while the intended Station010 project is the single
active PLE project.
