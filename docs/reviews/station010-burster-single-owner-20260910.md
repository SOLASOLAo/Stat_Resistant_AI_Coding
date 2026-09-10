# Burster single-owner candidate — 2026-09-10

## Status and authority

**Offline adapter staged and compiled. NOT integrated, downloaded or field-tested.**
The deployed two-owner candidate still failed at 12:45:42 with selector error 11,
standard Open, and `OpconTcpClientIpV4Stream.Close` invalid/closed handle. This
change removes the handoff in the proposed architecture; it is not evidence that
the supplier's private implementation is defective or that the field fault is fixed.
User approved this direction with “改吧”. No new online/hardware operation was made.
Do not publish to GitHub until the user confirms the version is field-stable.

## Implemented, kept inert

- New `Application/Fbs/FB_Wp100BursterSingleOwner`, implementing the public
  `IBursterResis2316 EXTENDS IOpconAsyncCall` interface, including inherited
  `LastError`. Library Manager and PLE-generated interface stubs verified the
  contract in NexeedBursterResis2316Base 1.0.0.0.
- One `OpconTcpClientIpV4` instance for identification, program selection/readback,
  single measurement, status, resistance and optional temperature. No other driver
  calls and no network operation in the FB body. No instance/binding added yet.
- Documented Ethernet fast-selection framing: address 0000, TCP 5555, no BCC;
  complete ACK/CR and STX/payload/CR/LF/ETX/[CR]/EOT/CR consumption. Bounded
  per-scan I/O; fragmented read/write support; no automatic command replay.
- `*RCL n` + `*RCL?` + error check before SelectionVerified. Program 0..15.
- SINGLE_MEAS: reject an already running measurement; discard stale EOC value;
  confirm it cleared; set single-shot mode; send INIT once; wait for EOC and not
  measuring; check questionable status; strictly parse resistance in Ohm and
  temperature in Celsius. No malformed/overflow response is returned as good zero.
- Cleanup finishes pending calls/whole replies, checks for an active measurement
  before ABOR, sends EOT before one Close, and never calls Close on a closed stream.
  Bounded failure blocks reuse; the first error survives subsequent cleanup faults.
- Local errors supply a valid LastError using the existing TableEthernet event
  table and numeric context; real underlying socket errors are retained unchanged.

All standard libraries, generated interfaces, Unit bindings, SFC steps, force
interlocks and production selector were kept unchanged. The production selector's
implementation SHA remains `4e10703b0b6eb9f0b2bdc1b1c7296a8958ca28a7079acfa2a037a20a1ec38c8e`.

## Deliberate limits / work not yet done

- SET_RANGE currently returns a clear unsupported-command error (1301), not a fake
  success. Automatic ranges/compensation remain instrument-program-owned. If manual
  range-setting is required later, agree and implement that separate function.
- Manual Start Single Measure **before any verified program selection** is not yet
  connected. Integration must route active TypeData.ProgramNo through the same owner
  for manual as well as automatic measurement; preserve existing Unit/HMI behavior
  and do not silently require an automatic cycle first.
- Actual firmware EOC clearing after FETC, numeric/unit formatting, command ACK
  semantics, repeated connections, cancellation and error recovery remain field
  acceptance items. The candidate fails closed if its stale-result check fails;
  never remove that check just to make a second position run.
- A stuck/uncertain I/O cleanup requires explicit recovery. No background retry,
  disconnect/reconnect loop, private socket-handle edit or runtime FORCE was added.

## Checkpoint, write and Build evidence

Only the exact offline Station010 project/profile was targeted through its existing
PLE REST session. MCP was not used to launch a second PLE. Project identity/offline
checks, exact declaration/implementation baselines, immutable PlanOnly SHA, second
pre-write GET, content-addressed checkpoint, reverse rollback and post-Save readback
guard every mutation. CpStudio-generated fields were not overwritten.

The first creation attempt hit PLE's auto-generated interface methods. Its transaction
rolled back successfully. The writer now creates the interface shell first, then
freezes actual PLE stubs in a second plan. The staging compile revealed a reserved
`r` local variable and a property-component access limitation; both were fixed,
along with signed index warnings. Final source and PLE readback match all 15 objects.

- Final application: `../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project`.
- Final saved project SHA-256:
  `ed7f11a5e71af70977d150b5e225e80e9b69145f652a93218cbfa426784a6e94`.
- Final zero-mutation plan SHA:
  `87c46a8c358a8bb43b7e47e512d640c8643e15a39404aabca0188e2b281430d7`.
- Fresh F11 in the user PLE completed **0 errors / 5 warnings**, 155 total messages.
  All five were expanded and read: 4 × C0351 (OPC.UA.DA unknown attribute),
  1 × C0373 (SymbolConfig ErrorCodes unsupported base DWord, line 2378).
  No new warning signature; no formal warning-baseline change.
- Final REST Application.isOnline=false. AiWp100 has no new driver instance;
  generated `iBursterResis2316 := _Wp100A103ResistantInterface` remains in place.
- Reports: `data/reports/plc/burster-single-owner-*-{plan,apply}.json` and
  `burster-single-owner-final-plan.json`. Project checkpoints are under
  `data/checkpoints/plc/` (hash-named .project copies).
- CpStudio saved Engineering backup: `data/checkpoints/cpstudio/20260910-single-owner-before-unbind/`.
  Five files copied and SHA-256 verified; source unchanged during copy. Lock file
  excluded. This is the disk-saved Engineering definition, not an entire deployment
  backup or proof of unsaved editor content. Engineering_Data.xml SHA:
  `2f3b6d3d23d2fdeabaa6ecd3d0c4335bc3ad4f0e32d98bd1fc184cf5de941a46`.

## Offline checks

`py -3.12 tests/offline/test_burster_single_owner_protocol.py`: **15 tests pass**.
Wire fixtures, fragmentation/numeric oracles and ST source contracts only; not
execution of compiled PLC code, not instrument simulation/acceptance.

Seven existing regression suites pass: BursterProgramRange, ProjectFramework,
Wp100ForceInterlock, RunOperatorGuidance, SfcCompletionContracts,
SfcRestWriterPlanOnly and SfcRestWriterTransaction. The shared transaction helper
keeps existing writers implementation-only; declaration updates require explicit
AI-owned full-object opt-in and now have exact rollback coverage.

Project Pack Build/Check: VALID, contentId
`2374350ef6e6076bb80dc6aae922c650d99667e23006bf36c2e6284c2e5f7658`.
`readyForEngineering` is pack readiness, not deployment readiness.

## Required next CpStudio / integration gate

Read-only UI navigation confirmed this exact path:
Model → Station → Wp100 → Wp100A103ResistantDetector → Parameters → Burster 2316 Channel.
Its current value is `Wp100A103ResistantInterface Channel`. The port is optional
in the standard OOD; clear this assignment in CpStudio. Keep the Detector Unit,
its HMI, TypeData, StationData and all other peripherals.

Under Peripherals, only the old non-bus `Wp100A103ResistantInterface` is to be
removed through CpStudio's **Remove** command. Its Sub items Active is greyed;
there is no enabled context-menu Disable command. Never delete the similarly named
`Wp100A103ResistantDetector` in Model. AI only inspected the menus; no removal,
assignment change, Save or Export was performed in CpStudio this turn.

After user Save/Export, **do not download the interim project**. AI must:

1. Verify the new export and absence of old Peripheral registration/cyclic calls.
2. Add the AI-owned instance and non-generated lifecycle/binding hook, not an
   override of a still-bound CpStudio parameter.
3. Replace the old selector implementation with a same-owner delegator; update
   N046's removed peripheral AutoRange guard to verified program-owned readiness.
   Preserve N045 program confirmation, both branch results, force/position checks
   and command handshakes. No blind true/OK gate.
4. Wire manual selection from active TypeData without double selection/concurrent
   calls during Unit Open/MeasCmd/Reset/ClearError. Finish cancellation ownership.
5. Re-read and compile the **integrated** application; check Symbol/export consistency,
   then separately authorize field download/testing. This staging Build is not that
   future integrated Build.

Field acceptance must cover manual measurement; LEFT→MIDDLE→RIGHT and another
complete cycle; program change; resistance grade/temperature; low/invalid force;
cancel before/after INIT; disconnected instrument/NAK/timeout; no duplicate INIT,
no stale resistance as a new result, and no conflicting socket owner.

Protocol source: `../Technical Docs/BA_2316_EN.pdf` (Ethernet pp.62–64,
status p.68/91–92, measurement pp.85–87, temperature p.96, RCL p.113).

## Post-unbind integration — 2026-09-10 (latest)

User Export request `47c44845-dae8-4d94-a25c-006feee0d90e` removed the
old optional channel/Peripheral. Targeted REST readback confirmed no old instance,
hierarchy registration, task-link call, generated parameters or generated Unit
binding. All 15 staged driver objects still matched. I/O audit: 56/56 matched,
38 active / 18 inactive. Fresh post-Export Build: 50 errors / 5 warnings from
the old selector's now-missing Peripheral references; this was an expected
incomplete integration, not a downloadable state.

Implemented and read back:

- One instance `AiWp100.Burster`, still implementing the standard
  `IBursterResis2316` interface. The standard Detector Unit/HMI and grading stay.
- Outside-OES child-interface binding in Wp100Unit.OnApplyParameters on STARTUP,
  CONFIGURATION and ONLINE_CHANGE. Existing endpoint 192.168.0.103:5555;
  measurement operation deadline 30 s. OnCall copies active TypeData.ProgramNo
  only; no background network/measurement command.
- Old selector replaced by a socket-free delegator. Its Open/Select share the
  owner used for all Unit commands. First failure is retained through same-owner
  Reset; cancellation pump remains. Dropping Execute after Done performs no
  owner Reset, so it cannot close a subsequent measurement.
- N046 requires connected, idle, error-free and verified matching program. All
  other SFC actions/branches, sensor In checks, force monitoring and standard
  command/results remain unchanged.
- Manual SINGLE_MEAS no longer requires a previous automatic selection. It
  serializes Open and (if needed) program selection on this owner, snapshots
  parameters, then freshly queries RCL before INIT. Already verified N045
  selection is not recalled again under load. A program change mid-command or
  instrument-side mismatch fails closed. Manual SET_RANGE release is disabled;
  unsupported range commands are never acknowledged as success.

Reviewed full-object writes are limited to AI-owned declarations. Every mixed
declaration and OES region is preserved. The extended writer only integrates
when the old generated registration/binding is absent, uses exact legacy hashes,
frozen requests, a second GET, checkpoint, reverse rollback and saved readback.

- Pre-write project checkpoint SHA:
  `3f4736fd9f99924e7a956ba24d81476e2d8bd2d895ff01ddb4621cc81afb2e95`.
- Apply plan SHA:
  `325df1dcdefb0561d3aae7646778e11a6df694732dddad6b4fc2773d5d2928fb`.
- Nine PUTs / one Save; 21 target objects match after Save.
- Saved project SHA, unchanged by fresh Build:
  `fbd91124bea48c8e3aefa3dad14429f9e8b90a19dd702d65a5a94f56c109e328`.
- Integrated final PlanOnly: zero mutations, SHA
  `e2a59a12ef443e903546b4399f41f3d1375f29b51c4d9cf29b51681e25bf1615`.
  Existing Run writer: 40 targets, zero mutations, SHA
  `68e943a72f1cc5e286a58771db0200475d6e29d002293f3ae9d814372d48003f`.
- New F11 **0 errors / 5 existing warnings**, 189 Build messages (190 total).
  All five visible: 4 C0351 OPC.UA.DA, 1 C0373 ErrorCodes/DWord at line2378.
  No baseline approval/change is inferred from the count.
- 17 protocol/source checks and all seven previous regression suites pass.
  These are source contracts/reference timing oracles, not executed PLC tests.

### Export #2 request after integration (historical; completed below)

The actual CpStudio PLC Export output was inspected after the successful Build:
`Error getting the symbol configuration! ... Build has error(s). You need error
free build to proceed`. Export #1 stopped its Symbol phase before integration.
The new PLE Build does not replay that export step. User has been asked to
Export again, not download yet. Verify hook retention and the single binding,
then perform a fresh Build after Export #2. Do not reset Symbol configuration,
claim HMI/DataSetAccess deployment, or relabel this as field-success evidence.

Stage 2 ledger for request `47c44845` is WAITING_FOR_RUNNER; no typed Runner
completion was fabricated from REST/UI evidence. Its immutable manifest hashes
predate integration. Use the next Export's fresh action, not the stale request,
and never start a second PLE to satisfy that ledger.

No PLC Login/download/start/stop/force/runtime write or instrument request was
performed. No Git commit/push; wait for user field-stability confirmation.

## Export #2 verified — 2026-09-10 14:05 local

User export request `c5beb205-8e88-4657-a986-a3faa2342de3` was previewed,
then consumed by Stage 1. The audit has only the generated-changes review
finding; 56/56 I/O channels match, 38 active / 18 inactive, no mismatch.
No engineering source or project was modified in this verification turn.

The current REST project/profile/compiler were verified, and Application was
offline before and after the checks. Integrated driver PlanOnly readback is
21 targets / zero mutations (`e2a59a12...5bf1615`), and the Run writer is
40 targets / zero mutations (`68e943a7...d48003f`). The obsolete Peripheral is
still removed, and the same-owner instance, hooks, selector, N046 and manual
release survive CpStudio export intact.

The actual CpStudio PLC Export Output pane is empty. A new F11 in that same
offline PLE visibly started and completed with **0 errors / 5 warnings**,
189 Build messages (190 total). The five warnings remain 4 C0351 OPC.UA.DA
and 1 C0373 ErrorCodes/DWord. No warning baseline was changed or approved.

The fresh Symbol XML timestamp is `2026-09-10T06:03:42.5637583Z`; its SHA is
`0455ce885d886b387d6f252478c4b40c079f288f7e768792433d4a3ff590ef8c`.
It retains StationData, TypeData, Burster.ProgramNo (INT / ReadWrite), and the
Detector Extension's InHmi/OutHmi, ExecStartMeas and command release/state
members. There are zero obsolete Peripheral-name occurrences. The symbol-config
REST endpoint returns HTTP 200 but cannot be decoded by the local strict JSON
reader; no raw payload was logged and no Symbol selection was edited. These
are scoped Export/Build/XML checks, not a full typed semantic-baseline result.

The project SHA after export and after Build is identical:
`077eebed69481d90e6f07ff5a4eccc2ec4eeaab3712d7ed704e2cfb2caf2c886`.
All 17 protocol/source tests and the program-range, force-interlock and SFC
completion static suites were rerun and passed. They do not execute the PLC
library or prove instrument behavior.

New Stage 2 ledger:
`cpstudio-stage2-c5beb205-8e88-4657-a986-a3faa2342de3-7064637d` remains
WAITING_FOR_RUNNER. The existing interactive PLE was inspected through REST/UI;
no second persistent PLE was started and no Runner evidence/DONE was fabricated.
Independent observations are recorded in
`data/reports/plc/burster-single-owner-export2-verification.json`.

The offline candidate is ready for the user's site-safe download and tests;
no routine third export is required. IPC HMI/DataSetAccess deployment remains
unverified and must match this project. Test manual SINGLE_MEAS, then
LEFT/MIDDLE/RIGHT and another full cycle before calling the repeat-connection
fault resolved; also safely validate program changes, cancellation/recovery and
the original force interlocks. No download, PLC action, instrument request,
Git commit or push was performed by AI.
