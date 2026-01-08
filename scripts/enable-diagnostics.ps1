<#
.SYNOPSIS
    Enables diagnostic logging for Azure Key Vaults to Log Analytics workspace

.DESCRIPTION
    This script configures diagnostic settings on all Key Vaults to send audit logs
    and metrics to a Log Analytics workspace for monitoring and compliance.
    
    Diagnostic logging enables:
    - Audit trail of all Key Vault operations
    - Security monitoring and alerting
    - Compliance reporting for regulatory requirements
    - Integration with Azure Monitor and Azure Sentinel
    
.PARAMETER SubscriptionId
    The Azure subscription ID containing Key Vaults to update

.PARAMETER WorkspaceId
    The resource ID of the Log Analytics workspace (format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace})

.PARAMETER ResourceGroupName
    Optional: Specific resource group to target. If omitted, applies to all vaults in subscription.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them

.EXAMPLE
    .\enable-diagnostics.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WorkspaceId "/subscriptions/sub-id/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-security"
    Enables diagnostic logging on all Key Vaults in the subscription

.EXAMPLE
    .\enable-diagnostics.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WorkspaceId "/subscriptions/.../workspaces/law-security" -ResourceGroupName "rg-keyvaults" -WhatIf
    Preview diagnostic settings for vaults in specific resource group

.NOTES
    Author: Azure Key Vault Security Framework
    Generated from: Test-AzurePolicyKeyVault.ps1
    Requires existing Log Analytics workspace (will not create one automatically)
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
