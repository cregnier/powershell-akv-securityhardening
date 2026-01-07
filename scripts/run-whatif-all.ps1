# Run all per-vault remediation scripts and templates in WhatIf mode
$ErrorActionPreference = 'Continue'
$subs = 'ab1336c7-687d-4107-b0f6-9649a0458adb'
$perVaultPath = "$PSScriptRoot\per-vault"
if (Test-Path $perVaultPath) {
    Get-ChildItem -Path $perVaultPath -Filter '*.ps1' | ForEach-Object {
        Write-Host "--- Running: $($_.Name)" -ForegroundColor Cyan
        # Per-vault scripts print WHATIF lines by default when -Apply is not provided
        & $_.FullName -SubscriptionId $subs
    }
}

# Run core templates; pass -WhatIf where supported
$enableSoft = "$PSScriptRoot\enable-soft-delete.ps1"
$enablePurge = "$PSScriptRoot\enable-purge-protection.ps1"
$enableRbac = "$PSScriptRoot\enable-rbac-migration.ps1"
$enableDiag = "$PSScriptRoot\enable-diagnostics.ps1"
$cfgFw = "$PSScriptRoot\configure-firewall.ps1"

if (Test-Path $enableSoft) { Write-Host '--- Running template: enable-soft-delete.ps1' -ForegroundColor Cyan; & $enableSoft -SubscriptionId $subs -WhatIf }
if (Test-Path $enablePurge) { Write-Host '--- Running template: enable-purge-protection.ps1' -ForegroundColor Cyan; & $enablePurge -SubscriptionId $subs -WhatIf }
if (Test-Path $enableRbac) { Write-Host '--- Running template: enable-rbac-migration.ps1' -ForegroundColor Cyan; & $enableRbac -SubscriptionId $subs -WhatIf }
if (Test-Path $enableDiag) { Write-Host '--- Running template: enable-diagnostics.ps1' -ForegroundColor Cyan; & $enableDiag -SubscriptionId $subs -WorkspaceId 'PLACEHOLDER-WORKSPACE-ID' -WhatIf }
if (Test-Path $cfgFw) { Write-Host '--- Running template: configure-firewall.ps1' -ForegroundColor Cyan; & $cfgFw -SubscriptionId $subs -AllowedIpAddresses @('203.0.113.5') -WhatIf }
