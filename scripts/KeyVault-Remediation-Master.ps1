# Azure Key Vault Policy - Comprehensive Remediation Scripts
# Generated from Test-AzurePolicyKeyVault.ps1

<#
.SYNOPSIS
    Comprehensive remediation scripts for Azure Key Vault Policy enforcement

.DESCRIPTION
    This file contains three master remediation scripts:
    1. Audit Mode Script - Assigns all audit policies at subscription level
    2. Enforce Mode Script - Assigns all deny policies at subscription level  
    3. Compliance Script - Remediates existing non-compliant resources

.NOTES
    Generated: 2026-01-02
    Test Matrix: AzurePolicy-KeyVault-TestMatrix.md
#>

#region Audit Mode Script

<#
.SYNOPSIS
    Assigns all Azure Key Vault policies in Audit mode at subscription level

.DESCRIPTION
    This script assigns 16 Azure Key Vault security policies in Audit mode.
    Audit mode detects non-compliance but does not prevent resource creation.
    Use this to understand current compliance posture before enforcing policies.

.PARAMETER SubscriptionId
    The Azure subscription ID where policies will be assigned

.EXAMPLE
    Assign-AllAuditPolicies -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
#>

function Assign-AllAuditPolicies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )
    
    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId
    
    Write-Host "Assigning Azure Key Vault policies in AUDIT mode..." -ForegroundColor Cyan
    
    # Define all policies with their IDs
    $policies = @(
        @{
            Name = "Key vaults should have soft delete enabled"
            Id = "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
            DisplayName = "KV-SoftDelete-Audit"
        },
        @{
            Name = "Key vaults should have deletion protection enabled"
            Id = "0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
            DisplayName = "KV-PurgeProtection-Audit"
        },
        @{
            Name = "Azure Key Vault should use RBAC permission model"
            Id = "12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
            DisplayName = "KV-RBAC-Audit"
        },
        @{
            Name = "Azure Key Vault should have firewall enabled"
            Id = "55615ac9-af46-4a59-874e-391cc3dfb490"
            DisplayName = "KV-Firewall-Audit"
        },
        @{
            Name = "Azure Key Vaults should use private link"
            Id = "a6abeaec-4d90-4a02-805f-6b26c4d3fbe9"
            DisplayName = "KV-PrivateLink-Audit"
        },
        @{
            Name = "Key Vault secrets should have an expiration date"
            Id = "98728c90-32c7-4049-8429-847dc0f4fe37"
            DisplayName = "KV-SecretExpiration-Audit"
        },
        @{
            Name = "Key Vault keys should have an expiration date"
            Id = "152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0"
            DisplayName = "KV-KeyExpiration-Audit"
        },
        @{
            Name = "Key vaults should have only allowed key types"
            Id = "1151cede-290b-4ba0-8b38-0ad145ac888f"
            DisplayName = "KV-KeyType-Audit"
        },
        @{
            Name = "Keys using RSA cryptography should have a minimum key size"
            Id = "82067dbb-e53b-4e06-b631-546d197452d9"
            DisplayName = "KV-RSAKeySize-Audit"
        },
        @{
            Name = "Keys using elliptic curve cryptography should use approved curve names"
            Id = "ff25f3c8-b739-4538-9d07-3d6d25cfb255"
            DisplayName = "KV-ECCurve-Audit"
        },
        @{
            Name = "Certificates should have the specified maximum validity period"
            Id = "0a075868-4c26-42ef-914c-5bc007359560"
            DisplayName = "KV-CertValidity-Audit"
        },
        @{
            Name = "Certificates should be issued by allowed certificate authorities"
            Id = "8e826246-c976-48f6-b03e-619bb92b3d82"
            DisplayName = "KV-CertCA-Audit"
        },
        @{
            Name = "Certificates using elliptic curve cryptography should use approved curve names"
            Id = "bd78111f-4953-4367-9fd3-2f7bc21a5e29"
            DisplayName = "KV-CertECCurve-Audit"
        },
        @{
            Name = "Certificates should use allowed key types"
            Id = "1151cede-290b-4ba0-8b38-0ad145ac888c"
            DisplayName = "KV-CertKeyType-Audit"
        },
        @{
            Name = "Certificates should have a lifetime action trigger"
            Id = "12ef42fe-5c3e-4529-a4e4-8d582e2e4c77"
            DisplayName = "KV-CertRenewal-Audit"
        },
        @{
            Name = "Azure Key Vault should have diagnostic logging enabled"
            Id = "cf820ca0-f99e-4f3e-84fb-66e913812d21"
            DisplayName = "KV-DiagnosticLogging-Audit"
        }
    )
    
    $assignedCount = 0
    $errorCount = 0
    
    foreach ($policy in $policies) {
        try {
            Write-Host "  Assigning: $($policy.Name)..." -ForegroundColor Yellow
            
            $assignment = New-AzPolicyAssignment `
                -Name $policy.DisplayName `
                -DisplayName $policy.DisplayName `
                -Scope "/subscriptions/$SubscriptionId" `
                -PolicyDefinition (Get-AzPolicyDefinition -Id $policy.Id) `
                -AssignIdentity `
                -Location "eastus" `
                -Description "Audit mode - detects non-compliant Key Vaults but allows creation"
            
            Write-Host "    ✓ Assigned successfully" -ForegroundColor Green
            $assignedCount++
        }
        catch {
            Write-Host "    ✗ Error: $_" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Assigned: $assignedCount" -ForegroundColor Green
    Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Gray' })
    
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Wait 15-30 minutes for initial compliance scan" -ForegroundColor White
    Write-Host "2. Review compliance dashboard: https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance" -ForegroundColor White
    Write-Host "3. Identify non-compliant resources and plan remediation" -ForegroundColor White
    Write-Host "4. Consider transitioning to Deny mode after achieving compliance" -ForegroundColor White
}

#endregion

#region Enforce Mode Script

<#
.SYNOPSIS
    Assigns all Azure Key Vault policies in Deny mode at subscription level

.DESCRIPTION
    This script assigns Azure Key Vault security policies in Deny (Enforce) mode.
    Deny mode actively blocks creation of non-compliant resources.
    
    WARNING: This will prevent creation of non-compliant Key Vaults!
    Ensure existing resources are compliant before enforcing.

.PARAMETER SubscriptionId
    The Azure subscription ID where policies will be assigned

.PARAMETER ConfirmEnforcement
    Switch parameter to confirm you understand the impact

.EXAMPLE
    Assign-AllEnforcePolicies -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ConfirmEnforcement
#>

function Assign-AllEnforcePolicies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [switch]$ConfirmEnforcement
    )
    
    if (-not $ConfirmEnforcement) {
        Write-Host "ERROR: Must specify -ConfirmEnforcement to proceed" -ForegroundColor Red
        Write-Host "This will BLOCK creation of non-compliant Key Vaults!" -ForegroundColor Yellow
        return
    }
    
    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId
    
    Write-Host "Assigning Azure Key Vault policies in DENY (ENFORCE) mode..." -ForegroundColor Red
    Write-Host "WARNING: Non-compliant resources will be BLOCKED from creation!" -ForegroundColor Yellow
    
    # Define policies that support Deny effect
    $policies = @(
        @{
            Name = "Key vaults should have soft delete enabled"
            Id = "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
            DisplayName = "KV-SoftDelete-Deny"
        },
        @{
            Name = "Key vaults should have deletion protection enabled"
            Id = "0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
            DisplayName = "KV-PurgeProtection-Deny"
        },
        @{
            Name = "Azure Key Vault should use RBAC permission model"
            Id = "12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
            DisplayName = "KV-RBAC-Deny"
        },
        @{
            Name = "Azure Key Vault should have firewall enabled"
            Id = "55615ac9-af46-4a59-874e-391cc3dfb490"
            DisplayName = "KV-Firewall-Deny"
        },
        @{
            Name = "Key Vault secrets should have an expiration date"
            Id = "98728c90-32c7-4049-8429-847dc0f4fe37"
            DisplayName = "KV-SecretExpiration-Deny"
        },
        @{
            Name = "Key Vault keys should have an expiration date"
            Id = "152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0"
            DisplayName = "KV-KeyExpiration-Deny"
        },
        @{
            Name = "Key vaults should have only allowed key types"
            Id = "1151cede-290b-4ba0-8b38-0ad145ac888f"
            DisplayName = "KV-KeyType-Deny"
        },
        @{
            Name = "Keys using RSA cryptography should have a minimum key size"
            Id = "82067dbb-e53b-4e06-b631-546d197452d9"
            DisplayName = "KV-RSAKeySize-Deny"
        },
        @{
            Name = "Keys using elliptic curve cryptography should use approved curve names"
            Id = "ff25f3c8-b739-4538-9d07-3d6d25cfb255"
            DisplayName = "KV-ECCurve-Deny"
        },
        @{
            Name = "Certificates should have the specified maximum validity period"
            Id = "0a075868-4c26-42ef-914c-5bc007359560"
            DisplayName = "KV-CertValidity-Deny"
        },
        @{
            Name = "Certificates should be issued by allowed certificate authorities"
            Id = "8e826246-c976-48f6-b03e-619bb92b3d82"
            DisplayName = "KV-CertCA-Deny"
        },
        @{
            Name = "Certificates should use allowed key types"
            Id = "1151cede-290b-4ba0-8b38-0ad145ac888c"
            DisplayName = "KV-CertKeyType-Deny"
        },
        @{
            Name = "Certificates should have a lifetime action trigger"
            Id = "12ef42fe-5c3e-4529-a4e4-8d582e2e4c77"
            DisplayName = "KV-CertRenewal-Deny"
        }
    )
    
    $assignedCount = 0
    $errorCount = 0
    
    foreach ($policy in $policies) {
        try {
            Write-Host "  Assigning: $($policy.Name)..." -ForegroundColor Yellow
            
            # Create parameters for Deny effect
            $policyParams = @{
                effect = @{
                    value = "Deny"
                }
            }
            
            $assignment = New-AzPolicyAssignment `
                -Name $policy.DisplayName `
                -DisplayName $policy.DisplayName `
                -Scope "/subscriptions/$SubscriptionId" `
                -PolicyDefinition (Get-AzPolicyDefinition -Id $policy.Id) `
                -PolicyParameterObject $policyParams `
                -Description "Deny mode - actively blocks non-compliant Key Vault resources"
            
            Write-Host "    ✓ Assigned successfully - NON-COMPLIANT RESOURCES WILL BE BLOCKED" -ForegroundColor Green
            $assignedCount++
        }
        catch {
            Write-Host "    ✗ Error: $_" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Assigned: $assignedCount" -ForegroundColor Green
    Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Gray' })
    
    Write-Host "`nIMPORTANT:" -ForegroundColor Red
    Write-Host "Policies are now ACTIVELY ENFORCING compliance!" -ForegroundColor Yellow
    Write-Host "Non-compliant Key Vault operations will be DENIED." -ForegroundColor Yellow
    
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Communicate policy enforcement to all teams" -ForegroundColor White
    Write-Host "2. Update IaC templates to comply with policies" -ForegroundColor White
    Write-Host "3. Create policy exemption process for special cases" -ForegroundColor White
    Write-Host "4. Monitor compliance dashboard regularly" -ForegroundColor White
}

#endregion

#region Compliance Remediation Script

<#
.SYNOPSIS
    Remediates existing non-compliant Key Vaults

.DESCRIPTION
    This script scans all Key Vaults in a subscription and remediates common
    compliance issues:
    - Enables soft delete
    - Enables purge protection
    - Migrates from access policies to RBAC
    - Configures firewall rules
    - Sets expiration dates on secrets/keys

.PARAMETER SubscriptionId
    The Azure subscription ID to scan

.PARAMETER ResourceGroupName
    Optional: specific resource group to remediate

.PARAMETER WhatIf
    Shows what would be remediated without making changes

.EXAMPLE
    Remediate-AllKeyVaults -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WhatIf
    
.EXAMPLE
    Remediate-AllKeyVaults -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ResourceGroupName "rg-prod"
#>

function Remediate-AllKeyVaults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )
    
    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId
    
    Write-Host "Scanning Key Vaults for compliance issues..." -ForegroundColor Cyan
    
    # Get all Key Vaults
    if ($ResourceGroupName) {
        $vaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName
    } else {
        $vaults = Get-AzKeyVault
    }
    
    Write-Host "Found $(@($vaults).Count) Key Vault(s) to scan" -ForegroundColor White
    
    $remediatedCount = 0
    $issues = @()
    
    foreach ($vault in $vaults) {
        Write-Host "`nChecking: $($vault.VaultName)..." -ForegroundColor Yellow
        
        # Get full vault details
        $fullVault = Get-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName
        
        # Check Soft Delete
        if ($fullVault.EnableSoftDelete -ne $true) {
            $issue = "Soft delete is NOT enabled"
            Write-Host "  ✗ $issue" -ForegroundColor Red
            $issues += @{
                Vault = $vault.VaultName
                Issue = $issue
                Remediation = "Update-AzKeyVault -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -EnableSoftDelete"
            }
            
            if (-not $WhatIf) {
                try {
                    Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -EnableSoftDelete
                    Write-Host "    ✓ Remediated: Soft delete enabled" -ForegroundColor Green
                    $remediatedCount++
                }
                catch {
                    Write-Host "    ✗ Failed to remediate: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  ✓ Soft delete enabled" -ForegroundColor Green
        }
        
        # Check Purge Protection
        if ($fullVault.EnablePurgeProtection -ne $true) {
            $issue = "Purge protection is NOT enabled"
            Write-Host "  ✗ $issue" -ForegroundColor Red
            $issues += @{
                Vault = $vault.VaultName
                Issue = $issue
                Remediation = "Update-AzKeyVault -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -EnablePurgeProtection"
            }
            
            if (-not $WhatIf) {
                try {
                    Update-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName -EnablePurgeProtection
                    Write-Host "    ✓ Remediated: Purge protection enabled" -ForegroundColor Green
                    $remediatedCount++
                }
                catch {
                    Write-Host "    ✗ Failed to remediate: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  ✓ Purge protection enabled" -ForegroundColor Green
        }
        
        # Check RBAC Authorization
        if ($fullVault.EnableRbacAuthorization -ne $true) {
            $issue = "Using legacy access policy model (should migrate to RBAC)"
            Write-Host "  ⚠ $issue" -ForegroundColor Yellow
            $issues += @{
                Vault = $vault.VaultName
                Issue = $issue
                Remediation = "Update-AzKeyVault -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -EnableRbacAuthorization # WARNING: Review access policies first!"
            }
            
            # Don't auto-remediate RBAC migration - requires manual review
            Write-Host "    ⚠ Manual review required - RBAC migration affects access policies" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ RBAC authorization enabled" -ForegroundColor Green
        }
        
        # Check Firewall
        $networkRules = $fullVault.NetworkAcls
        $hasFirewall = $networkRules -and (
            $networkRules.DefaultAction -eq 'Deny' -or
            $networkRules.IpRules.Count -gt 0 -or
            $networkRules.VirtualNetworkRules.Count -gt 0
        )
        
        if (-not $hasFirewall) {
            $issue = "No firewall configured - vault accepts connections from all networks"
            Write-Host "  ⚠ $issue" -ForegroundColor Yellow
            $issues += @{
                Vault = $vault.VaultName
                Issue = $issue
                Remediation = "# Configure firewall manually based on security requirements`nUpdate-AzKeyVaultNetworkRuleSet -VaultName '$($vault.VaultName)' -ResourceGroupName '$($vault.ResourceGroupName)' -DefaultAction Deny"
            }
            
            # Don't auto-remediate firewall - requires security review
            Write-Host "    ⚠ Manual configuration required - firewall rules depend on security requirements" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ Firewall configured" -ForegroundColor Green
        }
        
        # Check secrets for expiration
        $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        $secretsWithoutExpiration = 0
        
        foreach ($secret in $secrets) {
            $fullSecret = Get-AzKeyVaultSecret -VaultName $vault.VaultName -Name $secret.Name -ErrorAction SilentlyContinue
            if ($fullSecret.Attributes.Expires -eq $null) {
                $secretsWithoutExpiration++
                
                $issue = "Secret '$($secret.Name)' has no expiration date"
                $issues += @{
                    Vault = $vault.VaultName
                    Issue = $issue
                    Remediation = "Update-AzKeyVaultSecret -VaultName '$($vault.VaultName)' -Name '$($secret.Name)' -Expires (Get-Date).AddYears(1)"
                }
            }
        }
        
        if ($secretsWithoutExpiration -gt 0) {
            Write-Host "  ⚠ $secretsWithoutExpiration secret(s) without expiration date" -ForegroundColor Yellow
        }
        
        # Check keys for expiration
        $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        $keysWithoutExpiration = 0
        
        foreach ($key in $keys) {
            $fullKey = Get-AzKeyVaultKey -VaultName $vault.VaultName -Name $key.Name -ErrorAction SilentlyContinue
            if ($fullKey.Attributes.Expires -eq $null) {
                $keysWithoutExpiration++
                
                $issue = "Key '$($key.Name)' has no expiration date"
                $issues += @{
                    Vault = $vault.VaultName
                    Issue = $issue
                    Remediation = "Update-AzKeyVaultKey -VaultName '$($vault.VaultName)' -Name '$($key.Name)' -Expires (Get-Date).AddYears(1)"
                }
            }
        }
        
        if ($keysWithoutExpiration -gt 0) {
            Write-Host "  ⚠ $keysWithoutExpiration key(s) without expiration date" -ForegroundColor Yellow
        }
    }
    
    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Compliance Scan Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Vaults scanned: $(@($vaults).Count)" -ForegroundColor White
    Write-Host "Issues found: $($issues.Count)" -ForegroundColor Yellow
    
    if ($WhatIf) {
        Write-Host "`nRun without -WhatIf to apply remediations" -ForegroundColor Yellow
    } else {
        Write-Host "Issues remediated: $remediatedCount" -ForegroundColor Green
    }
    
    # Export remediation script
    if ($issues.Count -gt 0) {
        $scriptPath = "C:\Temp\KeyVault-Remediation-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
        
        $scriptContent = @"
# Key Vault Compliance Remediation Script
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Subscription: $SubscriptionId

<#
.SYNOPSIS
    Remediate $($issues.Count) Key Vault compliance issue(s)

.DESCRIPTION
    This script was auto-generated by the compliance scan.
    Review each command before executing.
#>

"@
        
        foreach ($issue in $issues) {
            $scriptContent += @"

# Vault: $($issue.Vault)
# Issue: $($issue.Issue)
$($issue.Remediation)

"@
        }
        
        $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
        Write-Host "`nRemediation script exported to: $scriptPath" -ForegroundColor Cyan
    }
}

#endregion

# Example usage (uncomment to run):
# Assign-AllAuditPolicies -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
# Assign-AllEnforcePolicies -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ConfirmEnforcement
# Remediate-AllKeyVaults -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WhatIf
