<#
.SYNOPSIS
    Maps Azure Policy IDs to their display names and details.

.DESCRIPTION
    This script resolves Azure Policy IDs to human-readable names and properties.
    It queries Azure Policy definitions and creates a mapping file for reference.
    
.PARAMETER SubscriptionId
    Azure subscription ID to query for policy definitions.
    
.PARAMETER PolicyIds
    Array of policy IDs to resolve.
    
.PARAMETER PolicyIdsFile
    Path to file containing policy IDs (one per line).
    
.PARAMETER OutFile
    Output path for the JSON mapping file (default: reports/policyIdMap.json).
    
.EXAMPLE
    .\map-policy-ids.ps1 -SubscriptionId "sub-id" -PolicyIds @("policy-id-1", "policy-id-2")
    
.NOTES
    Author: Azure Policy Testing Framework
    Version: 1.0.0
    Date: 2026-01-06
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [string[]]$PolicyIds,

    [Parameter(Mandatory=$false)]
    [string]$PolicyIdsFile = '',

    [Parameter(Mandatory=$false)]
    [string]$OutFile = "$PSScriptRoot\..\artifacts\json\policyIdMap.json"
)

if (-not (Get-Command Get-AzPolicyDefinition -ErrorAction SilentlyContinue)) {
    Write-Error "Az.Policy cmdlets not available. Ensure Az module is loaded and authenticated."
    exit 2
}

if ($PolicyIdsFile -and (Test-Path $PolicyIdsFile)) {
    $PolicyIds = Get-Content -Path $PolicyIdsFile | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
}

if (-not $PolicyIds -or $PolicyIds.Count -eq 0) {
    Write-Error "No policy IDs provided. Use -PolicyIds or -PolicyIdsFile."
    exit 2
}

function Resolve-PolicyId {
    param(
        [string]$id,
        [string]$sub
    )

    $result = [PSCustomObject]@{
        Original      = $id
        ResolvedId    = $null
        ResourceType  = $null
        Found         = $false
        Notes         = $null
    }

    # normalize
    $raw = $id.Trim()

    # If already looks like a full resource id, try to fetch directly
    if ($raw -match '^/providers/|^/subscriptions/') {
        try {
            $d = Get-AzPolicyDefinition -Id $raw -ErrorAction SilentlyContinue
            if ($d) { $result.ResolvedId = $d.Id; $result.ResourceType = 'PolicyDefinition'; $result.Found = $true; return $result }
            $s = Get-AzPolicySetDefinition -Id $raw -ErrorAction SilentlyContinue
            if ($s) { $result.ResolvedId = $s.Id; $result.ResourceType = 'PolicySetDefinition'; $result.Found = $true; return $result }
        }
        catch { $result.Notes = "Direct lookup failed: $_" }
    }

    # If looks like a GUID (common case), try provider & subscription scopes
    if ($raw -match '^[0-9a-fA-F-]{36}$') {
        $candidates = @(
            "/providers/Microsoft.Authorization/policyDefinitions/$raw",
            "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/policyDefinitions/$raw",
            "/providers/Microsoft.Authorization/policySetDefinitions/$raw",
            "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/policySetDefinitions/$raw"
        )

        foreach ($cand in $candidates) {
            try {
                $d = Get-AzPolicyDefinition -Id $cand -ErrorAction SilentlyContinue
                if ($d) { $result.ResolvedId = $d.Id; $result.ResourceType = 'PolicyDefinition'; $result.Found = $true; return $result }
                $s = Get-AzPolicySetDefinition -Id $cand -ErrorAction SilentlyContinue
                if ($s) { $result.ResolvedId = $s.Id; $result.ResourceType = 'PolicySetDefinition'; $result.Found = $true; return $result }
            }
            catch {
                # ignore and continue
            }
        }

        # As a last resort, try listing built-in definitions and match by GUID in Id
        try {
            $builtins = Get-AzPolicyDefinition -PolicyType BuiltIn -ErrorAction SilentlyContinue
            if ($builtins) {
                $match = $builtins | Where-Object { $_.Id -match $raw } | Select-Object -First 1
                if ($match) { $result.ResolvedId = $match.Id; $result.ResourceType = 'PolicyDefinition(BuiltIn)'; $result.Found = $true; return $result }
            }
        }
        catch {
            # ignore
        }
    }

    # If still not found, attempt a broad search (may be slow) in subscription definitions
    try {
        $subsDefs = Get-AzPolicyDefinition -ErrorAction SilentlyContinue | Where-Object { $_.Id -match [regex]::Escape($raw) } | Select-Object -First 1
        if ($subsDefs) { $result.ResolvedId = $subsDefs.Id; $result.ResourceType = 'PolicyDefinition(Subscription)'; $result.Found = $true; return $result }
    }
    catch {
        # ignore
    }

    $result.Notes = 'Not resolved by heuristics'
    return $result
}

$map = @()
foreach ($policyId in $PolicyIds) {
    Write-Host "Resolving: $policyId"
    $r = Resolve-PolicyId -id $policyId -sub $SubscriptionId
    $map += $r
}

# Ensure output folder exists
$dir = Split-Path -Path $OutFile -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$map | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutFile -Encoding utf8

$found = ($map | Where-Object { $_.Found -eq $true }).Count
$notfound = ($map | Where-Object { $_.Found -eq $false }).Count

Write-Host "Mapping complete. Found: $found. Not found: $notfound. Output: $OutFile"

return $OutFile
