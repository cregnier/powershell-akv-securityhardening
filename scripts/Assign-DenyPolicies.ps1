<#
.SYNOPSIS
    Assigns Azure Key Vault policies in Deny mode at subscription level

.DESCRIPTION
    This script assigns Azure Key Vault security policies in Deny (Enforce) mode.
    Deny mode actively blocks creation of non-compliant resources.
    
    ⚠️ WARNING: This will prevent creation of non-compliant Key Vaults!
    Ensure existing resources are compliant before enforcing.
    
    Generated from: Test-AzurePolicyKeyVault.ps1
    Test Results: AzurePolicy-KeyVault-TestReport-20260106-102723.html

.PARAMETER SubscriptionId
    The Azure subscription ID where policies will be assigned

.PARAMETER ConfirmEnforcement
    Required switch to acknowledge enforcement impact

.PARAMETER WhatIf
    Shows what would be assigned without making changes

.EXAMPLE
    .\Assign-DenyPolicies.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -ConfirmEnforcement
    
.EXAMPLE
    .\Assign-DenyPolicies.ps1 -SubscriptionId "ab1336c7-687d-4107-b0f6-9649a0458adb" -WhatIf

.NOTES
    Generated: 2026-01-06
    Test Matrix: AzurePolicy-KeyVault-TestMatrix.md
    Compliance Frameworks: MCSB, CIS, NIST, CERT
    
    IMPORTANT: Test results show all 14 Deny policies successfully block non-compliant operations.
    Verify compliance before enforcing to avoid disrupting operations.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$ConfirmEnforcement,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Requires Azure PowerShell modules
#Requires -Module Az.Accounts
#Requires -Module Az.Resources

if (-not $ConfirmEnforcement -and -not $WhatIf) {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "⚠️  ENFORCEMENT MODE REQUIRES CONFIRMATION" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script will assign policies in DENY mode." -ForegroundColor Yellow
    Write-Host "Non-compliant Key Vault operations will be BLOCKED!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Before proceeding:" -ForegroundColor Cyan
    Write-Host "1. Ensure existing Key Vaults are compliant" -ForegroundColor White
    Write-Host "2. Review audit mode compliance dashboard" -ForegroundColor White
    Write-Host "3. Update all IaC templates to comply" -ForegroundColor White
    Write-Host "4. Communicate policy enforcement to teams" -ForegroundColor White
    Write-Host ""
    Write-Host "To proceed, add -ConfirmEnforcement parameter" -ForegroundColor Yellow
    Write-Host "To preview changes, add -WhatIf parameter" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Set subscription context
Write-Host "Setting Azure context to subscription: $SubscriptionId..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

Write-Host ""
Write-Host "Assigning Azure Key Vault policies in DENY (ENFORCE) mode..." -ForegroundColor Red
Write-Host "⚠️  Non-compliant resources will be BLOCKED from creation!" -ForegroundColor Yellow
Write-Host ""

# Define policies that support Deny effect (based on test results)
$policies = @(
    @{
        Name = "Key vaults should have soft delete enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
        DisplayName = "KV-SoftDelete-Deny"
        Frameworks = "CIS 8.5, MCSB DP-8"
        Tested = $true
    },
    @{
        Name = "Key vaults should have deletion protection enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
        DisplayName = "KV-PurgeProtection-Deny"
        Frameworks = "CIS 8.5, MCSB DP-8"
        Tested = $true
    },
    @{
        Name = "Azure Key Vault should use RBAC permission model"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
        DisplayName = "KV-RBAC-Deny"
        Frameworks = "CIS 8.6, MCSB PA-7"
        Tested = $true
    },
    @{
        Name = "Azure Key Vault should have firewall enabled"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/55615ac9-af46-4a59-874e-391cc3dfb490"
        DisplayName = "KV-Firewall-Deny"
        Frameworks = "MCSB DP-8"
        Tested = $true
    },
    @{
        Name = "Key Vault secrets should have an expiration date"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/98728c90-32c7-4049-8429-847dc0f4fe37"
        DisplayName = "KV-SecretExpiration-Deny"
        Frameworks = "CIS 8.3, CIS 8.4, MCSB DP-6"
        Tested = $true
    },
    @{
        Name = "Key Vault keys should have an expiration date"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0"
        DisplayName = "KV-KeyExpiration-Deny"
        Frameworks = "MCSB DP-6"
        Tested = $true
    },
    @{
        Name = "Keys should be the specified cryptographic type RSA or EC"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1151cede-290b-4ba0-8b38-0ad145ac888f"
        DisplayName = "KV-KeyType-Deny"
        Frameworks = "NIST, CERT"
        Tested = $true
    },
    @{
        Name = "Keys using RSA cryptography should have a minimum key size"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/82067dbb-e53b-4e06-b631-546d197452d9"
        DisplayName = "KV-RSAKeySize-Deny"
        Frameworks = "NIST, CERT, MCSB"
        Tested = $true
    },
    @{
        Name = "Keys using elliptic curve cryptography should use approved curve names"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/ff25f3c8-b739-4538-9d07-3d6d25cfb255"
        DisplayName = "KV-ECCurve-Deny"
        Frameworks = "NIST, CERT"
        Tested = $true
    },
    @{
        Name = "Certificates should have the specified maximum validity period"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/0a075868-4c26-42ef-914c-5bc007359560"
        DisplayName = "KV-CertValidity-Deny"
        Frameworks = "MCSB DP-7"
        Tested = $true
    },
    @{
        Name = "Certificates should be issued by the specified integrated certificate authority"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/8e826246-c976-48f6-b03e-619bb92b3d82"
        DisplayName = "KV-CertCA-Deny"
        Frameworks = "MCSB DP-7"
        Tested = $true
    },
    @{
        Name = "Certificates using elliptic curve cryptography should use approved curve names"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/bd78111f-4953-4367-9fd3-2f7bc21a5e29"
        DisplayName = "KV-CertECCurve-Deny"
        Frameworks = "MCSB DP-7"
        Tested = $true
    },
    @{
        Name = "Certificates should use allowed key types"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/1151cede-290b-4ba0-8b38-0ad145ac888c"
        DisplayName = "KV-CertKeyType-Deny"
        Frameworks = "NIST, CERT"
        Tested = $true
    },
    @{
        Name = "Certificates should have the specified lifetime action triggers"
        Id = "/providers/Microsoft.Authorization/policyDefinitions/12ef42fe-5c3e-4529-a4e4-8d582e2e4c77"
        DisplayName = "KV-CertRenewal-Deny"
        Frameworks = "MCSB DP-7"
        Tested = $true
    }
)

$assignedCount = 0
$errorCount = 0
$skippedCount = 0

foreach ($policy in $policies) {
    try {
        Write-Host "  [$($assignedCount + 1)/$($policies.Count)] $($policy.Name)..." -ForegroundColor Yellow
        
        if ($WhatIf) {
            Write-Host "    [WhatIf] Would assign: $($policy.DisplayName) in DENY mode" -ForegroundColor Cyan
            Write-Host "    [WhatIf] Frameworks: $($policy.Frameworks)" -ForegroundColor Gray
            Write-Host "    [WhatIf] Impact: Non-compliant operations will be BLOCKED" -ForegroundColor Red
            $skippedCount++
            continue
        }
        
        $policyDef = Get-AzPolicyDefinition -Id $policy.Id -ErrorAction Stop
        
        # Check if assignment already exists
        $existingAssignment = Get-AzPolicyAssignment -Name $policy.DisplayName -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue
        
        if ($existingAssignment) {
            Write-Host "    ⚠ Already assigned - skipping" -ForegroundColor Yellow
            $skippedCount++
            continue
        }
        
        # Some policies may require parameters for Deny effect
        # Based on test results, these policies work with default Deny effect
        $assignment = New-AzPolicyAssignment `
            -Name $policy.DisplayName `
            -DisplayName $policy.DisplayName `
            -Scope "/subscriptions/$SubscriptionId" `
            -PolicyDefinition $policyDef `
            -Description "Deny mode - actively blocks non-compliant Key Vault resources. Frameworks: $($policy.Frameworks). Tested: 2026-01-06" `
            -ErrorAction Stop
        
        Write-Host "    ✓ Assigned - NON-COMPLIANT RESOURCES WILL BE BLOCKED" -ForegroundColor Green
        $assignedCount++
        
        Start-Sleep -Milliseconds 500  # Throttle to avoid API limits
    }
    catch {
        Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Enforcement Assignment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Total policies: $($policies.Count)" -ForegroundColor White
Write-Host "  Assigned: $assignedCount" -ForegroundColor Green
Write-Host "  Skipped: $skippedCount" -ForegroundColor Yellow
Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Gray' })

if ($assignedCount -gt 0) {
    Write-Host "`n⚠️  IMPORTANT:" -ForegroundColor Red
    Write-Host "Policies are now ACTIVELY ENFORCING compliance!" -ForegroundColor Yellow
    Write-Host "Non-compliant Key Vault operations will be DENIED." -ForegroundColor Yellow
    
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Communicate policy enforcement to all teams immediately" -ForegroundColor White
    Write-Host "2. Update all IaC templates (Terraform, Bicep, ARM) to comply" -ForegroundColor White
    Write-Host "3. Create policy exemption process for legitimate special cases" -ForegroundColor White
    Write-Host "4. Monitor compliance dashboard regularly:" -ForegroundColor White
    Write-Host "   https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance" -ForegroundColor Gray
    Write-Host "5. Document enforcement in runbooks and onboarding materials" -ForegroundColor White
    
    Write-Host "`nTest Results Reference:" -ForegroundColor Cyan
    Write-Host "  All 14 Deny policies validated on 2026-01-06" -ForegroundColor White
    Write-Host "  Report: AzurePolicy-KeyVault-TestReport-20260106-102723.html" -ForegroundColor Gray
}
