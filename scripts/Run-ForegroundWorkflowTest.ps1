<#
.SYNOPSIS
    Runs complete workflow test in FOREGROUND with detailed output

.DESCRIPTION
    Executes the full Azure Key Vault Policy testing workflow:
    0. Clean up existing environment
    1. Create test environment (vaults, secrets, keys)
    2. Verify environment readiness
    3. Execute workflow from QUICK_START.md
    4. Reset/cleanup environment
    5. Verify cleanup completed
    
    All steps run in foreground with full visibility.

.EXAMPLE
    .\Run-ForegroundWorkflowTest.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$rgName = "rg-policy-keyvault-test"
$location = "eastus"

# Function to write section headers
function Write-Section {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor $Color
    Write-Host " $Title" -ForegroundColor $Color
    Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor $Color
}

# Start workflow
Write-Section "AZURE KEY VAULT POLICY - FOREGROUND WORKFLOW TEST" "Green"

# Get Azure context
$ctx = Get-AzContext
if (-not $ctx) {
    Write-Host "❌ No Azure context. Please run: Connect-AzAccount" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Azure Context:" -ForegroundColor Green
Write-Host "  Subscription: $($ctx.Subscription.Name)" -ForegroundColor White
Write-Host "  Account: $($ctx.Account.Id)`n" -ForegroundColor White

# Ask user: Create new or reuse existing environment
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " ENVIRONMENT SETUP OPTIONS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "How would you like to proceed?" -ForegroundColor Yellow
Write-Host "  [C] Create new environment (cleanup existing resources first)" -ForegroundColor White
Write-Host "  [R] Reuse existing environment (if present)" -ForegroundColor White
Write-Host ""
$envChoice = Read-Host "Enter your choice (C/R)"

$createNew = $envChoice -match '^[Cc]'

# STEP 0: Clean up existing environment (if creating new)
if ($createNew) {
    Write-Section "STEP 0: CLEANING EXISTING ENVIRONMENT" "Red"

    Write-Host "Checking for existing resources..." -ForegroundColor Cyan
    $rgExists = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue

    # Always run cleanup to remove old policy assignments (they exist at subscription level)
    Write-Host "Running cleanup to remove any existing policies and resources..." -ForegroundColor Yellow
    
    & "$PSScriptRoot\Reset-PolicyTestEnvironment.ps1" `
        -ResourceGroupName $rgName `
        -RemovePolicyAssignments `
        -WhatIf:$false `
        -Confirm:$false
    
    Write-Host "`n✓ Cleanup completed" -ForegroundColor Green

    # Pause for user to see cleanup results
    Write-Host "Press ENTER to continue to Step 1..." -ForegroundColor Yellow
    Read-Host
} else {
    Write-Section "STEP 0: VALIDATING EXISTING ENVIRONMENT" "Cyan"
    
    Write-Host "Checking for existing resources..." -ForegroundColor Cyan
    $rgExists = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
    
    if ($rgExists) {
        $vaults = Get-AzKeyVault -ResourceGroupName $rgName -ErrorAction SilentlyContinue
        $vaultCount = if ($vaults) { ($vaults | Measure-Object).Count } else { 0 }
        
        Write-Host "✓ Found resource group: $rgName" -ForegroundColor Green
        Write-Host "✓ Found $vaultCount Key Vault(s)" -ForegroundColor Green
        
        if ($vaultCount -eq 0) {
            Write-Host "`n⚠️  Warning: No Key Vaults found in existing resource group" -ForegroundColor Yellow
            Write-Host "   You may want to create new environment instead`n" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Resource group '$rgName' not found" -ForegroundColor Red
        Write-Host "   Cannot reuse environment - you must create new`n" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`nPress ENTER to continue..." -ForegroundColor Yellow
    Read-Host
}

# STEP 1: Create test environment (only if creating new)
if ($createNew) {
    Write-Section "STEP 1: CREATING TEST ENVIRONMENT"

    Write-Host "Creating Key Vaults with comprehensive security testing..." -ForegroundColor Cyan
    Write-Host "This will create:" -ForegroundColor Gray
    Write-Host "  • 5 Key Vaults (2 compliant, 3 non-compliant)" -ForegroundColor White
    Write-Host "  • Sample secrets, keys, and certificates" -ForegroundColor White
    Write-Host "  • Policy-compliant AND policy-violating content for testing" -ForegroundColor White
    Write-Host "  • Key Vault Administrator role assignments`n" -ForegroundColor White

    & "$PSScriptRoot\Create-PolicyTestEnvironment.ps1" `
        -SubscriptionId $ctx.Subscription.Id `
        -ResourceGroupName $rgName `
        -Location $location `
        -CreateCompliant $true `
        -CreateNonCompliant $true

    Write-Host "`n✓ Environment creation completed" -ForegroundColor Green

    # STEP 1.5: Seed vaults with comprehensive policy test content
    Write-Host "`nSeeding vaults with additional policy test content..." -ForegroundColor Cyan

    # Get all created vaults
    $vaults = Get-AzKeyVault -ResourceGroupName $rgName -ErrorAction SilentlyContinue
    if ($vaults -and $vaults.Count -gt 0) {
        $vaultNames = $vaults | ForEach-Object { $_.VaultName }
        
        & "$PSScriptRoot\Seed-VaultsWithPolicyTests.ps1" `
            -ResourceGroupName $rgName `
            -VaultNames $vaultNames
        
        Write-Host "✓ Vault seeding completed`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No vaults found to seed`n" -ForegroundColor Yellow
    }

    # Pause for user
    Write-Host "`nPress ENTER to continue to Step 2..." -ForegroundColor Yellow
    Read-Host
} else {
    Write-Host "Skipping environment creation - reusing existing environment`n" -ForegroundColor Gray
}

# STEP 2: Verify environment readiness
Write-Section "STEP 2: VERIFYING ENVIRONMENT READINESS"

Write-Host "Checking created resources...`n" -ForegroundColor Cyan

# Check resource group
$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if ($rg) {
    Write-Host "✓ Resource Group: $rgName" -ForegroundColor Green
} else {
    Write-Host "❌ Resource Group not found!" -ForegroundColor Red
}

# Check Key Vaults
$vaults = Get-AzKeyVault -ResourceGroupName $rgName -ErrorAction SilentlyContinue
if ($vaults) {
    Write-Host "✓ Key Vaults Created: $($vaults.Count)" -ForegroundColor Green
    Write-Host "`nVault List:" -ForegroundColor Cyan
    $vaults | ForEach-Object {
        Write-Host "  • $($_.VaultName)" -ForegroundColor White
    }
} else {
    Write-Host "❌ No Key Vaults found!" -ForegroundColor Red
}

# Check objects in all vaults
if ($vaults.Count -gt 0) {
    Write-Host "\nChecking objects in all vaults..." -ForegroundColor Cyan
    $totalSecrets = 0; $totalKeys = 0; $totalCerts = 0
    foreach ($vault in $vaults) {
        $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        $keys = Get-AzKeyVaultKey -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        $certs = Get-AzKeyVaultCertificate -VaultName $vault.VaultName -ErrorAction SilentlyContinue
        Write-Host "  $($vault.VaultName): Secrets=$($secrets.Count), Keys=$($keys.Count), Certs=$($certs.Count)" -ForegroundColor White
        $totalSecrets += $secrets.Count; $totalKeys += $keys.Count; $totalCerts += $certs.Count
    }
    Write-Host "  " -NoNewline
    Write-Host "Total: Secrets=$totalSecrets, Keys=$totalKeys, Certs=$totalCerts" -ForegroundColor Green
}

# Check policies
Write-Host "`nChecking Azure Policy assignments..." -ForegroundColor Cyan
$policyAssignments = Get-AzPolicyAssignment -Scope "/subscriptions/$($ctx.Subscription.Id)" -ErrorAction SilentlyContinue | 
    Where-Object { $_.Properties.DisplayName -like "*Key*Vault*" -or $_.Name -like "*keyvault*" }

if ($policyAssignments) {
    Write-Host "⚠️  Found $($policyAssignments.Count) existing Key Vault policies" -ForegroundColor Yellow
} else {
    Write-Host "✓ No existing Key Vault policies (expected - policies assigned in workflow)" -ForegroundColor Green
}

Write-Host "`n✅ Environment verification complete!" -ForegroundColor Green

# Pause for user
Write-Host "`nPress ENTER to continue to Step 3 (Workflow Execution)..." -ForegroundColor Yellow
Read-Host

# STEP 3: Run QUICK_START.md workflow
Write-Section "STEP 3: EXECUTING QUICK_START.MD WORKFLOW"

Write-Host "Running complete workflow..." -ForegroundColor Cyan
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  • Capture baseline state" -ForegroundColor White
Write-Host "  • Assign Azure Policies (Audit mode)" -ForegroundColor White
Write-Host "  • Run compliance scans" -ForegroundColor White
Write-Host "  • Generate HTML/JSON reports`n" -ForegroundColor White

Write-Host "⏱️  This may take 5-10 minutes...`n" -ForegroundColor Yellow

# Use a workflow run id so all artifacts are correlated
$WorkflowRunId = (Get-Date -Format "yyyyMMdd-HHmmss")
$runStart = Get-Date

# Helper: Poll and re-run Regenerate-ComplianceReport until compliance data appears
function Poll-RegenerateCompliance {
    param(
        [Parameter(Mandatory=$true)][string]$WorkflowRunId,
        [Parameter(Mandatory=$false)][string]$ResourceGroupName,
        [int]$IntervalSeconds = 60,
        [int]$MaxAttempts = 10,
        [switch]$AutoOpenHtml
    )

    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $jsonDir = Join-Path (Split-Path -Parent $scriptRoot) "artifacts\json"
    $complianceJson = Join-Path $jsonDir "compliance-report-$WorkflowRunId.json"

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        Write-Host ("Attempt ${i}/${MaxAttempts}: regenerating compliance report...") -ForegroundColor Cyan
        & "$PSScriptRoot\Regenerate-ComplianceReport.ps1" -WorkflowRunId $WorkflowRunId -ResourceGroupName $ResourceGroupName

        # Give a moment for files to flush
        Start-Sleep -Seconds 2

        if (Test-Path $complianceJson) {
            try {
                $report = Get-Content $complianceJson -ErrorAction Stop | ConvertFrom-Json
                if ($report.totalEvaluations -gt 0) {
                    Write-Host "✓ Compliance data found: $($report.totalEvaluations) evaluations." -ForegroundColor Green
                    if ($AutoOpenHtml) {
                        $htmlPath = Join-Path (Split-Path -Parent $scriptRoot) "artifacts\html" "compliance-report-$WorkflowRunId.html"
                        if (Test-Path $htmlPath) { Start-Process $htmlPath }
                    }
                    return $true
                } else {
                    Write-Host "  Still zero evaluations in report." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  Warning: failed to parse JSON: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Compliance JSON not found yet." -ForegroundColor Yellow
        }

        if ($i -lt $MaxAttempts) {
            Write-Host "Waiting $IntervalSeconds seconds before retry..." -ForegroundColor Gray
            Start-Sleep -Seconds $IntervalSeconds
        }
    }

    Write-Host "⚠️  Reached max attempts ($MaxAttempts) without compliance evaluations." -ForegroundColor Yellow
    return $false
}

# Ask user: DevTest mode or Production mode (Production is the safe default)
Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " REMEDIATION MODE SELECTION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "Select remediation mode:" -ForegroundColor Yellow
Write-Host "`n  [P] Production Mode - SAFE (Default - Recommended)" -ForegroundColor Green
Write-Host "      ✅ Auto-fixes: Soft delete + purge protection (non-breaking)" -ForegroundColor Gray
Write-Host "      ⚠️  Manual review: RBAC, firewall, logging, expiration, certificates" -ForegroundColor Gray
Write-Host "      💡 Safe for production - will NOT break existing applications" -ForegroundColor Cyan
Write-Host "`n  [D] DevTest Mode - AGGRESSIVE (Test environments only)" -ForegroundColor Yellow
Write-Host "      ⚠️  Auto-fixes: ALL issues including breaking changes" -ForegroundColor Red
Write-Host "      🔥 WARNING: May invalidate access policies, block network access" -ForegroundColor Red
Write-Host "      ⛔ NOT safe for production environments" -ForegroundColor Red
Write-Host ""
Write-Host "Press ENTER for Production Mode (safe), or type D for DevTest Mode:" -ForegroundColor Cyan
$modeChoice = Read-Host "Choice (P/D or ENTER for Production)"

# Default to Production Mode (safe) if ENTER pressed or invalid input
if ($modeChoice -match '^[Dd]') {
    Write-Host "`n⚠️  DevTest Mode selected - AGGRESSIVE auto-remediation" -ForegroundColor Magenta
    Write-Host "   This will make breaking changes suitable only for test environments" -ForegroundColor Yellow
    Write-Host "   Access policies will be invalidated, network access may be blocked`n" -ForegroundColor Red
    $runResult = & "$PSScriptRoot\Run-CompleteWorkflow.ps1" -ResourceGroupName $rgName -WorkflowRunId $WorkflowRunId -DevTestMode -SkipComplianceWait -InvokedBy 'Run-ForegroundWorkflowTest.ps1'
} elseif ([string]::IsNullOrWhiteSpace($modeChoice) -or $modeChoice -match '^[Pp]') {
    if ([string]::IsNullOrWhiteSpace($modeChoice)) {
        Write-Host "`n✓ Production Mode selected (default) - SAFE" -ForegroundColor Green
    } else {
        Write-Host "`n✓ Production Mode selected - SAFE" -ForegroundColor Green
    }
    Write-Host "   Only non-breaking changes will be auto-fixed" -ForegroundColor Cyan
    Write-Host "   Breaking changes will be flagged for manual review`n" -ForegroundColor Gray
    $runResult = & "$PSScriptRoot\Run-CompleteWorkflow.ps1" -ResourceGroupName $rgName -WorkflowRunId $WorkflowRunId -AutoRemediate -SkipComplianceWait -InvokedBy 'Run-ForegroundWorkflowTest.ps1'
} else {
    Write-Host "`n⚠️  Invalid choice '$modeChoice' - defaulting to Production Mode (safe)" -ForegroundColor Yellow
    Write-Host "   Only non-breaking changes will be auto-fixed`n" -ForegroundColor Gray
    $runResult = & "$PSScriptRoot\Run-CompleteWorkflow.ps1" -ResourceGroupName $rgName -WorkflowRunId $WorkflowRunId -AutoRemediate -SkipComplianceWait -InvokedBy 'Run-ForegroundWorkflowTest.ps1'
}

$runEnd = Get-Date

if ($runResult -and $runResult.manifest) {
    Write-Host "`n✅ Workflow execution completed! (manifest: $($runResult.manifest))" -ForegroundColor Green
} else {
    Write-Host "`n✅ Workflow execution completed!" -ForegroundColor Green
}

# STEP 3.5: Validate Azure Policy Compliance
Write-Section "STEP 3.5: VALIDATING AZURE POLICY COMPLIANCE"

Write-Host "Running comprehensive policy validation..." -ForegroundColor Cyan
Write-Host "This validates:" -ForegroundColor Gray
Write-Host "  • Vault-level security (soft delete, purge protection, RBAC, firewall)" -ForegroundColor White
Write-Host "  • Secret/key/cert security (expiration, key strength, cert validity)" -ForegroundColor White
Write-Host "  • Policy detection of violations`n" -ForegroundColor White

$validationResult = & "$PSScriptRoot\Validate-KeyVaultPolicies.ps1" `
    -SubscriptionId $ctx.Subscription.Id `
    -ResourceGroupName $rgName

if ($validationResult) {
    Write-Host "`n✓ Policy validation completed" -ForegroundColor Green
    Write-Host "  Compliance: $($validationResult.CompliancePercent)%" -ForegroundColor $(if ($validationResult.CompliancePercent -ge 80) { "Green" } else { "Yellow" })
    Write-Host "  Issues Found: $($validationResult.TotalIssues)" -ForegroundColor $(if ($validationResult.TotalIssues -eq 0) { "Green" } else { "Red" })
} else {
    Write-Host "`n⚠️  Policy validation completed with warnings" -ForegroundColor Yellow
}

# Check if we got real compliance data
$complianceReportPath = Join-Path "$PSScriptRoot\..\artifacts\json" "compliance-report-$WorkflowRunId.json"
if (Test-Path $complianceReportPath) {
    $complianceData = Get-Content $complianceReportPath | ConvertFrom-Json
    if ($complianceData.totalEvaluations -eq 0) {
        Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Write-Host "⚠️  AZURE POLICY COMPLIANCE DATA NOT YET AVAILABLE" -ForegroundColor Yellow
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Write-Host "`nAzure Policy compliance evaluation typically takes 5-30 minutes after assignment." -ForegroundColor Gray
        Write-Host "The compliance report currently shows 0 evaluations (placeholder).`n" -ForegroundColor Gray
        
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  [W] Wait and check now (query Azure Policy for updated data)" -ForegroundColor White
        Write-Host "  [L] Wait Later - Keep resources and re-run compliance report manually" -ForegroundColor White
        Write-Host "  [C] Continue to cleanup (proceed with testing, ignore compliance data)`n" -ForegroundColor White
        
        $choice = Read-Host "Enter your choice (W/L/C)"
        
        if ($choice -eq 'W' -or $choice -eq 'w') {
            Write-Host "`n⏳ Querying Azure Policy for compliance data..." -ForegroundColor Cyan
            Write-Host "This will re-generate the compliance report with current data and optionally poll until data is available.`n" -ForegroundColor Gray

            # Call the poll helper (default: 60s interval x 10 attempts = up to ~10 minutes)
            $pollResult = Poll-RegenerateCompliance -WorkflowRunId $WorkflowRunId -ResourceGroupName $rgName -IntervalSeconds 60 -MaxAttempts 10 -AutoOpenHtml

            if ($pollResult) {
                Write-Host "`n✓ Compliance report updated and contains evaluations. Check the HTML file." -ForegroundColor Green
            } else {
                Write-Host "`n⚠ Compliance data still not available after polling. Consider waiting longer and re-running the regenerate script later." -ForegroundColor Yellow
            }
        }
        elseif ($choice -eq 'L' -or $choice -eq 'l') {
            Write-Host "`n📝 To re-generate the compliance report later, run:" -ForegroundColor Cyan
            Write-Host "   .\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId $WorkflowRunId -ResourceGroupName $rgName`n" -ForegroundColor White
            Write-Host "💡 Tip: Keep resources alive by choosing [N] at the cleanup prompt below." -ForegroundColor Yellow
        }
        else {
            Write-Host "`nContinuing with test workflow..." -ForegroundColor Gray
        }
    } else {
        Write-Host "`n✓ Compliance data available: $($complianceData.totalEvaluations) evaluations found" -ForegroundColor Green
    }
}

# ===================================================================
# OLD STEPS 4 & 5 (Automatic Cleanup) REMOVED
# ===================================================================
# Bug fix: These steps were deleting resources BEFORE asking the user
# if they wanted to keep them for compliance polling. The cleanup is
# now handled later with a user prompt (see CLEANUP AZURE RESOURCES).
# ===================================================================

# Final summary
Write-Section "WORKFLOW TEST COMPLETE" "Green"

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  0. ✓ Environment preparation" -ForegroundColor Green
if ($createNew) {
    Write-Host "  1. ✓ Environment created (vaults, secrets, keys, certs)" -ForegroundColor Green
    Write-Host "     ✓ Vault seeding with policy test content" -ForegroundColor Green
} else {
    Write-Host "  1. ✓ Existing environment reused" -ForegroundColor Green
}
Write-Host "  2. ✓ Environment verified" -ForegroundColor Green
Write-Host "  3. ✓ Workflow executed (baseline, policies, remediation, reports)" -ForegroundColor Green
Write-Host "     ✓ Policy compliance validation" -ForegroundColor Green
Write-Host "`n" -ForegroundColor Green

Write-Host "Policy Coverage Validated:" -ForegroundColor Cyan
Write-Host "  ✓ Key Vault Service Security (network rules, public access)" -ForegroundColor Green
Write-Host "  ✓ Vault Configuration (soft delete, purge protection, RBAC, firewall)" -ForegroundColor Green
Write-Host "  ✓ Secret/Key/Cert Security (expiration, key types, sizes, cert validity)" -ForegroundColor Green
Write-Host "  ✓ Compliance Frameworks: MCSB, CIS, NIST, CERT`n" -ForegroundColor Green

## Present grouped artifacts created during this run
Write-Host "📁 Artifacts produced during this run (grouped by timestamp):" -ForegroundColor Cyan

# Determine time window for this run
$windowStart = $runStart.AddSeconds(-5)
$windowEnd = $runEnd.AddMinutes(1)

$artifactRoot = Join-Path $PSScriptRoot '..\artifacts'
if (-not (Test-Path $artifactRoot)) {
    Write-Host "  No artifacts folder found." -ForegroundColor Yellow
} else {
    # Collect files created in the run window
    $files = Get-ChildItem -Path $artifactRoot -Recurse -File | Where-Object { $_.LastWriteTime -ge $windowStart -and $_.LastWriteTime -le $windowEnd }
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  No artifacts found in run time window ($($windowStart) - $($windowEnd))." -ForegroundColor Yellow
    } else {
        # Group by exact second timestamp
        $groups = $files | Group-Object { $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') } | Sort-Object Name

        foreach ($g in $groups) {
            Write-Host "`nTimestamp: $($g.Name)" -ForegroundColor Yellow
            $typesPresent = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($f in $g.Group | Sort-Object FullName) {
                $rel = $f.FullName.Replace((Resolve-Path $artifactRoot).Path + '\\', '')
                $ext = $f.Extension.ToLower()
                switch ($ext) {
                    '.json' { $typesPresent.Add('JSON') | Out-Null }
                    '.html' { $typesPresent.Add('HTML') | Out-Null }
                    '.csv'  { $typesPresent.Add('CSV') | Out-Null }
                    '.txt'  { $typesPresent.Add('TXT') | Out-Null }
                    default { $typesPresent.Add($ext.TrimStart('.').ToUpper()) | Out-Null }
                }
                Write-Host "  • $rel ($($f.Length/1KB) KB)" -ForegroundColor White
            }
            # Report missing expected types
            $expected = @('JSON','HTML','CSV')
            $missing = $expected | Where-Object { -not $typesPresent.Contains($_) }
            if ($missing.Count -eq 0) {
                Write-Host "  ✓ All expected types present: $([string]::Join(', ',$typesPresent))" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Missing types: $([string]::Join(', ',$missing)) — present: $([string]::Join(', ',$typesPresent))" -ForegroundColor Yellow
            }
        }
    }
}

# Ask user if they want to cleanup Azure resources
Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " CLEANUP AZURE RESOURCES" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "💡 If you want to wait for Azure Policy compliance data to populate," -ForegroundColor Cyan
Write-Host "   choose [N] to keep resources, then re-run the compliance report:" -ForegroundColor Cyan
Write-Host "   .\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId $WorkflowRunId -ResourceGroupName $rgName`n" -ForegroundColor White

Write-Host "Do you want to clean up the Azure resources created during this test?" -ForegroundColor Yellow
Write-Host "  [Y] Yes - Remove resource group and all policy assignments" -ForegroundColor White
Write-Host "  [N] No - Keep resources (you can manually cleanup later)" -ForegroundColor White
Write-Host ""
$cleanupChoice = Read-Host "Enter your choice (Y/N)"

if ($cleanupChoice -match '^[Yy]') {
    Write-Section "CLEANING UP AZURE RESOURCES" "Red"
    
    & "$PSScriptRoot\Reset-PolicyTestEnvironment.ps1" `
        -ResourceGroupName $rgName `
        -RemovePolicyAssignments `
        -WhatIf:$false `
        -Confirm:$false
    
    Write-Host "`n✓ Azure resources cleaned up" -ForegroundColor Green
    Write-Host "  • Resource group removed: $rgName" -ForegroundColor Gray
    Write-Host "  • Policy assignments removed" -ForegroundColor Gray
} else {
    Write-Host "`n⚠️  Azure resources have been kept" -ForegroundColor Yellow
    Write-Host "  Resource Group: $rgName" -ForegroundColor White
    Write-Host "  Location: $location`n" -ForegroundColor White

    # Offer to poll for compliance now while resources are kept
    Write-Host "Would you like to poll for Azure Policy compliance now while resources are kept? (Y/N)" -ForegroundColor Cyan
    $keepChoice = Read-Host "Enter your choice (Y/N)"
    if ($keepChoice -match '^[Yy]') {
        Write-Host "Starting polling for compliance (attempts: 10, interval: 60s)..." -ForegroundColor Cyan
        $pollResult = Poll-RegenerateCompliance -WorkflowRunId $WorkflowRunId -ResourceGroupName $rgName -IntervalSeconds 60 -MaxAttempts 10 -AutoOpenHtml
        if ($pollResult) {
            Write-Host "Compliance data available after polling." -ForegroundColor Green
        } else {
            Write-Host "Polling finished without finding compliance evaluations. You can re-run Regenerate-ComplianceReport.ps1 later." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Skipping polling; resources will be kept for manual inspection." -ForegroundColor Gray
    }

    Write-Host "To manually cleanup later, run:" -ForegroundColor Cyan
    Write-Host "  .\Reset-PolicyTestEnvironment.ps1 -ResourceGroupName '$rgName' -RemovePolicyAssignments`n" -ForegroundColor Gray
    Write-Host "⚠️  Note: Keeping resources may incur Azure costs" -ForegroundColor Yellow
}

Write-Host "`n🎉 Full workflow test completed!" -ForegroundColor Green
Write-Host ""
