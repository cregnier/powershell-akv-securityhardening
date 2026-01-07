<#
Configure Key Vault firewall rules or disable public network access
Usage: .\configure-firewall.ps1 -SubscriptionId <id> -AllowedIpAddresses @('1.2.3.4') [-ResourceGroupName <rg>] [-WhatIf]
Or use -UsePrivateEndpoint switch to generate guidance for creating private endpoints.
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
