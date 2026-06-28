[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("official", "community", "unclassified")]
    [string]$SourceKind,

    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [string]$OutputRoot = "",
    [string]$PackageName = "",
    [switch]$IncludeDependencies,
    [int]$ThrottleLimit = 10,
    [switch]$Force,
    [string]$DnSpyRoot = ""
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
$BatchScript = Join-Path $ScriptRoot "batch-decompile-managed-assemblies.ps1"
$DecompilerScript = Join-Path $ScriptRoot "decompile-dotnet-assembly.ps1"
$AnnotateScript = Join-Path $ScriptRoot "annotate-obfuscated-strings.ps1"

if (-not (Test-Path -LiteralPath $BatchScript -PathType Leaf)) { throw "Missing dependency: $BatchScript" }
if (-not (Test-Path -LiteralPath $DecompilerScript -PathType Leaf)) { throw "Missing dependency: $DecompilerScript" }
if (-not (Test-Path -LiteralPath $AnnotateScript -PathType Leaf)) { throw "Missing dependency: $AnnotateScript" }

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot "generated\app"
}

function New-Dir {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    return (Resolve-Path -LiteralPath $Path).Path
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}

function Write-JsonFile {
    param(
        [object]$Value,
        [string]$Path,
        [int]$Depth = 8
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-FileRecord {
    param(
        [string]$Path,
        [string]$BasePath
    )
    $item = Get-Item -LiteralPath $Path
    $relative = $item.FullName
    if (-not [string]::IsNullOrWhiteSpace($BasePath) -and (Test-Path -LiteralPath $BasePath)) {
        $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\'
        if ($item.FullName.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $item.FullName.Substring($base.Length)
        }
    }
    $hash = $null
    try { $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash } catch { $hash = $null }
    return [pscustomobject]@{
        path = $item.FullName
        relativePath = $relative
        bytes = $item.Length
        sha256 = $hash
        extension = $item.Extension
    }
}

function Get-DllSearchDirectories {
    param([string[]]$Roots)
    $dirs = [System.Collections.Generic.List[string]]::new()
    foreach ($root in $Roots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) { continue }
        $resolved = (Resolve-Path -LiteralPath $root).Path
        if ((Get-Item -LiteralPath $resolved).PSIsContainer) {
            if (-not $dirs.Contains($resolved)) { [void]$dirs.Add($resolved) }
            foreach ($dll in @(Get-ChildItem -LiteralPath $resolved -Recurse -Filter *.dll -File -ErrorAction SilentlyContinue)) {
                $dir = $dll.DirectoryName
                if (-not $dirs.Contains($dir)) { [void]$dirs.Add($dir) }
            }
        } else {
            $dir = Split-Path -Parent $resolved
            if (-not $dirs.Contains($dir)) { [void]$dirs.Add($dir) }
        }
    }
    return $dirs.ToArray()
}

function Write-FailureReport {
    param(
        [string]$BatchManifestPath,
        [string]$OutputPath
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
    $manifest = Read-JsonFile $BatchManifestPath
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add("# Failed Or Non-Managed Assemblies")
    [void]$lines.Add("")
    if ($null -eq $manifest -or $null -eq $manifest.assemblies) {
        [void]$lines.Add("No batch manifest was found.")
        $lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        return
    }

    $failed = @($manifest.assemblies | Where-Object { $_.status -in @("native-or-unreadable", "skipped-native-or-unreadable", "dnspy-failed", "script-error", "manifest-missing") })
    [void]$lines.Add(('- Total: `{0}`' -f $failed.Count))
    [void]$lines.Add("")
    [void]$lines.Add("| Status | Assembly | Relative Path | Error |")
    [void]$lines.Add("| --- | --- | --- | --- |")
    foreach ($row in ($failed | Sort-Object status, relativePath)) {
        $errorText = ([string]$row.error) -replace '\|', '\|' -replace "`r?`n", " "
        [void]$lines.Add(('| {0} | `{1}` | `{2}` | {3} |' -f $row.status, $row.assemblyName, $row.relativePath, $errorText))
    }
    $lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function Invoke-BatchDecompile {
    param(
        [string]$RootPath,
        [string]$OutputDir,
        [switch]$NoRecurse
    )
    $params = @{
        RootPath = $RootPath
        OutputDir = $OutputDir
        Parallel = $true
        ThrottleLimit = $ThrottleLimit
    }
    if ($NoRecurse) { $params.NoRecurse = $true }
    if ($Force) { $params.Force = $true }
    if (-not [string]::IsNullOrWhiteSpace($DnSpyRoot)) { $params.DnSpyRoot = $DnSpyRoot }

    $childOutput = $null
    try {
        $childOutput = & $BatchScript @params 2>&1
        foreach ($line in $childOutput) { Write-Host $line }
    } catch {
        if ($childOutput) { foreach ($line in $childOutput) { Write-Host $line } }
        throw "Batch decompile failed for $RootPath`: $($_.Exception.Message)"
    }
    return Join-Path $OutputDir "batch-manifest.json"
}

function Invoke-FullAssemblyDecompile {
    param(
        [string]$AssemblyPath,
        [string]$OutputDir,
        [string[]]$AssemblySearchPath = @()
    )
    $params = @{
        AssemblyPath = $AssemblyPath
        FullAssembly = $true
        OutputDir = $OutputDir
    }
    if ($AssemblySearchPath.Count -gt 0) { $params.AssemblySearchPath = $AssemblySearchPath }
    if (-not [string]::IsNullOrWhiteSpace($DnSpyRoot)) { $params.DnSpyRoot = $DnSpyRoot }

    $childOutput = $null
    try {
        $childOutput = & $DecompilerScript @params 2>&1
        foreach ($line in $childOutput) { Write-Host $line }
    } catch {
        if ($childOutput) { foreach ($line in $childOutput) { Write-Host $line } }
        throw "Full assembly decompile failed for $AssemblyPath`: $($_.Exception.Message)"
    }
    return Join-Path $OutputDir "manifest.json"
}

function New-JunctionOrReference {
    param(
        [string]$TargetPath,
        [string]$LinkPath
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LinkPath) | Out-Null
    if (Test-Path -LiteralPath $LinkPath) {
        return [pscustomobject]@{ linked = $true; linkPath = $LinkPath; targetPath = $TargetPath; mode = "existing" }
    }

    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
        return [pscustomobject]@{ linked = $true; linkPath = $LinkPath; targetPath = $TargetPath; mode = "junction" }
    } catch {
        $refPath = Join-Path (Split-Path -Parent $LinkPath) "REFERENCE.md"
        @(
            "# Referenced Generated Corpus",
            "",
            "The junction could not be created, so use this existing generated source root:",
            "",
            '```text',
            $TargetPath,
            '```',
            "",
            ("Error: " + $_.Exception.Message)
        ) | Set-Content -LiteralPath $refPath -Encoding UTF8
        return [pscustomobject]@{ linked = $false; linkPath = $LinkPath; targetPath = $TargetPath; mode = "reference"; reference = $refPath; error = $_.Exception.Message }
    }
}

function Write-CorpusRootDocs {
    param([string]$Root)
    $readme = Join-Path $Root "README.md"
    @(
        "# Offline dnSpy Corpus",
        "",
        "This generated corpus is local-only and ignored by Git.",
        "",
        '- `official/`: game, MelonLoader, and official dependency surfaces.',
        '- `community/`: community MOD samples and package-local annotations.',
        '- `official/GGBH_MOD/`: official/runtime loader bridge between the game MOD manager and MelonLoader.',
        '- `official/game-root/decompiled/Il2CppDumper_output/`: native IL2CPP structure evidence from GameAssembly.dll and global-metadata.dat.',
        '- `unclassified/`: ambiguous loader, bridge, or unknown-provenance assemblies waiting for classification.',
        "",
        "Do not treat wrapper source as original native game branch logic. Use runtime DWT traces for behavior truth."
    ) | Set-Content -LiteralPath $readme -Encoding UTF8

    foreach ($dir in @("official", "community", "unclassified")) {
        $path = Join-Path $Root $dir
        New-Item -ItemType Directory -Force -Path $path | Out-Null
        $title = switch ($dir) {
            "official" { "Official Corpus" }
            "community" { "Community Corpus" }
            default { "Unclassified Corpus" }
        }
        @("# $title", "", 'Generated local dnSpy corpus. See `../CORPUS_INDEX.md` for entry points.') |
            Set-Content -LiteralPath (Join-Path $path "README.md") -Encoding UTF8
    }
}

function Write-CorpusIndex {
    param([string]$Root)
    $indexPath = Join-Path $Root "CORPUS_INDEX.md"
    $officialRoot = Join-Path $Root "official"
    $communityRoot = Join-Path $Root "community"
    $unclassifiedRoot = Join-Path $Root "unclassified"
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add("# Offline dnSpy Corpus Index")
    [void]$lines.Add("")
    [void]$lines.Add(("Generated: {0}" -f (Get-Date).ToString("o")))
    [void]$lines.Add("")
    [void]$lines.Add("## Search")
    [void]$lines.Add("")
    [void]$lines.Add('```powershell')
    [void]$lines.Add(('rg -n "AddSkillMartialExp" "{0}"' -f $officialRoot))
    [void]$lines.Add(('rg -n "Button.onClick" "{0}"' -f $communityRoot))
    [void]$lines.Add(('rg -n "GameCMDMelonLoader|LoadDll|InitModMain" "{0}"' -f (Join-Path $officialRoot "GGBH_MOD")))
    [void]$lines.Add(('rg -n "SkillAttack|UnitEffectSkillHpSuck|UnitHitDynIntHandler" "{0}"' -f (Join-Path $officialRoot "game-root\decompiled\Il2CppDumper_output")))
    [void]$lines.Add(('rg -n "nBB.xBl" "{0}"' -f (Join-Path $communityRoot "SaiLL")))
    [void]$lines.Add(('rg -n "cMj.FMl" "{0}"' -f (Join-Path $communityRoot "SaiLL")))
    [void]$lines.Add('```')
    [void]$lines.Add("")
    [void]$lines.Add("## Trust Levels")
    [void]$lines.Add("")
    [void]$lines.Add('- `official`: highest static trust for API shape, loader bridge, official/runtime surfaces, and IL2CPP native structure evidence.')
    [void]$lines.Add('- `community`: useful examples, but not proof of game-kernel behavior.')
    [void]$lines.Add('- `unclassified`: readable code with unclear provenance; classify only after stronger evidence.')
    [void]$lines.Add("- IL2CPP wrapper, Cpp2IL, and Il2CppDumper outputs still need runtime validation for behavior.")
    [void]$lines.Add("")
    [void]$lines.Add("## Packages")
    [void]$lines.Add("")
    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    $packageManifests = @(
        Get-ChildItem -LiteralPath $Root -Recurse -Filter manifest.json -File -ErrorAction SilentlyContinue |
            Where-Object { (($_.FullName -notmatch '\\decompiled\\') -or ($_.FullName -match '\\Il2CppDumper_output\\manifest\.json$')) -and $_.FullName -notmatch '\\annotations\\reports\\' } |
            Sort-Object FullName
    )
    foreach ($manifest in $packageManifests) {
        $relative = $manifest.FullName.Substring($rootPath.Length + 1)
        [void]$lines.Add(('- `{0}`' -f $relative))
    }
    [void]$lines.Add("")
    [void]$lines.Add("## Generated Reports")
    [void]$lines.Add("")
    $reports = @(
        Get-ChildItem -LiteralPath $Root -Recurse -Include *.md -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -ieq ".md" -and (($_.FullName -match '\\failures\\|\\annotations\\reports\\') -or ($_.FullName -match '\\Il2CppDumper_output\\README\.md$')) -and $_.Name -ne "README.md" } |
            Sort-Object FullName
    )
    foreach ($report in $reports) {
        $relative = $report.FullName.Substring($rootPath.Length + 1)
        [void]$lines.Add(('- `{0}`' -f $relative))
    }
    $lines | Set-Content -LiteralPath $indexPath -Encoding UTF8
}

function New-StringCacheFromMap {
    param(
        [string]$StringMapPath,
        [string]$CachePath,
        [string]$Decoder = "unknown",
        [switch]$Append
    )
    $records = Read-JsonFile $StringMapPath
    $values = @()
    if ($records) {
        $values = @($records | Where-Object { $_.status -eq "ok" } | Sort-Object value, decoded -Unique | ForEach-Object {
            [pscustomobject]@{
                decoder = $Decoder
                expression = $_.expression
                value = $_.value
                decoded = $_.decoded
                sourceFile = $_.file
                sourceLine = $_.line
            }
        })
    }

    $existingEntries = @()
    if ($Append -and (Test-Path -LiteralPath $CachePath -PathType Leaf)) {
        $existing = Read-JsonFile $CachePath
        if ($existing -and $existing.entries) { $existingEntries = @($existing.entries) }
    }
    $allEntries = @($existingEntries + $values) | Sort-Object decoder, value, decoded, sourceFile, sourceLine -Unique

    Write-JsonFile ([pscustomobject]@{
        generatedAt = (Get-Date).ToString("o")
        sourceMap = $StringMapPath
        cacheKind = "package-local-string-decoder"
        entries = $allEntries
    }) $CachePath 10
}

function Copy-DirectoryContents {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )
    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) { return 0 }
    if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) { New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null }
    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    $count = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ieq ".cs" })) {
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
        $target = Join-Path $TargetDir $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        $count++
    }
    return $count
}

$OutputRoot = New-Dir $OutputRoot
Write-CorpusRootDocs $OutputRoot
$startedAt = Get-Date
$packageRecords = [System.Collections.Generic.List[object]]::new()

if ($SourceKind -eq "official") {
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) { throw "Official SourcePath must be a game root directory: $SourcePath" }
    $gameRoot = (Resolve-Path -LiteralPath $SourcePath).Path
    if ([string]::IsNullOrWhiteSpace($PackageName)) { $PackageName = "game" }
    $officialRoot = New-Dir (Join-Path $OutputRoot "official")
    $melonRoot = Join-Path $gameRoot "MelonLoader"

    $gameRootOut = New-Dir (Join-Path $officialRoot "game-root")
    $gameRootManifest = Invoke-BatchDecompile -RootPath $gameRoot -OutputDir (Join-Path $gameRootOut "decompiled") -NoRecurse
    Copy-Item -LiteralPath $gameRootManifest -Destination (Join-Path $gameRootOut "manifest.json") -Force
    Write-FailureReport $gameRootManifest (Join-Path $gameRootOut "failures\FAILED_ASSEMBLIES.md")
    [void]$packageRecords.Add([pscustomobject]@{ name = "official/game-root"; source = $gameRoot; manifest = (Join-Path $gameRootOut "manifest.json") })

    if (Test-Path -LiteralPath $melonRoot -PathType Container) {
        $melonPackage = New-Dir (Join-Path $officialRoot "MelonLoader")
        $managedDir = Join-Path $melonRoot "Managed"
        $dependenciesDir = Join-Path $melonRoot "Dependencies"

        $managedOut = New-Dir (Join-Path $melonPackage "Managed")
        $existingManaged = Join-Path $RepoRoot "generated\ait\AIT-010-managed-source"
        if (Test-Path -LiteralPath (Join-Path $existingManaged "batch-manifest.json") -PathType Leaf) {
            $linkInfo = New-JunctionOrReference -TargetPath $existingManaged -LinkPath (Join-Path $managedOut "decompiled\source")
            Copy-Item -LiteralPath (Join-Path $existingManaged "batch-manifest.json") -Destination (Join-Path $managedOut "manifest.json") -Force
            Write-FailureReport (Join-Path $existingManaged "batch-manifest.json") (Join-Path $managedOut "failures\FAILED_ASSEMBLIES.md")
            Write-JsonFile ([pscustomobject]@{
                generatedAt = (Get-Date).ToString("o")
                sourcePath = $managedDir
                reusedGeneratedCorpus = $existingManaged
                decompiledLink = $linkInfo
                note = "This package reuses AIT-010 instead of copying or regenerating the full Managed corpus."
            }) (Join-Path $managedOut "inventory\reference-manifest.json") 8
        } elseif (Test-Path -LiteralPath $managedDir -PathType Container) {
            $managedManifest = Invoke-BatchDecompile -RootPath $managedDir -OutputDir (Join-Path $managedOut "decompiled")
            Copy-Item -LiteralPath $managedManifest -Destination (Join-Path $managedOut "manifest.json") -Force
            Write-FailureReport $managedManifest (Join-Path $managedOut "failures\FAILED_ASSEMBLIES.md")
        }
        [void]$packageRecords.Add([pscustomobject]@{ name = "official/MelonLoader/Managed"; source = $managedDir; manifest = (Join-Path $managedOut "manifest.json") })

        if (Test-Path -LiteralPath $dependenciesDir -PathType Container) {
            $depsOut = New-Dir (Join-Path $melonPackage "Dependencies")
            $depsManifest = Invoke-BatchDecompile -RootPath $dependenciesDir -OutputDir (Join-Path $depsOut "decompiled")
            Copy-Item -LiteralPath $depsManifest -Destination (Join-Path $depsOut "manifest.json") -Force
            Write-FailureReport $depsManifest (Join-Path $depsOut "failures\FAILED_ASSEMBLIES.md")
            [void]$packageRecords.Add([pscustomobject]@{ name = "official/MelonLoader/Dependencies"; source = $dependenciesDir; manifest = (Join-Path $depsOut "manifest.json") })
        }

        $rootOut = New-Dir (Join-Path $melonPackage "root")
        $rootManifest = Invoke-BatchDecompile -RootPath $melonRoot -OutputDir (Join-Path $rootOut "decompiled") -NoRecurse
        Copy-Item -LiteralPath $rootManifest -Destination (Join-Path $rootOut "manifest.json") -Force
        Write-FailureReport $rootManifest (Join-Path $rootOut "failures\FAILED_ASSEMBLIES.md")
        [void]$packageRecords.Add([pscustomobject]@{ name = "official/MelonLoader/root"; source = $melonRoot; manifest = (Join-Path $rootOut "manifest.json") })

        Write-JsonFile ([pscustomobject]@{
            generatedAt = (Get-Date).ToString("o")
            sourceKind = "official"
            gameRoot = $gameRoot
            melonLoaderRoot = $melonRoot
            packages = $packageRecords
        }) (Join-Path $melonPackage "manifest.json") 8
    }
} elseif ($SourceKind -in @("community", "unclassified")) {
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw "$SourceKind SourcePath must be the main DLL: $SourcePath" }
    $mainDll = (Resolve-Path -LiteralPath $SourcePath).Path
    if ([string]::IsNullOrWhiteSpace($PackageName)) { $PackageName = [System.IO.Path]::GetFileNameWithoutExtension($mainDll) }
    $categoryRoot = New-Dir (Join-Path $OutputRoot $SourceKind)
    $packageRoot = New-Dir (Join-Path $categoryRoot $PackageName)
    $modsRoot = Split-Path -Parent $mainDll
    $packageAssetDir = Join-Path $modsRoot $PackageName

    $searchPathRoots = @($modsRoot)
    if (Test-Path -LiteralPath $packageAssetDir -PathType Container) { $searchPathRoots += $packageAssetDir }
    $searchPaths = Get-DllSearchDirectories $searchPathRoots

    $mainManifest = Invoke-FullAssemblyDecompile -AssemblyPath $mainDll -OutputDir (Join-Path $packageRoot "decompiled\main") -AssemblySearchPath $searchPaths
    $mainManifestJson = Read-JsonFile $mainManifest

    $depManifest = $null
    if ($IncludeDependencies -and (Test-Path -LiteralPath $packageAssetDir -PathType Container)) {
        $depManifest = Invoke-BatchDecompile -RootPath $packageAssetDir -OutputDir (Join-Path $packageRoot "decompiled\deps")
        Write-FailureReport $depManifest (Join-Path $packageRoot "failures\DEPENDENCY_FAILURES.md")
    }

    $allPackageFiles = @()
    if (Test-Path -LiteralPath $packageAssetDir -PathType Container) {
        $allPackageFiles = @(Get-ChildItem -LiteralPath $packageAssetDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { Get-FileRecord $_.FullName $packageAssetDir })
    }
    $dllRecords = @($allPackageFiles | Where-Object { $_.extension -ieq ".dll" })
    $resourceRecords = @($allPackageFiles | Where-Object { $_.extension -ine ".dll" } | Select-Object -First 500)

    $sourceMapPath = Join-Path $packageRoot "source-map.json"
    Write-JsonFile ([pscustomobject]@{
        generatedAt = (Get-Date).ToString("o")
        sourceKind = $SourceKind
        packageName = $PackageName
        mainDll = Get-FileRecord $mainDll $modsRoot
        packageDirectory = if (Test-Path -LiteralPath $packageAssetDir -PathType Container) { $packageAssetDir } else { $null }
        dlls = $dllRecords
        resourceFileSample = $resourceRecords
        resourceFileSampleLimit = 500
        mainDecompileManifest = $mainManifest
        dependencyBatchManifest = $depManifest
    }) $sourceMapPath 10

    $annotationRoot = New-Dir (Join-Path $packageRoot "annotations")
    $queueTasks = @()
    if ($PackageName -eq "SaiLL") {
        $queueTasks += [pscustomobject]@{
            id = "SaiLL-nBB-xBl"
            status = "ready"
            decoder = "KBR.nBB.xBl"
            pattern = "nBB.xBl(...)"
            assembly = $mainDll
            scope = "decompiled/main"
            note = "Package-local decoder. Do not treat as a game API."
        }
    }
    if ($PackageName -eq "SaiLL") {
        $chatGuiGuDll = Join-Path $packageAssetDir "AI\ChatGuiGuLocal.dll"
        $queueTasks += [pscustomobject]@{
            id = "SaiLL-deps-ChatGuiGuLocal-cMj-FMl"
            status = if (Test-Path -LiteralPath $chatGuiGuDll -PathType Leaf) { "ready" } else { "missing-assembly" }
            decoder = "qMY.cMj.FMl"
            pattern = "cMj.FMl(...)"
            assembly = $chatGuiGuDll
            scope = "decompiled/deps/AI_ChatGuiGuLocal"
            useDotnetHost = $true
            note = "Package-local dependency decoder for ChatGuiGuLocal.dll. Do not treat as a game API."
        }
    }
    Write-JsonFile ([pscustomobject]@{
        generatedAt = (Get-Date).ToString("o")
        packageName = $PackageName
        tasks = $queueTasks
    }) (Join-Path $annotationRoot "queue.json") 8

    if ($PackageName -eq "SaiLL" -and $mainManifestJson -and $mainManifestJson.fullAssembly -and (Test-Path -LiteralPath $mainManifestJson.fullAssembly.output -PathType Container)) {
        $reportsRoot = New-Dir (Join-Path $annotationRoot "reports")
        $annotationOut = Join-Path $reportsRoot "SaiLL-nBB-xBl"
        $annotateParams = @{
            AssemblyPath = $mainDll
            InputDir = [string]$mainManifestJson.fullAssembly.output
            OutputDir = $annotationOut
            DecoderType = "KBR.nBB"
            DecoderMethod = "xBl"
            DecoderGuardField = "KR9"
            DecoderGuardValue = 75
            CallPrefix = "nBB.xBl"
        }
        if ($searchPaths.Count -gt 0) { $annotateParams.AssemblySearchPath = $searchPaths }
        $childOutput = $null
        try {
            $childOutput = & $AnnotateScript @annotateParams 2>&1
            foreach ($line in $childOutput) { Write-Host $line }
        } catch {
            if ($childOutput) { foreach ($line in $childOutput) { Write-Host $line } }
            throw "String annotation failed for $PackageName`: $($_.Exception.Message)"
        }
        New-StringCacheFromMap -StringMapPath (Join-Path $annotationOut "string-map.json") -CachePath (Join-Path $annotationRoot "string-cache.json") -Decoder "KBR.nBB.xBl"
        $copiedAnnotatedFiles = Copy-DirectoryContents -SourceDir $annotationOut -TargetDir ([string]$mainManifestJson.fullAssembly.output)
        Write-JsonFile ([pscustomobject]@{
            generatedAt = (Get-Date).ToString("o")
            annotationOutput = $annotationOut
            decompiledMainOutput = [string]$mainManifestJson.fullAssembly.output
            copiedFileCount = $copiedAnnotatedFiles
            note = "Annotated C# files were copied back over decompiled/main for direct browsing."
        }) (Join-Path $annotationRoot "applied-to-main.json") 6
    }

    if ($PackageName -eq "SaiLL") {
        $chatGuiGuDll = Join-Path $packageAssetDir "AI\ChatGuiGuLocal.dll"
        $chatGuiGuManifestPath = Join-Path $packageRoot "decompiled\deps\AI_ChatGuiGuLocal\manifest.json"
        $chatGuiGuManifest = Read-JsonFile $chatGuiGuManifestPath
        if ((Test-Path -LiteralPath $chatGuiGuDll -PathType Leaf) -and $chatGuiGuManifest -and $chatGuiGuManifest.fullAssembly -and (Test-Path -LiteralPath $chatGuiGuManifest.fullAssembly.output -PathType Container)) {
            $reportsRoot = New-Dir (Join-Path $annotationRoot "reports")
            $annotationOut = Join-Path $reportsRoot "SaiLL-deps-ChatGuiGuLocal-cMj-FMl"
            $annotateParams = @{
                AssemblyPath = $chatGuiGuDll
                InputDir = [string]$chatGuiGuManifest.fullAssembly.output
                OutputDir = $annotationOut
                DecoderType = "qMY.cMj"
                DecoderMethod = "FMl"
                DecoderGuardField = "EM8"
                DecoderGuardValue = 75
                CallPrefix = "cMj.FMl"
                UseDotnetHost = $true
            }
            if ($searchPaths.Count -gt 0) { $annotateParams.AssemblySearchPath = $searchPaths }
            $childOutput = $null
            try {
                $childOutput = & $AnnotateScript @annotateParams 2>&1
                foreach ($line in $childOutput) { Write-Host $line }
            } catch {
                if ($childOutput) { foreach ($line in $childOutput) { Write-Host $line } }
                throw "String annotation failed for $PackageName dependency ChatGuiGuLocal`: $($_.Exception.Message)"
            }
            New-StringCacheFromMap -StringMapPath (Join-Path $annotationOut "string-map.json") -CachePath (Join-Path $annotationRoot "string-cache.json") -Decoder "qMY.cMj.FMl" -Append
            $copiedDepAnnotatedFiles = Copy-DirectoryContents -SourceDir $annotationOut -TargetDir ([string]$chatGuiGuManifest.fullAssembly.output)
            Write-JsonFile ([pscustomobject]@{
                generatedAt = (Get-Date).ToString("o")
                annotationOutput = $annotationOut
                decompiledDependencyOutput = [string]$chatGuiGuManifest.fullAssembly.output
                copiedFileCount = $copiedDepAnnotatedFiles
                decoder = "qMY.cMj.FMl"
                note = "Annotated C# files were copied back over decompiled/deps/AI_ChatGuiGuLocal for direct browsing."
            }) (Join-Path $annotationRoot "applied-to-deps-ChatGuiGuLocal.json") 6
        }
    }

    @(
        "# $PackageName Corpus",
        "",
        $(if ($SourceKind -eq "community") { "Community MOD sample package. Use this as implementation reference only, not as game-kernel truth." } else { "Unclassified package. Use this for evidence gathering only until provenance is resolved." }),
        "",
        "## Important Paths",
        "",
        '- Main decompile: `decompiled/main/`',
        '- Dependency decompile: `decompiled/deps/`',
        '- Annotation queue/cache: `annotations/`',
        '- Source map: `source-map.json`'
    ) | Set-Content -LiteralPath (Join-Path $packageRoot "README.md") -Encoding UTF8

    Write-JsonFile ([pscustomobject]@{
        generatedAt = (Get-Date).ToString("o")
        sourceKind = $SourceKind
        packageName = $PackageName
        mainDll = $mainDll
        packageDirectory = $packageAssetDir
        mainDecompileManifest = $mainManifest
        dependencyBatchManifest = $depManifest
        sourceMap = $sourceMapPath
        annotations = (Join-Path $packageRoot "annotations")
    }) (Join-Path $packageRoot "manifest.json") 8
}

Write-CorpusIndex $OutputRoot

Write-JsonFile ([pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    sourceKind = $SourceKind
    sourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
    outputRoot = $OutputRoot
    packageName = $PackageName
    includeDependencies = [bool]$IncludeDependencies
    throttleLimit = $ThrottleLimit
    force = [bool]$Force
    startedAt = $startedAt.ToString("o")
    finishedAt = (Get-Date).ToString("o")
}) (Join-Path $OutputRoot "last-run.json") 8

Write-Host "dnSpy corpus build complete:" -ForegroundColor Green
Write-Host "  $OutputRoot"
Write-Host "  $(Join-Path $OutputRoot 'CORPUS_INDEX.md')"
