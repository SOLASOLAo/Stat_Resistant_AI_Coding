# Kistler inactive-MP / N045 ordering repair — 2026-09-10

## 16:59 one complete automatic cycle observed

The user explicitly requested running the automatic process immediately. With
MP001 selected, Ready active and no red alarm observed beforehand, the agent
selected Automatic and clicked the normal HMI Start exactly once at
2026-09-10 16:57:18.420 +08:00. Fixture movement and physical pushbutton inputs
remained with the on-site operator; no input, interlock or Ready bit was forced.

HMI observations (local time):

- 16:57:28: waiting for the physical start button at the left position.
- 16:58:27: safety door opening.
- 16:58:51: measuring the right position.
- 16:59:12: measurement complete; Station in home position green; normal Start
  available again and Stop disabled. Automatic mode remained selected, but the
  cycle had ended. No second cycle was started.

No red alarm was visible in these observations; the existing blue PartCounter
service read-timeout warning remained. This is sampled HMI evidence, not a
continuous alarm or force trace. The parent SqC_Wp100_Run copies each position's
result only after the corresponding subchain completes and sets the completion
message at N999, supporting completion of this one left/middle/right cycle.
The machine illustration itself was not used as evidence of physical movement.

No PLC implementation change, build, download, alarm suppression or Git push was
performed in this run. Preserve the user's checkbox-only MP000/MP001 Active
setting and production TypeData program1. This supersedes earlier notes saying
no complete automatic cycle has been tested; it does not establish the exact
closed-source AUTO/MP handshake or universal firmware requirements.

Remaining acceptance: read retained Wp100.SqC_Run.Result.Left/Middle/Right
resistance values and Valid/Ok flags (a completed response need not mean quality
OK), verify a subsequent cycle/restart, and separately validate force-fault
holding. Numeric product quality, continuous force stability and long-run
reliability were not independently verified by this observation.

## 16:54 Active checkbox-only change restores manual program selection

The user explicitly did not want to configure program0, and reported changing
only its Active checkbox. MP000 and MP001 are now both checked; their program
contents were not copied/configured as part of this test. The user then tested
standard HMI Set program=0 and=1 and reported both working.

At 2026-09-10 16:54:06.443 +08:00 the agent independently read the IPC HMI:
actual Program number=1, editable target=1, Ready green, Alarm inactive,
force=12.91N, Manual selected, End measure disabled. Only the existing
PartCounter service warning remained visible. The agent did not repeat either
command, acknowledge alarms, start measurement, actuate cylinders, change
instrument configuration, edit/download PLC code or push Git during this turn.

This is meaningful before/after evidence that the MP000 Active setting affects
the observed program-selection failure in this installed combination. Preserve
the successful checkbox-only setting; do not require configuring/copying MP000.
Keep TypeData.KistlerProgramNo=1 and use MP001 for actual production measurement.
The two successful selection tests are user-reported; the current actual1/Ready
state is agent-observed. The precise internal AUTO/MP sequence has still not
been captured, and this is not a universal claim that every maXYmos installation
requires both programs active. The handbook's display/hide wording must not be
used to dismiss this observed functional effect.

No extra PLC edit, CpStudio Export, compile or download is needed solely for this
instrument checkbox change. Manual MP001 Start/End and complete automatic
left/middle/right plus a second cycle are still pending; do not mark the entire
automatic sequence accepted based only on program selection. Earlier entries
describing MP000 as unchecked or requiring repeated physical MP001 recovery are
historical and superseded by this result.

## 16:39 ready MP1 reproduction: standard SET_PROGRAM=1 changes actual to MP0

The user reported completion of physical PROCESS-page MP001 selection. The
agent refreshed the accessible IPC HMI and verified actual Program number=1,
Ready green, Alarm inactive, and updating force. Home-position view showed the
station in home position; Manual was subsequently selected by the user. Before
the command, PLE showed idle sendData.Auto=false and MeasProgNo=0. These are
baseline data, not a captured handshake waveform.

After normal bottom-right HMI operation release, the agent clicked exactly one
Set program button with visible target1 at 2026-09-10 16:39:05.493 +08:00. No
Start measure, End measure, Tare, ZeroX, cylinder or automatic-cycle command ran.
At 16:39:19.785 the existing PLE reported retained peripheral error Number=-5,
AddText='SetProg', NativeErrCode=0, and post-failure sendAuto=false/MeasProgNo=0.
The subsequent HMI observation showed actual0, Ready=false, Alarm=true. This
establishes a before/after 1-to-0 change following the standard manual command,
unlike the 16:16 test which started at actual0 and returned -1.

Further PLE Watch readback showed Unit.ParCmd.SetProgram.ProgNo=1,
Unit.ParCmd.Measure.ProgNo=1 and Unit.OutImm.ProgNo=0. The exposed application
Wp100A104KistlerExtension inherits the standard Extension and has only
OnManRelease; no custom application manual parameter-copy implementation was
found. Supplier HMI target binds Extension.ParCmd.SetProgram.ProgNo; the command
maps to standard command4. A post-command Unit readback is not a cycle trace,
but it does not support a persistent application request of zero.

The fault is reproducible through standard manual program selection without
running the SFC, Burster or cylinders. Exact closed-source handshake behavior
is still not established; AUTO-before-MP adoption of old zero remains a
hypothesis, not a proven waveform. No new speculative PLC patch, build,
download or Git push was made.

Next bounded test: user restores physical PROCESS MP001 again, then verify a
manual MEASURE/End pair without cylinder motion. Existing automatic helper
skips redundant SET_PROGRAM when actual MP already matches and is ready. It
is not yet established whether the separate MEASURE path also causes this
failure. Do not declare full automatic acceptance, force private PDOs, enable
MP0 or suppress readiness to pass the test. This test still needs physical
recovery; the user's download/test authorization remains valid.

### User-requested local screen-saver timeout

Read-only diagnosis found the current user's secure screen saver enabled with
900-second timeout. AC display-off and AC/DC sleep were Never. Standard screen-
saver policy values, InactivityTimeoutSecs and queried MDM lock keys were not
set; computer RSoP access was denied, so absence of all organizational control
cannot be claimed. Using the Windows SystemParametersInfo configuration API,
only the user timeout was changed to1800 seconds. API and saved-profile reads
both returned1800; enabled and password-on-resume states stayed1. No policy,
security-disable, keep-awake, PLC or IPC setting was modified. Do not fight a
future company policy refresh. One-off configuration script is under ignored
data/tmp/set-user-screensaver-timeout-20260910.ps1, not product code.
API reference: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow


## Latest: download/test authorized; no supported new patch; UI activation blocked

The user explicitly authorized this repair round to be downloaded and tested,
and identified the bottom-right HMI padlock as normal manual operation release.
This supersedes the older one-command-only authorization described below. Refresh
actual safe/manual state before deployment; start with program selection only,
not measurement, tare, cylinder motion or a full automatic cycle.

Read-only supplier audit found no public BL/TL compatibility parameter in the
Peripheral OOD/OSD. The listed BL/TL device IDs are supported hardware entries,
not mode parameters. AUTO byte1.bit4 and MP byte2.bit0..3 in the manufacturer BL
manual match the photographed C control-bit page. Thus neither a bit-layout
rewrite nor a guessed compatibility-flag patch is supported by this audit.
The supplier help documents a tested BL5867B FW2.3 and BL2.3/TL1.7 support; that
does not establish validation of the present 5867C or prove incompatibility.

The official REST read still identifies the exact Station010 PLC project and
ctrlX PLC 2.6.8. Existing generated Kistler Unit setup contains the channel binding
and DisplayStrokeForce, not a discovered model compatibility setting.

The RDP window was returned by native window discovery, but activation failed
with `failed to activate captured window`. A fresh window discovery and one retry
failed identically. No stale-coordinate input followed; the user was asked to
restore the existing PLE/RDP windows and keep the desktop unlocked. This round
made no PLC edits, Logout, compile, download, device command, force or Git push.

Next useful recovery verification requires the local instrument: after safely
exiting automatic operation, select the existing MP001 using the blue PROCESS
page MP selector, not merely open its Setup configuration. The manufacturer C
manual section 3.3 requires the appropriate user level and I-AUTO=0. It does not
explicitly guarantee selection during the current alarm. Then observe actual
ProgNo, Ready and Alarm in PLC/HMI before deciding a further implementation.
No instruction to enable/copy MP0, acknowledge all alarms, override Ready or
write private PDOs is justified. No documented C power-up MP persistence rule
was established. Current evidence remains the previous -1/SetProg and actual0,
not a completed 1-to-0 transition trace.

Manufacturer sources:
- BL control/selection sequence: https://kistler.cdn.celum.cloud/SAPCommerce_Download_original/002-626e.pdf
- C manual section 3.3: https://manualzz.com/doc/86121336/kistler-5867c-process-monitoring-system-maxymos-bl-owner-...


## Clarification after the user's MP0/MP1 Active question

Manufacturer-authored 5867C_012-118e-05.25 section 4.13.3, page 76 explicitly
describes MP Manager Active as display/hide MPs. An unchecked MP0 box alone
therefore does not establish that MP0 is blank, unconfigured or invalid. Earlier
phrasing that inferred those properties solely from the checkbox must not be
reused. The instrument's photographed Inactive MP selected message remains an
observed alarm, but its firmware-specific relationship to this setting requires
verification. There is no established requirement here to check both MP0 and MP1.

Source: https://manualzz.com/doc/86121336/kistler-5867c-process-monitoring-system-maxymos-bl-owner-...
Do not change either program's contents or Active settings based on this question.
Keep the proven single-command result (-1/SetProg, target1/actual0) separate from
speculation about program validity. TypeData remains 1; no additional test ran.

## 16:16:45 single manual SET_PROGRAM=1: fresh -1 / SetProg

User clarified that the bottom-right padlock is the HMI operation-release button,
not an authentication requirement. On the refreshed page the release was already
active (30-second indication), Manual selected, target=1, actual=0 and Alarm=true.
The agent did not toggle release unnecessarily or operate login. Exactly one
Set program click was issued at 2026-09-10 16:16:45.899 +08:00; the immediate HMI
read still showed actual 0. No Start measure, Tare, cylinder or mode command ran.

The existing PLE Watch at 16:16:59 showed a new retained error:
Peripheral._lastError.Number=-1, AddText='SetProg', NativeErrCode=0. This differs
from the earlier -5/AUTO timeout. SendData at that post-command observation:
Auto=false, MeasProgNo=0, Start=false. The observation was about 13 seconds after
the click; it is not a cycle-accurate record and does not prove no earlier AUTO
pulse was sent. A session guard prevents accidental repetition of the one click.

Further read-only bus diagnostics: SUPER._status.State.DeviceState=8,
LinkState=0, PdStatus=0, LastPdStatusError=0; force feedback continued updating.
The supplier event definition for error 1 is device/bus not ready. Public help
does not identify the exact internal SetProg predicate, so do not assert that
Alarm alone or Ready alone is proven to be the rejecting condition.

The user subsequently asked whether MP0 and MP1 should both be active. Earlier
photos showed MP0 inactive and MP1 active. Do not treat both-active as an established
requirement or enable an unconfigured MP0 merely to hide this fault. No instrument
MP configuration was changed. No PLC edit, compile, download, force or Git push.

## Authorized single-command test: pending normal HMI release

The user approved the specifically requested safe manual Set program=1 test,
with no measurement, cylinder actuation or automatic cycle. Current RDP shows
Manual selected, target 1, actual 0 and the device Alarm indicator active, but
Set program is disabled with a padlock. No command was clicked or dispatched;
no HMI release/security condition was bypassed. The user must complete normal
login/operator release before the one approved test can proceed.

Watch3 is prepared to display Peripheral._lastError together with
_sendData.Auto/MeasProgNo/Start. Idle baseline: error Number=0, AddText empty,
Auto=false, MeasProgNo=0, Start=false. This is not a command-sequence capture.
No PLC change, build, download or Git push was performed.

## 16:07 follow-up: actual MP remains zero; manual success is not established

User supplied `codex-clipboard-d7e15556-018c-4f32-9f6b-b66e17a6374a.png`:
HMI actual Program number is 0 while the editable Set program target is 1;
two Device not ready events are displayed. The prior inference that an alarm
disappearing after a manual HMI click proved successful remote program selection
is withdrawn. Only actual readback can establish that selection succeeded.

Fresh read-only observations in the existing Station010 PLE online session:

- The current CheckKistlerProgram implementation includes the latest candidate.
  PLE shows Program unchanged. No extra PLE/MCP session was opened.
- Unit.ParCmd.SetProgram.ProgNo=1 and Measure.ProgNo=1; the earlier parameter
  mismatch is no longer present. Measure.MeasuringTimeout=T#0ms at this snapshot.
- Unit.OutImm: ProgNo=0, Ready=false, Alarm=true, ScreenLocked=false,
  MeasRunning=false. PlcLockActive=false. The device is still not usable.
- At the later read, Peripheral._lastError.Number=0, AddText empty,
  NativeErrCode=0 and _initiallyConfigured=false. These idle values do not
  identify the command failure that produced the user's earlier screenshot;
  do not carry forward -5/SetProg as the fresh first error.
- RDP subsequently shows Manual selected, Fieldbus OK and Home position No;
  only the PartCounter warning is visible on that page. This is not a physical
  safety confirmation and does not prove the Kistler device alarm cleared.
- Supplier HMI template binds the editable target to Extension.ParCmd.SetProgram
  and the displayed actual program to Extension.OutImm.ProgNo. The SetProgram
  manual function maps to standard command 4. Current OnManRelease uses the
  common manual-release condition; no incorrect custom command mapping found.

This turn made no PLC/source change, build, download, live write, force, device
command or Git push. Next evidence required is one specifically authorized,
safe manual SET_PROGRAM=1 test with the requested MP, AUTO and returned MP/status
observed together. No automatic cycle is needed. Do not infer success from
alarm disappearance or the editable target, enable blank MP0, or mask readiness.

## 15:47 follow-up: reduce redundant selection; root-cause confirmation pending

User again reports actual MP000 inactive; the two instrument photos show the
same inactive-MP condition. Fresh read-only PLE observations before Logout:
`ProgNo=0`, `Ready=false`, `Alarm=true`, `ScreenLocked=false`, `MeasRunning=false`;
Peripheral `_lastError.Number=-5`, `AddText='SetProg'`. Unit
`ParCmd.SetProgram.ProgNo=1`, `ParCmd.Measure.ProgNo=0`,
`ParCfg.PlcLockActive=false`. Thus the default `DeviceUnlock=true` is not evidence
of a cyclic unlock conflict. Peripheral send controls were all zero after the
failure/cancellation; these snapshots do not prove the failing telegram order.

Version clarification: REST Library Manager resolves NexeedEcKistlerMaxymosBl
2.0.1.0, AtmoKistlerForceStroke 1.2.2.0 and its Base 1.2.1.0. The supplier OOD
package is 2.0.7.0, but that package's own Library/Library.osd explicitly requests
2.0.1.0. Object-package and PLC-library versions are different numbering schemes;
this is not proof of a stale/mismatched library. No library was replaced.

One application-method refinement was applied offline:

- Stage both SetProgram.ProgNo and Measure.ProgNo from the same captured active
  TypeData before any automatic command; retain N051's assignment before MEASURE.
- Do not issue SET_PROGRAM for an already matching, ready, alarm-free MP while
  the Unit is READY, Execute=false and no measurement is running. Recheck the
  unchanged completion guards on the next scan.
- A different or unhealthy MP still uses the standard command and its result,
  with no automatic retry, alarm acknowledgement, raw PDO writes or feedback
  overrides. All cylinder, relay, force and measurement-running guards remain.

Official REST: one implementation PUT, Save job `cf75a99e398dc5f1` succeeded;
exact method readback passed and parent declaration/SFC remained unchanged.
Recovery copy and before/after records:
`data/reports/plc/kistler-program-guard-20260910-154618/`.
Program source/lifecycle, force-interlock and SFC-completion checks passed.
Fresh F11 in the same offline PLE completed: **0 errors / 5 warnings**. All five
visible warnings match the previous kinds: four C0351 unknown OPC.UA.DA attributes
and one C0373 SymbolConfig ErrorCodes/DWord at line 2378. No download or live write;
Logout only. Burster program/range source checks also passed.

This change prevents unnecessary selection and aligns command parameters; it is
NOT proof that the inactive-MP recovery failure is fixed. Need the instrument's
Fieldbus / Control bits configuration and, if necessary, supervised observation
of the actual AUTO / requested-MP / acknowledged-MP sequence. Do not enable empty
MP0 or advise switching MP while the machine is waiting in automatic mode.

User subsequently supplied `IMG_20260910_154614.jpg`, a composite SERVICE /
Fieldbus info / Input control bits photo. It confirms AUTO at byte 1 bit 4 and
MP selection at byte 2 bits 0..3 with weights 1, 2, 4, 8. All shown inputs are off.
The label `MP-0 [1]` means the least-significant program-selection bit, not MP000.
These idle observations match the post-error zero send controls but do not prove
whether program bits were staged before AUTO during the failed command. The
remaining commissioning check is supervised manual SET_PROGRAM to MP1, with
automatic safely cancelled, observing requested and acknowledged bits. The
candidate is not a completed device-level fix; no additional PLC edits should be
guessed from an idle photo.

## Evidence and cause

- User photo `C:/Users/AGZ1WX/Desktop/kistler settings/IMG20260910143045.jpg`: Setup Error, Inactive MP selected.
- MP Manager photo `IMG20260910143803.jpg`: MP000 inactive, MP001 active. TypeData.KistlerProgramNo=1 is retained.
- Earlier read-only PLE observation in this fault: N045, Kistler Unit READY but device Ready=false, ProgNo=0, Alarm=true, MeasRunning=false. Safety-door/work-position and relay gates satisfied, pressing cylinder still at base; Burster selector not started.
- Old N045 required device Ready before N051 could assign the TypeData program. That ordering can indefinitely wait on the inactive current MP. The original source of the instrument's selection of MP0 is not proven.

## Minimal change

1. AI-owned `CheckKistlerProgram` stores request/DONE/program state in method VAR_INST. It issues the standard SET_PROGRAM with ParCmd.SetProgram.ProgNo from active TypeData. Issuing requires Unit READY, Execute=false and no running measurement, but does not require the old MP's measuring-ready bit.
2. The existing standard CheckUnitDone is called with RepeatOnError=false. DONE is latched: calling CheckUnitDone repeatedly after READY could otherwise reissue the command.
3. Completion additionally requires Unit READY, Execute=false, matching actual and active TypeData program, Ready=true, Alarm=false and MeasRunning=false. Both N045 branch returns remain RUNNING until the subsequent Burster selection also completes.
4. N050/N051 require matching program and no device alarm in addition to their existing conditions. Kistler MeasRunning remains mandatory before press-down; force qualification and measurement monitoring are unchanged.
5. N000 and OnChainFinish reset method state. Existing cancellation owns the falling Unit.Execute edge; the new method never clears device alarms or forces feedback.

No SFC step/transition, CpStudio-generated declaration, TypeData value, instrument MP configuration, I/O mapping, Burster driver or safety/force threshold was changed.

## Applied and verified

- Correct current project: `C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/Station010/Plc/Stat010_V5.11_CtrlX_PLC.project`, profile ctrlX PLC 2.6.8.
- Application.isOnline=false before and during official PLE REST writes. No additional PLE/MCP owner was started.
- One saved project copy before edits: `McpCoding/data/reports/plc/kistler-program-20260910-145115/Stat010-before-kistler-program.project`.
- 1 method POST and 5 implementation PUTs: CheckKistlerProgram, N000, N045, N050, N051, OnChainFinish. Existing target text matched its reviewed source baseline. Save job `46dae1008e656052` returned `Project successfully saved.`
- All six source targets read back equal after Save. Parent declaration and SFC implementation remained exactly equal to their pre-edit text.
- Fresh F11 in that same offline PLE: **Build complete — 0 errors, 5 warnings; Ready for download**. Warning details: four C0351 unknown OPC.UA.DA attributes and one C0373 SymbolConfig enumeration ErrorCodes with unsupported base type DWord (line 2378). These are the same warning kinds as the prior build; no new warning kind was observed.
- Passed: Test-Wp100KistlerProgram (source contracts and independent lifecycle model), Test-Wp100ForceInterlock, Test-Wp100BursterProgramRange, Test-SfcCompletionContracts; general Run writer PowerShell parsing and scoped git diff whitespace check.
- Ownership/hooks/specification/general Run writer now recognize the new method, so subsequent export reconciliation can preserve/recreate it.
- No download, PLC start/stop, runtime write/force, instrument command or Git commit/push was performed.

## Field acceptance still required

The offline build does not prove that this instrument/firmware accepts SET_PROGRAM while the inactive-MP alarm is latched. The standard command must report any rejection; its error must not be masked. A separate post-DONE Ready wait remains blocked if the alarm persists. No automatic alarm acknowledgement is added.

User must safely end the old automatic cycle before downloading and starting a fresh test. Do not manually switch MP or acknowledge the instrument while automatic execution is waiting: restored readiness could allow motion.

Observe MP1 selection/acknowledgement, device Ready and no Alarm, then measurement running before press-down; verify force qualification, resistance result, release and left/middle/right progression, including another full cycle. If selection is rejected, record the standard command event and handle the instrument only after safe cycle cancellation. Do not enable empty MP0 merely to remove the alarm. No extra CpStudio Export is needed for this AI-owned implementation-only repair.
