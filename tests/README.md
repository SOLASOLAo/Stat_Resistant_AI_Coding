# Tests

- `static/`: repository structure, ownership and safety-policy checks.
- `cpstudio/`: isolated post-export queue and offline-audit self-tests.
- `compile/`: offline PLC compile expectations and warning baselines.
- `simulation/`: bounded PLC simulation scenarios; no physical device access.

Run the framework smoke test from the repository root:

```powershell
.\tests\static\Test-ProjectFramework.ps1
.\tests\cpstudio\Test-PostExportQueue.ps1
```
