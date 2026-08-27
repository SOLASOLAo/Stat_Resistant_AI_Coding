# Automation scripts

- `cpstudio/`: the signal-only CpStudio export hook plus a separate,
  user-triggered offline Build checker.
- `runner/`: the controlled P1.1 entry for project preflight, OS-exclusive
  leasing, Stage 1/Stage 2 orchestration and structured run manifests.
- `plc/`: PLC Engineering snapshot/readback helpers.
- `ioe/`: ctrlX IO Engineering IPC helpers and official EtherCAT ESI import.
- `git/`: post-export diff/report orchestration helpers.
- `setup/`: read-only teammate workstation deployment checks.

CpStudio hook scripts must never launch a second PLC Engineering or
`codesys-mcp-persistent` instance. They only publish a request under the ignored
`data/requests` directory; the active single MCP session performs PLC work.
`Run-OfflinePostExportCheck.cmd` is deliberately not referenced by that hook;
it runs only after a person closes every existing PLE/MCP session.

The P1.1 Runner does not start PLE/MCP and does not execute immutable actions.
The P1.2 executor will use a single interactive-session broker; it must never
spawn a second PLE or expose online PLC capabilities by default.
