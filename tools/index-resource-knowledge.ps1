[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [string]$OutputDir,
    [int]$MaxTextPreviewChars = 240
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
if ($Path.Count -eq 0) {
    $Path = @(
        (Join-Path $RepoRoot "resource\modQ&A"),
        (Join-Path $RepoRoot "resource\Mod解包结果"),
        (Join-Path $RepoRoot "generated\GGBH_API_CHM_INDEX.md")
    )
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "generated\resource-knowledge-index"
}

$textExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ext in @(".md", ".txt", ".cs", ".json", ".xml", ".yaml", ".yml", ".htm", ".html", ".hhc", ".hhk", ".ps1", ".csv", ".tsv")) {
    [void]$textExtensions.Add($ext)
}
$skipExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ext in @(".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tga", ".psd", ".mp3", ".wav", ".ogg", ".mp4", ".avi", ".mov", ".ab", ".bundle")) {
    [void]$skipExtensions.Add($ext)
}

function Get-InputFiles {
    param([string[]]$Inputs)
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($inputPath in $Inputs) {
        if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }
        if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
            [void]$files.Add((Resolve-Path -LiteralPath $inputPath).Path)
        } elseif (Test-Path -LiteralPath $inputPath -PathType Container) {
            Get-ChildItem -LiteralPath $inputPath -Recurse -File -ErrorAction SilentlyContinue |
                ForEach-Object { [void]$files.Add($_.FullName) }
        }
    }
    return $files.ToArray()
}

function Get-Category {
    param([string]$File)
    $normalized = $File.Replace('/', '\')
    if ($normalized -like "*\resource\modQ&A\*") { return "official-mod-q-and-a" }
    if ($normalized -like "*\resource\Mod解包结果\*") { return "decompiled-mod-text-or-dll" }
    if ($normalized -like "*\generated\GGBH_API_CHM_INDEX.md") { return "generated-chm-index" }
    return "other"
}

function Read-Preview {
    param(
        [string]$File,
        [int]$MaxChars
    )
    try {
        $text = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8)
    } catch {
        try { $text = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::Default) } catch { return "" }
    }
    $text = ($text -replace "`r?`n", " ") -replace "\s+", " "
    if ($text.Length -gt $MaxChars) { return $text.Substring(0, $MaxChars) }
    return $text
}

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value.ToString() -replace '\|', '\|' -replace "`r?`n", " ")
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$files = Get-InputFiles $Path
$entries = [System.Collections.Generic.List[object]]::new()

foreach ($file in $files) {
    $item = Get-Item -LiteralPath $file
    $ext = $item.Extension
    $isSkippedMedia = $skipExtensions.Contains($ext)
    $isTextLike = $textExtensions.Contains($ext) -or [string]::IsNullOrWhiteSpace($ext)
    $entry = [pscustomobject]@{
        path = $item.FullName
        relativePath = if ($item.FullName.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) { $item.FullName.Substring($RepoRoot.Length).TrimStart('\') } else { $item.FullName }
        category = Get-Category $item.FullName
        extension = $ext
        size = $item.Length
        isTextIndexed = (-not $isSkippedMedia) -and $isTextLike
        isSkippedMedia = $isSkippedMedia
        preview = if ((-not $isSkippedMedia) -and $isTextLike -and $item.Length -le 2MB) { Read-Preview $item.FullName $MaxTextPreviewChars } else { "" }
    }
    [void]$entries.Add($entry)
}

$jsonPath = Join-Path $OutputDir "resource-knowledge-index.json"
$mdPath = Join-Path $OutputDir "RESOURCE_KNOWLEDGE_INDEX.md"
$entries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Resource Knowledge Index")
$lines.Add("")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("")
$lines.Add("Inputs:")
foreach ($inputPath in $Path) { $lines.Add('- `' + $inputPath + '`') }
$lines.Add("")
$lines.Add("## Category Summary")
$lines.Add("")
$lines.Add("| Category | Files | Text Indexed | Bytes |")
$lines.Add("| --- | ---: | ---: | ---: |")
foreach ($group in ($entries | Group-Object category | Sort-Object Name)) {
    $textCount = @($group.Group | Where-Object { $_.isTextIndexed }).Count
    $bytes = ($group.Group | Measure-Object size -Sum).Sum
    $lines.Add("| $(Escape-MarkdownCell $group.Name) | $($group.Count) | $textCount | $bytes |")
}
$lines.Add("")
$lines.Add("## Text Entries")
$lines.Add("")
$lines.Add("| Category | Path | Size | Preview |")
$lines.Add("| --- | --- | ---: | --- |")
foreach ($entry in ($entries | Where-Object { $_.isTextIndexed } | Sort-Object category, relativePath | Select-Object -First 500)) {
    $lines.Add("| $(Escape-MarkdownCell $entry.category) | $(Escape-MarkdownCell $entry.relativePath) | $($entry.size) | $(Escape-MarkdownCell $entry.preview) |")
}
Set-Content -LiteralPath $mdPath -Value $lines -Encoding UTF8

Write-Host "Resource knowledge index generated:" -ForegroundColor Green
Write-Host "  $mdPath"
Write-Host "  $jsonPath"
