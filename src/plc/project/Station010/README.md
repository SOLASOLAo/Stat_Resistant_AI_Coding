# Station010-specific PLC source

Place only fully AI-owned, Station010-specific PLC objects here. Generated or
mixed Station/Wp100 methods remain in the integration project and are protected
through `ai/hooks.yaml` plus the process specifications.

Current whole-object sources:

- `Wp100RunResultStruct.st`, `Wp100ResistanceResultStruct.st` and
  `Wp100KistlerResultStruct.st`: structured result returned by one reusable run
  SubChain execution.
- `Wp100RunSequenceResultStruct.st`: retained LEFT/MIDDLE/RIGHT results returned
  by the Run command chain.
- `SqS_Wp100_Run/declaration.st`: declaration outside the CpStudio merge area.
- `SqS_Wp100_Run/actions/*.st`: all SFC Action implementations.
- `SqS_Wp100_Run/OnChainFinish.st`: DONE/ERROR/CANCEL cleanup.
- `SqC_Wp100_Run/`: the command-chain declaration, 11 SFC Actions, reusable
  product-detection method and chain cleanup.

Apply these sources only with `scripts/plc/apply_wp100_run_rest.ps1` and
`scripts/plc/apply_wp100_run_sequence_rest.ps1`. The scripts use the PLC
Engineering official REST extension, hash-guard the CpStudio skeletons, perform
readback verification and save through `ProjectJob`. Never copy these files over
the encrypted `.project` container.

Mixed Station/Wp100 hooks for the other application behavior remain protected
through `ai/hooks.yaml`; their complete generated objects are intentionally not
mirrored here.
