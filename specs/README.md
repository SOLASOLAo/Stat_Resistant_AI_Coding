# Project specifications

This directory is the reviewed, machine-readable description of the project.
CpStudio remains the source of truth for its generated model; these files record
the process intent that AI uses to implement and audit PLC logic.

- `station.yaml`: Station hierarchy and standard AddOns.
- `io.yaml`: project-used signals and verified physical mappings.
- `events.yaml`: application event contracts.
- `units/`: Unit instances, bindings and interlocks.
- `chains/`: SFC process intent, steps, conditions and cleanup.

Do not store passwords, PLC credentials, production data or copied proprietary
manual contents here.
