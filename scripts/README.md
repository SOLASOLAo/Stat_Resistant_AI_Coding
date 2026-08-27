# Automation scripts

- `cpstudio/`: the signal-only CpStudio export hook plus a separate,
  user-triggered offline Build checker.
- `runner/`: the controlled P1.1/P1.2a entry for project orchestration,
  immutable action validation, local leasing and evidence sealing.
- `plc/`: PLC Engineering snapshot/readback helpers.
- `ioe/`: ctrlX IO Engineering IPC helpers and official EtherCAT ESI import.
- `git/`: post-export diff/report orchestration helpers.
- `setup/`: read-only teammate workstation deployment checks.

CpStudio hook scripts must never launch a second PLC Engineering or
`codesys-mcp-persistent` instance. They only publish a request under the ignored
`data/requests` directory; the active single MCP session performs PLC work.
`Run-OfflinePostExportCheck.cmd` is deliberately not referenced by that hook;
it runs only after a person closes every existing PLE/MCP session.

P1.2a consumes immutable actions only through an already-running local Broker
and never starts PLE/MCP. The unique interactive-session Agent/Broker is the
remaining P1.2b task; without it the client seals an honest blocked result and
cannot claim a fresh Build.
