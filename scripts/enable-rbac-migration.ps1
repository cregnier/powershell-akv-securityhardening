<#
Migrate Key Vaults to RBAC authorization model (manual review recommended)
Usage: .\enable-rbac-migration.ps1 -SubscriptionId <id> [-ResourceGroupName <rg>] [-WhatIf]
Warning: migrating to RBAC can change access; review access policies before enabling.
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
