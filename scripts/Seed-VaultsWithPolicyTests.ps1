<#
.SYNOPSIS
    Enhances Key Vaults with comprehensive secrets, keys, and certificates for Azure Policy testing

.DESCRIPTION
    Adds realistic policy-compliant and policy-violating content to test vaults:
    - Secrets: with/without expiration, expired secrets
    - Keys: RSA (various sizes), EC (various curves), with/without expiration
    - Certificates: self-signed with various validity periods and configurations
    
    Tests Azure Policies for:
    1. Key Vault service security (network rules, public access)
    2. Key vault configuration (soft delete, purge protection, RBAC, firewall, logging)
    3. Secret/key/cert security (expiration, key types/sizes, cert validity, CA requirements)
    
    Based on Microsoft Cloud Security Benchmark (MCSB), CIS Azure Foundations, NIST, and CERT guidance.

.PARAMETER ResourceGroupName
    Resource group containing the Key Vaults

.PARAMETER VaultNames
    Array of vault names to seed with content

.EXAMPLE
    .\Seed-VaultsWithPolicyTests.ps1 -ResourceGroupName "rg-test" -VaultNames @("kv-vault1", "kv-vault2")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string[]]$VaultNames
)

$ErrorActionPreference = 'Continue'

Write-Host "`n═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " SEEDING VAULTS WITH POLICY TEST CONTENT" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get current user for role assignments
$currentUser = Get-AzADUser -SignedIn
$currentUserId = $currentUser.Id

foreach ($vaultName in $VaultNames) {
    Write-Host "Processing: $vaultName" -ForegroundColor Yellow
    
    try {
        $vault = Get-AzKeyVault -VaultName $vaultName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        
        # Ensure Key Vault Administrator role is assigned
        Write-Host "  ✓ Setting up Key Vault Administrator role..." -ForegroundColor Gray
        $existingRole = Get-AzRoleAssignment -ObjectId $currentUserId -Scope $vault.ResourceId -RoleDefinitionName "Key Vault Administrator" -ErrorAction SilentlyContinue
        if (-not $existingRole) {
            New-AzRoleAssignment -ObjectId $currentUserId -RoleDefinitionName "Key Vault Administrator" -Scope $vault.ResourceId -ErrorAction Stop | Out-Null
            Write-Host "    Role assigned successfully" -ForegroundColor Green
            Start-Sleep -Seconds 10  # Allow RBAC to propagate
        } else {
            Write-Host "    Role already assigned" -ForegroundColor Gray
        }
        
        # Determine vault type from tags
        $vaultType = $vault.Tags["Type"]
        $violations = if ($vault.Tags["Violations"]) { $vault.Tags["Violations"].Split(',') } else { @() }
        
        Write-Host "  Vault Type: $vaultType" -ForegroundColor Cyan
        
        if ($vaultType -eq "Compliant") {
            # Add COMPLIANT content
            Write-Host "  Adding compliant secrets/keys/certs..." -ForegroundColor Green
            
            # Compliant Secrets (with expiration)
            Set-AzKeyVaultSecret -VaultName $vaultName -Name "CompanyDatabase-Password" `
                -SecretValue (ConvertTo-SecureString "SecureP@ssw0rd!2026" -AsPlainText -Force) `
                -Expires ((Get-Date).AddMonths(6)) `
                -ContentType "password" `
                -Tag @{Purpose="Production"; Compliant="Yes"} -ErrorAction SilentlyContinue | Out-Null
            
            Set-AzKeyVaultSecret -VaultName $vaultName -Name "ThirdParty-APIKey" `
                -SecretValue (ConvertTo-SecureString "sk-live-9876543210abcdef" -AsPlainText -Force) `
                -Expires ((Get-Date).AddMonths(3)) `
                -ContentType "apikey" `
                -Tag @{Purpose="Integration"; Compliant="Yes"} -ErrorAction SilentlyContinue | Out-Null
            
            # Compliant Keys (RSA-4096, EC P-384 with expiration)
            Add-AzKeyVaultKey -VaultName $vaultName -Name "DataEncryption-RSA4096" `
                -Destination Software -KeyType RSA -Size 4096 `
                -Expires ((Get-Date).AddYears(2)) `
                -Tag @{Purpose="Encryption"; Compliant="Yes"} -ErrorAction SilentlyContinue | Out-Null
            
            Add-AzKeyVaultKey -VaultName $vaultName -Name "DigitalSignature-P384" `
                -Destination Software -KeyType EC -CurveName P-384 `
                -Expires ((Get-Date).AddYears(1)) `
                -Tag @{Purpose="Signing"; Compliant="Yes"} -ErrorAction SilentlyContinue | Out-Null
            
            Add-AzKeyVaultKey -VaultName $vaultName -Name "ECDH-P521" `
                -Destination Software -KeyType EC -CurveName P-521 `
                -Expires ((Get-Date).AddMonths(18)) `
                -Tag @{Purpose="KeyExchange"; Compliant="Yes"} -ErrorAction SilentlyContinue | Out-Null
            
            Write-Host "    ✓ Added: 2 secrets, 3 keys (all compliant)" -ForegroundColor Green
            
        } elseif ($vaultType -eq "NonCompliant") {
            # Add NON-COMPLIANT content based on violation types
            Write-Host "  Adding non-compliant secrets/keys for policy testing..." -ForegroundColor Yellow
            Write-Host "  Target violations: $($violations -join ', ')" -ForegroundColor Gray
            
            # Secrets without expiration (violates secret expiration policy)
            Set-AzKeyVaultSecret -VaultName $vaultName -Name "Legacy-ConnectionString" `
                -SecretValue (ConvertTo-SecureString "Server=old.db;User=sa;Password=weak" -AsPlainText -Force) `
                -ContentType "connectionstring" `
                -Tag @{Purpose="Legacy"; Compliant="No"; Violation="NoExpiration"} -ErrorAction SilentlyContinue | Out-Null
            
            # Expired secret (violates active secret policy)
            Set-AzKeyVaultSecret -VaultName $vaultName -Name "Expired-Token" `
                -SecretValue (ConvertTo-SecureString "old-jwt-token-12345" -AsPlainText -Force) `
                -Expires ((Get-Date).AddDays(-60)) `
                -ContentType "token" `
                -Tag @{Purpose="Testing"; Compliant="No"; Violation="Expired"} -ErrorAction SilentlyContinue | Out-Null
            
            # Weak RSA key - 2048 bits (violates minimum key size policy)
            Add-AzKeyVaultKey -VaultName $vaultName -Name "WeakEncryption-RSA2048" `
                -Destination Software -KeyType RSA -Size 2048 `
                -Tag @{Purpose="Testing"; Compliant="No"; Violation="WeakKeySize"} -ErrorAction SilentlyContinue | Out-Null
            
            # EC key with non-recommended curve P-256 (some policies prefer P-384/P-521)
            Add-AzKeyVaultKey -VaultName $vaultName -Name "WeakEC-P256" `
                -Destination Software -KeyType EC -CurveName P-256 `
                -Tag @{Purpose="Testing"; Compliant="No"; Violation="WeakCurve"} -ErrorAction SilentlyContinue | Out-Null
            
            # Key without expiration (violates key expiration policy)
            Add-AzKeyVaultKey -VaultName $vaultName -Name "NoExpiry-RSA3072" `
                -Destination Software -KeyType RSA -Size 3072 `
                -Tag @{Purpose="Testing"; Compliant="No"; Violation="NoExpiration"} -ErrorAction SilentlyContinue | Out-Null
            
            # Create self-signed certificate with violations
            $certPolicy = New-AzKeyVaultCertificatePolicy `
                -SubjectName "CN=test.contoso.com" `
                -IssuerName Self `
                -ValidityInMonths 24 `
                -ReuseKeyOnRenewal:$true `
                -KeyType RSA -KeySize 2048 `
                -SecretContentType "application/x-pkcs12"
            
            Add-AzKeyVaultCertificate -VaultName $vaultName -Name "SelfSigned-InvalidCA" `
                -CertificatePolicy $certPolicy `
                -Tag @{Purpose="Testing"; Compliant="No"; Violation="SelfSigned,WeakKeySize,LongValidity"} -ErrorAction SilentlyContinue | Out-Null
            
            Write-Host "    ✓ Added: 2 secrets, 3 keys, 1 cert (all non-compliant)" -ForegroundColor Yellow
            Write-Host "      Violations:" -ForegroundColor Gray
            Write-Host "        - Secrets without expiration" -ForegroundColor Red
            Write-Host "        - Expired secret" -ForegroundColor Red
            Write-Host "        - Weak RSA-2048 key" -ForegroundColor Red
            Write-Host "        - Weak EC P-256 curve" -ForegroundColor Red
            Write-Host "        - Key without expiration" -ForegroundColor Red
            Write-Host "        - Self-signed cert (not from approved CA)" -ForegroundColor Red
        }
        
        # List final inventory
        $secrets = Get-AzKeyVaultSecret -VaultName $vaultName -ErrorAction SilentlyContinue
        $keys = Get-AzKeyVaultKey -VaultName $vaultName -ErrorAction SilentlyContinue
        $certs = Get-AzKeyVaultCertificate -VaultName $vaultName -ErrorAction SilentlyContinue
        
        Write-Host "  Inventory: Secrets=$($secrets.Count), Keys=$($keys.Count), Certs=$($certs.Count)" -ForegroundColor Cyan
        Write-Host ""
        
    } catch {
        Write-Host "  ✗ Error processing vault: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " VAULT SEEDING COMPLETE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════`n" -ForegroundColor Green

