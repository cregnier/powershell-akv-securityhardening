<#
.SYNOPSIS
    Enables soft delete on Azure Key Vaults

.DESCRIPTION
    This script enables soft delete protection on all Key Vaults in a subscription
    or specific resource group. Soft delete allows recovery of deleted vaults within
    a 90-day retention period.
    
    Soft delete is a critical security feature that:
    - Prevents permanent data loss from accidental deletion
    - Allows 90-day recovery window for deleted vaults
    - Is required by Azure Policy compliance standards (CIS, MCSB)
    
.PARAMETER SubscriptionId
    The Azure subscription ID containing Key Vaults to update

.PARAMETER ResourceGroupName
    Optional: Specific resource group to target. If omitted, applies to all vaults in subscription.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them

.EXAMPLE
    .\enable-soft-delete.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
    Enables soft delete on all Key Vaults in the subscription

.EXAMPLE
    .\enable-soft-delete.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ResourceGroupName "rg-keyvaults" -WhatIf
    Preview soft delete changes for vaults in specific resource group

.NOTES
    Author: Azure Key Vault Security Framework
    Generated from: Test-AzurePolicyKeyVault.ps1
    Soft delete cannot be disabled once enabled (this is intentional for security)
#>
param(
    [Parameter(Mandatory=$true)] [string]$SubscriptionId,
    [Parameter(Mandatory=$false)] [string]$ResourceGroupName,
    [switch]$WhatIf
)

Set-AzContext -SubscriptionId $SubscriptionId

$vaults = if ($ResourceGroupName) { Get-AzKeyVault -ResourceGroupName $ResourceGroupName } else { Get-AzKeyVault }

foreach ($v in $vaults) {
    $cmd = "Update-AzKeyVault -VaultName '$($v.VaultName)' -ResourceGroupName '$($v.ResourceGroupName)' -EnableSoftDelete"
    if ($WhatIf) {
        Write-Host "WHATIF: $cmd"
        continue
    }

    try {
        Update-AzKeyVault -VaultName $v.VaultName -ResourceGroupName $v.ResourceGroupName -EnableSoftDelete -ErrorAction Stop
        Write-Host "Enabled soft delete on $($v.VaultName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to enable soft delete on $($v.VaultName): $_" -ForegroundColor Red
    }
}
