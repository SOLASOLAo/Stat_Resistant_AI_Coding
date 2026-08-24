# PLC Engineering helpers

- `export_plc_snapshot.py` runs inside the active PLC Engineering IronPython
  ScriptEngine and exports deterministic Application text objects.
- `verify_plc_snapshot.ps1` validates the snapshot manifest and optional source
  project hash.
- `apply_wp100_run_rest.ps1` plans or applies the AI-owned
  `SqS_Wp100_Run` parallel SFC graph, Action/cleanup implementations and result
  DUTs through the active PLC Engineering official REST extension. The
  CpStudio-generated chain and existing Method declarations are verification
  contracts only and are never assigned by the writer.
- `apply_wp100_run_sequence_rest.ps1` applies `SqC_Wp100_Run`: the linear
  LEFT/MIDDLE/RIGHT command SFC, product-detection method, cleanup, actions and
  three-position result DUT. Obsolete CpStudio example actions are reported but
  retained; deletion is disabled until it has its own reviewed migration.

Both writers default to `PlanOnly`. A plan performs source/interface and
existing-object checks but sends no POST/PUT/Save request. The shared
`SfcRestWriter.Transaction.ps1` guard freezes every POST/PUT body as canonical
JSON, includes the complete JSON plus the Save request in the deterministic
plan SHA-256, and sends those exact UTF-8 bytes during Apply. A repeated GET can
never replace the first preflight snapshot; the second full-object GET/hash
pass and an immediate per-request precondition both run before mutation.
Every POST parent (including `Structs/Data` for a new DUT) must also have an
immutable snapshot, so indirect `children`/metadata changes are covered by the
plan and rollback verification. After a successful Save, both writers repeat
the complete graph/Action/Method/DUT readback and declaration/hash checks.
Before either PlanOnly or Apply can finish, the writer also resolves the
CpStudio-generated `AutoInfoLineEnum` DUT through read-only PLE REST and checks
that append-only symbols 4..16 exist in order. Explicit numeric assignments are
checked when exposed by the REST declaration; otherwise the gate records the
REST limitation and verifies symbol presence/order. A missing item stops before
any mutation and tells the user to Save/Export it from CpStudio.

After CpStudio Save/Export, review a fresh plan before the explicit Apply:

```powershell
$plan = .\scripts\plc\apply_wp100_run_rest.ps1 | ConvertFrom-Json
.\scripts\plc\apply_wp100_run_rest.ps1 `
  -Mode Apply `
  -ExpectedPlanSha256 $plan.planSha256
```

If any mutation, target readback, declaration check or Save job fails, every
attempted request is rolled back in reverse order. Existing objects are restored
from their immutable complete snapshots, created objects are deleted, the
restored state is saved, and every target is read back again. A failed recovery
is reported as `ROLLBACK FAILED` and is never presented as success. The plan's
rollback payloads are executable and hash-bound, not descriptive placeholders.
An all-verified PlanOnly result has no operations and performs no Save.

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

The Run-chain appliers save only through PLC Engineering `ProjectJob` in an
explicitly authorized Apply. They do not connect to a controller, download,
start the application or write runtime variables. Run them only while the
intended Station010 project is the single active PLE project.

If a project suddenly reports hundreds of contradictory missing-member or
ambiguous-library errors while a native export comparison shows identical
source, libraries and I/O mappings, close the project normally and move only
its sibling `<project-name>.precompilecache` out of the project directory.
Reopen, wait for library loading, then run a true Clean Build. Do not regenerate
the CpStudio project or rewrite device mappings until this cache isolation has
been tried.
