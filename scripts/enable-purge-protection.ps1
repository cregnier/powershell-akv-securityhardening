<#
.SYNOPSIS
    Enables purge protection on Azure Key Vaults

.DESCRIPTION
    This script enables purge protection on all Key Vaults in a subscription
    or specific resource group. Purge protection prevents permanent deletion
    of soft-deleted vaults until the retention period expires.
    
    Purge protection is a critical security feature that:
    - Prevents malicious permanent deletion of Key Vault data
    - Enforces minimum retention period for deleted vaults
    - Is required by Azure Policy compliance standards (CIS, MCSB)
    - Cannot be disabled once enabled (permanent protection)
    
.PARAMETER SubscriptionId
    The Azure subscription ID containing Key Vaults to update

.PARAMETER ResourceGroupName
    Optional: Specific resource group to target. If omitted, applies to all vaults in subscription.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them

.EXAMPLE
    .\enable-purge-protection.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
    Enables purge protection on all Key Vaults in the subscription

.EXAMPLE
    .\enable-purge-protection.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ResourceGroupName "rg-keyvaults" -WhatIf
    Preview purge protection changes for vaults in specific resource group

.NOTES
    Author: Azure Key Vault Security Framework
    Generated from: Test-AzurePolicyKeyVault.ps1
    ⚠️ WARNING: Purge protection cannot be disabled once enabled. Review carefully before applying.
#>
param(
    [Parameter(Mandatory=$true)] [string]$SubscriptionId,
    [Parameter(Mandatory=$false)] [string]$ResourceGroupName,
    [switch]$WhatIf
)

Set-AzContext -SubscriptionId $SubscriptionId

$vaults = if ($ResourceGroupName) { Get-AzKeyVault -ResourceGroupName $ResourceGroupName } else { Get-AzKeyVault }

foreach ($v in $vaults) {
    $cmd = "Update-AzKeyVault -VaultName '$($v.VaultName)' -ResourceGroupName '$($v.ResourceGroupName)' -EnablePurgeProtection"
    if ($WhatIf) { Write-Host "WHATIF: $cmd"; continue }

    try {
        Update-AzKeyVault -VaultName $v.VaultName -ResourceGroupName $v.ResourceGroupName -EnablePurgeProtection -ErrorAction Stop
        Write-Host "Enabled purge protection on $($v.VaultName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to enable purge protection on $($v.VaultName): $_" -ForegroundColor Red
    }
}
