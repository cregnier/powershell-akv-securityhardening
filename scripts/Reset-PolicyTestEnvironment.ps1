<#
.SYNOPSIS
    Resets the test environment to start workflow from scratch

.DESCRIPTION
    This script cleans up all test resources and artifacts to allow starting
    the workflow fresh. It can:
    - Remove Azure Key Vault test resources
    - Remove Azure Policy assignments
    - Delete local artifacts (JSON, HTML, CSV reports)
    - Optionally keep documentation files
    
.PARAMETER ResourceGroupName
    Resource group containing test Key Vaults to delete

.PARAMETER RemovePolicyAssignments
    Remove Azure Policy assignments at subscription level

.PARAMETER CleanArtifacts
    Delete all local report artifacts (JSON, HTML, CSV)

.PARAMETER KeepDocumentation
    Keep documentation files (only clean test artifacts)

.PARAMETER Confirm
    Confirm deletion of resources (recommended)

.EXAMPLE
    .\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-test" -Confirm
    
.EXAMPLE
    .\Reset-PolicyTestEnvironment.ps1 -CleanArtifacts -KeepDocumentation
    
.EXAMPLE
    .\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName "rg-policy-test" -RemovePolicyAssignments -CleanArtifacts

.NOTES
    This script permanently deletes resources. Use with caution!
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [switch]$RemovePolicyAssignments,
    
    [Parameter(Mandatory = $false)]
    [switch]$CleanArtifacts = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$KeepDocumentation = $true
)

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "🔄 Reset Policy Test Environment" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

if ($Confirm) {
    Write-Host "⚠️  WARNING: This will DELETE resources!" -ForegroundColor Red
    Write-Host ""
    if ($ResourceGroupName) {
        Write-Host "  - All Key Vaults in resource group: $ResourceGroupName" -ForegroundColor Gray
    }
    if ($RemovePolicyAssignments) {
        Write-Host "  - All Azure Policy assignments for Key Vault" -ForegroundColor Gray
    }
    if ($CleanArtifacts) {
        Write-Host "  - All local artifacts (JSON, HTML, CSV reports)" -ForegroundColor Gray
    }
    Write-Host ""
    $response = Read-Host "Type 'DELETE' to confirm (or anything else to cancel)"
    
    if ($response -ne 'DELETE') {
        Write-Host "`n❌ Reset cancelled by user" -ForegroundColor Yellow
        return
    }
}

$summary = @{
    vaultsDeleted = 0
    policyAssignmentsRemoved = 0
    artifactsDeleted = 0
    startTime = Get-Date
}

# Step 1: Remove Key Vaults
if ($ResourceGroupName) {
    Write-Host "`nStep 1: Removing Key Vaults..." -ForegroundColor Cyan
    
    try {
        $vaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        
        if ($vaults) {
            Write-Host "  Found $($vaults.Count) Key Vault(s) to delete:" -ForegroundColor Yellow
            
            foreach ($vault in $vaults) {
                Write-Host "    Deleting: $($vault.VaultName)..." -ForegroundColor Gray
                
                try {
                    Remove-AzKeyVault -VaultName $vault.VaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
                    $summary.vaultsDeleted++
                    Write-Host "      ✓ Deleted" -ForegroundColor Green
                } catch {
                    Write-Host "      ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  No Key Vaults found in resource group" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nStep 1: Skipping Key Vault deletion (no resource group specified)" -ForegroundColor Gray
}

# Step 2: Remove Policy Assignments
if ($RemovePolicyAssignments) {
    Write-Host "`nStep 2: Removing Policy Assignments..." -ForegroundColor Cyan
    
    try {
        # Get subscription context for subscription-scoped assignments
        $ctx = Get-AzContext
        if (-not $ctx) {
            Write-Host "  ✗ No Azure context. Run Connect-AzAccount first" -ForegroundColor Red
        } else {
            # Check for both subscription-scoped and resource-group-scoped assignments
            $assignments = @()
            
            # Get subscription-scoped assignments
            Write-Host "  Checking for subscription-scoped policy assignments..." -ForegroundColor Gray
            $subScope = "/subscriptions/$($ctx.Subscription.Id)"
            $subAssignments = Get-AzPolicyAssignment -Scope $subScope -ErrorAction SilentlyContinue | Where-Object { 
                $_.Properties.DisplayName -like '*Key Vault*' -or 
                $_.Properties.DisplayName -like '*key vault*' 
            }
            if ($subAssignments) {
                $assignments += $subAssignments
                Write-Host "    Found $($subAssignments.Count) subscription-scoped assignment(s)" -ForegroundColor Yellow
            }
            
            # Get resource-group-scoped assignments (if ResourceGroupName provided)
            if ($ResourceGroupName) {
                Write-Host "  Checking for resource-group-scoped policy assignments in: $ResourceGroupName..." -ForegroundColor Gray
                $rgScope = "/subscriptions/$($ctx.Subscription.Id)/resourceGroups/$ResourceGroupName"
                $rgAssignments = Get-AzPolicyAssignment -Scope $rgScope -ErrorAction SilentlyContinue | Where-Object { 
                    $_.Properties.DisplayName -like '*Key Vault*' -or 
                    $_.Properties.DisplayName -like '*key vault*' 
                }
                if ($rgAssignments) {
                    $assignments += $rgAssignments
                    Write-Host "    Found $($rgAssignments.Count) resource-group-scoped assignment(s)" -ForegroundColor Yellow
                }
            }
            
            if ($assignments -and $assignments.Count -gt 0) {
                Write-Host "  Found $($assignments.Count) total policy assignment(s) to remove:" -ForegroundColor Yellow
                
                foreach ($assignment in $assignments) {
                    $scope = if ($assignment.Properties.Scope -like "*/resourceGroups/*") { "RG" } else { "Sub" }
                    Write-Host "    Removing [$scope]: $($assignment.Properties.DisplayName)..." -ForegroundColor Gray
                    
                    try {
                        Remove-AzPolicyAssignment -Id $assignment.ResourceId -ErrorAction Stop
                        $summary.policyAssignmentsRemoved++
                        Write-Host "      ✓ Removed" -ForegroundColor Green
                    } catch {
                        Write-Host "      ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "  No Key Vault policy assignments found" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nStep 2: Skipping policy assignment removal" -ForegroundColor Gray
}

# Step 3: Clean Local Artifacts
if ($CleanArtifacts) {
    Write-Host "`nStep 3: Cleaning Local Artifacts..." -ForegroundColor Cyan
    
    $artifactPatterns = @(
        "baseline-*.json",
        "baseline-*.html",
        "after-remediation-*.json",
        "compliance-report-*.json",
        "compliance-report-*.csv",
        "remediation-preview-*.json",
        "remediation-results-*.json",
        "policy-assignments-*.json",
        "policy-assignments-*.html",
        "remediation-preview-*.html",
        "remediation-results-*.html",
        "compliance-report-*.html",
        "Workflow-Comprehensive-Report-*.html",
        "Workflow-Comprehensive-Report-*.json"
    )
    
    if (-not $KeepDocumentation) {
        Write-Host "  ⚠️  Also removing test reports..." -ForegroundColor Yellow
        $artifactPatterns += "AzurePolicy-KeyVault-TestReport-*.html"
    }
    
    foreach ($pattern in $artifactPatterns) {
        # Look for artifacts in artifacts folders first, then fall back to current dir for backwards compatibility
        $files = @()
        $artifactSearchRoot = Join-Path $PSScriptRoot '..\artifacts'
        if (Test-Path $artifactSearchRoot) {
            $files += Get-ChildItem -Path $artifactSearchRoot -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue
        }
        $files += Get-ChildItem -Path . -Filter $pattern -File -ErrorAction SilentlyContinue
        
        if ($files) {
            Write-Host "  Deleting $($files.Count) file(s) matching: $pattern" -ForegroundColor Gray
            
            foreach ($file in $files) {
                try {
                    Remove-Item $file.FullName -Force -ErrorAction Stop
                    $summary.artifactsDeleted++
                } catch {
                    Write-Host "    ✗ Failed to delete $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    Write-Host "  ✓ Deleted $($summary.artifactsDeleted) artifact file(s)" -ForegroundColor Green
} else {
    Write-Host "`nStep 3: Skipping artifact cleanup" -ForegroundColor Gray
}

# Step 4: Clean Resource Tracking
Write-Host "`nStep 4: Cleaning Resource Tracking..." -ForegroundColor Cyan
$artifactsJsonDir = Join-Path $PSScriptRoot '..\artifacts\json'
if (-not (Test-Path $artifactsJsonDir)) { New-Item -ItemType Directory -Path $artifactsJsonDir -Force | Out-Null }

# If a legacy resource-tracking.json exists in current dir, preserve it by moving to artifacts/json with timestamp
if (Test-Path "resource-tracking.json") {
    try {
        $mvts = Get-Date -Format "yyyyMMdd-HHmmss"
        $dest = Join-Path $artifactsJsonDir ("resource-tracking-legacy-$mvts.json")
        Move-Item -Path "resource-tracking.json" -Destination $dest -Force
        Write-Host "  ✓ Moved existing resource-tracking.json to $dest" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to move existing resource-tracking.json: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create fresh tracking object in artifacts/json with timestamped filename to avoid overwrites
try {
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $newTrackingPath = Join-Path $artifactsJsonDir ("resource-tracking-$ts.json")
    $tracking = [PSCustomObject]@{
        resources = @()
        lastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $tracking | ConvertTo-Json -Depth 10 | Out-File $newTrackingPath -Encoding UTF8
    Write-Host "  ✓ Reset resource tracking -> $newTrackingPath" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to reset tracking: $($_.Exception.Message)" -ForegroundColor Red
}

$summary.endTime = Get-Date
$summary.duration = ($summary.endTime - $summary.startTime).TotalSeconds

# Final Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ Reset Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Key Vaults Deleted: $($summary.vaultsDeleted)" -ForegroundColor Gray
Write-Host "  Policy Assignments Removed: $($summary.policyAssignmentsRemoved)" -ForegroundColor Gray
Write-Host "  Artifacts Deleted: $($summary.artifactsDeleted)" -ForegroundColor Gray
Write-Host "  Duration: $([math]::Round($summary.duration, 2)) seconds" -ForegroundColor Gray
Write-Host ""
Write-Host "Environment is now clean. Ready to run workflow again!" -ForegroundColor Green
Write-Host ""

if ($KeepDocumentation) {
    Write-Host "📚 Documentation files preserved:" -ForegroundColor Cyan
    @(
        "README.md",
        "QUICK_START.md",
        "SCENARIO_VERIFICATION.md",
        "docs/secrets-guidance.md",
        "AzurePolicy-KeyVault-TestMatrix.md"
    ) | ForEach-Object {
        if (Test-Path $_) {
            Write-Host "  ✓ $_" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Create new test environment: .\scripts\Create-PolicyTestEnvironment.ps1" -ForegroundColor Gray
Write-Host "  2. Follow QUICK_START.md workflow" -ForegroundColor Gray
Write-Host ""

return $summary
