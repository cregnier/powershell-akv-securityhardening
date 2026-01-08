# Azure Key Vault Policy Gap - Implementation Plan
**Created:** January 8, 2026  
**Status:** Planning Phase  
**Goal:** Expand coverage from 16 to 36 policies (excluding preview & Managed HSM)

---

## Executive Summary

**Total Azure Key Vault Policies:** 46  
**Currently Implemented:** 16  
**To Be Implemented:** 20 (non-preview, non-Managed HSM)  
**Deferred:** 10 (preview + Managed HSM policies)

---

## Currently Implemented Policies (16)

### Key Vault Configuration
1. ✅ Key vaults should have soft delete enabled (`1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d`)
2. ✅ Key vaults should have deletion protection enabled (`0b60c0b2-2dc2-4e1c-b5c9-abbed971de53`)
3. ✅ Azure Key Vault should use RBAC permission model (`12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5`)
4. ✅ Azure Key Vault should have firewall enabled (`55615ac9-af46-4a59-874e-391cc3dfb490`)
5. ✅ Azure Key Vaults should use private link (`a6abeaec-4d90-4a02-805f-6b26c4d3fbe9`)
6. ✅ Resource logs in Key Vault should be enabled (`cf820ca0-f99e-4f3e-84fb-66e913812d21`)

### Secrets Management
7. ✅ Key Vault secrets should have an expiration date (`98728c90-32c7-4049-8429-847dc0f4fe37`)

### Keys Management
8. ✅ Key Vault keys should have an expiration date (`152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0`)
9. ✅ Keys should be the specified cryptographic type RSA or EC (`75c4f823-d65c-4f29-a733-01d0077fdbcb`)
10. ✅ Keys using RSA cryptography should have a specified minimum key size (`82067dbb-e53b-4e06-b631-546d197452d9`)
11. ✅ Keys using elliptic curve cryptography should have the specified curve names (`ff25f3c8-b739-4538-9d07-3d6d25cfb255`)

### Certificates Management
12. ✅ Certificates should be issued by the specified integrated certificate authority (`8e826246-c976-48f6-b03e-619bb92b3d82`)
13. ✅ Certificates should be issued by the specified non-integrated certificate authority (`a22f4a40-01d3-4c7d-8071-da157eeff341`)
14. ✅ Certificates should use allowed key types (`1151cede-290b-4ba0-8b38-0ad145ac888f`)
15. ✅ Certificates using RSA cryptography should have the specified minimum key size (`bd78111f-4953-4367-9fd3-50c8b81e5e51`)
16. ✅ Certificates using elliptic curve cryptography should have allowed curve names (`9f0a4d80-0fb3-4fa3-8f68-4b18f8e8eca3`)

---

## Policies To Be Implemented (20)

### Phase 1: Certificate Lifecycle & Advanced Policies (5 policies)
**Priority:** HIGH  
**Estimated Effort:** 3-4 hours

1. **Certificates should have the specified maximum validity period**
   - Version: 2.2.1
   - Effect: Audit, Deny, Disabled
   - Test: Create cert with 25-month validity when policy requires ≤24 months
   - Implementation:
     - Add `Test-CertificateMaxValidityPolicy` function
     - Update `Create-PolicyTestEnvironment.ps1` to create long-validity cert
     - Add policy assignment in `Assign-AuditPolicies.ps1` and `Assign-DenyPolicies.ps1`

2. **Certificates should have the specified lifetime action triggers**
   - Version: 2.1.0
   - Effect: Audit, Deny, Disabled
   - Test: Create cert without auto-renewal trigger
   - Implementation:
     - Add `Test-CertificateLifetimeActionPolicy` function
     - Test auto-renewal configuration
     - Verify lifetime action triggers

3. **Certificates should not expire within the specified number of days**
   - Version: 2.1.1
   - Effect: Audit, Deny, Disabled
   - Test: Create cert expiring in 15 days when policy requires >30 days
   - Implementation:
     - Add `Test-CertificateExpirationWarningPolicy` function
     - Create near-expiry certificates
     - Verify expiration date checking

4. **Certificates should be issued by one of the specified non-integrated certificate authorities**
   - Version: 1.0.1
   - Effect: Audit, Deny, Disabled
   - Test: Create cert from unauthorized CA
   - Implementation:
     - Add `Test-CertificateMultipleCAPolicy` function
     - Test allowlist of multiple CAs
     - Verify CA validation logic

5. **Secrets should have content type set**
   - Version: 1.0.1
   - Effect: Audit, Deny, Disabled
   - Test: Create secret without ContentType property
   - Implementation:
     - Add `Test-SecretContentTypePolicy` function
     - Update test environment to create secrets with/without content type
     - Verify content type validation

### Phase 2: Key & Secret Lifecycle Policies (6 policies)
**Priority:** HIGH  
**Estimated Effort:** 4-5 hours

6. **Keys should have the specified maximum validity period**
   - Version: 1.0.1
   - Effect: Audit, Deny, Disabled
   - Test: Create key valid for 400 days when policy requires ≤365 days
   - Implementation:
     - Add `Test-KeyMaxValidityPolicy` function
     - Create keys with custom validity periods
     - Verify validity period checking

7. **Keys should have more than the specified number of days before expiration**
   - Version: 1.0.1
   - Effect: Audit, Deny, Disabled
   - Test: Create key expiring in 15 days when policy requires >30 days
   - Implementation:
     - Add `Test-KeyExpirationWarningPolicy` function
     - Create near-expiry keys
     - Verify expiration warning logic

8. **Keys should not be active for longer than the specified number of days**
   - Version: 1.0.1
   - Effect: Audit, Deny, Disabled
   - Test: Create key active for 400 days when policy requires ≤365 days
   - Implementation:
     - Add `Test-KeyMaxActivePolicy` function
     - Calculate key active duration
     - Verify active period validation

9. **Secrets should have the specified maximum validity period**
   - Version: 1.0.1
   - Effect: Audit, Deny, Disabled
   - Test: Create secret valid for 400 days when policy requires ≤365 days
   - Implementation:
     - Add `Test-SecretMaxValidityPolicy` function
     - Create secrets with custom validity periods
     - Verify validity period checking

10. **Secrets should have more than the specified number of days before expiration**
    - Version: 1.0.1
    - Effect: Audit, Deny, Disabled
    - Test: Create secret expiring in 15 days when policy requires >30 days
    - Implementation:
      - Add `Test-SecretExpirationWarningPolicy` function
      - Create near-expiry secrets
      - Verify expiration warning logic

11. **Secrets should not be active for longer than the specified number of days**
    - Version: 1.0.1
    - Effect: Audit, Deny, Disabled
    - Test: Create secret active for 400 days when policy requires ≤365 days
    - Implementation:
      - Add `Test-SecretMaxActivePolicy` function
      - Calculate secret active duration
      - Verify active period validation

### Phase 3: Advanced Key Features (2 policies)
**Priority:** MEDIUM  
**Estimated Effort:** 2-3 hours

12. **Keys should be backed by a hardware security module (HSM)**
    - Version: 1.0.1
    - Effect: Audit, Deny, Disabled
    - Test: Create software-protected key when policy requires HSM
    - Implementation:
      - Add `Test-KeyHSMBackedPolicy` function
      - Create both software and HSM keys
      - Verify HSM requirement enforcement
      - Note: Requires Premium Key Vault SKU

13. **Keys should have a rotation policy ensuring that their rotation is scheduled within the specified number of days after creation**
    - Version: 1.0.0
    - Effect: Audit, Deny, Disabled
    - Test: Create key without rotation policy
    - Implementation:
      - Add `Test-KeyRotationPolicyPolicy` function
      - Configure automatic key rotation
      - Verify rotation policy validation

### Phase 4: Network Security (1 policy)
**Priority:** MEDIUM  
**Estimated Effort:** 1-2 hours

14. **Azure Key Vault should disable public network access**
    - Version: 1.1.0
    - Effect: Audit, Deny, Disabled
    - Test: Create vault with public network access enabled
    - Implementation:
      - Add `Test-DisablePublicNetworkAccessPolicy` function
      - Verify public network access settings
      - Note: Different from firewall policy - this is complete disable

### Phase 5: DeployIfNotExists/Modify Policies (6 policies)
**Priority:** LOW (Complex - requires Log Analytics, Event Hub, Private Endpoints)  
**Estimated Effort:** 6-8 hours

15. **Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace**
    - Version: 2.0.1
    - Effect: DeployIfNotExists, Disabled
    - Test: Verify automatic deployment of diagnostic settings
    - Implementation:
      - Add `Test-DeployDiagnosticSettingsLAWPolicy` function
      - Create Log Analytics workspace in test environment
      - Test automatic diagnostic settings deployment
      - Verify compliance after auto-deployment

16. **Deploy Diagnostic Settings for Key Vault to Event Hub**
    - Version: 3.0.1
    - Effect: DeployIfNotExists, AuditIfNotExists, Disabled
    - Test: Verify automatic deployment to Event Hub
    - Implementation:
      - Add `Test-DeployDiagnosticSettingsEventHubPolicy` function
      - Create Event Hub in test environment
      - Test automatic diagnostic settings deployment

17. **Configure Azure Key Vaults with private endpoints**
    - Version: 1.0.1
    - Effect: Modify, Disabled
    - Test: Verify automatic private endpoint configuration
    - Implementation:
      - Add `Test-ConfigurePrivateEndpointsPolicy` function
      - Create VNet/Subnet in test environment
      - Test automatic private endpoint creation
      - Verify network configuration after deployment

18. **Configure Azure Key Vaults to use private DNS zones**
    - Version: 1.0.1
    - Effect: DeployIfNotExists, Disabled
    - Test: Verify automatic DNS zone configuration
    - Implementation:
      - Add `Test-ConfigurePrivateDNSPolicy` function
      - Verify DNS zone creation/association
      - Test with private endpoints

19. **Configure key vaults to enable firewall**
    - Version: 1.1.1
    - Effect: Modify, Disabled
    - Test: Verify automatic firewall configuration
    - Implementation:
      - Add `Test-ConfigureFirewallPolicy` function
      - Test automatic firewall enablement
      - Verify default deny configuration

20. **Resource logs in Key Vault should be enabled**
    - Version: 5.0.0
    - Effect: AuditIfNotExists, Disabled
    - Test: Verify resource logs enabled
    - Implementation:
      - Add `Test-ResourceLogsEnabledPolicy` function
      - Verify diagnostic logs configuration
      - Note: Similar to diagnostic settings but different policy

---

## Deferred Policies (10)

### Managed HSM Policies (Deferred - Requires Managed HSM Infrastructure)
1. [Preview]: Azure Key Vault Managed HSM should disable public network access (v1.0.0-preview)
2. [Preview]: Azure Key Vault Managed HSM keys should have an expiration date (v1.0.1-preview)
3. [Preview]: Azure Key Vault Managed HSM should use private link (v1.0.0-preview)
4. [Preview]: Configure Azure Key Vault Managed HSM to disable public network access (v2.0.0-preview)
5. [Preview]: Azure Key Vault Managed HSM keys using RSA cryptography should have minimum key size (v1.0.1-preview)
6. [Preview]: Azure Key Vault Managed HSM Keys should have more than specified days before expiration (v1.0.1-preview)
7. Azure Key Vault Managed HSM should have purge protection enabled (v1.0.0)
8. Resource logs in Azure Key Vault Managed HSM should be enabled (v1.1.0)
9. Deploy - Configure diagnostic settings to Event Hub for Azure Key Vault Managed HSM (v1.0.0)
10. [Preview]: Configure Azure Key Vault Managed HSM with private endpoints (v1.0.0-preview)
11. [Preview]: Azure Key Vault Managed HSM keys using elliptic curve cryptography should have specified curve names (v1.0.1-preview)

**Reason:** Managed HSM requires dedicated infrastructure, separate pricing tier, and preview features are not production-ready

---

## Implementation Checklist

### For Each Policy:

#### 1. Script Updates
- [ ] Add test function to `Test-AzurePolicyKeyVault.ps1`
- [ ] Add policy assignment to `Assign-AuditPolicies.ps1`
- [ ] Add policy assignment to `Assign-DenyPolicies.ps1` (if Deny effect supported)
- [ ] Update `Create-PolicyTestEnvironment.ps1` to create non-compliant resources
- [ ] Update `Remediate-ComplianceIssues.ps1` with remediation guidance

#### 2. Documentation Updates
- [ ] Update `AzurePolicy-KeyVault-TestMatrix.md` with new policy details
- [ ] Update `README.md` with new policy count (16 → 36)
- [ ] Update `IMPLEMENTATION_STATUS.md` with new test results
- [ ] Update `GAP_ANALYSIS.md` to show progress

#### 3. Test Environment
- [ ] Create test resources that violate the policy
- [ ] Create compliant resources for comparison
- [ ] Add to resource tracking

#### 4. Validation
- [ ] Test Audit mode (policy detects violation)
- [ ] Test Deny mode (policy blocks creation - if supported)
- [ ] Test Compliance scan (existing resources)
- [ ] Verify HTML/JSON/CSV reports include new policy
- [ ] Update compliance report with friendly policy names

---

## Estimated Timeline

**Phase 1 (Certificate Policies):** 3-4 hours  
**Phase 2 (Key & Secret Lifecycle):** 4-5 hours  
**Phase 3 (Advanced Key Features):** 2-3 hours  
**Phase 4 (Network Security):** 1-2 hours  
**Phase 5 (Deployment Policies):** 6-8 hours  
**Documentation & Testing:** 4-5 hours  

**Total Estimated Time:** 20-27 hours

---

## Success Criteria

- [ ] Policy coverage increased from 16 to 36 (125% increase)
- [ ] All non-preview, non-Managed HSM policies implemented
- [ ] All Audit mode tests passing
- [ ] All Deny mode tests passing (where supported)
- [ ] Test environment creates compliant and non-compliant resources
- [ ] Reports updated with friendly policy names
- [ ] Documentation updated with new coverage

---

## Dependencies

### Infrastructure Requirements:
- Azure Subscription with Key Vault permissions
- Log Analytics workspace (for Phase 5)
- Event Hub namespace (for Phase 5)
- VNet/Subnet (for Phase 5)
- Premium Key Vault SKU (for HSM-backed keys)

### Code Dependencies:
- All existing helper functions in Test-AzurePolicyKeyVault.ps1
- Policy assignment REST API (for custom parameters)
- Azure Policy compliance API

---

## Risk & Mitigation

**Risk:** DeployIfNotExists policies require additional Azure resources (Log Analytics, Event Hub, Private Endpoints)  
**Mitigation:** Implement in separate phase, make infrastructure creation optional

**Risk:** Some policies may have parameters that require custom values  
**Mitigation:** Use REST API for policy assignments with parameters

**Risk:** Time-based policies (expiration warnings) may be harder to test  
**Mitigation:** Create resources with backdated creation times or near-expiry dates

**Risk:** Premium SKU required for HSM-backed keys increases cost  
**Mitigation:** Make HSM tests optional, provide clear documentation

---

## Next Steps

1. ✅ Create this implementation plan
2. ✅ Update todos.md with tasks
3. ✅ Update tracked todo list
4. ⏳ Begin Phase 1 implementation
5. ⏳ Update test matrix documentation
6. ⏳ Implement remaining phases sequentially
