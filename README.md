# Azure Key Vault Security Hardening & Policy Testing Framework

## 📋 Overview

Comprehensive PowerShell framework for testing, deploying, and validating Azure Key Vault security policies. This toolkit enables security teams to:

- **Test Azure Policies** against known-good and known-bad Key Vault configurations
- **Deploy 16+ Built-in Azure Policies** for Key Vault security hardening
- **Auto-remediate** common security misconfigurations (Production & DevTest modes)
- **Generate Compliance Reports** with HTML, JSON, and CSV outputs
- **Validate** security posture before/after policy enforcement

### 🎯 Key Features

- ✅ **100% Policy Coverage**: Tests all 16 Azure Key Vault built-in policies
- 🔄 **Two Operation Modes**: Production (safe) and DevTest (aggressive) auto-remediation
- 📊 **Rich Reporting**: HTML dashboards, JSON structured data, CSV exports with footer metadata
- 🛡️ **Security Best Practices**: Enforces Microsoft security baselines
- 🔍 **Granular Compliance Tracking**: Vault-level and resource-level policy evaluation
- 🚀 **Automated Workflows**: One-click baseline → policy → remediation → validation

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  1. Create Baseline Environment                            │
│     ├─ Create-PolicyTestEnvironment.ps1                    │
│     └─ 5 vaults (2 compliant, 3 non-compliant)             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  2. Capture Baseline State                                 │
│     ├─ Document-PolicyEnvironmentState.ps1                 │
│     └─ JSON/HTML baseline reports                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  3. Deploy Azure Policies                                  │
│     ├─ Assign-AuditPolicies.ps1 / Assign-DenyPolicies.ps1  │
│     └─ 16 built-in policies assigned                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  4. Wait for Azure Policy Evaluation (15-30 min)           │
│     └─ Start-AzPolicyComplianceScan (manual trigger)       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  5. Remediate Security Issues                              │
│     ├─ Remediate-ComplianceIssues.ps1                      │
│     ├─ Production Mode: 3 safe auto-fixes                  │
│     └─ DevTest Mode: 13 aggressive auto-fixes              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  6. Capture After-Remediation State                        │
│     ├─ Document-PolicyEnvironmentState.ps1                 │
│     └─ Compare before/after compliance                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  7. Generate Compliance Reports                            │
│     ├─ Regenerate-ComplianceReport.ps1                     │
│     └─ HTML/JSON/CSV compliance data                       │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **PowerShell 7.0+** (recommended)
- **Azure PowerShell Modules**:
  ```powershell
  Install-Module -Name Az.Accounts, Az.KeyVault, Az.Resources, Az.Monitor, Az.OperationalInsights -Force
  ```
- **Azure Subscription** with Contributor or Owner role
- **Authenticated Azure Session**:
  ```powershell
  Connect-AzAccount
  Set-AzContext -SubscriptionId "your-subscription-id"
  ```

### Option 1: Interactive Workflow Test (Recommended for First-Time Users)

```powershell
# Run interactive test workflow with mode selection
.\scripts\Run-ForegroundWorkflowTest.ps1
```

This interactive script will:
1. Prompt you to choose **Production Mode** (ENTER, safe default) or **DevTest Mode**
2. Create test environment with 5 vaults (2 compliant, 3 non-compliant)
3. Deploy 16 Azure policies
4. Wait for Azure Policy compliance scan
5. Remediate security issues (auto-fixes based on selected mode)
6. Capture before/after states
7. Generate 7 HTML reports + JSON/CSV data
8. Prompt for cleanup (optional)

### Option 2: Automated Complete Workflow

```powershell
# Production Mode (Safe auto-remediation only)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-keyvault-test" -AutoRemediate

# DevTest Mode (Aggressive auto-remediation for testing)
.\scripts\Run-CompleteWorkflow.ps1 -ResourceGroupName "rg-keyvault-test" -DevTestMode -AutoRemediate
```

### Option 3: Individual Script Execution

```powershell
# 1. Create test environment
.\scripts\Create-PolicyTestEnvironment.ps1 -SubscriptionId "your-sub" -ResourceGroupName "rg-test"

# 2. Capture baseline state
.\scripts\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-test" -OutputPath "baseline.json"

# 3. Deploy policies (Audit mode)
.\scripts\Assign-AuditPolicies.ps1 -ResourceGroupName "rg-test"

# 4. Trigger manual compliance scan
Start-AzPolicyComplianceScan -ResourceGroupName "rg-test"

# 5. Remediate issues
.\scripts\Remediate-ComplianceIssues.ps1 -ResourceGroupName "rg-test" -AutoRemediate

# 6. Regenerate compliance report
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId "20260108-120000" -ResourceGroupName "rg-test"
```

## 📊 Reports Generated

All reports include **footer metadata**: script name, command, mode, timestamp, workflow ID.

### 1. Baseline Environment State
- **Files**: `baseline-{RunID}.html`, `baseline-{RunID}.json`
- **Content**: Pre-policy vault configurations, security settings, violations
- **Counting Method**: Vault-level (how many vaults have each violation)

### 2. Policy Assignment Report
- **Files**: `policy-assignments-{RunID}.html`, `policy-assignments-{RunID}.json`
- **Content**: 16 policies deployed, auto-fix capability per policy

### 3. Compliance Report
- **Files**: `compliance-report-{RunID}.html`, `compliance-report-{RunID}.json`, `compliance-report-{RunID}.csv`
- **Content**: Azure Policy evaluation results, vault + resource-level compliance
- **Note**: Azure Policy evaluates **each vault AND each resource** (secrets/keys/certs) separately
  - Example: 5 vaults × 3 resources = 15 evaluations per policy

### 4. Remediation Result Report
- **Files**: `remediation-result-{RunID}.html`, `remediation-result-{RunID}.json`
- **Content**: Issues found, auto-fixed count, manual review items, severity breakdown
- **Counting Method**: Individual issue counting (each secret, key, cert, config)

### 5. After-Remediation State
- **Files**: `after-remediation-{RunID}.html`, `after-remediation-{RunID}.json`
- **Content**: Post-remediation vault configurations, remaining violations
- **Comparison**: Shows improvement from baseline state

### 6. Workflow Summary
- **Files**: `summary-{RunID}.html`, `summary-{RunID}.json`
- **Content**: End-to-end workflow metrics, policy deployment, remediation effectiveness

### 7. Artifacts Summary
- **Files**: `artifacts-summary.html`
- **Content**: Links to all generated artifacts with descriptions

## 🔧 Core Scripts Reference

### Create-PolicyTestEnvironment.ps1
**Purpose**: Creates test Key Vaults with known compliant/non-compliant configurations.

**Parameters**:
- `-SubscriptionId`: Azure subscription ID (required)
- `-ResourceGroupName`: Resource group name (default: `rg-policy-keyvault-test`)
- `-Location`: Azure region (default: `eastus`)
- `-EnvironmentPrefix`: Vault name prefix (default: `kv-bl`)
- `-CreateNonCompliant`: Create non-compliant vaults (default: `$true`)

**Creates**:
- 2 compliant vaults (secure, RBAC-enabled)
- 3 non-compliant vaults (legacy, public access, no logging)
- Secrets, keys, certificates for policy testing
- Self-signed certificates (production guidance for real CAs)

### Document-PolicyEnvironmentState.ps1
**Purpose**: Captures snapshot of Key Vault configurations for before/after comparison.

**Parameters**:
- `-ResourceGroupName`: Resource group containing vaults
- `-OutputPath`: JSON output file path
- `-IncludeCompliance`: Include Azure Policy compliance state

**Output**:
- Security settings (soft delete, purge protection, RBAC)
- Network configuration (firewall, private endpoints)
- Vault objects (secrets, keys, certificates) with expiration status
- Policy compliance state (if `-IncludeCompliance`)
- Violation summary and statistics

### Run-CompleteWorkflow.ps1
**Purpose**: Orchestrates end-to-end workflow from baseline to compliance reporting.

**Parameters**:
- `-ResourceGroupName`: Resource group for testing
- `-DevTestMode`: Enables aggressive auto-remediation (13 fixes)
- `-AutoRemediate`: Enables safe auto-remediation (3 fixes)
- `-InvokedBy`: Custom command string for footer metadata

**Workflow Steps**:
1. Capture baseline state → `baseline-{RunID}.html/json`
2. Deploy 16 Azure policies → `policy-assignments-{RunID}.html/json`
3. Wait for compliance scan (15-30 min) → Azure Policy evaluation
4. Generate compliance report → `compliance-report-{RunID}.html/json/csv`
5. Remediate issues → `remediation-result-{RunID}.html/json`
6. Capture after-remediation state → `after-remediation-{RunID}.html/json`
7. Generate summary → `summary-{RunID}.html/json`

### Remediate-ComplianceIssues.ps1
**Purpose**: Scans and fixes Key Vault security misconfigurations.

**Parameters**:
- `-ResourceGroupName`: Resource group to scan
- `-AutoRemediate`: Enable safe auto-fixes (Production Mode)
- `-DevTestMode`: Enable aggressive auto-fixes (DevTest Mode)
- `-ScanOnly`: Preview mode, no changes

**Production Mode (3 safe fixes)**:
- ✅ Enable soft delete
- ✅ Enable purge protection
- ✅ Update weak RSA keys to 2048+ bits

**DevTest Mode (13 aggressive fixes)**:
- All Production Mode fixes, plus:
- ✅ Enable RBAC authorization
- ✅ Configure network firewall
- ✅ Enable diagnostic logging
- ✅ Set secret/key/certificate expiration dates
- ✅ Fix certificate configurations
- ✅ And more...

### Regenerate-ComplianceReport.ps1
**Purpose**: Re-generates compliance report with latest Azure Policy data.

**Parameters**:
- `-WorkflowRunId`: Workflow run ID timestamp (e.g., `20260108-120000`)
- `-ResourceGroupName`: Optional resource group filter

**Use When**:
- Azure Policy evaluation completed after initial workflow run
- Need updated compliance data without re-running full workflow

## 🔑 Understanding Report Counting Methods

This framework uses **two different counting methodologies**, both correct for their purposes:

### Method 1: Vault-Level Counting (Baseline/After-Remediation)
- **Purpose**: Show which vaults have violations
- **Unit**: Vaults with violation type
- **Example**: "5 vaults have MissingExpiration" (even if 20 secrets lack expiration)
- **Used in**: `baseline-*.html`, `after-remediation-*.html`

### Method 2: Individual Issue Counting (Remediation)
- **Purpose**: Show total work items to fix
- **Unit**: Individual secrets, keys, certificates, configs
- **Example**: "20 secrets need expiration dates"
- **Used in**: `remediation-result-*.html`

### Azure Policy Evaluation Counts
- **Purpose**: Show granular compliance per policy
- **Unit**: Each vault AND each resource evaluated separately
- **Example**: 5 vaults × 3 resources = 15 evaluations per policy
- **Used in**: `compliance-report-*.html/json/csv`

## 📂 Directory Structure

```
powershell-akv-securityhardening/
├── README.md                          # This file
├── scripts/                           # Core PowerShell scripts
│   ├── Create-PolicyTestEnvironment.ps1
│   ├── Document-PolicyEnvironmentState.ps1
│   ├── Run-CompleteWorkflow.ps1
│   ├── Run-ForegroundWorkflowTest.ps1  # Interactive test runner
│   ├── Remediate-ComplianceIssues.ps1
│   ├── Regenerate-ComplianceReport.ps1
│   ├── Assign-AuditPolicies.ps1
│   ├── Assign-DenyPolicies.ps1
│   └── ... (utility scripts)
├── artifacts/                         # Generated reports
│   ├── html/                          # HTML dashboards
│   ├── json/                          # Structured JSON data
│   ├── csv/                           # CSV exports
│   └── txt/                           # Plain text logs
└── docs/                              # Documentation
    ├── QUICK_START.md
    ├── IMPLEMENTATION_STATUS.md
    ├── AzurePolicy-KeyVault-TestMatrix.md
    └── ... (additional guides)
```

## 🔐 16 Azure Policies Deployed

| # | Policy Name | Policy ID | Auto-Fix Capability |
|---|-------------|-----------|---------------------|
| 1 | Key Vault Soft Delete | 0b60c0b2-2dc2-4e1c-b5c9-abbed971de53 | ✅ Production + DevTest |
| 2 | Key Vault Purge Protection | a400a00b-2de8-46d3-a5a3-72631a0e0e92 | ✅ Production + DevTest |
| 3 | RBAC Authorization | 12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5 | ✅ DevTest Only |
| 4 | Network Firewall | 55615ac9-af46-4a59-874e-391cc3dfb490 | ✅ DevTest Only |
| 5 | Private Link | a6abeaec-4d90-4a02-805f-6b26c4d3fbe9 | ⚠️ Manual Review |
| 6 | Secrets Expiration | 98728c90-32c7-4049-8429-847dc0f4fe37 | ✅ DevTest Only |
| 7 | Keys Expiration | 152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0 | ✅ DevTest Only |
| 8 | Allowed Key Types | 75c4f823-d65a-4f59-a679-427d20e9ba0d | ⚠️ Manual Review |
| 9 | RSA Key Minimum Size | 82067dbb-e53b-4e06-b631-546d197452d9 | ✅ Production + DevTest |
| 10 | EC Key Minimum Curve | ff25f3c8-b739-4538-9d07-3d6d25cfb255 | ⚠️ Manual Review |
| 11 | Certificate Validity Period | 0aa6d03c-b052-4f49-9992-64c697e7d88b | ⚠️ Manual Review |
| 12 | Certificate Approved CAs | a22f4a40-01d3-4c7d-8071-da157eeff341 | ⚠️ Manual Review |
| 13 | Certificate EC Curve | 11c30ece-f97b-45b9-9e84-1c43c2e88e19 | ⚠️ Manual Review |
| 14 | Certificate Key Type | 1151cede-290b-4ba0-8b38-0ad145ac888f | ⚠️ Manual Review |
| 15 | Certificate Renewal | 12ef42fe-5c3e-4529-a4e4-8d582e2e4c77 | ✅ DevTest Only |
| 16 | Diagnostic Logging | cf820ca0-f99e-4f3e-84fb-66e913812d21 | ✅ DevTest Only |

## 🎓 Learning Resources

- **Quick Start Guide**: `docs/QUICK_START.md` - Get started in 5 minutes
- **Implementation Status**: `docs/IMPLEMENTATION_STATUS.md` - Feature completion tracking
- **Policy Test Matrix**: `docs/AzurePolicy-KeyVault-TestMatrix.md` - Policy coverage details
- **Workflow Documentation**: `docs/WORKFLOW_EXECUTION_SUMMARY.md` - Step-by-step guides

## 🤝 Contributing

Contributions welcome! Please:
1. Follow PowerShell best practices (comment-based help, proper error handling)
2. Update documentation for new features
3. Test changes with both Production and DevTest modes
4. Ensure all JSON/HTML outputs include footer metadata

## 📜 License

MIT License - See LICENSE file for details

## 🐛 Troubleshooting

### "No compliance data available"
- **Cause**: Azure Policy evaluation takes 15-30 minutes after policy assignment
- **Fix**: Wait longer, or trigger manual scan with `Start-AzPolicyComplianceScan`

### "Policy name showing as GUID"
- **Cause**: Policy mapping missing in script
- **Fix**: Update `$policyNameMap` in `Regenerate-ComplianceReport.ps1` or `Run-CompleteWorkflow.ps1`

### "Forbidden by firewall" errors
- **Cause**: Key Vault firewall blocking your IP
- **Fix**: Temporarily add your IP to firewall rules, or use `-DevTestMode` for testing

### "Module not found" errors
- **Cause**: Missing Azure PowerShell modules
- **Fix**: Install required modules:
  ```powershell
  Install-Module -Name Az.Accounts, Az.KeyVault, Az.Resources, Az.Monitor, Az.OperationalInsights
  ```

## 📞 Support

For issues, questions, or feature requests:
- Review `docs/` folder for detailed documentation
- Check `artifacts/json/` for structured output data
- Examine HTML reports for visual troubleshooting

---

**Version**: 2.0.0  
**Last Updated**: 2026-01-08  
**Maintained By**: Azure Security Testing Team
