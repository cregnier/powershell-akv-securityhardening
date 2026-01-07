<#
Enable Purge Protection on Key Vaults
Usage: .\enable-purge-protection.ps1 -SubscriptionId <id> [-ResourceGroupName <rg>] [-WhatIf]
Note: Purge protection cannot be disabled once enabled — review before applying.
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
