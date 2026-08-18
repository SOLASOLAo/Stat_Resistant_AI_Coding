# Git and post-export orchestration

This directory is reserved for deterministic diff/report helpers consumed by
the active Codex/MCP session after `data/requests/export_request.json` appears.

The orchestration order is: Git diff, PLC text snapshot, ownership/hook audit,
I/O and Symbol Configuration audit, controlled MCP/REST repair, compile,
readback report and explicit commit.
