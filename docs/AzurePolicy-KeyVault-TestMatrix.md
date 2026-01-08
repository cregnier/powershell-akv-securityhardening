# Azure Policy Test Matrix for Key Vault Secrets Management

**Last Updated:** January 8, 2026

**Latest Enhancements (2026-01-08):** All compliance reports now display friendly policy names instead of GUIDs, making it easier to understand policy violations. See [COMPLIANCE_REPORT_ENHANCEMENT.md](COMPLIANCE_REPORT_ENHANCEMENT.md) for details.

---

## Overview

This document provides a comprehensive test matrix for Azure Policy enforcement on Azure Key Vault service, focusing on secrets management aligned with industry compliance frameworks.

**Important Note on Deny Mode Testing**: The Deny mode tests in this framework demonstrate Azure Policy's blocking behavior in a controlled test environment. **Actual deny enforcement across your Azure environment requires assignment of these policies at the subscription or management group level.** Without subscription-level policy assignment, resources can be created outside the test environment without policy enforcement. Use the included remediation scripts (`KeyVault-Remediation-Master.ps1`) to assign policies at the appropriate scope for enterprise-wide enforcement.

## Compliance Frameworks

- **Microsoft Cloud Security Benchmark (MCSB)**
- **CIS Microsoft Azure Foundations Benchmark 2.0.0**
- **CIS Microsoft Azure Foundations Benchmark 1.4.0**
- **CIS Microsoft Azure Foundations Benchmark 1.3.0**
- **CERT Security Guidelines**
- **NIST Cybersecurity Framework**

---

## Test Matrix Categories

### 1. Key Vault Configuration & Security

#### 1.1 Soft Delete Protection

- **Policy Name**: Key vaults should have soft delete enabled
- **Policy ID**: `1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d`
- **Compliance Framework**: CIS 8.5, MCSB DP-8
- **Description**: Prevents permanent data loss by enabling recovery of deleted key vaults
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create Key Vault without soft delete
  - Deny mode: Attempt to create Key Vault without soft delete
  - Compliance: Verify soft delete is enabled on existing vaults

#### 1.2 Deletion Protection (Purge Protection)

- **Policy Name**: Key vaults should have deletion protection enabled
- **Policy ID**: `0b60c0b2-2dc2-4e1c-b5c9-abbed971de53`
- **Compliance Framework**: CIS 8.5, MCSB DP-8
- **Description**: Enforces mandatory retention period for soft-deleted key vaults
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create Key Vault without purge protection
  - Deny mode: Attempt to create Key Vault without purge protection
  - Compliance: Verify purge protection on existing vaults

#### 1.3 Private Link Configuration

- **Policy Name**: Azure Key Vaults should use private link
- **Policy ID**: `a6abeaec-4d90-4a02-805f-6b26c4d3fbe9`
- **Compliance Framework**: MCSB DP-8
- **Description**: Ensures secure private connectivity to Key Vault
- **Effects**: Audit, Disabled
- **Test Scenarios**:
  - Audit mode: Create Key Vault without private endpoint
  - Compliance: Verify private endpoint configuration

#### 1.4 Firewall & Network Access

- **Policy Name**: Azure Key Vault should have firewall enabled or public network access disabled
- **Policy ID**: `55615ac9-af46-4a59-874e-391cc3dfb490`
- **Compliance Framework**: MCSB DP-8
- **Description**: Restricts network access to Key Vault
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create Key Vault with public access enabled
  - Deny mode: Attempt to create Key Vault with unrestricted access
  - Compliance: Verify firewall rules are configured

#### 1.5 RBAC Permission Model

- **Policy Name**: Azure Key Vault should use RBAC permission model
- **Policy ID**: `12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5`
- **Compliance Framework**: CIS 8.6, MCSB PA-7
- **Description**: Enforces role-based access control over vault access policies
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create Key Vault with vault access policy model
  - Deny mode: Attempt to use vault access policy model
  - Compliance: Verify RBAC is enabled

---

### 2. Secrets Management

#### 2.1 Secret Expiration Date

- **Policy Name**: Key Vault secrets should have an expiration date
- **Policy ID**: `98728c90-32c7-4049-8429-847dc0f4fe37`
- **Compliance Framework**: CIS 8.3, CIS 8.4, MCSB DP-6
- **Description**: Ensures secrets have defined lifecycle and expiration
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create secret without expiration date
  - Deny mode: Attempt to create secret without expiration
  - Compliance: Verify all secrets have expiration dates
  - Rotation: Test secret rotation before expiration

---

### 3. Keys Management

#### 3.1 Key Expiration Date

- **Policy Name**: Key Vault keys should have an expiration date
- **Policy ID**: `152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0`
- **Compliance Framework**: MCSB DP-6
- **Description**: Ensures cryptographic keys have defined lifecycle
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create key without expiration date
  - Deny mode: Attempt to create key without expiration
  - Compliance: Verify all keys have expiration dates

#### 3.2 Key Type and Size

- **Policy Name**: Keys should be the specified cryptographic type RSA or EC
- **Policy ID**: `75c4f823-d65c-4f29-a733-01d0077fdbcb`
- **Compliance Framework**: NIST, CERT
- **Description**: Enforces cryptographic standards for key types
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create key with non-compliant type
  - Deny mode: Attempt to create weak key type
  - Compliance: Verify key types meet standards

#### 3.3 Minimum Key Size (RSA)

- **Policy Name**: Keys using RSA cryptography should have a specified minimum key size
- **Policy ID**: `82067dbb-e53b-4e06-b631-546d197452d9`
- **Compliance Framework**: NIST, CERT, MCSB
- **Description**: Enforces minimum 2048-bit RSA keys
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create RSA key smaller than 2048 bits
  - Deny mode: Attempt to create 1024-bit RSA key
  - Compliance: Verify all RSA keys meet minimum size

#### 3.4 Elliptic Curve Names

- **Policy Name**: Keys using elliptic curve cryptography should have the specified curve names
- **Policy ID**: `ff25f3c8-b739-4538-9d07-3d6d25cfb255`
- **Compliance Framework**: NIST, CERT
- **Description**: Enforces approved elliptic curves (P-256, P-384, P-521)
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create EC key with non-approved curve
  - Deny mode: Attempt to use weak elliptic curve
  - Compliance: Verify EC keys use approved curves

---

### 4. Certificates Management

#### 4.1 Certificate Expiration Date

- **Policy Name**: Certificates should have the specified maximum validity period
- **Policy ID**: `0a075868-4c26-42ef-914c-5bc007359560`
- **Compliance Framework**: MCSB DP-7
- **Description**: Limits certificate validity period
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create certificate with excessive validity period
  - Deny mode: Attempt to create long-lived certificate
  - Compliance: Verify certificate validity periods

#### 4.2 Certificate Authority (CA)

- **Policy Name**: Certificates should be issued by the specified integrated certificate authority
- **Policy ID**: `8e826246-c976-48f6-b03e-619bb92b3d82`
- **Compliance Framework**: MCSB DP-7
- **Description**: Enforces use of approved CAs
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create certificate from non-approved CA
  - Deny mode: Attempt to use unapproved CA
  - Compliance: Verify certificates from approved CAs

#### 4.3 Non-Integrated CA Certificates

- **Policy Name**: Certificates should be issued by the specified non-integrated certificate authority
- **Policy ID**: `a22f4a40-01d3-4c7d-8071-da157eeff341`
- **Compliance Framework**: MCSB DP-7
- **Description**: Enforces external CA when not using integrated CA
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create self-signed certificate
  - Deny mode: Block self-signed certificates
  - Compliance: Verify external CA usage

#### 4.4 Certificate Key Type

- **Policy Name**: Certificates should use allowed key types
- **Policy ID**: `1151cede-290b-4ba0-8b38-0ad145ac888f`
- **Compliance Framework**: NIST, CERT
- **Description**: Enforces RSA or EC key types for certificates
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create certificate with non-allowed key type
  - Deny mode: Block non-compliant key types
  - Compliance: Verify certificate key types

#### 4.5 Certificate Renewal (Lifetime Actions)

- **Policy Name**: Certificates should have the specified lifetime action triggers
- **Policy ID**: `12ef42cb-9903-4e39-9c26-422d29570417`
- **Compliance Framework**: MCSB DP-7
- **Description**: Enforces certificate renewal automation
- **Effects**: Audit, Deny, Disabled
- **Test Scenarios**:
  - Audit mode: Create certificate without renewal action
  - Deny mode: Block certificates without auto-renewal
  - Compliance: Verify renewal triggers configured

---

### 5. Logging & Monitoring

#### 5.1 Diagnostic Logging

- **Policy Name**: Resource logs in Key Vault should be enabled
- **Policy ID**: `cf820ca0-f99e-4f3e-84fb-66e913812d21`
- **Compliance Framework**: MCSB LT-3, CIS
- **Description**: Enables audit logging for security investigation
- **Effects**: AuditIfNotExists, Disabled
- **Test Scenarios**:
  - Audit mode: Create Key Vault without diagnostic settings
  - Compliance: Verify diagnostic logging enabled
  - Monitoring: Verify logs are collected in Log Analytics

---

## Test Execution Matrix

| Category | Policy Count | Audit Tests | Deny Tests | Compliance Checks |
|----------|--------------|-------------|------------|-------------------|
| Key Vault Configuration | 5 | 5 | 4 | 5 |
| Secrets Management | 1 | 1 | 1 | 2 |
| Keys Management | 4 | 4 | 4 | 4 |
| Certificates Management | 5 | 5 | 5 | 5 |
| Logging & Monitoring | 1 | 1 | 0 | 1 |
| **TOTAL** | **16** | **16** | **14** | **17** |

---

## Policy Effect Modes

### Audit Mode

- Policy evaluates resources but does not block non-compliant actions
- Non-compliant resources are flagged in Azure Policy compliance dashboard
- Used for assessment and gradual rollout
- **Test Focus**: Verify non-compliant resources are detected

### Deny Mode

- Policy actively blocks non-compliant resource creation/modification
- Returns error message to user attempting non-compliant action
- Used for strict enforcement
- **Test Focus**: Verify non-compliant actions are blocked

### AuditIfNotExists Mode

- Checks if related resource exists (e.g., diagnostic settings)
- Does not block resource creation
- Flags missing related resources as non-compliant
- **Test Focus**: Verify missing configurations are detected

---

## Remediation Strategies

### 1. Soft Delete & Purge Protection

```powershell
# Enable soft delete and purge protection
Update-AzKeyVault -VaultName "vault-name" `
    -EnableSoftDelete `
    -EnablePurgeProtection
```

### 2. Private Link Configuration

```powershell
# Create private endpoint for Key Vault
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "subnet-name" -VirtualNetwork $vnet
$privateEndpoint = New-AzPrivateEndpoint -Name "kv-pe" `
    -ResourceGroupName "rg-name" `
    -Location "location" `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $plsConnection
```

### 3. Enable RBAC Authorization

```powershell
# Update Key Vault to use RBAC
Update-AzKeyVault -VaultName "vault-name" `
    -ResourceGroupName "rg-name" `
    -EnableRbacAuthorization $true
```

### 4. Set Secret Expiration

```powershell
# Set expiration date for secret (90 days from now)
$expires = (Get-Date).AddDays(90).ToUniversalTime()
Set-AzKeyVaultSecret -VaultName "vault-name" `
    -Name "secret-name" `
    -SecretValue $secretValue `
    -Expires $expires
```

### 5. Enable Diagnostic Logging

```powershell
# Enable diagnostic settings
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-name" -Name "workspace-name"
Set-AzDiagnosticSetting -ResourceId $keyVault.ResourceId `
    -Name "kv-diagnostics" `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category "AuditEvent"
```

---

## Compliance Mapping

### Microsoft Cloud Security Benchmark (MCSB)

- **DP-6**: Lifecycle management for secrets and keys
- **DP-7**: Secure certificate management
- **DP-8**: Security of key and certificate repository
- **LT-3**: Enable logging for security investigation
- **PA-7**: Follow least privilege principle

### CIS Azure Foundations Benchmark 2.0.0

- **8.3**: Set expiration date for all secrets in RBAC Key Vaults
- **8.4**: Set expiration date for all secrets in non-RBAC Key Vaults
- **8.5**: Ensure Key Vault is recoverable (soft delete + purge protection)
- **8.6**: Enable RBAC for Azure Key Vault

### CERT/NIST Guidelines

- Use strong cryptographic algorithms (RSA ≥ 2048, approved EC curves)
- Implement key rotation and lifecycle management
- Enable comprehensive audit logging
- Use network isolation and encryption in transit
- Follow least privilege access control

---

## Test Data Requirements

### Test Key Vault Names

- `kv-audit-test-[unique]` - For audit mode testing
- `kv-deny-test-[unique]` - For deny mode testing
- `kv-compliant-[unique]` - For compliant baseline

### Test Secrets

- `secret-no-expiry` - Secret without expiration
- `secret-with-expiry` - Compliant secret with expiration
- `secret-rotate-test` - For rotation testing

### Test Keys

- `key-rsa-1024` - Non-compliant RSA key size
- `key-rsa-2048` - Compliant RSA key
- `key-ec-weak` - Non-approved EC curve
- `key-ec-p256` - Compliant EC key

### Test Certificates

- `cert-self-signed` - Self-signed certificate
- `cert-long-validity` - Certificate with excessive validity
- `cert-compliant` - Fully compliant certificate

---

## Expected Outcomes

### Audit Mode Results

- All non-compliant resources should be detected
- Compliance dashboard should show violations
- No operations should be blocked
- Detailed compliance report generated

### Deny Mode Results

- Non-compliant operations should be blocked
- Error messages should be clear and actionable
- Compliant operations should succeed
- Event logs should record denied attempts

### Compliance Remediation

- Scripts should successfully remediate violations
- Re-evaluation should show improved compliance
- Remediation should not impact availability

---

## Documentation References

- [Azure Policy for Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/azure-policy)
- [Key Vault Security Controls](https://learn.microsoft.com/en-us/azure/key-vault/security-controls-policy)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)
- [Microsoft Cloud Security Benchmark](https://learn.microsoft.com/en-us/security/benchmark/azure/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
