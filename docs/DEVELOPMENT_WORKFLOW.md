# Development Workflow

This document is the runbook for developing DualWieldMod against the game-generated Guigubahuang MOD project. It defines the repeatable workflow for source edits, compile checks, game-kernel API validation, and runtime smoke testing.

For project iteration and handoff discipline, use `docs/FLYWHEEL.md`. The Flywheel is the required delivery loop for code-bearing rounds: implement, compile the real MOD project, report expected behavior, wait for user in-game testing, record feedback, then iterate.

## Current Status

Development can proceed.

Last verified locally:

- `test/ApiProbe` compiles against `D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed`; the script also discovers the sibling `MelonLoader` directory for `0Harmony.dll`.
- The real MOD project builds successfully through `tools/sync-src-to-game.ps1 -Apply -Build` with `0 error`; the remaining warnings are missing optional template references from the generated project.

Important paths:

- Clean knowledge/source repo: `D:\WorkSpace\Codex\DualWieldMod`
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

Use the cheapest verification that can answer the current question, then move upward only when needed. In normal development, these verification levels are executed inside a Flywheel round and recorded in `docs/FLYWHEEL.md`.

1. Documentation evidence
   - Read `docs/DATA_FIELD_RESEARCH.md`, `docs/DUAL_WIELD_DESIGN_MVP.md`, and `docs/MOD_QA_TUTORIAL_INDEX.md`.
   - Treat decompiled code and official examples as evidence, but not as runtime proof.

2. Compile-only API probe
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

3. Real project compile
   - Sync from `src/` into the real game-generated project and build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1 -Apply -Build
```

   - This builds `bin\Release\MOD_h6Zv8g.dll` unless another configuration is explicitly supplied.
   - Template reference warnings are acceptable if there are `0 error` and the changed code does not depend on the missing optional assemblies.

4. In-game debug smoke test
   - Use the MOD editor/game debug path described by the official tutorials: save the project, enter game debug, and load the MOD in the actual game runtime.
   - Codex reports the expected behavior and waits here; the user performs the in-game test and reports feedback.
   - Minimum smoke checks:
     - MOD loads without startup errors.
     - Entering/leaving battle does not crash.
     - Normal attack still works without offhand enabled.
     - Debug logs confirm expected events fire once.
     - Save/load does not corrupt MOD-owned data.

5. Runtime API promotion
   - Promote an API from `Candidate` to `Confirmed` only after compile and runtime evidence match.
   - Update `docs/DATA_FIELD_RESEARCH.md` for detailed evidence and `docs/AI_CONTEXT.md` for compact conclusions.

## Game-Kernel API Development Loop

For any uncertain game-kernel API, use this loop:

1. Locate candidate API in official tutorials, config tables, decompiled MOD code, or `GGBH_API` references.
2. Write the smallest compile probe or real-project call site that proves the symbol shape.
3. Keep the implementation behind a narrow wrapper in `src/ModCode/ModMain/`.
4. Sync and build the real MOD project.
5. Add temporary debug logging for runtime behavior if the API affects battle state, UI input, resources, hit events, or persistence.
6. Test in-game through the MOD editor/game debug flow.
7. Record the result in docs before building more behavior on top of it.

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

- Real project compile result.
- Files changed at a high level.
- Expected in-game behavior.
- Behavior that should not occur.
- A short checklist for the user's runtime test.
- Current Flywheel record status, usually `Awaiting Game Test`.

For docs-only rounds, the final handoff should state that no MOD build was required and record the round as `Docs Only` in `docs/FLYWHEEL.md`.

## Still Runtime-Unknown

Do not build irreversible design assumptions on these until tested in-game:

- Learned skill instance current mastery/proficiency field.
- Battle-safe current/max `mp` and `sp` read/write API.
- Q-wheel hover detection and complete attack input swallowing.
- Reliable offhand-only damage attribution inside hit events.
- In-combat unique/movement/divine switching and shared cooldown behavior.
- Whether altered direction arguments work uniformly for every normal attack projectile/trail type.

## Recommended Next Implementation Path

1. Rebuild the readable equivalent of the existing `MOD_Addk03` normal-attack offhand seed under `src/ModCode/ModMain/`.
   - Open a new Flywheel record before making the code change.
2. Keep default behavior conservative: no offhand fire unless a valid offhand is configured.
3. Add battle start/end initialization, save/load, and frame update wrappers.
4. Add compile-time wrappers around learned skills, main normal attack id, config lookup, and offhand `SkillAttack` creation.
5. Sync/build the real project.
6. Run an in-game smoke test before adding Q wheel, stamina stages, or mastery persistence.
7. Promote newly verified fields/APIs into `DATA_FIELD_RESEARCH.md` and compact them into `AI_CONTEXT.md`.

## Git And Upload Guardrails

Allowed tracked areas:

- `.gitignore`
- `dual_wield_mod_skill.md`
- `docs/`
- `src/`
- `tools/`
- `test/`

Forbidden tracked areas:

- `ideas/`
- Anything under `D:\Games\mods\guigubahuang\ModProject_h6Zv8g`
- `bin/`, `obj/`, `refs/`
- `*.dll`, `*.pdb`, `*.cache`, `*.csproj.user`
- Exported MOD packages and copied game DLLs

Before any upload:

```powershell
git status --short
git diff --check
git diff -- .gitignore dual_wield_mod_skill.md docs src tools test
git add .gitignore dual_wield_mod_skill.md docs src tools test
git status --short
git diff --cached --name-only
```

Only commit and push after confirming that staged files are limited to the allowed paths.
