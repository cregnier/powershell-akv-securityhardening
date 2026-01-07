<#
Enable diagnostic settings for Key Vaults to a Log Analytics workspace
Usage: .\enable-diagnostics.ps1 -SubscriptionId <id> -WorkspaceId <workspaceResourceId> [-ResourceGroupName <rg>] [-WhatIf]
#>
param(
    [Parameter(Mandatory=$true)] [string]$SubscriptionId,
    [Parameter(Mandatory=$true)] [string]$WorkspaceId,
    [Parameter(Mandatory=$false)] [string]$ResourceGroupName,
    [switch]$WhatIf
)

Set-AzContext -SubscriptionId $SubscriptionId

$vaults = if ($ResourceGroupName) { Get-AzKeyVault -ResourceGroupName $ResourceGroupName } else { Get-AzKeyVault }

foreach ($v in $vaults) {
    $resourceId = $v.ResourceId
    $cmd = "Set-AzDiagnosticSetting -ResourceId '$resourceId' -WorkspaceId '$WorkspaceId' -Enabled $true -Category 'AuditEvent'"
    if ($WhatIf) { Write-Host "WHATIF: $cmd"; continue }

    try {
        Set-AzDiagnosticSetting -ResourceId $resourceId -WorkspaceId $WorkspaceId -Enabled $true -Category @('AuditEvent') -ErrorAction Stop
        Write-Host "Diagnostic settings enabled for $($v.VaultName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to enable diagnostics for $($v.VaultName): $_" -ForegroundColor Red
    }
}
