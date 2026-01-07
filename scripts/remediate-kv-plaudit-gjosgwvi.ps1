<#
Per-vault remediation script for kv-plaudit-gjosgwvi
Usage: .\remediate-kv-plaudit-gjosgwvi.ps1 -SubscriptionId <id> [-Apply]
#>
param(
    [Parameter(Mandatory=$true)][string]$SubscriptionId,
    [switch]$Apply
)
Set-AzContext -SubscriptionId $SubscriptionId
$vaultName = 'kv-plaudit-gjosgwvi'
$resourceId = '/subscriptions/ab1336c7-687d-4107-b0f6-9649a0458adb/resourceGroups/rg-policy-keyvault-test/providers/Microsoft.KeyVault/vaults/kv-plaudit-gjosgwvi'
$rg = 'rg-policy-keyvault-test'

$cmds = @(
    "Update-AzKeyVault -VaultName '$vaultName' -ResourceGroupName '$rg' -EnableSoftDelete",
    "Update-AzKeyVault -VaultName '$vaultName' -ResourceGroupName '$rg' -EnablePurgeProtection",
    "Update-AzKeyVault -VaultName '$vaultName' -ResourceGroupName '$rg' -EnableRbacAuthorization",
    "Set-AzDiagnosticSetting -ResourceId '$resourceId' -Enabled `$true -Category 'AuditEvent' -WorkspaceId <log-analytics-resource-id>"
)

if (-not $Apply) { $cmds | ForEach-Object { Write-Host "WHATIF: $_" }; Write-Host "Run with -Apply to execute." -ForegroundColor Yellow; return }

foreach ($c in $cmds) { try { Invoke-Expression $c } catch { Write-Host "Failed: $c - $_" -ForegroundColor Red } }
Write-Host "Remediation complete for $vaultName" -ForegroundColor Green
