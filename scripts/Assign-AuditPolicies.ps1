<#
.SYNOPSIS
    Assigns all Azure Key Vault policies in Audit mode at subscription or resource group level

.DESCRIPTION
    This script assigns 16 Azure Key Vault security policies in Audit mode.
    Audit mode detects non-compliance but does not prevent resource creation.
    Use this to understand current compliance posture before enforcing policies.
    
    Generated from: Test-AzurePolicyKeyVault.ps1
    Test Results: AzurePolicy-KeyVault-TestReport-20260106-102723.html
    
.PARAMETER SubscriptionId
    The Azure subscription ID where policies will be assigned

.PARAMETER ResourceGroupName
    Optional: Resource group name to scope policies. If specified, policies only apply to Key Vaults in this RG.

.PARAMETER WhatIf
    Shows what would be assigned without making changes

.EXAMPLE
    .\Assign-AuditPolicies.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb"
    
.EXAMPLE
    .\Assign-AuditPolicies.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ResourceGroupName "rg-policy-keyvault-test"

.EXAMPLE
    .\Assign-AuditPolicies.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WhatIf

.NOTES
    Generated: 2026-01-06
    Test Matrix: AzurePolicy-KeyVault-TestMatrix.md
    Compliance Frameworks: MCSB, CIS, NIST, CERT
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName
)

# Requires Azure PowerShell modules
#Requires -Module Az.Accounts
#Requires -Module Az.Resources

# Set subscription context
Write-Host "Setting Azure context to subscription: $SubscriptionId..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

# Determine scope
if ($ResourceGroupName) {
    $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
    Write-Host "Assigning Azure Key Vault policies in AUDIT mode to resource group: $ResourceGroupName..." -ForegroundColor Cyan
} else {
    $scope = "/subscriptions/$SubscriptionId"
    Write-Host "Assigning Azure Key Vault policies in AUDIT mode to entire subscription..." -ForegroundColor Cyan
}
Write-Host "Audit mode detects non-compliance but allows resource creation`n" -ForegroundColor Gray

# Define all policies with their IDs
$policies = @(
    @{
        Name = "Key vaults should have soft delete enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
        DisplayName = "KV-SoftDelete-Audit"
        Frameworks = "CIS 8.5, MCSB DP-8"
    },
    @{
        Name = "Key vaults should have deletion protection enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
        DisplayName = "KV-PurgeProtection-Audit"
        Frameworks = "CIS 8.5, MCSB DP-8"
    },
    @{
        Name = "Azure Key Vault should use RBAC permission model"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
        DisplayName = "KV-RBAC-Audit"
        Frameworks = "CIS 8.6, MCSB PA-7"
    },
    @{
        Name = "Azure Key Vault should have firewall enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/55615ac9-af46-4a59-874e-391cc3dfb490"
        DisplayName = "KV-Firewall-Audit"
        Frameworks = "MCSB DP-8"
    },
    @{
        Name = "Azure Key Vaults should use private link"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/a6abeaec-4d90-4a02-805f-6b26c4d3fbe9"
        DisplayName = "KV-PrivateLink-Audit"
        Frameworks = "MCSB DP-8"
    },
    @{
        Name = "Key Vault secrets should have an expiration date"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/98728c90-32c7-4049-8429-847dc0f4fe37"
        DisplayName = "KV-SecretExpiration-Audit"
        Frameworks = "CIS 8.3, CIS 8.4, MCSB DP-6"
    },
    @{
        Name = "Key Vault keys should have an expiration date"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0"
        DisplayName = "KV-KeyExpiration-Audit"
        Frameworks = "MCSB DP-6"
    },
    @{
        Name = "Keys should be the specified cryptographic type RSA or EC"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1151cede-290b-4ba0-8b38-0ad145ac888f"
        DisplayName = "KV-KeyType-Audit"
        Frameworks = "NIST, CERT"
    },
    @{
        Name = "Keys using RSA cryptography should have a minimum key size"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/82067dbb-e53b-4e06-b631-546d197452d9"
        DisplayName = "KV-RSAKeySize-Audit"
        Frameworks = "NIST, CERT, MCSB"
    },
    @{
        Name = "Keys using elliptic curve cryptography should use approved curve names"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/ff25f3c8-b739-4538-9d07-3d6d25cfb255"
        DisplayName = "KV-ECCurve-Audit"
        Frameworks = "NIST, CERT"
    },
    @{
        Name = "Certificates should have the specified maximum validity period"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/0a075868-4c26-42ef-914c-5bc007359560"
        DisplayName = "KV-CertValidity-Audit"
        Frameworks = "MCSB DP-7"
    },
    @{
        Name = "Certificates should be issued by the specified integrated certificate authority"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/8e826246-c976-48f6-b03e-619bb92b3d82"
        DisplayName = "KV-CertCA-Audit"
        Frameworks = "MCSB DP-7"
    },
    @{
        Name = "Certificates using elliptic curve cryptography should use approved curve names"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/bd78111f-4953-4367-9fd3-2f7bc21a5e29"
        DisplayName = "KV-CertECCurve-Audit"
        Frameworks = "MCSB DP-7"
    },
    @{
        Name = "Certificates should use allowed key types"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1151cede-290b-4ba0-8b38-0ad145ac888c"
        DisplayName = "KV-CertKeyType-Audit"
        Frameworks = "NIST, CERT"
    },
    @{
        Name = "Certificates should have the specified lifetime action triggers"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/12ef42fe-5c3e-4529-a4e4-8d582e2e4c77"
        DisplayName = "KV-CertRenewal-Audit"
        Frameworks = "MCSB DP-7"
    },
    @{
        Name = "Resource logs in Key Vault should be enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/cf820ca0-f99e-4f3e-84fb-66e913812d21"
        DisplayName = "KV-DiagnosticLogging-Audit"
        Frameworks = "MCSB LT-3, CIS"
    }
)

$assignedCount = 0
$errorCount = 0
$skippedCount = 0

foreach ($policy in $policies) {
    try {
        Write-Host "  [$($assignedCount + 1)/$($policies.Count)] $($policy.Name)..." -ForegroundColor Yellow
        
        if ($WhatIfPreference) {
            Write-Host "    [WhatIf] Would assign: $($policy.DisplayName)" -ForegroundColor Cyan
            Write-Host "    [WhatIf] Frameworks: $($policy.Frameworks)" -ForegroundColor Gray
            $skippedCount++
            continue
        }
        
        $policyDef = Get-AzPolicyDefinition -Id $policy.Id -ErrorAction Stop
        
        # Check if assignment already exists
        $existingAssignment = Get-AzPolicyAssignment -Name $policy.DisplayName -Scope $scope -ErrorAction SilentlyContinue
        
        if ($existingAssignment) {
            Write-Host "    ⚠ Already assigned - skipping" -ForegroundColor Yellow
            $skippedCount++
            continue
        }
        
        $assignment = New-AzPolicyAssignment `
            -Name $policy.DisplayName `
            -DisplayName $policy.DisplayName `
            -Scope $scope `
            -PolicyDefinition $policyDef `
            -Description "Audit mode - detects non-compliant Key Vaults. Frameworks: $($policy.Frameworks)" `
            -ErrorAction Stop
        
        Write-Host "    ✓ Assigned successfully" -ForegroundColor Green
        $assignedCount++
        
        Start-Sleep -Milliseconds 500  # Throttle to avoid API limits
    }
    catch {
        Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Assignment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Total policies: $($policies.Count)" -ForegroundColor White
Write-Host "  Assigned: $assignedCount" -ForegroundColor Green
Write-Host "  Skipped: $skippedCount" -ForegroundColor Yellow
Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Gray' })

if ($assignedCount -gt 0) {
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Wait 15-30 minutes for initial compliance scan" -ForegroundColor White
    Write-Host "2. Review compliance dashboard:" -ForegroundColor White
    Write-Host "   https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance" -ForegroundColor Gray
    Write-Host "3. Identify non-compliant resources and plan remediation" -ForegroundColor White
    Write-Host "4. Run .\Remediate-ComplianceIssues.ps1 to fix common issues" -ForegroundColor White
    Write-Host "5. Consider transitioning to Deny mode after achieving compliance" -ForegroundColor White
}
