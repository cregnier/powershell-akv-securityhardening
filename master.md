**Repository Scripts — Master Reference**

This document summarizes the primary PowerShell scripts in this repository, when to use them, and the key switches/behavior. Use this as the single reference (expanded `scripts-matrix.md`).

**How to read this:**
- **Script**: filename and link to source.
- **Purpose**: what the script does (Who / What).
- **When to run**: quick guidance (When).
- **Primary flags / switches**: important CLI switches (How).
- **Notes**: important caveats or side-effects (Why / Warnings).

---

| Script | Purpose | When to run | Primary flags | Notes |
|---|---|---|---|---|
| [scripts/Run-CompleteWorkflow.ps1](scripts/Run-CompleteWorkflow.ps1) | Core workflow: capture baseline, assign policies, run compliance scans, generate artifacts (JSON/HTML/CSV), and optionally remediate. | Use when you want the full, repeatable workflow against a resource group (non-interactive). | `-ResourceGroupName`, `-WorkflowRunId`, `-DevTestMode` (test remediations), `-AutoRemediate`, `-SkipPolicyDeployment`, `-SkipComplianceWait`, `-InvokedBy` | Produces manifest and per-artifact provenance. Writes artifacts under `artifacts/`. Avoid `DevTestMode` in production. |
| [scripts/Run-FullWorkflowTest.ps1](scripts/Run-FullWorkflowTest.ps1) | CI-style automated run: creates test environment, runs `Run-CompleteWorkflow`, then resets environment. | CI or automated E2E test runs. Use `-SkipReset` to preserve environment for investigation. | `-SkipReset` | Creates and destroys resources; careful with costs and destructive cleanup. |
| [scripts/Run-ForegroundWorkflowTest.ps1](scripts/Run-ForegroundWorkflowTest.ps1) | Interactive foreground runner with prompts to create or reuse environment, run workflow, and optionally cleanup. Includes an inline polling helper to re-run compliance reporting. | Manual demos, local troubleshooting, or step-through verification. Choose to keep resources if waiting for Azure Policy results. | Interactive choices; passes `-InvokedBy 'Run-ForegroundWorkflowTest.ps1'` when invoking core workflow. | Prompts at end whether to clean up. If you expect policy data to appear later, answer No to cleanup and run `Regenerate-ComplianceReport.ps1` (helper available via the `W` option). |
| [scripts/Create-PolicyTestEnvironment.ps1](scripts/Create-PolicyTestEnvironment.ps1) | Creates resource group(s), Key Vaults, sample secrets/keys/certs for compliant and non-compliant scenarios. | Before running the core workflow when you need a fresh test environment. | `-SubscriptionId`, `-ResourceGroupName`, `-Location`, `-CreateCompliant`, `-CreateNonCompliant` | Creates multiple vaults and test data; idempotent behavior may vary. |
| [scripts/Reset-PolicyTestEnvironment.ps1](scripts/Reset-PolicyTestEnvironment.ps1) | Cleans up test resources and removes policy assignments. Destructive. | After tests or when you want to remove created resources. | `-ResourceGroupName`, `-WhatIf`, `-Confirm`, `-RemovePolicyAssignments` | Use `WhatIf`/Confirm by default to avoid accidental destruction. |
| [scripts/Regenerate-ComplianceReport.ps1](scripts/Regenerate-ComplianceReport.ps1) | Re-queries Azure Policy state and regenerates compliance HTML/JSON/CSV for a given `-WorkflowRunId`. | When compliance data was not available during run (Azure Policy evaluations may take 15–30 minutes). | `-WorkflowRunId` (required), `-ResourceGroupName` (optional) | Generates `artifacts/json/compliance-report-<id>.json`, `artifacts/html/compliance-report-<id>.html`, and CSV. Can be invoked repeatedly; use the foreground helper to poll automatically. |
| [scripts/Validate-KeyVaultPolicies.ps1](scripts/Validate-KeyVaultPolicies.ps1) | Local validation checks for vault config and policy-level detections used in post-run validation. | Use when you want a quick local validation of vault settings outside of Azure Policy timing. | `-SubscriptionId`, `-ResourceGroupName` | Complements Azure Policy evaluations. |

---

Notes:
- Artifacts: all reporting outputs are placed under `artifacts/` (subfolders `json`, `html`, `csv`). `Run-CompleteWorkflow.ps1` writes an `artifacts-manifest-<id>.json` which now includes `generatedBy`, `invokedBy`, and `generatedAt` metadata.
- Provenance: callers should pass `-InvokedBy` where possible; test harnesses are already updated to do so.
- Re-running compliance: use [scripts/Regenerate-ComplianceReport.ps1](scripts/Regenerate-ComplianceReport.ps1) or the inline poll helper in `Run-ForegroundWorkflowTest.ps1` (choose `W` when prompted).

If you'd like, I can extend this `master.md` with a searchable index, add links to example outputs, or generate a printable PDF.
