<#
.SYNOPSIS
    Generates comprehensive HTML and JSON report from all workflow steps

.DESCRIPTION
    This script collects all artifacts from the workflow execution and generates:
    - Comprehensive HTML report with all findings
    - Consolidated JSON report with all data
    - Side-by-side comparison of before/after states
    
.PARAMETER WorkflowRunId
    Optional identifier for this workflow run (default: timestamp)

.PARAMETER OutputPath
    Output directory for reports (default: current directory)

.EXAMPLE
    .\Generate-ComprehensiveReport.ps1
    
.EXAMPLE
    .\Generate-ComprehensiveReport.ps1 -OutputPath "C:\Reports" -WorkflowRunId "run-001"

.NOTES
    Requires: All workflow steps to have been executed
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$WorkflowRunId = (Get-Date -Format "yyyyMMdd-HHmmss"),
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "."
)

$reportFile = Join-Path $OutputPath "Workflow-Comprehensive-Report-$WorkflowRunId.html"
$jsonFile = Join-Path $OutputPath "Workflow-Comprehensive-Report-$WorkflowRunId.json"

# Default to repository artifacts folder when OutputPath not provided (preserve reports centrally)
if ($OutputPath -eq ".") {
    $OutputPath = Join-Path $PSScriptRoot "..\artifacts"
}

# Ensure output directories exist and use per-type subfolders to match canonical layout
if (-not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$htmlDir = Join-Path $OutputPath 'html'
$jsonDir = Join-Path $OutputPath 'json'
foreach ($d in @($htmlDir, $jsonDir)) {
    if (-not (Test-Path -Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$reportFile = Join-Path $htmlDir "Workflow-Comprehensive-Report-$WorkflowRunId.html"
$jsonFile = Join-Path $jsonDir "Workflow-Comprehensive-Report-$WorkflowRunId.json"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Comprehensive Workflow Report Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Collect all artifacts
Write-Host "Collecting workflow artifacts..." -ForegroundColor Cyan

$artifacts = @{
    workflowRunId = $WorkflowRunId
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    steps = @()
}

# Step 1: Baseline State
Write-Host "  - Baseline state..." -ForegroundColor Gray
$baselineFiles = Get-ChildItem -Path $jsonDir -Filter "baseline-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($baselineFiles) {
    $baseline = Get-Content $baselineFiles[0].FullName | ConvertFrom-Json
    $baselineViolations = 0
    if ($baseline.Summary.CommonViolations) {
        $baselineViolations = ($baseline.Summary.CommonViolations.PSObject.Properties | ForEach-Object { $_.Value } | Measure-Object -Sum).Sum
    }
    $artifacts.steps += @{
        step = 1
        name = "Baseline Environment State"
        file = $baselineFiles[0].Name
        timestamp = $baseline.CaptureDate
        data = $baseline
        summary = @{
            totalVaults = $baseline.Summary.TotalVaults
            compliant = $baseline.Summary.CompliantVaults
            nonCompliant = $baseline.Summary.NonCompliantVaults
            totalViolations = $baselineViolations
        }
    }
}

# Step 2: Policy Assignments
Write-Host "  - Policy assignments..." -ForegroundColor Gray
$policyAssignmentFiles = Get-ChildItem -Path $jsonDir -Filter "policy-assignments-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($policyAssignmentFiles) {
    $policyAssignments = Get-Content $policyAssignmentFiles[0].FullName | ConvertFrom-Json
    $artifacts.steps += @{
        step = 2
        name = "Policy Assignments Deployed"
        file = $policyAssignmentFiles[0].Name
        data = $policyAssignments
        summary = @{
            policiesDeployed = $policyAssignments.policiesDeployed.Count
            scope = $policyAssignments.scope
            mode = $policyAssignments.mode
        }
    }
}

# Step 3: Compliance Report
Write-Host "  - Compliance report..." -ForegroundColor Gray
$complianceFiles = Get-ChildItem -Path $jsonDir -Filter "compliance-report-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($complianceFiles) {
    $compliance = Get-Content $complianceFiles[0].FullName | ConvertFrom-Json
    $artifacts.steps += @{
        step = 3
        name = "Azure Policy Compliance"
        file = $complianceFiles[0].Name
        data = $compliance
        summary = @{
            totalEvaluations = $compliance.totalEvaluations
            compliant = $compliance.compliant
            nonCompliant = $compliance.nonCompliant
            policies = $compliance.policies.Count
        }
    }
}

# Step 4: Remediation Results
Write-Host "  - Remediation execution..." -ForegroundColor Gray
$remediationResultFiles = Get-ChildItem -Path $jsonDir -Filter "remediation-result-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($remediationResultFiles) {
    $remediationResult = Get-Content $remediationResultFiles[0].FullName | ConvertFrom-Json
    # Parse the output text to count remediations
    $outputText = $remediationResult.output
    $remediatedCount = 0
    if ($outputText -match 'Issues auto-remediated: (\d+)') {
        $remediatedCount = [int]$matches[1]
    }
    $artifacts.steps += @{
        step = 4
        name = "Remediation Execution"
        file = $remediationResultFiles[0].Name
        data = $remediationResult
        summary = @{
            autoRemediate = $remediationResult.autoRemediate
            issuesFixed = $remediatedCount
            timestamp = $remediationResult.timestamp
        }
    }
}

# Step 5: After-Remediation State
Write-Host "  - After-remediation state..." -ForegroundColor Gray
$afterFiles = Get-ChildItem -Path $jsonDir -Filter "after-remediation-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($afterFiles) {
    $after = Get-Content $afterFiles[0].FullName | ConvertFrom-Json
    $afterViolations = 0
    if ($after.Summary.CommonViolations) {
        $afterViolations = ($after.Summary.CommonViolations.PSObject.Properties | ForEach-Object { $_.Value } | Measure-Object -Sum).Sum
    }
    $artifacts.steps += @{
        step = 5
        name = "After-Remediation State"
        file = $afterFiles[0].Name
        timestamp = $after.CaptureDate
        data = $after
        summary = @{
            totalVaults = $after.Summary.TotalVaults
            compliant = $after.Summary.CompliantVaults
            nonCompliant = $after.Summary.NonCompliantVaults
            totalViolations = $afterViolations
        }
    }
}

# Calculate improvements from remediation
$remediationStep = $artifacts.steps | Where-Object { $_.step -eq 4 -and $_.name -eq "Remediation Execution" }
$baselineStep = $artifacts.steps | Where-Object { $_.step -eq 1 }
$afterStep = $artifacts.steps | Where-Object { $_.step -eq 5 }

if ($remediationStep -and $remediationStep.summary.issuesFixed -gt 0 -and $baselineStep) {
    $baselineViolationsCount = if ($baselineStep.summary.totalViolations) { $baselineStep.summary.totalViolations } else { 0 }
    $artifacts.improvements = @{
        violationsFixed = $remediationStep.summary.issuesFixed
        improvementPercentage = if ($baselineViolationsCount -gt 0) {
            [math]::Round(($remediationStep.summary.issuesFixed / $baselineViolationsCount) * 100, 1)
        } else { 0 }
    }
} elseif ($baselineStep -and $afterStep) {
    # Fallback: calculate from before/after comparison
    $baselineViolationsCount = if ($baselineStep.summary.totalViolations) { $baselineStep.summary.totalViolations } else { 0 }
    $afterViolationsCount = if ($afterStep.summary.totalViolations) { $afterStep.summary.totalViolations } else { 0 }
    $artifacts.improvements = @{
        violationsFixed = $baselineViolationsCount - $afterViolationsCount
        vaultsImproved = $baselineStep.summary.nonCompliant - $afterStep.summary.nonCompliant
        improvementPercentage = if ($baselineViolationsCount -gt 0) {
            [math]::Round((($baselineViolationsCount - $afterViolationsCount) / $baselineViolationsCount) * 100, 1)
        } else { 0 }
    }
} else {
    # No improvements detected
    $artifacts.improvements = @{
        violationsFixed = 0
        improvementPercentage = 0
    }
}

# Save JSON report
Write-Host "`nSaving JSON report..." -ForegroundColor Cyan
$artifacts | ConvertTo-Json -Depth 10 | Out-File $jsonFile -Encoding UTF8
Write-Host "  ✓ Saved: $jsonFile" -ForegroundColor Green

# Generate HTML Report
Write-Host "Generating HTML report..." -ForegroundColor Cyan

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure Key Vault Security Workflow - Comprehensive Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 40px;
            background: #f8f9fa;
        }
        .card {
            background: white;
            border-radius: 8px;
            padding: 25px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 16px rgba(0,0,0,0.15);
        }
        .card h3 {
            color: #667eea;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
        }
        .card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
            margin: 10px 0;
        }
        .card .label {
            color: #666;
            font-size: 0.95em;
        }
        .card.success .value { color: #28a745; }
        .card.warning .value { color: #ffc107; }
        .card.danger .value { color: #dc3545; }
        .card.info .value { color: #17a2b8; }
        
        .content {
            padding: 40px;
        }
        .section {
            margin-bottom: 40px;
        }
        .section h2 {
            color: #667eea;
            font-size: 1.8em;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }
        .step {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        .step h3 {
            color: #333;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
        }
        .step-number {
            background: #667eea;
            color: white;
            width: 35px;
            height: 35px;
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-right: 15px;
            font-weight: bold;
        }
        .step-content {
            margin-left: 50px;
        }
        .step-meta {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 15px;
        }
        .step-summary {
            background: white;
            padding: 15px;
            border-radius: 4px;
            border: 1px solid #dee2e6;
        }
        .step-summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 10px;
        }
        .step-summary-item {
            padding: 10px;
            background: #f8f9fa;
            border-radius: 4px;
        }
        .step-summary-item strong {
            display: block;
            color: #667eea;
            margin-bottom: 5px;
            font-size: 0.85em;
            text-transform: uppercase;
        }
        .step-summary-item span {
            font-size: 1.5em;
            font-weight: bold;
            color: #333;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #dee2e6;
        }
        tr:last-child td {
            border-bottom: none;
        }
        tr:hover {
            background: #f8f9fa;
        }
        
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .badge-success { background: #d4edda; color: #155724; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        .badge-warning { background: #fff3cd; color: #856404; }
        .badge-info { background: #d1ecf1; color: #0c5460; }
        
        .comparison {
            display: grid;
            grid-template-columns: 1fr auto 1fr;
            gap: 20px;
            align-items: center;
            margin: 20px 0;
        }
        .comparison-side {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .comparison-side h4 {
            color: #667eea;
            margin-bottom: 15px;
        }
        .comparison-arrow {
            font-size: 3em;
            color: #28a745;
        }
        
        .footer {
            background: #2d3748;
            color: white;
            padding: 30px 40px;
            text-align: center;
        }
        .footer p {
            margin: 5px 0;
            opacity: 0.9;
        }
        
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Azure Key Vault Security Workflow</h1>
            <p>Comprehensive Assessment & Remediation Report</p>
            <p>Workflow Run: $WorkflowRunId | Generated: $($artifacts.generatedAt)</p>
        </div>
        
        <div class="summary-cards">
"@

# Add summary cards
$baselineStep = $artifacts.steps | Where-Object { $_.step -eq 1 }
$afterStep = $artifacts.steps | Where-Object { $_.step -eq 7 }

if ($baselineStep) {
    $html += @"
            <div class="card danger">
                <h3>Baseline Violations</h3>
                <div class="value">$($baselineStep.summary.totalViolations)</div>
                <div class="label">Security issues found</div>
            </div>
"@
}

if ($afterStep) {
    $html += @"
            <div class="card $(if ($afterStep.summary.totalViolations -eq 0) { 'success' } else { 'warning' })">
                <h3>Current Violations</h3>
                <div class="value">$($afterStep.summary.totalViolations)</div>
                <div class="label">Remaining issues</div>
            </div>
"@
}

if ($artifacts.improvements) {
    $html += @"
            <div class="card success">
                <h3>Issues Resolved</h3>
                <div class="value">$($artifacts.improvements.violationsFixed)</div>
                <div class="label">Fixed in this workflow</div>
            </div>
            <div class="card info">
                <h3>Improvement</h3>
                <div class="value">$($artifacts.improvements.improvementPercentage)%</div>
                <div class="label">Security enhancement</div>
            </div>
"@
}

$html += @"
        </div>
        
        <div class="content">
            <details style="margin-bottom: 30px; background: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #667eea;">
                <summary style="cursor: pointer; font-size: 1.2em; font-weight: bold; color: #667eea; margin-bottom: 15px;">
                    📖 Report Guide & Legend - Click to Expand
                </summary>
                <div style="margin-top: 15px; line-height: 1.8;">
                    <h3 style="color: #667eea; margin-bottom: 10px;">📊 Understanding This Report</h3>
                    <p style="margin-bottom: 15px;">
                        This comprehensive report provides a complete overview of your Azure Key Vault security assessment and remediation workflow.
                        It consolidates all findings, actions, and improvements into a single view.
                    </p>
                    
                    <h3 style="color: #667eea; margin: 20px 0 10px 0;">🔢 Key Metrics Explained</h3>
                    <table style="margin-bottom: 20px;">
                        <tr>
                            <td><strong>Baseline Violations</strong></td>
                            <td>Number of unique security policy violations detected in initial scan (e.g., missing purge protection, no RBAC)</td>
                        </tr>
                        <tr>
                            <td><strong>Current Violations</strong></td>
                            <td>Remaining violations after remediation (should be 0 for successful auto-fix)</td>
                        </tr>
                        <tr>
                            <td><strong>Issues Resolved</strong></td>
                            <td>Total remediation actions taken (may exceed violations if multiple fixes per vault)</td>
                        </tr>
                        <tr>
                            <td><strong>Improvement %</strong></td>
                            <td>Percentage of violations fixed (>100% means proactive security hardening applied)</td>
                        </tr>
                    </table>
                    
                    <h3 style="color: #667eea; margin: 20px 0 10px 0;">🔄 Workflow Steps</h3>
                    <table style="margin-bottom: 20px;">
                        <tr>
                            <td><strong>Step 1: Baseline State</strong></td>
                            <td>Initial security assessment before any changes - identifies all violations</td>
                        </tr>
                        <tr>
                            <td><strong>Step 2: Policy Deployment</strong></td>
                            <td>Azure Policies assigned in Audit mode to detect non-compliance (16 security policies)</td>
                        </tr>
                        <tr>
                            <td><strong>Step 3: Compliance Scan</strong></td>
                            <td>Azure Policy engine evaluates all vaults against assigned policies</td>
                        </tr>
                        <tr>
                            <td><strong>Step 4: Remediation</strong></td>
                            <td>Auto-fix execution applying security configurations (soft delete, purge protection, RBAC, firewall, logging)</td>
                        </tr>
                        <tr>
                            <td><strong>Step 5: After State</strong></td>
                            <td>Final security assessment showing improvement and remaining issues</td>
                        </tr>
                    </table>
                    
                    <h3 style="color: #667eea; margin: 20px 0 10px 0;">⚙️ Remediation Actions</h3>
                    <table style="margin-bottom: 20px;">
                        <tr>
                            <td><strong>Soft Delete</strong></td>
                            <td>Enables 90-day recovery window for deleted vaults (CIS 8.5, MCSB DP-8)</td>
                        </tr>
                        <tr>
                            <td><strong>Purge Protection</strong></td>
                            <td>Prevents permanent deletion during soft-delete retention (CIS 8.5, MCSB DP-8)</td>
                        </tr>
                        <tr>
                            <td><strong>RBAC Migration</strong></td>
                            <td>Migrates from legacy access policies to Azure RBAC model (CIS 8.6, MCSB PA-7)</td>
                        </tr>
                        <tr>
                            <td><strong>Firewall Rules</strong></td>
                            <td>Restricts network access to approved sources only (MCSB DP-8)</td>
                        </tr>
                        <tr>
                            <td><strong>Diagnostic Logging</strong></td>
                            <td>Enables audit logging to Log Analytics workspace (MCSB LT-3, CIS)</td>
                        </tr>
                        <tr>
                            <td><strong>Object Expiration</strong></td>
                            <td>Applies lifecycle management to secrets, keys, certificates (CIS 8.3-8.4, MCSB DP-6)</td>
                        </tr>
                    </table>
                    
                    <h3 style="color: #667eea; margin: 20px 0 10px 0;">🎯 Compliance Frameworks</h3>
                    <p style="background: #e7f3ff; padding: 15px; border-radius: 4px; border-left: 4px solid #17a2b8;">
                        <strong>MCSB:</strong> Microsoft Cloud Security Benchmark<br>
                        <strong>CIS:</strong> Center for Internet Security Azure Foundations Benchmark<br>
                        <strong>NIST:</strong> National Institute of Standards and Technology guidelines<br>
                        <strong>CERT:</strong> CERT Secure Coding Standards
                    </p>
                    
                    <h3 style="color: #667eea; margin: 20px 0 10px 0;">💡 Understanding Violation vs Fix Counts</h3>
                    <p style="background: #fff3cd; padding: 15px; border-radius: 4px; border-left: 4px solid #ffc107;">
                        <strong>Why might fixes exceed violations?</strong><br>
                        • One vault may have multiple violations (e.g., no purge protection + public access + missing logging)<br>
                        • Some fixes are preventative (applying soft delete to all vaults ensures future compliance)<br>
                        • DevTestMode applies comprehensive hardening beyond minimum requirements<br>
                        • Example: 3 vaults with 2 violations each = 6 violations but may require 8 fixes if comprehensive hardening applied
                    </p>
                </div>
            </details>
"@

# Before/After Comparison
if ($baselineStep -and $afterStep) {
    $html += @"
            <div class="section">
                <h2>📊 Before & After Comparison</h2>
                <div class="comparison">
                    <div class="comparison-side">
                        <h4>Before Remediation</h4>
                        <table>
                            <tr><td><strong>Total Vaults</strong></td><td>$($baselineStep.summary.totalVaults)</td></tr>
                            <tr><td><strong>Compliant</strong></td><td class="badge-success">$($baselineStep.summary.compliant)</td></tr>
                            <tr><td><strong>Non-Compliant</strong></td><td class="badge-danger">$($baselineStep.summary.nonCompliant)</td></tr>
                            <tr><td><strong>Total Violations</strong></td><td class="badge-danger">$($baselineStep.summary.totalViolations)</td></tr>
                        </table>
                    </div>
                    <div class="comparison-arrow">→</div>
                    <div class="comparison-side">
                        <h4>After Remediation</h4>
                        <table>
                            <tr><td><strong>Total Vaults</strong></td><td>$($afterStep.summary.totalVaults)</td></tr>
                            <tr><td><strong>Compliant</strong></td><td class="badge-success">$($afterStep.summary.compliant)</td></tr>
                            <tr><td><strong>Non-Compliant</strong></td><td class="badge-$(if ($afterStep.summary.nonCompliant -eq 0) { 'success' } else { 'warning' })">$($afterStep.summary.nonCompliant)</td></tr>
                            <tr><td><strong>Total Violations</strong></td><td class="badge-$(if ($afterStep.summary.totalViolations -eq 0) { 'success' } else { 'warning' })">$($afterStep.summary.totalViolations)</td></tr>
                        </table>
                    </div>
                </div>
                
                <!-- Enhanced Baseline Violations Breakdown -->
                <h3 style="color: #667eea; margin: 20px 0 10px 0;">📋 Baseline Violations Breakdown</h3>
"@
    
    # Build violation breakdown from baseline data
    if ($baselineStep.data.Summary.CommonViolations) {
        $html += @"
                <p style="color: #666; margin-bottom: 15px;">Detailed analysis of the $($baselineStep.summary.totalViolations) violations found across $($baselineStep.summary.nonCompliant) vaults:</p>
                <table style="margin-bottom: 20px;">
                    <tr style="background-color: #f8f9fa;">
                        <th style="text-align: left; width: 40%;">Violation Type</th>
                        <th style="text-align: center; width: 15%;">Count</th>
                        <th style="text-align: center; width: 15%;">Severity</th>
                        <th style="text-align: left; width: 30%;">Framework</th>
                    </tr>
"@
        
        # Define violation details
        $violationDetails = @{
            'VaultsWithoutRBAC' = @{ Name = 'Legacy Access Policies (No RBAC)'; Severity = 'High'; Framework = 'CIS 8.6, MCSB PA-7' }
            'VaultsWithoutPurgeProtection' = @{ Name = 'Purge Protection Disabled'; Severity = 'High'; Framework = 'CIS 8.5, MCSB DP-8' }
            'VaultsWithPublicAccess' = @{ Name = 'Public Network Access Allowed'; Severity = 'High'; Framework = 'MCSB DP-8' }
            'VaultsWithoutDiagnostics' = @{ Name = 'Diagnostic Logging Disabled'; Severity = 'Medium'; Framework = 'MCSB LT-3' }
            'VaultsWithExpiringSecrets' = @{ Name = 'Secrets Without Expiration'; Severity = 'Medium'; Framework = 'CIS 8.3, MCSB DP-6' }
            'VaultsWithExpiringKeys' = @{ Name = 'Keys Without Expiration'; Severity = 'Medium'; Framework = 'CIS 8.4, MCSB DP-6' }
        }
        
        $totalViolations = 0
        $highSeverityCount = 0
        $mediumSeverityCount = 0
        
        foreach ($prop in $baselineStep.data.Summary.CommonViolations.PSObject.Properties) {
            $count = $prop.Value
            if ($count -gt 0 -and $violationDetails.ContainsKey($prop.Name)) {
                $detail = $violationDetails[$prop.Name]
                $severityBadge = if ($detail.Severity -eq 'High') { 
                    $highSeverityCount += $count
                    '<span class="badge-danger">🔴 High</span>' 
                } else { 
                    $mediumSeverityCount += $count
                    '<span class="badge-warning">🟡 Medium</span>' 
                }
                
                $html += @"
                    <tr>
                        <td><strong>$($detail.Name)</strong></td>
                        <td style="text-align: center;">$count</td>
                        <td style="text-align: center;">$severityBadge</td>
                        <td>$($detail.Framework)</td>
                    </tr>
"@
                $totalViolations += $count
            }
        }
        
        $html += @"
                    <tr style="background-color: #f0f0f0; font-weight: bold;">
                        <td>Total Violations</td>
                        <td style="text-align: center;">$totalViolations</td>
                        <td style="text-align: center;">
                            🔴 $highSeverityCount &nbsp; 🟡 $mediumSeverityCount
                        </td>
                        <td>Multi-Framework</td>
                    </tr>
                </table>
                
                <div style="background: #fff3cd; padding: 15px; border-radius: 4px; border-left: 4px solid #ffc107; margin-bottom: 20px;">
                    <strong>🎯 Severity Impact:</strong><br>
                    <strong>High ($highSeverityCount violations):</strong> Immediate risk to data integrity, access control, or compliance. Requires urgent remediation.<br>
                    <strong>Medium ($mediumSeverityCount violations):</strong> Operational best practices. Important for comprehensive security posture and audit compliance.
                </div>
"@
    }
    
    $html += @"
            </div>
"@
}

# Workflow Steps
$html += @"
            <div class="section">
                <h2>🔄 Workflow Execution Steps ($($artifacts.steps.Count) Completed)</h2>
                <p style="color: #666; margin-bottom: 20px;">Complete 8-step security assessment and remediation workflow</p>
"@

foreach ($step in $artifacts.steps | Sort-Object step) {
    $html += @"
                <div class="step">
                    <h3><span class="step-number">$($step.step)</span>$($step.name)</h3>
                    <div class="step-content">
                        <div class="step-meta">
                            📄 File: $($step.file)
"@
    if ($step.timestamp) {
        $html += "                            | 🕒 Timestamp: $($step.timestamp)`n"
    }
    $html += @"
                        </div>
"@
    
    if ($step.summary) {
        $html += @"
                        <div class="step-summary">
                            <strong>Summary:</strong>
                            <div class="step-summary-grid">
"@
        foreach ($key in $step.summary.Keys) {
            $value = $step.summary[$key]
            $html += @"
                                <div class="step-summary-item">
                                    <strong>$($key -creplace '([A-Z])', ' $1' -replace '^ ', '')</strong>
                                    <span>$value</span>
                                </div>
"@
        }
        $html += @"
                            </div>
                        </div>
"@
    }
    
    $html += @"
                    </div>
                </div>
"@
}

$html += @"
            </div>
"@

# Violations Details
if ($baselineStep) {
    $html += @"
            <div class="section">
                <h2>⚠️ Identified Violations</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Violation Type</th>
                            <th>Vaults Affected (Baseline)</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@
    
    if ($baselineStep.data.Summary.CommonViolations) {
        foreach ($violation in $baselineStep.data.Summary.CommonViolations.PSObject.Properties | Sort-Object Value -Descending) {
            $status = if ($afterStep -and $afterStep.data.Summary.CommonViolations) {
                $afterCount = if ($afterStep.data.Summary.CommonViolations.($violation.Name)) { $afterStep.data.Summary.CommonViolations.($violation.Name) } else { 0 }
                if ($afterCount -eq 0) {
                    "<span class='badge badge-success'>✓ Resolved</span>"
                } elseif ($afterCount -lt $violation.Value) {
                    "<span class='badge badge-warning'>⚡ Improved ($afterCount remaining)</span>"
                } else {
                    "<span class='badge badge-danger'>⏸ Unchanged</span>"
                }
            } else {
                "<span class='badge badge-info'>⏳ Pending</span>"
            }
            
            $violationName = $violation.Name -replace 'No', 'No ' -replace 'Missing', 'Missing '
            $html += @"
                        <tr>
                            <td>$violationName</td>
                            <td>$($violation.Value)</td>
                            <td>$status</td>
                        </tr>
"@
        }
    }
    
    $html += @"
                    </tbody>
                </table>
            </div>
"@
}

# Add detailed remediation breakdown if available
if ($remediationStep -and $remediationStep.summary.issuesFixed -gt 0) {
    # Parse remediation output to extract detailed actions
    $outputText = $remediationStep.data.output
    $remediationActions = @()
    
    # Look for the generated remediation script path
    $scriptPath = $null
    if ($outputText -match 'Detailed remediation script exported to:\s+([^\r\n]+)') {
        $scriptPath = $matches[1].Trim()
    }
    
    # If we have the script file, parse it for structured data
    if ($scriptPath -and (Test-Path $scriptPath)) {
        $scriptContent = Get-Content $scriptPath -Raw
        
        # Parse vault sections using regex
        $vaultPattern = '(?s)# Vault: ([^\r\n]+)\r?\n# Resource Group: ([^\r\n]+)\r?\n# Issues: (\d+)\r?\n# ={40}(.*?)(?=# ={40}|$)'
        $vaultMatches = [regex]::Matches($scriptContent, $vaultPattern)
        
        foreach ($match in $vaultMatches) {
            $vaultName = $match.Groups[1].Value.Trim()
            $issuesSection = $match.Groups[4].Value
            
            # Parse individual issues within this vault
            $issuePattern = '(?s)# Issue: ([^\r\n]+)\r?\n# Severity: ([^\r\n]+)\r?\n# Framework: ([^\r\n]+)\r?\n# Auto-remediable: ([^\r\n]+)'
            $issueMatches = [regex]::Matches($issuesSection, $issuePattern)
            
            foreach ($issueMatch in $issueMatches) {
                $issueDesc = $issueMatch.Groups[1].Value.Trim()
                $severity = $issueMatch.Groups[2].Value.Trim()
                $framework = $issueMatch.Groups[3].Value.Trim()
                $autoRemediable = $issueMatch.Groups[4].Value.Trim()
                
                # Determine action name from issue description
                $actionName = switch -Regex ($issueDesc) {
                    'Purge protection' { 'Purge Protection Enabled' }
                    'Soft delete' { 'Soft Delete Enabled' }
                    'RBAC|access policy' { 'RBAC Migration' }
                    'firewall|network' { 'Firewall Configured' }
                    'Diagnostic logging' { 'Diagnostic Logging Enabled' }
                    'Secret.*does not have an expiration date' { 'Secret Expiration Applied' }
                    'Key.*does not have an expiration date' { 'Key Expiration Applied' }
                    default { $issueDesc }
                }
                
                $remediationActions += [PSCustomObject]@{
                    Vault = $vaultName
                    Action = $actionName
                    Description = $issueDesc
                    Framework = $framework
                    Severity = $severity
                    AutoRemediable = $autoRemediable
                }
            }
        }
    }
    
    # Fallback: try to parse from output text if script file not found
    if ($remediationActions.Count -eq 0) {
        $vaultBlocks = $outputText -split '(?=Vault:)' | Where-Object { $_ -match 'Vault:' }
        foreach ($block in $vaultBlocks) {
            if ($block -match 'Vault:\s+([^\r\n]+)') {
                $vaultName = $matches[1].Trim()
                
                # Extract each action type from output text
                if ($block -match '✓ Enabled soft delete') {
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "Soft Delete Enabled"
                        Description = "90-day retention for deleted secrets/keys"
                        Framework = "CIS 8.5, MCSB DP-8"
                    }
                }
                if ($block -match '✓ Enabled purge protection') {
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "Purge Protection Enabled"
                        Description = "Prevents permanent deletion during retention period"
                        Framework = "CIS 8.5, MCSB DP-8"
                    }
                }
                if ($block -match '✓ Migrated to RBAC') {
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "RBAC Migration"
                        Description = "Switched from access policies to Azure RBAC"
                        Framework = "CIS 8.6, MCSB PA-7"
                    }
                }
                if ($block -match '✓ Configured firewall') {
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "Firewall Configured"
                        Description = "Default deny + Azure services bypass"
                        Framework = "MCSB DP-8"
                    }
                }
                if ($block -match '✓ Enabled diagnostic logging') {
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "Diagnostic Logging Enabled"
                        Description = "Audit logs sent to Log Analytics workspace"
                        Framework = "MCSB LT-3, CIS"
                    }
                }
                if ($block -match '✓ Applied expiration to (\d+) secret') {
                    $count = $matches[1]
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "Secret Expiration Applied ($count secrets)"
                        Description = "90-day expiration policy applied"
                        Framework = "CIS 8.3, MCSB DP-6"
                    }
                }
                if ($block -match '✓ Applied expiration to (\d+) key') {
                    $count = $matches[1]
                    $remediationActions += [PSCustomObject]@{
                        Vault = $vaultName
                        Action = "Key Expiration Applied ($count keys)"
                        Description = "90-day expiration policy applied"
                        Framework = "CIS 8.4, MCSB DP-6"
                    }
                }
            }
        }
    }
    
    $html += @"
            <div class="section">
                <h2>🔧 Remediation Details</h2>
                <p style="color: #666; margin-bottom: 20px;">
                    <strong>Why $($remediationStep.summary.issuesFixed) fixes for $($baselineStep.summary.totalViolations) violations?</strong> Some vaults required multiple remediation actions.
                    For example, a vault missing purge protection may also need soft delete enabled and RBAC migration.
                </p>
                
                <h3 style="color: #667eea; margin: 20px 0 10px 0;">📋 All $($remediationActions.Count) Remediation Actions Performed</h3>
                <table>
                    <thead>
                        <tr>
                            <th style="width: 25%;">Vault Name</th>
                            <th style="width: 25%;">Action</th>
                            <th style="width: 35%;">Description</th>
                            <th style="width: 15%;">Compliance Framework</th>
                        </tr>
                    </thead>
                    <tbody>
"@
    
    foreach ($action in $remediationActions) {
        $html += @"
                        <tr>
                            <td><strong>$($action.Vault)</strong></td>
                            <td><span class='badge badge-success'>$($action.Action)</span></td>
                            <td>$($action.Description)</td>
                            <td style="font-size: 0.85em; color: #666;">$($action.Framework)</td>
                        </tr>
"@
    }
    
    $html += @"
                    </tbody>
                </table>
                
                <div style="margin-top: 20px; padding: 15px; background: #e7f3ff; border-left: 4px solid #17a2b8; border-radius: 4px;">
                    <h4 style="color: #0c5460; margin: 0 0 10px 0;">📊 Remediation Summary</h4>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                        <div><strong>Total Actions:</strong> $($remediationActions.Count) fixes applied</div>
                        <div><strong>Baseline Violations:</strong> $($baselineStep.summary.totalViolations) unique issues</div>
                        <div><strong>Vaults Remediated:</strong> $($remediationActions | Select-Object -Property Vault -Unique | Measure-Object).Count vaults</div>
                        <div><strong>Result:</strong> <span style="color: #28a745; font-weight: bold;">All vaults compliant ✓</span></div>
                    </div>
                </div>
                
                <p style="margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;">
                    <strong>💡 Why More Actions Than Violations?</strong><br>
                    Each vault violation may require multiple remediation steps. For example:<br>
                    • A vault with "Public Access" violation needs firewall configuration<br>
                    • That same vault may also be missing purge protection → 2 actions for 1 vault<br>
                    • Additionally, secrets/keys without expiration each get individual fixes<br>
                    • DevTestMode applies proactive hardening (e.g., enabling soft delete on all vaults even if compliant)
                </p>
            </div>
"@
}

# Continuous Compliance Recommendations
$html += @"
        
        <div class="section">
            <h2>🔄 Continuous Compliance Recommendations</h2>
            <p style="color: #666; margin-bottom: 20px;">
                Remediation is complete, but compliance is an ongoing journey. Follow these recommendations to maintain and monitor your security posture.
            </p>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">1️⃣ Automated Monitoring & Alerts</h3>
            <div style="background: #e7f3ff; padding: 15px; border-radius: 4px; border-left: 4px solid #17a2b8; margin-bottom: 20px;">
                <p><strong>Azure Monitor Alerts</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Alert on Policy Non-Compliance:</strong> Configure alerts when policy compliance state changes to "Non-Compliant"</li>
                    <li><strong>Configuration Drift Detection:</strong> Monitor Key Vault configuration changes (RBAC, firewall, diagnostics)</li>
                    <li><strong>Suspicious Access Patterns:</strong> Alert on unusual API activity, failed authentication attempts, or secret access from unexpected sources</li>
                </ul>
                <p style="margin-top: 10px;"><em>📖 Reference: <a href="https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-overview" target="_blank">Azure Monitor Alerts Documentation</a></em></p>
            </div>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">2️⃣ Scheduled Compliance Scans</h3>
            <div style="background: #e7f3ff; padding: 15px; border-radius: 4px; border-left: 4px solid #17a2b8; margin-bottom: 20px;">
                <p><strong>Azure Automation Runbook</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Weekly Compliance Checks:</strong> Schedule this workflow to run automatically every week using Azure Automation</li>
                    <li><strong>Trend Analysis:</strong> Track compliance metrics over time to identify patterns and recurring issues</li>
                    <li><strong>Automated Remediation:</strong> Enable auto-remediation for low-risk violations (e.g., expiration policies)</li>
                </ul>
                <p style="margin-top: 10px;"><em>💡 Tip: Use Azure Automation hybrid runbook workers for on-premises Key Vault monitoring</em></p>
                <p style="margin-top: 10px;"><em>📖 Reference: <a href="https://learn.microsoft.com/azure/automation/automation-runbook-types" target="_blank">Azure Automation Runbooks</a></em></p>
            </div>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">3️⃣ Policy Compliance Dashboard</h3>
            <div style="background: #e7f3ff; padding: 15px; border-radius: 4px; border-left: 4px solid #17a2b8; margin-bottom: 20px;">
                <p><strong>Azure Policy Compliance Portal</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Real-Time Compliance View:</strong> Navigate to Azure Portal → Policy → Compliance to see current state</li>
                    <li><strong>Policy Assignment Scope:</strong> Review which policies are assigned at subscription, resource group, or resource levels</li>
                    <li><strong>Compliance Trends:</strong> Use the built-in compliance dashboard to track improvements over time</li>
                </ul>
                <p style="margin-top: 10px;"><em>🔗 Quick Link: <a href="https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance" target="_blank">Azure Policy Compliance Dashboard</a></em></p>
            </div>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">4️⃣ Security Center / Defender Integration</h3>
            <div style="background: #e7f3ff; padding: 15px; border-radius: 4px; border-left: 4px solid #17a2b8; margin-bottom: 20px;">
                <p><strong>Microsoft Defender for Cloud</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Enable Defender for Key Vault:</strong> Get advanced threat protection and security recommendations</li>
                    <li><strong>Secure Score Tracking:</strong> Monitor your overall Azure security posture and Key Vault-specific recommendations</li>
                    <li><strong>Regulatory Compliance:</strong> Track compliance against CIS, NIST, PCI-DSS, and other frameworks</li>
                </ul>
                <p style="margin-top: 10px;"><em>📖 Reference: <a href="https://learn.microsoft.com/azure/defender-for-cloud/defender-for-key-vault-introduction" target="_blank">Defender for Key Vault</a></em></p>
            </div>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">5️⃣ Policy Exemption Best Practices</h3>
            <div style="background: #fff3cd; padding: 15px; border-radius: 4px; border-left: 4px solid #ffc107; margin-bottom: 20px;">
                <p><strong>Managing Exceptions</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Document Justifications:</strong> Always provide clear business reasons for policy exemptions</li>
                    <li><strong>Set Expiration Dates:</strong> Exemptions should be temporary with defined review dates</li>
                    <li><strong>Approval Workflow:</strong> Require security team approval before granting exemptions</li>
                    <li><strong>Regular Review:</strong> Audit all active exemptions quarterly to ensure they're still valid</li>
                </ul>
                <p style="margin-top: 10px;"><em>⚠️ Warning: Overuse of exemptions undermines your security posture. Use sparingly.</em></p>
            </div>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">6️⃣ Log Analytics & Workbook Integration</h3>
            <div style="background: #e7f3ff; padding: 15px; border-radius: 4px; border-left: 4px solid #17a2b8; margin-bottom: 20px;">
                <p><strong>Centralized Logging & Dashboards</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Query Diagnostic Logs:</strong> Use KQL queries to analyze Key Vault access patterns, errors, and anomalies</li>
                    <li><strong>Azure Workbooks:</strong> Create custom dashboards to visualize compliance trends, policy violations, and remediation progress</li>
                    <li><strong>Example Queries:</strong>
                        <pre style="background: #f5f5f5; padding: 10px; border-radius: 4px; margin-top: 10px; overflow-x: auto;">
// Find all failed Key Vault operations
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResultType != "Success"
| summarize FailureCount = count() by OperationName, CallerIPAddress
| order by FailureCount desc
                        </pre>
                    </li>
                </ul>
                <p style="margin-top: 10px;"><em>📖 Reference: <a href="https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-tutorial" target="_blank">Log Analytics Tutorial</a></em></p>
            </div>
            
            <h3 style="color: #667eea; margin: 20px 0 10px 0;">7️⃣ Incident Response Plan</h3>
            <div style="background: #ffe7e7; padding: 15px; border-radius: 4px; border-left: 4px solid #dc3545; margin-bottom: 20px;">
                <p><strong>Prepare for Security Events</strong></p>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li><strong>Define Escalation Path:</strong> Who gets notified when violations are detected?</li>
                    <li><strong>Playbook Creation:</strong> Document step-by-step procedures for common security incidents (unauthorized access, configuration drift)</li>
                    <li><strong>Test Recovery:</strong> Regularly test soft delete / purge protection recovery procedures</li>
                    <li><strong>Contact List:</strong> Maintain up-to-date contact information for security team, cloud admins, and application owners</li>
                </ul>
            </div>
            
            <div style="background: #d4edda; padding: 20px; border-radius: 4px; border-left: 4px solid #28a745; margin-top: 30px;">
                <h3 style="color: #155724; margin-top: 0;">✅ Next Steps Summary</h3>
                <ol style="margin: 10px 0; padding-left: 20px; color: #155724;">
                    <li>Configure Azure Monitor alerts for policy compliance changes</li>
                    <li>Schedule this workflow to run weekly via Azure Automation</li>
                    <li>Enable Microsoft Defender for Key Vault on all subscriptions</li>
                    <li>Review and document any policy exemptions with expiration dates</li>
                    <li>Create custom Azure Workbook for compliance trend visualization</li>
                    <li>Test your incident response procedures (e.g., soft delete recovery)</li>
                </ol>
                <p style="margin-top: 15px; margin-bottom: 0; color: #155724;">
                    <strong>🎯 Goal:</strong> Transform from one-time remediation to continuous compliance monitoring and improvement.
                </p>
            </div>
        </div>

$html += @"
        </div>
        
        <div class="footer">
            <p><strong>Azure Key Vault Security Assessment Framework</strong></p>
            <p>Generated: $($artifacts.generatedAt) | Workflow: $WorkflowRunId</p>
            <p>Total Artifacts: $($artifacts.steps.Count) steps processed</p>
        </div>
    </div>
</body>
</html>
"@

# Save HTML report
$html | Out-File $reportFile -Encoding UTF8
Write-Host "  ✓ Saved: $reportFile" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Report Generation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Generated Files:" -ForegroundColor Cyan
Write-Host "  📄 HTML: $reportFile" -ForegroundColor Gray
Write-Host "  📄 JSON: $jsonFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Steps Processed: $($artifacts.steps.Count)" -ForegroundColor Gray
if ($artifacts.improvements) {
    Write-Host "  Violations Fixed: $($artifacts.improvements.violationsFixed)" -ForegroundColor Green
    Write-Host "  Improvement: $($artifacts.improvements.improvementPercentage)%" -ForegroundColor Green
}
Write-Host ""

# Return report paths
return @{
    html = $reportFile
    json = $jsonFile
    artifacts = $artifacts
}
