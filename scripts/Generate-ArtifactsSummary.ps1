<#
.SYNOPSIS
  Generate a consolidated CSV and HTML summary of artifacts and save them
  to artifacts/csv and artifacts/html. If run interactively, open HTML files
  in the user's default browser.
#>

param()

try {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $repoRoot = (Resolve-Path (Join-Path $scriptRoot '..')).Path
} catch {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $repoRoot = Join-Path $scriptRoot '..'
}

$artifactsRoot = Join-Path $repoRoot 'artifacts'
$jsonDir = Join-Path $artifactsRoot 'json'
$htmlDir = Join-Path $artifactsRoot 'html'
$csvDir = Join-Path $artifactsRoot 'csv'

foreach ($d in @($artifactsRoot, $jsonDir, $htmlDir, $csvDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

# Gather files of interest
$extensions = '.json','.html','.csv','.txt'
$files = Get-ChildItem -Path $artifactsRoot -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $extensions -contains $_.Extension.ToLower() }

if (-not $files) {
    Write-Host "No artifacts found under $artifactsRoot"
    exit 0
}

# Group by second-granularity timestamp to mirror workflow grouping
$groups = $files | Group-Object @{Name='GroupKey';Expression={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}} | Sort-Object Name

$summary = foreach ($g in $groups) {
    $types = $g.Group.Extension | ForEach-Object { $_.TrimStart('.') } | Sort-Object -Unique
    [PSCustomObject]@{
        Timestamp = $g.Name
        Types     = ($types -join ',')
        Files     = ($g.Group | ForEach-Object { $_.FullName } ) -join ';'
    }
}

$nowTs = (Get-Date).ToString('yyyyMMdd-HHmmss')
$csvOut = Join-Path $csvDir "Workflow-Artifacts-Summary-$nowTs.csv"
$htmlOut = Join-Path $htmlDir "Workflow-Artifacts-Summary-$nowTs.html"

$summary | Export-Csv -Path $csvOut -NoTypeInformation -Encoding UTF8

# Build a simple HTML summary with links
$html = @()
$html += '<!doctype html>'
$html += '<html><head><meta charset="utf-8"><title>Artifacts Summary</title></head><body>'
$html += "<h1>Artifacts Summary - $nowTs</h1>"
$html += '<table border="1" cellpadding="6" cellspacing="0">'
$html += '<tr><th>Timestamp</th><th>Types</th><th>Files</th></tr>'

foreach ($row in $summary) {
    $fileLinks = $row.Files -split ';' | ForEach-Object {
        $rel = Resolve-Path -Path $_ -ErrorAction SilentlyContinue
        if ($rel) {
            $f = $rel.Path
            $enc = [System.Uri]::EscapeDataString($f)
            "<a href='file:///$f'>$([System.IO.Path]::GetFileName($f))</a>"
        } else { [System.IO.Path]::GetFileName($_) }
    } | Sort-Object

    $html += "<tr><td>$($row.Timestamp)</td><td>$($row.Types)</td><td>$(( $fileLinks -join '<br/>'))</td></tr>"
}

$html += '</table>'
$html += '</body></html>'

[System.IO.File]::WriteAllLines($htmlOut,$html)

Write-Host "Wrote CSV summary: $csvOut"
Write-Host "Wrote HTML summary: $htmlOut"

# If run interactively, open all HTML reports in artifacts/html
function Test-Interactive {
    try {
        return -not [Console]::IsInputRedirected
    } catch {
        return $false
    }
}

if (Test-Interactive) {
    $htmlFiles = Get-ChildItem -Path $htmlDir -Filter *.html -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    foreach ($f in $htmlFiles) {
        try {
            Start-Process -FilePath $f.FullName -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Unable to open $($f.FullName): $_"
        }
    }
}

return @{ Csv = $csvOut; Html = $htmlOut }
param(
    [string]$ManifestPath
)

Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsJsonDir = Join-Path $repoRoot '..\artifacts\json' | Resolve-Path -ErrorAction SilentlyContinue | ForEach-Object { $_.ProviderPath }
if (-not $artifactsJsonDir) { $artifactsJsonDir = Join-Path $repoRoot '..\artifacts\json' }
$artifactsHtmlDir = Join-Path $repoRoot '..\artifacts\html'
$artifactsCsvDir = Join-Path $repoRoot '..\artifacts\csv'

New-Item -ItemType Directory -Path $artifactsHtmlDir -Force | Out-Null
New-Item -ItemType Directory -Path $artifactsCsvDir -Force | Out-Null

if (-not $ManifestPath) {
    $manifest = Get-ChildItem -Path $artifactsJsonDir -Filter 'artifacts-manifest-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($manifest) {
        $ManifestPath = $manifest.FullName
        $manifestJson = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    }
}

# If we have a manifest, build rows from it; otherwise scan artifact folders and synthesize summary
$rows = @()
if ($ManifestPath -and (Test-Path $ManifestPath) -and $manifestJson) {
    if ($manifestJson.WorkflowRunId) { $runId = $manifestJson.WorkflowRunId } else {
        $m = [System.IO.Path]::GetFileName($ManifestPath) -match 'artifacts-manifest-(.+)\.json'
        $runId = if ($m) { $matches[1] } else { ([System.IO.Path]::GetFileNameWithoutExtension($ManifestPath)) }
    }

    foreach ($entry in $manifestJson.Artifacts) {
        $jsonRel = if ($entry.json) { $entry.json } else { $null }
        $htmlRel = if ($entry.html) { $entry.html } else { $null }
        $csvRel = if ($entry.csv) { $entry.csv } else { $null }

        $jsonPath = if ($jsonRel) { Join-Path (Join-Path $repoRoot '..\artifacts\json') $jsonRel } else { $null }
        $htmlPath = if ($htmlRel) { Join-Path (Join-Path $repoRoot '..\artifacts\html') $htmlRel } else { $null }
        $csvPath = if ($csvRel) { Join-Path (Join-Path $repoRoot '..\artifacts\csv') $csvRel } else { $null }

        $jsonExists = $false; $jsonSize = '' ; $jsonMod = ''
        if ($jsonPath -and (Test-Path $jsonPath)) { $fi = Get-Item $jsonPath; $jsonExists = $true; $jsonSize = [math]::Round($fi.Length / 1KB,2); $jsonMod = $fi.LastWriteTime }
        $htmlExists = $false; $htmlSize=''; $htmlMod=''
        if ($htmlPath -and (Test-Path $htmlPath)) { $fi = Get-Item $htmlPath; $htmlExists = $true; $htmlSize = [math]::Round($fi.Length / 1KB,2); $htmlMod = $fi.LastWriteTime }
        $csvExists = $false; $csvSize=''; $csvMod=''
        if ($csvPath -and (Test-Path $csvPath)) { $fi = Get-Item $csvPath; $csvExists = $true; $csvSize = [math]::Round($fi.Length / 1KB,2); $csvMod = $fi.LastWriteTime }

        $rows += [PSCustomObject]@{
            Step = $entry.step
            Name = $entry.name
            JSON = if ($jsonRel) { $jsonRel } else { '' }
            JSON_Exists = $jsonExists
            JSON_KB = $jsonSize
            JSON_Modified = $jsonMod
            HTML = if ($htmlRel) { $htmlRel } else { '' }
            HTML_Exists = $htmlExists
            HTML_KB = $htmlSize
            HTML_Modified = $htmlMod
            CSV = if ($csvRel) { $csvRel } else { '' }
            CSV_Exists = $csvExists
            CSV_KB = $csvSize
            CSV_Modified = $csvMod
        }
    }
} else {
    # No manifest; synthesize summary by scanning artifact folders and matching by base filename
    $runId = (Get-Date -Format 'yyyyMMdd-HHmmss')

    $jsonFiles = Get-ChildItem -Path (Join-Path $repoRoot '..\artifacts\json') -File -ErrorAction SilentlyContinue
    $htmlFiles = Get-ChildItem -Path (Join-Path $repoRoot '..\artifacts\html') -File -ErrorAction SilentlyContinue
    $csvFiles = Get-ChildItem -Path (Join-Path $repoRoot '..\artifacts\csv') -File -ErrorAction SilentlyContinue

    $allNames = @{}
    foreach ($f in $jsonFiles) { $allNames[$f.BaseName] = $true }
    foreach ($f in $htmlFiles) { $allNames[$f.BaseName] = $true }
    foreach ($f in $csvFiles) { $allNames[$f.BaseName] = $true }

    foreach ($base in $allNames.Keys | Sort-Object) {
        $json = (Get-ChildItem -Path (Join-Path $repoRoot '..\artifacts\json') -Filter "$base.*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.json' }) | Select-Object -First 1
        $html = (Get-ChildItem -Path (Join-Path $repoRoot '..\artifacts\html') -Filter "$base.*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.html' }) | Select-Object -First 1
        $csv = (Get-ChildItem -Path (Join-Path $repoRoot '..\artifacts\csv') -Filter "$base.*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.csv' }) | Select-Object -First 1

        $rows += [PSCustomObject]@{
            Step = ''
            Name = $base
            JSON = if ($json) { $json.Name } else { '' }
            JSON_Exists = [bool]$json
            JSON_KB = if ($json) { [math]::Round($json.Length/1KB,2) } else { '' }
            JSON_Modified = if ($json) { $json.LastWriteTime } else { '' }
            HTML = if ($html) { $html.Name } else { '' }
            HTML_Exists = [bool]$html
            HTML_KB = if ($html) { [math]::Round($html.Length/1KB,2) } else { '' }
            HTML_Modified = if ($html) { $html.LastWriteTime } else { '' }
            CSV = if ($csv) { $csv.Name } else { '' }
            CSV_Exists = [bool]$csv
            CSV_KB = if ($csv) { [math]::Round($csv.Length/1KB,2) } else { '' }
            CSV_Modified = if ($csv) { $csv.LastWriteTime } else { '' }
        }
    }
}

# Export CSV
$outCsv = Join-Path $artifactsCsvDir "artifacts-summary-$runId.csv"
$outHtml = Join-Path $artifactsHtmlDir "artifacts-summary-$runId.html"

# Add CSV header comments with metadata
$csvHeader = @"
# Artifacts Summary Report
# Generated by: Generate-ArtifactsSummary.ps1
# Command: .\Generate-ArtifactsSummary.ps1
# Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Workflow Run ID: $runId
#
"@

$csvHeader | Out-File -FilePath $outCsv -Encoding UTF8
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8 -Append

# Build HTML table
$htmlBuilder = @()
$htmlBuilder += '<!doctype html>'
$htmlBuilder += '<html><head><meta charset="utf-8"><title>Artifacts Summary - ' + $runId + '</title>'
$htmlBuilder += '<style>table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:6px;text-align:left}th{background:#f4f4f4}</style>'
$htmlBuilder += '</head><body>'
$htmlBuilder += '<h1>Artifacts Summary - ' + $runId + '</h1>'
$htmlBuilder += '<p>Generated: ' + (Get-Date).ToString() + '</p>'
$htmlBuilder += '<table><thead><tr><th>Step</th><th>Name</th><th>JSON</th><th>HTML</th><th>CSV</th><th>Notes</th></tr></thead><tbody>'

foreach ($r in $rows) {
    $notes = @()
    $jsonLink = ''
    if ($r.JSON) {
        if ($r.JSON_Exists) { $jsonLink = "<a href='../json/" + [System.Web.HttpUtility]::HtmlEncode($r.JSON) + "'>" + [System.Web.HttpUtility]::HtmlEncode($r.JSON) + "</a>" } else { $jsonLink = [System.Web.HttpUtility]::HtmlEncode($r.JSON); $notes += 'JSON missing' }
    }
    $htmlLink = ''
    if ($r.HTML) {
        if ($r.HTML_Exists) { $htmlLink = "<a href='" + [System.Web.HttpUtility]::HtmlEncode($r.HTML) + "'>" + [System.Web.HttpUtility]::HtmlEncode($r.HTML) + "</a>" } else { $htmlLink = [System.Web.HttpUtility]::HtmlEncode($r.HTML); $notes += 'HTML missing' }
    }
    $csvLink = ''
    if ($r.CSV) {
        if ($r.CSV_Exists) { $csvLink = "<a href='../csv/" + [System.Web.HttpUtility]::HtmlEncode($r.CSV) + "'>" + [System.Web.HttpUtility]::HtmlEncode($r.CSV) + "</a>" } else { $csvLink = [System.Web.HttpUtility]::HtmlEncode($r.CSV); $notes += 'CSV missing' }
    }

    $notesText = if ($notes.Count -gt 0) { [System.Web.HttpUtility]::HtmlEncode(($notes -join '; ')) } else { '' }

    $htmlBuilder += "<tr><td>" + [System.Web.HttpUtility]::HtmlEncode($r.Step) + "</td><td>" + [System.Web.HttpUtility]::HtmlEncode($r.Name) + "</td><td>" + $jsonLink + "</td><td>" + $htmlLink + "</td><td>" + $csvLink + "</td><td>" + $notesText + "</td></tr>"
}

$htmlBuilder += '</tbody></table>'
$htmlBuilder += "<p>CSV: <a href='../csv/" + [System.IO.Path]::GetFileName($outCsv) + "'>" + [System.IO.Path]::GetFileName($outCsv) + "</a></p>"

# Add metadata footer
$htmlBuilder += '<div style="margin-top: 40px; padding-top: 20px; border-top: 2px solid #e0e0e0; color: #666; font-size: 0.9em;">'
$htmlBuilder += '<p><strong>Generated by:</strong> Generate-ArtifactsSummary.ps1</p>'
$htmlBuilder += '<p><strong>Command:</strong> .\Generate-ArtifactsSummary.ps1</p>'
$htmlBuilder += '<p><strong>Timestamp:</strong> ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '</p>'
if ($ManifestPath) {
    $htmlBuilder += '<p><strong>Source Manifest:</strong> ' + [System.IO.Path]::GetFileName($ManifestPath) + '</p>'
}
$htmlBuilder += '<p><strong>Workflow Run ID:</strong> ' + $runId + '</p>'
$htmlBuilder += '</div>'

$htmlBuilder += '</body></html>'

$htmlBuilder -join "`n" | Out-File -FilePath $outHtml -Encoding UTF8

Write-Output "Wrote summary CSV: $outCsv"
Write-Output "Wrote summary HTML: $outHtml"

# mark todo done

