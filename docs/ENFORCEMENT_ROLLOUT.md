# Enforcement Rollout Plan (Draft)

**Last Updated:** January 8, 2026

**Note:** All compliance reports now include friendly policy names, evaluation explanations, and comprehensive metadata footers. See [COMPLIANCE_REPORT_ENHANCEMENT.md](COMPLIANCE_REPORT_ENHANCEMENT.md) for details.

---

Goal: Transition validated Key Vault policies from Audit -> Deny with minimal service disruption.

Prerequisites
- Stakeholder sign-off (application owners, platform ops, security)
- Inventory of vaults and owners (see `resource-tracking.json`)
- Backout plan and verification playbooks
- Communication windows and maintenance schedule

Phased Rollout
1. Pilot (1-2 weeks)
   - Scope: 2 non-production subscriptions / test resource group
   - Actions: Apply Deny policies at resource group scope for pilot vaults
   - Verify: Run `Test-AzurePolicyKeyVault.ps1` in Deny mode and validate application behavior

2. Staged Enforcement (2-4 weeks)
   - Scope: Selected production resource groups with low change velocity
   - Actions: Assign Deny policies at resource-group scope; monitor logs for blocked operations
   - Verify: Weekly review of diagnostic logs and support tickets

3. Subscription Enforcement
   - Scope: Organization subscriptions after successful staged runs
   - Actions: Assign Deny policies at subscription or management-group scope
   - Verify: Continuous monitoring and automated alerts for denied operations

Operational Steps
- Enable diagnostic export to Log Analytics before enforcement
- Create runbooks for emergency rollback (policy delete/assignment removal)
- Confirm backup/restore procedures for keys and secrets where allowed
- Prepare runbook for RBAC migration (if moving from access policies)

Communication
- Send pre-enforcement notices 2 weeks prior to each stage
- Provide owners with remediation scripts and per-vault action items
- Offer a 48-hour window for exceptions (temporary resource tags) with approval tracking

Risk & Mitigation
- Risk: Application failures due to denied operations
  - Mitigation: Pilot and staged enforcement; provide remediation scripts and owner support
- Risk: Loss of audit data
  - Mitigation: Ensure diagnostics and log exports are configured before enforcement

Approval
- Document approvers and dates. Do not proceed to broader scopes without explicit approval.

This is a working draft — I can expand into a stakeholder-ready rollout checklist and timeline on request.
