# Azure Policy Key Vault Testing Framework

## Overview

This comprehensive testing framework validates Azure Policy enforcement for Azure Key Vault service, covering secrets, keys, and certificates management aligned with industry compliance frameworks including Microsoft Cloud Security Benchmark, CIS Azure Foundations Benchmark, CERT, and NIST guidelines.

## Features

✅ **Comprehensive Policy Testing**: Tests 16 Azure Policy definitions for Key Vault  
✅ **Dual-Mode Testing**: Supports both Audit and Deny policy modes  
✅ **Interactive Test Selection**: Choose specific tests or categories to run  
✅ **Resource Tracking & Reuse**: Track created resources and reuse them across runs  
✅ **Compliance Alignment**: Maps to CIS, MCSB, PCI DSS 4.0, CERT, ISO 27001, and NIST frameworks  
✅ **Automated Artifact Creation**: Creates necessary Azure resources for testing  
✅ **HTML Reporting**: Generates detailed compliance reports with remediation guidance  
✅ **MSA Authentication**: Uses locally logged-in credentials  
✅ **Resource Cleanup Options**: Automated cleanup or resource preservation  

## Prerequisites

### Required Software

- **PowerShell**: Version 7.0 or higher
- **Azure PowerShell Module**: Az 11.0 or higher

### Required Modules

```powershell
Install-Module -Name Az.Accounts -Force -AllowClobber
Install-Module -Name Az.KeyVault -Force -AllowClobber
Install-Module -Name Az.Resources -Force -AllowClobber
Install-Module -Name Az.PolicyInsights -Force -AllowClobber
Install-Module -Name Az.Monitor -Force -AllowClobber
Install-Module -Name Az.OperationalInsights -Force -AllowClobber
```

### Azure Permissions Required

- **Subscription Contributor** or higher
- **User Access Administrator** (for RBAC assignments)
- **Policy Contributor** (for policy compliance evaluation)

### Azure Subscription Requirements

- Active Azure subscription
- Sufficient quota for Key Vaults (recommended: 10+ vaults)
- Sufficient quota for Log Analytics workspaces (1 workspace)

## Important Limitations

### Deny Mode Enforcement Scope

**The Deny mode tests in this framework demonstrate Azure Policy blocking behavior in a controlled test environment only.**

**Critical Note**: Actual deny enforcement across your entire Azure environment requires policy assignment at the **subscription or management group level**. The test framework does NOT automatically assign policies at the subscription level for safety reasons.

**What This Means**:
- ✅ Deny mode tests: Resources in the test resource group are blocked by policies applied during testing
- ❌ Outside test scope: Resources created in other resource groups will NOT be blocked unless policies are assigned at subscription level
- ⚠️ **To enable organization-wide deny enforcement**: Use the included `KeyVault-Remediation-Master.ps1` script with the `Assign-AllEnforcePolicies` function to assign deny policies at subscription level

**Production Deployment**: After validating policy behavior with this testing framework, use the master remediation script to deploy policies at the appropriate scope for your organization.

## Quick Start

### Complete Workflow Guide

See [QUICK_START.md](QUICK_START.md) for detailed copy-paste commands and workflow instructions.

### 1. Clone or Download Files

Download the following files to your local machine:

- `Test-AzurePolicyKeyVault.ps1` - Main testing script
- `AzurePolicy-KeyVault-TestMatrix.md` - Test matrix documentation

### 2. Authenticate to Azure

```powershell
# Connect to Azure using your Microsoft Account
Connect-AzAccount

# Verify connection
Get-AzContext

# (Optional) Set specific subscription
Set-AzContext -SubscriptionId "your-subscription-id"
```

### 3. Create Test Environment

```powershell
# Create test Key Vaults with intentional violations
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-keyvault-test"
```

### 4. Run Complete Workflow

```powershell
# Automated workflow (recommended)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-policy-keyvault-test"

# OR step-by-step manual workflow (see QUICK_START.md)
```

### 5. Review Results

The script will:

1. Create a resource group for testing
2. Deploy test Key Vaults with various configurations
3. Execute policy compliance tests
4. Generate HTML + JSON reports for each step
5. Create comprehensive final report combining all steps

---

## 📁 Complete File Inventory

### 📂 Root Directory

| File | Type | Purpose |
|------|------|---------|
| `inventory-before.json` | Data | Pre-reorganization file count |
| `inventory-after.json` | Data | Post-reorganization file count (verification) |

### 📂 docs/ - Documentation

| File | Lines | Purpose |
|------|-------|---------|
| `README.md` | 750+ | Main project documentation and overview |
| `QUICK_START.md` | 650+ | Fast-track commands and workflow guide |
| `SCENARIO_VERIFICATION.md` | 800+ | Complete scenario coverage validation |
| `secrets-guidance.md` | 835 | Azure Key Vault best practices guide |
| `AzurePolicy-KeyVault-TestMatrix.md` | 200+ | All 16 policies detailed specification |
| `GAP_ANALYSIS.md` | 124 | Missing tests and recommendations |
| `IMPLEMENTATION_STATUS.md` | - | Project implementation tracking |
| `IMPLEMENTATION_SUMMARY.md` | - | High-level implementation summary |
| `PROJECT_COMPLETION_SUMMARY.md` | - | Project completion documentation |
| `WORKFLOW_ENHANCEMENTS.md` | 400+ | Artifact enhancement documentation |
| `WORKFLOW_EXECUTION_SUMMARY.md` | - | Workflow execution tracking |
| `todos.md` | - | Project task tracking |

### 📂 scripts/ - PowerShell Scripts

All PowerShell scripts consolidated in one location for easy access.

#### Core Workflow Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| `Run-CompleteWorkflow.ps1` | 600+ | **Master orchestration script** - Runs complete 8-step workflow with all artifacts |
| `Create-PolicyTestEnvironment.ps1` | 440 | **Environment setup** - Creates compliant/non-compliant Key Vaults for testing |
| `Document-PolicyEnvironmentState.ps1` | 286 | **Baseline capture** - Documents current vault state (JSON + HTML) |
| `Generate-ComprehensiveReport.ps1` | 500+ | **Final report** - Combines all workflow steps into comprehensive HTML + JSON |
| `Reset-PolicyTestEnvironment.ps1` | 300+ | **Cleanup utility** - Deletes vaults, policies, artifacts for fresh start |

#### Test and Analysis Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| `Test-AzurePolicyKeyVault.ps1` | 4625 | **Main test suite** - Comprehensive policy testing (Audit/Deny modes) |
| `Test-AzurePolicyKeyVault-v2.ps1` | - | Alternative version of test suite |
| `KeyVault-Remediation-Master.ps1` | - | **Production remediation** - Fixes compliance issues, deploys policies |

#### Remediation Scripts (Production Deployment)

| Script | Purpose |
|--------|---------|
| `Assign-AuditPolicies.ps1` | Deploy all 16 policies in Audit mode (monitoring only) |
| `Assign-DenyPolicies.ps1` | Deploy all 16 policies in Deny mode (enforcement) |
| `Remediate-ComplianceIssues.ps1` | Automatically fix compliance violations |

#### Utility Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| `parse-fails.ps1` | 20 | Extracts failed tests from HTML reports |
| `map-policy-ids.ps1` | 123 | Maps policy IDs to display names |
| `gen-cert.ps1` | 15 | Generates self-signed root certificate for testing |
| `another.ps1` | 18 | Generates P2S VPN child certificate |
| `AiCostCalculator.ps1` | 441 | Forecasts AI service costs based on usage |

### 📂 artifacts/ - Generated Outputs

#### artifacts/json/ - Structured Data

| File Pattern | Example | Purpose |
|--------------|---------|---------|
| `baseline-*.json` | `baseline-20260106-124251.json` | Baseline environment state with vault configurations |
| `after-remediation-*.json` | `after-remediation-20260106-124718.json` | Post-remediation environment state |
| `Workflow-Comprehensive-*.json` | `Workflow-Comprehensive-Report-20260106-144500.json` | All workflow steps consolidated |
| Various workflow JSONs | - | Policy assignments, compliance, remediation data |

#### artifacts/html/ - Visual Reports

| File Pattern | Example | Purpose |
|--------------|---------|---------|
| `AzurePolicy-KeyVault-TestReport-*.html` | `AzurePolicy-KeyVault-TestReport-20260106-093951.html` | Policy test results with styling |
| `Workflow-Comprehensive-*.html` | `Workflow-Comprehensive-Report-20260106-144500.html` | **FINAL REPORT** - All steps with charts and comparisons |
| Various workflow HTMLs | - | Step-by-step visual reports |

#### artifacts/csv/ - Data Exports

| File Pattern | Example | Purpose |
|--------------|---------|---------|
| `compliance-report-*.csv` | `compliance-report-20260106-124520.csv` | Exportable compliance data for analysis |
| `assignment-coverage.csv` | - | Policy assignment coverage analysis |
| `deny-triage.csv` | - | Deny mode test triage data |
| `test-mode-mapping.csv` | - | Test mode configuration mapping |

#### artifacts/txt/ - Test Logs

| File Pattern | Purpose |
|--------------|---------|
| `test-run-*.txt` | Test execution logs and outputs |
| `failed-tests.txt` | Extracted failed test list |
| `remediation-preview.txt` | Remediation preview output |

#### artifacts/html/archive/ - Historical Reports

Multiple timestamped HTML reports archived for historical comparison.

### 📂 Root Directory

| File | Type | Purpose |
|------|------|---------|
| `inventory-before.json` | Data | Initial pre-reorganization file count |
| `inventory-after.json` | Data | Post-reorganization file count (verification) |
| `detailed-inventory-before-reorg.csv` | Data | Complete file listing before final reorganization |

**Note:** The `reports/` folder structure has been reorganized. All remediation scripts moved to `scripts/`, documentation to `docs/`, and artifacts to `artifacts/`.

### 📂 .history/ - VS Code Local History

PowerShell script version history (managed by VS Code extension).

---

## 🔄 Typical Workflow File Flow

### Initial Setup
```
1. Create-PolicyTestEnvironment.ps1
   └─> Creates: 10 Key Vaults in Azure

2. Document-PolicyEnvironmentState.ps1
   └─> Creates: baseline-{timestamp}.json
   └─> Creates: baseline-{timestamp}.html
```

### Complete Automated Workflow
```
Run-CompleteWorkflow.ps1
├─> Step 1: baseline-{timestamp}.json + .html
├─> Step 2: policy-assignments-{timestamp}.json + .html
├─> Step 3: [Wait for Azure Policy scan]
├─> Step 4: compliance-report-{timestamp}.json + .html + .csv
├─> Step 5: remediation-preview-{timestamp}.json + .html
├─> Step 6: remediation-results-{timestamp}.json + .html
├─> Step 7: after-remediation-{timestamp}.json + .html
└─> Step 8: Workflow-Comprehensive-Report-{timestamp}.json + .html ⭐
```

### Cleanup and Reset
```
Reset-PolicyTestEnvironment.ps1
├─> Deletes: All Key Vaults in resource group
├─> Removes: Azure Policy assignments
├─> Cleans: All JSON/HTML/CSV artifacts
└─> Resets: resource-tracking.json
```

---

## 🎯 File Naming Conventions

All artifacts follow consistent naming: `{type}-{timestamp}.{format}`

**Timestamp Format:** `yyyyMMdd-HHmmss` (e.g., `20260106-143022`)

**Examples:**
- `baseline-20260106-143022.json`
- `compliance-report-20260106-143530.html`
- `Workflow-Comprehensive-Report-20260106-144500.html`

**Benefits:**
- ✓ Chronological sorting
- ✓ Easy to find latest (`Sort-Object LastWriteTime -Descending | Select-Object -First 1`)
- ✓ Compare multiple runs side-by-side
- ✓ Archive historical data without conflicts

---

## Quick Start
5. Automatically open the report in your browser

## Usage Examples

### Test Audit Mode Only

```powershell
.\Test-AzurePolicyKeyVault.ps1 `
    -Location "eastus" `
    -TestMode "Audit" `
    -ResourceGroupName "rg-policy-test"
```

### Test Deny Mode Only

```powershell
.\Test-AzurePolicyKeyVault.ps1 `
    -Location "westus2" `
    -TestMode "Deny" `
    -ResourceGroupName "rg-policy-deny-test"
```

### Test with Auto-Cleanup

```powershell
.\Test-AzurePolicyKeyVault.ps1 `
    -Location "eastus" `
    -TestMode "Both" `
    -CleanupAfterTest $true
```

### Test Specific Subscription

```powershell
.\Test-AzurePolicyKeyVault.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -Location "centralus" `
    -ResourceGroupName "rg-custom-test"
```

### Interactive Test Selection

```powershell
# Choose specific tests to run interactively
.\Test-AzurePolicyKeyVault.ps1 `
    -Location "eastus" `
    -InteractiveTestSelection
```

### Resource Reuse and Tracking

```powershell
# First run - creates resources and saves tracking info
.\Test-AzurePolicyKeyVault.ps1 `
    -Location "eastus" `
    -ReuseResources

# Subsequent run - offers options to reuse or cleanup existing resources
.\Test-AzurePolicyKeyVault.ps1 `
    -Location "eastus" `
    -ReuseResources
```

### Combined Advanced Usage

```powershell
# Interactive test selection with resource reuse
.\Test-AzurePolicyKeyVault.ps1 `
    -SubscriptionId "your-sub-id" `
    -Location "eastus" `
    -TestMode "Audit" `
    -ReuseResources `
    -InteractiveTestSelection
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `SubscriptionId` | String | No | Current context | Azure subscription ID for testing |
| `Location` | String | No | eastus | Azure region for resource deployment |
| `ResourceGroupName` | String | No | rg-policy-keyvault-test | Name of the test resource group |
| `TestMode` | String | No | Both | Test mode: Audit, Deny, or Both |
| `CleanupAfterTest` | Boolean | No | false | Whether to cleanup resources after testing |
| `ReuseResources` | Switch | No | Not set | Enable resource tracking and reuse options |
| `InteractiveTestSelection` | Switch | No | Not set | Show interactive menu to select tests |

## Test Categories

### 1. Key Vault Configuration (4 tests)

- ✅ Soft Delete Protection
- ✅ Purge Protection
- ✅ Firewall & Network Access
- ✅ RBAC Authorization Model

### 2. Secrets Management (1 test)

- ✅ Secret Expiration Date

### 3. Keys Management (4 tests)

- ✅ Key Expiration Date
- ✅ Key Type and Size
- ✅ Minimum RSA Key Size
- ✅ Elliptic Curve Names

### 4. Certificates Management (4 tests)

- ✅ Certificate Validity Period
- ✅ Integrated Certificate Authority
- ✅ Certificate Key Type
- ✅ Certificate Renewal Actions

### 5. Logging & Monitoring (1 test)

- ✅ Diagnostic Logging

## Interactive Test Selection

When using the `-InteractiveTestSelection` parameter, you'll be presented with a menu to choose which tests to run:

**Selection Options:**

- Type `all` to run all 14 tests
- Type specific test numbers separated by commas (e.g., `1,2,5,7`)
- Type category numbers to run all tests in a category:
  - Category 1: KeyVault Configuration (tests 1-5)
  - Category 2: Secrets Management (test 6)
  - Category 3: Keys Management (tests 7-10)
  - Category 4: Certificates Management (tests 11-15)
  - Category 5: Logging & Monitoring (test 16)
- Type category numbers to run all tests in a category:
  - Category 1: KeyVault Configuration (tests 1-4)
  - Category 2: Secrets Management (test 5)
  - Category 3: Keys Management (tests 6-9)
  - Category 4: Certificates Management (tests 10-13)
  - Category 5: Logging & Monitoring (test 14)

**Example:**

```
Select tests to run: 1,2,5,6
# Runs: Soft Delete, Purge Protection, Secret Expiration, Key Expiration

Select tests to run: 3
# Runs: All Keys Management tests (tests 6-9)

Select tests to run: all
# Runs: All available tests
```

## Resource Tracking and Reuse

The framework now tracks all created resources in a JSON file (`resource-tracking.json`) and allows you to reuse or clean them up on subsequent runs.

**How it works:**

1. **First Run with `-ReuseResources`**: Creates resources and saves tracking information
2. **Subsequent Runs**: Prompts you with three options:
   - **Clean up and start fresh**: Deletes all previous resources and creates new ones
   - **Reuse existing resources**: Continues with existing Key Vaults and resource group
   - **Cancel**: Exits without changes

**Benefits:**

- **Cost Savings**: Reuse existing Key Vaults instead of creating new ones
- **Time Savings**: Skip resource creation when testing specific scenarios
- **Clean Environment**: Easily clean up all test resources between runs
- **Audit Trail**: JSON file tracks what was created, when, and where

**Tracking File Location:**

- File: `resource-tracking.json` (same directory as script)
- Contains: Subscription, resource group, location, all created resources with timestamps

## Test Categories

### 1. Key Vault Configuration (5 tests)

- ✅ Soft Delete Protection
- ✅ Purge Protection
- ✅ RBAC Authorization Model
- ✅ Firewall & Network Access
- ✅ Private Link Configuration

### 2. Secrets Management (1 test)

- ✅ Secret Expiration Date

### 3. Keys Management (4 tests)

- ✅ Key Expiration Date
- ✅ Key Type and Size
- ✅ Minimum RSA Key Size
- ✅ Elliptic Curve Names

### 4. Certificates Management (5 tests)

- ✅ Certificate Validity Period
- ✅ Integrated Certificate Authority
- ✅ Non-Integrated CA Certificates
- ✅ Certificate Key Type
- ✅ Certificate Renewal Actions

### 5. Logging & Monitoring (1 test)

- ✅ Diagnostic Logging

## Compliance Frameworks
- ✅ Firewall & Network Access
- ✅ Private Link Configuration

### 2. Secrets Management (1 test)

- ✅ Secret Expiration Date

### 3. Keys Management (4 tests)

- ✅ Key Expiration Date
- ✅ Key Type and Size
- ✅ Minimum RSA Key Size
- ✅ Elliptic Curve Names

### 4. Certificates Management (5 tests)

- ✅ Certificate Validity Period
- ✅ Integrated Certificate Authority
- ✅ Non-Integrated CA Certificates
- ✅ Certificate Key Type
- ✅ Certificate Renewal Actions

### 5. Logging & Monitoring (1 test)

- ✅ Diagnostic Logging

## Compliance Frameworks

### Microsoft Cloud Security Benchmark (MCSB)

- **DP-6**: Lifecycle management for secrets and keys
- **DP-7**: Secure certificate management
- **DP-8**: Security of key and certificate repository
- **LT-3**: Enable logging for security investigation
- **PA-7**: Follow least privilege principle

### CIS Azure Foundations Benchmark 2.0.0

- **8.3**: Set expiration date for all secrets in RBAC Key Vaults
- **8.4**: Set expiration date for all secrets in non-RBAC Key Vaults
- **8.5**: Ensure Key Vault is recoverable
- **8.6**: Enable RBAC for Azure Key Vault

### PCI DSS 4.0.1 Requirements

The framework aligns with Payment Card Industry Data Security Standard 4.0.1:

- **Requirement 3.5**: Protect keys used to secure stored cardholder data
  - 3.5.1: Maintain documented cryptographic architecture
  - 3.5.2: Restrict access to cryptographic keys (least privilege)
  - 3.5.3: Store keys in HSM or secure encrypted form
- **Requirement 3.6**: Implement key-management processes
  - 3.6.1: Strong key generation (RSA 2048+, approved curves)
  - 3.6.2: Secure key distribution
  - 3.6.3: Secure key storage (Azure Key Vault Premium with HSM)
  - 3.6.4: Key rotation and cryptoperiod management
  - 3.6.5-3.6.8: Key compromise response and substitution prevention

**Azure Key Vault Premium** provides:

- FIPS 140-3 Level 3 validated HSMs (Marvell LiquidSecurity)
- PCI-compliant cryptographic key storage
- Automated key rotation capabilities
- Comprehensive audit logging

### NIST SP 800-171 R2 Controls

- **3.13.11**: Employ cryptographic mechanisms to protect confidentiality
- **3.13.16**: Protect confidentiality of CUI at rest
- **3.3.1**: Create and retain system audit records
- **3.3.2**: Ensure audit records contain sufficient information

### ISO 27001:2013 Controls

- **A.9.1**: Business requirements for access control
- **A.10.1**: Cryptographic controls
- **A.12.3**: Information backup and recovery
- **A.12.4**: Logging and monitoring

### CERT Secure Coding Guidelines

- Strong cryptographic algorithms (RSA ≥ 2048 bits)
- Approved elliptic curves (P-256, P-384, P-521)
- Key rotation and lifecycle management
- Comprehensive audit logging
- Network isolation and encryption
- Hardware security module usage for sensitive keys

## Compliance Frameworks (Summary)

## Latest Test Report

- **Report HTML:** [AzurePolicy-KeyVault-TestReport-20260105-124607.html](AzurePolicy-KeyVault-TestReport-20260105-124607.html)
- **Artifacts folder:** [reports/](reports/)
- **Summary:** 16 policies evaluated, 39 test executions — Passed: 25; Failed: 14; Success Rate: 64.1%; Duration: ~32.9 minutes.

See `reports/` for remediation templates, per-vault scripts, and `remediation-preview.txt` containing WHATIF outputs.

### Microsoft Cloud Security Benchmark (MCSB)

- **DP-6**: Lifecycle management for secrets and keys
- **DP-7**: Secure certificate management
- **DP-8**: Security of key and certificate repository
- **LT-3**: Enable logging for security investigation
- **PA-7**: Follow least privilege principle

### CIS Azure Foundations Benchmark 2.0.0

- **8.3**: Set expiration date for all secrets in RBAC Key Vaults
- **8.4**: Set expiration date for all secrets in non-RBAC Key Vaults
- **8.5**: Ensure Key Vault is recoverable
- **8.6**: Enable RBAC for Azure Key Vault

### CERT/NIST Guidelines

- Strong cryptographic algorithms (RSA ≥ 2048 bits)
- Approved elliptic curves (P-256, P-384, P-521)
- Key rotation and lifecycle management
- Comprehensive audit logging
- Network isolation and encryption

## HTML Report Contents

The generated HTML report includes:

1. **Executive Summary**
   - Total tests executed
   - Pass/Fail/Error counts
   - Success rate percentage
   - Test duration

2. **Test Environment Details**
   - Subscription information
   - Resource group and location
   - Test mode and execution time
   - User account

3. **Compliance Framework Mapping**
   - All applicable frameworks
   - Framework-specific requirements

4. **Detailed Test Results**
   - Categorized by test type
   - Policy names and IDs
   - Test mode (Audit/Deny)
   - Pass/Fail status
   - Error messages (if any)
   - Remediation scripts

5. **Created Resources List**
   - All Azure resources created
   - Resource IDs and locations
   - Creation timestamps

6. **Recommendations**
   - Immediate action items
   - Policy deployment strategy
   - Compliance alignment guidance

## Understanding Test Results

### Pass ✅

- **Audit Mode**: Non-compliant resource was created and detected by policy
- **Deny Mode**: Non-compliant resource creation was blocked by policy

### Fail ❌

- **Audit Mode**: Resource was not properly flagged as non-compliant
- **Deny Mode**: Non-compliant resource was created despite policy

### Error ⚠️

- Unexpected error occurred during test execution
- Check error message for details

## Remediation Scripts

Each test result includes PowerShell remediation scripts. Examples:

### Enable Soft Delete

```powershell
Update-AzKeyVault -VaultName "vault-name" -EnableSoftDelete
```

### Enable Purge Protection

```powershell
Update-AzKeyVault -VaultName "vault-name" -EnablePurgeProtection
```

### Enable RBAC Authorization

```powershell
Update-AzKeyVault -VaultName "vault-name" `
    -ResourceGroupName "rg-name" `
    -EnableRbacAuthorization $true
```

### Set Secret Expiration

```powershell
$expires = (Get-Date).AddDays(90)
Set-AzKeyVaultSecret -VaultName "vault-name" `
    -Name "secret-name" `
    -SecretValue $secretValue `
    -Expires $expires
```

### Enable Diagnostic Logging

```powershell
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-name" -Name "workspace-name"
Set-AzDiagnosticSetting -ResourceId $keyVaultResourceId `
    -Name "kv-diagnostics" `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category "AuditEvent"
```

## Resource Cleanup

### Manual Cleanup

```powershell
# Remove the test resource group
Remove-AzResourceGroup -Name "rg-policy-keyvault-test" -Force
```

### Automatic Cleanup

```powershell
# Run with cleanup enabled
.\Test-AzurePolicyKeyVault.ps1 -CleanupAfterTest $true
```

**Note**: Cleanup runs as a background job and may take several minutes to complete.

## Policy Deployment Strategy

### Phase 1: Assessment (Week 1-2)

1. Deploy all policies in **Audit mode** at subscription level
2. Run this testing framework to validate detection
3. Review compliance dashboard in Azure Portal
4. Identify all non-compliant resources

### Phase 2: Remediation (Week 3-4)

1. Use remediation scripts from test reports
2. Update non-compliant Key Vaults
3. Set expiration dates for secrets/keys/certificates
4. Enable diagnostic logging

### Phase 3: Enforcement (Week 5-6)

1. Transition critical policies to **Deny mode**:
   - Soft delete and purge protection
   - Secret expiration dates
   - RBAC authorization
2. Monitor for policy violations
3. Adjust policies based on feedback

### Phase 4: Continuous Monitoring

1. Schedule weekly compliance scans
2. Review policy compliance dashboard
3. Update policies as new requirements emerge
4. Re-run testing framework quarterly

## Troubleshooting

### Issue: "Authentication failed"

**Solution**: Ensure you're logged into Azure

```powershell
Connect-AzAccount
Get-AzContext
```

### Issue: "Insufficient permissions"

**Solution**: Verify you have Contributor role on subscription

```powershell
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id
```

### Issue: "Key Vault name already exists"

**Solution**: The script uses unique IDs. If this occurs, delete the existing vault or wait 90 days for soft-delete purge.

### Issue: "Policy compliance not detected"

**Solution**: Policy evaluation can take time. Wait 5-10 minutes and re-check compliance state:

```powershell
Start-AzPolicyComplianceScan -AsJob
```

### Issue: "Quota exceeded"

**Solution**: Check your subscription quotas

```powershell
Get-AzVMUsage -Location "eastus" | Where-Object {$_.Name.Value -like "*vault*"}
```

## Best Practices

### Before Running Tests

1. ✅ Review test matrix documentation
2. ✅ Ensure sufficient Azure quotas
3. ✅ Use a non-production subscription for initial testing
4. ✅ Verify authentication and permissions
5. ✅ Choose appropriate Azure region

### During Testing

1. ✅ Monitor Azure Portal for resource creation
2. ✅ Review PowerShell output for warnings/errors
3. ✅ Keep test execution window open
4. ✅ Document any unexpected behaviors

### After Testing

1. ✅ Review HTML report thoroughly
2. ✅ Save report for compliance documentation
3. ✅ Execute remediation scripts on non-compliant resources
4. ✅ Schedule resource cleanup if not using -CleanupAfterTest
5. ✅ Share results with security and compliance teams

## Integration with CI/CD

### Azure DevOps Pipeline Example

```yaml
trigger:
  - main

pool:
  vmImage: 'windows-latest'

steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'Azure Subscription Connection'
    ScriptType: 'FilePath'
    ScriptPath: '$(System.DefaultWorkingDirectory)/Test-AzurePolicyKeyVault.ps1'
    ScriptArguments: '-Location "eastus" -TestMode "Both" -CleanupAfterTest $true'
    azurePowerShellVersion: 'LatestVersion'

- task: PublishHtmlReport@1
  inputs:
    reportDir: '$(System.DefaultWorkingDirectory)/*.html'
```

### GitHub Actions Example

```yaml
name: Azure Policy Testing

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
  workflow_dispatch:

jobs:
  test-azure-policy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Run Policy Tests
        shell: pwsh
        run: |
          ./Test-AzurePolicyKeyVault.ps1 -Location "eastus" -CleanupAfterTest $true
      
      - name: Upload Report
        uses: actions/upload-artifact@v3
        with:
          name: policy-test-report
          path: '*.html'
```

## Cost Considerations

### Estimated Costs (USD per test run)

- Key Vaults (10 vaults × $0.03/month): ~$0.01
- Log Analytics Workspace: ~$2.30/month (pro-rated)
- Storage (diagnostic logs): < $0.01

**Total estimated cost per test**: < $0.05

**Note**: Costs are minimal as resources are typically deleted after testing. Use -CleanupAfterTest to minimize costs.

## Support and Contribution

### Report Issues

- GitHub Issues: [Create issue](https://github.com/your-repo/issues)
- Email support: <azure-policy-testing@example.com>

### Documentation References

- [Azure Policy for Key Vault](https://learn.microsoft.com/azure/key-vault/general/azure-policy)
- [Key Vault Security Controls](https://learn.microsoft.com/azure/key-vault/security-controls-policy)
- [CIS Azure Benchmark](https://www.cisecurity.org/benchmark/azure)
- [Microsoft Cloud Security Benchmark](https://learn.microsoft.com/security/benchmark/azure/)

## Version History

### v1.0.0 (2026-01-02)

- ✅ Initial release
- ✅ Support for 17 policy definitions
- ✅ Audit and Deny mode testing
- ✅ HTML report generation
- ✅ Compliance framework mapping
- ✅ Automated resource cleanup

## License

This testing framework is provided as-is for educational and testing purposes. Ensure compliance with your organization's security and governance policies before use.

---

**Important**: Always test in a non-production environment first. This framework creates Azure resources that may incur costs. Review and understand all policies before implementing in production environments.
