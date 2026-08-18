# CpStudio export hook

CpStudio V5.11 officially supports configuring a pre-export or post-export
batch/Python script. The hook capability is official; the scripts in this
directory are project-owned automation.

Configure the Post-export script from the Station010 Engineering directory as:

```text
..\..\McpCoding\scripts\cpstudio\post_export_signal.bat
```

The batch file calls `write_export_request.ps1`, which atomically writes:

```text
McpCoding\data\requests\export_request.json
```

It deliberately does not start PLC Engineering, connect to a PLC, compile or
change the generated project. The existing Codex/MCP session consumes the
request and runs the controlled post-export workflow.
