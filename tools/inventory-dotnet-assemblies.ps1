[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [string]$OutputDir,
    [string]$CecilPath = ""
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
if ($Path.Count -eq 0) {
    $Path = @(
        (Join-Path $RepoRoot "resource\app"),
        (Join-Path $RepoRoot "resource\Mod解包结果\SaiLL.dll")
    )
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "generated\assembly-inventory"
}

function Add-ExistingFile {
    param(
        [System.Collections.Generic.List[string]]$Files,
        [string]$Candidate
    )
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return }
    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        $resolved = (Resolve-Path -LiteralPath $Candidate).Path
        if (-not $Files.Contains($resolved)) { [void]$Files.Add($resolved) }
    }
}

function Find-Cecil {
    $candidates = [System.Collections.Generic.List[string]]::new()
    Add-ExistingFile $candidates $CecilPath
    Add-ExistingFile $candidates (Join-Path $RepoRoot "resource\app\MelonLoader\Mono.Cecil.dll")
    Add-ExistingFile $candidates (Join-Path $RepoRoot "resource\app\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Il2CppAssemblyUnhollower\Mono.Cecil.dll")
    Add-ExistingFile $candidates "D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Mono.Cecil.dll"
    if ($candidates.Count -gt 0) { return $candidates[0] }
    return $null
}

function Get-InputDlls {
    param([string[]]$Inputs)
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($rawInputPath in $Inputs) {
        foreach ($inputPath in ($rawInputPath -split ',')) {
            $inputPath = $inputPath.Trim()
            if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }
            if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
                if ([System.IO.Path]::GetExtension($inputPath) -ieq ".dll") {
                    Add-ExistingFile $files $inputPath
                }
            } elseif (Test-Path -LiteralPath $inputPath -PathType Container) {
                Get-ChildItem -LiteralPath $inputPath -Recurse -Filter *.dll -File -ErrorAction SilentlyContinue |
                    ForEach-Object { Add-ExistingFile $files $_.FullName }
            }
        }
    }
    return $files.ToArray()
}

function Classify-AssemblySource {
    param([string]$File)
    $normalized = $File.Replace('/', '\')
    if ([System.IO.Path]::GetFileName($normalized) -eq "SaiLL.dll") { return "decompiled mod sample" }
    if ($normalized -like "*\MelonLoader\Managed\Assembly-CSharp.dll") { return "IL2CPP interop wrapper (Managed)" }
    if ($normalized -like "*\Cpp2IL\cpp2il_out\Assembly-CSharp.dll") { return "Cpp2IL output" }
    if ($normalized -like "*\MelonLoader\MelonLoader\*.dll") { return "MelonLoader/runtime dependency" }
    return "unknown"
}

function Get-NamespaceSummary {
    param([Mono.Cecil.ModuleDefinition]$Module)
    return @($Module.GetTypes() |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.Namespace) } |
        Group-Object Namespace |
        Sort-Object Count -Descending |
        Select-Object -First 30 |
        ForEach-Object { [pscustomobject]@{ namespace = $_.Name; typeCount = $_.Count } })
}

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value.ToString() -replace '\|', '\|' -replace "`r?`n", " ")
}

$resolvedCecil = Find-Cecil
if ([string]::IsNullOrWhiteSpace($resolvedCecil)) { throw "Mono.Cecil.dll was not found. Pass -CecilPath or keep resource/app available." }
Add-Type -LiteralPath $resolvedCecil

$dlls = Get-InputDlls $Path
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

foreach ($dll in $dlls) {
    $item = Get-Item -LiteralPath $dll
    $row = [ordered]@{
        path = $item.FullName
        fileName = $item.Name
        size = $item.Length
        sourceKind = Classify-AssemblySource $item.FullName
        isManaged = $false
        assemblyName = $null
        version = $null
        typeCount = 0
        methodCount = 0
        methodBodyCount = 0
        methodBodyRatio = 0
        fieldCount = 0
        propertyCount = 0
        referenceCount = 0
        references = @()
        namespaces = @()
        dnSpySuitability = "native-or-unreadable"
        readError = $null
    }

    try {
        $resolver = [Mono.Cecil.DefaultAssemblyResolver]::new()
        $resolver.AddSearchDirectory((Split-Path -Parent $item.FullName))
        foreach ($inputPath in $Path) {
            if (Test-Path -LiteralPath $inputPath -PathType Container) { $resolver.AddSearchDirectory((Resolve-Path -LiteralPath $inputPath).Path) }
        }
        $readerParams = [Mono.Cecil.ReaderParameters]::new()
        $readerParams.AssemblyResolver = $resolver
        $assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($item.FullName, $readerParams)
        $module = $assembly.MainModule
        $types = @($module.GetTypes())
        $methods = @($types | ForEach-Object { $_.Methods })
        $methodBodies = @($methods | Where-Object { $_.HasBody })
        $fields = @($types | ForEach-Object { $_.Fields })
        $properties = @($types | ForEach-Object { $_.Properties })
        $references = @($module.AssemblyReferences | ForEach-Object { $_.FullName })
        $ratio = if ($methods.Count -gt 0) { [Math]::Round($methodBodies.Count / [double]$methods.Count, 4) } else { 0 }

        $row.isManaged = $true
        $row.assemblyName = $assembly.Name.Name
        $row.version = $assembly.Name.Version.ToString()
        $row.typeCount = $types.Count
        $row.methodCount = $methods.Count
        $row.methodBodyCount = $methodBodies.Count
        $row.methodBodyRatio = $ratio
        $row.fieldCount = $fields.Count
        $row.propertyCount = $properties.Count
        $row.referenceCount = $references.Count
        $row.references = $references
        $row.namespaces = Get-NamespaceSummary $module
        $row.dnSpySuitability = if ($methodBodies.Count -eq 0) {
            "metadata-only-or-empty"
        } elseif ($row.sourceKind -like "IL2CPP interop wrapper*") {
            "wrapper-has-bodies-but-not-original-game-logic"
        } elseif ($row.sourceKind -eq "Cpp2IL output") {
            "cpp2il-structure-often-stubbed"
        } else {
            "managed-full-decompile-candidate"
        }
    } catch {
        $row.readError = $_.Exception.Message
    }

    [void]$results.Add([pscustomobject]$row)
}

$jsonPath = Join-Path $OutputDir "assembly-inventory.json"
$mdPath = Join-Path $OutputDir "ASSEMBLY_INVENTORY.md"
ConvertTo-Json -InputObject @($results.ToArray()) -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Assembly Inventory")
$lines.Add("")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("")
$lines.Add('Cecil: `' + $resolvedCecil + '`')
$lines.Add("")
$lines.Add("Inputs:")
foreach ($inputPath in $Path) { $lines.Add('- `' + $inputPath + '`') }
$lines.Add("")
$lines.Add("## Summary")
$lines.Add("")
$lines.Add("| File | Source | Managed | Types | Methods | Bodies | Body Ratio | dnSpy Suitability | Error |")
$lines.Add("| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |")
foreach ($result in ($results | Sort-Object fileName)) {
    $lines.Add("| $(Escape-MarkdownCell $result.fileName) | $(Escape-MarkdownCell $result.sourceKind) | $($result.isManaged) | $($result.typeCount) | $($result.methodCount) | $($result.methodBodyCount) | $($result.methodBodyRatio) | $(Escape-MarkdownCell $result.dnSpySuitability) | $(Escape-MarkdownCell $result.readError) |")
}
$lines.Add("")
$lines.Add("## Focus Assemblies")
$focusNames = @("MelonLoader.dll", "0Harmony.dll", "MonoMod.RuntimeDetour.dll", "Assembly-CSharp.dll", "SaiLL.dll")
foreach ($focus in $focusNames) {
    $matches = @($results | Where-Object { $_.fileName -eq $focus })
    if ($matches.Count -eq 0) { continue }
    foreach ($match in $matches) {
        $lines.Add("")
        $lines.Add(('### `{0}`' -f $match.fileName))
        $lines.Add("")
        $lines.Add(('- Path: `{0}`' -f $match.path))
        $lines.Add(('- Source: `{0}`' -f $match.sourceKind))
        $lines.Add(('- Managed: `{0}`' -f $match.isManaged))
        $lines.Add(('- Methods with bodies: `{0}/{1}`' -f $match.methodBodyCount, $match.methodCount))
        $lines.Add(('- dnSpy suitability: `{0}`' -f $match.dnSpySuitability))
        if ($match.namespaces.Count -gt 0) {
            $topNamespaces = (($match.namespaces | Select-Object -First 8 | ForEach-Object { $_.namespace + ':' + $_.typeCount }) -join ', ')
            $lines.Add(('- Top namespaces: `{0}`' -f $topNamespaces))
        }
    }
}

Set-Content -LiteralPath $mdPath -Value $lines -Encoding UTF8

Write-Host "Assembly inventory generated:" -ForegroundColor Green
Write-Host "  $mdPath"
Write-Host "  $jsonPath"

