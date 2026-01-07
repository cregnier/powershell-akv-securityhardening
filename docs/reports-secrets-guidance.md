# Secrets Guidance (Draft)

- **Access model:** Prefer **RBAC** over Access Policies for new vaults; RBAC simplifies management and integrates with Azure AD. For existing vaults with many access policies, plan staged migration and communicate to app owners.
- **Managed identities:** Use platform-managed identities for services that need Key Vault secrets/keys; avoid long-lived service principals when possible.
- **Secret rotation:** Enforce short-lived secrets and automated rotation. Use Azure Key Vault rotation features or implement Automation/Functions to rotate secrets and update consumers.
- **Certificates & HSM:** Store production keys in HSM-protected vaults (Managed HSM or dedicated HSM pool) when compliance requires it. Use Key Vault certificate management for SSL/TLS lifecycle.
- **Least privilege:** Grant minimum permissions (Get, List for apps; Cert/Key/Secret specific roles). Review and remove stale principals regularly.
- **Discovery & inventory:** Maintain `resource-tracking.json` and include application owners, purpose, and rotation contacts for each vault.
- **Logging & alerting:** Enable diagnostic settings to send `AuditEvent` to Log Analytics / Event Hub; create alerts on unusual access patterns and export logs off-cluster for retention.
- **Network controls:** Prefer private endpoints for sensitive vaults; use firewall IP rules only for known fixed-host IPs and combine with service tags where appropriate.
- **Operational playbook:** Document rollback, emergency key rotation, and owner escalation contacts. Test recovery scenarios periodically (backup/restore of keys where allowed).

This is a draft — I can expand each section into actionable runbooks and sample commands if you'd like.
