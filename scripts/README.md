# Automation scripts

- `cpstudio/`: lightweight scripts invoked by the supported CpStudio export hook.
- `plc/`: PLC Engineering snapshot/readback helpers.
- `ioe/`: ctrlX IO Engineering IPC helpers and official EtherCAT ESI import.
- `git/`: post-export diff/report orchestration helpers.
- `setup/`: read-only teammate workstation deployment checks.

CpStudio hook scripts must never launch a second PLC Engineering or
`codesys-mcp-persistent` instance. They only publish a request under the ignored
`data/requests` directory; the active single MCP session performs PLC work.
