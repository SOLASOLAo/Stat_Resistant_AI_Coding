# Workstation setup

`Test-TeamWorkstation.ps1` performs a read-only deployment check for a new
developer computer. It derives the Station and `Std` paths from
`config/project.yaml`, checks the pinned vendor tools and MCP package, and runs
the ctrlX compatibility patch in `-Check` mode.

It never starts an IDE, opens or saves a project, connects to a PLC, or changes
the npm package.
