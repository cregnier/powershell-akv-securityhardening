<#
.SYNOPSIS
    Comprehensive Azure Policy testing script for Azure Key Vault secrets management - v2.0

.DESCRIPTION
    This script performs comprehensive testing of Azure Policy enforcement on Azure Key Vault
    including keys, secrets, and certificates. Tests both Audit and Deny modes and generates
    detailed HTML compliance reports. Supports resource tracking and test selection.

.PARAMETER SubscriptionId
    The Azure subscription ID to use for testing.

.PARAMETER Location
    Azure region for resource deployment (default: eastus).

.PARAMETER ResourceGroupName
    Name of the resource group to create for testing (default: rg-policy-keyvault-test).

.PARAMETER TestMode
    Test mode: 'Audit', 'Deny', or 'Both' (default: Both).

.PARAMETER CleanupAfterTest
    Whether to cleanup resources after test completion (default: $false).

.PARAMETER UseMSAAccount
    Switch to use Microsoft Account (MSA) instead of corporate account. Forces re-authentication.

.PARAMETER ReuseResources
    Switch to reuse existing resources from previous test runs.

.PARAMETER InteractiveTestSelection
    Switch to enable interactive test selection menu.

.EXAMPLE
    .\Test-AzurePolicyKeyVault-v2.ps1 -Location "eastus"

.EXAMPLE
    .\Test-AzurePolicyKeyVault-v2.ps1 -InteractiveTestSelection -ReuseResources

.NOTES
    Author: Azure Policy Testing Framework
    Version: 2.0.0
    Date: 2026-01-02
    Requires: Az PowerShell module 11.0 or higher
    
    Comprehensive Compliance Coverage:
    - Microsoft Cloud Security Benchmark (MCSB)
    - CIS Microsoft Azure Foundations Benchmark (1.3.0, 1.4.0, 2.0.0)
    - NIST SP 800-171 R2
    - PCI DSS 4.0
    - ISO 27001
    - CERT Security Guidelines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-policy-keyvault-test",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Audit', 'Deny', 'Both')]
    [string]$TestMode = 'Both',
    
    [Parameter(Mandatory = $false)]
    [bool]$CleanupAfterTest = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseMSAAccount,
    
    [Parameter(Mandatory = $false)]
    [switch]$ReuseResources,
    
    [Parameter(Mandatory = $false)]
    [switch]$InteractiveTestSelection
)

# Script configuration
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$VerbosePreference = 'Continue'

# Global variables
$script:TestResults = @()
$script:CreatedResources = @()
$script:ComplianceResults = @()
$script:StartTime = Get-Date
$script:UniqueId = -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$script:ResourceTrackingFile = Join-Path $PSScriptRoot "resource-tracking.json"
$script:SelectedTests = @()

# Define all available tests
$script:AllAvailableTests = @(
    @{ID=1; Name="Soft Delete Policy"; Category="KeyVault Configuration"; Function="Test-SoftDeletePolicy"; RequiresVault=$false}
    @{ID=2; Name="Purge Protection Policy"; Category="KeyVault Configuration"; Function="Test-PurgeProtectionPolicy"; RequiresVault=$false}
    @{ID=3; Name="RBAC Authorization Policy"; Category="KeyVault Configuration"; Function="Test-RBACAuthorizationPolicy"; RequiresVault=$false}
    @{ID=4; Name="Firewall & Network Access Policy"; Category="KeyVault Configuration"; Function="Test-FirewallPolicy"; RequiresVault=$false}
    @{ID=5; Name="Private Link Policy"; Category="KeyVault Configuration"; Function="Test-PrivateLinkPolicy"; RequiresVault=$true}
    @{ID=6; Name="Secret Expiration Policy"; Category="Secrets Management"; Function="Test-SecretExpirationPolicy"; RequiresVault=$true}
    @{ID=7; Name="Key Expiration Policy"; Category="Keys Management"; Function="Test-KeyExpirationPolicy"; RequiresVault=$true}
    @{ID=8; Name="Key Type Policy (RSA/EC)"; Category="Keys Management"; Function="Test-KeyTypePolicy"; RequiresVault=$true}
    @{ID=9; Name="RSA Key Minimum Size Policy"; Category="Keys Management"; Function="Test-RSAKeySizePolicy"; RequiresVault=$true}
    @{ID=10; Name="EC Curve Names Policy"; Category="Keys Management"; Function="Test-ECCurvePolicy"; RequiresVault=$true}
    @{ID=11; Name="Certificate Validity Period Policy"; Category="Certificates Management"; Function="Test-CertificateValidityPolicy"; RequiresVault=$true}
    @{ID=12; Name="Certificate Issuer (CA) Policy"; Category="Certificates Management"; Function="Test-CertificateCAPolicy"; RequiresVault=$true}
    @{ID=13; Name="Certificate Key Type Policy"; Category="Certificates Management"; Function="Test-CertificateKeyTypePolicy"; RequiresVault=$true}
    @{ID=14; Name="Certificate Renewal Policy"; Category="Certificates Management"; Function="Test-CertificateRenewalPolicy"; RequiresVault=$true}
    @{ID=15; Name="Diagnostic Logging Policy"; Category="Logging & Monitoring"; Function="Test-DiagnosticLoggingPolicy"; RequiresVault=$true}
)

#region Resource Tracking Functions

function Save-ResourceTracking {
    $tracking = @{
        UniqueId = $script:UniqueId
        Timestamp = (Get-Date).ToString('o')
        Subscription = (Get-AzContext).Subscription.Id
        ResourceGroup = $ResourceGroupName
        Resources = $script:CreatedResources
    }
    
    $tracking | ConvertTo-Json -Depth 10 | Out-File $script:ResourceTrackingFile -Encoding UTF8
    Write-TestLog "Resource tracking saved to $script:ResourceTrackingFile" -Level Info
}

function Load-ResourceTracking {
    if (Test-Path $script:ResourceTrackingFile) {
        $tracking = Get-Content $script:ResourceTrackingFile -Raw | ConvertFrom-Json
        return $tracking
    }
    return $null
}

function Show-PreviousResources {
    $tracking = Load-ResourceTracking
    
    if ($tracking) {
        Write-Host "`n=== Previous Test Run Detected ===" -ForegroundColor Cyan
        Write-Host "Run Time: $($tracking.Timestamp)" -ForegroundColor Yellow
        Write-Host "Subscription: $($tracking.Subscription)" -ForegroundColor Yellow
        Write-Host "Resource Group: $($tracking.ResourceGroup)" -ForegroundColor Yellow
        Write-Host "`nResources Created:" -ForegroundColor Yellow
        
        foreach ($resource in $tracking.Resources) {
            Write-Host "  - $($resource.Type): $($resource.Name)" -ForegroundColor Gray
        }
        
        Write-Host ""
        $response = Read-Host "Would you like to (C)leanup old resources, (R)euse existing resources, or (N)ew fresh start? [C/R/N]"
        
        switch ($response.ToUpper()) {
            'C' {
                Write-Host "Cleaning up previous resources..." -ForegroundColor Yellow
                Cleanup-PreviousResources -Tracking $tracking
                return $false
            }
            'R' {
                Write-Host "Reusing existing resources..." -ForegroundColor Green
                $script:CreatedResources = $tracking.Resources
                $script:UniqueId = $tracking.UniqueId
                return $true
            }
            default {
                Write-Host "Starting fresh with new resources..." -ForegroundColor Green
                return $false
            }
        }
    }
    
    return $false
}

function Cleanup-PreviousResources {
    param([Parameter(Mandatory=$true)]$Tracking)
    
    try {
        if ($Tracking.ResourceGroup) {
            $rg = Get-AzResourceGroup -Name $Tracking.ResourceGroup -ErrorAction SilentlyContinue
            if ($rg) {
                Write-TestLog "Removing resource group: $($Tracking.ResourceGroup)" -Level Warning
                Remove-AzResourceGroup -Name $Tracking.ResourceGroup -Force | Out-Null
                Write-TestLog "Resource group removed successfully" -Level Success
            }
        }
        
        if (Test-Path $script:ResourceTrackingFile) {
            Remove-Item $script:ResourceTrackingFile -Force
        }
    }
    catch {
        Write-TestLog "Error during cleanup: $_" -Level Error
    }
}

#endregion

#region Test Selection Functions

function Show-TestSelectionMenu {
    Write-Host "`n=== Azure Policy Key Vault Test Selection ===" -ForegroundColor Cyan
    Write-Host "Available Tests:" -ForegroundColor Yellow
    Write-Host ""
    
    # Group by category
    $categories = $script:AllAvailableTests | Group-Object -Property Category
    
    foreach ($category in $categories) {
        Write-Host "[$($category.Name)]" -ForegroundColor Green
        foreach ($test in $category.Group) {
            $vaultReq = if ($test.RequiresVault) { "(Requires Vault)" } else { "" }
            Write-Host "  $($test.ID). $($test.Name) $vaultReq" -ForegroundColor White
        }
        Write-Host ""
    }
    
    Write-Host "Special Options:" -ForegroundColor Yellow
    Write-Host "  A. Run ALL tests" -ForegroundColor White
    Write-Host "  C. Run tests by Category" -ForegroundColor White
    Write-Host ""
    
    $selection = Read-Host "Enter test numbers (comma-separated), 'A' for all, or 'C' for category selection"
    
    if ($selection.ToUpper() -eq 'A') {
        $script:SelectedTests = $script:AllAvailableTests
        Write-Host "Selected: ALL tests ($($script:SelectedTests.Count) tests)" -ForegroundColor Green
    }
    elseif ($selection.ToUpper() -eq 'C') {
        Select-TestsByCategory
    }
    else {
        $testIds = $selection -split ',' | ForEach-Object { [int]$_.Trim() }
        $script:SelectedTests = $script:AllAvailableTests | Where-Object { $testIds -contains $_.ID }
        Write-Host "Selected: $($script:SelectedTests.Count) tests" -ForegroundColor Green
    }
}

function Select-TestsByCategory {
    $categories = $script:AllAvailableTests | Group-Object -Property Category
    
    Write-Host "`n=== Select by Category ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $categories.Count; $i++) {
        Write-Host "  $($i + 1). $($categories[$i].Name) ($($categories[$i].Count) tests)" -ForegroundColor White
    }
    Write-Host ""
    
    $selection = Read-Host "Enter category numbers (comma-separated) or 'A' for all categories"
    
    if ($selection.ToUpper() -eq 'A') {
        $script:SelectedTests = $script:AllAvailableTests
    }
    else {
        $catIds = $selection -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
        $selectedCategories = $categories[$catIds]
        $script:SelectedTests = $selectedCategories | ForEach-Object { $_.Group }
    }
    
    Write-Host "Selected: $($script:SelectedTests.Count) tests" -ForegroundColor Green
}

#endregion

#region Prerequisite Checks

function Test-Prerequisites {
    Write-Host "`n=== Checking Prerequisites ===" -ForegroundColor Cyan
    $allChecksPassed = $true
    
    # Check PowerShell version
    Write-Host "Checking PowerShell version..." -ForegroundColor Yellow
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Write-Host "  ✓ PowerShell $($psVersion.Major).$($psVersion.Minor).$($psVersion.Build)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ PowerShell $($psVersion.Major).$($psVersion.Minor) is too old. Version 5.1 or higher required." -ForegroundColor Red
        $allChecksPassed = $false
    }
    
    # Check required modules
    Write-Host "Checking required Azure modules..." -ForegroundColor Yellow
    $requiredModules = @(
        @{Name='Az.Accounts'; MinVersion='2.0.0'},
        @{Name='Az.KeyVault'; MinVersion='4.0.0'},
        @{Name='Az.Resources'; MinVersion='6.0.0'},
        @{Name='Az.PolicyInsights'; MinVersion='1.0.0'},
        @{Name='Az.Monitor'; MinVersion='4.0.0'},
        @{Name='Az.OperationalInsights'; MinVersion='3.0.0'}
    )
    
    foreach ($module in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
        if ($installed) {
            if ($installed.Version -ge [version]$module.MinVersion) {
                Write-Host "  ✓ $($module.Name) v$($installed.Version)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ $($module.Name) v$($installed.Version) (v$($module.MinVersion)+ recommended)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✗ $($module.Name) not installed" -ForegroundColor Red
            $allChecksPassed = $false
        }
    }
    
    if (-not $allChecksPassed) {
        Write-Host "`nTo install missing modules, run:" -ForegroundColor Yellow
        Write-Host "Install-Module Az.Accounts, Az.KeyVault, Az.Resources, Az.PolicyInsights, Az.Monitor, Az.OperationalInsights -Force -AllowClobber" -ForegroundColor Cyan
        throw "Prerequisites not met. Please install required modules."
    }
    
    Write-Host "✓ All prerequisites met" -ForegroundColor Green
    return $true
}

#endregion

#region Helper Functions

function Write-TestLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Add-TestResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [string]$Category,
        
        [Parameter(Mandatory = $true)]
        [string]$PolicyName,
        
        [Parameter(Mandatory = $true)]
        [string]$PolicyId,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Audit', 'Deny')]
        [string]$Mode,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Pass', 'Fail', 'Error', 'Skipped')]
        [string]$Result,
        
        [Parameter(Mandatory = $false)]
        [string]$Details,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage,
        
        [Parameter(Mandatory = $false)]
        [string]$ComplianceFramework,
        
        [Parameter(Mandatory = $false)]
        [string]$RemediationScript
    )
    
    $script:TestResults += [PSCustomObject]@{
        Timestamp           = Get-Date
        TestName            = $TestName
        Category            = $Category
        PolicyName          = $PolicyName
        PolicyId            = $PolicyId
        Mode                = $Mode
        Result              = $Result
        Details             = $Details
        ErrorMessage        = $ErrorMessage
        ComplianceFramework = $ComplianceFramework
        RemediationScript   = $RemediationScript
    }
}

# [Previous authentication and resource functions will go here - I'll add them in the next part due to length]

This file is getting very long. Let me create a modular approach by splitting it into the main script with updated functions. Would you like me to continue with a comprehensive update, or would you prefer to:

1. Update the existing script incrementally with fixes
2. Create a completely new v2 script with all enhancements

Which approach would you prefer?
