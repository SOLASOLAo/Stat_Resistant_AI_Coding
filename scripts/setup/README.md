# Workstation setup

`Test-TeamWorkstation.ps1` performs a read-only deployment check for a new
developer computer. It derives the Station and `Std` paths from
`config/project.yaml`, checks the pinned vendor tools and MCP package, and runs
the ctrlX compatibility patch in `-Check` mode.

It never starts an IDE, opens or saves a project, connects to a PLC, or changes
the npm package.

`New-DevelopmentPcMigrationBundle.ps1` prepares a minimal transfer package in
the company OneDrive. It records the three Git commits, archives the current
encrypted PLC project, and packages `Std` plus `Technical Docs`. It deliberately
excludes plaintext connection credentials, licenses, IDE caches and Git data.

Close CpStudio, PLC Engineering and IO Engineering, preview once, then create
the bundle:

```powershell
.\scripts\setup\New-DevelopmentPcMigrationBundle.ps1 -WhatIf
.\scripts\setup\New-DevelopmentPcMigrationBundle.ps1
```

OneDrive is only the transfer channel. Extract the package and clone the Git
repositories into a normal local workspace on the new computer.
