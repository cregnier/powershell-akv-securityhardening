# Policy Test Environment Scripts

This directory contains scripts for creating and documenting baseline environments for Azure Key Vault policy testing.

## Scripts Overview

### 1. Create-PolicyTestEnvironment.ps1
Creates a baseline pre/post policy environment with both compliant and non-compliant Key Vaults.

**Purpose:**
- Demonstrate policy behavior (Audit mode flags violations, Deny mode blocks creation)
- Test remediation scripts on known non-compliant resources
- Validate compliance scanning and reporting
- Show before/after state when applying policies

**Usage:**
```powershell
# Create full environment (compliant + non-compliant vaults)
.\Create-PolicyTestEnvironment.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-policy-baseline"

# Create only compliant vaults
.\Create-PolicyTestEnvironment.ps1 -CreateNonCompliant $false

# Custom prefix and location
.\Create-PolicyTestEnvironment.ps1 -EnvironmentPrefix "demo" -Location "westus2"
```

**What it creates:**

**Compliant Vaults (2):**
- `kv-baseline-secure-{suffix}`: Full security configuration
  - ✓ Soft delete enabled
  - ✓ Purge protection enabled
  - ✓ RBAC authorization
  - ✓ Public access disabled
  - ✓ Secrets/keys with 90-day expiration

- `kv-baseline-rbac-{suffix}`: RBAC with firewall
  - ✓ Soft delete enabled
  - ✓ Purge protection enabled
  - ✓ RBAC authorization
  - ✓ Firewall configured (allow current IP)

**Non-Compliant Vaults (3):**
- `kv-baseline-legacy-{suffix}`: Legacy access policies
  - ✗ Uses access policies (no RBAC)
  - ✗ No purge protection
  - ✗ Secrets without expiration

- `kv-baseline-public-{suffix}`: Public access + weak keys
  - ✗ Public network access enabled
  - ✗ No purge protection
  - ✗ No expiration on secrets/keys

- `kv-baseline-nolog-{suffix}`: Missing diagnostic logging
  - ✗ No diagnostic logging configured
  - ✗ No purge protection

### 2. Document-PolicyEnvironmentState.ps1
Captures a snapshot of Key Vault configurations for before/after comparison.

**Purpose:**
- Document baseline state before applying policies
- Compare state after remediation
- Generate compliance reports
- Track policy enforcement impact

**Usage:**
```powershell
# Document current state
.\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline"

# Include Azure Policy compliance data
.\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline" -IncludeCompliance

# Custom output path
.\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline" -OutputPath "before-remediation.json"
```

**Output includes:**
- Security settings (soft delete, purge protection, RBAC)
- Network configuration (firewall, private endpoints)
- Vault objects (secrets, keys, certificates) with expiration status
- Policy compliance state (if -IncludeCompliance specified)
- Violation summary and statistics

### 3. map-policy-ids.ps1
Maps policy names to GUIDs and creates policy reference documentation.

**Usage:**
```powershell
.\map-policy-ids.ps1
```

### 4. parse-fails.ps1
Parses test run logs to extract failed test information.

**Usage:**
```powershell
.\parse-fails.ps1
```

## Typical Workflow

### Phase 1: Create Baseline Environment
```powershell
# Step 1: Create environment with both compliant and non-compliant vaults
.\scripts\Create-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-baseline"

# Step 2: Document initial state
.\scripts\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline" -OutputPath "state-before.json"
```

### Phase 2: Test Audit Mode
```powershell
# Step 3: Run test harness in Audit mode
.\Test-AzurePolicyKeyVault.ps1 -TestMode Audit -ResourceGroupName "rg-policy-baseline"

# Step 4: Review HTML report for detected violations
# Report will show non-compliant vaults flagged by policies
```

### Phase 3: Remediate Issues
```powershell
# Step 5: Run compliance remediation script
.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 `
    -SubscriptionId "your-sub-id" `
    -ScanOnly

# Step 6: Apply fixes (with confirmation)
.\reports\remediation-scripts\Remediate-ComplianceIssues.ps1 `
    -SubscriptionId "your-sub-id" `
    -AutoRemediate `
    -ExportCustomScript "custom-remediation.ps1"
```

### Phase 4: Verify Improvements
```powershell
# Step 7: Document post-remediation state
.\scripts\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline" -OutputPath "state-after.json"

# Step 8: Compare before/after states
$before = Get-Content "state-before.json" | ConvertFrom-Json
$after = Get-Content "state-after.json" | ConvertFrom-Json

Write-Host "Before: $($before.Summary.NonCompliantVaults) non-compliant"
Write-Host "After: $($after.Summary.NonCompliantVaults) non-compliant"
```

### Phase 5: Deploy Deny Mode (Optional)
```powershell
# Step 9: Assign policies in Deny mode at subscription level
.\reports\remediation-scripts\Assign-DenyPolicies.ps1 `
    -SubscriptionId "your-sub-id" `
    -ConfirmEnforcement

# Step 10: Test that non-compliant operations are blocked
.\Test-AzurePolicyKeyVault.ps1 -TestMode Deny -ResourceGroupName "rg-policy-test"
```

## Best Practices

1. **Start with Audit Mode**
   - Always begin with Audit mode to understand current compliance state
   - Review violations before applying deny enforcement

2. **Document State Changes**
   - Capture before/after snapshots for audit trails
   - Compare compliance improvements over time

3. **Test Remediation Safely**
   - Use `-ScanOnly` first to preview changes
   - Review exported scripts before applying bulk fixes

4. **Gradual Enforcement**
   - Phase 1-2 weeks: Audit mode + remediation
   - Phase 3-4 weeks: Staged deny enforcement (dev/test first)
   - Phase 5+: Production enforcement with monitoring

5. **Resource Cleanup**
   - Test environments can be deleted after validation
   - Use `-WhatIf` on cleanup commands to preview deletions

## Cleanup

To remove the baseline environment:

```powershell
# Remove all vaults in resource group
Get-AzKeyVault -ResourceGroupName "rg-policy-baseline" | ForEach-Object {
    Remove-AzKeyVault -VaultName $_.VaultName -Force
}

# Remove resource group (after vault soft-delete period)
Remove-AzResourceGroup -Name "rg-policy-baseline" -Force
```

## Support

For questions or issues:
- Review test harness documentation: `README.md`
- Check remediation scripts: `reports/remediation-scripts/README.md`
- Review secrets guidance: `docs/secrets-guidance.md`
