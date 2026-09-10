# Burster E1106: quoted no-error response rejected — 2026-09-10

Status: confirmed false positive repaired in the offline PLE project; saved/read back. Fresh F11: **0 errors / 5 existing warnings**. No download or field acceptance yet.

## Current evidence

- User reports Kistler initially still raised Device not ready, then manually selecting MP001 on the instrument removed that error. This is not successful automatic recovery by the previous offline patch.
- Existing IPC RDP 192.168.0.50: opened alarm details without acknowledging/clearing. Event time 2026-09-10 14:56:36, event 35, additional text `B2316 E=1106 CMD=SYST:ERR?`.
- Existing Station010 PLE, Application.isOnline=true, PLC RUN/program unchanged. No new PLC connection/session was opened. Added only the read-only Watch expression `AiWp100.Burster`; Prepared value was not edited.
- Burster live diagnostics: RequestedProgramNo=0, ErrorCode=1106, LastCommand=`SYST:ERR?`, LastResponse=`0,"NO ERROR"`, MeasurementStarts=0. After cleanup: Connected=false, SelectionVerified=false, SelectedProgram=-1, Operation=0, Phase=0, CleanupBlocked=false. The closed connection after cleanup is not proof of the initiating failure.
- Kistler live: ProgNo=1, Ready=true, Alarm=false, Warning=false, MeasRunning=false. Press base feedback=true; Burster Unit ERROR in the observed N045 gate.

## Root cause

Pre-fix official REST readback of `Application/Fbs/FB_Wp100BursterSingleOwner/SelectProgram` matched local source. In Phase 20, after a successful query exchange, the guard only accepted the exact unquoted strings `0, NO ERROR` and `0,NO ERROR`. The observed response contained double quotes around NO ERROR. Both comparisons therefore failed, invoking Fail(1106), clearing SelectionVerified and blocking measurement.

The driver maps this local protocol/check failure to the exported generic Ethernet event -35, which is why the HMI says Unexpected communication error. The specific E1106 and raw response show that this occurrence is a false positive, not a nonzero instrument error or the old invalid socket-close fault. MeasurementStarts=0 corroborates that INIT had not been issued by this driver instance.

Manufacturer reference: [RESISTOMAT 2316 operating manual](https://www.burster.de/fileadmin/user_upload/redaktion/Documents/Products/Manuals/Section_2/BA_2316_EN.pdf), §8.11.4, printed page 89. The error table maps 0 / NO ERROR to no errors present; actual quoting was observed on this instrument, not inferred from the manual typography.

## Applied bounded fix

The minimal implementation retains the two existing complete-string comparisons and adds only `0,"NO ERROR"` and `0, "NO ERROR"`. This is a finite whitelist, not a general numeric parser or arbitrary whitespace normalization. Only those four complete zero / NO ERROR forms pass. Nonzero codes, unknown text/case/spacing, unbalanced quotes, empty/truncated replies and trailing garbage still fail closed as E1106; failed transfers are unchanged.

The new source-contract test extracts the actual ST equality guard and tests all four allowed forms plus nonzero/malformed examples. The exact live quoted payload is also tested at every TCP fragmentation boundary with both supported Ethernet trailers. All **18 protocol/source tests pass**, as does `Test-Wp100BursterProgramRange.ps1`. These are offline models/source checks, not execution of compiled ST or instrument acceptance.

Program ACK/readback, single TCP owner, force/safety interlocks, motion ordering and generated interfaces are unchanged. Automatic/manual selection shares this single repaired method. No new method, declaration, generic parser or socket change was added.

## Offline application and boundaries

- The earlier inspection-only turn made no PLC mutation. The user then explicitly requested the repair with “改啊”.
- Used Online → Logout in the existing correct Station010 PLE; official REST confirmed `Application.isOnline=false` before every write. PLC Stop was not used.
- Preserved one ordinary project copy after Save, plus the exact target/parent texts. No hashes or full-project writer were run.
- Applied **one implementation PUT** to the existing SelectProgram method, saved and read back through the same PLE REST. Method identity/declaration and parent declaration/implementation are unchanged.
- Recovery/readback evidence: `data/reports/plc/burster-error-response-20260910-151220/`; one-off apply script: `data/tmp/apply-burster-error-response-20260910.ps1`.
- Fresh F11 was explicitly started after that Save and observed through completion: **0 errors / 5 warnings, Ready for download**. All five warning rows were visible: four C0351 (`OPC.UA.DA` unknown attribute) and one C0373 (SymbolConfig ErrorCodes / DWord, line 2378), matching the previous signatures. Evidence note: `build.md` in the same report directory. `after.json` intentionally records the transaction before Build, not the final Build result.
- No download, runtime write, force, start/stop, instrument command, CpStudio change, commit or Git push. This implementation-only repair does not require another CpStudio Export.
- User-controlled field retest remains necessary: safely end the old automatic cycle before deployment, then verify selection, measurement and the left/middle/right sequence. Kistler's initial inactive-MP readiness limitation remains separate and unresolved by this repair.
