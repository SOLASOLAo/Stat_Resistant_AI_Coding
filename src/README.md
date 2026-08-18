# PLC source assets

`src/plc/common` contains canonical text for fully AI-owned, reusable POUs.
`src/plc/project` contains project-specific AI code when an entire object is
AI-owned. CpStudio-generated or mixed objects are governed by `ai/hooks.yaml`
instead of being mirrored and overwritten wholesale.

These files are applied to the encrypted PLC project only through PLC
Engineering MCP/REST interfaces. They are never written directly into a
`.project` container.
