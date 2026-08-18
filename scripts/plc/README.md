# PLC Engineering helpers

- `export_plc_snapshot.py` runs inside the active PLC Engineering IronPython
  ScriptEngine and exports deterministic Application text objects.
- `verify_plc_snapshot.ps1` validates the snapshot manifest and optional source
  project hash.

The exporter uses `se.projects.primary`; it never opens a second project,
saves, compiles or performs online operations.
