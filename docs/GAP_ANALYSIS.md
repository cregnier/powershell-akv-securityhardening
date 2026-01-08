# Test Matrix Gap Analysis

**Last Updated:** January 8, 2026

**Note:** As of January 8, 2026, all reports now include friendly policy names instead of GUIDs. See [COMPLIANCE_REPORT_ENHANCEMENT.md](COMPLIANCE_REPORT_ENHANCEMENT.md).

---

## Current State: 14 Tests Implemented vs 17 Required

### ✅ IMPLEMENTED Tests (14 total)

#### Key Vault Configuration (4 of 5)
1. ✅ Soft Delete - Policy ID: 1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d
2. ✅ Purge Protection - Policy ID: 0b60c0b2-2dc2-4e1c-b5c9-abbed971de53
3. ❌ **MISSING: Private Link** - Policy ID: a6abeaec-4d90-4a02-805f-6b26c4d3fbe9
4. ✅ Firewall & Network Access - Policy ID: 55615ac9-af46-4a59-874e-391cc3dfb490
5. ✅ RBAC Authorization - Policy ID: 12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5

#### Secrets Management (1 of 1)
1. ✅ Secret Expiration - Policy ID: 98728c90-32c7-4049-8429-847dc0f4fe37

#### Keys Management (4 of 4)
1. ✅ Key Expiration - Policy ID: 152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0
2. ✅ Key Type (RSA/EC) - Policy ID: 75c4f823-d65c-4f29-a733-01d0077fdbcb
3. ✅ RSA Key Size - Policy ID: 82067dbb-e53b-4e06-b631-546d197452d9
4. ✅ EC Curve Names - Policy ID: ff25f3c8-b739-4538-9d07-3d6d25cfb255

#### Certificates Management (4 of 6)
1. ❌ **MISSING: Certificate Expiration Date** - Policy ID: 0a075868-4c26-42ef-914c-5bc007359560
2. ✅ Certificate CA (Integrated) - Policy ID: 8e826246-c976-48f6-b03e-619bb92b3d82
3. ❌ **MISSING: Non-Integrated CA** - Policy ID: a22f4a40-01d3-4c7d-8071-da157eeff341
4. ✅ Certificate Key Type - Policy ID: 1151cede-290b-4ba0-8b38-0ad145ac888f
5. ✅ Certificate Renewal - Policy ID: 12ef42cb-9903-4e39-9c26-422d29570417
6. ✅ Certificate Validity (already implemented, covers validity period)

Note: Current implementation has "Certificate Validity" which may overlap with "Certificate Expiration Date" - need to verify distinction

#### Logging & Monitoring (1 of 1)
1. ✅ Diagnostic Logging - Policy ID: cf820ca0-f99e-4f3e-84fb-66e913812d21

---

## ❌ MISSING TESTS (3 total)

### 1. Private Link Configuration
- **Policy Name**: Azure Key Vaults should use private link
- **Policy ID**: a6abeaec-4d90-4a02-805f-6b26c4d3fbe9
- **Compliance Framework**: MCSB DP-8
- **Test Modes**: Audit only (no Deny mode)
- **Implementation Required**:
  - Test creating KeyVault without private endpoint
  - Verify policy detects missing private endpoint configuration
  - Function: `Test-PrivateLinkPolicy`

### 2. Non-Integrated CA Certificates
- **Policy Name**: Certificates should be issued by the specified non-integrated certificate authority
- **Policy ID**: a22f4a40-01d3-4c7d-8071-da157eeff341
- **Compliance Framework**: MCSB DP-7
- **Test Modes**: Audit, Deny
- **Implementation Required**:
  - Test creating self-signed certificates
  - Test creating certificates from non-approved external CA
  - Verify policy enforces external CA requirements
  - Function: `Test-NonIntegratedCAPolicy`

### 3. Certificate Expiration Date (Maximum Validity)
- **Policy Name**: Certificates should have the specified maximum validity period
- **Policy ID**: 0a075868-4c26-42ef-914c-5bc007359560
- **Compliance Framework**: MCSB DP-7
- **Test Modes**: Audit, Deny
- **Current Status**: May be partially covered by existing `Test-CertificateValidityPolicy`
- **Verification Needed**: Check if current validity test covers maximum expiration period
- **Implementation Required**:
  - Test creating certificates with excessive validity periods (e.g., >2 years)
  - Verify policy enforces maximum validity period
  - May need to rename or enhance existing test

---

## Implementation Priority

### High Priority (Required for 17 test coverage)
1. **Private Link Configuration** - New test function needed
2. **Non-Integrated CA Certificates** - New test function needed  
3. **Certificate Expiration Date** - Verify existing test or create new

### Medium Priority (Enhancement)
4. **HTML Report Enhancement** - Add before/after/verification/next steps for each test
5. **Test Matrix Validation** - Ensure all test scenarios from matrix are covered

### Low Priority (Documentation)
6. **README Update** - Restore to 17 policies with complete list
7. **Test Matrix Update** - Align with actual implementation

---

## Test Execution Matrix Validation

Current matrix shows:
- **17 Policy Count** - Need to implement 3 missing
- **17 Audit Tests** - Need to add 3 audit mode tests
- **15 Deny Tests** - Need to add 2 deny mode tests (Private Link is audit-only)
- **18 Compliance Checks** - Need to verify all compliance validations

---

## Action Items

1. ✅ Create gap analysis (this document)
2. ⏳ Implement `Test-PrivateLinkPolicy` function
3. ⏳ Implement `Test-NonIntegratedCAPolicy` function
4. ⏳ Verify/enhance `Test-CertificateValidityPolicy` for expiration
5. ⏳ Update `$script:AllAvailableTests` array to 17 entries
6. ⏳ Enhance HTML report template with policy lifecycle details
7. ⏳ Update README with all 17 policies
8. ⏳ Test all 17 scenarios in Audit and Deny modes
