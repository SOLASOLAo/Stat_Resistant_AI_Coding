# Station010 — Burster measuring-connection handoff, 2026-09-10

## Status

**Applied, saved and freshly compiled in the existing offline Station010 PLE:
0 errors / 5 warnings. Not downloaded or field-accepted.** The operator confirmed
Logout without PLC Stop. The first attempt paused after checkpoint creation when
Computer Use was stopped; the operator then explicitly requested continuation.
The resumed operation rechecked project/profile, offline state, checkpoint and
the full plan before its single implementation PUT.

## Read-only field evidence

The user ran automatic LEFT: safety door and pressing cylinder descended, no
resistance result was visible on the instrument, then HMI showed two Kistler
measurement-end timeout entries, the Wp100 force-interlock event and an unrelated
PartCounter service timeout.

Verified in the existing PLE session, not by launching a second IDE/MCP:

- Exact project: `../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project`, profile
  `ctrlX PLC 2.6.8`, compiler `3.5.19.70`, Application online/RUN.
- `AiWp100.BursterProgramSelect`: Execute TRUE, ProgramNo 0, Busy FALSE,
  Done TRUE, Error FALSE, ErrorCode 0. The program-selection ACK/EOT/temporary
  Close path has completed; this is new evidence beyond yesterday's N045 fault.
- N090 online action: `_bursterStarted = TRUE`, `_unitResult = RUNNING`,
  `_retVal = RUNNING`, resistance result not valid and value 0. This confirms
  that the application issued the SINGLE_MEAS request, **not** that the meter
  physically executed or completed it.
- The retained first force-event detail is
  `LEFT FORCE_DATA_INVALID F=2637.033 N`. It is not a below-2500 N diagnosis.
  The code latches this reason for loss of Kistler measuring state, Kistler
  execution/device alarm, or non-finite force data. The measured value in this
  event is finite and above threshold.
- After the force fault's cancellation handling, the standard Burster driver
  shows IsOpen FALSE, ConnState CLOSED, `_currentCmd = WAITING`, `_environDone`
  FALSE, LastError.Number 0 and no current read/connect timeout. Unit Execute is
  FALSE. **This post-cancel snapshot cannot prove its pre-fault socket state.**
- The existing N051 implementation already reserves PressForceTimeout + 30 s
  for Kistler measurement, retaining a larger configured value. No evidence
  justifies an unlimited measurement or bypassing force protection.

Two expression-only watches were added to existing Watch 3 for the retained
force-event detail and Burster Unit. No prepared value, write, force, alarm
acknowledgment, instrument command, PLC Stop/Start or download was performed.

## Confirmed source gap and bounded repair

The selector closes the standard `IpBurster2316` connection before its temporary
TCP session. Previously it reported Done immediately after temporary Close, and
N047 checked only the standard Unit's READY/Execute state. It never explicitly
restored the standard measuring connection. This is a verified handoff gap and
a plausible cause of the subsequent waiting; **the complete first-cause chain
still needs a new controlled field test**, since the retained driver state was
already affected by cancellation.

Only the AI-owned selector implementation changes:

1. ACK → EOT → completed temporary Close → new state 70, public standard
   `IpBurster2316.Open()` → Done only when that method returns OK.
2. Standard Open has a 35 s pre-motion watchdog. Failure/timeout retains the
   standard LastError and ErrorCode 11; it never releases Kistler or press-down.
3. Cancel or failed Open enters standard Reset (state 187), waits for the
   method to leave RUNNING, then completes standard Close before temporary
   cleanup. Reset timeout reports ErrorCode 12 only if no earlier error exists;
   it stays Busy while pending. No selection/measurement retry is introduced.
4. The standard connection is left to the standard Unit after successful
   handoff. No application write to driver private fields, generated ParCfg,
   range, program number, force limits, command/results or motion logic.

PLE Library Manager exposes Open and Reset as parameterless methods returning
DINT in NexeedIpBurster2316 1.0.1.0. This is public interface inspection, not
standard-library modification or reverse engineering. Existing project/manual
async contracts remain applicable. The standard library remains read-only.

## Verification and deployment gate

- Existing selector implementation read back via REST equals committed HEAD
  after line-ending/terminal-newline normalization. Exact REST implementation
  SHA-256: `2a718290fe56f6418973188e6c36709cf9a65c05309f875d4a77504c33dc6fea`.
  Only this observed upgrade baseline was added to the existing writer allowlist;
  unknown code and any declaration drift still fail closed.
- PASS: Test-Wp100BursterProgramRange, Test-SfcRestWriterPlanOnly,
  Test-SfcRestWriterTransaction, Test-ProjectFramework,
  Test-Wp100ForceInterlock, Test-RunOperatorGuidance,
  Test-SfcCompletionContracts. These are offline source, timing-model and mocked
  REST tests, **not execution of the vendor PLC library or instrument tests**.
- Project Pack Build and Check VALID, content ID
  `945a1a267e632c0f629b6cbe2291e07ec1c4fba9b3b8b0c8d2c730c45390257e`.
- Verified content-addressed checkpoint of the saved pre-change project:
  `fefa4e5e0c28abad95105e40ab87a65c506317e0cc39827a040f94d34bec170f`.
  Reused that exact checkpoint after the pause; no hash-identical second backup.
- Approved Plan SHA:
  `31d33db16281e1923e09c2bb63afeb812772da8c2b85a1e4c387595a5b3c6ed3`.
  Exactly one PUT, `Application/Fbs/FB_Wp100BursterProgramSelect`, and one Save;
  40 targets verified before/after persistence. All declarations, other actions
  and the 27-step Run graph remained unchanged.
- Saved project SHA (unchanged after F11):
  `ea8707274be28258f155dd74fc3027388beee6d1f4c3b45eb2b649861dea5919`.
  Final selector implementation SHA:
  `333bbff542217cb21464ceb405a0d04b6b6a871d1100d98313390891ef4e9292`.
- Observed fresh F11 Build started and Build complete in the same PLE window:
  **0 errors / 5 warnings**, 156 Build information messages (157 across all
  message categories). The actual warnings are four C0351 `OPC.UA.DA` unknown
  attribute entries and one C0373 SymbolConfig `ErrorCodes` unsupported base
  type `DWord`, matching the previous batch. No new warning; the formal baseline
  and Symbol Configuration were not changed. This is compilation evidence, not
  runtime Symbol or instrument acceptance.
- At 2026-09-10 11:20:59 +08:00, exact project/profile and offline state rechecked.
  Final PlanOnly: 0 operations / 40 objects; plan SHA
  `d8280461594b02ef563378a4fdf13d57f55208296fd9d73b1b909e62a7c3625d`.
  Reports: `data/reports/plc/burster-measuring-handoff-20260910-{plan,apply,post-plan,final-plan,verification}.json`.
- No CpStudio Export or AutoRange edit required. No download, runtime write,
  FORCE, machine movement or instrument command was performed by the agent.

## Field acceptance after offline validation

The operator handles safe recovery and download. Check, in order:

- Program 0 selection finishes only after standard Open; selector ErrorCode 11
  isolates a reconnect failure before the press can start.
- Press down → force >2500 N continuously for 2 s → SINGLE_MEAS accepted →
  resistance result returned → Kistler END and press return complete.
- Repeat MIDDLE and RIGHT; verify cancellation during reconnect, plus the
  existing force-loss and force-wait timeout holds without automatic press-up.
- If N090 still waits, capture Burster ExecState, Execute, public LastError,
  current driver command/step, and Kistler timeout/state **before** Kistler times
  out. Do not present the current post-cancel CLOSED state as the original cause.
- PartCounter service timeout remains separate and unmodified; it is not
  established as the blocker for the resistance-measurement chain.
