# Azure Policy Compliance & Remediation - Quick Reference
**Last Updated:** 2026-01-08

This guide explains how to handle Azure Policy compliance data timing, use the compliance report regeneration script, and understand report enhancements.

---

## 🎯 Recent Enhancements (2026-01-08)

The compliance report system has been enhanced with:

1. **Friendly Policy Names**: GUID policy IDs now show friendly names (e.g., "Azure Key Vaults should use private link")
2. **Evaluation Count Explanation**: Reports now explain why 5 vaults show 15 evaluations (vault + resources evaluated separately)
3. **Report Metadata Footers**: All generated reports (HTML/JSON/CSV) include generation metadata:
   - Script name that generated the report
   - Command used
   - Mode (DevTest vs Production)
   - Timestamp
   - Workflow Run ID

### Updated Policy Name Mappings

The following GUID policy IDs are now automatically mapped to friendly names:

- `a6abeaec-4d90-4a02-805f-6b26c4d3ffd9` → "Azure Key Vaults should use private link"
- `cf820ca0-f99e-4f3e-84fb-66e913812d21` → "Azure Key Vault should have diagnostic logging enabled"

---

## 🕐 Azure Policy Compliance Timing

### The Challenge
Azure Policy evaluations take **15-30 minutes** after policy assignment or resource changes. During this time, compliance reports show **zero evaluations** (not a bug - just Azure catching up).

### What Happens During Workflow

1. **Step 1-3:** Baseline captured, policies assigned, workflow runs
2. **Step 4:** Compliance report generated → Shows "No data available" placeholder
3. **Azure Backend:** Policies start evaluating all Key Vaults (15-30 min)
4. **Step 5:** Remediation runs (fixes issues)
5. **After remediation:** Compliance data STILL may not be ready yet

### ✅ Solution: Automated Polling Helper

When you run `Run-ForegroundWorkflowTest.ps1`, the script offers to **poll automatically** for compliance data:

```
Would you like to poll for Azure Policy compliance now while resources are kept? (Y/N)
Enter your choice (Y/N): Y

Polling for compliance data...
Attempt 1/10: regenerating compliance report...
  Still zero evaluations in report.
Waiting 60 seconds before retry...
Attempt 2/10: regenerating compliance report...
  ✓ Compliance data found: 80 evaluations.
  ✓ Compliance report updated with fresh data.
```

**Polling Parameters:**
- **Interval:** 60 seconds between attempts
- **Max Attempts:** 10 (total: 10 minutes polling window)
- **Auto-Open:** Opens HTML report when data appears

---

## 🔧 Manual Compliance Report Regeneration

If you didn't poll during the workflow, regenerate the report later:

```powershell
# Wait 15-30 minutes after workflow completion, then:
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId <your-run-id> -ResourceGroupName <your-rg>

# Example:
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260108-115947 -ResourceGroupName rg-policy-keyvault-test
```

**Output:**
- Overwrites existing `compliance-report-<id>.json/html/csv` with fresh Azure Policy data
- Shows actual compliance state (not placeholder)

### Force Azure Policy Re-Evaluation

To trigger Azure to re-evaluate immediately (still takes 5-10 minutes):

```powershell
Start-AzPolicyComplianceScan -ResourceGroupName "rg-policy-keyvault-test"

# Then wait 5-10 minutes and regenerate report:
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId <run-id>
```

### What the Regenerated Report Includes

When you regenerate, the new report contains:

1. **Updated Compliance Data**: Fresh Azure Policy evaluation results
2. **Friendly Policy Names**: GUIDs replaced with readable names
3. **Evaluation Count Explanation**: CSV header comments explaining why evaluations don't match vault count
4. **Report Metadata**: Footer with:
   - Script name (Regenerate-ComplianceReport.ps1)
   - Command used
   - Timestamp
   - Workflow Run ID

**Example CSV Header Comments:**
```csv
# Azure Policy Compliance Report
# Generated: 2026-01-08 14:30:22
# Workflow Run ID: 20260108-115947
# 
# NOTE: Evaluation count may exceed vault count because Azure Policy evaluates:
# - Each Key Vault resource itself
# - Individual secrets within each vault
# - Individual keys within each vault
# - Individual certificates within each vault
# Example: 5 vaults with 2 secrets each = 5 vault evaluations + 10 secret evaluations = 15 total
```

---

## ⚙️ Remediation Mode Selection

### Production Mode vs DevTest Mode

When you run `Run-ForegroundWorkflowTest.ps1`, you'll see:

```
═══════════════════════════════════════════════════════════════════
 REMEDIATION MODE SELECTION
═══════════════════════════════════════════════════════════════════

Select remediation mode:
  [D] DevTest Mode    - Full auto-remediation (⚠️  BREAKS production - use for testing only)
  [P] Production Mode - Safe fixes only (✓ Recommended for production)
```

### 🟢 Production Mode (Recommended for Real Environments)

**What Gets Auto-Fixed:**
- ✅ Enable soft delete (non-breaking, adds 90-day recovery window)
- ✅ Enable purge protection (non-breaking, prevents permanent deletion)

**What Gets Flagged for Manual Review:**
- ⚠️ **RBAC migration** - Requires planning, invalidates existing access policies
- ⚠️ **Firewall configuration** - Requires IP allowlist, may block existing traffic
- ⚠️ **Diagnostic logging** - Requires Log Analytics workspace (cost impact)
- ⚠️ **Secret/key expiration** - Requires business policy on rotation schedules
- ⚠️ **Certificate policies** - Requires CA configuration and renewal planning

**Use When:**
- Running against production or shared environments
- You need stakeholder approval for breaking changes
- You want to review risky changes before applying

**Expected Outcome:**
- Improvement: 10-30% (only safe fixes applied)
- Manual review count: 8-15 items per vault
- Remediation report clearly shows what needs manual attention

---

### 🔴 DevTest Mode (Test Environments Only)

**What Gets Auto-Fixed:**
- ✅ Enable soft delete
- ✅ Enable purge protection
- ⚠️ **Force RBAC migration** (BREAKS existing access policies)
- ⚠️ **Configure test firewall** (deny all + Azure services bypass)
- ⚠️ **Create Log Analytics workspace and enable logging**
- ⚠️ **Auto-set 90-day expiration** on all secrets/keys without expiration

**Safety Confirmation:**
When you select DevTest mode, the remediation script prompts:

```
⚠️  DevTestMode will make BREAKING CHANGES:
   • RBAC migration (invalidates existing access policies)
   • Firewall configuration (may break existing access)
   • Auto-set expiration on secrets/keys
Continue with DevTestMode? (Y/N)
```

**Use When:**
- Testing in ephemeral dev/test environments
- Resources will be deleted after testing
- You want to see 100% automated remediation

**Expected Outcome:**
- Improvement: 80-100% (all fixable issues resolved)
- Manual review count: 0-3 items (only complex certificate policies)
- Remediation report shows "DevTest Mode Enabled" banner

---

## 📊 Understanding Remediation Reports

### Production Mode Report
```html
✓ PRODUCTION MODE - Safe Fixes Only
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Vaults scanned: 5
Total issues found: 16
  High: 3 (no purge protection)
  Medium: 13 (firewall, logging, expiration, RBAC)
Issues auto-remediated: 3 (purge protection enabled)
Manual review required: 13

Improvement: 18.75%
```

### DevTest Mode Report
```html
⚠️ DEV/TEST MODE ENABLED ⚠️
This report shows full automated remediation including BREAKING CHANGES.
Do NOT use these settings in production without careful review.

Vaults scanned: 5
Total issues found: 16
  High: 3 (no purge protection)
  Medium: 13 (firewall, logging, expiration, RBAC)
Issues auto-remediated: 15 (RBAC, firewall, logging, expiration, purge protection)
Manual review required: 1 (certificate CA configuration)

Improvement: 93.75%
```

---

## 🔍 Policy Coverage Verification

### 16 Policies Tested

**Vault-Level Security (5 policies):**
1. ✅ Soft Delete - enabled by default on all new vaults
2. ✅ Purge Protection - auto-fixed in both modes
3. ✅ RBAC Authorization - DevTest only (Production: manual review)
4. ✅ Firewall Enabled - DevTest only (Production: manual review)
5. ⚠️ Diagnostic Logging - DevTest only (Production: manual review)

**Object-Level Security (6 policies):**
6. ✅ Secret Expiration - tested with secrets without expiration
7. ✅ Key Expiration - tested with keys without expiration
8. ⚠️ Key Type - **Gap:** Need to add non-RSA/EC keys for full coverage
9. ⚠️ RSA Key Size - **Gap:** Need to add RSA-2048 keys (weak)
10. ⚠️ EC Curve Names - **Gap:** Need to add weak curves (secp256k1)
11. ⚠️ Private Link - **Gap:** Not tested (no private endpoints created)

**Certificate Policies (5 policies):**
12. ❌ Certificate Validity - **Gap:** No certificates in test environment
13. ❌ Integrated CA - **Gap:** No certificates in test environment
14. ❌ Non-Integrated CA - **Gap:** No certificates in test environment
15. ❌ Certificate Key Type - **Gap:** No certificates in test environment
16. ❌ Certificate Renewal - **Gap:** No certificates in test environment

### Current Test Environment

**Created Resources:**
- **5 Key Vaults:**
  - 2 compliant (soft delete, purge, RBAC, firewall)
  - 3 non-compliant (legacy access policies, no purge, public access)
  
- **Secrets:** 2 total
  - 1 with 90-day expiration (compliant)
  - 1 without expiration (non-compliant) ✅
  
- **Keys:** 2 total
  - 1 RSA-4096 with expiration (compliant)
  - 1 without expiration (non-compliant) ✅
  
- **Certificates:** 0 ❌ (Gap - certificate policies not tested)

### Gaps to Address

To achieve **full policy coverage**, enhance test environment with:

1. **Weak RSA Keys:**
   ```powershell
   Add-AzKeyVaultKey -VaultName $vault -Name "WeakRSA2048" -KeyType RSA -Size 2048
   ```

2. **Weak EC Keys:**
   ```powershell
   Add-AzKeyVaultKey -VaultName $vault -Name "WeakECKey" -KeyType EC -CurveName secp256k1
   ```

3. **Self-Signed Certificates:**
   ```powershell
   $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=test.local" -IssuerName "Self" -ValidityInMonths 24
   Add-AzKeyVaultCertificate -VaultName $vault -Name "SelfSignedCert" -CertificatePolicy $policy
   ```

4. **Diagnostic Logging:**
   ```powershell
   Set-AzDiagnosticSetting -ResourceId $vaultId -WorkspaceId $workspaceId -Enabled $true
   ```

---

## 📊 Understanding Report Output Files

When you regenerate compliance reports, you'll receive three formats with consistent metadata:

### HTML Report
- **File**: `compliance-report-<workflow-id>.html`
- **Contains**: 
  - Friendly policy names (not GUIDs)
  - Color-coded compliance status
  - Evaluation count explanation in header
  - Footer metadata (script, command, timestamp, mode, workflow ID)

### JSON Report
- **File**: `compliance-report-<workflow-id>.json`
- **Contains**:
  - Machine-readable compliance data
  - Metadata section with generation info
  - Note about evaluation counting methodology
  - Friendly policy name mappings

### CSV Report
- **File**: `compliance-report-<workflow-id>.csv`
- **Contains**:
  - Tabular compliance data (Excel-friendly)
  - Header comments explaining evaluation counts
  - Footer comments with generation metadata
  - Friendly policy names in PolicyName column

**All Three Formats Include:**
- ✅ Friendly policy names
- ✅ Evaluation count explanation
- ✅ Generation metadata (script, command, timestamp, workflow ID, mode)

---

## 🎯 Best Practices from Cybersecurity Perspective

### 1. Use Production Mode for Real Environments
- Manual review ensures stakeholder approval
- Prevents unexpected application downtime
- Allows planning for RBAC migration and firewall configuration

### 2. Use DevTest Mode for Ephemeral Testing Only
- Validates end-to-end remediation flow
- Shows what "100% compliant" looks like
- Safe because resources are deleted after testing

### 3. Wait for Compliance Data Before Making Decisions
- Don't rely on initial "zero evaluations" report
- Use polling helper or wait 15-30 minutes
- Re-run compliance report before executive summaries

### 4. Document Manual Review Items
- Export remediation scripts for custom fixes
- Share with security team for approval
- Track completion in change management system

### 5. Test Certificate Policies Thoroughly
- Certificates have complex renewal and CA integration requirements
- Expiration outages are common security incidents
- Automated testing ensures policies catch misconfigurations

---

## 📝 Quick Command Reference

```powershell
# Run interactive workflow with mode selection
.\scripts\Run-ForegroundWorkflowTest.ps1

# Regenerate compliance report (after 15-30 min wait)
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId <run-id>

# Force Azure Policy re-evaluation
Start-AzPolicyComplianceScan -ResourceGroupName <rg-name>

# Run master workflow directly (production mode)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName <rg> -AutoRemediate

# Run master workflow directly (DevTest mode)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName <rg> -DevTestMode

# Create test environment
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName <rg>

# Reset/cleanup test environment
.\scripts\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName <rg> -RemovePolicyAssignments
```

---

## 🚨 Common Issues & Solutions

### Issue: Compliance report shows zero evaluations
**Cause:** Azure Policy still evaluating (15-30 min delay)  
**Solution:** Wait and re-run `Regenerate-ComplianceReport.ps1`

### Issue: Remediation report shows DevTest mode when I selected Production
**Status:** FIXED in latest version (2026-01-08)  
**Solution:** Update `Run-ForegroundWorkflowTest.ps1` to latest version

### Issue: Manual review count too high in DevTest mode
**Expected:** DevTest mode should have 0-3 manual review items  
**Check:** Ensure remediation script received `-DevTestMode` flag  
**Debug:** Check comprehensive report provenance field

### Issue: Improvement percentage low (< 30%)
**Cause:** Production mode only fixes safe items (soft delete, purge)  
**Expected:** 10-30% improvement in Production mode, 80-100% in DevTest  
**Solution:** Use DevTest mode for testing or manually address flagged items

### Issue: Certificate policies not triggering
**Cause:** No certificates in test environment  
**Solution:** Enhance `Create-PolicyTestEnvironment.ps1` to create test certificates

---

## 📧 Support

For questions or issues:
1. Check `ISSUE_ANALYSIS_20260108.md` for detailed root cause analysis
2. Review `docs/QUICK_START.md` for workflow guidance
3. Check `docs/GAP_ANALYSIS.md` for policy coverage details
4. Open issue in repository with workflow run ID and error details
