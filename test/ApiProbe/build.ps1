[CmdletBinding()]
param(
    [string[]]$ReferenceDir = @(),
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..\..")).Path
$ObjDir = Join-Path $ScriptRoot "obj"
$BinDir = Join-Path $ScriptRoot "bin\$Configuration"
$SourceFile = Join-Path $ScriptRoot "src\ApiSurfaceProbe.cs"
$OutputDll = Join-Path $BinDir "DualWieldMod.ApiProbe.dll"

function Add-ExistingDir {
    param(
        [System.Collections.Generic.List[string]]$Dirs,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $resolved = (Resolve-Path -LiteralPath $Path).Path
        if (-not $Dirs.Contains($resolved)) {
            [void]$Dirs.Add($resolved)
        }
    }
}

function Add-ReferenceDirWithCompanions {
    param(
        [System.Collections.Generic.List[string]]$Dirs,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    Add-ExistingDir $Dirs $resolved

    $leaf = Split-Path -Leaf $resolved
    if ($leaf -ieq "Managed") {
        Add-ExistingDir $Dirs (Split-Path -Parent $resolved)
    } else {
        Add-ExistingDir $Dirs (Join-Path $resolved "Managed")
    }
}

function Get-IdeaTemplateDllDir {
    param([string]$Root)

    $modQa = Join-Path $Root "ideas\modQ&A"
    if (-not (Test-Path -LiteralPath $modQa -PathType Container)) { return $null }

    $templateRoot = Get-ChildItem -LiteralPath $modQa -Directory |
        Where-Object { $_.Name -like "MOD*" } |
        Select-Object -First 1
    if ($null -eq $templateRoot) { return $null }

    $uiExample = Get-ChildItem -LiteralPath $templateRoot.FullName -Directory |
        Where-Object { $_.Name -like "*UI*" } |
        Select-Object -First 1
    if ($null -eq $uiExample) { return $null }

    return Join-Path $uiExample.FullName "ModProject\ModCode\ModMain\dll"
}

function Find-Assembly {
    param(
        [string]$Name,
        [string[]]$Dirs
    )

    foreach ($dir in $Dirs) {
        $candidate = Join-Path $dir $Name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

$frameworkRef = "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.7.2"
if (-not (Test-Path -LiteralPath $frameworkRef -PathType Container)) {
    throw ".NET Framework 4.7.2 reference assemblies were not found at: $frameworkRef"
}

$cscDll = Join-Path $env:ProgramFiles "dotnet\sdk\10.0.102\Roslyn\bincore\csc.dll"
if (-not (Test-Path -LiteralPath $cscDll -PathType Leaf)) {
    $sdkRoot = Join-Path $env:ProgramFiles "dotnet\sdk"
    $cscDll = Get-ChildItem -LiteralPath $sdkRoot -Recurse -Filter "csc.dll" |
        Where-Object { $_.FullName -like "*\Roslyn\bincore\csc.dll" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $cscDll) {
    throw "Roslyn csc.dll was not found under the installed .NET SDK."
}

$referenceDirs = [System.Collections.Generic.List[string]]::new()
foreach ($dir in $ReferenceDir) { Add-ReferenceDirWithCompanions $referenceDirs $dir }
Add-ReferenceDirWithCompanions $referenceDirs (Join-Path $ScriptRoot "refs")
Add-ReferenceDirWithCompanions $referenceDirs $env:DUALWIELDMOD_MANAGED_DIR
Add-ReferenceDirWithCompanions $referenceDirs $env:GGBH_MANAGED_DIR
Add-ReferenceDirWithCompanions $referenceDirs $env:TOI_MANAGED_DIR
Add-ReferenceDirWithCompanions $referenceDirs $env:GAME_MANAGED_DIR
Add-ExistingDir $referenceDirs (Get-IdeaTemplateDllDir $RepoRoot)

$frameworkAssemblies = @(
    "mscorlib.dll",
    "System.dll",
    "System.Core.dll",
    "Microsoft.CSharp.dll"
)

$requiredGameAssemblies = @(
    "Assembly-CSharp.dll",
    "0Harmony.dll",
    "Il2Cppmscorlib.dll",
    "Il2CppSystem.dll",
    "UnhollowerBaseLib.dll",
    "UnhollowerRuntimeLib.dll",
    "UnityEngine.CoreModule.dll",
    "UnityEngine.InputLegacyModule.dll",
    "UnityEngine.UIModule.dll",
    "UnityEngine.UI.dll"
)

Write-Host "ApiProbe reference directories:" -ForegroundColor Cyan
foreach ($dir in $referenceDirs) { Write-Host "  $dir" }

$missing = @()
foreach ($assembly in $requiredGameAssemblies) {
    if (-not (Find-Assembly $assembly $referenceDirs.ToArray())) {
        $missing += $assembly
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Missing required reference assemblies:" -ForegroundColor Yellow
    foreach ($assembly in $missing) { Write-Host "  $assembly" }
    Write-Host ""
    Write-Host "Provide the game's MelonLoader or Managed DLL directory with:" -ForegroundColor Yellow
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1 -ReferenceDir "<GameMelonLoaderOrManagedDir>"'
    Write-Host ""
    Write-Host "Or place/symlink DLLs into: test/ApiProbe/refs"
    exit 2
}

New-Item -ItemType Directory -Force -Path $ObjDir, $BinDir | Out-Null

$frameworkRefs = foreach ($assembly in $frameworkAssemblies) {
    $path = Join-Path $frameworkRef $assembly
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required .NET Framework reference not found: $path"
    }
    (Resolve-Path -LiteralPath $path).Path
}
$gameRefs = foreach ($assembly in $requiredGameAssemblies) {
    Find-Assembly $assembly $referenceDirs.ToArray()
}
$allRefs = @($frameworkRefs + $gameRefs) | Sort-Object -Unique

$rsp = Join-Path $ObjDir "compile.rsp"
$lines = @(
    "/noconfig",
    "/nostdlib+",
    "/target:library",
    "/langversion:7.3",
    "/optimize-",
    "/warn:4",
    "/out:`"$OutputDll`""
)
foreach ($ref in $allRefs) {
    $lines += "/reference:`"$ref`""
}
$lines += "`"$SourceFile`""
Set-Content -LiteralPath $rsp -Value $lines -Encoding UTF8

Write-Host "Compiling ApiProbe..." -ForegroundColor Cyan
& dotnet $cscDll "@$rsp"
if ($LASTEXITCODE -ne 0) {
    throw "ApiProbe compilation failed with exit code $LASTEXITCODE."
}

Write-Host "ApiProbe compiled successfully:" -ForegroundColor Green
Write-Host "  $OutputDll"
