# Tests

- `static/`: repository structure, ownership and safety-policy checks.
- `cpstudio/`: isolated post-export queue and offline-audit self-tests.
- `compile/`: offline PLC compile expectations and warning baselines.
- `simulation/`: bounded PLC simulation scenarios; no physical device access.
- `hmi/`: independent HMI node-contract, read-only-surface and Release-build checks.
- `ioe/`: CpStudio ePLAN ASC byte contract and Station010 EtherCAT naming-chain checks.

Run the framework smoke test from the repository root:

```powershell
.\tests\static\Test-ProjectFramework.ps1
.\tests\static\Test-SfcRestWriterPlanOnly.ps1
.\tests\static\Test-SfcRestWriterTransaction.ps1
.\tests\static\Test-RunOperatorGuidance.ps1
.\tests\cpstudio\Test-PostExportQueue.ps1
.\tests\hmi\Test-HmiReadOnlyScaffold.ps1
pwsh -NoProfile -File .\tests\ioe\Test-CpStudioEplanIoAutomation.ps1
pwsh -NoProfile -File .\tests\ioe\Test-CpStudioEplanIoAscIntake.ps1
```
