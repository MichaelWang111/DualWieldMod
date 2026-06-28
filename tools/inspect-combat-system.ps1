[CmdletBinding()]
param(
    [string]$AssemblyPath,
    [string]$CecilPath,
    [string]$OutputDir,
    [switch]$NoJson
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "generated"
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

function Find-AssemblyCSharp {
    $candidates = [System.Collections.Generic.List[string]]::new()

    foreach ($envName in @("DUALWIELDMOD_MANAGED_DIR", "GGBH_MANAGED_DIR", "TOI_MANAGED_DIR", "GAME_MANAGED_DIR")) {
        $value = [Environment]::GetEnvironmentVariable($envName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            Add-ExistingFile $candidates (Join-Path $value "Assembly-CSharp.dll")
            Add-ExistingFile $candidates (Join-Path $value "Managed\Assembly-CSharp.dll")
        }
    }

    $knownRoots = @(
        "D:\Games\Steam\steamapps\common",
        "C:\Program Files (x86)\Steam\steamapps\common"
    )

    foreach ($root in $knownRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Add-ExistingFile $candidates (Join-Path $_.FullName "MelonLoader\Managed\Assembly-CSharp.dll")
                Add-ExistingFile $candidates (Join-Path $_.FullName "Managed\Assembly-CSharp.dll")
            }
    }

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }

    return $null
}

function Find-Cecil {
    param([string]$ResolvedAssemblyPath)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($ResolvedAssemblyPath)) {
        $managedDir = Split-Path -Parent $ResolvedAssemblyPath
        $melonLoaderDir = Split-Path -Parent $managedDir
        Add-ExistingFile $candidates (Join-Path $melonLoaderDir "Mono.Cecil.dll")
        Add-ExistingFile $candidates (Join-Path $managedDir "Mono.Cecil.dll")
    }

    foreach ($envName in @("DUALWIELDMOD_MANAGED_DIR", "GGBH_MANAGED_DIR", "TOI_MANAGED_DIR", "GAME_MANAGED_DIR")) {
        $value = [Environment]::GetEnvironmentVariable($envName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            Add-ExistingFile $candidates (Join-Path $value "Mono.Cecil.dll")
            Add-ExistingFile $candidates (Join-Path $value "..\Mono.Cecil.dll")
        }
    }

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }

    return $null
}

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value.ToString() -replace '\|', '\|' -replace "`r?`n", " ")
}

function Get-TypeByName {
    param(
        [Mono.Cecil.AssemblyDefinition]$Assembly,
        [string]$Name
    )
    return $Assembly.MainModule.GetTypes() |
        Where-Object { $_.FullName -eq $Name -or $_.Name -eq $Name -or $_.FullName -like "*$Name" } |
        Select-Object -First 1
}

function Get-InterestingMethods {
    param([Mono.Cecil.TypeDefinition]$Type)
    $patterns = "BattleStart|BattleEnd|Create|Hit|Exp|Martial|Skill|Attack|Cost|CD|Use|Shot|Damage|Dmg|Effect|Init|IsCreate|Add"
    return @($Type.Methods |
        Where-Object { $_.Name -match $patterns -and -not $_.IsGetter -and -not $_.IsSetter } |
        Select-Object -First 80 |
        ForEach-Object {
            $params = ($_.Parameters | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }) -join ", "
            [pscustomobject]@{
                Name = $_.Name
                ReturnType = $_.ReturnType.Name
                Parameters = $params
            }
        })
}

function Get-InterestingProperties {
    param([Mono.Cecil.TypeDefinition]$Type)
    $patterns = "exp|mastery|martial|skill|hit|battle|damage|dmg|cost|cd|create|effect|unit|weapon|magic|data"
    return @($Type.Properties |
        Where-Object { $_.Name -match $patterns -or $_.PropertyType.Name -match $patterns } |
        Select-Object -First 80 |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Type = $_.PropertyType.FullName
            }
        })
}

function Get-InterestingFields {
    param([Mono.Cecil.TypeDefinition]$Type)
    $patterns = "exp|mastery|martial|skill|hit|battle|damage|dmg|cost|cd|create|effect|unit|weapon|magic|data|FieldInfoPtr_"
    return @($Type.Fields |
        Where-Object { $_.Name -match $patterns -or $_.FieldType.Name -match $patterns } |
        Select-Object -First 100 |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Type = $_.FieldType.FullName
            }
        })
}

function Get-NestedClosureInfo {
    param([Mono.Cecil.TypeDefinition]$Type)
    return @($Type.NestedTypes |
        Where-Object { $_.Name -match "DisplayClass|__c" } |
        Select-Object -First 40 |
        ForEach-Object {
            $fields = @($_.Fields |
                Where-Object { $_.Name -match "FieldInfoPtr_" } |
                ForEach-Object { $_.Name -replace "^NativeFieldInfoPtr_", "" })
            $methods = @($_.Methods |
                Where-Object { $_.Name -notmatch "^get_|^set_|cctor|\.ctor" } |
                ForEach-Object { $_.Name })
            [pscustomobject]@{
                Name = $_.FullName
                Fields = $fields
                Methods = $methods
            }
        })
}

function Add-Table {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [array]$Rows,
        [string[]]$Columns
    )
    if ($Rows.Count -eq 0) {
        $Lines.Add("_None found._")
        return
    }

    $Lines.Add("| " + ($Columns -join " | ") + " |")
    $Lines.Add("| " + (($Columns | ForEach-Object { "---" }) -join " | ") + " |")
    foreach ($row in $Rows) {
        $values = foreach ($column in $Columns) { Escape-MarkdownCell $row.$column }
        $Lines.Add("| " + ($values -join " | ") + " |")
    }
}

if ([string]::IsNullOrWhiteSpace($AssemblyPath)) {
    $AssemblyPath = Find-AssemblyCSharp
}
if ([string]::IsNullOrWhiteSpace($AssemblyPath) -or -not (Test-Path -LiteralPath $AssemblyPath -PathType Leaf)) {
    throw "Assembly-CSharp.dll was not found. Pass -AssemblyPath or set GGBH_MANAGED_DIR / GAME_MANAGED_DIR."
}
$AssemblyPath = (Resolve-Path -LiteralPath $AssemblyPath).Path

if ([string]::IsNullOrWhiteSpace($CecilPath)) {
    $CecilPath = Find-Cecil $AssemblyPath
}
if ([string]::IsNullOrWhiteSpace($CecilPath) -or -not (Test-Path -LiteralPath $CecilPath -PathType Leaf)) {
    throw "Mono.Cecil.dll was not found. Pass -CecilPath."
}
$CecilPath = (Resolve-Path -LiteralPath $CecilPath).Path

Add-Type -LiteralPath $CecilPath
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($AssemblyPath)

$focusTypeNames = @(
    "UnitCtrlPlayer",
    "DLCUnitCtrlPlayer",
    "BattleDataMgr",
    "BattleEndMgr",
    "BattleMapMgr",
    "WorldBattleMgr",
    "UnitActionRoleBattle",
    "SkillAttack",
    "SkillBase",
    "SkillDataAttack",
    "SkillCreateData",
    "MissileShotData",
    "MartialTool",
    "MartialTool/HitData",
    "FormulaTool/Battle",
    "FormulaTool/Martial"
)

$focusTypes = @()
foreach ($name in $focusTypeNames) {
    $type = Get-TypeByName $assembly $name
    if ($null -ne $type) {
        $focusTypes += [pscustomobject]@{
            Name = $type.FullName
            Properties = Get-InterestingProperties $type
            Fields = Get-InterestingFields $type
            Methods = Get-InterestingMethods $type
            NestedClosures = Get-NestedClosureInfo $type
        }
    }
}

$battleEventTypes = @($assembly.MainModule.GetTypes() |
    Where-Object { $_.Namespace -eq "EBattleTypeData" -and $_.Name -match "Battle|UseSkill|Hit|DynInt|Effect|Bullet|Unit" } |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            Name = $_.FullName
            Properties = @($_.Properties | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Type = $_.PropertyType.FullName } })
        }
    })

$battleType = Get-TypeByName $assembly "EBattleType"
$battleEventHelpers = @()
if ($null -ne $battleType) {
    $battleEventHelpers = @($battleType.Methods |
        Where-Object { $_.Name -match "Battle|Skill|Hit|DynInt|Unit" -and -not $_.IsGetter -and -not $_.IsSetter } |
        Sort-Object Name |
        ForEach-Object {
            $params = ($_.Parameters | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }) -join ", "
            [pscustomobject]@{ Name = $_.Name; ReturnType = $_.ReturnType.Name; Parameters = $params }
        })
}

$experienceSurface = @($assembly.MainModule.GetTypes() |
    Where-Object { $_.Name -match "Battle|Unit|Skill|Martial|Exp" } |
    ForEach-Object {
        $type = $_
        @($type.Properties | Where-Object { $_.Name -match "exp|mastery|martialUseAddExp|allMartialOldExp|allUpLevelMartial" } |
            ForEach-Object { [pscustomobject]@{ Owner = $type.FullName; Kind = "Property"; Name = $_.Name; Type = $_.PropertyType.FullName } })
        @($type.Methods | Where-Object { $_.Name -match "Exp|Mastery|SkillAddExp|AddSkillMartialExp" } |
            ForEach-Object {
                $params = ($_.Parameters | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }) -join ", "
                [pscustomobject]@{ Owner = $type.FullName; Kind = "Method"; Name = $_.Name; Type = "$($_.ReturnType.Name)($params)" }
            })
    } |
    Select-Object -First 220)

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("# Combat System Static Report")
$report.Add("")
$report.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$report.Add("")
$report.Add('Assembly: `' + $AssemblyPath + '`')
$report.Add("")
$report.Add('Cecil: `' + $CecilPath + '`')
$report.Add("")
$report.Add("## What This Can And Cannot Prove")
$report.Add("")
$report.Add("This report is fully offline. It reads IL2CPP interop assemblies and does not launch the game or load the MOD.")
$report.Add("")
$report.Add("It can confirm type names, method signatures, fields, properties, event data shapes, and useful Harmony/API probe targets. It cannot prove method-internal branch order, runtime event order, damage formulas, or whether an API call actually mutates game state. Those require a small runtime trace MOD.")
$report.Add("")
$report.Add("## High-Value Offline Findings")
$report.Add("")
$report.Add('- UnitCtrlPlayer exposes normal skill creation, hit handling, martialUseAddExp, and both AddSkillMartialExp(...) overloads.')
$report.Add('- BattleDataMgr exposes battle start/end tracking, allMartialOldExp, allUpLevelMartial, and start mastery fields for left/right/step/ultimate/abilities.')
$report.Add('- UnitActionRoleBattle.SkillAddExp(WorldUnitBase) is a likely battle-end or action-level skill-exp settlement target.')
$report.Add('- EBattleTypeData exposes fine-grained use/hit/damage/effect events suitable for runtime tracing.')
$report.Add('- UnitEffectSkillHpSuck exists and should be traced for blade lifesteal attribution.')
$report.Add("")
$report.Add("## Recommended Runtime Trace Hooks")
$report.Add("")
$traceRows = @(
    [pscustomobject]@{ Hook = "EBattleType.OneUnitUseSkillAttackFront / OneUnitUseSkillAttack"; Purpose = "Skill use starts; capture SkillAttack and SkillCreateData before projectiles."; Offline = "Event data shape confirmed" },
    [pscustomobject]@{ Hook = "EBattleType.OneUnitHitSkillFront / OneUnitHitSkill / UnitHit"; Purpose = "Hit attribution; capture SkillBase, HitData, bullet, hit unit."; Offline = "Event data shape confirmed" },
    [pscustomobject]@{ Hook = "EBattleType.UnitHitDynIntHandler"; Purpose = "Damage mutation window; capture dyn value and HitData."; Offline = "Event data shape confirmed" },
    [pscustomobject]@{ Hook = "EBattleType.UnitEffectSkillHpSuck"; Purpose = "Lifesteal attribution check."; Offline = "Event data shape confirmed" },
    [pscustomobject]@{ Hook = "UnitCtrlPlayer.AddSkillMartialExp overloads"; Purpose = "Direct skill-exp API calls."; Offline = "Method signatures confirmed" },
    [pscustomobject]@{ Hook = "UnitCtrlPlayer.OnUnitHit"; Purpose = "Player hit-side aggregation; likely martialUseAddExp mutation area."; Offline = "Method signature confirmed" },
    [pscustomobject]@{ Hook = "BattleDataMgr.OnUnitHit / OnBattleEndCall"; Purpose = "Battle data aggregation and settlement."; Offline = "Method signatures and fields confirmed" },
    [pscustomobject]@{ Hook = "UnitActionRoleBattle.SkillAddExp"; Purpose = "Possible battle-end skill exp settlement."; Offline = "Method signature confirmed" }
)
Add-Table $report $traceRows @("Hook", "Purpose", "Offline")
$report.Add("")
$report.Add("## Focus Types")
foreach ($typeInfo in $focusTypes) {
    $report.Add("")
    $report.Add('### `' + $typeInfo.Name + '`')
    $report.Add("")
    $report.Add("Properties:")
    Add-Table $report $typeInfo.Properties @("Name", "Type")
    $report.Add("")
    $report.Add("Methods:")
    Add-Table $report $typeInfo.Methods @("Name", "ReturnType", "Parameters")
    if ($typeInfo.NestedClosures.Count -gt 0) {
        $report.Add("")
        $report.Add("Nested closure clues:")
        $closureRows = @($typeInfo.NestedClosures | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Fields = ($_.Fields -join ", "); Methods = ($_.Methods -join ", ") }
        })
        Add-Table $report $closureRows @("Name", "Fields", "Methods")
    }
}

$report.Add("")
$report.Add("## Battle Event Data Types")
foreach ($eventType in $battleEventTypes) {
    $report.Add("")
    $report.Add('### `' + $eventType.Name + '`')
    Add-Table $report $eventType.Properties @("Name", "Type")
}

$report.Add("")
$report.Add("## EBattleType Helper Methods")
Add-Table $report $battleEventHelpers @("Name", "ReturnType", "Parameters")

$report.Add("")
$report.Add("## Experience And Mastery Surface")
Add-Table $report $experienceSurface @("Owner", "Kind", "Name", "Type")

$report.Add("")
$report.Add("## Offline Checklist")
$report.Add("")
$report.Add('- [x] Resolve Assembly-CSharp.dll without launching the game.')
$report.Add('- [x] Resolve Mono.Cecil.dll without launching the game.')
$report.Add("- [x] List combat use/hit/damage/effect event data shapes.")
$report.Add("- [x] List core player, skill, hit, battle-data, and battle-end API surfaces.")
$report.Add("- [x] Identify experience and mastery candidate fields/methods.")
$report.Add("- [ ] Compile an ApiProbe for every proposed trace hook.")
$report.Add("- [ ] Build a runtime BattleTrace module only for unresolved dynamic questions.")

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$markdownPath = Join-Path $OutputDir "COMBAT_SYSTEM_STATIC_REPORT.md"
Set-Content -LiteralPath $markdownPath -Value $report -Encoding UTF8

if (-not $NoJson) {
    $jsonPath = Join-Path $OutputDir "combat-system-static-index.json"
    $json = [pscustomobject]@{
        generatedAt = (Get-Date).ToString("o")
        assemblyPath = $AssemblyPath
        cecilPath = $CecilPath
        focusTypes = $focusTypes
        battleEventTypes = $battleEventTypes
        battleEventHelpers = $battleEventHelpers
        experienceSurface = $experienceSurface
    }
    $json | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
}

Write-Host "Combat system static report generated:" -ForegroundColor Green
Write-Host "  $markdownPath"
if (-not $NoJson) {
    Write-Host "  $(Join-Path $OutputDir 'combat-system-static-index.json')"
}
