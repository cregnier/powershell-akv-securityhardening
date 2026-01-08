<#
.SYNOPSIS
    Re-generates the compliance report for a specific workflow run.

.DESCRIPTION
    This script re-queries Azure Policy compliance data and regenerates the
    compliance report HTML/JSON files. Useful when compliance data wasn't
    available during the initial workflow run (Azure Policy evaluation can
    take 5-30 minutes after policy assignment).

.PARAMETER WorkflowRunId
    The workflow run ID (timestamp format: yyyyMMdd-HHmmss)

.PARAMETER ResourceGroupName
    Optional. Filter compliance data to specific resource group.

.EXAMPLE
    .\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310
    
.EXAMPLE
    .\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310 -ResourceGroupName rg-policy-keyvault-test
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkflowRunId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = 'Stop'

# Get Azure context
try {
    $ctx = Get-AzContext
    if (-not $ctx) {
        throw "Not connected to Azure. Run Connect-AzAccount first."
    }
    $SubscriptionId = $ctx.Subscription.Id
} catch {
    Write-Error "Failed to get Azure context: $_"
    exit 1
}

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " REGENERATE COMPLIANCE REPORT" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "Workflow Run ID: $WorkflowRunId" -ForegroundColor White
Write-Host "Subscription: $($ctx.Subscription.Name) ($SubscriptionId)" -ForegroundColor Gray
if ($ResourceGroupName) {
    Write-Host "Resource Group Filter: $ResourceGroupName" -ForegroundColor Gray
}
Write-Host ""

# Define output paths
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonDir = Join-Path (Split-Path -Parent $scriptRoot) "artifacts\json"
$htmlDir = Join-Path (Split-Path -Parent $scriptRoot) "artifacts\html"
$csvDir = Join-Path (Split-Path -Parent $scriptRoot) "artifacts\csv"

$complianceJson = Join-Path $jsonDir "compliance-report-$WorkflowRunId.json"
$complianceHtml = Join-Path $htmlDir "compliance-report-$WorkflowRunId.html"
$complianceCsv = Join-Path $csvDir "compliance-report-$WorkflowRunId.csv"

# Query Azure Policy compliance data
Write-Host "⏳ Querying Azure Policy for compliance data..." -ForegroundColor Cyan
$allComplianceData = Get-AzPolicyState -SubscriptionId $SubscriptionId -Filter "ResourceType eq 'Microsoft.KeyVault/vaults'" -ErrorAction SilentlyContinue

if ($allComplianceData) {
    Write-Host "  ✓ Retrieved $($allComplianceData.Count) total Key Vault policy evaluations" -ForegroundColor Green
    
    if ($ResourceGroupName) {
        Write-Host "  Filtering for resource group: $ResourceGroupName" -ForegroundColor Gray
        $complianceData = $allComplianceData | Where-Object { $_.ResourceId -like "*/resourcegroups/$ResourceGroupName/*" }
        Write-Host "  After filtering: $($complianceData.Count) evaluations in target resource group" -ForegroundColor Gray
        
        # Debug: Show sample ResourceId if filtered count is 0
        if ($complianceData.Count -eq 0 -and $allComplianceData.Count -gt 0) {
            $sampleId = $allComplianceData[0].ResourceId
            Write-Host "  ⚠ Note: Sample ResourceId format: $sampleId" -ForegroundColor Yellow
            Write-Host "  ⚠ Looking for pattern: */resourcegroups/$ResourceGroupName/*" -ForegroundColor Yellow
        }
    } else {
        $complianceData = $allComplianceData
    }
} else {
    Write-Host "  ⚠ No compliance data retrieved from Azure Policy" -ForegroundColor Yellow
    $complianceData = @()
}

if ($complianceData.Count -eq 0) {
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host "⚠️  STILL NO COMPLIANCE DATA AVAILABLE" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Yellow
    
    Write-Host "Azure Policy compliance evaluation can take 15-30 minutes after policy assignment." -ForegroundColor Gray
    Write-Host "Please wait longer and try again.`n" -ForegroundColor Gray
    
    Write-Host "Tips:" -ForegroundColor Cyan
    Write-Host "  • Check Azure Portal → Policy → Compliance to see if evaluations are complete" -ForegroundColor White
    Write-Host "  • Ensure policy assignments are active (not in 'NotStarted' state)" -ForegroundColor White
    Write-Host "  • Wait at least 15-30 minutes after initial policy assignment`n" -ForegroundColor White
    
    exit 0
}

# Create policy name mapping for friendly display
$policyNameMap = @{
    '0b60c0b2-2dc2-4e1c-b5c9-abbed971de53' = 'Key Vault Soft Delete'
    'a400a00b-2de8-46d3-a5a3-72631a0e0e92' = 'Key Vault Purge Protection'
    '12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5' = 'Key Vault RBAC Authorization'
    '55615ac9-af46-4a59-874e-391cc3dfb490' = 'Key Vault Network Firewall'
    '1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d' = 'Key Vault Private Link'
    '98728c90-32c7-4049-8429-847dc0f4fe37' = 'Key Vault Secrets Expiration'
    '152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0' = 'Key Vault Keys Expiration'
    '75c4f823-d65a-4f59-a679-427d20e9ba0d' = 'Key Vault Allowed Key Types'
    '82067dbb-e53b-4e06-b631-546d197452d9' = 'Key Vault RSA Key Minimum Size'
    'ff25f3c8-b739-4538-9d07-3d6d25cfb255' = 'Key Vault EC Key Minimum Curve'
    '0aa6d03c-b052-4f49-9992-64c697e7d88b' = 'Key Vault Certificate Validity Period'
    'a22f4a40-01d3-4c7d-8071-da157eeff341' = 'Key Vault Certificate Approved CAs'
    '11c30ece-f97b-45b9-9e84-1c43c2e88e19' = 'Key Vault Certificate EC Curve'
    '1151cede-290b-4ba0-8b38-0ad145ac888f' = 'Key Vault Certificate Key Type'
    '7d39b5a6-aff5-44e3-a5d5-9e72e5b7f1da' = 'Key Vault Certificate Renewal'
    'a6abeaec-4d90-4a02-805f-6b26c4d3fbe9' = 'Azure Key Vaults should use private link'
    'cf820ca0-f99e-4f3e-84fb-66e913812d21' = 'Azure Key Vault should have diagnostic logging enabled'
    '12ef42fe-5c3e-4529-a4e4-8d582e2e4c77' = 'Certificates should have a lifetime action trigger'
}

Write-Host "`n⚙️  Generating reports..." -ForegroundColor Cyan

# Export CSV
$csvHeader = @"
# Azure Policy Compliance Report
# Generated by: Regenerate-ComplianceReport.ps1
# Command: .\Regenerate-ComplianceReport.ps1 -WorkflowRunId $WorkflowRunId$(if ($ResourceGroupName) { " -ResourceGroupName $ResourceGroupName" })
# Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Subscription: $SubscriptionId
# Note: Azure Policy evaluates each vault AND each resource (secrets, keys, certificates) separately
#
"@
$csvHeader | Out-File $complianceCsv -Encoding UTF8 -NoNewline
$complianceData | Select-Object ResourceId, PolicyDefinitionName, PolicyDefinitionAction, ComplianceState, Timestamp |
    Export-Csv $complianceCsv -NoTypeInformation -Append
Write-Host "  ✓ CSV: $complianceCsv" -ForegroundColor Green

# Create JSON
$complianceReport = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    subscriptionId = $SubscriptionId
    totalEvaluations = $complianceData.Count
    compliant = ($complianceData | Where-Object ComplianceState -eq 'Compliant').Count
    nonCompliant = ($complianceData | Where-Object ComplianceState -eq 'NonCompliant').Count
    policies = $complianceData | Group-Object PolicyDefinitionName | ForEach-Object {
        $policyGuid = $_.Name -replace '.*/([^/]+)$','$1'
        $friendlyName = if ($policyNameMap.ContainsKey($policyGuid)) { $policyNameMap[$policyGuid] } else { $policyGuid }
        @{
            policyName = $_.Name
            policyGuid = $policyGuid
            friendlyName = $friendlyName
            compliant = ($_.Group | Where-Object ComplianceState -eq 'Compliant').Count
            nonCompliant = ($_.Group | Where-Object ComplianceState -eq 'NonCompliant').Count
        }
    }
    details = $complianceData | Select-Object ResourceId, PolicyDefinitionName, ComplianceState, Timestamp
    metadata = @{
        generatedBy = "Regenerate-ComplianceReport.ps1"
        command = ".\Regenerate-ComplianceReport.ps1 -WorkflowRunId $WorkflowRunId$(if ($ResourceGroupName) { " -ResourceGroupName $ResourceGroupName" })"
        workflowRunId = $WorkflowRunId
        generatedTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        note = "Azure Policy evaluates each vault AND each resource (secrets, keys, certificates) separately"
    }
}
$complianceReport | ConvertTo-Json -Depth 10 | Out-File $complianceJson -Encoding UTF8
Write-Host "  ✓ JSON: $complianceJson" -ForegroundColor Green

# Generate HTML
$htmlContent = @"
<!DOCTYPE html>
<html><head><title>Compliance Report - $WorkflowRunId (Regenerated)</title><style>
body { font-family: 'Segoe UI', sans-serif; margin: 20px; background: #f5f5f5; }
.container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
h1, h2 { color: #667eea; border-bottom: 3px solid #667eea; padding-bottom: 10px; }
.summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
.card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
.card .value { font-size: 2.5em; font-weight: bold; color: #667eea; }
.card .label { color: #666; margin-top: 5px; }
.badge-success { background: #28a745; color: white; padding: 4px 12px; border-radius: 4px; font-size: 0.9em; font-weight: bold; }
.badge-danger { background: #dc3545; color: white; padding: 4px 12px; border-radius: 4px; font-size: 0.9em; font-weight: bold; }
.regenerated-banner { background: #17a2b8; color: white; padding: 15px; border-radius: 4px; margin-bottom: 20px; text-align: center; }
table { width: 100%; border-collapse: collapse; margin: 20px 0; }
th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
th { background-color: #667eea; color: white; font-weight: 600; }
tr:hover { background-color: #f5f5f5; }
.guid-text { color: #999; font-size: 0.85em; font-family: 'Consolas', monospace; }
</style></head><body>
<div class="container">
<div class="regenerated-banner">
    ✨ This report was regenerated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') with updated Azure Policy compliance data
</div>
<h1>🔍 Azure Policy Compliance Report</h1>
<p><strong>Workflow Run ID:</strong> $WorkflowRunId</p>
<p><strong>Subscription:</strong> $SubscriptionId</p>
<p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>

<div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
    <h3 style="margin-top: 0; color: #856404;">📊 Understanding Compliance Counts</h3>
    <p style="margin-bottom: 0; color: #856404;">
        Azure Policy evaluates <strong>each vault AND each resource</strong> (secrets, keys, certificates) separately.
        For example, 5 vaults with 3 resources each = 15 total evaluations per policy. This granular approach
        ensures comprehensive compliance checking across all Key Vault objects.
    </p>
</div>

<div class="summary">
    <div class="card">
        <div class="value">$($complianceReport.totalEvaluations)</div>
        <div class="label">Total Evaluations</div>
    </div>
    <div class="card">
        <div class="value" style="color: #28a745;">$($complianceReport.compliant)</div>
        <div class="label">Compliant</div>
    </div>
    <div class="card">
        <div class="value" style="color: #dc3545;">$($complianceReport.nonCompliant)</div>
        <div class="label">Non-Compliant</div>
    </div>
    <div class="card">
        <div class="value">$([math]::Round(($complianceReport.compliant / $complianceReport.totalEvaluations) * 100, 1))%</div>
        <div class="label">Compliance Rate</div>
    </div>
</div>

<h2>Policy-Level Breakdown</h2>
<table>
<tr>
    <th>Policy Name</th>
    <th>Compliant</th>
    <th>Non-Compliant</th>
    <th>Total</th>
</tr>
"@

foreach ($policy in $complianceReport.policies) {
    $htmlContent += @"
<tr>
    <td><strong>$($policy.friendlyName)</strong><br><span class="guid-text">$($policy.policyGuid)</span></td>
    <td><span class="badge-success">$($policy.compliant)</span></td>
    <td><span class="badge-danger">$($policy.nonCompliant)</span></td>
    <td>$($policy.compliant + $policy.nonCompliant)</td>
</tr>
"@
}

$htmlContent += @"
</table>

<h2>Resource-Level Details</h2>
<table>
<tr>
    <th>Vault Name</th>
    <th>Policy</th>
    <th>State</th>
</tr>
"@

foreach ($detail in $complianceReport.details) {
    $vaultName = ($detail.ResourceId -split '/')[-1]
    $policyGuid = ($detail.PolicyDefinitionName -split '/')[-1]
    $friendlyName = if ($policyNameMap.ContainsKey($policyGuid)) { $policyNameMap[$policyGuid] } else { $policyGuid }
    $badge = if ($detail.ComplianceState -eq 'Compliant') { 'badge-success' } else { 'badge-danger' }
    
    $htmlContent += @"
<tr>
    <td>$vaultName</td>
    <td><strong>$friendlyName</strong><br><span class="guid-text">$policyGuid</span></td>
    <td><span class="$badge">$($detail.ComplianceState)</span></td>
</tr>
"@
}

$htmlContent += @"
</table>

<div style="margin-top: 40px; padding-top: 20px; border-top: 2px solid #e0e0e0; color: #666; font-size: 0.9em;">
    <p><strong>Generated by:</strong> Regenerate-ComplianceReport.ps1</p>
    <p><strong>Command:</strong> .\Regenerate-ComplianceReport.ps1 -WorkflowRunId $WorkflowRunId$(if ($ResourceGroupName) { " -ResourceGroupName $ResourceGroupName" })</p>
    <p><strong>Timestamp:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <p><strong>Subscription:</strong> $SubscriptionId</p>
</div>

</div>
</body></html>
"@

$htmlContent | Out-File $complianceHtml -Encoding UTF8
Write-Host "  ✓ HTML: $complianceHtml" -ForegroundColor Green

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " ✅ COMPLIANCE REPORT REGENERATED" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Green

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total Evaluations: $($complianceReport.totalEvaluations)" -ForegroundColor White
Write-Host "  Compliant: $($complianceReport.compliant)" -ForegroundColor Green
Write-Host "  Non-Compliant: $($complianceReport.nonCompliant)" -ForegroundColor Red
Write-Host "  Compliance Rate: $([math]::Round(($complianceReport.compliant / $complianceReport.totalEvaluations) * 100, 1))%`n" -ForegroundColor White

Write-Host "Opening HTML report in browser..." -ForegroundColor Gray
Start-Process $complianceHtml
