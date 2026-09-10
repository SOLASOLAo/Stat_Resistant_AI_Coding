# Burster repeated-position reconnect lifecycle — 2026-09-10

## Status

**Applied, saved and freshly compiled offline: 0 errors / 5 warnings.** The
operator confirmed Logout, and the existing correct PLE session was verified
offline before writing. No download, PLC action or instrument command was made.
MIDDLE/RIGHT and repeated-cycle hardware acceptance remain pending.

## New field evidence

- The operator reports LEFT completed normally after the previous fix. MIDDLE
  then closed the safety door but did not lower the press; HMI displayed
  `ETHERNET_TABLE General : Socket handle invalid or closed`, with additional
  text `OpconTcpClientIpV4Stream.Close`, at 2026-09-10 11:26:42.
- The agent inspected the existing correct Station010 PLE session, online/RUN;
  MCP ownership was none and no second IDE/MCP was started.
- Selector retained ErrorCode **11**, not 2: the failure was captured in standard
  **Open/handoff**, after numeric program selection and temporary EOT/Close.
  LastSocketError.Number = -1, NativeErrCode = 32766, AddText =
  `OpconTcpClientIpV4Stream.Close`. This first-error copy was already taken before
  the selector's error-cleanup Reset; the entire original fault cannot be
  attributed solely to the later redundant cleanup Close.
- Retained counters: requested program 0, send length/offset 17/17, written EOT
  byte 1, received bytes 2. At inspection, Execute/Busy/Done/Error were FALSE,
  `_state = 0`, and the numeric first ErrorCode remained 11 after cancellation.
  Standard LastError retained the same Close signature; its step variables were
  already reset to 0. These are post-cancel values, not a trace of the library's
  private state at its first invalid-handle operation.
- REST selector implementation SHA still matched the previous applied batch:
  `333bbff542217cb21464ceb405a0d04b6b6a871d1100d98313390891ef4e9292`.
  Only this observed baseline is added to the existing guarded writer.

LEFT success is useful operator-reported field evidence for the earlier handoff,
not acceptance of MIDDLE/RIGHT or repeated full production cycles.

## Diagnosis and repair scope

The application explicitly closes the standard measuring connection for each
program-selection session, then previously called standard Open without a fresh
standard Reset/ClearError lifecycle. The temporary socket was reset, but that is
a different owner and does not reset the standard driver's state. Reuse after
LEFT exposed an Open-stage error with a Close signature. Driver lifecycle reuse
is the working diagnosis; the supplier library's exact internal failing line
has not been observed, so field confirmation remains required.

One independently confirmed application defect was the previous error cleanup
`standard Reset -> standard Close`: the local NxBase technical manual explicitly
states that Reset closes the stream. A second Close is unnecessary and can use
an already invalid handle. Correcting it does not by itself prove the origin of
the first ErrorCode 11.

The shared AI-owned selector implementation now:

1. Preserves standard Close -> temporary numeric RCL ACK -> EOT -> completed
   temporary Close; no concurrent connections and no program/range override.
2. Takes standard **Reset (65) -> ClearError (66) -> Open (70)** on every
   selection, including MIDDLE/RIGHT and future LEFT cycles. Each preparation
   method must return OK; the existing Open-OK gate still controls Done.
3. Gives Reset/ClearError separate 3 s watchdogs and errors 12/13; failed or
   timed-out preparation enters standard cleanup rather than clearing a newly
   captured error and pretending readiness. No automatic retry or cached bypass.
4. Cancels pending standard Reset/ClearError/Open via standard Reset, polled to
   completion; then goes directly to temporary cleanup, **without another
   standard Close**. Pending Reset remains Busy; the first failure is retained.

No standard library/private-field write, generated declaration, SFC graph,
StationData/TypeData, AutoRange, 2500 N/2 s force logic, press or door command was
changed. A failed preparation still blocks press-down before force monitoring.

## Public interface and tests

- Existing Library Manager: NexeedIpBurster2316 1.0.1.0 exposes Open, Close,
  Reset and ClearError. Local NxBase documentation provides parameterless DINT
  async Reset/ClearError contracts; successful Reset closes the stream, pending
  methods must be polled, and errors require a new Open after ClearError.
  References: local extracted `5cc96dcf-1c54-45bf-b3d4-d1ec775fa3e3.htm` (Reset),
  `eeeabdd0-6e57-4e21-9060-59a935f440f9.htm` (ClearError). No supplier manual or
  implementation is copied into Git.
- Source tests enforce the single Reset/ClearError/Open entry path, no Close
  after Reset, preparation failures/timeouts, per-owner cancellation and first
  error retention. These inspect actual ST but **do not execute the supplier
  PLC library or prove repeated-position operation on hardware**.
- Project Pack content ID:
  `7e3cef4657eeba73bfe3e865ba512a99483210f601d9eb0c3fd466b38c1bc558`.

## Completed offline validation

- Exact Station010 project/profile `ctrlX PLC 2.6.8`, compiler `3.5.19.70`;
  existing PLE REST only, no second IDE or MCP takeover.
- Saved pre-change checkpoint, verified by SHA-256:
  `42545d1db9aced74c114d51361a1cf090911d6ef8b89552c2e465f443079089d`.
- Guarded apply plan:
  `badd5cd7ecbe63a137cc94b86d30345d3b2734a8f081153a4c846c838aab019e`.
  Exactly one implementation PUT and one post-apply Save; 40 targets read back,
  declarations and the 27-step Run SFC unchanged.
- New F11 Build started/completed was observed in this PLE, with **0 errors /
  5 warnings**. All five visible warnings were checked: four C0351
  `OPC.UA.DA` attribute warnings and one C0373 `ErrorCodes`/`DWord` SymbolConfig
  warning, matching the preceding batch. Formal warning baseline not changed.
- Seven checks passed: Burster program/range source contracts, project
  framework, force interlock, operator guidance, SFC completion, REST PlanOnly,
  and REST transaction regression. Project Pack Build/Check: VALID.
- Final post-Build PlanOnly: **0 operations / 40 objects**, SHA
  `4d8fded0c0eedb7b0fcc777b993e6a5fc54d606980b8e33f84fbad7f3886195e`.
  Saved project SHA, unchanged by Build:
  `11c428eb8b8ee42c19a92960226240a21d93a5fe36372555bca80e76446042bf`.
  Selector implementation normalized-LF SHA:
  `cae05d7f9d5bff516623fbd2f97340062e2c18aa7d60716c6015cb5c6fa373e2`.
- Local evidence: `data/reports/plc/burster-repeat-lifecycle-20260910-` files
  `plan.json`, `apply.json`, `post-plan.json`, `verification.json`. Checkpoint,
  reports, vendor documentation and project binaries stay local, outside Git.

## Required field check after offline validation

The operator handles safe download and normal fault acknowledgment/restart.
Retest LEFT -> MIDDLE -> RIGHT and then another complete part, not just LEFT.
Verify each position selects the active program, restores the measuring
connection, qualifies force, returns a resistance result and releases normally.
If preparation fails, preserve selector ErrorCode 11/12/13, LastSocketError and
stage before acknowledgment; do not bypass interlocks or repeatedly force
measurements. No CpStudio Export or AutoRange edit is needed for this batch.
