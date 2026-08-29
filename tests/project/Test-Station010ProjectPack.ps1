[CmdletBinding()]
param(
    [string]$EngineeringRoot
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required for the Station010 Project Pack test.'
}

if ([string]::IsNullOrWhiteSpace($EngineeringRoot)) {
    $EngineeringRoot = Join-Path $PSScriptRoot '..\..'
}
$root = [System.IO.Path]::GetFullPath($EngineeringRoot).TrimEnd('\', '/')

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $path = Join-Path $root ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    Assert-True -Condition ([System.IO.File]::Exists($path)) -Message "Required file is missing: $RelativePath"
    return ([System.IO.File]::ReadAllText($path) | ConvertFrom-Json -Depth 64)
}

function Assert-ExactSequence {
    param(
        [Parameter(Mandatory = $true)][object[]]$Actual,
        [Parameter(Mandatory = $true)][object[]]$Expected,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $difference = @(Compare-Object -ReferenceObject $Expected -DifferenceObject $Actual -SyncWindow 0)
    Assert-True -Condition ($difference.Count -eq 0) -Message "$Description differs from the reviewed sequence."
}

$builderRelativePath = 'scripts/project/Build-CtrlXOpconProjectPack.ps1'
$builderPath = Join-Path $root ($builderRelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
Assert-True -Condition ([System.IO.File]::Exists($builderPath)) -Message "Project Pack builder is missing: $builderRelativePath"

$pack = Read-JsonFile -RelativePath 'project-pack.json'
Assert-True -Condition ($pack.kind -ceq 'ctrlx-opcon-project-pack') -Message 'Unexpected Project Pack kind.'
Assert-True -Condition ($pack.status -ceq 'ready') -Message 'Station010 Project Pack must remain ready.'

$expectedProcesses = @(
    'specs/processes/SqC_Wp100_Run.process.json',
    'specs/processes/SqS_Wp100_Run.process.json'
)
Assert-ExactSequence -Actual @($pack.sources.processes) -Expected $expectedProcesses -Description 'Project Pack process sources'
Assert-True -Condition (@($pack.sources.processes | Where-Object { $_ -like 'specs/chains/*' }).Count -eq 0) `
    -Message 'Project Pack must consume compact process JSON rather than duplicating the detailed Chain YAML.'
Assert-ExactSequence -Actual @($pack.sources.hmi) -Expected @(
    'specs/hmi/auto_info_line.yaml',
    'src/hmi/Bpp.ResistantStation.Hmi/Configuration/station010.hmi.json'
) -Description 'Project Pack HMI sources'

$commandProcess = Read-JsonFile -RelativePath $expectedProcesses[0]
$atomicProcess = Read-JsonFile -RelativePath $expectedProcesses[1]

Assert-True -Condition ($commandProcess.chain.plcPath -ceq 'Application/Station/Wp100/_this/Chains/Cmd/SqC_Wp100_Run') `
    -Message 'SqC_Wp100_Run PLC path drifted.'
Assert-True -Condition ($atomicProcess.chain.plcPath -ceq 'Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run') `
    -Message 'SqS_Wp100_Run PLC path drifted.'
Assert-True -Condition (@($atomicProcess.chain.inputs | Where-Object { $_.name -ceq 'MeasurePos' -and $_.source -ceq 'cpstudio' }).Count -eq 1) `
    -Message 'MeasurePos must remain a CpStudio-owned SqS input.'
foreach ($process in @($commandProcess, $atomicProcess)) {
    Assert-True -Condition (@(@($process.chain.inputs) + @($process.chain.outputs) | Where-Object { $_.source -cne 'cpstudio' }).Count -eq 0) `
        -Message "All generated POU interfaces in '$($process.processId)' must remain CpStudio-owned."
}

$expectedCommandSteps = @('N000', 'N010', 'N015', 'N020', 'N030', 'N040', 'N045', 'N050', 'N060', 'N070', 'N075', 'N080', 'N090', 'N999')
$expectedAtomicSteps = @('N000', 'N010', 'N020', 'N030', 'N040', 'N045', 'N050', 'N051', 'N060', 'N061', 'N070', 'N080', 'N090', 'N095', 'N100', 'N101', 'N110', 'N120', 'N130', 'N140', 'N999')
Assert-ExactSequence -Actual @($commandProcess.steps.id) -Expected $expectedCommandSteps -Description 'SqC_Wp100_Run steps'
Assert-ExactSequence -Actual @($atomicProcess.steps.id) -Expected $expectedAtomicSteps -Description 'SqS_Wp100_Run steps'

foreach ($process in @($commandProcess, $atomicProcess)) {
    $requirementIds = @($process.requirements.id)
    Assert-True -Condition ($requirementIds.Count -eq @($requirementIds | Sort-Object -Unique).Count) `
        -Message "Process '$($process.processId)' contains duplicate requirement IDs."

    foreach ($step in @($process.steps)) {
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$step.id)) `
            -Message "Process '$($process.processId)' contains a step without an ID."
        Assert-True -Condition (([string]$step.comment).Length -le 80) `
            -Message "Process '$($process.processId)' step '$($step.id)' comment exceeds 80 characters."
        Assert-True -Condition (@($step.requirements).Count -gt 0) `
            -Message "Process '$($process.processId)' step '$($step.id)' has no requirement trace."
        Assert-True -Condition (@($step.acceptance).Count -gt 0) `
            -Message "Process '$($process.processId)' step '$($step.id)' has no acceptance statement."
        foreach ($requirementId in @($step.requirements)) {
            Assert-True -Condition ($requirementIds -ccontains $requirementId) `
                -Message "Process '$($process.processId)' step '$($step.id)' references unknown requirement '$requirementId'."
        }
        if ($null -ne $step.prompt) {
            Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$step.prompt.english)) `
                -Message "Process '$($process.processId)' step '$($step.id)' has no English prompt."
            Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$step.prompt.chinese)) `
                -Message "Process '$($process.processId)' step '$($step.id)' has no Chinese prompt."
        }
        if ($null -ne $step.promptVariants) {
            foreach ($variant in @($step.promptVariants)) {
                Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$variant.when)) `
                    -Message "Process '$($process.processId)' step '$($step.id)' has a prompt variant without a selector."
                Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$variant.english)) `
                    -Message "Process '$($process.processId)' step '$($step.id)' has no English prompt variant."
                Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$variant.chinese)) `
                    -Message "Process '$($process.processId)' step '$($step.id)' has no Chinese prompt variant."
            }
        }
    }

    foreach ($requirementId in $requirementIds) {
        Assert-True -Condition (@($process.steps | Where-Object { @($_.requirements) -ccontains $requirementId }).Count -gt 0) `
            -Message "Requirement '$requirementId' has no step trace."
        Assert-True -Condition (@($process.acceptanceTests | Where-Object { @($_.requirements) -ccontains $requirementId }).Count -gt 0) `
            -Message "Requirement '$requirementId' has no acceptance-test trace."
    }
}

$parallelSteps = @($atomicProcess.steps | Where-Object { $null -ne $_.parallel })
Assert-True -Condition ($parallelSteps.Count -eq 8) -Message 'SqS must retain eight explicit parallel branch steps.'
Assert-True -Condition (@($parallelSteps | Where-Object { $null -ne $_.prompt }).Count -eq 0) `
    -Message 'Parallel branch steps must not compete for the operator prompt.'
foreach ($group in @('measurement_start', 'measurement_finish')) {
    foreach ($branch in @(1, 2)) {
        Assert-True -Condition (@($parallelSteps | Where-Object { $_.parallel.group -ceq $group -and $_.parallel.branch -eq $branch }).Count -eq 2) `
            -Message "Parallel group '$group' branch $branch must contain one start/capture-or-wait pair."
    }
}

$expectedVariantKeys = @(
    'USER_INFO_MOVE_FIXTURE_LEFT', 'USER_INFO_MOVE_FIXTURE_MIDDLE', 'USER_INFO_MOVE_FIXTURE_RIGHT',
    'USER_INFO_PRESS_START_LEFT', 'USER_INFO_PRESS_START_MIDDLE', 'USER_INFO_PRESS_START_RIGHT',
    'USER_INFO_MEASURING_LEFT', 'USER_INFO_MEASURING_MIDDLE', 'USER_INFO_MEASURING_RIGHT'
)
$actualVariantKeys = @($atomicProcess.steps.promptVariants.key | Where-Object { $null -ne $_ })
Assert-ExactSequence -Actual $actualVariantKeys -Expected $expectedVariantKeys -Description 'SqS MeasurePos prompt variants'
$autoInfoText = [System.IO.File]::ReadAllText((Join-Path $root 'specs\hmi\auto_info_line.yaml'))
foreach ($key in $expectedVariantKeys) {
    Assert-True -Condition ($autoInfoText -cmatch ('(?m)^\s+name:\s+' + [regex]::Escape($key) + '\s*$')) `
        -Message "Prompt variant '$key' is missing from the CpStudio AutoInfoLineEnum contract."
}

$builderOutput = (& $builderPath -Command Check -EngineeringRoot $root -RequireReady -Json | Out-String).Trim()
$builderResult = $builderOutput | ConvertFrom-Json
Assert-True -Condition ($builderResult.status -ceq 'VALID') -Message 'Project Pack Check did not return VALID.'
Assert-True -Condition ($builderResult.readyForEngineering -eq $true) -Message 'Project Pack is not ready for engineering.'
Assert-True -Condition ($builderResult.processCount -eq 2) -Message 'Generated plan must contain exactly two reviewed Station010 processes.'

$plan = Read-JsonFile -RelativePath 'generated/engineering-plan.json'
Assert-True -Condition ($plan.kind -ceq 'ctrlx-opcon-engineering-plan') -Message 'Unexpected engineering-plan kind.'
Assert-True -Condition ($plan.readyForEngineering -eq $true) -Message 'Generated engineering plan is not ready.'
Assert-True -Condition (@($plan.sfcPlans).Count -eq 2) -Message 'Generated engineering plan must contain two SFC plans.'
Assert-True -Condition (@($plan.testCases).Count -eq 9) -Message 'Generated engineering plan must contain nine acceptance tests.'
Assert-True -Condition (@($plan.traceability).Count -eq 13) -Message 'Generated engineering plan must contain thirteen requirement traces.'
Assert-True -Condition (@($plan.traceability | Where-Object { @($_.stepIds).Count -eq 0 -or @($_.testIds).Count -eq 0 }).Count -eq 0) `
    -Message 'Every generated requirement must trace to both steps and acceptance tests.'

Write-Output 'Station010 Project Pack OK: 2 processes, 35 steps, 13 requirements, 9 acceptance tests.'
