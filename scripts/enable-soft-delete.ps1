<#
Enable Soft Delete on Key Vaults
Usage: .\enable-soft-delete.ps1 -SubscriptionId <id> [-ResourceGroupName <rg>] [-WhatIf]
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
