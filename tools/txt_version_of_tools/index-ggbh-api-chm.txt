[CmdletBinding()]
param(
    [string]$ChmPath,
    [string]$OutputDir,
    [string[]]$Terms = @(
        "UnitCtrlPlayer",
        "BattleDataMgr",
        "UnitActionRoleBattle",
        "DataUnit.UnitInfoData.AddMartialExpInBattle",
        "DataUnit.UnitInfoData.AddMartialExp",
        "GetMartialAddExpRate",
        "AddSkillMartialExp",
        "SkillAddExp",
        "martialUseAddExp",
        "allMartialOldExp",
        "allUpLevelMartial",
        "SkillAttack",
        "SkillDataAttack",
        "SkillCreateData",
        "MissileShotData",
        "UnitHitDynIntHandler",
        "UnitEffectSkillHpSuck",
        "OneUnitHitSkill",
        "OneUnitUseSkillAttack",
        "CreateSkillAttack"
    ),
    [int]$MaxMatchesPerTerm = 30,
    [switch]$ForceDecompile,
    [switch]$SkipDecompile
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "generated\GGBH_API_chm"
}

function Add-ExistingFile {
    param(
        [System.Collections.Generic.List[string]]$Files,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $resolved = (Resolve-Path -LiteralPath $Path).Path
        if (-not $Files.Contains($resolved)) {
            [void]$Files.Add($resolved)
        }
    }
}

function Find-GgbhApiChm {
    $candidates = [System.Collections.Generic.List[string]]::new()
    Add-ExistingFile $candidates ([Environment]::GetEnvironmentVariable("GGBH_API_CHM"))

    foreach ($commonRoot in @("D:\Games\Steam\steamapps\common", "C:\Program Files (x86)\Steam\steamapps\common")) {
        if (-not (Test-Path -LiteralPath $commonRoot -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $commonRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $modFaqRoot = Join-Path $_.FullName "Mod\modFQA"
                if (-not (Test-Path -LiteralPath $modFaqRoot -PathType Container)) { return }
                $found = Get-ChildItem -LiteralPath $modFaqRoot -Recurse -Filter "GGBH_API.chm" -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1 -ExpandProperty FullName
                Add-ExistingFile $candidates $found
            }
    }

    if ($candidates.Count -gt 0) { return $candidates[0] }
    return $null
}

function HtmlDecode {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlDecode($Value)
}

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value.ToString() -replace '\|', '\|' -replace "`r?`n", " ")
}

function New-TermStates {
    param([string[]]$TermNames)
    $states = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($term in $TermNames) {
        if ([string]::IsNullOrWhiteSpace($term)) { continue }
        if ($states.Contains($term)) { continue }
        $states[$term] = [pscustomobject]@{
            term = $term
            count = 0
            matches = [System.Collections.Generic.List[object]]::new()
            seen = [System.Collections.Generic.HashSet[string]]::new()
        }
    }
    return $states
}

function Add-TermMatch {
    param(
        [System.Collections.Specialized.OrderedDictionary]$States,
        [string]$Name,
        [string]$Local,
        [string]$SourceName,
        [int]$MaxMatches
    )
    if ([string]::IsNullOrWhiteSpace($Name)) { return }

    foreach ($term in $States.Keys) {
        if ($Name -notlike "*$term*") { continue }
        $state = $States[$term]
        $dedupeKey = "$Name|$Local|$SourceName"
        if (-not $state.seen.Add($dedupeKey)) { continue }
        $state.count++
        if ($state.matches.Count -lt $MaxMatches) {
            [void]$state.matches.Add([pscustomobject]@{
                name = $Name
                local = $Local
                path = if ([string]::IsNullOrWhiteSpace($Local)) { "" } else { Join-Path $OutputDir ($Local -replace '/', '\') }
                source = $SourceName
            })
        }
    }
}

function Scan-SitemapForTerms {
    param(
        [string]$Path,
        [string]$SourceName,
        [System.Collections.Specialized.OrderedDictionary]$States,
        [int]$MaxMatches
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }

    $currentName = ""
    $currentLocal = ""
    $paramPattern = '<param\s+name="([^"]*)"\s+value="([^"]*)"'
    foreach ($line in [System.IO.File]::ReadLines($Path, [System.Text.Encoding]::Default)) {
        $paramMatches = [System.Text.RegularExpressions.Regex]::Matches($line, $paramPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($paramMatch in $paramMatches) {
            $paramName = $paramMatch.Groups[1].Value
            $paramValue = HtmlDecode $paramMatch.Groups[2].Value
            if ($paramName -eq "Name") {
                $currentName = $paramValue
            } elseif ($paramName -eq "Local") {
                $currentLocal = $paramValue
            }
        }

        if ($line -match '</OBJECT>') {
            Add-TermMatch $States $currentName $currentLocal $SourceName $MaxMatches
            $currentName = ""
            $currentLocal = ""
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ChmPath)) {
    $ChmPath = Find-GgbhApiChm
}
if ([string]::IsNullOrWhiteSpace($ChmPath) -or -not (Test-Path -LiteralPath $ChmPath -PathType Leaf)) {
    throw "GGBH_API.chm was not found. Pass -ChmPath or set GGBH_API_CHM."
}
$ChmPath = (Resolve-Path -LiteralPath $ChmPath).Path

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$hhExe = Join-Path $env:WINDIR "hh.exe"
if (-not (Test-Path -LiteralPath $hhExe -PathType Leaf)) {
    throw "hh.exe was not found under WINDIR. Cannot decompile CHM."
}

$hhcPath = Join-Path $OutputDir "GGBH_API.hhc"
$hhkPath = Join-Path $OutputDir "GGBH_API.hhk"
$needsDecompile = (-not $SkipDecompile) -and ($ForceDecompile -or -not (Test-Path -LiteralPath $hhcPath -PathType Leaf) -or -not (Test-Path -LiteralPath $hhkPath -PathType Leaf))
if ($needsDecompile) {
    Write-Host "Decompiling CHM -> $OutputDir" -ForegroundColor Cyan
    & $hhExe -decompile $OutputDir $ChmPath | Out-Null
}

if (-not (Test-Path -LiteralPath $hhcPath -PathType Leaf) -or -not (Test-Path -LiteralPath $hhkPath -PathType Leaf)) {
    throw "CHM decompile did not produce GGBH_API.hhc and GGBH_API.hhk under $OutputDir."
}

Write-Host "Scanning CHM sitemap indexes..." -ForegroundColor Cyan
$termStates = New-TermStates $Terms
Scan-SitemapForTerms $hhcPath "hhc" $termStates $MaxMatchesPerTerm
Scan-SitemapForTerms $hhkPath "hhk" $termStates $MaxMatchesPerTerm

$termReports = [System.Collections.Generic.List[object]]::new()
foreach ($term in $termStates.Keys) {
    $state = $termStates[$term]
    [void]$termReports.Add([pscustomobject]@{
        term = $state.term
        count = $state.count
        matches = $state.matches.ToArray()
    })
}

$fileCount = (Get-ChildItem -LiteralPath $OutputDir -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
$generatedRoot = Split-Path -Parent $OutputDir
$markdownPath = Join-Path $generatedRoot "GGBH_API_CHM_INDEX.md"
$jsonPath = Join-Path $generatedRoot "ggbh-api-chm-index.json"

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# GGBH API CHM Index")
$lines.Add("")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("")
$lines.Add('CHM: `' + $ChmPath + '`')
$lines.Add("")
$lines.Add('Decompiled output: `' + $OutputDir + '`')
$lines.Add("")
$lines.Add("Files: $fileCount")
$lines.Add("")
$lines.Add("## Use")
$lines.Add("")
$lines.Add('```powershell')
$lines.Add('powershell -ExecutionPolicy Bypass -File .\tools\index-ggbh-api-chm.ps1')
$lines.Add('powershell -ExecutionPolicy Bypass -File .\tools\index-ggbh-api-chm.ps1 -Terms AddSkillMartialExp,UnitHitDynIntHandler')
$lines.Add('rg -n "AddSkillMartialExp" .\generated\GGBH_API_chm\GGBH_API.hhk .\generated\GGBH_API_chm\GGBH_API.hhc')
$lines.Add('rg -n "SkillCreateData" .\generated\GGBH_API_chm\html')
$lines.Add('```')
$lines.Add("")
$lines.Add("## Limits")
$lines.Add("")
$lines.Add("The CHM is useful for finding official documented type/member names and signatures. It does not prove event order, mutation order, or battle-time side effects; those still need ApiProbe compile checks and runtime DWT traces.")
$lines.Add("")
$lines.Add("## Term Summary")
$lines.Add("")
$lines.Add("| Term | Matches |")
$lines.Add("| --- | --- |")
foreach ($report in $termReports) {
    $lines.Add("| $(Escape-MarkdownCell $report.term) | $($report.count) |")
}

foreach ($report in $termReports) {
    $lines.Add("")
    $lines.Add('## `' + $report.term + '`')
    $lines.Add("")
    if ($report.matches.Count -eq 0) {
        $lines.Add("_No matches._")
        continue
    }
    $lines.Add("| Name | Local | Source |")
    $lines.Add("| --- | --- | --- |")
    foreach ($match in $report.matches) {
        $lines.Add("| $(Escape-MarkdownCell $match.name) | $(Escape-MarkdownCell $match.local) | $(Escape-MarkdownCell $match.source) |")
    }
}

Set-Content -LiteralPath $markdownPath -Value $lines -Encoding UTF8
[pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    chmPath = $ChmPath
    outputDir = $OutputDir
    fileCount = $fileCount
    entryCount = $null
    terms = $termReports
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host "GGBH API CHM index generated:" -ForegroundColor Green
Write-Host "  $markdownPath"
Write-Host "  $jsonPath"
