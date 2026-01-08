# Run Decision Tree — Which script to run and dependencies

Legend:
- (A) Automated / non-interactive
- (I) Interactive
- * = creates resources
- ! = destructive / cleanup

Decision tree (start here):

Run locally? ──┬── No (CI / automated) ──> `Run-FullWorkflowTest.ps1` (A)
              │                          └─> calls: `Create-PolicyTestEnvironment.ps1` * -> `Run-CompleteWorkflow.ps1` -> `Reset-PolicyTestEnvironment.ps1` (!)
              │
              └── Yes (manual) ──┬── Want interactive, step-through? ──> `Run-ForegroundWorkflowTest.ps1` (I)
                                 │                                       └─> prompts -> (optionally) `Create-PolicyTestEnvironment.ps1` * -> `Run-CompleteWorkflow.ps1` (-DevTestMode often) -> `Reset-PolicyTestEnvironment.ps1` (!) if chosen
                                 │
                                 └── Want single run against existing env? ──> `Run-CompleteWorkflow.ps1` (A/I)
                                                                         ├─ Use `-ResourceGroupName` to scope
                                                                         ├─ Use `-DevTestMode` only in disposable test envs (breaking)
                                                                         ├─ Use `-AutoRemediate` for safer fixes
                                                                         └─ Produces artifacts in `artifacts/json|html|csv`


Quick dependency map (ordered):
- `Create-PolicyTestEnvironment.ps1` (creates test RG & vaults) —> optional first step for tests
- `Run-CompleteWorkflow.ps1` (core generator) —> required by both test runners
- `Run-FullWorkflowTest.ps1` (automated harness) —> calls Create -> Run-CompleteWorkflow -> Reset
- `Run-ForegroundWorkflowTest.ps1` (interactive harness) —> optionally calls Create -> Run-CompleteWorkflow -> offers Reset
- `Reset-PolicyTestEnvironment.ps1` (cleanup) —> run after tests or invoked by harnesses
- `Validate-KeyVaultPolicies.ps1` / `Generate-*` scripts —> auxiliary; run after or called by `Run-CompleteWorkflow.ps1`

Common flows (concise):
- End-to-end automated CI: `Run-FullWorkflowTest.ps1` (non-interactive)
- Manual demo / step-through: `Run-ForegroundWorkflowTest.ps1` (interactive)
- Single run against existing resources: `Run-CompleteWorkflow.ps1`

Safety notes:
- `-DevTestMode` makes breaking changes (enables RBAC, adds firewall rules, creates Log Analytics, sets expirations). Use only in disposable test environments.
- To preserve resources, use `-SkipReset` on the full test script or choose Reuse in the foreground runner.
- `Run-CompleteWorkflow.ps1` now accepts `-InvokedBy` and annotates produced artifacts with provenance metadata.

Quick commands:
```powershell
# Automated full test (CI)
.\scripts\Run-FullWorkflowTest.ps1

# Interactive foreground demo
.\scripts\Run-ForegroundWorkflowTest.ps1

# Single run against existing RG (safe options)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName rg-policy-keyvault-test -WorkflowRunId 20260107-130310 -AutoRemediate -SkipComplianceWait
```

If you want, I can also:
- Add a visual PNG of the tree, or
- Generate a CSV listing script dependencies and switches.
