# Scripts Matrix — Run-CompleteWorkflow.ps1, Run-FullWorkflowTest.ps1, Run-ForegroundWorkflowTest.ps1

This document summarizes the 5 W's (What, When, Who, Why, Where), plus How, prerequisites, switches, and reasons to use them for the three main scripts.

---

## `Run-CompleteWorkflow.ps1`

- **What**: Orchestrates the full assessment workflow: captures baseline, assigns audit policies (optional), runs compliance scans, performs remediation (optional), and generates JSON/HTML/CSV artifacts.
- **When**: Run when you want to execute the workflow against an existing environment or as the core step invoked by test harnesses.
- **Who**: Operators, automation pipelines, or other test scripts (`Run-FullWorkflowTest.ps1`, `Run-ForegroundWorkflowTest.ps1`).
- **Why**: Produce canonical baseline, policy assignment, compliance, remediation, and comprehensive reports for Key Vault security assessment.
- **Where**: Produces artifacts under the `artifacts` folder (`artifacts/json`, `artifacts/html`, `artifacts/csv`).

### How (example)
```powershell
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName rg-policy-keyvault-test -WorkflowRunId 20260107-130310 -DevTestMode -SkipComplianceWait
```

### Prerequisites
- `Connect-AzAccount` authenticated to the target subscription.
- `Az` PowerShell modules installed and available.
- Correct `-SubscriptionId` or active context.
- Sufficient RBAC permissions to read Key Vaults and assign policies (if used).

### Important switches / parameters
- `-ResourceGroupName <name>`: scope the run to a resource group. Use when you want to limit scanning to test RG.
- `-SubscriptionId <id>`: explicitly set subscription context if not set in Az context.
- `-WorkflowRunId <id>`: set artifact timestamp prefix; useful to correlate artifacts.
- `-SkipPolicyDeployment` (switch): skip assigning Azure Policy assignments. Use in environments where you cannot modify subscription-level policies.
- `-AutoRemediate` (switch): perform non-breaking auto-remediation where safe; use for production-safe automated fixes.
- `-DevTestMode` (switch): FULL AUTO-REMEDIATION (breaking) — intended for test environments only; will enable RBAC, add firewall rules, create Log Analytics, and set expirations. Use only in disposable test environments.
- `-DevTestMode` reason: quick, fully-automated remediation for testing scenarios.
- `-SkipComplianceWait` (switch): do not wait for Azure Policy compliance data to settle — use for faster test runs when you don't need final policy evaluation.

---

## `Run-FullWorkflowTest.ps1`

- **What**: Automated end-to-end test harness: (optionally resets) creates test environment (resource group + Key Vaults), runs `Run-CompleteWorkflow.ps1`, then resets/cleans up and verifies cleanup.
- **When**: Use in CI or automated validation runs where you need create→test→teardown with minimal interaction.
- **Who**: CI systems, automated test operators.
- **Why**: Validate the entire workflow and remediations in a reproducible, automated fashion.
- **Where**: Creates resources in target subscription (default RG `rg-policy-keyvault-test` in samples) and writes artifacts to `artifacts/*`.

### How (example)
```powershell
.\scripts\Run-FullWorkflowTest.ps1 -SkipReset
```

### Prerequisites
- `Connect-AzAccount` with appropriate subscription.
- Permissions to create/delete resource groups, Key Vaults, role assignments, and policy assignments.
- `Az` modules installed.

### Important switches / parameters
- `-SkipReset` (switch): if set, reuses an existing environment instead of resetting first. Use when you want to speed up repeated runs or preserve manual changes during debugging.

Notes:
- Non-interactive and intended for automated use; the script executes `Run-CompleteWorkflow.ps1` internally and then runs the reset script.

---

## `Run-ForegroundWorkflowTest.ps1`

- **What**: Interactive, verbose foreground tester and demo runner. Prompts user to create vs reuse environment, steps through creation, seeding, runs `Run-CompleteWorkflow.ps1` (usually with `-DevTestMode` in demo), validates policy compliance, and offers cleanup choices.
- **When**: Use during manual testing, demonstrations, or interactive debugging where you want to inspect results and choose cleanup.
- **Who**: Engineers and demo operators who run the workflow by hand.
- **Why**: Step-through process with pauses, interactive confirmations, and options to inspect artifacts before cleanup.
- **Where**: Affects target subscription and writes artifacts to `artifacts/*`.

### How (example)
```powershell
.\scripts\Run-ForegroundWorkflowTest.ps1
# Follow prompts: choose Create (C) or Reuse (R)
```

### Prerequisites
- `Connect-AzAccount` with user interactive session.
- Az PowerShell modules.
- Permissions similar to `Run-FullWorkflowTest.ps1` if creating resources.

### Important behavior / switches
- Interactive choice prompts (Create new vs Reuse existing environment).
- Calls `Run-CompleteWorkflow.ps1` with `-WorkflowRunId` and `-DevTestMode` in typical interactive/demo flows.
- Use this when you want to step through and approve or inspect stages; do not use `-DevTestMode` in production.

---

## Switches comparison (quick)
- `-DevTestMode`: Use only in test/demo runs (foreground or full test when intended). It makes breaking changes to resources.
- `-AutoRemediate`: Safer for production non-interactive remediation.
- `-SkipPolicyDeployment`: Avoid deploying subscription-level policies.
- `-SkipComplianceWait`: Speed up runs by not waiting for Azure Policy evaluation to converge.
- `-SkipReset` (FullWorkflowTest): Reuse existing environment.

---