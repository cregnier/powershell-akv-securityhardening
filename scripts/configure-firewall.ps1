<#
.SYNOPSIS
    Configures network access controls for Azure Key Vaults

.DESCRIPTION
    This script configures firewall rules and network access restrictions on Key Vaults.
    Supports two modes:
    1. Firewall IP allowlist mode: Specify allowed public IP addresses
    2. Private endpoint mode: Provides guidance for creating private endpoints
    
    Network security controls:
    - Restrict public network access to specific IP addresses
    - Block all public access (requires private endpoint)
    - Enable virtual network service endpoints
    - Transition to private endpoint architecture
    
.PARAMETER SubscriptionId
    The Azure subscription ID containing Key Vaults to configure

.PARAMETER AllowedIpAddresses
    Array of IP addresses or CIDR ranges to allow through the firewall (e.g., @('1.2.3.4', '10.0.0.0/24'))

.PARAMETER UsePrivateEndpoint
    Switch to receive guidance for creating private endpoints (instead of IP allowlist)

.PARAMETER ResourceGroupName
    Optional: Specific resource group to target. If omitted, applies to all vaults in subscription.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them

.EXAMPLE
    .\configure-firewall.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -AllowedIpAddresses @('203.0.113.10')
    Configures firewall to allow specific public IP address

.EXAMPLE
    .\configure-firewall.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -UsePrivateEndpoint
    Provides guidance for setting up private endpoints

.EXAMPLE
    .\configure-firewall.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -AllowedIpAddresses @('10.0.0.0/24') -ResourceGroupName "rg-keyvaults" -WhatIf
    Preview firewall changes for vaults in specific resource group

.NOTES
    Author: Azure Key Vault Security Framework
    Generated from: Test-AzurePolicyKeyVault.ps1
    ⚠️ WARNING: Configuring firewall may block existing applications. Test in non-production first.
#>
param(
    [Parameter(Mandatory=$true)] [string]$SubscriptionId,
    [Parameter(Mandatory=$false)] [string[]]$AllowedIpAddresses,
    [Parameter(Mandatory=$false)] [switch]$UsePrivateEndpoint,
    [Parameter(Mandatory=$false)] [string]$ResourceGroupName,
    [switch]$WhatIf
)

Set-AzContext -SubscriptionId $SubscriptionId
$vaults = if ($ResourceGroupName) { Get-AzKeyVault -ResourceGroupName $ResourceGroupName } else { Get-AzKeyVault }

foreach ($v in $vaults) {
    if ($UsePrivateEndpoint) {
        Write-Host "GUIDANCE: Create a private endpoint for $($v.VaultName) and then run Update-AzKeyVault to disable public access." -ForegroundColor Cyan
        Write-Host "Example: New-AzPrivateEndpoint -Name 'kv-pe' -ResourceGroupName '$($v.ResourceGroupName)' -Location '$($v.Location)' -Subnet <SubnetObject> -PrivateLinkServiceConnection <pls>" -ForegroundColor Yellow
        continue
    }

    if (-not $AllowedIpAddresses) {
        Write-Host "No AllowedIpAddresses provided for $($v.VaultName); skipping" -ForegroundColor Yellow
        continue
    }

    $cmd = "Update-AzKeyVaultNetworkRuleSet -VaultName '$($v.VaultName)' -ResourceGroupName '$($v.ResourceGroupName)' -DefaultAction Deny -IpRule (<$($AllowedIpAddresses -join ', ')>)"
    if ($WhatIf) { Write-Host "WHATIF: $cmd"; continue }

    $ipRuleObjects = @()
    foreach ($ip in $AllowedIpAddresses) {
        $ipRuleObjects += New-Object -TypeName Microsoft.Azure.Commands.KeyVault.Models.PSKeyVaultIpRule -ArgumentList $ip
    }

    try {
        Update-AzKeyVaultNetworkRuleSet -VaultName $v.VaultName -ResourceGroupName $v.ResourceGroupName -DefaultAction Deny -IpRule $ipRuleObjects -ErrorAction Stop
        Write-Host "Configured firewall for $($v.VaultName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to configure firewall for $($v.VaultName): $_" -ForegroundColor Red
    }
}
