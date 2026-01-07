# Azure Key Vault Secrets & Identity Management Guidance

**Document Version:** 1.0  
**Last Updated:** 2026-01-06  
**Audience:** Security teams, DevOps engineers, application developers

---

## Executive Summary

This document provides comprehensive guidance for managing secrets, keys, and certificates in Azure Key Vault, aligned with the 16 Azure Policy tests validated in this framework. It covers authentication methods, access control models, encryption standards, lifecycle management, and operational best practices.

**Key Recommendations:**
- ✅ Use **Managed Identities** for Azure resource authentication (eliminates credential management)
- ✅ Adopt **RBAC authorization model** for granular, auditable access control
- ✅ Enable **soft delete and purge protection** on all Key Vaults (prevents permanent data loss)
- ✅ Set **expiration dates** on all secrets, keys, and certificates
- ✅ Use **Azure Key Vault Premium** with HSM-backed keys for cryptographic operations
- ✅ Enable **diagnostic logging** to Azure Monitor for audit trails
- ✅ Implement **network restrictions** (private endpoints or firewall rules)

---

## 1. Authentication & Identity: Managed Identities vs Service Principals

### 1.1 Managed Identities (Recommended)

**What are Managed Identities?**
- Azure-managed service principals that eliminate the need to store credentials
- Automatically rotated by Azure (no manual credential rotation required)
- Two types: **System-assigned** (tied to resource lifecycle) and **User-assigned** (independent lifecycle)

**When to use:**
- ✅ Azure-hosted applications (App Service, Functions, VMs, Container Apps, AKS)
- ✅ CI/CD pipelines using Azure DevOps or GitHub Actions with federated credentials
- ✅ Data services accessing Key Vault (Azure SQL, Cosmos DB, Storage)

**Benefits:**
- No credentials in code or configuration files
- Automatic credential rotation
- Reduced attack surface
- Simplified compliance (no shared secrets to audit)

**Example: Azure Function with Managed Identity**
```csharp
// DefaultAzureCredential automatically uses Managed Identity in Azure
var credential = new DefaultAzureCredential();
var client = new SecretClient(new Uri("https://myvault.vault.azure.net/"), credential);
var secret = await client.GetSecretAsync("DatabasePassword");
```

**Example: Assigning RBAC permissions**
```powershell
# Grant Managed Identity access to Key Vault
$appIdentity = (Get-AzWebApp -ResourceGroupName "myRG" -Name "myApp").Identity.PrincipalId
New-AzRoleAssignment -ObjectId $appIdentity `
    -RoleDefinitionName "Key Vault Secrets User" `
    -Scope "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault-name}"
```

### 1.2 Service Principals (When Managed Identities Aren't Available)

**When to use:**
- Applications running outside Azure (on-premises, other clouds)
- Legacy applications that can't use DefaultAzureCredential
- Third-party integrations requiring explicit credentials

**Security requirements:**
- ✅ Store credentials in Azure Key Vault (not in code or config files)
- ✅ Rotate credentials every 90 days maximum
- ✅ Use certificate-based authentication (more secure than client secrets)
- ✅ Apply least privilege permissions
- ✅ Enable conditional access policies

**Example: Service Principal with certificate**
```powershell
# Create service principal with certificate
$cert = New-SelfSignedCertificate -Subject "CN=MyApp" -CertStoreLocation "Cert:\CurrentUser\My"
$certValue = [Convert]::ToBase64String($cert.GetRawCertData())
New-AzADServicePrincipal -DisplayName "MyApp" -CertValue $certValue
```

### 1.3 Comparison Matrix

| Feature | Managed Identity | Service Principal |
|---------|------------------|-------------------|
| **Credential storage** | Not required | Required (Key Vault recommended) |
| **Credential rotation** | Automatic | Manual |
| **Where it works** | Azure resources only | Anywhere |
| **Setup complexity** | Low | Medium |
| **Security posture** | High | Medium (depends on storage) |
| **Compliance audit** | Simple | Complex |
| **Recommendation** | ✅ **Preferred** | Use only when MI unavailable |

---

## 2. Access Control: RBAC vs Access Policies

### 2.1 RBAC Authorization Model (Recommended)

**Azure Policy Validated:** `Azure Key Vault should use RBAC permission model`

**Why RBAC?**
- **Centralized management:** Consistent with Azure resource access control
- **Granular permissions:** 15+ built-in roles (Key Vault Reader, Secrets User, Crypto User, etc.)
- **Auditable:** All access logged in Azure Activity Log
- **Scalable:** Supports Azure AD groups, conditional access, PIM
- **Policy enforcement:** Can be enforced via Azure Policy (Audit/Deny modes)

**Built-in RBAC Roles:**

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Key Vault Administrator** | Full management + data access | Break-glass admin accounts |
| **Key Vault Secrets Officer** | Manage secrets (create, read, delete) | Secret rotation automation |
| **Key Vault Secrets User** | Read secrets only | Application runtime access |
| **Key Vault Crypto Officer** | Manage keys | Key rotation, crypto operations |
| **Key Vault Crypto User** | Use keys (encrypt, decrypt, sign) | Application encryption |
| **Key Vault Certificates Officer** | Manage certificates | Certificate lifecycle automation |
| **Key Vault Reader** | Read metadata (not secret values) | Auditing, inventory |

**Example: Assign RBAC role**
```powershell
# Grant application read-only access to secrets
New-AzRoleAssignment `
    -ObjectId $appPrincipalId `
    -RoleDefinitionName "Key Vault Secrets User" `
    -Scope "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault}"
```

**Migration from Access Policies to RBAC:**
```powershell
# Enable RBAC authorization on existing vault
Update-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault" -EnableRbacAuthorization $true

# Query existing access policies before migration
$vault = Get-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault"
$vault.AccessPolicies | Select-Object DisplayName, Permissions
```

### 2.2 Access Policies (Legacy, Limited Use Cases)

**When to still use Access Policies:**
- Legacy applications incompatible with RBAC
- Temporary exemption during RBAC migration
- Specific scenarios requiring fine-grained permission combinations not covered by RBAC roles

**Security considerations:**
- ⚠️ All-or-nothing permissions (e.g., "Get" allows reading ALL secrets)
- ⚠️ No support for conditional access
- ⚠️ Difficult to audit at scale
- ⚠️ Not enforceable via Azure Policy

**Recommendation:** Plan migration to RBAC within 6-12 months

---

## 3. Cryptographic Standards & HSM

### 3.1 Key Types & Minimum Sizes

**Azure Policies Validated:**
- `Keys should be the specified cryptographic type RSA or EC`
- `Keys using RSA cryptography should have a specified minimum key size`
- `Keys using elliptic curve cryptography should have the specified curve names`

**Recommended Standards:**

| Key Type | Minimum Size/Curve | Use Case | HSM Support |
|----------|-------------------|----------|-------------|
| **RSA** | 2048-bit (3072/4096 preferred) | General encryption, signing | ✅ Yes |
| **EC (Elliptic Curve)** | P-256, P-384, P-521 | Performance-sensitive encryption | ✅ Yes |
| **AES** | 256-bit | Symmetric encryption | ✅ Yes (Premium only) |

**Compliance Mapping:**
- **NIST SP 800-57:** RSA 2048+ for near-term, 3072+ for long-term protection
- **FIPS 140-3:** Requires HSM-backed keys for Level 3 compliance
- **PCI DSS 4.0:** Minimum RSA 2048-bit or ECC equivalent

### 3.2 Azure Key Vault Premium (HSM-Backed Keys)

**When to use Premium SKU:**
- ✅ Regulatory compliance requiring FIPS 140-3 Level 3 HSMs
- ✅ High-value cryptographic operations (payment processing, PHI, PII)
- ✅ Certificate authority operations
- ✅ Key wrapping for customer-managed encryption keys (CMK)

**Benefits:**
- **Hardware security:** Keys stored in FIPS 140-3 Level 3 validated HSMs
- **Enhanced security:** Keys never leave HSM boundary
- **Compliance:** Meets PCI DSS, HIPAA, FedRAMP High requirements

**Cost consideration:** Premium ~$1.25/vault/month vs Standard ~$0.025/vault/month

**Example: Create HSM-backed key**
```powershell
Add-AzKeyVaultKey -VaultName "myVault" -Name "PaymentKey" `
    -KeyType RSA-HSM -Size 3072 -KeyOps encrypt,decrypt,sign,verify
```

### 3.3 Approved Elliptic Curve Names

**Validated by Policy:** `Keys using elliptic curve cryptography should have the specified curve names`

**Approved curves:**
- ✅ **P-256** (secp256r1): Most widely supported, good performance
- ✅ **P-384** (secp384r1): Higher security margin, moderate performance
- ✅ **P-521** (secp521r1): Maximum security, lower performance
- ✅ **P-256K** (secp256k1): Bitcoin/blockchain compatibility

**NOT approved:**
- ❌ Weak curves (P-192, P-224)
- ❌ Non-standard or proprietary curves

---

## 4. Secret, Key, and Certificate Lifecycle Management

### 4.1 Expiration Requirements

**Azure Policies Validated:**
- `Key Vault secrets should have an expiration date`
- `Key Vault keys should have an expiration date`
- `Certificates should have the specified maximum validity period`

**Why expiration matters:**
- Limits exposure window if credential is compromised
- Forces regular rotation (defense-in-depth)
- Compliance requirement (PCI DSS, CIS, MCSB)

**Recommended Expiration Periods:**

| Asset Type | Maximum Validity | Rotation Frequency | Rationale |
|------------|------------------|-------------------|-----------|
| **Secrets (passwords, API keys)** | 90 days | Every 60-90 days | High-risk, easily compromised |
| **Keys (encryption, signing)** | 2 years | Annually | Balance security and operational overhead |
| **Certificates (TLS, code signing)** | 13 months | 12 months | Industry standard (Apple, Google requirements) |
| **Root CA certificates** | 10 years | Not rotated | Long-term trust anchor |

**Example: Create secret with expiration**
```powershell
$expires = (Get-Date).AddDays(90)
Set-AzKeyVaultSecret -VaultName "myVault" -Name "ApiKey" `
    -SecretValue (ConvertTo-SecureString "value" -AsPlainText -Force) `
    -Expires $expires `
    -ContentType "application/text"
```

### 4.2 Automated Rotation Strategies

**Option 1: Azure Key Vault Rotation (Native)**
- Configure rotation policy in Key Vault
- Supports secrets, certificates, storage account keys
- No code changes required

**Example: Configure secret rotation**
```powershell
$policy = @{
    rotationPolicy = @{
        lifetimeActions = @(
            @{
                trigger = @{ timeBeforeExpiry = "P30D" }
                action = @{ type = "Rotate" }
            }
        )
        attributes = @{ expiryTime = "P90D" }
    }
}
Set-AzKeyVaultSecretRotationPolicy -VaultName "myVault" -Name "ApiKey" -Policy $policy
```

**Option 2: Azure Functions (Custom Logic)**
- Timer-triggered function checks expiration dates
- Calls external APIs to generate new credentials
- Updates Key Vault with new values

**Example: Rotation function pseudocode**
```csharp
[FunctionName("RotateApiKey")]
public async Task Run([TimerTrigger("0 0 2 * * *")] TimerInfo timer)
{
    var secrets = await kvClient.GetSecretsAsync();
    foreach (var secret in secrets.Where(s => s.Properties.ExpiresOn < DateTime.UtcNow.AddDays(30)))
    {
        // Call external API to generate new key
        var newKey = await externalApi.GenerateNewKey(secret.Name);
        
        // Update Key Vault
        await kvClient.SetSecretAsync(secret.Name, newKey, new SecretProperties { ExpiresOn = DateTime.UtcNow.AddDays(90) });
        
        // Notify operations team
        await notificationService.SendAlert($"Rotated {secret.Name}");
    }
}
```

**Option 3: Event Grid + Logic Apps**
- Monitor Key Vault events (near-expiration)
- Trigger rotation workflow
- Update dependent services automatically

### 4.3 Certificate Lifecycle Policies

**Azure Policies Validated:**
- `Certificates should have the specified maximum validity period` (≤13 months)
- `Certificates should have the specified lifetime action triggers`
- `Certificates should be issued by the specified integrated certificate authority`

**Integrated CA Support:**
- DigiCert (recommended for public-facing services)
- GlobalSign

**Auto-renewal configuration:**
```powershell
$policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=www.contoso.com" `
    -IssuerName "DigiCert" `
    -ValidityInMonths 12 `
    -RenewAtPercentageLifetime 80 `
    -EmailAtPercentageLifetime 90 `
    -KeyType RSA -KeySize 2048 `
    -ContentType "application/x-pkcs12"

Add-AzKeyVaultCertificate -VaultName "myVault" -Name "TlsCert" -CertificatePolicy $policy
```

---

## 5. Data Protection & Recovery

### 5.1 Soft Delete (Required)

**Azure Policy Validated:** `Key vaults should have soft delete enabled`

**What is soft delete?**
- Deleted secrets/keys/certificates retained for 90 days (configurable 7-90 days)
- Prevents accidental or malicious permanent deletion
- Can be recovered during retention period

**Compliance requirement:** CIS 8.5, MCSB DP-8

**Enable soft delete:**
```powershell
# New vault (soft delete enabled by default)
New-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault" -Location "eastus"

# Existing vault (if not already enabled)
Update-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault" -EnableSoftDelete $true
```

**Recovery example:**
```powershell
# List deleted secrets
Get-AzKeyVaultSecret -VaultName "myVault" -InRemovedState

# Recover deleted secret
Undo-AzKeyVaultSecretRemoval -VaultName "myVault" -Name "DatabasePassword"
```

### 5.2 Purge Protection (Strongly Recommended)

**Azure Policy Validated:** `Key vaults should have deletion protection enabled`

**What is purge protection?**
- Enforces mandatory retention period for deleted items
- Prevents immediate purge (even by administrators)
- **Irreversible once enabled**

**When to enable:**
- ✅ Production Key Vaults
- ✅ Vaults storing encryption keys for data at rest
- ✅ Compliance requirements (PCI DSS, HIPAA)

**⚠️ Important:** Cannot be disabled after enabling

```powershell
# Enable purge protection (irreversible)
Update-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault" `
    -EnableSoftDelete $true -EnablePurgeProtection $true
```

---

## 6. Network Security

### 6.1 Private Link (Recommended for Production)

**Azure Policy Validated:** `Azure Key Vaults should use private link`

**Benefits:**
- Eliminates public internet exposure
- Traffic stays within Azure backbone network
- Supports hybrid connectivity (ExpressRoute, VPN)
- Required for zero-trust architecture

**Setup:**
```powershell
# Create private endpoint
$privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName "myRG" `
    -Name "kvPrivateEndpoint" -Location "eastus" `
    -Subnet $subnet `
    -PrivateLinkServiceConnection (New-AzPrivateLinkServiceConnection `
        -Name "kvConnection" `
        -PrivateLinkServiceId $keyVault.ResourceId `
        -GroupId "vault")

# Configure private DNS zone
New-AzPrivateDnsZone -ResourceGroupName "myRG" -Name "privatelink.vaultcore.azure.net"
```

### 6.2 Firewall Rules (Alternative or Additional)

**Azure Policy Validated:** `Azure Key Vault should have firewall enabled or public network access disabled`

**When to use:**
- Public access required (not ideal, but sometimes necessary)
- Allowlist known IP ranges
- Supplement private link for defense-in-depth

**Configuration:**
```powershell
# Enable firewall and default deny
Update-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault" `
    -DefaultAction Deny

# Add IP allowlist
Add-AzKeyVaultNetworkRule -VaultName "myVault" -IpAddressRange "203.0.113.0/24"

# Allow trusted Azure services (Azure DevOps, Azure Functions, etc.)
Update-AzKeyVault -ResourceGroupName "myRG" -VaultName "myVault" `
    -NetworkRuleSet @{Bypass="AzureServices"; DefaultAction="Deny"}
```

---

## 7. Auditing & Monitoring

### 7.1 Diagnostic Logging (Required)

**Azure Policy Validated:** `Resource logs in Key Vault should be enabled`

**Why logging matters:**
- **Security incidents:** Detect unauthorized access attempts
- **Compliance:** PCI DSS, HIPAA, SOC 2 require audit trails
- **Forensics:** Investigate data breaches
- **Operational insights:** Track secret/key usage patterns

**Compliance mapping:**
- **MCSB LT-3:** Enable logging for security investigation
- **CIS:** Log all administrative and data access operations
- **NIST SP 800-171:** Audit record retention and analysis

**Setup diagnostic settings:**
```powershell
$workspaceId = (Get-AzOperationalInsightsWorkspace -ResourceGroupName "myRG" -Name "myWorkspace").ResourceId

Set-AzDiagnosticSetting -ResourceId $keyVault.ResourceId -Name "AuditLogs" `
    -WorkspaceId $workspaceId `
    -Enabled $true `
    -Category AuditEvent, AllMetrics
```

### 7.2 Key Events to Monitor

**Critical events:**
- ✅ Secret/key accessed (especially by new identities)
- ✅ Secret/key created, updated, deleted
- ✅ Access policy or RBAC changes
- ✅ Failed authentication attempts
- ✅ Vault configuration changes (firewall, soft delete)

**Example: Azure Monitor alert for unauthorized access**
```kql
AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "SecretGet"
| where httpStatusCode_d == 403
| summarize count() by identity_claim_appid_g, bin(TimeGenerated, 5m)
| where count_ > 5
```

### 7.3 Retention Policies

**Recommended retention:**
- **Audit logs:** 90 days minimum (1 year for compliance)
- **Metrics:** 30 days
- **Archive:** 7 years for regulated industries (PCI DSS, HIPAA)

---

## 8. CI/CD Pipeline Integration

### 8.1 GitHub Actions (Recommended)

**Use Federated Credentials (no secrets in GitHub!):**
```yaml
name: Deploy Application
on: [push]
permissions:
  id-token: write  # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login (Federated)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Get Secret from Key Vault
        id: kvsecret
        run: |
          SECRET=$(az keyvault secret show --vault-name myVault --name DbPassword --query value -o tsv)
          echo "::add-mask::$SECRET"
          echo "secret=$SECRET" >> $GITHUB_OUTPUT
      
      - name: Use Secret (masked in logs)
        run: |
          echo "Deploying with connection string..."
          # Use ${{ steps.kvsecret.outputs.secret }}
```

### 8.2 Azure DevOps Pipelines

**Use Azure Key Vault task:**
```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzureKeyVault@2
  inputs:
    azureSubscription: 'MyServiceConnection'
    KeyVaultName: 'myVault'
    SecretsFilter: 'DatabasePassword,ApiKey'
    RunAsPreJob: true

- script: |
    echo "Password is: $(DatabasePassword)"  # Auto-masked by Azure DevOps
  displayName: 'Deploy Application'
```

### 8.3 Security Best Practices for CI/CD

**Do:**
- ✅ Use federated credentials (GitHub) or service connections (Azure DevOps)
- ✅ Grant pipelines minimum necessary Key Vault permissions (Secrets User)
- ✅ Mask secrets in logs automatically
- ✅ Rotate service principal credentials every 90 days
- ✅ Use separate Key Vaults for dev/staging/prod

**Don't:**
- ❌ Store Key Vault credentials as GitHub secrets
- ❌ Echo secrets to console logs
- ❌ Commit secrets to repositories (use .gitignore, git-secrets)
- ❌ Share Key Vaults across environments

---

## 9. Application Development Guidance

### 9.1 SDK Best Practices

**Use DefaultAzureCredential (supports multiple auth methods):**
```csharp
// .NET example
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var credential = new DefaultAzureCredential(); // Auto-selects best auth method
var client = new SecretClient(new Uri("https://myvault.vault.azure.net/"), credential);

try
{
    KeyVaultSecret secret = await client.GetSecretAsync("DatabasePassword");
    // Use secret.Value
}
catch (RequestFailedException ex) when (ex.Status == 404)
{
    // Handle missing secret
}
```

**Authentication chain priority:**
1. Environment variables (local dev)
2. Managed Identity (Azure resources)
3. Azure CLI (local dev)
4. Visual Studio (local dev)
5. Azure PowerShell (local dev)

### 9.2 Caching & Performance

**Problem:** Key Vault has rate limits (2000 requests/10s for Standard SKU)

**Solution:** Implement client-side caching
```csharp
private static readonly MemoryCache _cache = new MemoryCache(new MemoryCacheOptions());

public async Task<string> GetSecretCachedAsync(string secretName)
{
    if (_cache.TryGetValue(secretName, out string cachedValue))
        return cachedValue;

    var secret = await _kvClient.GetSecretAsync(secretName);
    var cacheOptions = new MemoryCacheEntryOptions()
        .SetAbsoluteExpiration(TimeSpan.FromMinutes(15)); // Refresh every 15 min
    
    _cache.Set(secretName, secret.Value, cacheOptions);
    return secret.Value;
}
```

**Recommendation:** Cache for 5-15 minutes for frequently accessed secrets

### 9.3 Connection String Management

**❌ Bad: Hardcoded connection string**
```json
{
  "ConnectionStrings": {
    "Database": "Server=myserver;Database=mydb;User=admin;Password=P@ssw0rd123;"
  }
}
```

**✅ Good: Key Vault reference**
```json
{
  "ConnectionStrings": {
    "Database": "@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/DbConnectionString/)"
  }
}
```

**✅ Better: Managed Identity + Azure SQL**
```csharp
var connectionString = "Server=myserver.database.windows.net;Database=mydb;Authentication=Active Directory Managed Identity;";
```

---

## 10. Compliance Checklists

### 10.1 Pre-Production Checklist

Before deploying a Key Vault to production:

- [ ] Soft delete enabled (90-day retention)
- [ ] Purge protection enabled (irreversible)
- [ ] RBAC authorization model enabled
- [ ] Private endpoint configured (or firewall rules)
- [ ] Diagnostic logging to Log Analytics workspace
- [ ] All secrets/keys have expiration dates
- [ ] Expiration < 90 days for secrets, < 2 years for keys
- [ ] Certificates auto-renew at 80% lifetime
- [ ] Premium SKU for HSM-backed keys (if required)
- [ ] Resource locks applied (prevent accidental deletion)
- [ ] Azure Policy assignments validated (Audit mode first)
- [ ] Backup/DR plan documented
- [ ] Access reviewed (least privilege)

### 10.2 PCI DSS 4.0 Compliance

**Requirement 3.5.x: Key Management**
- [ ] Keys stored in HSM (Premium SKU)
- [ ] Key rotation every 2 years maximum
- [ ] Split knowledge/dual control for key generation (separate RBAC roles)
- [ ] Cryptographic architecture documented
- [ ] Key backup and recovery procedures tested

**Requirement 3.6.x: Key Lifecycle**
- [ ] Secure key generation (Azure-managed)
- [ ] Secure key distribution (private endpoints)
- [ ] Secure key storage (FIPS 140-3 Level 3)
- [ ] Periodic key changes (automated rotation)
- [ ] Retirement and replacement procedures
- [ ] Destruction of old keys (soft delete + purge after retention)
- [ ] Key compromise response plan

### 10.3 CIS Azure Benchmark

**CIS 8.3:** Secrets expiration
- [ ] All secrets have expiration ≤ 90 days
- [ ] Automated rotation configured

**CIS 8.4:** Keys expiration
- [ ] All keys have expiration ≤ 730 days (2 years)

**CIS 8.5:** Soft delete and purge protection
- [ ] Soft delete enabled on all vaults
- [ ] Purge protection enabled on production vaults

**CIS 8.6:** RBAC authorization
- [ ] Access policies migrated to RBAC
- [ ] Least privilege roles assigned

---

## 11. Disaster Recovery & Business Continuity

### 11.1 Multi-Region Strategy

**Key Vault is regionally resilient but not geo-redundant by default**

**Option 1: Secondary Key Vault (Manual Failover)**
```powershell
# Primary region
$primaryVault = New-AzKeyVault -ResourceGroupName "primary-rg" -VaultName "kv-primary" -Location "eastus"

# Secondary region (disaster recovery)
$secondaryVault = New-AzKeyVault -ResourceGroupName "dr-rg" -VaultName "kv-secondary" -Location "westus"

# Sync secrets (scheduled task or Azure Automation)
$secrets = Get-AzKeyVaultSecret -VaultName "kv-primary"
foreach ($secret in $secrets) {
    $value = Get-AzKeyVaultSecret -VaultName "kv-primary" -Name $secret.Name -AsPlainText
    Set-AzKeyVaultSecret -VaultName "kv-secondary" -Name $secret.Name -SecretValue (ConvertTo-SecureString $value -AsPlainText -Force)
}
```

**Option 2: Application-level failover**
- Configure app to try primary vault, fallback to secondary
- Use Traffic Manager or Front Door for automatic DNS failover

### 11.2 Backup & Recovery

**Backup secrets (not keys/certificates):**
```powershell
# Backup secret
Backup-AzKeyVaultSecret -VaultName "myVault" -Name "DatabasePassword" -OutputFile "C:\backup\secret.blob"

# Restore to another vault
Restore-AzKeyVaultSecret -VaultName "recoveryVault" -InputFile "C:\backup\secret.blob"
```

**⚠️ Limitation:** Cannot backup HSM keys (use key export for Premium vaults)

---

## 12. Common Anti-Patterns to Avoid

### ❌ Anti-Pattern #1: Storing secrets in code
```csharp
// NEVER DO THIS
string apiKey = "abc123xyz";
```

### ❌ Anti-Pattern #2: Using access policies at scale
- Difficult to audit
- No conditional access support
- Migrate to RBAC

### ❌ Anti-Pattern #3: No expiration dates
- Violates CIS 8.3, 8.4
- Compliance violations
- Security risk

### ❌ Anti-Pattern #4: Sharing Key Vaults across environments
- Dev/staging/prod should have separate vaults
- Prevents accidental production access from non-prod

### ❌ Anti-Pattern #5: Public network access without firewall
- Exposes vault to internet attacks
- Enable private link or firewall

### ❌ Anti-Pattern #6: Ignoring soft delete
- Risk of permanent data loss
- Cannot recover deleted secrets

### ❌ Anti-Pattern #7: Service principal secrets in config files
- Use managed identities instead
- If unavoidable, store SP secret in Key Vault

---

## 13. Resources & References

### Official Documentation
- [Azure Key Vault Overview](https://learn.microsoft.com/azure/key-vault/)
- [Managed Identities](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [RBAC for Key Vault](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)
- [Key Vault Security](https://learn.microsoft.com/azure/key-vault/general/security-features)

### Compliance & Standards
- [Microsoft Cloud Security Benchmark](https://learn.microsoft.com/security/benchmark/azure/)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)
- [PCI DSS 4.0](https://www.pcisecuritystandards.org/)
- [NIST SP 800-171](https://csrc.nist.gov/publications/detail/sp/800-171/rev-2/final)

### Tools & Scripts
- [Azure Policy Tests](../Test-AzurePolicyKeyVault.ps1) (this repository)
- [Remediation Scripts](../reports/remediation-scripts/)
- [Azure Key Vault SDK Samples](https://github.com/Azure/azure-sdk-for-net/tree/main/sdk/keyvault)

---

## Appendix A: Quick Reference Commands

```powershell
# Create Key Vault (production-ready)
New-AzKeyVault -ResourceGroupName "prod-rg" -VaultName "kv-prod" -Location "eastus" `
    -EnableSoftDelete $true -EnablePurgeProtection $true `
    -EnableRbacAuthorization $true -Sku Premium

# Add secret with expiration
Set-AzKeyVaultSecret -VaultName "kv-prod" -Name "ApiKey" `
    -SecretValue (ConvertTo-SecureString "value" -AsPlainText -Force) `
    -Expires (Get-Date).AddDays(90)

# Grant RBAC access
New-AzRoleAssignment -ObjectId $principalId `
    -RoleDefinitionName "Key Vault Secrets User" `
    -Scope "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault}"

# Enable diagnostic logging
Set-AzDiagnosticSetting -ResourceId $vaultId -Name "AuditLogs" `
    -WorkspaceId $workspaceId -Enabled $true -Category AuditEvent

# Configure firewall
Update-AzKeyVault -VaultName "kv-prod" -DefaultAction Deny
Add-AzKeyVaultNetworkRule -VaultName "kv-prod" -IpAddressRange "203.0.113.0/24"
```

---

**Document End**
