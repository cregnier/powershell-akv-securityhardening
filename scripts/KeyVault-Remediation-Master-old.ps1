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
















... (file truncated)    Assigns all Azure Key Vault policies in Deny mode at subscription level.SYNOPSIS<#
n#region Enforce Mode Script    )
    
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

#endregion        [string]$SubscriptionId        [Parameter(Mandatory = $true)]    param(function Assign-AllAuditPolicies {#>    Assign-AllAuditPolicies -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"n.EXAMPLE