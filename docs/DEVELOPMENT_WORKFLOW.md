# Development Workflow

This document is the runbook for developing DualWieldMod against the game-generated Guigubahuang MOD project. It defines the repeatable workflow for source edits, compile checks, game-kernel API validation, and runtime smoke testing.

For project iteration and handoff discipline, use `docs/FLYWHEEL.md`. The Flywheel is the required delivery loop for code-bearing rounds: implement, compile the real MOD project, report expected behavior, wait for user in-game testing, record feedback, then iterate.

Low-level reverse-engineering work now uses two pre-DWT tracks:

- `AIT` (`docs/API_TOOLCHAIN_TEST_PLAN.md`): prove offline tool capability for CHM, Cecil, dnSpy, resource indexing, and ApiProbe.
- `KEP` (`docs/KEY_EVIDENCE_PROBE_PLAN.md`): use AIT-proven tools to answer narrow combat evidence questions before opening a runtime DWT trace.

`DWT` remains for real gameplay/MOD behavior tested in game.

Historical round records live in `docs/FLYWHEEL_LOG.md`. Stable runtime test IDs live in `docs/SERIAL_TEST_PLAN.md`; code-bearing rounds should bind one or more `DWT-###` tests unless they are pure diagnostics or compile probes.

## Current Status

Development can proceed.

Last verified locally:

- `test/ApiProbe` compiles against `D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed`; the script also discovers the sibling `MelonLoader` directory for `0Harmony.dll`.
- The real MOD project builds successfully through `tools/sync-src-to-game.ps1 -Apply -Build` with `0 error`.
- The generated project currently emits 6 known optional template-reference warnings. Treat these as the ignored baseline when the warning set is exactly: `com.unity.multiplayer-hlapi.Runtime`, `DOTweenPro`, `UnityEngine.GridModule`, `UnityEngine.TerrainModule`, `UnityEngine.VRModule`, `UnityEngine.XRModule`.

Important paths:

- Clean knowledge/source repo: `D:\WorkSpace\Codex\DualWieldMod`
- Local ignored resource library: `D:\WorkSpace\Codex\DualWieldMod\resource`
- Local ignored generated reports: `D:\WorkSpace\Codex\DualWieldMod\generated`
- Real game-generated MOD project: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject`
- Real code project: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain`
- MOD namespace and assembly: `MOD_h6Zv8g`
- Primary build target: `ModMain.csproj` under the real game-generated project.

The Git repo is the source of truth for intentional work. The game-generated project is the build/debug target. Do not commit the real generated project.

## Source Overlay Model

Editable source is kept under `src/` and synced into the real MOD project only when testing.

```text
src/ModCode/ModMain/ -> ModProject/ModCode/ModMain/
src/ModExcel/        -> ModProject/ModExcel/        optional, only custom config tables
src/ModAssets/       -> ModProject/ModAssets/       optional, only custom assets
```

Use the sync script from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1
```

This is a dry run by default. To write files and build the real project:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1 -Apply -Build
```

The sync script defaults to `Release` when `-Build` is used, because the official game debug flow commonly loads the Release output. Use `-Configuration Debug` only for targeted compile diagnostics.

## Verification Levels

Use the cheapest verification that can answer the current question, then move upward only when needed. In normal development, these verification levels are executed inside a Flywheel round, recorded in `docs/FLYWHEEL_LOG.md`, and tied to `docs/SERIAL_TEST_PLAN.md` when runtime behavior changes.

1. Documentation evidence
   - Read `docs/DATA_FIELD_RESEARCH.md`, `docs/DUAL_WIELD_DESIGN_MVP.md`, `docs/WHEEL_DESIGN.md`, and `docs/MOD_QA_TUTORIAL_INDEX.md`.
   - Treat decompiled code and official examples as evidence, but not as runtime proof.

2. Offline API/library inspection
   - Use `tools/index-ggbh-api-chm.ps1` to decompile and index the official `GGBH_API.chm` into `generated/GGBH_API_chm`.
   - Use `tools/inspect-combat-system.ps1` for a Cecil-based combat surface report.
   - Use `tools/export-dnspy-types.ps1` for focused Cpp2IL/dnSpy type exports.
   - Use `tools/decompile-dotnet-assembly.ps1` for AIT managed DLL decompilation. For ordinary managed DLLs and MelonLoader Mod DLLs it can export readable function bodies, not just type shells.
   - Use `tools/inventory-dotnet-assemblies.ps1` for Cecil assembly census and managed/native/body-coverage classification.
   - Use `tools/index-resource-knowledge.ps1` for local `resource/` search indexes.
   - Generated reports are local and reproducible under `generated/`, which is ignored by Git.
   - This level proves documented symbols, signatures, fields, and useful hook candidates. It still does not prove battle-time behavior.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\index-ggbh-api-chm.ps1
powershell -ExecutionPolicy Bypass -File .\tools\inspect-combat-system.ps1
powershell -ExecutionPolicy Bypass -File .\tools\export-dnspy-types.ps1
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\Mod解包结果\SaiLL.dll -TypeName A7T.t7w -OutputDir .\generated\ait\AIT-001
powershell -ExecutionPolicy Bypass -File .\tools\inventory-dotnet-assemblies.ps1 -Path .\resource\app,.\resource\Mod解包结果\SaiLL.dll -OutputDir .\generated\ait\AIT-003
powershell -ExecutionPolicy Bypass -File .\tools\index-resource-knowledge.ps1
```

3. Compile-only API probe
   - Use `test/ApiProbe` for small API-surface checks that do not need to be a playable MOD.
   - Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1
```

   - With the current local install, this explicit reference command is known-good:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1 -ReferenceDir "D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed"
```

   - A successful compile proves symbols exist in the referenced assemblies. It does not prove the API works safely during battle.

4. Real project compile
   - Sync from `src/` into the real game-generated project and build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1 -Apply -Build
```

   - This builds `bin\Release\MOD_h6Zv8g.dll` unless another configuration is explicitly supplied.
   - Build acceptance baseline: `0 error` and only the 6 known optional template-reference warnings listed under Current Status. Do not expand these warnings in routine handoffs.
   - If the build emits any additional warning, a different warning, or any error, report it and treat the build as needing investigation.

5. In-game debug smoke test
   - Use the MOD editor/game debug path described by the official tutorials: save the project, enter game debug, and load the MOD in the actual game runtime.
   - Codex reports the expected behavior and waits here; the user performs the in-game test and reports feedback.
   - Minimum smoke checks:
     - MOD loads without startup errors.
     - Entering/leaving battle does not crash.
     - Normal attack still works without offhand enabled.
     - Debug logs confirm expected events fire once.
     - Save/load does not corrupt MOD-owned data.

6. Runtime API promotion
   - Promote an API from `Candidate` to `Confirmed` only after compile and runtime evidence match.
   - Update `docs/DATA_FIELD_RESEARCH.md` for detailed evidence and `docs/AI_CONTEXT.md` for compact conclusions.

## Game-Kernel API Development Loop

For any uncertain game-kernel API, use this loop. If the question is about battle internals rather than gameplay delivery, open a KEP first and keep DWT for the later runtime trace.

1. Locate candidate API in official tutorials, config tables, decompiled MOD code, generated CHM index, Cecil report, dnSpy export, or `GGBH_API` references.
2. Write the smallest compile probe or real-project call site that proves the symbol shape.
3. For KEP work, produce a symbol/call graph and minimal runtime hook list before touching gameplay code.
4. For DWT work, keep the implementation behind a narrow wrapper in `src/ModCode/ModMain/`.
5. Sync and build the real MOD project.
6. Add temporary debug logging for runtime behavior if the API affects battle state, UI input, resources, hit events, or persistence.
7. Test in-game through the MOD editor/game debug flow.
8. Record the result in docs before building more behavior on top of it.

## Confirmed Development API Surface

Current evidence is enough to start the normal-attack MVP path.

- Lifecycle: `ModMain.Init()` and `Destroy()`.
- Timers: `g.timer.Frame`, `g.timer.Time`, `g.timer.Stop`; battle frame updates can use `SceneType.battle.timer.Frame(...)`.
- Events: `g.events.On/Off`, including `EGameType.IntoWorld`, `EGameType.OpenUIEnd`, `EGameType.SaveData`, `EBattleType.BattleStart`, `EBattleType.BattleEnd`.
- Persistence: `g.data.obj.SetString/GetString/ContainsKey/DelGroup`.
- Input: Unity `Input.GetKey/GetKeyDown/GetKeyUp`; existing decompiled code reads `g.data.globle.key.battleSkill1` for normal attack.
- Normal attack creation: `BattleFactory.CreateSkill(2).Cast<SkillAttack>()`, `SkillAttack.Init(...)`, `SkillAttack.IsCreate(...)`, `SkillAttack.Create(...)`.
- Learned normal attacks: `g.world.playerUnit.data.unitData.allActionMartial`, current main normal attack `skillLeft`, and skill identity `propsInfoBase.baseID`.
- Config lookup: `g.conf.battleSkillAttack.GetItem(baseID)`.
- Equip actions compile as `UnitActionMartialUnequip(MartialType, int)` and `UnitActionMartialEquip(learnedMartial, int)`. Decompiled integer slot ids may need explicit casts to `MartialType` in current source.
- UI examples: `g.ui.OpenUI`, `g.ui.GetUI<T>`, `OpenUIEnd`, Unity UI cloning, `Button.onClick`, and tooltips.
- Harmony is available, but should be reserved for places where events/timers/UI APIs cannot intercept behavior cleanly.
- Compile probes must reference `UnhollowerBaseLib.dll` in addition to `UnhollowerRuntimeLib.dll` for `Cast<T>()`, IL2CPP event data, and game object wrappers.

## Flywheel Delivery Rules

For code-bearing rounds, the final handoff must include:

- Real project compile result. If the build has `0 error` and only the known 6-warning baseline, say so briefly and do not list all 6 warnings.
- Serial test IDs advanced or rechecked.
- Files changed at a high level.
- Expected in-game behavior.
- Behavior that should not occur.
- A short checklist for the user's runtime test.
- Current Flywheel record status, usually `Awaiting Game Test`.

For docs-only rounds, the final handoff should state that no MOD build was required and record the round as `Docs Only` in `docs/FLYWHEEL_LOG.md`.

## Still Runtime-Unknown

Do not build irreversible design assumptions on these until tested in-game:

- Learned skill instance current mastery/proficiency field.
- Battle-safe current/max `mp` and `sp` read/write API.
- Q-wheel hover detection and complete attack input swallowing.
- Reliable offhand-only damage attribution inside hit events.
- In-combat unique/movement/divine switching and shared cooldown behavior.
- Whether altered direction arguments work uniformly for every normal attack projectile/trail type.

## Recommended Next Implementation Path

1. Finish the AIT toolchain validations in `docs/API_TOOLCHAIN_TEST_PLAN.md`.
2. Run `KEP-001` for the skill experience mutation chain and `KEP-002` for hit/effect/lifesteal attribution.
3. Use the KEP outputs to define a small `DWT-025` runtime trace if offline/compile evidence cannot decide behavior.
4. After attribution and experience pollution are isolated, implement a separate offhand proficiency correction test using the smallest native-compatible experience path.
5. Then resume `DWT-021`: add a MOD-owned normal wheel candidate store, likely `normalWheelPool_v1`, and a compact PlayerInfo candidate setup UI.
6. Verify candidate add/replace/clear, duplicate cleanup, cap at six, and save/load order stability.
7. Only after DWT-021 is accepted, implement DWT-008 Q wheel open/close and input suppression.
8. Promote newly verified fields/APIs into `DATA_FIELD_RESEARCH.md` and compact them into `AI_CONTEXT.md`.

## Git And Upload Guardrails

Allowed tracked areas:

- `README.md`
- `.gitignore`
- `dual_wield_mod_skill.md`
- `docs/`
- `src/`
- `tools/`
- `test/`

Forbidden tracked areas:

- `ideas/`
- `resource/`
- `generated/`
- Anything under `D:\Games\mods\guigubahuang\ModProject_h6Zv8g`
- `bin/`, `obj/`, `refs/`
- `*.dll`, `*.pdb`, `*.cache`, `*.csproj.user`
- Exported MOD packages and copied game DLLs

Before any upload:

```powershell
git status --short
git diff --check
git diff -- README.md .gitignore dual_wield_mod_skill.md docs src tools test
git add README.md .gitignore dual_wield_mod_skill.md docs src tools test
git status --short
git diff --cached --name-only
```

Only commit and push after confirming that staged files are limited to the allowed paths.

