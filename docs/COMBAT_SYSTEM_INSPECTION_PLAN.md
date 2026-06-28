# Combat System Inspection Plan

## Purpose

This document defines the repeatable inspection workflow for the game's battle system. The goal is to stop hand-reading decompiled code whenever possible and replace it with reproducible evidence.

Battle-system investigation now uses three named tracks:

- `AIT`: validate the offline toolchain itself.
- `KEP`: use the validated toolchain to answer key evidence questions.
- `DWT`: run actual gameplay/MOD behavior tests in the real game.

The workflow deliberately separates three evidence levels:

- Offline static inspection: no game launch, no MOD load, no manual play.
- Compile-only probe: no game launch, but verifies that candidate hooks/API calls compile against the game assemblies.
- Runtime trace: the only level that can prove event order, mutations, and battle-time side effects.

## Fully Offline Checklist

These steps do not require the game process.

1. Decompile and index the official CHM API library.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\index-ggbh-api-chm.ps1
```

Outputs:

- `generated/GGBH_API_chm/`
- `generated/GGBH_API_CHM_INDEX.md`
- `generated/ggbh-api-chm-index.json`

This is the fastest way to find official documented type/member names such as `AddSkillMartialExp`, `UnitHitDynIntHandler`, `SkillCreateData`, and `UnitEffectSkillHpSuck`. The CHM is symbol evidence only; it does not prove runtime behavior.

2. Generate the static combat report.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\inspect-combat-system.ps1
```

Outputs:

- `generated/COMBAT_SYSTEM_STATIC_REPORT.md`
- `generated/combat-system-static-index.json`

3. Export readable dnSpy/Cpp2IL type stubs for focused review.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export-dnspy-types.ps1
```

Outputs:

- `generated/dnspy-types/*.cs`
- `generated/dnspy-types/manifest.json`

Notes:

- Use `dotnet <dnSpyRoot>/bin/dnSpy.Console.dll`; `dnSpy.Console.exe` can fail in non-interactive captured terminals because it tries to set console output encoding.
- For ordinary managed DLLs and MelonLoader Mod DLLs, dnSpy can export readable C# function bodies. Use `tools/decompile-dotnet-assembly.ps1` for focused type/member export or full assembly export.
- For IL2CPP game assemblies, do not assume a complete original function body exists. `MelonLoader/Managed/Assembly-CSharp.dll` is often an interop wrapper; `Cpp2IL/cpp2il_out/Assembly-CSharp.dll` can provide structure and stubs. Check Cecil body coverage before treating dnSpy output as logic evidence.
- The default export uses `Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out/Assembly-CSharp.dll`, which is useful for Cpp2IL tokens, RVAs, field offsets, and class structure.
- Pass `-UseManagedAssembly` to export from `MelonLoader/Managed/Assembly-CSharp.dll`; that view is useful for IL2CPP wrapper metadata such as `CallerCount` and `CachedScanResults`.

4. Review the generated material in this order:

- `API_TOOLCHAIN_TEST_PLAN.md` AIT acceptance results when tool capability is in doubt
- `KEY_EVIDENCE_PROBE_PLAN.md` for current KEP question scope
- `GGBH_API_CHM_INDEX.md` term summary for official symbols
- `High-Value Offline Findings`
- `Recommended Runtime Trace Hooks`
- `Focus Types`
- `Battle Event Data Types`
- `Experience And Mastery Surface`

5. Treat offline findings as symbol evidence only. They confirm that a type, field, method, or event data shape exists; they do not prove behavior.

## Compile-Only Checklist

These steps still do not launch the game.

1. Run the existing API surface probe.

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1
```

2. Add compile coverage before adding a runtime hook for any newly discovered symbol.

Current priority compile targets:

- `EBattleType.OneUnitUseSkillAttackFront`
- `EBattleType.OneUnitUseSkillAttack`
- `EBattleType.OneUnitHitSkillFront`
- `EBattleType.OneUnitHitSkill`
- `EBattleType.UnitHit`
- `EBattleType.UnitEffectSkillHpSuck`
- `UnitCtrlPlayer.OnUnitHit`
- `BattleDataMgr.OnUnitHit`
- `BattleDataMgr.OnBattleEndCall`
- `UnitActionRoleBattle.SkillAddExp`
- `DataUnit.UnitInfoData.AddMartialExpInBattle`
- `DataUnit.UnitInfoData.AddMartialExp`
- `DataUnit.UnitInfoData.GetMartialAddExpRate`

Before adding a new compile target, export the type with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export-dnspy-types.ps1 -TypeName UnitCtrlPlayer,BattleDataMgr
```

## Runtime Trace Checklist

These steps require the real game. Keep them minimal and targeted.

Use runtime tracing only after offline and compile-only evidence cannot answer the question.

Recommended DWT-025 trace hooks:

| Hook | Why it matters |
| --- | --- |
| `OneUnitUseSkillAttackFront` / `OneUnitUseSkillAttack` | Skill use start and `SkillCreateData` identity. |
| `OneUnitHitSkillFront` / `OneUnitHitSkill` / `UnitHit` | Hit attribution before and after damage. |
| `UnitHitDynIntHandler` | Damage mutation window and current `HitData`. |
| `UnitEffectSkillHpSuck` | Blade lifesteal attribution. |
| `UnitCtrlPlayer.AddSkillMartialExp(...)` | Direct visible exp API. |
| `UnitCtrlPlayer.OnUnitHit` | Likely player-side hit aggregation. |
| `BattleDataMgr.OnUnitHit` | Battle statistics and exp tracking. |
| `UnitActionRoleBattle.SkillAddExp` | Possible battle-end skill exp settlement. |
| `DataUnit.UnitInfoData.AddMartialExpInBattle` | Candidate lower-level in-battle exp mutation. |
| `DataUnit.UnitInfoData.AddMartialExp` | Candidate lower-level exp mutation. |

## Current Offline Findings

AIT-001 confirms the local dnSpy flow can reproduce a full managed function body from `resource/Mod解包结果/SaiLL.dll` for `A7T.t7w`. This validates dnSpy as a real decompiler for managed MOD DLLs. It does not imply that IL2CPP game wrapper assemblies contain the original game logic body.

The official `GGBH_API.chm` decompiled successfully through `hh.exe -decompile` into about 110k local files. Its sitemap indexes contain the combat and proficiency symbols needed for the current investigation, including `UnitCtrlPlayer.AddSkillMartialExp`, `UnitCtrlPlayer.martialUseAddExp`, `DataUnit.UnitInfoData.AddMartialExpInBattle`, `UnitActionRoleBattle.SkillAddExp`, `EBattleType.UnitHitDynIntHandler`, `EBattleType.OneUnitHitSkill`, `EBattleType.OneUnitUseSkillAttack`, `EBattleType.UnitEffectSkillHpSuck`, `SkillCreateData`, `MissileShotData`, and `SkillDataAttack.actionMartialData`.

The static report currently identifies these high-value surfaces:

- `UnitCtrlPlayer.martialUseAddExp`: battle-time pending skill use exp dictionary.
- `UnitCtrlPlayer.AddSkillMartialExp(...)`: direct skill exp API candidates.
- `BattleDataMgr.allMartialOldExp`: battle-start learned-skill exp snapshots.
- `BattleDataMgr.allUpLevelMartial`: skills that leveled during battle.
- `BattleDataMgr.startSkillLeftMastery` / `startSkillRightMastery`: battle-start mastery fields.
- `UnitActionRoleBattle.SkillAddExp(WorldUnitBase)`: likely battle-end or action-level settlement point.
- `DataUnit.UnitInfoData.AddMartialExpInBattle`: likely lower-level in-battle exp mutation point.
- `DataUnit.UnitInfoData.AddMartialExp`: likely lower-level general exp mutation point.
- `EBattleTypeData.UnitEffectSkillHpSuck`: lifesteal attribution event data.

The dnSpy export currently confirms readable stubs for:

- `UnitCtrlPlayer`
- `BattleDataMgr`
- `UnitActionRoleBattle`
- `SkillAttack`
- `SkillBase`
- `SkillDataAttack`
- `MartialTool`
- `DataUnit` including nested `UnitInfoData`

AIT-007 focused system DLL parsing adds a static/dynamic comparison layer in `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`. It exported the key combat types from both `MelonLoader/Managed/Assembly-CSharp.dll` and `Cpp2IL/cpp2il_out/Assembly-CSharp.dll` into ignored `generated/ait/AIT-007-system-dll-parse/`.

High-value AIT-007 confirmations:

- `SkillAttack.Create(...)` accepts `SkillCreateData`, and `SkillBase.Create(...)` has the same attribution parameter.
- `SkillDataAttack.actionMartialData` exists as the learned-skill binding on normal attack data.
- `SkillCreateData` contains `skillCreateSoleID`, `mainSkillID`, `valueData`, `createSkillBase`, `wings`, `isIngoreShotPosi`, and `isImmortalSkill`.
- `MissileShotData.skillCreateData` carries creation attribution into projectile data.
- `MartialTool.HitData` carries `skillCreateData`, `weaponType`, `magicType`, `hitValue`, `skillBase`, and `basCoefficient`.
- `UnitEffectSkillHpSuck` carries `unit`, `createSkillBase`, `hitData`, and `hpSuck`, making lifesteal attribution traceable.
- `DataUnit.UnitInfoData` exposes `AddMartialExpInBattle`, `AddMartialExp`, and `GetMartialAddExpRate`; `UnitCtrlPlayer` exposes `AddSkillMartialExp(...)` overloads and `martialUseAddExp`.

Interpretation boundary: the Managed assembly is IL2CPP wrapper evidence and Cpp2IL is structure/stub evidence. They are excellent for finding symbols and hook fields, but runtime traces remain necessary for event order, delayed experience settlement, and passive-effect attribution.

## What Cannot Be Fully Offline

These require runtime trace evidence:

- Exact event order from input to projectile to hit to exp.
- Whether `SkillAttack.Create(...)` fires use events for MOD-created skills.
- Whether `UnitCtrlPlayer.OnUnitHit` or `BattleDataMgr.OnUnitHit` mutates `martialUseAddExp`.
- Whether `UnitActionRoleBattle.SkillAddExp` writes final learned-skill exp at battle end.
- Whether `DataUnit.UnitInfoData.AddMartialExpInBattle` is the actual low-level exp writer.
- Whether blade lifesteal is sourced from `HitData.skillBase`, `SkillCreateData.createSkillBase`, equipped main martial effects, or another global effect list.

## Near-Term Decision

Before further guessing at exp fixes, run `KEP-001` and `KEP-002`. If they cannot decide behavior offline/through compile probes, then open DWT-025 as a narrow BattleTrace round with only the hook list produced by KEP.

If DWT-024 succeeds, DWT-025 can still be delayed until the offhand proficiency correction needs lower-level exp writer confirmation, but the KEP evidence map should exist first.
