[CmdletBinding()]
param(
    [string]$RootPath = "",
    [string]$OutputDir = "",
    [string]$IncludeRegex = "",
    [string]$ExcludeRegex = "",
    [int]$MaxAssemblies = 0,
    [switch]$NoRecurse,
    [switch]$Parallel,
    [int]$ThrottleLimit = 10,
    [switch]$Force,
    [string]$DnSpyRoot = ""
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
$DecompilerScript = Join-Path $ScriptRoot "decompile-dotnet-assembly.ps1"
if (-not (Test-Path -LiteralPath $DecompilerScript -PathType Leaf)) {
    throw "Missing dependency: $DecompilerScript"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "generated\ait\AIT-009-melonloader-source"
}

function Find-MelonLoaderRoot {
    $candidateRoots = @(
        "D:\Games\Steam\steamapps\common",
        "C:\Program Files (x86)\Steam\steamapps\common"
    )
    foreach ($candidateRoot in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $candidateRoot -PathType Container)) { continue }
        $found = Get-ChildItem -LiteralPath $candidateRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "MelonLoader\MelonLoader.dll" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
        if ($found) { return (Split-Path -Parent $found) }
    }
    return $null
}

function Test-ManagedAssembly {
    param([string]$Path)
    try {
        $name = [System.Reflection.AssemblyName]::GetAssemblyName($Path)
        return [pscustomobject]@{
            isManaged = $true
            fullName = $name.FullName
            name = $name.Name
            version = if ($name.Version) { $name.Version.ToString() } else { "" }
            error = ""
        }
    } catch {
        return [pscustomobject]@{
            isManaged = $false
            fullName = ""
            name = ""
            version = ""
            error = $_.Exception.Message
        }
    }
}

function Get-RelativePathSafe {
    param(
        [string]$BasePath,
        [string]$Path
    )
    $baseFull = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\'
    $pathFull = (Resolve-Path -LiteralPath $Path).Path
    if ($pathFull.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $pathFull.Substring($baseFull.Length)
    }
    return [System.IO.Path]::GetFileName($pathFull)
}

function ConvertTo-SafePathPart {
    param([string]$Value)
    $safe = $Value
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace($ch, '_') }
    $safe = $safe.Replace(':', '_').Replace('/', '\')
    $parts = $safe -split '[\\]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    return ($parts -join '__')
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}

if ([string]::IsNullOrWhiteSpace($RootPath)) {
    $RootPath = Find-MelonLoaderRoot
}
if ([string]::IsNullOrWhiteSpace($RootPath)) { throw "RootPath was not provided and MelonLoader root was not found." }
if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) { throw "RootPath not found: $RootPath" }
$RootPath = (Resolve-Path -LiteralPath $RootPath).Path

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$dllSearchArgs = @{ LiteralPath = $RootPath; Filter = "*.dll"; File = $true; ErrorAction = "SilentlyContinue" }
if (-not $NoRecurse) { $dllSearchArgs.Recurse = $true }
$dlls = @(Get-ChildItem @dllSearchArgs | Sort-Object FullName)
if (-not [string]::IsNullOrWhiteSpace($IncludeRegex)) {
    $dlls = @($dlls | Where-Object { $_.FullName -match $IncludeRegex })
}
if (-not [string]::IsNullOrWhiteSpace($ExcludeRegex)) {
    $dlls = @($dlls | Where-Object { $_.FullName -notmatch $ExcludeRegex })
}
if ($MaxAssemblies -gt 0) {
    $dlls = @($dlls | Select-Object -First $MaxAssemblies)
}

$assemblySearchPaths = @($dlls | ForEach-Object { $_.DirectoryName } | Sort-Object -Unique)
$rows = [System.Collections.Generic.List[object]]::new()
$searchRoots = [System.Collections.Generic.List[string]]::new()
$startedAt = Get-Date

$workItems = [System.Collections.Generic.List[object]]::new()
$index = 0
foreach ($dll in $dlls) {
    $index++
    $relative = Get-RelativePathSafe -BasePath $RootPath -Path $dll.FullName
    $managed = Test-ManagedAssembly -Path $dll.FullName
    $safeBase = ConvertTo-SafePathPart ($relative -replace '\.dll$', '')
    $assemblyOutDir = Join-Path $OutputDir $safeBase
    $manifestPath = Join-Path $assemblyOutDir "manifest.json"
    $status = "pending"
    $exitCode = $null
    $sourceFileCount = 0
    $namespaceCount = 0
    $typeCount = 0
    $decompileOutput = ""
    $errorMessage = ""

    if (-not $managed.isManaged) {
        $status = "native-or-unreadable"
        $errorMessage = $managed.error
    } else {
        $existing = Read-JsonFile -Path $manifestPath
        if (($existing -ne $null) -and (-not $Force)) {
            $existingExit = $existing.fullAssembly.exitCode
            if ($existingExit -eq 0) {
                $status = "skipped-existing"
                $exitCode = 0
                $sourceFileCount = [int]$existing.fullAssembly.sourceFileCount
                $namespaceCount = [int]$existing.fullAssembly.namespaceCount
                $typeCount = [int]$existing.fullAssembly.typeCount
                $decompileOutput = [string]$existing.fullAssembly.output
                if (-not [string]::IsNullOrWhiteSpace($decompileOutput)) { [void]$searchRoots.Add($decompileOutput) }
            }
        }
    }

    $row = [pscustomobject]@{
        relativePath = $relative
        path = $dll.FullName
        bytes = $dll.Length
        managed = $managed.isManaged
        assemblyName = $managed.name
        assemblyFullName = $managed.fullName
        version = $managed.version
        status = $status
        exitCode = $exitCode
        outputDir = $assemblyOutDir
        decompileOutput = $decompileOutput
        sourceFileCount = $sourceFileCount
        namespaceCount = $namespaceCount
        typeCount = $typeCount
        error = $errorMessage
        index = $index
    }

    if (($status -eq "pending") -and $managed.isManaged) {
        [void]$workItems.Add($row)
    } else {
        [void]$rows.Add($row)
    }
}

function Read-DecompileRow {
    param(
        [object]$WorkItem,
        [string]$ManifestPath
    )
    $child = Read-JsonFile -Path $ManifestPath
    if ($child -and $child.fullAssembly) {
        $WorkItem.exitCode = [int]$child.fullAssembly.exitCode
        $WorkItem.sourceFileCount = [int]$child.fullAssembly.sourceFileCount
        $WorkItem.namespaceCount = [int]$child.fullAssembly.namespaceCount
        $WorkItem.typeCount = [int]$child.fullAssembly.typeCount
        $WorkItem.decompileOutput = [string]$child.fullAssembly.output
        $WorkItem.status = if ($WorkItem.exitCode -eq 0) { "decompiled" } else { "dnspy-failed" }
    } else {
        $WorkItem.status = "manifest-missing"
        $WorkItem.error = "No child manifest was produced."
    }
    return $WorkItem
}

if ($workItems.Count -gt 0) {
    if ($Parallel) {
        $throttle = [Math]::Max(1, $ThrottleLimit)
        $jobs = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $workItems) {
            New-Item -ItemType Directory -Force -Path $item.outputDir | Out-Null
            $stdoutLog = Join-Path $item.outputDir "batch.stdout.txt"
            $stderrLog = Join-Path $item.outputDir "batch.stderr.txt"
            $manifestPath = Join-Path $item.outputDir "manifest.json"
            while (@($jobs | Where-Object { $_.Job.State -eq "Running" }).Count -ge $throttle) {
                $done = Wait-Job -Job @($jobs | ForEach-Object { $_.Job }) -Any -Timeout 2
                if ($done) {
                    $finished = @($jobs | Where-Object { $_.Job.Id -eq $done.Id })
                    foreach ($entry in $finished) {
                        Receive-Job -Job $entry.Job -ErrorAction SilentlyContinue | Out-Null
                        Remove-Job -Job $entry.Job -Force -ErrorAction SilentlyContinue
                        [void]$jobs.Remove($entry)
                        $updated = Read-DecompileRow -WorkItem $entry.Item -ManifestPath $entry.ManifestPath
                        if ($entry.Job.State -eq "Failed") { $updated.status = "script-error"; $updated.error = "Background job failed." }
                        [void]$rows.Add($updated)
                        if (($updated.exitCode -eq 0) -and (-not [string]::IsNullOrWhiteSpace($updated.decompileOutput))) { [void]$searchRoots.Add($updated.decompileOutput) }
                    }
                }
            }
            Write-Host ("[{0}/{1}] Queue decompile {2}" -f $item.index, $dlls.Count, $item.relativePath) -ForegroundColor Cyan
            $job = Start-Job -ScriptBlock {
                param($DecompilerScript, $AssemblyPath, $OutputDir, $AssemblySearchPaths, $DnSpyRoot, $StdoutLog, $StderrLog)
                & $DecompilerScript -AssemblyPath $AssemblyPath -FullAssembly -OutputDir $OutputDir -AssemblySearchPath $AssemblySearchPaths -DnSpyRoot $DnSpyRoot 1> $StdoutLog 2> $StderrLog
            } -ArgumentList $DecompilerScript, $item.path, $item.outputDir, $assemblySearchPaths, $DnSpyRoot, $stdoutLog, $stderrLog
            [void]$jobs.Add([pscustomobject]@{ Job = $job; Item = $item; ManifestPath = $manifestPath })
        }
        while ($jobs.Count -gt 0) {
            $done = Wait-Job -Job @($jobs | ForEach-Object { $_.Job }) -Any -Timeout 2
            if (-not $done) { continue }
            $finished = @($jobs | Where-Object { $_.Job.Id -eq $done.Id })
            foreach ($entry in $finished) {
                Receive-Job -Job $entry.Job -ErrorAction SilentlyContinue | Out-Null
                Remove-Job -Job $entry.Job -Force -ErrorAction SilentlyContinue
                [void]$jobs.Remove($entry)
                $updated = Read-DecompileRow -WorkItem $entry.Item -ManifestPath $entry.ManifestPath
                if ($entry.Job.State -eq "Failed") { $updated.status = "script-error"; $updated.error = "Background job failed." }
                [void]$rows.Add($updated)
                if (($updated.exitCode -eq 0) -and (-not [string]::IsNullOrWhiteSpace($updated.decompileOutput))) { [void]$searchRoots.Add($updated.decompileOutput) }
            }
        }
    } else {
        foreach ($item in $workItems) {
            New-Item -ItemType Directory -Force -Path $item.outputDir | Out-Null
            $stdoutLog = Join-Path $item.outputDir "batch.stdout.txt"
            $stderrLog = Join-Path $item.outputDir "batch.stderr.txt"
            $manifestPath = Join-Path $item.outputDir "manifest.json"
            Write-Host ("[{0}/{1}] Decompiling {2}" -f $item.index, $dlls.Count, $item.relativePath) -ForegroundColor Cyan
            try {
                & $DecompilerScript -AssemblyPath $item.path -FullAssembly -OutputDir $item.outputDir -AssemblySearchPath $assemblySearchPaths -DnSpyRoot $DnSpyRoot 1> $stdoutLog 2> $stderrLog
                $updated = Read-DecompileRow -WorkItem $item -ManifestPath $manifestPath
            } catch {
                $item.status = "script-error"
                $item.error = $_.Exception.Message
                $updated = $item
            }
            [void]$rows.Add($updated)
            if (($updated.exitCode -eq 0) -and (-not [string]::IsNullOrWhiteSpace($updated.decompileOutput))) { [void]$searchRoots.Add($updated.decompileOutput) }
        }
    }
}


$finishedAt = Get-Date
$summary = [pscustomobject]@{
    generatedAt = $finishedAt.ToString("o")
    rootPath = $RootPath
    outputDir = $OutputDir
    includeRegex = $IncludeRegex
    excludeRegex = $ExcludeRegex
    maxAssemblies = $MaxAssemblies
    noRecurse = [bool]$NoRecurse
    force = [bool]$Force
    startedAt = $startedAt.ToString("o")
    finishedAt = $finishedAt.ToString("o")
    elapsedSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 3)
    totalDlls = $dlls.Count
    managedCount = @($rows | Where-Object { $_.managed }).Count
    nativeOrUnreadableCount = @($rows | Where-Object { -not $_.managed }).Count
    decompiledCount = @($rows | Where-Object { $_.status -eq "decompiled" }).Count
    skippedExistingCount = @($rows | Where-Object { $_.status -eq "skipped-existing" }).Count
    failedCount = @($rows | Where-Object { $_.status -in @("dnspy-failed", "script-error", "manifest-missing") }).Count
    sourceFileCount = @($rows | Measure-Object -Property sourceFileCount -Sum).Sum
    namespaceCount = @($rows | Measure-Object -Property namespaceCount -Sum).Sum
    typeCount = @($rows | Measure-Object -Property typeCount -Sum).Sum
    assemblies = $rows
}

$manifestPath = Join-Path $OutputDir "batch-manifest.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$searchRootsPath = Join-Path $OutputDir "source-roots.txt"
@($searchRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) | Set-Content -LiteralPath $searchRootsPath -Encoding UTF8

$reportPath = Join-Path $OutputDir "SOURCE_INDEX.md"
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add("# Managed Assembly Source Index")
[void]$lines.Add("")
[void]$lines.Add("Generated: $($summary.generatedAt)")
[void]$lines.Add("")
[void]$lines.Add('Root: `' + $RootPath + '`')
[void]$lines.Add("")
[void]$lines.Add("## Summary")
[void]$lines.Add("")
[void]$lines.Add("| Metric | Value |")
[void]$lines.Add("| --- | ---: |")
[void]$lines.Add("| DLLs considered | $($summary.totalDlls) |")
[void]$lines.Add("| Managed DLLs | $($summary.managedCount) |")
[void]$lines.Add("| Native/unreadable skipped | $($summary.nativeOrUnreadableCount) |")
[void]$lines.Add("| Decompiled this run | $($summary.decompiledCount) |")
[void]$lines.Add("| Skipped existing | $($summary.skippedExistingCount) |")
[void]$lines.Add("| Failed | $($summary.failedCount) |")
[void]$lines.Add("| Source files | $($summary.sourceFileCount) |")
[void]$lines.Add("| Types | $($summary.typeCount) |")
[void]$lines.Add("")
[void]$lines.Add("## Search")
[void]$lines.Add("")
[void]$lines.Add("Use ripgrep against this ignored generated corpus:")
[void]$lines.Add("")
[void]$lines.Add('```powershell')
[void]$lines.Add('rg -n "Harmony" "' + $OutputDir + '"')
[void]$lines.Add('rg -n "il2cpp_runtime_invoke|RegisterTypeInIl2Cpp|MelonMod" "' + $OutputDir + '"')
[void]$lines.Add('```')
[void]$lines.Add("")
[void]$lines.Add("## Assemblies")
[void]$lines.Add("")
[void]$lines.Add("| Status | Managed | Source Files | Types | Assembly | Relative Path |")
[void]$lines.Add("| --- | --- | ---: | ---: | --- | --- |")
foreach ($row in ($rows | Sort-Object status, relativePath)) {
    $assemblyLabel = if ([string]::IsNullOrWhiteSpace($row.assemblyName)) { "" } else { $row.assemblyName }
    [void]$lines.Add(('| {0} | {1} | {2} | {3} | `{4}` | `{5}` |' -f $row.status, $row.managed, $row.sourceFileCount, $row.typeCount, $assemblyLabel, $row.relativePath))
}
$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host "Batch managed decompile complete:" -ForegroundColor Green
Write-Host "  $OutputDir"
Write-Host "  $manifestPath"
Write-Host "  $reportPath"
Write-Host "  $searchRootsPath"
