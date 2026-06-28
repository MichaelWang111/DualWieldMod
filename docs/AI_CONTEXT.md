# AI Context

## Project

DualWieldMod is a Guigubahuang / Tale of Immortal MOD project evolving an existing decompiled dual-wield DLL into a fuller combat subsystem.

The repo tracks documentation, a clean `src/` source overlay, helper tools, and compile probes. Human-authored idea notes live under ignored `ideas/`. Local official tutorials, copied MelonLoader files, decompiled samples, external DLLs, and other heavy research resources live under ignored `resource/`. Generated indexes/decompilation output live under ignored `generated/`.

## Current Git State

- Remote: `git@github.com:MichaelWang111/DualWieldMod.git`
- Branch: `master`
- `.gitignore` ignores `ideas/`, `resource/`, `generated/`, build outputs, copied refs, DLL/PDB/cache artifacts, and `.csproj.user` files.
- Allowed tracked areas: `.gitignore`, `dual_wield_mod_skill.md`, `docs/`, `src/`, `tools/`, and `test/`.
- The real game-generated project under `D:\Games\mods\guigubahuang\ModProject_h6Zv8g` is a build/debug target, not a Git source tree.
- Code-bearing rounds must follow `docs/FLYWHEEL.md`: implement, compile the real MOD project, report expected behavior, wait for user in-game testing, record feedback, then iterate.
- Per-round history lives in `docs/FLYWHEEL_LOG.md`; runtime behavior rounds should bind one or more `DWT-###` cases from `docs/SERIAL_TEST_PLAN.md`.

## Key Docs

- `docs/DUAL_WIELD_DESIGN_MVP.md`: current gameplay/design/MVP spec.
- `docs/WHEEL_DESIGN.md`: prebattle wheel setup UI plus combat Q wheel architecture.
- `docs/DATA_FIELD_RESEARCH.md`: confirmed/candidate/unknown data fields and API evidence.
- `docs/MOD_QA_TUTORIAL_INDEX.md`: direct `.docx` tutorial index from `ideas/modQ&A`.
- `docs/DEVELOPMENT_WORKFLOW.md`: source overlay, sync/build, compile-probe, and runtime smoke-test runbook.
- `docs/COMBAT_SYSTEM_INSPECTION_PLAN.md`: CHM, Cecil, dnSpy, ApiProbe, and runtime trace workflow for battle-system investigation.
- `docs/API_TOOLCHAIN_TEST_PLAN.md`: `AIT` offline toolchain capability tests.
- `docs/KEY_EVIDENCE_PROBE_PLAN.md`: `KEP` combat-kernel questions that must use AIT-proven tools before opening broad runtime DWT probes.
- `docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md`: official corpus scan for dual-wield feasibility, available symbols, excluded false positives, and KEP implications.
- `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`: `AIT-007` focused system DLL parsing results and static/dynamic evidence map.
- `docs/FLYWHEEL.md`: required delivery protocol and record template.
- `docs/FLYWHEEL_LOG.md`: historical Flywheel round records.
- `docs/SERIAL_TEST_PLAN.md`: stable serial runtime tests from `DWT-001` upward.
- `docs/AI_CONTEXT.md`: compact context snapshot.
- `dual_wield_mod_skill.md`: project-local agent workflow and upload guardrails.

## Important Source Material

- `resource/Mod解包结果/MOD_Addk03`: decompiled dual-wield seed implementation.
- `resource/Mod解包结果/MOD_nXbfml`: decompiled official/example API code.
- `resource/modQ&A`: official MOD tutorials, config tables, resources, examples, and API material.
- `resource/app`: local copied game app/runtime root for offline inspection. It contains root native modules (`GameAssembly.dll`, `global-metadata.dat`, `UnityPlayer.dll`, etc.) plus `MelonLoader/` managed wrappers, loader DLLs, and dependencies.
- `ideas/`: human-authored design notes only.
- `src/ModCode/ModMain/`: clean source overlay for intentional MOD code changes.
- `tools/sync-src-to-game.ps1`: copies the overlay into the real MOD project and can build it.
  - `-Build` defaults to `Release`; runtime testing succeeded with `bin\Release\MOD_h6Zv8g.dll`.
- `tools/index-ggbh-api-chm.ps1`: decompiles official `GGBH_API.chm` with `hh.exe` and writes a local searchable index under ignored `generated/`.
- `tools/inspect-combat-system.ps1`: Cecil-based offline combat surface report.
- `tools/export-dnspy-types.ps1`: focused dnSpy/Cpp2IL type export; use `dotnet dnSpy.Console.dll`, not `dnSpy.Console.exe`.
- `tools/decompile-dotnet-assembly.ps1`: AIT dnSpy wrapper for focused type/member export or full managed assembly export, including a generated namespace/type manifest.
- `tools/inventory-dotnet-assemblies.ps1`: Cecil assembly census for managed/native classification, references, type/method/field counts, and method-body coverage.
- `tools/batch-decompile-managed-assemblies.ps1`: batch dnSpy source export for managed DLL directories, with managed/native filtering, incremental reruns, `SOURCE_INDEX.md`, and `source-roots.txt`.
- `tools/build-dnspy-corpus.ps1`: builds the local `generated/app/` corpus; `-SourceKind` supports `official`, `community`, and `unclassified`.
- `D:\Games\tools\解包\Il2CppDumper-win-v6.7.46`: external IL2CPP native dump tool. Current output lives under ignored `generated/app/official/game-root/decompiled/Il2CppDumper_output/`.
- Pending community batch sources, recorded but not processed: `D:\Games\Steam\steamapps\common\鬼谷八荒\ModExportData` and `D:\Games\Steam\steamapps\workshop\content\1468810`.
- `tools/index-resource-knowledge.ps1`: local searchable index over `resource/modQ&A`, decompiled text directories, and generated CHM summaries.
- `test/ApiProbe`: compile-only API surface probe for uncertain game-kernel symbols.

## Existing Decompiled Behavior

`MOD_Addk03` proves a player-side secondary normal attack can work at MOD level.

Current project runtime proof: `FW-20260627-01` and `FW-20260627-02` confirmed in game that `EBattleType.BattleStart` fires, a minimal offhand `SkillAttack` can initialize from the current normal attack, and `SkillAttack.Create(...)` produces a visible second sword/projectile. These map to accepted serial tests `DWT-001`, `DWT-002`, and `DWT-003`. User screenshots showed `[DualWieldMod] Offhand fired` counts 1 and 2 with `skillId=IIER7Z`, `baseId=11452`.

Current runtime state: `FW-20260627-05` / `DWT-004` is accepted. Offhand no longer fires autonomously; it fires only during normal attack input via `Input.GetKey(g.data.globle.key.battleSkill1)`. User confirmed overlapping second projectile and second damage instance in game.

Current runtime state: `FW-20260627-13` is accepted. The PlayerInfo offhand button writes `offhandSkillId`, save/reload works, battle start can use `source=saved`, setting current main as offhand is accepted, and the user observed independent main/offhand cooldowns. FW-11 is accepted: empty offhand stays empty and no implicit double hit occurs. FW-13 adds a Harmony prefix on all `WorldBattleMgr.IntoBattle` overloads through `WorldBattleLoadoutPatch`, calling `DualWieldLoadoutGuard` before battle initialization; user confirmed the former offhand can become main and be used in the same battle. DWT-005 and DWT-006 are accepted for loadout behavior.

UI evidence and current implementation: decompiled `MOD_Addk03` uses `EGameType.OpenUIEnd`, checks `UIType.PlayerInfo`, gets `UIPlayerInfo`, clones `ui.btnClose.gameObject` under `ui.uiSkill.goSkillLeftRoot`, attaches `Button.onClick`, writes `AKData.aleft = skillLeft`, calls `UnitActionMartialUnequip(1, 0)`, and updates icon/tooltip. `src/ModCode/ModMain/DualWield/OffhandSelectionUiController.cs` follows this pattern by injecting a minimal button near `goSkillLeftRoot`, saving current `skillLeft` through `DualWieldSaveStore`, clearing offhand as a toggle, unequipping main with `UnitActionMartialUnequip((MartialType)1, 0)`, and building hover text from skill name plus localized `BattleSkillAttack.desc`.

Build reporting rule: the real generated project has a known ignored 6-warning baseline for optional template references (`com.unity.multiplayer-hlapi.Runtime`, `DOTweenPro`, `UnityEngine.GridModule`, `UnityEngine.TerrainModule`, `UnityEngine.VRModule`, `UnityEngine.XRModule`). If a build has `0 error` and only these warnings, treat it as passed and do not expand the warnings in routine handoffs.

Observed behavior:

- Stores offhand normal attack id in `AKData.aleft`.
- Saves/loads via `g.data.obj.SetString/GetString`.
- Injects a button into player info skill UI.
- On battle start, validates offhand martial data from `allActionMartial`.
- Creates a `SkillAttack` via `BattleFactory.CreateSkill(2).Cast<SkillAttack>()`.
- Initializes offhand skill with `Global.skleft.Init(playerUnitCtrl, propsSkillData)`.
- On each battle frame, reads normal attack key `g.data.globle.key.battleSkill1` and calls `Global.skleft.Create(...)`.
- Uses `skillLeft` as current main normal attack slot.
- Uses `propsInfoBase.baseID` to compare current/offhand identity and fetch `g.conf.battleSkillAttack` config.

## Core Design

Only normal attacks dual wield.

- Left click / normal attack channel: main normal attack plus optional offhand normal attack.
- Empty offhand means no offhand attack. Never bootstrap/copy current main into offhand on battle start.
- Empty main plus valid saved offhand means promote offhand to main and clear offhand on battle start.
- Right click: unique skill, not offhand attack.
- Movement skill: switchable, not dual wielded.
- Divine skill: switchable, not dual wielded.

Wheel pools:

- Every category can have 0-6 candidate skills.
- Normal attack has main + offhand + 0-6 candidates.
- Unique, movement, and divine have current + 0-6 candidates.
- Non-normal categories should use shared cooldown per category if switching is implemented.

## Skill Trigger Consistency

A skill trigger is correct only when the selected learned instance, runtime visual/damage object, cooldown owner, resource-cost owner, `SkillCreateData` / `MissileShotData` source, hit/effect attribution, experience recipient, and UI/input/action state all point to the same skill or a documented category-specific object derived from it.

For normal attacks this means `SkillAttack` visual/projectile, `SkillAttack` cooldown, `SkillDataAttack.actionMartialData`, and the `ActionMartialData.exp` recipient must agree. DWT-022 proved the current offhand `SkillAttack` is bound to the saved offhand martial data and produces offhand damage, but `SkillAttack.Create(...)` alone does not award native offhand proficiency: `offhandExp`, `runtimeExp`, and `offhandUseAddExp` stayed at `0` while main values changed through native main attacks.

DWT-023 partially worked but is insufficient. Runtime logs showed clean offhand hit attribution for the first offhand hit (`matchesOffhandSkill=True`, `createSoleMatches=True`, `suspiciousMainSkill=False`) and proved the Harmony patch can block `UnitCtrlPlayer.AddSkillMartialExp(actionData)` calls targeting main. However later offhand-bound hits still increased main exp / `mainUseAddExp`, so at least one pending or delayed experience path bypasses that API block.

DWT-024 is currently awaiting game test. It keeps the API block and adds rollback of main `ActionMartialData.exp` plus `UnitCtrlPlayer.martialUseAddExp[mainSkillId]` after offhand-attributed hits. Hit diagnostic logging remains capped, but attribution guarding now continues after the log cap. If a hit is clearly main-attributed, the guard refreshes the main baseline and suppresses rollback briefly so legitimate main hit experience is preserved. It still does not award offhand proficiency.

Runtime category split: normal attacks use `SkillAttack`; movement uses `StepBase`; field/god-eye/immortal/ability systems have their own base classes. Non-normal switching must get category-specific probes.

## Q Wheel Rules

Wheel system split:

- Prebattle setup UI in the player skill screen configures 0-6 normal candidates.
- Combat Q wheel selects from the prepared candidates only.

Normal attack combat wheel:

- Hold `Q`: open wheel and disable/ignore attack input.
- Hover option and release `Q`: replace main normal attack.
- Hold `Q` and left click option: replace offhand normal attack and close wheel.
- If no offhand is selected before battle, Q wheel or the offhand slot must be used before offhand attacks can occur.
- Release `Q` with no hover target: close without change.

## Dual Eligibility

- Dual normal attack should require both selected normal attack techniques to have full individual proficiency.
- If not eligible, selecting a second normal attack replaces main and leaves offhand empty.
- Config thresholds are confirmed in `BattleSkillMastery`; the exact runtime field for a learned skill instance's current mastery is not yet verified.

## Pattern Mastery

Permanent dual mastery is recorded against normalized attack pattern pairs, not concrete skill instance ids.

- MVP pattern key: `attack_<propsInfoBase.baseID>`.
- Future pattern key: alias table mapping multiple `baseID` values to one attack pattern.
- Pair key should be canonicalized, for example sorted `pattern_a|pattern_b`.

Growth sources:

- Combat: offhand fires, both hit in a sync window, both hit same target, both contributed to a kill.
- Cultivation: out-of-combat training for a selected pattern pair.

## Resource Model

Base game attribute keys confirmed from official config:

- `mp` = 灵力.
- `sp` = 念力.
- `energy` = original game 精力.

The MOD should add its own runtime-only battle resource, not reuse `energy` directly:

- Suggested names: `dualCombatStamina`, `dualFocus`, or `combatFocus`.
- Combat stamina resets at battle start in MVP.

Dual wield stage model:

- Stage 0, 70%-100%: stable.
- Stage 1, 40%-70%: offhand delay.
- Stage 2, 20%-40%: extra spirit pressure using `mp` once runtime API is confirmed.
- Stage 3, 5%-20%: random offhand instability.
- Stage 4, 0%-5%: mind power overdraw using `sp`; if depleted, offhand mode locks for the rest of battle.

Stage 3 instability pool:

- Delay.
- Missed trigger.
- Damage decay.
- Trajectory offset.
- Sync failure / extra offhand cooldown.

## Confirmed Config Fields

From official config JSON and table headers:

- `RoleAttributeDesc.attribute = mp/sp/energy`: base attribute keys.
- `BattleSkillAttack.type = 1`: normal attack pool; samples have `mpCost = 0`.
- `BattleSkillAttack.skillID`: links skill entry to `BattleSkillBase.id`.
- `BattleSkillAttack.basType`, `basRequire`, `growExp`: aptitude and growth context.
- `BattleSkillBase`: damage, `missileID`, `shotCD`, `skillEffect`, `skillSub`.
- `BattleMissile`: projectile type/model/speed/range/shot/trail/lifecycle.
- `BattleSkillEffect`: trigger, probability, delay, target, effect id, min CD.
- `BattleSkillSub`: secondary skill trigger, delay, create delay, sub skill id, capacity.
- `BattleSkillMastery`: mastery threshold rows `skill_mastery1` through `skill_mastery12`, columns `grade1` through `grade10`.
- `BattleSkillTrain`: `masteryLevel` and `mastery` training values.
- `ModFunction`: includes `battleSkillTrainUp`, `addAttr`, `setAttr`, `addCurAttrPercent`, `regainAttr`.
- `ModCondition`: includes `skillGrade`, `skillEquip`, and attr comparison conditions.

## Not Yet Confirmed

- Runtime field for a learned skill instance's current proficiency/mastery.
- Correct native-compatible way to award offhand proficiency after a MOD-created offhand attack without duplicate growth. Candidate API: `UnitCtrlPlayer.AddSkillMartialExp(...)`.
- Battle-safe runtime API for current/max `mp` and `sp` read/write.
- Runtime actions for unique/movement/divine skill switching and shared cooldown.
- Complete Q wheel implementation details: hover detection and attack input swallowing.
- Reliable way to tag `UnitHitDynIntHandler` events as offhand damage only.
- Whether changing the direction argument to `SkillAttack.Create(...)` works for every normal attack projectile/trail type.

## API Evidence

AIT/KEP split:

- `AIT` proves offline tool capability: CHM index, Cecil inventory/static scan, dnSpy decompilation, resource indexing, and ApiProbe compile contracts.
- `KEP` uses AIT tools to answer narrow combat questions before opening DWT runtime rounds. First priorities are `KEP-001` skill experience mutation and `KEP-002` hit/effect/lifesteal attribution.
- `DWT` is reserved for real game MOD behavior and in-game runtime testing.
- For ordinary managed DLLs and MelonLoader Mod DLLs, `dotnet dnSpy.Console.dll --no-color -l C# -t <type> <dll>` can export full readable C# function bodies. `SaiLL.dll -> A7T.t7w` is the local capability proof.
- `ApiProbe` is a Roslyn compile validator, not Cecil. Cecil is for static metadata/IL inventory and automatic symbol discovery.
- `SaiLL_human_dnspy` is only a dnSpy capability comparison sample; do not absorb its business logic into project design.
- dnSpy `Token/RVA/File Offset` comments are metadata/method body location annotations. `nBB.xBl(int expression)` patterns in `SaiLL` are string-obfuscation constants, not native machine code.
- `nBB` is `SaiLL`'s helper method, not a game-kernel API. Its value for DualWieldMod is methodological: it shows how an external MOD may hide/read strings, paths, UI names, or environment-derived values through helper methods and embedded resources. Use this as an AIT reference pattern, not as gameplay evidence.
- `AIT-006` can annotate `SaiLL` dnSpy output by resolving `nBB.xBl(...)` into comments in ignored `generated/ait/AIT-006-string-annotations/`.
- `AIT-007` parsed focused combat-system types from both `resource/app/MelonLoader/Managed/Assembly-CSharp.dll` and `resource/app/MelonLoader/Dependencies/Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out/Assembly-CSharp.dll`; output lives under ignored `generated/ait/AIT-007-system-dll-parse/`, with tracked conclusions in `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`.
- AIT-007 confirms static surfaces for `SkillAttack.Create(..., SkillCreateData)`, `SkillDataAttack.actionMartialData`, `SkillCreateData.skillCreateSoleID/mainSkillID/createSkillBase`, `MissileShotData.skillCreateData`, `MartialTool.HitData`, `UnitEffectSkillHpSuck`, `UnitCtrlPlayer.AddSkillMartialExp`, `martialUseAddExp`, `DataUnit.UnitInfoData.AddMartialExpInBattle`, and `UnitActionRoleBattle.SkillAddExp`.
- Managed wrapper output is MOD-callable shape evidence, not original game branch logic. Cpp2IL output is class/signature/offset evidence and often stubbed. Only DWT runtime traces can confirm event order, delayed settlement, and mutation ownership.
- `AIT-008` tested direct `GameAssembly.dll` decompilation. `GameAssembly.dll` is native x64 PE (`Machine=0x8664`, `PE32+`) with an `il2cpp` section and no `.NET`/CLR runtime header (`.NET.VirtualAddress=0`, `.NET.Size=0`). dnSpy Console rejects it as `不是 .NET 文件`.
- Cpp2IL can read `GameAssembly.dll + global-metadata.dat` and generate dummy DLLs; the tested run mapped `139476` method definitions and produced `65` assemblies, but focused dnSpy exports show empty/default method bodies for key combat methods. Treat this as structure/signature evidence, not original C# logic.
- Il2CppDumper output is now available at `generated/app/official/game-root/decompiled/Il2CppDumper_output/`: `dump.cs`, `il2cpp.h`, `script.json`, `stringliteral.json`, and `DummyDll/66` assemblies. It is official native IL2CPP structure evidence from `resource/app/GameAssembly.dll` plus `resource/app/global-metadata.dat`, not original C# branch logic.
- Official dual-wield static scan (`docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md`) found no native offhand/dual-normal-attack feature. `dual/LeftHand/RightHand` hits are Unity/input/socket false positives, not martial dual wield. The official corpus does expose enough surfaces for a MOD-built consistency chain: `SkillAttack`, `SkillDataAttack.actionMartialData`, `SkillCreateData`, `MissileShotData`, `UnitCtrlBase.skills/allSkills`, `UnitCtrlPlayer.CreateSkillAttack`, `DataUnit.UnitInfoData` learned martial APIs, `AddSkillMartialExp`/`martialUseAddExp`, `OneUnitUseSkillAttack`, `OneUnitHitSkill`, `UnitHitDynIntHandler`, `UnitEffectSkillHpSuck`, `UnitDataBase`/`WorldUnitDynData` mp/sp fields, and PlayerInfo/input UI classes.
- Correction: that official scan is a symbol/field/event surface scan, not a complete C# method-body call-chain analysis. `game-root` direct dnSpy output is native/unreadable except Il2CppDumper metadata; `generated/app/official/MelonLoader/Managed/decompiled/source/Assembly-CSharp` is Unhollower wrapper code around `IL2CPP.il2cpp_runtime_invoke(...)`; `MelonLoader/Dependencies/...cpp2il_out_Assembly-CSharp` is mostly Cpp2IL stub structure. These are valuable for API/hook design and xref hints, but not original battle-kernel function bodies.
- `AIT-009` generated a high-value ignored MelonLoader managed source corpus at `generated/ait/AIT-009-melonloader-managed-source/`: `28` managed DLLs, `4575` C# files, `5069` types, `0` failures. It includes MelonLoader, Harmony, Cecil, MonoMod.RuntimeDetour, UnhollowerBaseLib/RuntimeLib, Cpp2IL.Core, LibCpp2IL, AsmResolver, and related support libraries.
- Use `rg` against that corpus for loader/toolchain questions, for example `rg -n "PatchAll|HarmonyPatch" generated/ait/AIT-009-melonloader-managed-source` or `rg -n "RegisterTypeInIl2Cpp|UnhollowerSupport" generated/ait/AIT-009-melonloader-managed-source`.
- `AIT-010` upgraded `tools/batch-decompile-managed-assemblies.ps1` with `-Parallel` and `-ThrottleLimit`, then generated a full ignored source corpus for `D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed` at `generated/ait/AIT-010-managed-source/`.
- `AIT-010` current totals: `206` DLLs considered, `205` managed DLLs, `1` native/unreadable skipped, `40361` C# files, `58292` types. `Assembly-CSharp.dll` succeeded with `7960` wrapper C# files and `15035` types. `20` UnityEngine module wrappers are `manifest-missing`; they are not blocking for current combat/API work.
- Historical `AIT-010` remains useful, but the canonical wrapper/API search path is now `generated/app/official/MelonLoader/Managed/decompiled/source`, regenerated from `resource/app/MelonLoader/Managed` with `206` DLLs considered, `205` managed DLLs, `1` native/unreadable skipped, `41380` C# files, `60751` types, and `0` dnSpy failures.
- `AIT-011` created the canonical ignored dnSpy corpus at `generated/app/`, split into `official/` for game/MelonLoader surfaces and `community/` for external MOD samples. Start from `docs/OFFLINE_CORPUS_WORKFLOW.md` and `generated/app/CORPUS_INDEX.md` for future source searches.
- `AIT-011` official corpus includes `game-root`, canonical `MelonLoader/Managed`, `MelonLoader/Dependencies` (`169` DLLs, `164` managed, `19686` C# files), and `MelonLoader/root` (`11` managed DLLs, `1294` C# files). Community corpus includes `SaiLL`, managed deps, native failure records, and `nBB.xBl(...)` string-cache annotations (`1346/1346` decoded).
- `AIT-015` checked whether Managed content was accidentally written to Dependencies. Conclusion: no. `Dependencies` contains Cpp2IL `cpp2il_out_*` outputs that naturally resemble Managed wrapper assembly names; canonical `Managed` had been empty/stale and was regenerated to `generated/app/official/MelonLoader/Managed/decompiled/source`. Method-body classification is recorded locally at `generated/app/official/MelonLoader/METHOD_BODY_QUALITY_REPORT.md`.
- `AIT-012` expanded SaiLL community annotation to dependency DLLs. `AI\ChatGuiGuLocal.dll` uses package-local `qMY.cMj.FMl(...)` string obfuscation, not `KBR.nBB.xBl(...)`. Because this dependency targets `net8.0`, `tools/annotate-obfuscated-strings.ps1 -UseDotnetHost` calls `tools/StringDecoderHost` to decode it under a modern .NET runtime. Current dependency result: `158/158` `cMj.FMl(...)` calls decoded, copied back into `generated/app/community/SaiLL/decompiled/deps/AI_ChatGuiGuLocal/ChatGuiGuLocal`, with cache entries merged into `annotations/string-cache.json`.
- `AIT-013` migrated generated output from `docs/generated/` to root `generated/`; `docs/generated/` was removed after verification. `.gitignore` still ignores both `generated/` and historical `docs/generated/`.
- `AIT-013` adds `generated/app/community/ChatGuigu/`: `ChatGuigu.dll` decompiled to `46` C# files, `23` namespaces, `60` types. Its package-local decoder is `WS3.eSA.UDi(...)`; annotation report decoded `2205` calls with `0` errors, and browsable main source has `1726/1726` `eSA.UDi(...)` lines annotated. Treat it as community MOD sample code only.
- `AIT-013` originally added `GGBH_MOD`; it is now promoted to `generated/app/official/GGBH_MOD/` as `official/loader-bridge`. It writes `MelonLoader/GGBH_MOD_LOAD_COMPLETE.txt`, patches `EventsMgr.Init`, registers `GameCMDMelonLoader`, handles `LoadDll` / `InitModMain`, calls `MelonHandler.LoadFromFile(...)`, and reflects `<namespace>.ModMain.Init()` / `Destroy()`.

Offline official API source:

- `D:\Games\Steam\steamapps\common\鬼谷八荒\Mod\modFQA\代码编写教程\GGBH_API.chm` decompiles with `hh.exe -decompile` and contains about 110k Sandcastle HTML/index files for `Assembly-CSharp`.
- The CHM index confirms symbol pages for current combat investigation targets: `AddSkillMartialExp`, `martialUseAddExp`, `AddMartialExpInBattle`, `SkillAddExp`, `UnitHitDynIntHandler`, `UnitEffectSkillHpSuck`, `OneUnitHitSkill`, `OneUnitUseSkillAttack`, `SkillCreateData`, `MissileShotData`, and `SkillDataAttack.actionMartialData`.
- CHM/Cecil/dnSpy evidence confirms names and signatures, not event order or state mutation. Use ApiProbe and DWT runtime traces for behavior.

Runtime-tested in this project:

- Release build handoff via `tools/sync-src-to-game.ps1 -Apply -Build` loads in game.
- `EBattleType.BattleStart` is received by `OffhandController`.
- `SceneType.battle.timer.Frame(...)` can drive battle-frame offhand attempts.
- `BattleFactory.CreateSkill(2).Cast<SkillAttack>()`, `SkillAttack.Init(...)`, `SkillAttack.IsCreate(...)`, and `SkillAttack.Create(...)` can create a visible extra normal attack.

Official/decompiled examples show:

- `ModMain.Init()` and `Destroy()` lifecycle.
- Harmony patching via `HarmonyLib.Harmony(...).PatchAll(Assembly.GetExecutingAssembly())`.
- `g.timer.Frame`, `g.timer.Time`, `g.timer.Stop`.
- `g.events.On/Off` with `EGameType`, `EMapType`, `EBattleType`.
- `EGameType.IntoWorld`, `OpenUIEnd`, `SaveData`.
- `EBattleType.BattleStart`, `BattleEnd`, `UnitHitDynIntHandler`.
- `SceneType.battle.battleMap.playerUnitCtrl`.
- `SceneType.battle.unit.CreateUnitHuman/CreateUnitMonst` and `playerUnitCtrl.AddEffect(...)`.
- `g.ui.OpenUI`, `g.ui.GetUI<T>`, `g.ui.CloseUI`, `UITipItem.AddTip`.
- Unity UI cloning, `Button.onClick`, image sprite replacement, `UISkyTipEffect` tooltip setup.
- Unity `Input.GetKey/GetKeyDown` and `KeyCode` polling.
- `g.res.Load<T>()`, `g.sounds.PlayEffect()`.
- `g.conf` config access, including `g.conf.battleSkillAttack.GetItem(baseID)`.
- `g.data.obj` MOD persistence.
- `UnitActionMartialEquip` / `UnitActionMartialUnequip`.

## Next Work

Recommended implementation order follows `docs/SERIAL_TEST_PLAN.md`:

1. Treat `AIT-001` through `AIT-013` as established. Use `generated/app/` as the canonical local corpus: `official` for API/loader/native structure, `community` for MOD examples, and `unclassified` only for unsettled provenance.
2. Run `KEP-001` to map the skill experience mutation chain and decide the smallest DWT runtime trace for experience.
3. Run `KEP-002` to map hit/effect/lifesteal attribution and decide the smallest DWT runtime trace for passive leakage.
4. Run `KEP-003` before implementing combat wheel runtime switching, because switching must preserve skill object, cooldown, cost, hit/effect attribution, and proficiency ownership.
5. Only then open the next DWT gameplay/runtime round, using the KEP hook list instead of broad exploratory logging.
6. After experience and attribution are isolated, resume `DWT-021` prebattle normal wheel candidate setup, `DWT-008` combat Q wheel shell, and `DWT-009` / `DWT-010` switching.

