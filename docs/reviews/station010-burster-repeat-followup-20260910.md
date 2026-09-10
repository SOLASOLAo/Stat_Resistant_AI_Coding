# Burster MIDDLE recurrence after 88f0980 — 2026-09-10

## Status

**Field failed again at 12:45:42 after the ClearError removal candidate.**
The newest retained first fault is **ErrorCode 11**, standard Open, with
`OpconTcpClientIpV4Stream.Close` / invalid handle. The preceding ErrorCode 13
correction and its fresh F11 0 errors / 5 warnings are historical offline
evidence only. No further PLC implementation change or Build after this
latest recurrence; see the final section for the verified access boundary.

## Evidence and access boundary

- New operator screenshot: `codex-clipboard-6585f5d2-883b-40e9-855a-316c44117a69.png`.
  It shows MIDDLE guidance and the Burster invalid/closed socket alarm, but not
  the new selector ErrorCode or underlying operation's detailed text.
- Existing correct Station010 PLE, profile `ctrlX PLC 2.6.8`, compiler
  `3.5.19.70`; persistent MCP stopped with no ownership. No second IDE opened.
- Pre-correction selector implementation normalized-LF SHA:
  `cae05d7f9d5bff516623fbd2f97340062e2c18aa7d60716c6015cb5c6fa373e2`.
  Saved project SHA before this follow-up's pre-checkpoint Save was
  `11c428eb8b8ee42c19a92960226240a21d93a5fe36372555bca80e76446042bf`.
  This confirms offline source, not the downloaded application's fingerprint.
- The GUI returned `failed to activate captured window` on the initial
  activation and one fresh-window retry. App input stopped; desktop unlock
  was requested. No online watch values were obtained in that blocked phase. A LockApp process
  alone is not proof of lock state, and no lock/authentication UI was operated.
- Operator explicitly authorized Logout. The installed PLE OpenAPI documents
  ApplicationJob `Logout` as disconnecting to offline mode, distinct from Stop.
  Job `9e9be36a1136bcab` returned Done / successful Logout; subsequent REST
  Application.isOnline=false. No Start, Stop, Login, download or runtime write.

## Read-only review

The shared selector, its N045 caller, OnChainFinish cancellation, Station cyclic
cleanup hook, and the three-position caller were reviewed. Public stream
documentation still requires polling asynchronous methods and does not justify
ignoring an invalid-handle error. The local Burster Unit technical manual and
Peripheral version history do not expose the supplier's internal failing line.
No supplier implementation was decompiled or changed, and no network probe was
made to the instrument. Documentation extraction stayed in local ignored data.

The first pass required this failure's own ErrorCode and LastSocketError before
choosing another lifecycle change: code 2 identifies initial standard Close,
12 Reset preparation, 13 the previous ClearError preparation, and 11 standard Open. Those
are distinct paths, despite similar HMI alarm wording. Record state and both
return values when possible. Neither bypassing the selection handshake nor
caching readiness from a previous successful part proves the program or socket
is valid now; no such bypass was implemented.

## New first-fault evidence after unlock

- User unlocked the desktop and authorized one read-only Login if needed.
  No Login POST was sent: the initial GET was busy, then the existing PLE was
  already online. Read its Watch 3 only; Program loaded / Program unchanged.
- Selector retained ErrorCode **13**; LastSocketError Number=-1,
  NativeErrCode=32766, AddText=`OpconTcpClientIpV4Stream.Close`.
  In the applied source, code 13 is assigned only when standard ClearError
  fails/times out at state 66, after standard Reset state 65 returned OK.
  This locates the failing public call; it is not supplier-internal source proof.
- After cancellation: Execute/Busy/Done/Error FALSE, state=0, requested program
  0; sendLength/sendOffset=17/17, bytesWritten=1, bytesRead=2. Retained counters
  and idle state are not a new active transaction or a new measuring result.
- Authorized Logout job `2ec66403b1e39302` completed; REST isOnline=false before
  any PLC mutation. No Stop/Start, download, FORCE or instrument command.

## Small shared correction and verification

- Only `Application/Fbs/FB_Wp100BursterProgramSelect` implementation changed.
  Remove state 66 entirely: temporary EOT/Close -> standard Reset65 OK ->
  Open70 OK -> Done. Do not insert an empty success step or cache a previous
  position's readiness. Preserve all failures/watchdogs, first-error retention,
  per-owner cleanup, and Open-before-press gating.
- The temporary socket's initial ClearError remains; it is a different owner.
  No supplier library, generated declaration, TypeData/StationData, 27-step
  Run SFC, range, 2500 N / 2 s force or motion/safety logic changed.
- Regression first failed against the old source on Reset-to-Open/no-extra-
  ClearError, then all seven source/transaction suites passed. Project Pack
  Build/Check VALID, contentId
  `95a44cc940c6484e86d5e2e8f0024b258a2dcb281e1450036862e8acce3dd0ba`.
  These checks do not execute the supplier library or prove field behavior.
- Exact project/profile: Station010 `Stat010_V5.11_CtrlX_PLC.project`,
  `ctrlX PLC 2.6.8`, compiler `3.5.19.70`; original PLE session only.
  Pre-checkpoint Save job `f57c11ee0ce8ae22` preserved current project state.
  One content-addressed checkpoint, copied SHA-256 verified:
  `f1e10d49ec955c6454f85a39b6ce97251858dda6ebed0b764e2d48be5b3ab630`.
- Plan `0b72cb2cea4698392b250f61ebca3b8a5ecdb278f1c1d14998770eb91c07f739`:
  **1 implementation PUT / 1 Save after Apply / 40 targets read back**.
  Before/after target fingerprints differ only for the selector (39 unchanged).
- Fresh F11 observed Build started and complete after Apply. **0 errors /
  5 warnings / 155 Build information messages**: 4 x C0351 OPC.UA.DA ignored;
  1 x C0373 SymbolConfig ErrorCodes unsupported base type DWord. All signatures
  match the preceding batch; no formal warning baseline change. Ordinary
  Build, not Clean Build. The initial minimized-window block was resolved by
  the user restoring PLE; no unsupported REST Build action was used.
- After Build: offline, final PlanOnly **0 operations / 40 targets**,
  plan `d73ca73ea67fe9efc5ef4682e05466d87df4dfc29d87acf081881eb016e0e3a5`.
  Saved project SHA unchanged by Build:
  `80ccdf667c50c13960387506172cc2bc9799dd231098899cec4c4befc0112b14`.
  Selector implementation LF SHA:
  `4e10703b0b6eb9f0b2bdc1b1c7296a8958ca28a7079acfa2a037a20a1ec38c8e`.
- Machine-readable local records:
  `data/reports/plc/burster-clearerror-20260910-{plan,apply,post-plan,verification}.json`.

## Remaining field test and publication

No CpStudio Export needed for this implementation-only change. Operator to
confirm safety, download, then test LEFT -> MIDDLE -> RIGHT and a second
complete part. This removes the newly observed ClearError-stage defect;
the earlier Open-stage ErrorCode 11 is not proven solved until repeated-position
field testing passes. Preserve the new first code and LastSocketError if it
recurs; do not ignore failed Reset/Open or let the press advance on a fault.

Per the operator's new instruction, keep iterations local and push GitHub only
once the field version is stable, or after a separate explicit upload request.
No commit or push was performed.

## 12:45:42 recurrence after ClearError removal — current finding

- User screenshot `codex-clipboard-18a8f077-333f-42da-a912-ada3ef0e5029.png`
  shows MIDDLE guidance, Event 1 from Wp100A103ResistantInterface,
  `ETHERNET_TABLE General : Socket handle invalid or closed`, timestamp
  2026-09-10 12:45:42, AdditionalInfo `OpconTcpClientIpV4Stream.Close`.
- Existing PLE was already online. Read-only Watch 3: selector ErrorCode=11,
  Execute/Busy/Done/Error FALSE after cancellation, ProgramNo=0,
  LastSocketError Number=-1 and AddText Close. This is not reused ErrorCode 13.
  Standard socket ConnState=ERROR, retained local endpoint 192.168.0.51:32892
  and remote endpoint 192.168.0.103:5555. Endpoint fields after cancellation
  do not prove a currently open TCP connection or its initial failure state.
- PLE showed Program loaded / Program unchanged; REST selector source LF SHA
  `4e10703b0b6eb9f0b2bdc1b1c7296a8958ca28a7079acfa2a037a20a1ec38c8e`,
  project SHA `80ccdf667c50c13960387506172cc2bc9799dd231098899cec4c4befc0112b14`.
  The ClearError-removal implementation is present, not the older candidate.
- User's standing permission for AI Logout was used. Official Logout job
  `9549bc2bf0ad72b5` Done; subsequent Application.isOnline=false. No Login,
  Stop/Start, download, runtime write/FORCE, instrument probe or command.
- Re-read the complete shared selector and its N045/OnChainFinish/cyclic
  callers. In this source code 11 is assigned only when standard Open fails
  or times out after completed temporary EOT/Close and standard Reset.
  The public call boundary is located; the supplier's internal failing line
  or initiating defect is not proven. Do not add/remove lifecycle calls again
  solely because the HMI wording is the same.
- Current PLE Library Manager confirms `NexeedIpBurster2316 1.0.1.0` public
  methods: ClearError, Close, MeasCmd, Open, Reset, SetRangeCmd, UpdateInputs,
  UpdateOutputs and LastError property. MeasCmd takes
  BursterResis2316BaseSetting and a result reference; the setting structure
  contains temperature/range fields, no program number or arbitrary command.
  There is no exposed same-connection RCL/raw-stream hook in this interface.
- OOD 1.0.3.0 marks CXA/ctrlX NotTested; that metadata is not proof of a
  specific library bug. No compiled-library reverse engineering, private
  field writes, generated interface change, standard library edit or guessed
  enum command was attempted.
- Remaining decision: obtain a supported Nexeed program-selection/connection
  interface, or approve a separate single-owner Burster communication adapter
  that handles both program selection and measurement while retaining the
  CpStudio/HMI and force/motion contracts. This is a communication-layer change
  with a CpStudio binding boundary, not another one-step source patch.
  Do not silently disable program verification, use a permanent Ready cache,
  or present LEFT-only/once-per-part selection as solving repeated connection
  use. No replacement adapter has been implemented or approved in this pass.
- Latest pass is diagnosis only: project bytes unchanged, no new Build and
  no commit/push. The version is not field-stable and must not be published
  as a completed fix.
