# Controlled Runner

`Invoke-CtrlXOpconRunner.ps1` is the single local entry for Phase 1.

## P1.1 control plane

- `Status`: validate project paths, profile, quality gates and ownership manifests;
- `ProcessOne`: consume at most one pending CpStudio Post-export request, run Stage 1 audit and create/resume the immutable Stage 2 action.

```powershell
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Status
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command ProcessOne
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command ProcessOne -WhatIf
```

Every P1.1 invocation takes an OS-enforced exclusive file lease under
`data/runner/` and writes `data/runs/runner/<run-id>/run-manifest.json`.
Concurrent invocations return exit code `20`.

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

Production engineering success remains disabled until the repository's
controlled MCP ownership/fresh-Build patch is separately reviewed, applied to
the installed adapter and accepted, and the independent semantic acceptance
producers are implemented. Missing proof returns
`BLOCKED_CAPABILITY_NOT_IMPLEMENTED`; it cannot become a successful Stage 2
result merely because compilation was clean.

## Safety boundary

Neither P1.1 nor P1.2a contains connect, download, start/stop, runtime write or
FORCE capability. The client has no command that launches PLE/MCP/Broker and no
generic tool-execution surface.
