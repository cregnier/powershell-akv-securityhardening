<#
Converts JSON and CSV artifact files under ../artifacts into HTML files under ../artifacts/html
Usage: .\scripts\Convert-ArtifactsToHtml.ps1
#>
param(
    [string]$ArtifactsRoot = "$(Split-Path -Path $PSScriptRoot -Parent)\artifacts"
)

function Encode-Html([string]$s){
    if ($null -eq $s) { return "" }
    $s = $s -replace '&','&amp;'
    $s = $s -replace '<','&lt;'
    $s = $s -replace '>','&gt;'
    $s = $s -replace '"','&quot;'
    $s = $s -replace "'",'&#39;'
    return $s
}

function Render-JsonAsHtml($obj){
    if ($null -eq $obj) { return "<div>Empty</div>" }
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])){
        $rows = @($obj)
        if ($rows.Count -eq 0){ return "<div>Empty array</div>" }
        $first = $rows[0]
        if ($first -is [System.Management.Automation.PSCustomObject] -or $first -is [hashtable]){
            $cols = ($rows | Select-Object -First 1 | Get-Member -MemberType NoteProperty,Property | Select-Object -ExpandProperty Name)
            $html = "<table class=tbl><thead><tr>"
            foreach ($c in $cols){ $html += "<th>$(Encode-Html $c)</th>" }
            $html += "</tr></thead><tbody>"
            foreach ($r in $rows){
                $html += "<tr>"
                foreach ($c in $cols){
                    $v = $r.$c
                    $cell = if ($null -eq $v) { '' } elseif ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])) { Encode-Html (ConvertTo-Json $v -Depth 3) } else { Encode-Html ($v.ToString()) }
                    $html += "<td>$cell</td>"
                }
                $html += "</tr>"
            }
            $html += "</tbody></table>"
            return $html
        }
    }
    return "<pre>$(Encode-Html (ConvertTo-Json $obj -Depth 5))</pre>"
}

function Render-CsvAsHtml($csv){
    if ($null -eq $csv) { return "<div>Empty CSV</div>" }
    $rows = @($csv)
    if ($rows.Count -eq 0){ return "<div>Empty CSV</div>" }
    $cols = $rows[0].PSObject.Properties | ForEach-Object { $_.Name }
    $html = "<table class=tbl><thead><tr>"
    foreach ($c in $cols){ $html += "<th>$(Encode-Html $c)</th>" }
    $html += "</tr></thead><tbody>"
    foreach ($r in $rows){
        $html += "<tr>"
        foreach ($c in $cols){ $html += "<td>$(Encode-Html ($r.$c))</td>" }
        $html += "</tr>"
    }
    $html += "</tbody></table>"
    return $html
}

$artifactsRoot = Resolve-Path -LiteralPath $ArtifactsRoot
$jsonDir = Join-Path $artifactsRoot 'json'
$csvDir = Join-Path $artifactsRoot 'csv'
$htmlDir = Join-Path $artifactsRoot 'html'

New-Item -ItemType Directory -Path $htmlDir -Force | Out-Null

$style = @'
<style>
body{font-family:Segoe UI,Arial;margin:20px}
.tbl{border-collapse:collapse;width:100%}
.tbl th,.tbl td{border:1px solid #ddd;padding:6px;text-align:left}
.tbl th{background:#f4f4f4}
section{margin-bottom:30px}
h2{margin-top:0}
</style>
'@

$nav = @()

# Process JSON files
if (Test-Path $jsonDir){
    Get-ChildItem -Path $jsonDir -Filter *.json -File | ForEach-Object {
        $src = $_.FullName
        $base = $_.BaseName
        $out = Join-Path $htmlDir ($base + '.html')
        try{
            $j = Get-Content -Raw -Path $src | ConvertFrom-Json -Depth 10
            $body = Render-JsonAsHtml $j
        } catch {
            $body = "<pre>Could not parse JSON: $(Encode-Html $_.Exception.Message)</pre>"
        }
        $html = "<html><head><meta charset=\"utf-8\"><title>$base</title>$style</head><body>"
        $html += "<h2>$(Encode-Html $base)</h2><section>$body</section>"
        $html += "</body></html>"
        Set-Content -Path $out -Value $html -Encoding UTF8
        $nav += $base
        Write-Host "Wrote $out"
    }
}

# Process CSV files
if (Test-Path $csvDir){
    Get-ChildItem -Path $csvDir -Filter *.csv -File | ForEach-Object {
        $src = $_.FullName
        $base = $_.BaseName
        $out = Join-Path $htmlDir ($base + '.html')
        try{
            $c = Import-Csv -Path $src
            $body = Render-CsvAsHtml $c
        } catch {
            $body = "<pre>Could not read CSV: $(Encode-Html $_.Exception.Message)</pre>"
        }
        $html = "<html><head><meta charset=\"utf-8\"><title>$base</title>$style</head><body>"
        $html += "<h2>$(Encode-Html $base)</h2><section>$body</section>"
        $html += "</body></html>"
        Set-Content -Path $out -Value $html -Encoding UTF8
        $nav += $base
        Write-Host "Wrote $out"
    }
}

# Create index
$indexOut = Join-Path $htmlDir 'index.html'
$links = $nav | Sort-Object | ForEach-Object { "<li><a href=\"$($_).html\">$(Encode-Html $_)</a></li>" } -join "`n"
$indexHtml = "<html><head><meta charset='utf-8'><title>Artifacts Index</title>$style</head><body><h1>Artifacts</h1><ul>$links</ul></body></html>"
Set-Content -Path $indexOut -Value $indexHtml -Encoding UTF8
Write-Host "Wrote $indexOut"
