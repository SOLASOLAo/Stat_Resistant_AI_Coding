# AI increment control

The AI increment layer contains ownership and integration contracts. It is not
a second PLC project and does not replace CpStudio.

- `ownership.yaml` maps PLC objects to their authoritative source and write mode.
- `hooks.yaml` records calls and safety/lifecycle behavior that must survive a
  CpStudio export.
- `graphical.yaml` records SFC graphical attributes written through the official
  PLC Engineering REST extension API.

Whole AI-owned POUs may be reapplied from `src/plc/` through MCP. Mixed generated
objects must be merged semantically; never overwrite the entire object blindly.
