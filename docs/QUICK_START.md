# Quick Start Guide - Azure Key Vault Security Assessment

**Date:** January 6, 2026 (Updated: January 8, 2026)  
**Purpose:** Fast-track commands for complete Key Vault security workflow

---

## 📊 Report Quality (Updated 2026-01-08)

All generated reports now include:
- **Friendly Policy Names**: "Azure Key Vaults should use private link" instead of GUIDs
- **Evaluation Explanations**: Clear notes explaining why 5 vaults = 15 evaluations
- **Comprehensive Metadata**: All HTML/JSON/CSV reports include generation details

See [COMPLIANCE_REPORT_ENHANCEMENT.md](COMPLIANCE_REPORT_ENHANCEMENT.md) for details.

---

## ⚡ Prerequisites: Test Environment Setup

### IMPORTANT: Reset vs. Create

**Reset Script (`Reset-PolicyTestEnvironment.ps1`):**
- ❌ **DOES NOT** create new Azure resources
- ✅ **ONLY CLEANS** existing test resources (local artifacts are preserved by default)
- Purpose: Clean slate for re-running workflow on existing environment while keeping generated reports for archive
- Use when: You want to clear previous test runs' Azure resources but keep artifacts for review

**Test Environment Script (`Test-AzurePolicyKeyVault.ps1` or `Create-PolicyTestEnvironment.ps1`):**
- ✅ **CREATES** new Azure resources (Key Vaults, secrets, certificates, etc.)
- ✅ **GENERATES** test environment with compliant and non-compliant vaults
- Purpose: Build new test infrastructure
- Use when: First time setup or after reset script has cleaned everything

### Workflow Order

```powershell
# 1️⃣ FIRST TIME: Create test environment
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"
# Creates: 10 Key Vaults with intentional violations for testing

# 2️⃣ Run the complete workflow
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# 3️⃣ LATER: Clean up to start over (artifacts preserved by default)
# Reset Azure resources only (preserves JSON/HTML/CSV artifacts):
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"
# To also delete local artifacts, add `-CleanArtifacts`:
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test" -CleanArtifacts -Confirm

# 4️⃣ REPEAT: Create environment again (after reset)
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# 5️⃣ Run workflow again on fresh environment
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-keyvault-test"
```

### Script Comparison

| Feature | Reset-PolicyTestEnvironment.ps1 | Create-PolicyTestEnvironment.ps1 | Test-AzurePolicyKeyVault.ps1 |
|---------|--------------------------------|----------------------------------|----------------------------|
| **Creates Key Vaults** | ❌ No | ✅ Yes (10 vaults) | ✅ Yes (10 vaults) |
| **Creates Secrets/Keys** | ❌ No | ✅ Yes | ✅ Yes |
| **Deletes Resources** | ✅ Yes | ❌ No | ❌ No |
| **Removes Policies** | ✅ Yes | ❌ No | ❌ No |
| **Cleans Artifacts** | Optional (`-CleanArtifacts`) | ❌ No | ❌ No |
| **Runs Tests** | ❌ No | ❌ No | ✅ Yes |
| **Use Case** | Start fresh | Initial setup | Full test suite |

### Quick Decision Tree

```
Do you have test Key Vaults already?
│
├─ NO → Use Create-PolicyTestEnvironment.ps1 or Test-AzurePolicyKeyVault.ps1
│        (Creates new vaults with test data)
│
└─ YES → Do you want to keep them?
         │
         ├─ NO → Use Reset-PolicyTestEnvironment.ps1
         │        (Deletes vaults, then run Create again)
         │
         └─ YES → Use Run-CompleteWorkflow.ps1
                  (Runs workflow on existing vaults)
```

---

## 🚀 Complete Workflow (Copy-Paste Ready)

### Option A: Automated Full Workflow (Recommended)

```powershell
# Run complete workflow with all steps - generates HTML + JSON for everything
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-test"

# With auto-remediation
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-test" -AutoRemediate

# Output: 
#  - baseline-{timestamp}.json + .html
#  - policy-assignments-{timestamp}.json + .html
#  - compliance-report-{timestamp}.json + .html + .csv
#  - remediation-preview-{timestamp}.json + .html
#  - remediation-results-{timestamp}.json + .html
#  - after-remediation-{timestamp}.json + .html
#  - Workflow-Comprehensive-Report-{timestamp}.json + .html (FINAL SUMMARY)
```

### Option B: Step-by-Step Manual Workflow

### Step 1: Capture Current Environment (5 minutes)

```powershell
# Change to project directory
cd C:\Temp

# Capture baseline state of all Key Vaults
.\scripts\Document-PolicyEnvironmentState.ps1 `
    -ResourceGroupName "rg-policy-test" `
    -OutputPath "baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss').json" `
    -IncludeCompliance

# Output: 
#  📄 baseline-{timestamp}.json - Full state data
#  🌐 baseline-{timestamp}.html - Visual report (auto-generated)
```

---

### Step 2: Deploy Audit Policies (2 minutes)

```powershell
# Get your subscription ID
$subId = (Get-AzContext).Subscription.Id
Write-Host "Deploying to subscription: $subId" -ForegroundColor Cyan

# Deploy all 16 policies in Audit mode (monitoring only, non-blocking)
.\reports\remediation-scripts\Assign-AuditPolicies.ps1 -SubscriptionId $subId

# OR preview what would be deployed without making changes
.\reports\remediation-scripts\Assign-AuditPolicies.ps1 -SubscriptionId $subId -WhatIf
```

**Expected Output:**
```
Assigning Azure Key Vault policies in AUDIT mode...
✓ Assigned: Key vaults should have soft delete enabled
✓ Assigned: Key vaults should have purge protection enabled
... (16 policies total)
All policies assigned successfully!
```

---

### Step 3: Wait for Compliance Scan (15-30 minutes)

```powershell
# Check if compliance data is available
$subId = (Get-AzContext).Subscription.Id
$compliance = Get-AzPolicyState -SubscriptionId $subId -Filter "ResourceType eq 'Microsoft.KeyVault/vaults'"

if ($compliance) {
    Write-Host "✓ Compliance scan complete!" -ForegroundColor Green
    Write-Host "Found $($compliance.Count) policy evaluations" -ForegroundColor Cyan
} else {
    Write-Host "⏳ Compliance scan still in progress. Wait 10-15 more minutes." -ForegroundColor Yellow
}
```

---

### Step 4: Generate Compliance Report (2 minutes)

```powershell
# Get current subscription ID
$subId = (Get-AzContext).Subscription.Id
$date = Get-Date -Format "yyyyMMdd-HHmmss"

# Export detailed compliance report to CSV
Get-AzPolicyState -SubscriptionId $subId | 
    Where-Object { $_.ResourceType -eq 'Microsoft.KeyVault/vaults' } |
    Select-Object ResourceId, PolicyDefinitionName, ComplianceState, Timestamp |
    Export-Csv "compliance-report-$date.csv" -NoTypeInformation

Write-Host "✓ Report saved: compliance-report-$date.csv" -ForegroundColor Green

# Display summary
$compliance = Import-Csv "compliance-report-$date.csv"
$summary = $compliance | Group-Object ComplianceState | 
    Select-Object Name, Count

Write-Host "`nCompliance Summary:" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

# Show violations by policy
Write-Host "`nNon-Compliant Resources by Policy:" -ForegroundColor Yellow
$compliance | Where-Object ComplianceState -eq 'NonCompliant' |
    Group-Object PolicyDefinitionName |
    Select-Object Count, @{N='Policy';E={$_.Name}} |
    Sort-Object Count -Descending |
    Format-Table -AutoSize
```

**Example Output:**
```
Compliance Summary:
Name          Count
----          -----
Compliant     45
NonCompliant  23

Non-Compliant Resources by Policy:
Count Policy
----- ------
8     Key vaults should have purge protection enabled
6     Secrets should have expiration date set
5     Key vaults should use RBAC authorization
4     Public network access should be disabled
```

---

### Step 5: Preview Remediations (5 minutes)

```powershell
# Scan all vaults and show what would be fixed (no changes made)
.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 -ScanOnly

# Output shows:
# - Vaults needing remediation
# - Which fixes can be automated (safe)
# - Which fixes require manual review
```

**Example Output:**
```
Scanning 15 Key Vaults for compliance issues...

SAFE AUTO-REMEDIATIONS (can be automated):
  ✓ kv-prod-app1: Enable soft delete
  ✓ kv-prod-app2: Enable purge protection
  ✓ kv-dev-test: Migrate to RBAC authorization

MANUAL REVIEW REQUIRED:
  ⚠ kv-prod-web: Configure firewall rules (requires IP allowlist)
  ⚠ kv-prod-api: Enable diagnostic logging (requires Log Analytics workspace)
  ⚠ kv-prod-db: Set secret expiration dates (requires app coordination)

Summary: 3 auto-remediations available, 3 manual remediations needed
```

---

### Step 6: Execute Safe Remediations (10 minutes)

```powershell
# Apply automated fixes (soft delete, purge protection, RBAC migration)
.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 -AutoRemediate

# Export custom scripts for manual remediations
.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 `
    -ExportScripts `
    -OutputPath "custom-remediation-scripts"

Write-Host "`nCustom remediation scripts saved to: custom-remediation-scripts\" -ForegroundColor Green
```

---

### Step 7: Verify Improvements (5 minutes)

```powershell
# Capture post-remediation state
.\scripts\Document-PolicyEnvironmentState.ps1 `
    -OutputPath "after-remediation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json" `
    -IncludeCompliance

# Compare before/after (assumes you saved baseline earlier)
$beforeFile = Get-ChildItem "baseline-*.json" | Sort-Object LastWriteTime | Select-Object -Last 1
$afterFile = Get-ChildItem "after-remediation-*.json" | Sort-Object LastWriteTime | Select-Object -Last 1

$before = Get-Content $beforeFile.FullName | ConvertFrom-Json
$after = Get-Content $afterFile.FullName | ConvertFrom-Json

Write-Host "`n=== REMEDIATION IMPACT ===" -ForegroundColor Cyan
Write-Host "Before: $($before.summary.totalViolations) violations" -ForegroundColor Yellow
Write-Host "After:  $($after.summary.totalViolations) violations" -ForegroundColor Green
Write-Host "Fixed:  $(($before.summary.totalViolations - $after.summary.totalViolations)) violations" -ForegroundColor Green

$improvement = [math]::Round((($before.summary.totalViolations - $after.summary.totalViolations) / $before.summary.totalViolations) * 100, 1)
Write-Host "Improvement: $improvement%" -ForegroundColor Cyan
```

---

### Step 8: Deploy Enforcement (OPTIONAL - Week 5-6)

```powershell
# ⚠️ WARNING: This BLOCKS non-compliant resource operations!
# Only run after all critical vaults are compliant

# Preview enforcement assignments
.\reports\remediation-scripts\Assign-DenyPolicies.ps1 `
    -SubscriptionId $subId `
    -WhatIf

# Deploy enforcement (requires confirmation)
.\reports\remediation-scripts\Assign-DenyPolicies.ps1 `
    -SubscriptionId $subId `
    -ConfirmEnforcement

# After enforcement, test that non-compliant operations are blocked
.\Test-AzurePolicyKeyVault.ps1 -TestMode Deny
```

---

## 📋 Common Commands

### Check Azure Context
```powershell
# Verify you're logged in and using correct subscription
Get-AzContext

# Switch subscription if needed
Set-AzContext -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
```

### List All Key Vaults
```powershell
# Show all vaults in current subscription
Get-AzKeyVault | Select-Object VaultName, ResourceGroupName, Location

# Get specific vault details
Get-AzKeyVault -VaultName "kv-prod-app1" | Format-List
```

### Check Policy Assignments
```powershell
# List all policy assignments at subscription level
Get-AzPolicyAssignment -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)" |
    Where-Object { $_.Properties.DisplayName -like '*Key Vault*' } |
    Select-Object Name, @{N='Policy';E={$_.Properties.DisplayName}}
```

### Remove Policy Assignments (Cleanup)
```powershell
# Remove all Key Vault policy assignments
Get-AzPolicyAssignment | 
    Where-Object { $_.Properties.DisplayName -like '*Key Vault*' } |
    ForEach-Object { Remove-AzPolicyAssignment -Id $_.ResourceId }
```

### Generate Test Environment
```powershell
# Create 5 test vaults (2 compliant, 3 non-compliant)
.\scripts\Create-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-policy-test" `
    -Location "eastus"

# Test policies against test environment
.\Test-AzurePolicyKeyVault.ps1 `
    -TestMode Both `
    -ResourceGroupName "rg-policy-test"
```

---

## 📊 Monitoring & Alerting Setup

### Enable Diagnostic Logging (All Vaults)
```powershell
# Requires Log Analytics workspace
$workspaceId = "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}"

Get-AzKeyVault | ForEach-Object {
    Write-Host "Enabling logging for: $($_.VaultName)" -ForegroundColor Cyan
    
    Set-AzDiagnosticSetting -ResourceId $_.ResourceId `
        -WorkspaceId $workspaceId `
        -Name "DiagnosticSettings" `
        -Enabled $true `
        -Category AuditEvent `
        -RetentionEnabled $true `
        -RetentionInDays 90
}
```

### Create Azure Monitor Alert
```powershell
# Alert on policy violations
$actionGroup = Get-AzActionGroup -Name "SecurityTeam" -ResourceGroupName "rg-monitoring"

New-AzActivityLogAlert `
    -Name "KeyVault-PolicyViolation" `
    -ResourceGroupName "rg-monitoring" `
    -Location "Global" `
    -Condition @{field='category'; equals='Policy'; field='operationName'; equals='Microsoft.Authorization/policyStates/write'} `
    -ActionGroupId $actionGroup.Id `
    -Description "Alert when Key Vault becomes non-compliant"
```

### Daily Compliance Report (Azure Automation)
```powershell
# Save as runbook in Azure Automation
$subId = (Get-AzContext).Subscription.Id
$date = Get-Date -Format "yyyyMMdd"

# Get compliance state
$compliance = Get-AzPolicyState -SubscriptionId $subId | 
    Where-Object { $_.ResourceType -eq 'Microsoft.KeyVault/vaults' }

# Export to Blob Storage
$storageAccount = Get-AzStorageAccount -ResourceGroupName "rg-reports" -Name "stcompliance"
$ctx = $storageAccount.Context

$compliance | ConvertTo-Json -Depth 10 | 
    Set-AzStorageBlobContent -Container "compliance-reports" `
        -Blob "keyvault-compliance-$date.json" `
        -Context $ctx `
        -Force

# Send email summary
$summary = @{
    Date = $date
    Compliant = ($compliance | Where-Object ComplianceState -eq 'Compliant').Count
    NonCompliant = ($compliance | Where-Object ComplianceState -eq 'NonCompliant').Count
}

Send-MailMessage -To "security@company.com" `
    -Subject "Key Vault Compliance - $date" `
    -Body "Compliant: $($summary.Compliant), Non-Compliant: $($summary.NonCompliant)"
```

---

## 🎯 Quick Reference

| Task | Command | Duration |
|------|---------|----------|
| Capture baseline | `.\scripts\Document-PolicyEnvironmentState.ps1` | 5 min |
| Deploy Audit policies | `.\reports\remediation-scripts\Assign-AuditPolicies.ps1` | 2 min |
| Wait for scan | Azure Policy evaluation | 15-30 min |
| Generate report | `Get-AzPolicyState` + Export-Csv | 2 min |
| Preview fixes | `.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 -ScanOnly` | 5 min |
| Execute fixes | `.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 -AutoRemediate` | 10 min |
| Verify improvements | Compare before/after JSON | 5 min |
| Deploy enforcement | `.\reports\remediation-scripts\Assign-DenyPolicies.ps1` | 2 min |

**Total Time:** ~45 minutes (excluding 15-30 min Azure Policy scan wait)

---

## 📚 Documentation Reference

| Document | Purpose | Lines |
|----------|---------|-------|
| [README.md](README.md) | Project overview, prerequisites, features | 748 |
| [SCENARIO_VERIFICATION.md](SCENARIO_VERIFICATION.md) | Complete scenario coverage verification | 800+ |
| [docs/secrets-guidance.md](docs/secrets-guidance.md) | Comprehensive best practices guide | 835 |
| [AzurePolicy-KeyVault-TestMatrix.md](AzurePolicy-KeyVault-TestMatrix.md) | All 16 policies detailed | 200+ |
| [GAP_ANALYSIS.md](GAP_ANALYSIS.md) | Missing tests and recommendations | 124 |
| [reports/remediation-scripts/README.md](reports/remediation-scripts/README.md) | Remediation workflow guide | 150+ |
| [scripts/README.md](scripts/README.md) | 5-phase testing workflow | 220 |

---

## ⚠️ Important Notes

### Audit vs Deny Mode
- **Audit:** Monitors compliance, allows all operations (recommended first)
- **Deny:** Blocks non-compliant operations (enforce after remediation)

### Compliance Scan Timing
- **New assignments:** 15-30 minutes for first scan
- **Updates:** 15-30 minutes after resource changes
- **Dashboard updates:** Up to 24 hours for initial visualization

### Safe Auto-Remediations
- ✅ Enable soft delete (can be disabled within 90 days)
- ✅ Enable purge protection (permanent - cannot be disabled)
- ✅ Migrate to RBAC (preserves existing permissions)

### Manual Review Required
- ⚠️ Network isolation (requires IP allowlists or private endpoints)
- ⚠️ Diagnostic logging (requires Log Analytics workspace)
- ⚠️ Object expiration dates (requires app coordination)

---

## 🚨 Troubleshooting

### "WhatIf parameter defined multiple times"
**Fix:** Already applied in latest version of `Assign-AuditPolicies.ps1`

### "Cannot evaluate parameter 'SubscriptionId' as script block"
```powershell
# ❌ Wrong: Get-AzPolicyState -SubscriptionId {sub-id}
# ✅ Correct:
$subId = (Get-AzContext).Subscription.Id
Get-AzPolicyState -SubscriptionId $subId
```

### "No compliance data available" / Compliance Report Shows 0 Evaluations
**Cause:** Azure Policy evaluation takes 5-30 minutes after policy assignment  
**Solution:** 

**Option 1: Wait during workflow**
- When the workflow test pauses at "Policy validation completed", choose [W] to wait and retry
- The script will re-query Azure Policy for updated compliance data

**Option 2: Re-generate compliance report later**
```powershell
# Keep resources alive (choose [N] at cleanup prompt)
# Then run this script after 15-30 minutes:
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310

# Or with resource group filter:
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310 -ResourceGroupName rg-policy-keyvault-test
```

**Option 3: Manual check in Azure Portal**
- Navigate to: Azure Portal → Policy → Compliance
- Wait until policy evaluations show "Compliant" or "Non-Compliant" (not "Not Started")
- Then re-run: `.\scripts\Regenerate-ComplianceReport.ps1`

### "Policy assignment already exists"
**Cause:** Policies deployed previously  
**Solution:** Remove existing assignments or skip with `-Force` parameter

---

## 📞 Support

- **Test Reports:** `AzurePolicy-KeyVault-TestReport-{date}.html`
- **Compliance Data:** `Get-AzPolicyState -SubscriptionId $subId`
- **Best Practices:** [docs/secrets-guidance.md](docs/secrets-guidance.md)
- **Policy Matrix:** [AzurePolicy-KeyVault-TestMatrix.md](AzurePolicy-KeyVault-TestMatrix.md)

---

---

## 🔄 Reset Environment & Start Over

### Clean Up Test Environment

```powershell
# Option 1: Clean everything (Key Vaults + Policies + Artifacts)
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-policy-test" `
    -RemovePolicyAssignments `
    -CleanArtifacts `
    -Confirm

# Option 2: Clean only artifacts (keep Azure resources)
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -CleanArtifacts `
    -KeepDocumentation

# Option 3: Clean only Azure resources (keep local reports)
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-policy-test" `
    -RemovePolicyAssignments `
    -CleanArtifacts:$false
```

**What Gets Deleted:**
- ✓ Test Key Vaults in specified resource group
- ✓ Azure Policy assignments for Key Vault
- ✓ All JSON/HTML/CSV artifacts (baseline, compliance, remediation reports)
- ✓ Resource tracking data
- ✓ Keeps documentation files (README, guides, matrix)

---

## 📊 Artifact Output Summary

### Every Step Produces Multiple Formats

| Step | JSON | HTML | CSV | Description |
|------|------|------|-----|-------------|
| **1. Baseline** | ✅ | ✅ | ❌ | Current environment state |
| **2. Policy Deploy** | ✅ | ✅ | ❌ | Assigned policies list |
| **3. Compliance** | ✅ | ✅ | ✅ | Azure Policy violations |
| **4. Remediation Preview** | ✅ | ✅ | ❌ | Fixable issues analysis |
| **5. Remediation Execute** | ✅ | ✅ | ❌ | Remediation results |
| **6. After-State** | ✅ | ✅ | ❌ | Post-fix environment |
| **7. Comprehensive** | ✅ | ✅ | ❌ | **All steps combined** |

### Final Comprehensive Report

**Workflow-Comprehensive-Report-{timestamp}.html** includes:
- 📊 Before/After comparison with charts
- 📈 Improvement percentage and metrics
- 📋 All workflow steps with summaries
- 🔍 Detailed violation breakdown
- ✅ Resolved vs. Remaining issues
- 🎯 Interactive HTML with styling

**Workflow-Comprehensive-Report-{timestamp}.json** includes:
- Complete workflow execution data
- All step artifacts consolidated
- Programmatic access for automation
- Integration with monitoring tools

---

## 🚀 Quick Start Examples

### Example 1: Fresh Assessment

```powershell
# 1. Create test environment
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-test"

# 2. Run complete workflow
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-test"

# 3. Open comprehensive report
Invoke-Item (Get-ChildItem "Workflow-Comprehensive-Report-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

### Example 2: Re-Run After Changes

```powershell
# 1. Clean up previous run
.\scripts\Reset-PolicyTestEnvironment.ps1 -CleanArtifacts -KeepDocumentation

# 2. Run workflow again
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-test"

# 3. Compare reports
$reports = Get-ChildItem "Workflow-Comprehensive-Report-*.html" | Sort-Object LastWriteTime -Descending
Invoke-Item $reports[0].FullName  # Latest
Invoke-Item $reports[1].FullName  # Previous
```

### Example 3: Production Assessment

```powershell
# 1. Baseline ALL vaults in subscription
.\scripts\Document-PolicyEnvironmentState.ps1 -OutputPath "production-baseline.json" -IncludeCompliance

# 2. Deploy Audit policies
$subId = (Get-AzContext).Subscription.Id
.\reports\remediation-scripts\Assign-AuditPolicies.ps1 -SubscriptionId $subId

# 3. Wait 30 minutes for compliance scan

# 4. Generate compliance report
Get-AzPolicyState -SubscriptionId $subId | 
    Where-Object { $_.ResourceType -eq 'Microsoft.KeyVault/vaults' } |
    Export-Csv "production-compliance.csv" -NoTypeInformation

# 5. Review violations
Import-Csv "production-compliance.csv" | 
    Where-Object ComplianceState -eq 'NonCompliant' | 
    Group-Object PolicyDefinitionName | 
    Format-Table Count, Name -AutoSize
```

---

## 📁 Artifact File Naming Convention

All artifacts use consistent naming: `{type}-{timestamp}.{format}`

**Examples:**
- `baseline-20260106-143022.json`
- `baseline-20260106-143022.html`
- `compliance-report-20260106-143530.json`
- `compliance-report-20260106-143530.html`
- `compliance-report-20260106-143530.csv`
- `Workflow-Comprehensive-Report-20260106-144500.json`
- `Workflow-Comprehensive-Report-20260106-144500.html`

**Benefits:**
- ✓ Chronological sorting
- ✓ Easy to find latest
- ✓ Compare multiple runs
- ✓ Archive historical data

---

**Ready to secure your Key Vaults? Start with Step 1!** 🚀
