<#
.SYNOPSIS
    Remediates existing non-compliant Key Vaults

.DESCRIPTION
    This script scans all Key Vaults in a subscription and remediates common
    compliance issues identified by Azure Policy:
    
    Automatic Remediation (safe):
    - Enables soft delete
    - Enables purge protection
    
    Manual Review Required:
    - RBAC migration (affects access policies)
    - Firewall configuration (security requirements vary)
    - Secret/Key expiration dates (business requirements vary)
    - Diagnostic logging (requires Log Analytics workspace)
    
    Generated from: Test-AzurePolicyKeyVault.ps1
    Test Results: AzurePolicy-KeyVault-TestReport-20260106-102723.html

.PARAMETER SubscriptionId
    The Azure subscription ID to scan

.PARAMETER ResourceGroupName
    Optional: specific resource group to remediate

.PARAMETER WhatIf
    Shows what would be remediated without making changes

.PARAMETER AutoRemediate
    PRODUCTION MODE (SAFE - Recommended): Automatically fixes safe, non-breaking issues only.
    Auto-fixes: Soft delete, purge protection
    Manual review: RBAC migration, firewall, logging, expiration (breaking changes)
    This is the recommended default for production environments.

.PARAMETER DevTestMode
    DEVTEST MODE (AGGRESSIVE - Test environments only): Auto-fixes ALL issues including breaking changes.
    WARNING: This mode invalidates access policies, blocks network access, and may break applications.
    Only use in development/test environments where disruption is acceptable.
    For production, use -AutoRemediate instead (safe mode).

.EXAMPLE
    .\Remediate-ComplianceIssues.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WhatIf
    
.EXAMPLE
    .\Remediate-ComplianceIssues.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -AutoRemediate
    
.EXAMPLE
    .\Remediate-ComplianceIssues.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ResourceGroupName "rg-prod" -AutoRemediate

.NOTES
    Generated: 2026-01-06
    Compliance Frameworks: MCSB, CIS, NIST, CERT
    
    Based on test results showing common compliance gaps:
    - Soft delete compliance: HIGH
    - Purge protection compliance: HIGH
    - RBAC migration: MEDIUM (requires planning)
    - Firewall configuration: LOW (requires security review)
    - Object expiration: LOW (requires business alignment)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [switch]$ScanOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoRemediate,
    
    [Parameter(Mandatory = $false)]
    [switch]$DevTestMode
)

# Requires Azure PowerShell modules
#Requires -Module Az.Accounts
#Requires -Module Az.KeyVault
#Requires -Module Az.Resources

# Set subscription context
Write-Host "Setting Azure context to subscription: $SubscriptionId..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

# DevTestMode safety check
if ($DevTestMode) {
    Write-Host "`n⚠️  WARNING: DEV/TEST MODE ENABLED ⚠️" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "This mode will make BREAKING CHANGES including:" -ForegroundColor Yellow
    Write-Host "  • Force enable RBAC (may break existing access policies)" -ForegroundColor Yellow
    Write-Host "  • Add test firewall rules (may block access)" -ForegroundColor Yellow
    Write-Host "  • Create/configure Log Analytics workspace" -ForegroundColor Yellow
    Write-Host "  • Auto-set 90-day expiration on secrets/keys" -ForegroundColor Yellow
    Write-Host "`nOnly use in TEST environments! For production, use -AutoRemediate instead." -ForegroundColor Red
    Write-Host ""
    
    $confirmation = Read-Host "Continue with DevTestMode? (Y/N)"
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host "Aborted by user. No changes made." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "✓ DevTestMode confirmed. Proceeding with full automated remediation...`n" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Key Vault Compliance Remediation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIfPreference -or $ScanOnly) {
    Write-Host "Running in preview mode - no changes will be made`n" -ForegroundColor Yellow
} elseif (-not $AutoRemediate -and -not $DevTestMode) {
    Write-Host "Running in scan-only mode - add -AutoRemediate to fix issues`n" -ForegroundColor Yellow
} elseif ($DevTestMode) {
    Write-Host "Running in DevTest Mode - FULL AUTO-REMEDIATION ENABLED`n" -ForegroundColor Magenta
} elseif ($AutoRemediate) {
    Write-Host "Running in Auto-Remediate mode - safe fixes only`n" -ForegroundColor Green
}

Write-Host "Scanning Key Vaults for compliance issues...`n" -ForegroundColor White

# Get all Key Vaults
if ($ResourceGroupName) {
    Write-Host "Scanning resource group: $ResourceGroupName" -ForegroundColor Gray
    $vaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName
} else {
    Write-Host "Scanning all resource groups in subscription" -ForegroundColor Gray
    $vaults = Get-AzKeyVault
}

Write-Host "Found $(@($vaults).Count) Key Vault(s) to scan`n" -ForegroundColor White

$remediatedCount = 0
$issues = @()
$vaultResults = @()

foreach ($vault in $vaults) {
    Write-Host "Checking: $($vault.VaultName)" -ForegroundColor Yellow
    Write-Host "  Resource Group: $($vault.ResourceGroupName)" -ForegroundColor Gray
    Write-Host "  Location: $($vault.Location)" -ForegroundColor Gray
    
    $vaultIssues = @()
    $vaultRemediated = 0
    
    # Get full vault details
    $fullVault = Get-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName
    
    # ========================================
    # Check Soft Delete (CIS 8.5, MCSB DP-8)
    # ========================================
    if ($fullVault.EnableSoftDelete -ne $true) {
        $issue = @{
            Vault = $vault.VaultName
            Category = "Configuration"
            Issue = "Soft delete is NOT enabled"
            Severity = "High"
            Framework = "CIS 8.5, MCSB DP-8"
            AutoRemediable = $true
            Remediation = "Update-AzKeyVault -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -EnableSoftDelete"
        }
        
        Write-Host "  ✗ Soft delete NOT enabled [CIS 8.5]" -ForegroundColor Red
        $vaultIssues += $issue
        
        if (($AutoRemediate -or $DevTestMode) -and -not $WhatIf) {
            try {
                Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -EnableSoftDelete -ErrorAction Stop | Out-Null
                Write-Host "    ✓ Remediated: Soft delete enabled" -ForegroundColor Green
                $remediatedCount++
                $vaultRemediated++
            }
            catch {
                Write-Host "    ✗ Failed to remediate: $($_.Exception.Message)" -ForegroundColor Red
            }
        } elseif ($WhatIfPreference -or $ScanOnly) {
            Write-Host "    [Preview] Would enable soft delete" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ✓ Soft delete enabled" -ForegroundColor Green
    }
    
    # ========================================
    # Check Purge Protection (CIS 8.5, MCSB DP-8)
    # ========================================
    if ($fullVault.EnablePurgeProtection -ne $true) {
        $issue = @{
            Vault = $vault.VaultName
            Category = "Configuration"
            Issue = "Purge protection is NOT enabled"
            Severity = "High"
            Framework = "CIS 8.5, MCSB DP-8"
            AutoRemediable = $true
            Remediation = "Update-AzKeyVault -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -EnablePurgeProtection"
        }
        
        Write-Host "  ✗ Purge protection NOT enabled [CIS 8.5]" -ForegroundColor Red
        $vaultIssues += $issue
        
        if (($AutoRemediate -or $DevTestMode) -and -not $WhatIf) {
            try {
                Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -EnablePurgeProtection -ErrorAction Stop | Out-Null
                Write-Host "    ✓ Remediated: Purge protection enabled" -ForegroundColor Green
                $remediatedCount++
                $vaultRemediated++
            }
            catch {
                Write-Host "    ✗ Failed to remediate: $($_.Exception.Message)" -ForegroundColor Red
            }
        } elseif ($WhatIfPreference -or $ScanOnly) {
            Write-Host "    [Preview] Would enable purge protection" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ✓ Purge protection enabled" -ForegroundColor Green
    }
    
    # ========================================
    # Check RBAC Authorization (CIS 8.6, MCSB PA-7)
    # ========================================
    if ($fullVault.EnableRbacAuthorization -ne $true) {
        $issue = @{
            Vault = $vault.VaultName
            Category = "Access Control"
            Issue = "Using legacy access policy model (should migrate to RBAC)"
            Severity = "Medium"
            Framework = "CIS 8.6, MCSB PA-7"
            AutoRemediable = $false
            Remediation = "# MANUAL REVIEW REQUIRED - RBAC migration affects access policies`n# 1. Document existing access policies`n# 2. Plan RBAC role assignments`n# 3. Test in non-production first`nUpdate-AzKeyVault -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -DisableRbacAuthorization `$false"
        }
        
        Write-Host "  ⚠ Using legacy access policies (should use RBAC) [CIS 8.6]" -ForegroundColor Yellow
        $vaultIssues += $issue
        
        if ($DevTestMode -and -not $WhatIf) {
            try {
                Write-Host "    [DevTestMode] Enabling RBAC authorization..." -ForegroundColor Cyan
                Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -DisableRbacAuthorization $false -ErrorAction Stop | Out-Null
                Write-Host "    ✓ Remediated: RBAC enabled (access policies cleared)" -ForegroundColor Green
                $remediatedCount++
                $vaultRemediated++
            }
            catch {
                Write-Host "    ✗ Failed to enable RBAC: $($_.Exception.Message)" -ForegroundColor Red
            }
        } elseif (-not $DevTestMode) {
            Write-Host "    → Manual review required - migration affects access" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✓ RBAC authorization enabled" -ForegroundColor Green
    }
    
    # ========================================
    # Check Firewall (MCSB DP-8)
    # ========================================
    $networkRules = $fullVault.NetworkAcls
    $hasFirewall = $networkRules -and (
        $networkRules.DefaultAction -eq 'Deny' -or
        ($networkRules.IpRules -and $networkRules.IpRules.Count -gt 0) -or
        ($networkRules.VirtualNetworkRules -and $networkRules.VirtualNetworkRules.Count -gt 0)
    )
    
    if (-not $hasFirewall) {
        $issue = @{
            Vault = $vault.VaultName
            Category = "Network Security"
            Issue = "No firewall configured - accepts connections from all networks"
            Severity = "Medium"
            Framework = "MCSB DP-8"
            AutoRemediable = $false
            Remediation = "# MANUAL CONFIGURATION REQUIRED - security requirements vary`n# Option 1: Deny all, allow specific IPs`nUpdate-AzKeyVaultNetworkRuleSet -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -DefaultAction Deny -IpAddressRange @('1.2.3.4/32')`n# Option 2: Allow Azure services bypass`nUpdate-AzKeyVaultNetworkRuleSet -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -Bypass AzureServices"
        }
        
        Write-Host "  ⚠ No firewall configured [MCSB DP-8]" -ForegroundColor Yellow
        $vaultIssues += $issue
        
        if ($DevTestMode -and -not $WhatIf) {
            try {
                Write-Host "    [DevTestMode] Configuring test firewall (deny all + Azure services bypass)..." -ForegroundColor Cyan
                Update-AzKeyVaultNetworkRuleSet -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -DefaultAction Deny -Bypass AzureServices -ErrorAction Stop | Out-Null
                Write-Host "    ✓ Remediated: Firewall enabled (deny all, Azure services allowed)" -ForegroundColor Green
                $remediatedCount++
                $vaultRemediated++
            }
            catch {
                Write-Host "    ✗ Failed to configure firewall: $($_.Exception.Message)" -ForegroundColor Red
            }
        } elseif (-not $DevTestMode) {
            Write-Host "    → Manual configuration required per security requirements" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✓ Firewall configured" -ForegroundColor Green
    }
    
    # ========================================
    # Check Diagnostic Logging (MCSB LT-3, CIS)
    # ========================================
    try {
        $diagnostics = Get-AzDiagnosticSetting -ResourceId $fullVault.ResourceId -ErrorAction SilentlyContinue 2>$null
        $hasLogging = $diagnostics -and ($diagnostics | Where-Object { $_.Logs.Enabled -contains $true })
        
        if (-not $hasLogging) {
            $issue = @{
                Vault = $vault.VaultName
                Category = "Monitoring"
                Issue = "Diagnostic logging not configured"
                Severity = "Medium"
                Framework = "MCSB LT-3, CIS"
                AutoRemediable = $false
                Remediation = "# MANUAL CONFIGURATION REQUIRED - requires Log Analytics workspace`n`$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName 'rg-monitoring' -Name 'law-central'`nSet-AzDiagnosticSetting -ResourceId '$($fullVault.ResourceId)' -WorkspaceId `$workspace.ResourceId -Enabled `$true -Category AuditEvent"
            }
            
            Write-Host "  ⚠ Diagnostic logging not configured [MCSB LT-3]" -ForegroundColor Yellow
            $vaultIssues += $issue
            
            if ($DevTestMode -and -not $WhatIf) {
                try {
                    Write-Host "    [DevTestMode] Creating/finding Log Analytics workspace..." -ForegroundColor Cyan
                    
                    # Try to find existing workspace in same resource group
                    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $vault.ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1
                    
                    if (-not $workspace) {
                        # Create new workspace
                        $workspaceName = "law-keyvault-test-$(Get-Random -Minimum 1000 -Maximum 9999)"
                        $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $vault.ResourceGroupName -Name $workspaceName -Location $fullVault.Location -Sku PerGB2018 -ErrorAction Stop
                        Write-Host "    ✓ Created Log Analytics workspace: $workspaceName" -ForegroundColor Green
                    } else {
                        Write-Host "    ✓ Using existing workspace: $($workspace.Name)" -ForegroundColor Green
                    }
                    
                    # Enable diagnostic logging
                    $logCategories = @(
                        New-AzDiagnosticSettingLogSettingsObject -Category AuditEvent -Enabled $true
                    )
                    $metricCategories = @(
                        New-AzDiagnosticSettingMetricSettingsObject -Category AllMetrics -Enabled $true
                    )
                    
                    New-AzDiagnosticSetting -Name "KeyVaultDiagnostics" -ResourceId $fullVault.ResourceId -WorkspaceId $workspace.ResourceId -Log $logCategories -Metric $metricCategories -ErrorAction Stop | Out-Null
                    Write-Host "    ✓ Remediated: Diagnostic logging enabled" -ForegroundColor Green
                    $remediatedCount++
                    $vaultRemediated++
                }
                catch {
                    Write-Host "    ✗ Failed to configure logging: $($_.Exception.Message)" -ForegroundColor Red
                }
            } elseif (-not $DevTestMode) {
                Write-Host "    → Requires Log Analytics workspace configuration" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✓ Diagnostic logging enabled" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠ Could not check diagnostic settings" -ForegroundColor Yellow
    }
    
    # ========================================
    # Check Secrets for Expiration (CIS 8.3, 8.4, MCSB DP-6)
    # ========================================
    try {
        $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        $secretsWithoutExpiration = @()
        
        foreach ($secret in $secrets) {
            $fullSecret = Get-AzKeyVaultSecret -VaultName $vault.VaultName -Name $secret.Name -ErrorAction SilentlyContinue
            if ($fullSecret.Attributes.Expires -eq $null) {
                $secretsWithoutExpiration += $secret.Name
            }
        }
        
        if ($secretsWithoutExpiration.Count -gt 0) {
            $issue = @{
                Vault = $vault.VaultName
                Category = "Secrets Lifecycle"
                Issue = "$($secretsWithoutExpiration.Count) secret(s) without expiration date"
                Severity = "Medium"
                Framework = "CIS 8.3, 8.4, MCSB DP-6"
                AutoRemediable = $false
                Remediation = "# MANUAL REVIEW REQUIRED - expiration periods vary by business requirements`n# Example: Set 1-year expiration`n" + ($secretsWithoutExpiration | ForEach-Object { "Update-AzKeyVaultSecret -VaultName '$($vault.VaultName)' -Name '$_' -Expires (Get-Date).AddYears(1)" }) -join "`n"
            }
            
            Write-Host "  ⚠ $($secretsWithoutExpiration.Count) secret(s) without expiration [CIS 8.3]" -ForegroundColor Yellow
            $vaultIssues += $issue
            
            if ($DevTestMode -and -not $WhatIf) {
                Write-Host "    [DevTestMode] Setting 90-day expiration on secrets..." -ForegroundColor Cyan
                $expireDate = (Get-Date).AddDays(90)
                $secretsFixed = 0
                foreach ($secretName in $secretsWithoutExpiration) {
                    try {
                        Update-AzKeyVaultSecret -VaultName $vault.VaultName -Name $secretName -Expires $expireDate -ErrorAction Stop | Out-Null
                        $secretsFixed++
                    }
                    catch {
                        Write-Host "    ✗ Failed to update secret '$secretName': $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                if ($secretsFixed -gt 0) {
                    Write-Host "    ✓ Remediated: Set 90-day expiration on $secretsFixed secret(s)" -ForegroundColor Green
                    $remediatedCount++
                    $vaultRemediated++
                }
            } elseif (-not $DevTestMode) {
                Write-Host "    → Review business requirements for expiration periods" -ForegroundColor Gray
            }
        } elseif ($secrets.Count -gt 0) {
            Write-Host "  ✓ All secrets have expiration dates" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠ Could not check secrets (may lack permissions)" -ForegroundColor Yellow
    }
    
    # ========================================
    # Check Keys for Expiration (MCSB DP-6)
    # ========================================
    try {
        $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        $keysWithoutExpiration = @()
        
        foreach ($key in $keys) {
            $fullKey = Get-AzKeyVaultKey -VaultName $vault.VaultName -Name $key.Name -ErrorAction SilentlyContinue
            if ($fullKey.Attributes.Expires -eq $null) {
                $keysWithoutExpiration += $key.Name
            }
        }
        
        if ($keysWithoutExpiration.Count -gt 0) {
            $issue = @{
                Vault = $vault.VaultName
                Category = "Key Lifecycle"
                Issue = "$($keysWithoutExpiration.Count) key(s) without expiration date"
                Severity = "Medium"
                Framework = "MCSB DP-6"
                AutoRemediable = $false
                Remediation = "# MANUAL REVIEW REQUIRED - key rotation schedules vary`n# Example: Set 2-year expiration for encryption keys`n" + ($keysWithoutExpiration | ForEach-Object { "Update-AzKeyVaultKey -VaultName '$($vault.VaultName)' -Name '$_' -Expires (Get-Date).AddYears(2)" }) -join "`n"
            }
            
            Write-Host "  ⚠ $($keysWithoutExpiration.Count) key(s) without expiration [MCSB DP-6]" -ForegroundColor Yellow
            $vaultIssues += $issue
            
            if ($DevTestMode -and -not $WhatIf) {
                Write-Host "    [DevTestMode] Setting 90-day expiration on keys..." -ForegroundColor Cyan
                $expireDate = (Get-Date).AddDays(90)
                $keysFixed = 0
                foreach ($keyName in $keysWithoutExpiration) {
                    try {
                        Update-AzKeyVaultKey -VaultName $vault.VaultName -Name $keyName -Expires $expireDate -ErrorAction Stop | Out-Null
                        $keysFixed++
                    }
                    catch {
                        Write-Host "    ✗ Failed to update key '$keyName': $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                if ($keysFixed -gt 0) {
                    Write-Host "    ✓ Remediated: Set 90-day expiration on $keysFixed key(s)" -ForegroundColor Green
                    $remediatedCount++
                    $vaultRemediated++
                }
            } elseif (-not $DevTestMode) {
                Write-Host "    → Align with key rotation policy" -ForegroundColor Gray
            }
        } elseif ($keys.Count -gt 0) {
            Write-Host "  ✓ All keys have expiration dates" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠ Could not check keys (may lack permissions)" -ForegroundColor Yellow
    }
    
    $vaultResults += @{
        VaultName = $vault.VaultName
        ResourceGroup = $vault.ResourceGroupName
        IssueCount = $vaultIssues.Count
        RemediatedCount = $vaultRemediated
        Issues = $vaultIssues
    }
    
    $issues += $vaultIssues
    Write-Host ""
}

# ========================================
# Summary
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Compliance Scan Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Vaults scanned: $(@($vaults).Count)" -ForegroundColor White
Write-Host "Total issues found: $($issues.Count)" -ForegroundColor Yellow

$issuesBySeverity = $issues | Group-Object Severity
foreach ($group in $issuesBySeverity) {
    $color = switch ($group.Name) {
        "High" { "Red" }
        "Medium" { "Yellow" }
        "Low" { "Gray" }
        default { "White" }
    }
    Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor $color
}

if (($AutoRemediate -or $DevTestMode) -and -not $WhatIf) {
    Write-Host "`nIssues auto-remediated: $remediatedCount" -ForegroundColor Green
    Write-Host "Manual review required: $($issues.Count - $remediatedCount)" -ForegroundColor Yellow
} elseif ($WhatIf) {
    Write-Host "`nRun without -WhatIf and with -AutoRemediate to fix safe issues" -ForegroundColor Cyan
} else {
    Write-Host "`nAdd -AutoRemediate to fix safe issues automatically" -ForegroundColor Cyan
}

# ========================================
# Export Remediation Script
# ========================================
if ($issues.Count -gt 0) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $scriptPath = "$PSScriptRoot\KeyVault-Remediation-$timestamp.ps1"
    
    $scriptContent = @"
# Key Vault Compliance Remediation Script
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Subscription: $SubscriptionId
# Scanned: $(@($vaults).Count) vault(s)
# Issues: $($issues.Count)

<#
.SYNOPSIS
    Remediate $($issues.Count) Key Vault compliance issue(s)

.DESCRIPTION
    This script was auto-generated by compliance scan.
    Review each command before executing.
    
    Summary by Category:
$($issues | Group-Object Category | ForEach-Object { "    - $($_.Name): $($_.Count) issue(s)" } | Out-String)
#>

# Set context
Set-AzContext -SubscriptionId '$SubscriptionId'

"@
    
    foreach ($vaultResult in $vaultResults) {
        if ($vaultResult.Issues.Count -gt 0) {
            $scriptContent += @"

# ========================================
# Vault: $($vaultResult.VaultName)
# Resource Group: $($vaultResult.ResourceGroup)
# Issues: $($vaultResult.Issues.Count)
# ========================================

"@
            
            foreach ($issue in $vaultResult.Issues) {
                $scriptContent += @"
# Issue: $($issue.Issue)
# Severity: $($issue.Severity)
# Framework: $($issue.Framework)
# Auto-remediable: $($issue.AutoRemediable)

$($issue.Remediation)

"@
            }
        }
    }
    
    $scriptContent += @"

Write-Host "`nRemediation complete. Review results and update compliance dashboard." -ForegroundColor Green
"@
    
    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
    Write-Host "`nDetailed remediation script exported to:" -ForegroundColor Cyan
    Write-Host "  $scriptPath" -ForegroundColor White
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Review exported remediation script" -ForegroundColor White
Write-Host "2. Execute manual remediation items (RBAC, firewall, logging)" -ForegroundColor White
Write-Host "3. Set expiration dates based on business requirements" -ForegroundColor White
Write-Host "4. Re-run this script to verify compliance" -ForegroundColor White
Write-Host "5. Check Azure Policy dashboard after 15-30 minutes:" -ForegroundColor White
Write-Host "   https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance" -ForegroundColor Gray
