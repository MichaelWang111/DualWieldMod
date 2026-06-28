[CmdletBinding()]
param(
    [string]$GameProjectRoot = "D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject",
    [switch]$Apply,
    [switch]$Build,
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
$SourceRoot = Join-Path $RepoRoot "src"

function Get-FullPathSafe {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-UnderPath {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )

    $baseFull = Get-FullPathSafe $BasePath
    $childFull = Get-FullPathSafe $ChildPath
    $baseWithSlash = $baseFull.TrimEnd('\') + '\'
    if (-not ($childFull.StartsWith($baseWithSlash, [System.StringComparison]::OrdinalIgnoreCase) -or $childFull.Equals($baseFull, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing to write outside target root. Base=$baseFull Child=$childFull"
    }
    return $childFull
}

function Get-RelativePathFromBase {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseFull = (Get-FullPathSafe $BasePath).TrimEnd('\') + '\'
    $full = Get-FullPathSafe $FullPath
    return $full.Substring($baseFull.Length)
}

function Test-SkippedFile {
    param([System.IO.FileInfo]$File)

    $skipNames = @(".gitkeep")
    $skipExtensions = @(".md", ".dll", ".pdb", ".cache", ".user")
    $skipDirs = @("bin", "obj", "refs", ".git")

    if ($skipNames -contains $File.Name) { return $true }
    if ($skipExtensions -contains $File.Extension.ToLowerInvariant()) { return $true }

    foreach ($part in $File.FullName.Split([System.IO.Path]::DirectorySeparatorChar)) {
        if ($skipDirs -contains $part) { return $true }
    }
    return $false
}

function Copy-Overlay {
    param(
        [string]$SourceSubdir,
        [string]$TargetSubdir
    )

    $sourceDir = Join-Path $SourceRoot $SourceSubdir
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        return @()
    }

    $targetDir = Assert-UnderPath $GameProjectRoot (Join-Path $GameProjectRoot $TargetSubdir)
    $changes = @()
    $files = Get-ChildItem -LiteralPath $sourceDir -Recurse -File | Where-Object { -not (Test-SkippedFile $_) }

    foreach ($file in $files) {
        $relative = Get-RelativePathFromBase $sourceDir $file.FullName
        $targetFile = Assert-UnderPath $targetDir (Join-Path $targetDir $relative)
        $action = "COPY"
        if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
            $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
            if ($sourceHash -eq $targetHash) {
                $action = "SKIP"
            }
        }

        if ($action -eq "COPY") {
            $changes += "$SourceSubdir\$relative -> $TargetSubdir\$relative"
            if ($Apply) {
                $parent = Split-Path -Parent $targetFile
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
                Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force
            }
        }
    }
    return $changes
}

function Ensure-ProjectCompileIncludes {
    $projectPath = Join-Path $GameProjectRoot "ModCode\ModMain\ModMain.csproj"
    $sourceModMain = Join-Path $SourceRoot "ModCode\ModMain"
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) { return @() }
    if (-not (Test-Path -LiteralPath $sourceModMain -PathType Container)) { return @() }

    [xml]$project = Get-Content -LiteralPath $projectPath
    $nsUri = $project.Project.NamespaceURI
    $ns = New-Object System.Xml.XmlNamespaceManager($project.NameTable)
    $ns.AddNamespace("msb", $nsUri)

    $compileNodes = $project.SelectNodes("//msb:Compile", $ns)
    $existing = @{}
    foreach ($node in $compileNodes) {
        $include = $node.GetAttribute("Include")
        if ($include) { $existing[$include.ToLowerInvariant()] = $true }
    }

    $missing = @()
    $sourceCsFiles = Get-ChildItem -LiteralPath $sourceModMain -Recurse -Filter "*.cs" -File | Where-Object { -not (Test-SkippedFile $_) }
    foreach ($file in $sourceCsFiles) {
        $relative = Get-RelativePathFromBase $sourceModMain $file.FullName
        if (-not $existing.ContainsKey($relative.ToLowerInvariant())) {
            $missing += $relative
        }
    }

    if ($missing.Count -eq 0) { return @() }

    if ($Apply) {
        $itemGroup = $project.SelectSingleNode("//msb:ItemGroup[msb:Compile]", $ns)
        if ($null -eq $itemGroup) {
            $itemGroup = $project.CreateElement("ItemGroup", $nsUri)
            [void]$project.Project.AppendChild($itemGroup)
        }
        foreach ($relative in $missing) {
            $compile = $project.CreateElement("Compile", $nsUri)
            $compile.SetAttribute("Include", $relative)
            [void]$itemGroup.AppendChild($compile)
        }
        $project.Save($projectPath)
    }

    return $missing | ForEach-Object { "ADD Compile Include=$_." }
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Source root not found: $SourceRoot"
}
if (-not (Test-Path -LiteralPath $GameProjectRoot -PathType Container)) {
    throw "Game project root not found: $GameProjectRoot"
}

$GameProjectRoot = (Resolve-Path -LiteralPath $GameProjectRoot).Path
Write-Host "DualWieldMod source sync" -ForegroundColor Cyan
Write-Host "  Repo:   $RepoRoot"
Write-Host "  Source: $SourceRoot"
Write-Host "  Target: $GameProjectRoot"
Write-Host "  Mode:   $(if ($Apply) { 'APPLY' } else { 'DRY-RUN' })"
Write-Host "  Build:  $(if ($Build) { $Configuration } else { 'disabled' })"

$changes = @()
$changes += Copy-Overlay "ModCode\ModMain" "ModCode\ModMain"
$changes += Copy-Overlay "ModExcel" "ModExcel"
$changes += Copy-Overlay "ModAssets" "ModAssets"
$changes += Ensure-ProjectCompileIncludes

if ($changes.Count -eq 0) {
    Write-Host "No source changes to sync." -ForegroundColor Green
} else {
    Write-Host "Planned changes:" -ForegroundColor Yellow
    foreach ($change in $changes) { Write-Host "  $change" }
    if (-not $Apply) {
        Write-Host "Dry-run only. Re-run with -Apply to write files." -ForegroundColor Yellow
    }
}

if ($Build) {
    $projectPath = Join-Path $GameProjectRoot "ModCode\ModMain\ModMain.csproj"
    Write-Host "Building real MOD project ($Configuration)..." -ForegroundColor Cyan
    & dotnet build $projectPath -c $Configuration -v:minimal
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed with exit code $LASTEXITCODE"
    }
}
