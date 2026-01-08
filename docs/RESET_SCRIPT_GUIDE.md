# Reset Script Complete Guide

**Date:** January 6, 2026 (Updated: January 8, 2026)  
**Script:** `Reset-PolicyTestEnvironment.ps1`  
**Purpose:** Understanding when and how to use the reset script

**Note (2026-01-08):** All workflow reports generated after reset now include friendly policy names and comprehensive metadata footers.

---

## ⚠️ CRITICAL: What Reset Script Does and Doesn't Do

### ❌ What Reset Script DOES NOT Do

**The reset script is NOT a setup or creation tool.**

It **DOES NOT**:
- ❌ Create new Azure resources (Key Vaults, secrets, keys, certificates, identities)
- ❌ Generate test data
- ❌ Set up test environment
- ❌ Configure Azure resources
- ❌ Deploy policies
- ❌ Prepare anything for workflow execution
- ❌ Build test infrastructure

### ✅ What Reset Script DOES

**The reset script is a cleanup/demolition tool.**

It **DOES**:
- ✅ **DELETE** Key Vaults in specified resource group
- ✅ **REMOVE** Azure Policy assignments at subscription level
- ✅ **CLEAN** local artifacts:
  - Baseline JSON/HTML files
  - Compliance report JSON/HTML/CSV files
  - Remediation JSON/HTML files
  - After-state JSON/HTML files
  - Comprehensive report JSON/HTML files
- ✅ **RESET** resource tracking data (resource-tracking.json)
- ✅ **PREPARE** clean slate for next workflow run

---

## 🔄 Complete Workflow Cycle

### Understanding the Three Key Scripts

| Script | Role | Analogy | What It Does |
|--------|------|---------|--------------|
| **Reset-PolicyTestEnvironment.ps1** | Destroyer | Demolition Crew | Tears down existing test infrastructure |
| **Create-PolicyTestEnvironment.ps1** | Builder | Construction Crew | Builds new test infrastructure |
| **Run-CompleteWorkflow.ps1** | Tester | Building Inspector | Tests and generates reports |

**Key Insight:** You cannot inspect a building that doesn't exist!

**Order:** BUILD → INSPECT → DEMOLISH → BUILD AGAIN

---

## 📋 Step-by-Step Workflow

### First Time Setup

```powershell
# Step 1: Create test environment (BUILDS test infrastructure)
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# What this creates:
# ✓ Resource group (if doesn't exist)
# ✓ 10 Key Vaults (5 compliant, 5 non-compliant)
# ✓ Secrets with various configurations
# ✓ Keys with different settings
# ✓ Certificates for testing
# ✓ Intentional policy violations for testing

# Step 2: Run complete workflow (TESTS and REPORTS)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# What this generates:
# ✓ baseline-{timestamp}.json + .html
# ✓ compliance-report-{timestamp}.json + .html + .csv
# ✓ remediation-preview-{timestamp}.json + .html
# ✓ remediation-results-{timestamp}.json + .html
# ✓ after-remediation-{timestamp}.json + .html
# ✓ Workflow-Comprehensive-Report-{timestamp}.json + .html

# Step 3: Review results
$latest = Get-ChildItem "artifacts\html\Workflow-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Invoke-Item $latest.FullName
```

### Starting Over (Reset and Re-Run)

```powershell
# Step 4: Reset environment (DESTROYS test infrastructure)
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -CleanArtifacts

# What this deletes:
# ✓ All Key Vaults in rg-policy-keyvault-test
# ✓ Azure Policy assignments
# ✓ All local artifacts (JSON, HTML, CSV)
# ✓ Resource tracking data

# Step 5: Create environment again (REBUILDS test infrastructure)
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# What this creates:
# ✓ Fresh 10 Key Vaults with new configurations
# ✓ New test data
# ✓ New resource tracking

# Step 6: Run workflow again
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-keyvault-test"
```

---

## 🎯 When to Use Reset Script

### ✅ Use Reset Script When:
 ✅ **OPTIONAL: CLEAN** local artifacts (only when `-CleanArtifacts` is specified):
  - Baseline JSON/HTML files
  - Compliance report JSON/HTML/CSV files
  - Remediation JSON/HTML files
  - After-state JSON/HTML files
  - Comprehensive report JSON/HTML files
2. **Cleaning Up After Testing**
   - You're done with testing
   - You want to remove all test resources
   - You need to free up Azure quota
```powershell
# Minimum: reset Azure resources only (artifacts preserved by default)
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# To also delete local artifacts (JSON/HTML/CSV), pass -CleanArtifacts explicitly
.\scripts\Reset-PolicyTestEnvironment.ps1 `
   -ResourceGroupName "rg-policy-keyvault-test" `
   -CleanArtifacts `
   -Confirm
```
3. **Removing Old Artifacts**
   - Your artifacts folder is cluttered
   - You want to clean up old reports
```powershell
# Full Cleanup (Azure resources + local artifacts)
.\scripts\Reset-PolicyTestEnvironment.ps1 `
   -ResourceGroupName "rg-policy-keyvault-test" `
   -RemovePolicyAssignments `
   -CleanArtifacts `
   -Confirm
```
   - You need different test data

5. **Before Demo or Presentation**
```powershell
# Just delete Azure resources (keep artifacts for review) — default behavior
.\scripts\Reset-PolicyTestEnvironment.ps1 `
   -ResourceGroupName "rg-policy-keyvault-test" `
   -RemovePolicyAssignments
```
### ❌ DON'T Use Reset Script When:

1. **Haven't Created Environment Yet**
   - ❌ Wrong: Run reset first
   - ✅ Correct: Run Create-PolicyTestEnvironment.ps1 first
   - Reset would have nothing to delete

2. **Just Want to Re-Run Reports**
   - ❌ Wrong: Reset then re-create then run workflow
   - ✅ Correct: Just run workflow scripts again
   - No need to delete and recreate vaults

3. **Want to Compare Results**
   - ❌ Wrong: Reset artifacts
   - ✅ Correct: Keep old artifacts for comparison
   - Reset would delete historical data

4. **Want to Test Remediation**
   - ❌ Wrong: Reset between baseline and remediation
   - ✅ Correct: Run full workflow without reset
   - Reset would lose baseline state

---

## 🔍 Reset Script Options

### Basic Usage

```powershell
# Minimum - just clean artifacts (keep Azure resources)
.\scripts\Reset-PolicyTestEnvironment.ps1 -CleanArtifacts
```

### Full Cleanup

```powershell
# Delete everything - Azure resources + artifacts
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -RemovePolicyAssignments `
    -CleanArtifacts `
    -Confirm
```

### Selective Cleanup

```powershell
# Just delete Azure resources (keep artifacts for review)
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-policy-keyvault-test" `
    -RemovePolicyAssignments `
    -CleanArtifacts:$false
```

---

## ⚡ Quick Decision Tree

```
Do you have test Key Vaults already?
│
├─ NO → Use Create-PolicyTestEnvironment.ps1
│        (Creates new vaults with test data)
│        Then: Run-CompleteWorkflow.ps1
│
└─ YES → Do you want to keep them?
         │
         ├─ NO → Use Reset-PolicyTestEnvironment.ps1
         │        (Deletes vaults + artifacts)
         │        Then: Create-PolicyTestEnvironment.ps1
         │        Then: Run-CompleteWorkflow.ps1
         │
         └─ YES → Use Run-CompleteWorkflow.ps1
                  (Runs workflow on existing vaults)
```

---

## 🚨 Common Mistakes

### Mistake 1: Running Reset Before Create

```powershell
# ❌ WRONG ORDER
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-test"

# Result: Workflow fails - no vaults to test!
```

```powershell
# ✅ CORRECT ORDER
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-test"

# Result: Success - vaults exist to test
```

### Mistake 2: Resetting Between Workflow Steps

```powershell
# ❌ WRONG - Resetting mid-workflow
.\scripts\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-test"
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"  # ← DON'T DO THIS
.\scripts\Remediate-ComplianceIssues.ps1 -ResourceGroupName "rg-test"

# Result: Remediation fails - baseline state lost!
```

```powershell
# ✅ CORRECT - Complete workflow first
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-test"
# Review results
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
# Start fresh
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"

# Result: Clean workflow cycle
```

### Mistake 3: Expecting Reset to Create Resources

```powershell
# ❌ WRONG - Thinking reset creates vaults
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
# "Now I have a clean environment ready to test"

# Result: Environment is empty - nothing to test!
```

```powershell
# ✅ CORRECT - Use create script after reset
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
# "Now I have a clean environment WITH vaults ready to test"

# Result: Environment has fresh vaults
```

---

## 📊 What Gets Deleted by Reset Script

### Azure Resources (with `-ResourceGroupName`)

- ✅ All Key Vaults in specified resource group
- ✅ All secrets within those vaults
- ✅ All keys within those vaults
- ✅ All certificates within those vaults
- ❌ Resource group itself (not deleted)

### Azure Policies (with `-RemovePolicyAssignments`)

- ✅ All Azure Policy assignments for Key Vault at subscription level
- ❌ Policy definitions themselves (not deleted - these are built-in)

### Local Artifacts (with `-CleanArtifacts`)

- ✅ `baseline-*.json` and `.html`
- ✅ `compliance-report-*.json`, `.html`, `.csv`
- ✅ `remediation-preview-*.json` and `.html`
- ✅ `remediation-results-*.json` and `.html`
- ✅ `after-remediation-*.json` and `.html`
- ✅ `Workflow-Comprehensive-Report-*.json` and `.html`
- ✅ `resource-tracking.json`
- ❌ Documentation files (preserved with `-KeepDocumentation`)

---

## 💡 Best Practices

### 1. Always Create After Reset

```powershell
# Pattern: Reset → Create → Workflow
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test" -CleanArtifacts
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-test"
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-test"
```

### 2. Keep Artifacts for Comparison

```powershell
# Don't clean artifacts if you want to compare runs
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-test" `
    -CleanArtifacts:$false

# Artifacts from previous run preserved
# Create new environment and run workflow
# Compare old vs new reports
```

### 3. Use Confirmation for Safety

```powershell
# Always use -Confirm for production-like environments
.\scripts\Reset-PolicyTestEnvironment.ps1 `
    -ResourceGroupName "rg-production-test" `
    -Confirm

# Script will ask you to type "DELETE" to proceed
```

---

## 📖 Summary

**Reset Script Purpose:** Cleanup and prepare for fresh workflow run

**What It Does:**
- Destroys existing test infrastructure
- Removes Azure Policy assignments
- Cleans local artifacts

**What It Does NOT Do:**
- Create new test infrastructure
- Generate test data
- Set up environment

**Correct Usage Pattern:**
1. Create environment (Build)
2. Run workflow (Test)
3. Review results (Analyze)
4. Reset environment (Demolish)
5. Back to step 1 (Rebuild)

**Remember:** Reset = Eraser, Create = Builder, Workflow = Inspector

---

## 🔗 Related Documentation

- [README.md](README.md) - Complete project overview
- [QUICK_START.md](QUICK_START.md) - Fast-track workflow commands
- [DIRECTORY_REORGANIZATION.md](DIRECTORY_REORGANIZATION.md) - File organization details

---

**Questions?** Review the comprehensive examples above or see QUICK_START.md for copy-paste commands.
