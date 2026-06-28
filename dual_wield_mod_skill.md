---
name: dual-wield-mod-dev
description: Project-local agent instructions for DualWieldMod. Use when implementing, syncing, building, committing, or uploading the Tale of Immortal / Guigubahuang dual-wield MOD from the clean GitHub repo into the real game-generated MOD project without committing generated files, raw ideas, binaries, caches, or game-project artifacts.
---

# DualWieldMod Agent Skill

Use this file as the project-local skill for agents working on this MOD.

## Paths

- Knowledge/source repo: `D:\WorkSpace\Codex\DualWieldMod`
- Real game MOD project: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject`
- Real code project: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain`
- Game managed refs: `D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed`
- MOD namespace and assembly: `MOD_h6Zv8g`
- Target framework: `.NET Framework 4.7.2`

## Repository Contract

The GitHub repo is the clean source of truth. The game-generated project is a deployment/build target.

Allowed tracked areas:

- `README.md`: project entrypoint.
- `src/`: source overlay that may be synced into the real MOD project.
- `docs/`: design, API research, handoff, AI context.
- `tools/`: deterministic helper scripts.
- `test/`: compile probes and validation harnesses.
- `.gitignore` and this `dual_wield_mod_skill.md`.

Forbidden tracked areas:

- `ideas/`
- `resource/`
- `generated/`
- Anything under `D:\Games\mods\guigubahuang\ModProject_h6Zv8g`
- `bin/`, `obj/`, `refs/`
- `*.dll`, `*.pdb`, `*.cache`, `*.csproj.user`
- Exported MOD packages, game cache files, generated Excel cache, copied game DLLs

## Source Layout

Mirror only real editable source under `src/`:

```text
src/ModCode/ModMain/        -> ModProject/ModCode/ModMain
src/ModExcel/               -> ModProject/ModExcel, only if custom config tables are added
src/ModAssets/              -> ModProject/ModAssets, only if custom non-generated assets are added
```

Do not copy the full game-generated project into `src/`. Do not import template example code unless it is intentionally modified and required.

## Development Workflow

1. Read `docs/AI_CONTEXT.md`, `docs/DATA_FIELD_RESEARCH.md`, `docs/FLYWHEEL.md`, and `docs/SERIAL_TEST_PLAN.md` before implementing.
2. For uncertain game-kernel symbols, first decide the track: `AIT` validates tool capability, `KEP` answers narrow combat evidence questions, and `DWT` changes or traces real gameplay behavior.
3. For AIT/KEP, use the offline tools in this order when relevant: `tools/index-ggbh-api-chm.ps1`, `tools/inventory-dotnet-assemblies.ps1`, `tools/inspect-combat-system.ps1`, `tools/decompile-dotnet-assembly.ps1`, `tools/export-dnspy-types.ps1`, `tools/index-resource-knowledge.ps1`, then `test/ApiProbe`. These write local reproducible output to ignored `generated/`.
4. For code-bearing work, create or update a Flywheel record in `docs/FLYWHEEL_LOG.md` before editing. Bind runtime behavior to one or more `DWT-###` test IDs. The round must end with real project compile results, expected in-game behavior, a user test checklist, and status `Awaiting Game Test` unless blocked.
5. Edit clean source under `src/` first.
6. Dry-run sync:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1
```

7. Apply sync and build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1 -Apply -Build
```

8. If build fails, fix `src/` and sync again. Do not patch generated `bin/obj` outputs.
9. If new API facts are discovered, update `docs/DATA_FIELD_RESEARCH.md` or `docs/AI_CONTEXT.md`.
10. Stop after handoff while runtime status is unverified; the user tests in game and reports feedback for the next Flywheel round.
11. When feedback arrives, update `docs/FLYWHEEL_LOG.md`; update `docs/SERIAL_TEST_PLAN.md` only when a serial test status or evidence changes.

## Upload Workflow

Only upload when the user explicitly asks to commit, push, upload, or send to remote.

Before committing:

```powershell
git status --short
git diff --check
git diff -- README.md .gitignore dual_wield_mod_skill.md docs src tools test
```

Stage only allowed paths:

```powershell
git add README.md .gitignore dual_wield_mod_skill.md docs src tools test
git status --short
git diff --cached --name-only
```

Reject the commit if staged files include forbidden paths or generated artifacts. Then commit and push:

Never stage `resource/` or `generated/`, even when they contain useful local evidence. Record only concise conclusions and reproducible commands in tracked docs.

```powershell
git commit -m "<clear message>"
git push origin master
```

Never run `git add .` unless `.gitignore` and `git status --short` have been reviewed and the result is limited to allowed paths.

## Build Verification

Primary verification is the real generated project:

```powershell
dotnet build "D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\ModMain.csproj" -v:minimal
```

Warnings about unused template references may be acceptable if the build has `0 error` and the touched code does not depend on those missing assemblies.

Ignore the known 6-warning baseline in routine reports when these are the only warnings:

- `com.unity.multiplayer-hlapi.Runtime`
- `DOTweenPro`
- `UnityEngine.GridModule`
- `UnityEngine.TerrainModule`
- `UnityEngine.VRModule`
- `UnityEngine.XRModule`

If the warning set changes or any error appears, report it explicitly.

## Current Known Gaps

Do not claim these APIs are confirmed until a compile or runtime probe proves them:

Offline CHM/Cecil/dnSpy evidence can promote a symbol to candidate, but not to runtime-confirmed behavior.
Managed DLL dnSpy output can include full function bodies; IL2CPP wrapper/stub output still needs Cecil body coverage checks before treating it as logic evidence.

- Learned skill instance current mastery/proficiency field.
- Battle-safe current/max `mp` and `sp` read/write API.
- Q-wheel hover and full attack input swallowing behavior.
- Offhand-only damage attribution inside `UnitHitDynIntHandler`.
- Unique/movement/divine in-combat switching with shared cooldown.
