<#
Per-vault remediation script for kv-comp-gjosgwvi
Usage: .\remediate-kv-comp-gjosgwvi.ps1 -SubscriptionId <id> [-Apply]
By default prints WHATIF lines; pass -Apply to run.
#>
param(
    [Parameter(Mandatory=$true)][string]$SubscriptionId,
    [switch]$Apply
)

Set-AzContext -SubscriptionId $SubscriptionId
$vaultName = 'kv-comp-gjosgwvi'
$resourceId = '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-keyvault-test/providers/Microsoft.KeyVault/vaults/kv-comp-gjosgwvi'
$rg = 'rg-policy-keyvault-test'

$cmds = @(
    "Update-AzKeyVault -VaultName '$vaultName' -ResourceGroupName '$rg' -EnableSoftDelete",
    "Update-AzKeyVault -VaultName '$vaultName' -ResourceGroupName '$rg' -EnablePurgeProtection",
    "Update-AzKeyVault -VaultName '$vaultName' -ResourceGroupName '$rg' -EnableRbacAuthorization",
    "Set-AzDiagnosticSetting -ResourceId '$resourceId' -Enabled `$true -Category 'AuditEvent' -WorkspaceId <log-analytics-resource-id>"
)

if (-not $Apply) {
    foreach ($c in $cmds) { Write-Host "WHATIF: $c" }
    Write-Host "Run with -Apply to execute these changes." -ForegroundColor Yellow
}
else {
    try {
        Update-AzKeyVault -VaultName $vaultName -ResourceGroupName $rg -EnableSoftDelete -ErrorAction Stop
    } catch { Write-Host ("Failed soft-delete for {0}: {1}" -f $vaultName, $_) -ForegroundColor Red }
    try {
        Update-AzKeyVault -VaultName $vaultName -ResourceGroupName $rg -EnablePurgeProtection -ErrorAction Stop
    } catch { Write-Host ("Failed purge-protection for {0}: {1}" -f $vaultName, $_) -ForegroundColor Red }
    try {
        Update-AzKeyVault -VaultName $vaultName -ResourceGroupName $rg -EnableRbacAuthorization -ErrorAction Stop
    } catch { Write-Host ("Failed RBAC enable for {0}: {1}" -f $vaultName, $_) -ForegroundColor Red }
    Write-Host "Completed remediation attempts for $vaultName" -ForegroundColor Green
}
