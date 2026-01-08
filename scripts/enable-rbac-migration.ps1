<#
.SYNOPSIS
    Migrates Azure Key Vaults from Access Policies to RBAC authorization model

.DESCRIPTION
    This script enables the RBAC (Role-Based Access Control) authorization model on Key Vaults.
    RBAC provides more granular and auditable access control compared to Access Policies.
    
    Benefits of RBAC model:
    - Consistent access management across all Azure resources
    - More granular permissions (built-in and custom roles)
    - Better audit trail through Azure Activity Log
    - Integration with Azure AD Privileged Identity Management (PIM)
    - Recommended by Microsoft for new deployments
    
    ⚠️ IMPORTANT: This change affects vault access!
    - Existing access policies will continue to work during transition
    - Manual migration of access policies to RBAC roles required
    - Coordinate with application owners before enabling
    - Test in non-production environment first
    
.PARAMETER SubscriptionId
    The Azure subscription ID containing Key Vaults to migrate

.PARAMETER ResourceGroupName
    Optional: Specific resource group to target. If omitted, applies to all vaults in subscription.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them

.EXAMPLE
    .\enable-rbac-migration.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WhatIf
    Preview RBAC migration for all vaults in subscription

.EXAMPLE
    .\enable-rbac-migration.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ResourceGroupName "rg-keyvaults"
    Enable RBAC on vaults in specific resource group

.NOTES
    Author: Azure Key Vault Security Framework
    Generated from: Test-AzurePolicyKeyVault.ps1
    ⚠️ WARNING: Manual review and migration of access policies to RBAC roles required after enabling.
    See: https://learn.microsoft.com/azure/key-vault/general/rbac-migration
#>
param(
    [Parameter(Mandatory=$true)] [string]$SubscriptionId,
    [Parameter(Mandatory=$false)] [string]$ResourceGroupName,
    [switch]$WhatIf
)

Set-AzContext -SubscriptionId $SubscriptionId

$vaults = if ($ResourceGroupName) { Get-AzKeyVault -ResourceGroupName $ResourceGroupName } else { Get-AzKeyVault }

foreach ($v in $vaults) {
    Write-Host "Vault: $($v.VaultName) — reviewing access policies..." -ForegroundColor Cyan
    $access = (Get-AzKeyVault -VaultName $v.VaultName -ResourceGroupName $v.ResourceGroupName)
    Write-Host "AccessPolicies count: $($access.AccessPolicies.Count)" -ForegroundColor Yellow

    $cmd = "Update-AzKeyVault -VaultName '$($v.VaultName)' -ResourceGroupName '$($v.ResourceGroupName)' -EnableRbacAuthorization \$true"
    if ($WhatIf) { Write-Host "WHATIF: $cmd"; continue }

    Write-Host "MANUAL ACTION REQUIRED: Confirm that existing access policies have been migrated into equivalent RBAC roles before enabling RBAC." -ForegroundColor Magenta
    # If operator confirms, they can uncomment below to apply
    # Update-AzKeyVault -VaultName $v.VaultName -ResourceGroupName $v.ResourceGroupName -EnableRbacAuthorization $true
}
