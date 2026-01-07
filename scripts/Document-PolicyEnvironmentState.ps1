<#
.SYNOPSIS
    Documents the current state of Key Vaults for before/after policy comparison.

.DESCRIPTION
    This script captures a snapshot of Key Vault configurations including:
    - Security settings (soft delete, purge protection, RBAC)
    - Network configuration (firewall rules, private endpoints)
    - Diagnostic logging status
    - Vault objects (secrets, keys, certificates) with expiration status
    - Policy compliance state
    
    Use this to:
    - Document baseline state before applying policies
    - Compare state after remediation
    - Generate compliance reports
    - Track policy enforcement impact

.PARAMETER ResourceGroupName
    Resource group name containing Key Vaults to document.

.PARAMETER OutputPath
    Path for output report (default: policy-environment-state-{timestamp}.json).

.PARAMETER IncludeCompliance
    Include Azure Policy compliance state (requires policy assignments).

.EXAMPLE
    .\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline"
    
    Documents all Key Vaults in the resource group.

.EXAMPLE
    .\Document-PolicyEnvironmentState.ps1 -ResourceGroupName "rg-policy-baseline" -IncludeCompliance
    
    Documents vaults and includes Azure Policy compliance results.

.NOTES
    Author: Azure Policy Testing Framework
    Version: 1.0.0
    Date: 2026-01-06
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeCompliance
)

$ErrorActionPreference = 'Stop'

Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Resources -ErrorAction Stop
Import-Module Az.KeyVault -ErrorAction Stop

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Key Vault Environment State Documentation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set default output path
if (-not $OutputPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path (Get-Location) "policy-environment-state-$timestamp.json"
}

# Get all Key Vaults in resource group
Write-Host "Scanning resource group: $ResourceGroupName" -ForegroundColor Yellow
$vaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName

if ($vaults.Count -eq 0) {
    Write-Host "No Key Vaults found in resource group." -ForegroundColor Red
    exit
}

Write-Host "Found $($vaults.Count) Key Vault(s)" -ForegroundColor Green
Write-Host ""

$stateReport = @{
    CaptureDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    ResourceGroup = $ResourceGroupName
    VaultCount = $vaults.Count
    Vaults = @()
}

foreach ($vault in $vaults) {
    Write-Host "Documenting: $($vault.VaultName)..." -ForegroundColor Cyan
    
    # Get detailed vault properties
    $vaultDetails = Get-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $ResourceGroupName
    
    $vaultState = @{
        Name = $vault.VaultName
        ResourceId = $vault.ResourceId
        Location = $vault.Location
        Tags = $vault.Tags
        
        Security = @{
            SoftDeleteEnabled = $vaultDetails.EnableSoftDelete
            PurgeProtectionEnabled = $vaultDetails.EnablePurgeProtection
            RbacAuthorizationEnabled = $vaultDetails.EnableRbacAuthorization
        }
        
        Network = @{
            PublicNetworkAccess = $vaultDetails.PublicNetworkAccess
            DefaultAction = $vaultDetails.NetworkAcls.DefaultAction
            IpRules = @($vaultDetails.NetworkAcls.IpAddressRanges)
            VirtualNetworkRules = @($vaultDetails.NetworkAcls.VirtualNetworkResourceIds)
            Bypass = $vaultDetails.NetworkAcls.Bypass
        }
        
        Objects = @{
            Secrets = @()
            Keys = @()
            Certificates = @()
        }
        
        Compliance = @{}
    }
    
    # Get vault objects
    try {
        # Secrets
        $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName
        foreach ($secret in $secrets) {
            $secretDetail = Get-AzKeyVaultSecret -VaultName $vault.VaultName -Name $secret.Name
            $vaultState.Objects.Secrets += @{
                Name = $secret.Name
                Enabled = $secret.Enabled
                Expires = if ($secret.Expires) { $secret.Expires.ToString("yyyy-MM-dd") } else { $null }
                HasExpiration = $null -ne $secret.Expires
                ContentType = $secret.ContentType
                Created = $secret.Created.ToString("yyyy-MM-dd")
            }
        }
        Write-Host "  ✓ Secrets: $($secrets.Count)" -ForegroundColor Gray
        
        # Keys
        $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName
        foreach ($key in $keys) {
            $keyDetail = Get-AzKeyVaultKey -VaultName $vault.VaultName -Name $key.Name
            $vaultState.Objects.Keys += @{
                Name = $key.Name
                Enabled = $key.Enabled
                Expires = if ($key.Expires) { $key.Expires.ToString("yyyy-MM-dd") } else { $null }
                HasExpiration = $null -ne $key.Expires
                KeyType = $key.KeyType
                KeySize = $key.KeySize
                CurveName = $key.CurveName
                Created = $key.Created.ToString("yyyy-MM-dd")
            }
        }
        Write-Host "  ✓ Keys: $($keys.Count)" -ForegroundColor Gray
        
        # Certificates
        $certs = Get-AzKeyVaultCertificate -VaultName $vault.VaultName
        foreach ($cert in $certs) {
            $vaultState.Objects.Certificates += @{
                Name = $cert.Name
                Enabled = $cert.Enabled
                Expires = if ($cert.Expires) { $cert.Expires.ToString("yyyy-MM-dd") } else { $null }
                HasExpiration = $null -ne $cert.Expires
                Issuer = $cert.Certificate.Issuer
                SubjectName = $cert.Certificate.SubjectName.Name
                Created = $cert.Created.ToString("yyyy-MM-dd")
            }
        }
        Write-Host "  ✓ Certificates: $($certs.Count)" -ForegroundColor Gray
        
    } catch {
        Write-Host "  ⚠ Unable to list vault objects (permissions required)" -ForegroundColor Yellow
    }
    
    # Get policy compliance (if requested)
    if ($IncludeCompliance) {
        try {
            $complianceStates = Get-AzPolicyState -ResourceId $vault.ResourceId -Top 50
            $vaultState.Compliance = @{
                TotalPolicies = $complianceStates.Count
                Compliant = ($complianceStates | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
                NonCompliant = ($complianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
                Policies = @()
            }
            
            foreach ($state in $complianceStates) {
                $vaultState.Compliance.Policies += @{
                    PolicyName = $state.PolicyDefinitionName
                    ComplianceState = $state.ComplianceState
                    PolicyDefinitionId = $state.PolicyDefinitionId
                }
            }
            Write-Host "  ✓ Compliance: $($vaultState.Compliance.Compliant)/$($vaultState.Compliance.TotalPolicies) compliant" -ForegroundColor Gray
        } catch {
            Write-Host "  ⚠ Compliance data unavailable (policies may not be assigned)" -ForegroundColor Yellow
        }
    }
    
    # Assess violations
    $violations = @()
    if (-not $vaultState.Security.RbacAuthorizationEnabled) { $violations += "NoRBAC" }
    if (-not $vaultState.Security.PurgeProtectionEnabled) { $violations += "NoPurgeProtection" }
    if ($vaultState.Network.PublicNetworkAccess -eq 'Enabled' -and 
        $vaultState.Network.DefaultAction -eq 'Allow') { $violations += "PublicAccess" }
    
    $objectsWithoutExpiration = 0
    $objectsWithoutExpiration += ($vaultState.Objects.Secrets | Where-Object { -not $_.HasExpiration }).Count
    $objectsWithoutExpiration += ($vaultState.Objects.Keys | Where-Object { -not $_.HasExpiration }).Count
    if ($objectsWithoutExpiration -gt 0) { $violations += "MissingExpiration" }
    
    $vaultState.Violations = $violations
    $vaultState.IsCompliant = $violations.Count -eq 0
    
    if ($vaultState.IsCompliant) {
        Write-Host "  ✓ Status: COMPLIANT" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Status: NON-COMPLIANT [$($violations -join ', ')]" -ForegroundColor Red
    }
    
    $stateReport.Vaults += $vaultState
    Write-Host ""
}

# Generate summary statistics
$compliantVaults = @($stateReport.Vaults | Where-Object { $_.IsCompliant })
$nonCompliantVaults = @($stateReport.Vaults | Where-Object { -not $_.IsCompliant })
$compliantCount = $compliantVaults.Count
$nonCompliantCount = $nonCompliantVaults.Count

$stateReport.Summary = @{
    TotalVaults = $vaults.Count
    CompliantVaults = $compliantCount
    NonCompliantVaults = $nonCompliantCount
    
    SecurityFeatures = @{
        SoftDeleteEnabled = ($stateReport.Vaults | Where-Object { $_.Security.SoftDeleteEnabled }).Count
        PurgeProtectionEnabled = ($stateReport.Vaults | Where-Object { $_.Security.PurgeProtectionEnabled }).Count
        RbacEnabled = ($stateReport.Vaults | Where-Object { $_.Security.RbacAuthorizationEnabled }).Count
    }
    
    Objects = @{
        TotalSecrets = ($stateReport.Vaults.Objects.Secrets | Measure-Object).Count
        SecretsWithExpiration = ($stateReport.Vaults.Objects.Secrets | Where-Object { $_.HasExpiration } | Measure-Object).Count
        TotalKeys = ($stateReport.Vaults.Objects.Keys | Measure-Object).Count
        KeysWithExpiration = ($stateReport.Vaults.Objects.Keys | Where-Object { $_.HasExpiration } | Measure-Object).Count
        TotalCertificates = ($stateReport.Vaults.Objects.Certificates | Measure-Object).Count
    }
    
    CommonViolations = @{}
}

# Count violations
$allViolations = $stateReport.Vaults.Violations | Group-Object | Sort-Object Count -Descending
foreach ($violation in $allViolations) {
    $stateReport.Summary.CommonViolations[$violation.Name] = $violation.Count
}

# Save report
$stateReport | ConvertTo-Json -Depth 10 | Set-Content $OutputPath
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Vaults: $($stateReport.Summary.TotalVaults)" -ForegroundColor Gray
Write-Host "Compliant: $($stateReport.Summary.CompliantVaults)" -ForegroundColor Green
Write-Host "Non-Compliant: $($stateReport.Summary.NonCompliantVaults)" -ForegroundColor Red
Write-Host ""
Write-Host "Security Features:" -ForegroundColor Yellow
Write-Host "  Soft Delete: $($stateReport.Summary.SecurityFeatures.SoftDeleteEnabled)/$($stateReport.Summary.TotalVaults)" -ForegroundColor Gray
Write-Host "  Purge Protection: $($stateReport.Summary.SecurityFeatures.PurgeProtectionEnabled)/$($stateReport.Summary.TotalVaults)" -ForegroundColor Gray
Write-Host "  RBAC Enabled: $($stateReport.Summary.SecurityFeatures.RbacEnabled)/$($stateReport.Summary.TotalVaults)" -ForegroundColor Gray
Write-Host ""
Write-Host "Vault Objects:" -ForegroundColor Yellow
Write-Host "  Secrets: $($stateReport.Summary.Objects.TotalSecrets) ($($stateReport.Summary.Objects.SecretsWithExpiration) with expiration)" -ForegroundColor Gray
Write-Host "  Keys: $($stateReport.Summary.Objects.TotalKeys) ($($stateReport.Summary.Objects.KeysWithExpiration) with expiration)" -ForegroundColor Gray
Write-Host "  Certificates: $($stateReport.Summary.Objects.TotalCertificates)" -ForegroundColor Gray
Write-Host ""
if ($stateReport.Summary.CommonViolations.Count -gt 0) {
    Write-Host "Common Violations:" -ForegroundColor Red
    foreach ($v in $stateReport.Summary.CommonViolations.GetEnumerator()) {
        Write-Host "  $($v.Key): $($v.Value) vault(s)" -ForegroundColor Red
    }
    Write-Host ""
}
Write-Host "Report saved to: $OutputPath" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
