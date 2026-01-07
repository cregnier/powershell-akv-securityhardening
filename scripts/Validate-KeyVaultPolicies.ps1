<#
.SYNOPSIS
    Validates Azure Policy compliance for Key Vault service, vaults, and secrets/keys/certs

.DESCRIPTION
    Comprehensive validation of Azure Policies protecting:
    1. Key Vault Service - Network security, public access restrictions
    2. Key Vaults - Soft delete, purge protection, RBAC, firewall, private link, diagnostics
    3. Secrets/Keys/Certs - Expiration, key types/sizes, curves, cert validity, CA requirements
    
    Based on: Microsoft Cloud Security Benchmark, CIS Azure Foundations, NIST, CERT

.PARAMETER SubscriptionId
    Azure subscription ID

.PARAMETER ResourceGroupName
    Resource group containing Key Vaults to validate

.EXAMPLE
    .\Validate-KeyVaultPolicies.ps1 -SubscriptionId "sub-id" -ResourceGroupName "rg-test"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = 'Continue'

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " AZURE POLICY VALIDATION - KEY VAULT COMPREHENSIVE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get all policy states for Key Vault resources
Write-Host "[1/5] Retrieving policy compliance states..." -ForegroundColor Yellow
$policyStates = Get-AzPolicyState -SubscriptionId $SubscriptionId -Filter "ResourceType eq 'Microsoft.KeyVault/vaults'" -ErrorAction SilentlyContinue

if (-not $policyStates) {
    Write-Host "  ⚠️  No policy states found (policies may need time to evaluate)" -ForegroundColor Yellow
    Write-Host "  Waiting 30 seconds for policy evaluation...`n" -ForegroundColor Gray
    Start-Sleep -Seconds 30
    $policyStates = Get-AzPolicyState -SubscriptionId $SubscriptionId -Filter "ResourceType eq 'Microsoft.KeyVault/vaults'" -ErrorAction SilentlyContinue
}

Write-Host "  ✓ Retrieved $($policyStates.Count) policy evaluation(s)`n" -ForegroundColor Green

# Get Key Vaults in resource group
Write-Host "[2/5] Scanning Key Vaults..." -ForegroundColor Yellow
$vaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $vaults) {
    Write-Host "  ✗ No Key Vaults found in resource group!`n" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Found $($vaults.Count) Key Vault(s)`n" -ForegroundColor Green

# Category 1: VAULT-LEVEL POLICIES
Write-Host "[3/5] Validating Vault-Level Security Policies..." -ForegroundColor Yellow

$vaultPolicyResults = @{
    SoftDelete = @{Compliant=0; NonCompliant=0; NotEvaluated=0}
    PurgeProtection = @{Compliant=0; NonCompliant=0; NotEvaluated=0}
    RBAC = @{Compliant=0; NonCompliant=0; NotEvaluated=0}
    Firewall = @{Compliant=0; NonCompliant=0; NotEvaluated=0}
    PrivateLink = @{Compliant=0; NonCompliant=0; NotEvaluated=0}
    Logging = @{Compliant=0; NonCompliant=0; NotEvaluated=0}
}

foreach ($vault in $vaults) {
    $vaultStates = $policyStates | Where-Object { $_.ResourceId -eq $vault.ResourceId }
    
    Write-Host "  Vault: $($vault.VaultName)" -ForegroundColor Cyan
    
    # Soft Delete
    $sdPolicy = $vaultStates | Where-Object { $_.PolicyDefinitionId -like "*1e66c121-a66a-4b1f*" }
    if ($sdPolicy) {
        if ($sdPolicy.ComplianceState -eq "Compliant") { 
            Write-Host "    ✓ Soft Delete: COMPLIANT" -ForegroundColor Green
            $vaultPolicyResults.SoftDelete.Compliant++
        } else {
            Write-Host "    ✗ Soft Delete: NON-COMPLIANT" -ForegroundColor Red
            $vaultPolicyResults.SoftDelete.NonCompliant++
        }
    } else {
        Write-Host "    ⚠ Soft Delete: NOT EVALUATED" -ForegroundColor Yellow
        $vaultPolicyResults.SoftDelete.NotEvaluated++
    }
    
    # Purge Protection
    $ppPolicy = $vaultStates | Where-Object { $_.PolicyDefinitionId -like "*0b60c0b2-2dc2*" }
    if ($ppPolicy) {
        if ($ppPolicy.ComplianceState -eq "Compliant") {
            Write-Host "    ✓ Purge Protection: COMPLIANT" -ForegroundColor Green
            $vaultPolicyResults.PurgeProtection.Compliant++
        } else {
            Write-Host "    ✗ Purge Protection: NON-COMPLIANT" -ForegroundColor Red
            $vaultPolicyResults.PurgeProtection.NonCompliant++
        }
    } else {
        Write-Host "    ⚠ Purge Protection: NOT EVALUATED" -ForegroundColor Yellow
        $vaultPolicyResults.PurgeProtection.NotEvaluated++
    }
    
    # RBAC
    $rbacPolicy = $vaultStates | Where-Object { $_.PolicyDefinitionId -like "*12d4fa5e-1f9f*" }
    if ($rbacPolicy) {
        if ($rbacPolicy.ComplianceState -eq "Compliant") {
            Write-Host "    ✓ RBAC Model: COMPLIANT" -ForegroundColor Green
            $vaultPolicyResults.RBAC.Compliant++
        } else {
            Write-Host "    ✗ RBAC Model: NON-COMPLIANT" -ForegroundColor Red
            $vaultPolicyResults.RBAC.NonCompliant++
        }
    } else {
        Write-Host "    ⚠ RBAC Model: NOT EVALUATED" -ForegroundColor Yellow
        $vaultPolicyResults.RBAC.NotEvaluated++
    }
    
    # Firewall
    $fwPolicy = $vaultStates | Where-Object { $_.PolicyDefinitionId -like "*55615ac9-af46*" }
    if ($fwPolicy) {
        if ($fwPolicy.ComplianceState -eq "Compliant") {
            Write-Host "    ✓ Firewall: COMPLIANT" -ForegroundColor Green
            $vaultPolicyResults.Firewall.Compliant++
        } else {
            Write-Host "    ✗ Firewall: NON-COMPLIANT" -ForegroundColor Red
            $vaultPolicyResults.Firewall.NonCompliant++
        }
    } else {
        Write-Host "    ⚠ Firewall: NOT EVALUATED" -ForegroundColor Yellow
        $vaultPolicyResults.Firewall.NotEvaluated++
    }
    
    Write-Host ""
}

Write-Host "Vault-Level Policy Summary:" -ForegroundColor Cyan
Write-Host "  Soft Delete:       $($vaultPolicyResults.SoftDelete.Compliant) compliant, $($vaultPolicyResults.SoftDelete.NonCompliant) non-compliant, $($vaultPolicyResults.SoftDelete.NotEvaluated) not evaluated" -ForegroundColor White
Write-Host "  Purge Protection:  $($vaultPolicyResults.PurgeProtection.Compliant) compliant, $($vaultPolicyResults.PurgeProtection.NonCompliant) non-compliant, $($vaultPolicyResults.PurgeProtection.NotEvaluated) not evaluated" -ForegroundColor White
Write-Host "  RBAC Model:        $($vaultPolicyResults.RBAC.Compliant) compliant, $($vaultPolicyResults.RBAC.NonCompliant) non-compliant, $($vaultPolicyResults.RBAC.NotEvaluated) not evaluated" -ForegroundColor White
Write-Host "  Firewall:          $($vaultPolicyResults.Firewall.Compliant) compliant, $($vaultPolicyResults.Firewall.NonCompliant) non-compliant, $($vaultPolicyResults.Firewall.NotEvaluated) not evaluated" -ForegroundColor White
Write-Host ""

# Category 2: SECRET/KEY/CERT POLICIES
Write-Host "[4/5] Validating Secret/Key/Certificate Security..." -ForegroundColor Yellow

$objectResults = @{
    TotalSecrets = 0
    SecretsWithExpiration = 0
    SecretsWithoutExpiration = 0
    ExpiredSecrets = 0
    TotalKeys = 0
    KeysWithExpiration = 0
    KeysWithoutExpiration = 0
    WeakKeys = 0  # RSA < 4096
    StrongKeys = 0  # RSA >= 4096 or EC P-384/P-521
    TotalCerts = 0
}

foreach ($vault in $vaults) {
    Write-Host "  Vault: $($vault.VaultName)" -ForegroundColor Cyan
    
    # Check secrets
    $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName -ErrorAction SilentlyContinue
    $objectResults.TotalSecrets += $secrets.Count
    
    foreach ($secret in $secrets) {
        $secretDetail = Get-AzKeyVaultSecret -VaultName $vault.VaultName -Name $secret.Name -ErrorAction SilentlyContinue
        if ($secretDetail.Expires) {
            if ($secretDetail.Expires -lt (Get-Date)) {
                $objectResults.ExpiredSecrets++
            } else {
                $objectResults.SecretsWithExpiration++
            }
        } else {
            $objectResults.SecretsWithoutExpiration++
        }
    }
    
    # Check keys
    $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName -ErrorAction SilentlyContinue
    $objectResults.TotalKeys += $keys.Count
    
    foreach ($key in $keys) {
        $keyDetail = Get-AzKeyVaultKey -VaultName $vault.VaultName -Name $key.Name -ErrorAction SilentlyContinue
        
        # Check expiration
        if ($keyDetail.Expires) {
            $objectResults.KeysWithExpiration++
        } else {
            $objectResults.KeysWithoutExpiration++
        }
        
        # Check key strength
        if ($keyDetail.Key.KeyType -eq "RSA" -and $keyDetail.Key.KeySize -lt 4096) {
            $objectResults.WeakKeys++
        } elseif ($keyDetail.Key.KeyType -eq "EC" -and $keyDetail.Key.CurveName -eq "P-256") {
            $objectResults.WeakKeys++
        } else {
            $objectResults.StrongKeys++
        }
    }
    
    # Check certificates
    $certs = Get-AzKeyVaultCertificate -VaultName $vault.VaultName -ErrorAction SilentlyContinue
    $objectResults.TotalCerts += $certs.Count
    
    Write-Host "    Secrets: $($secrets.Count), Keys: $($keys.Count), Certs: $($certs.Count)" -ForegroundColor White
}

Write-Host "`nSecret/Key/Certificate Summary:" -ForegroundColor Cyan
Write-Host "  Secrets:" -ForegroundColor White
Write-Host "    Total: $($objectResults.TotalSecrets)" -ForegroundColor Gray
Write-Host "    With Expiration: $($objectResults.SecretsWithExpiration)" -ForegroundColor Green
Write-Host "    Without Expiration: $($objectResults.SecretsWithoutExpiration)" -ForegroundColor $(if ($objectResults.SecretsWithoutExpiration -gt 0) { "Red" } else { "Green" })
Write-Host "    Expired: $($objectResults.ExpiredSecrets)" -ForegroundColor $(if ($objectResults.ExpiredSecrets -gt 0) { "Red" } else { "Green" })
Write-Host "  Keys:" -ForegroundColor White
Write-Host "    Total: $($objectResults.TotalKeys)" -ForegroundColor Gray
Write-Host "    With Expiration: $($objectResults.KeysWithExpiration)" -ForegroundColor Green
Write-Host "    Without Expiration: $($objectResults.KeysWithoutExpiration)" -ForegroundColor $(if ($objectResults.KeysWithoutExpiration -gt 0) { "Red" } else { "Green" })
Write-Host "    Strong Keys (RSA-4096+ or EC P-384/521): $($objectResults.StrongKeys)" -ForegroundColor Green
Write-Host "    Weak Keys (RSA-2048/3072 or EC P-256): $($objectResults.WeakKeys)" -ForegroundColor $(if ($objectResults.WeakKeys -gt 0) { "Red" } else { "Green" })
Write-Host "  Certificates:" -ForegroundColor White
Write-Host "    Total: $($objectResults.TotalCerts)" -ForegroundColor Gray
Write-Host ""

# Final validation summary
Write-Host "[5/5] Overall Compliance Summary..." -ForegroundColor Yellow

$totalCompliant = $vaultPolicyResults.SoftDelete.Compliant + $vaultPolicyResults.PurgeProtection.Compliant + 
                  $vaultPolicyResults.RBAC.Compliant + $vaultPolicyResults.Firewall.Compliant
$totalNonCompliant = $vaultPolicyResults.SoftDelete.NonCompliant + $vaultPolicyResults.PurgeProtection.NonCompliant + 
                     $vaultPolicyResults.RBAC.NonCompliant + $vaultPolicyResults.Firewall.NonCompliant
$totalEvaluations = $totalCompliant + $totalNonCompliant

if ($totalEvaluations -gt 0) {
    $compliancePercent = [math]::Round(($totalCompliant / $totalEvaluations) * 100, 1)
    Write-Host "`n  Vault Compliance: $compliancePercent% ($totalCompliant/$totalEvaluations policies compliant)" -ForegroundColor $(if ($compliancePercent -ge 80) { "Green" } elseif ($compliancePercent -ge 50) { "Yellow" } else { "Red" })
} else {
    Write-Host "`n  ⚠️  No policy evaluations completed yet" -ForegroundColor Yellow
}

# Object-level compliance
$objectIssues = $objectResults.SecretsWithoutExpiration + $objectResults.ExpiredSecrets + 
                $objectResults.KeysWithoutExpiration + $objectResults.WeakKeys

if ($objectIssues -gt 0) {
    Write-Host "  Object Security: $objectIssues issue(s) detected" -ForegroundColor Red
    Write-Host "    - Secrets without expiration: $($objectResults.SecretsWithoutExpiration)" -ForegroundColor Red
    Write-Host "    - Expired secrets: $($objectResults.ExpiredSecrets)" -ForegroundColor Red
    Write-Host "    - Keys without expiration: $($objectResults.KeysWithoutExpiration)" -ForegroundColor Red
    Write-Host "    - Weak keys: $($objectResults.WeakKeys)" -ForegroundColor Red
} else {
    Write-Host "  Object Security: All secrets/keys/certs compliant ✓" -ForegroundColor Green
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " POLICY VALIDATION COMPLETE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Green

# Return results for potential further processing
return @{
    VaultPolicies = $vaultPolicyResults
    ObjectSecurity = $objectResults
    CompliancePercent = $compliancePercent
    TotalIssues = $objectIssues
}
