# PLC Engineering helpers

- `export_plc_snapshot.py` runs inside the active PLC Engineering IronPython
  ScriptEngine and exports deterministic Application text objects.
- `verify_plc_snapshot.ps1` validates the snapshot manifest and optional source
  project hash.
- `apply_wp100_run_rest.ps1` applies the AI-owned `SqS_Wp100_Run` declaration,
  parallel SFC graph, Action/cleanup implementations and result DUTs through
  the active
  PLC Engineering official REST extension. It verifies the CpStudio skeleton
  hashes before first application and performs exact readback on every rerun;
  an all-verified rerun skips both PUT and project save.
- `apply_wp100_run_sequence_rest.ps1` applies `SqC_Wp100_Run`: the linear
  LEFT/MIDDLE/RIGHT command SFC, product-detection method, cleanup, actions and
  three-position result DUT. It also hash-checks and removes the obsolete
  CpStudio example actions after replacing the graph.

Every generated PLCopenXML SFC `<transition>` has an explicit internal
`name="SourceStep__to__TargetStep"`. Omitting this attribute makes PLE persist a
null `VariableName`; the graphical editor may still look plausible, but later
native export/import or code generation can fail. `Test-ProjectFramework.ps1`
guards both Run-chain writers against unnamed transition tags and calls.

PLE REST has an asymmetric normalization rule: PUT must contain the transition
`name`, while a later GET omits that attribute even when the native
`VariableName` is valid. The writers therefore hash both the named desired XML
and the normalized REST readback XML; this keeps reruns idempotent without
dropping the name from writes.

OpCon `SetEvent` accepts `AdditionalInfo : STRING(63)`. Canonical PLC sources
must keep a literal third argument at 63 characters or fewer; the static test
checks this and prevents compiler warning C0198.

The exporter uses `se.projects.primary`; it never opens a second project,
saves, compiles or performs online operations.

The Run-chain appliers save only through PLC Engineering `ProjectJob`; they do
not connect to a controller, download, start the application or write runtime
variables. Run them only while the intended Station010 project is the single
active PLE project.

If a project suddenly reports hundreds of contradictory missing-member or
ambiguous-library errors while a native export comparison shows identical
source, libraries and I/O mappings, close the project normally and move only
its sibling `<project-name>.precompilecache` out of the project directory.
Reopen, wait for library loading, then run a true Clean Build. Do not regenerate
the CpStudio project or rewrite device mappings until this cache isolation has
been tried.
