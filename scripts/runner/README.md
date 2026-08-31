# Controlled Runner

`Invoke-CtrlXOpconRunner.ps1` is the single local entry for Phase 1.

## P1.1 control plane

- `Run` (recommended): safely advance one offline orchestration step. It consumes at most one pending CpStudio Post-export request, runs Stage 1 and creates/resumes the immutable Stage 2 action; with no request it returns `IDLE` and the next step;
- `Status`: validate project paths, profile, quality gates and ownership manifests;
- `ProcessOne`: compatibility name for the same Stage 1/Stage 2 step used by `Run`.

```powershell
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Status
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Run
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Run -WhatIf
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command ProcessOne
```

Every P1.1 invocation takes an OS-enforced exclusive file lease under
`data/runner/` and writes `data/runs/runner/<run-id>/run-manifest.json`.
Concurrent invocations return exit code `20`.

`Run` resumes only the `operationId` recorded by the most recent earlier
`Run` manifest. It never adopts legacy open ledgers by directory order. A
tracked `WAITING_FOR_RUNNER` action is reported before any new request is
consumed; a tracked `WAITING_FOR_EXPORT_2` operation binds the next audit
through the existing coordinator. With neither a tracked operation nor a
request it returns `IDLE` with `reasonCode=NO_PENDING`.

## P1.2 action client and Broker discovery

The .NET 8 Runner client is installed under `tools/runner/` by the project
initializer. In this Station010 sidecar it can also use
`ctrlx-ai-coding/src/runner/`.

Before first use, build the trusted checked-in source explicitly once. The
action wrapper only executes the resulting Release DLL; it never invokes
MSBuild/`dotnet run` while consuming an action.

```powershell
dotnet build .\ctrlx-ai-coding\src\runner\CtrlX.OpCon.Runner.Cli\CtrlX.OpCon.Runner.Cli.csproj -c Release
```

```powershell
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Doctor

.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 `
  -Command ExecuteAction `
  -ActionPath '<absolute actionRequestPath from Stage 2>' `
  -ExpectedActionSha256 '<actionRequestSha256>'

.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 `
  -Command ActionStatus -ActionRunId '<runId>'

.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 `
  -Command ActionVerify -ActionRunId '<runId>'
```

The client binds the immutable action to `operation.json.currentAction`,
validates hashes/fingerprints and every replay artifact, obtains separate
profile/project and action-run leases, and connects only to an already-running
local Named Pipe Broker. Protocol v2 discovers the Broker only through the
canonical current-user registration derived from `EngineeringRoot`; callers
cannot provide or override its Pipe name or PID. The client checks heartbeat,
live process identity, Windows session and exact project identity. It never
starts PLE, MCP, or the Broker.

The Broker foundation provides durable submit/query, exact replay and typed
`inspect_and_build` / `verify_after_export_2` allowlisting. The current Windows
user is the local trust boundary; code signing/release-bound Broker identity is
still required before commercial distribution.

The controlled ownership/fresh-Build adapter and read-only semantic snapshot
channel have passed the final real offline PLE action. Formal warning/semantic
baselines, the local content-addressed pre-Build checkpoint and a new immutable
action were verified at 0 errors / 4 warnings with 456 mappings and stable
Symbol/project hashes. One explicit user confirmation is sufficient; no name,
employee ID or redundant approval is collected. `apply_change_set_and_build`
remains unsupported and returns `BLOCKED_UNSUPPORTED_ACTION`.

## P1.3 current-user Host lifecycle

Production lifecycle commands use only a validated immutable release installed
under the current user's `LocalAppData`:

```powershell
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Install
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Rollback
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Status
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Start
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Stop
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Logs
```

`Install` is idempotent for the same release and performs an upgrade when the
release changes. It installs a content-addressed immutable five-file release and
registers an AtLogOn Scheduled Task whose action points exactly to the release
executable; the task description records the release and manifest identities.
Explicit lifecycle commands validate all five release files and run the apphost
self-check. The logon task launches the executable directly and does not perform
a prelaunch manifest validation. `Rollback` switches to the previous validated
release. A failed upgrade restores the old task and its prior running/stopped state.

Production `Start` never runs from build output. A raw build-output process is
available only for explicit development testing:

```powershell
dotnet build .\ctrlx-ai-coding\src\runner\CtrlX.OpCon.Runner.Host\CtrlX.OpCon.Runner.Host.csproj -c Release
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Start -DevelopmentProcess
```

The Host runs only in the current user's interactive Windows session. It consumes
eligible immutable actions and verifies result/evidence hashes plus the immutable
action/ledger before invoking the Stage 2 coordinator. Valid `UNKNOWN`/`FAILED`
results without evidence remain `WAITING_FOR_COORDINATOR` for manual review;
busy is retried with bounded backoff and malformed ledgers fail closed. The Host
never starts Broker, MCP, PLE, Node or an online PLC operation.

P1.3c technical implementation and local-machine acceptance are complete. The
production ingestor's default Host assembly passed six fixture E2E cases and a
real ledger-lock busy case. Durable pending journal/reconcile recovery passed for
disabled and deleted source tasks, `STATE_COMMITTED`, and a force-killed wrapper
followed by the narrowly gated default `Start`. New-release upgrade, same-release
no-op, rollback, corrupt-candidate rejection, and safe task-derived `Uninstall`
with missing deployment state also passed. The main Host is active on release
`faa27c...0f1`, with previous release `ac89b...4b51`, and reports
`WAITING_FOR_ACTION`.

P1.4 remains open for team-workstation installation, signing, a controlled
installer package, pre-logon manifest bootstrap, compatibility coverage, and
new-machine acceptance.

## Safety boundary

P1.1, P1.2a and the P1.3 Host contain no connect, download, PLC runtime start/stop,
runtime write or FORCE capability. The client and Host have no generic
tool-execution surface; the Host also has no command that launches
PLE/MCP/Broker/Node.
