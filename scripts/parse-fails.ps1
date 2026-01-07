<#
.SYNOPSIS
    Parses HTML test reports to extract failed tests.

.DESCRIPTION
    This utility script extracts failed test information from HTML policy test reports
    and saves them to a text file for easier review and analysis.
    
.NOTES
    Author: Azure Policy Testing Framework
    Version: 1.0.0
    Date: 2026-01-06
    Purpose: Report parsing and failure extraction
#>

$html = Get-Content 'C:\Temp\AzurePolicy-KeyVault-TestReport-20260105-140754.html' -Raw
$rows = $html -split '<tr>'
$result = @()
foreach ($r in $rows) {
    if ($r -match 'badge fail') {
        if ($r -match '<td><strong>(.*?)</strong></td>') { $n = $matches[1].Trim() } else { $n = '(unknown)' }
        if ($r -match "<td>.*?<span class='badge (audit|deny|compliance|pass|fail)'.*?>(.*?)</span>.*?</td>") { $m = $matches[2].Trim() } else { $m = '(unknown)' }
        $result += "$m`t$n"
    }
}
$result | Out-File -FilePath "$PSScriptRoot\..\artifacts\txt\failed-tests.txt" -Encoding utf8
Write-Host 'done'