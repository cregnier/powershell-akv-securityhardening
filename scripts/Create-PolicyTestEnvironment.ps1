<#
.SYNOPSIS
    Creates a baseline pre/post policy environment for Azure Key Vault policy testing.

.DESCRIPTION
    This script creates two sets of Key Vaults:
    1. COMPLIANT vaults that meet all policy requirements (baseline "good" state)
    2. NON-COMPLIANT vaults with intentional policy violations (baseline "bad" state)
    
    Use this environment to:
    - Demonstrate policy behavior (Audit mode flags violations, Deny mode blocks creation)
    - Test remediation scripts on known non-compliant resources
    - Validate compliance scanning and reporting
    - Show before/after state when applying policies

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be created.

.PARAMETER ResourceGroupName
    Resource group name for test environment (will be created if doesn't exist).

.PARAMETER Location
    Azure region for resources (default: eastus).

.PARAMETER EnvironmentPrefix
    Prefix for resource naming (default: baseline).

.PARAMETER CreateCompliant
    Create compliant Key Vaults (default: $true).

.PARAMETER CreateNonCompliant
    Create non-compliant Key Vaults for testing (default: $true).

.PARAMETER UpdateTracking
    Update resource-tracking.json with created resources (default: $true).

.EXAMPLE
    .\Create-PolicyTestEnvironment.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-policy-baseline"
    
    Creates both compliant and non-compliant vaults in the specified resource group.

.EXAMPLE
    .\Create-PolicyTestEnvironment.ps1 -CreateNonCompliant $false
    
    Creates only compliant vaults (for production-like baseline).

.NOTES
    Author: Azure Policy Testing Framework
    Version: 1.0.0
    Date: 2026-01-06
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-policy-baseline",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentPrefix = "bl",
    
    [Parameter(Mandatory=$false)]
    [bool]$CreateCompliant = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$CreateNonCompliant = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$UpdateTracking = $true
)

$ErrorActionPreference = 'Stop'

# Import required modules
Import-Module Az.Accounts -MinimumVersion 2.0.0 -ErrorAction Stop
Import-Module Az.Resources -MinimumVersion 6.0.0 -ErrorAction Stop
Import-Module Az.KeyVault -MinimumVersion 4.0.0 -ErrorAction Stop

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Key Vault Policy Test Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Connect to Azure and set subscription
Write-Host "[Step 1/6] Connecting to Azure..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Write-Host "No Azure context found. Please login..." -ForegroundColor Yellow
    Connect-AzAccount
    $context = Get-AzContext
}

if ($SubscriptionId) {
    Write-Host "Setting subscription to: $SubscriptionId" -ForegroundColor Gray
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
} else {
    $SubscriptionId = $context.Subscription.Id
    Write-Host "Using current subscription: $SubscriptionId" -ForegroundColor Gray
}

# Step 2: Create or verify resource group
Write-Host "`n[Step 2/6] Verifying resource group..." -ForegroundColor Yellow
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Creating resource group: $ResourceGroupName in $Location" -ForegroundColor Gray
    $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-Host "✓ Resource group created" -ForegroundColor Green
} else {
    Write-Host "✓ Resource group exists: $ResourceGroupName" -ForegroundColor Green
}

# Step 3: Generate unique suffix for vault names
$uniqueSuffix = -join ((97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
Write-Host "`n[Step 3/6] Generated unique suffix: $uniqueSuffix" -ForegroundColor Yellow

# Get current user for RBAC assignments
$currentUser = Get-AzADUser -SignedIn
$currentUserId = $currentUser.Id

# Initialize tracking
$createdVaults = @()
$trackingData = @{
    CreatedDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    SubscriptionId = $SubscriptionId
    ResourceGroup = $ResourceGroupName
    Location = $Location
    EnvironmentPrefix = $EnvironmentPrefix
    CompliantVaults = @()
    NonCompliantVaults = @()
}

# Step 4: Create COMPLIANT vaults
if ($CreateCompliant) {
    Write-Host "`n[Step 4/6] Creating COMPLIANT Key Vaults..." -ForegroundColor Yellow
    Write-Host "These vaults meet all policy requirements (best practices)" -ForegroundColor Gray
    
    # Compliant Vault 1: Full security configuration
    $vault1Name = "kv-$EnvironmentPrefix-sec-$uniqueSuffix"
    Write-Host "`n  Creating: $vault1Name (Full Security)" -ForegroundColor Cyan
    try {
        $vault1 = New-AzKeyVault `
            -VaultName $vault1Name `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -EnablePurgeProtection `
            -Tag @{
                Environment = "Baseline"
                Type = "Compliant"
                Purpose = "Full Security Configuration"
                Compliance = "CIS 2.0, MCSB, PCI DSS"
            }
        
        # Assign RBAC permissions to current user
        Start-Sleep -Seconds 3
        New-AzRoleAssignment -ObjectId $currentUserId `
            -RoleDefinitionName "Key Vault Administrator" `
            -Scope $vault1.ResourceId `
            -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "    ✓ Soft delete: ENABLED" -ForegroundColor Green
        Write-Host "    ✓ Purge protection: ENABLED" -ForegroundColor Green
        Write-Host "    ✓ RBAC authorization: ENABLED" -ForegroundColor Green
        Write-Host "    ✓ Public access: ENABLED (for testing)" -ForegroundColor Yellow
        
        # Create sample objects with expiration dates (wait for RBAC propagation)
        Write-Host "    ⏳ Waiting 15 seconds for RBAC propagation..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
        $expiry = (Get-Date).AddDays(90)
        
        try {
            $secret1 = Set-AzKeyVaultSecret -VaultName $vault1Name -Name "DatabasePassword" `
                -SecretValue (ConvertTo-SecureString "CompliantP@ssw0rd123!" -AsPlainText -Force) `
                -Expires $expiry -ContentType "password" -ErrorAction Stop
            Write-Host "    ✓ Secret created with 90-day expiration" -ForegroundColor Green
        } catch {
            Write-Host "    ✗ Failed to create secret: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        try {
            $key1 = Add-AzKeyVaultKey -VaultName $vault1Name -Name "EncryptionKey" `
                -Destination Software -KeyType RSA -Size 4096 -Expires $expiry -ErrorAction Stop
            Write-Host "    ✓ RSA-4096 key created with 90-day expiration" -ForegroundColor Green
        } catch {
            Write-Host "    ✗ Failed to create key: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        $createdVaults += $vault1
        $trackingData.CompliantVaults += @{
            Name = $vault1Name
            ResourceId = $vault1.ResourceId
            Purpose = "Full Security Configuration"
            Features = @("SoftDelete", "PurgeProtection", "RBAC", "PrivateAccess")
            Objects = @{
                Secrets = 1
                Keys = 1
            }
        }
    } catch {
        Write-Host "    ✗ Failed to create vault: $_" -ForegroundColor Red
    }
    
    # Compliant Vault 2: RBAC + Firewall
    $vault2Name = "kv-$EnvironmentPrefix-rbac-$uniqueSuffix"
    Write-Host "`n  Creating: $vault2Name (RBAC + Firewall)" -ForegroundColor Cyan
    try {
        $vault2 = New-AzKeyVault `
            -VaultName $vault2Name `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -EnablePurgeProtection `
            -Tag @{
                Environment = "Baseline"
                Type = "Compliant"
                Purpose = "RBAC with Firewall Rules"
            }
        
        # Configure firewall (allow current IP)
        Start-Sleep -Seconds 3
        $myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
        Update-AzKeyVaultNetworkRuleSet -VaultName $vault2Name `
            -DefaultAction Deny `
            -IpAddressRange @("$myIp/32") `
            -Bypass AzureServices
        
        # Assign RBAC
        New-AzRoleAssignment -ObjectId $currentUserId `
            -RoleDefinitionName "Key Vault Secrets Officer" `
            -Scope $vault2.ResourceId `
            -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "    ✓ Soft delete: ENABLED" -ForegroundColor Green
        Write-Host "    ✓ Purge protection: ENABLED" -ForegroundColor Green
        Write-Host "    ✓ RBAC authorization: ENABLED" -ForegroundColor Green
        Write-Host "    ✓ Firewall: CONFIGURED ($myIp)" -ForegroundColor Green
        
        $createdVaults += $vault2
        $trackingData.CompliantVaults += @{
            Name = $vault2Name
            ResourceId = $vault2.ResourceId
            Purpose = "RBAC with Firewall Rules"
            Features = @("SoftDelete", "PurgeProtection", "RBAC", "Firewall")
        }
    } catch {
        Write-Host "    ✗ Failed to create vault: $_" -ForegroundColor Red
    }
    
    Write-Host "`n  ✓ Created $($trackingData.CompliantVaults.Count) compliant vault(s)" -ForegroundColor Green
}

# Step 5: Create NON-COMPLIANT vaults (for testing)
if ($CreateNonCompliant) {
    Write-Host "`n[Step 5/6] Creating NON-COMPLIANT Key Vaults..." -ForegroundColor Yellow
    Write-Host "These vaults intentionally violate policies for testing" -ForegroundColor Gray
    
    # Non-Compliant Vault 1: Legacy access policies (no RBAC)
    $vault3Name = "kv-$EnvironmentPrefix-leg-$uniqueSuffix"
    Write-Host "`n  Creating: $vault3Name (Legacy Access Policies)" -ForegroundColor Magenta
    try {
        $vault3 = New-AzKeyVault `
            -VaultName $vault3Name `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Tag @{
                Environment = "Baseline"
                Type = "NonCompliant"
                Purpose = "Legacy Access Policies (No RBAC)"
                Violations = "NoRBAC"
            }
        
        # Disable RBAC to use legacy access policies
        Start-Sleep -Seconds 3
        Update-AzKeyVault -ResourceId $vault3.ResourceId -DisableRbacAuthorization $true
        
        # Grant access policy to current user (old model)
        Start-Sleep -Seconds 2
        Set-AzKeyVaultAccessPolicy -VaultName $vault3Name -ObjectId $currentUserId `
            -PermissionsToSecrets Get,List,Set -PermissionsToKeys Get,List,Create | Out-Null
        
        Write-Host "    ✗ RBAC authorization: DISABLED (uses access policies)" -ForegroundColor Red
        Write-Host "    ✓ Soft delete: ENABLED" -ForegroundColor Yellow
        Write-Host "    ✗ Purge protection: DISABLED" -ForegroundColor Red
        
        # Create secret WITHOUT expiration
        Start-Sleep -Seconds 5
        try {
            $secret3 = Set-AzKeyVaultSecret -VaultName $vault3Name -Name "LegacySecret" `
                -SecretValue (ConvertTo-SecureString "NoExpiry123!" -AsPlainText -Force) -ErrorAction Stop
            Write-Host "    ✗ Secret created WITHOUT expiration date" -ForegroundColor Red
        } catch {
            Write-Host "    ✗ Failed to create secret: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        $createdVaults += $vault3
        $trackingData.NonCompliantVaults += @{
            Name = $vault3Name
            ResourceId = $vault3.ResourceId
            Purpose = "Legacy Access Policies"
            Violations = @("NoRBAC", "NoPurgeProtection", "NoSecretExpiration")
            Objects = @{ Secrets = 1 }
        }
    } catch {
        Write-Host "    ✗ Failed to create vault: $_" -ForegroundColor Red
    }
    
    # Non-Compliant Vault 2: Public access + weak keys
    $vault4Name = "kv-$EnvironmentPrefix-pub-$uniqueSuffix"
    Write-Host "`n  Creating: $vault4Name (Public Access + Weak Keys)" -ForegroundColor Magenta
    try {
        $vault4 = New-AzKeyVault `
            -VaultName $vault4Name `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Tag @{
                Environment = "Baseline"
                Type = "NonCompliant"
                Purpose = "Public Access + Weak Cryptography"
                Violations = "PublicAccess,NoPurgeProtection"
            }
        
        # Assign RBAC for object creation
        Start-Sleep -Seconds 3
        New-AzRoleAssignment -ObjectId $currentUserId `
            -RoleDefinitionName "Key Vault Administrator" `
            -Scope $vault4.ResourceId `
            -ErrorAction SilentlyContinue | Out-Null
        
        # Configure public access (no firewall)
        Update-AzKeyVaultNetworkRuleSet -VaultName $vault4Name -DefaultAction Allow
        
        Write-Host "    ✗ Public access: ENABLED (no firewall)" -ForegroundColor Red
        Write-Host "    ✗ Purge protection: DISABLED" -ForegroundColor Red
        Write-Host "    ✓ RBAC authorization: ENABLED" -ForegroundColor Yellow
        
        # Create objects without expiration (wait for RBAC propagation)
        Write-Host "    ⏳ Waiting 15 seconds for RBAC propagation..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
        
        try {
            $secret4 = Set-AzKeyVaultSecret -VaultName $vault4Name -Name "PublicSecret" `
                -SecretValue (ConvertTo-SecureString "NoExpiry456!" -AsPlainText -Force) -ErrorAction Stop
            Write-Host "    ✗ Secret created WITHOUT expiration" -ForegroundColor Red
        } catch {
            Write-Host "    ✗ Failed to create secret: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        try {
            $key4 = Add-AzKeyVaultKey -VaultName $vault4Name -Name "WeakKey" `
                -Destination Software -KeyType RSA -Size 2048 -ErrorAction Stop
            Write-Host "    ✗ RSA-2048 key created WITHOUT expiration (minimum allowed)" -ForegroundColor Red
        } catch {
            Write-Host "    ✗ Failed to create key: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        $createdVaults += $vault4
        $trackingData.NonCompliantVaults += @{
            Name = $vault4Name
            ResourceId = $vault4.ResourceId
            Purpose = "Public Access + Weak Cryptography"
            Violations = @("PublicAccess", "NoPurgeProtection", "NoSecretExpiration", "NoKeyExpiration")
            Objects = @{ Secrets = 1; Keys = 1 }
        }
    } catch {
        Write-Host "    ✗ Failed to create vault: $_" -ForegroundColor Red
    }
    
    # Non-Compliant Vault 3: Missing diagnostic logging
    $vault5Name = "kv-$EnvironmentPrefix-log-$uniqueSuffix"
    Write-Host "`n  Creating: $vault5Name (No Diagnostic Logging)" -ForegroundColor Magenta
    try {
        $vault5 = New-AzKeyVault `
            -VaultName $vault5Name `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Tag @{
                Environment = "Baseline"
                Type = "NonCompliant"
                Purpose = "No Diagnostic Logging"
                Violations = "NoLogging,NoPurgeProtection"
            }
        
        # Assign RBAC
        Start-Sleep -Seconds 3
        New-AzRoleAssignment -ObjectId $currentUserId `
            -RoleDefinitionName "Key Vault Administrator" `
            -Scope $vault5.ResourceId `
            -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "    ✗ Diagnostic logging: NOT CONFIGURED" -ForegroundColor Red
        Write-Host "    ✗ Purge protection: DISABLED" -ForegroundColor Red
        Write-Host "    ✓ RBAC authorization: ENABLED" -ForegroundColor Yellow
        
        $createdVaults += $vault5
        $trackingData.NonCompliantVaults += @{
            Name = $vault5Name
            ResourceId = $vault5.ResourceId
            Purpose = "No Diagnostic Logging"
            Violations = @("NoLogging", "NoPurgeProtection")
        }
    } catch {
        Write-Host "    ✗ Failed to create vault: $_" -ForegroundColor Red
    }
    
    Write-Host "`n  ✓ Created $($trackingData.NonCompliantVaults.Count) non-compliant vault(s)" -ForegroundColor Green
}

# Step 6: Update resource tracking
if ($UpdateTracking) {
    Write-Host "`n[Step 6/6] Updating resource tracking..." -ForegroundColor Yellow
    
    $artifactsJsonDir = Join-Path $PSScriptRoot "..\artifacts\json"
    if (-not (Test-Path $artifactsJsonDir)) { New-Item -ItemType Directory -Path $artifactsJsonDir -Force | Out-Null }
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $trackingPath = Join-Path $artifactsJsonDir ("resource-tracking-$ts.json")
    $existingTracking = @{}
    
    # If an existing resource-tracking file exists in the canonical artifacts folder, load the most recent one
    $existingFiles = Get-ChildItem -Path $artifactsJsonDir -Filter "resource-tracking*.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($existingFiles -and $existingFiles.Count -gt 0) {
        $existingTracking = Get-Content $existingFiles[0].FullName -Raw | ConvertFrom-Json -AsHashtable
    }
    
    # Add baseline environment section
    if (-not $existingTracking.ContainsKey('BaselineEnvironment')) {
        $existingTracking['BaselineEnvironment'] = @()
    }
    
    $existingTracking['BaselineEnvironment'] += $trackingData
    
    $existingTracking | ConvertTo-Json -Depth 10 | Set-Content $trackingPath
    Write-Host "  ✓ Updated: $trackingPath" -ForegroundColor Green
}

# Summary Report
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Environment Creation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host ""
Write-Host "Compliant Vaults: $($trackingData.CompliantVaults.Count)" -ForegroundColor Green
foreach ($v in $trackingData.CompliantVaults) {
    Write-Host "  - $($v.Name)" -ForegroundColor Green
}
Write-Host ""
Write-Host "Non-Compliant Vaults: $($trackingData.NonCompliantVaults.Count)" -ForegroundColor Red
foreach ($v in $trackingData.NonCompliantVaults) {
    Write-Host "  - $($v.Name) [$($v.Violations -join ', ')]" -ForegroundColor Red
}
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run .\Test-AzurePolicyKeyVault.ps1 -TestMode Audit to scan environment" -ForegroundColor Gray
Write-Host "2. Review compliance results for non-compliant vaults" -ForegroundColor Gray
Write-Host "3. Run remediation scripts to fix violations" -ForegroundColor Gray
Write-Host "4. Re-test to verify compliance improvements" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
