# Key Evidence Probe Plan

## Purpose

`KEP` is the Key Evidence Probe track for DualWieldMod. It sits between `AIT` and `DWT`:

- `AIT` proves the offline tooling works.
- `KEP` uses that tooling to answer narrow game-kernel evidence questions.
- `DWT` implements or traces real MOD behavior in game only after KEP has produced a small, testable hypothesis.

KEP outputs are evidence maps and minimal runtime trace designs. They are not gameplay implementation rounds.

## Evidence Levels

| Level | Meaning | Promotion rule |
| --- | --- | --- |
| `Confirmed Symbol` | A type, field, method, enum value, or config key exists in CHM, Cecil, dnSpy, or official examples. | Enough for research notes, not enough for runtime behavior. |
| `Compile Confirmed` | A minimal ApiProbe or real MOD compile proves candidate C# code can reference the symbol. | Enough to write a guarded runtime probe. |
| `Runtime Confirmed` | In-game DWT logs/screenshots show the event order or mutation actually happens. | Enough to build gameplay behavior on top. |
| `Rejected` | Evidence shows the candidate does not exist, does not compile, or behaves contrary to the hypothesis. | Keep the reason and avoid re-testing without new evidence. |
| `Unknown` | Not enough evidence yet. | Requires more AIT/KEP work or a runtime probe. |

## Standard KEP Workflow

1. State the question in one sentence.
2. List exact symbols, config tables, or decompiled methods to inspect.
3. Run the smallest offline command: CHM index search, Cecil inventory, dnSpy focused export, or resource index search.
4. If a runtime call/hook is likely, add or update a minimal ApiProbe compile sample.
5. Write a candidate chain with confidence labels.
6. Produce the smallest DWT runtime trace checklist only if offline/compile evidence cannot decide behavior.
7. Update `docs/DATA_FIELD_RESEARCH.md` only with reusable conclusions, not large decompiled source blocks.

Generated outputs belong under `generated/` and remain ignored.

Current shared static evidence entry point: `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md` (`AIT-007`) maps the focused system DLL exports to existing DWT observations. Start there before adding new broad decompilation passes.

## KEP-001 - Skill Experience Mutation Chain

Question: when an offhand-created normal attack hits, why does experience not go to the offhand learned skill, and which native path writes main skill experience?

Offline targets:

| Target | Why |
| --- | --- |
| `UnitCtrlPlayer.AddSkillMartialExp` | Direct visible experience API already caught by DWT-023. |
| `UnitCtrlPlayer.martialUseAddExp` | Pending battle-use experience dictionary observed changing in DWT-022. |
| `DataUnit.UnitInfoData.AddMartialExpInBattle` | Candidate lower-level in-battle writer. |
| `DataUnit.UnitInfoData.AddMartialExp` | Candidate general learned-skill writer. |
| `DataUnit.UnitInfoData.GetMartialAddExpRate` | Candidate multiplier source. |
| `UnitActionRoleBattle.SkillAddExp` | Candidate battle-end settlement path. |
| `BattleDataMgr.OnBattleEndCall` | Candidate battle-end aggregation/flush point. |

Offline commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\inspect-combat-system.ps1
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll -TypeName UnitCtrlPlayer,UnitActionRoleBattle,BattleDataMgr,DataUnit -OutputDir .\generated\kep\KEP-001
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL\cpp2il_out\Assembly-CSharp.dll -TypeName UnitCtrlPlayer,UnitActionRoleBattle,BattleDataMgr,DataUnit -OutputDir .\generated\kep\KEP-001-cpp2il
```

ApiProbe requirement:

- Compile references to the AddSkillMartialExp overloads.
- Compile references to `martialUseAddExp`, `ActionMartialData.exp`, and lower-level `DataUnit.UnitInfoData` methods if public/accessible.
- If a method cannot be called but can be Harmony-patched, record that as `Compile Confirmed hook surface`, not direct call surface.

Expected output:

- Candidate mutation graph from `SkillAttack`/hit/use events to pending exp and final learned-skill exp.
- Minimal hook list for DWT-025 if needed.
- Decision on whether offhand proficiency correction should call a native API, mutate learned exp directly, or wait for battle-end settlement.

Entry condition for DWT:

- At least one compile-confirmed hook/call surface for direct exp API or lower-level mutation observation.

## KEP-002 - Hit/Effect/Lifesteal Attribution

Question: why can an offhand sword hit appear to inherit main blade lifesteal/effects, and where does lifesteal read its skill attribution from?

Offline targets:

| Target | Why |
| --- | --- |
| `EBattleType.UnitEffectSkillHpSuck` | Event surface for lifesteal. |
| `EBattleTypeData.UnitEffectSkillHpSuck.createSkillBase` | Candidate skill source for lifesteal. |
| `EBattleTypeData.UnitEffectSkillHpSuck.hitData` | Candidate hit source for lifesteal. |
| `EBattleTypeData.UnitEffectSkillHpSuck.hpSuck` | Lifesteal amount. |
| `OneUnitHitSkill` / `OneUnitHitSkillFront` | Hit attribution before/after damage. |
| `UnitHitDynIntHandler` | Damage mutation and hit context window. |
| `SkillCreateData` | Creation attribution carrier. |
| `MissileShotData` | Projectile attribution carrier. |

Offline commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll -TypeName EBattleTypeData,SkillCreateData,MissileShotData,UnitCtrlPlayer,BattleDataMgr -OutputDir .\generated\kep\KEP-002
powershell -ExecutionPolicy Bypass -File .\tools\inspect-combat-system.ps1
```

ApiProbe requirement:

- Compile event subscriptions for `UnitEffectSkillHpSuck`, `OneUnitHitSkill`, and `UnitHitDynIntHandler`.
- Compile reads of `createSkillBase`, `hitData`, `hpSuck`, `SkillCreateData.createSkillBase`, `SkillCreateData.mainSkillID`, and `MissileShotData.skillCreateData` if accessible.

Expected output:

- Lifesteal attribution field table.
- Minimal DWT-025 log format:
  - event name
  - create skill sole id/base id
  - hit skill id/base id
  - weapon/magic type
  - damage before/after
  - hp suck amount
  - whether source matches offhand runtime create id

Entry condition for DWT:

- Compile-confirmed event subscriptions and readable attribution fields, or a documented rejection that forces a different trace surface.

## KEP-003 - Runtime Skill Object Switching

Question: can combat wheel switching replace the runtime `action/skill` object and preserve visual, cooldown, cost, hit/effect attribution, and experience consistency?

Offline targets:

| Target | Why |
| --- | --- |
| `UnitCtrlPlayer.CreateSkillAttack` | Candidate native rebuild path for normal attacks. |
| `UnitCtrlBase.skills` | Runtime skill list. |
| `UnitCtrlBase.allSkills` | Runtime all-skill collection. |
| `SkillAttack.data` | Runtime normal attack data owner. |
| `SkillDataAttack.actionMartialData` | Learned skill binding and exp owner. |
| `SkillAttack.Init` / `Create` / `IsCreate` | Current offhand creation path and cooldown gate. |

Offline commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll -TypeName UnitCtrlPlayer,UnitCtrlBase,SkillAttack,SkillDataAttack,SkillBase -OutputDir .\generated\kep\KEP-003
powershell -ExecutionPolicy Bypass -File .\tools\inventory-dotnet-assemblies.ps1 -Path .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll,.\resource\app\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL\cpp2il_out\Assembly-CSharp.dll -OutputDir .\generated\kep\KEP-003-inventory
```

ApiProbe requirement:

- Compile access to `CreateSkillAttack(MartialType)` if callable.
- Compile reads of `skills`, `allSkills`, `SkillAttack.data`, and `SkillDataAttack.actionMartialData` if accessible.

Expected output:

- Candidate switching paths:
  - native equip/rebuild before battle
  - runtime rebuild through `CreateSkillAttack`
  - direct `SkillAttack.Init` for offhand-only object
  - rejected path: changing projectile/create data without changing action/cooldown/exp owner
- Consistency checklist for any future wheel DWT.

Entry condition for DWT:

- A compile-confirmed candidate path and a rollback plan if runtime switching fails.

## KEP-004 - Resource Access mp/sp

Question: how can the MOD safely read/write current and max spirit (`mp`) and mind (`sp`) during battle?

Offline targets:

| Target | Why |
| --- | --- |
| `DataUnit.PropertyData` | Candidate attribute storage. |
| Current/max attribute accessors on `DataUnit`, `UnitCtrlPlayer`, or world unit data | Needed for battle stamina/resource stages. |
| `ModFunction.addAttr` | Config/script-side attribute mutation reference. |
| `ModFunction.setAttr` | Config/script-side set reference. |
| `ModFunction.addCurAttrPercent` | Current attribute mutation reference. |
| `ModFunction.regainAttr` | Recovery reference. |

Offline commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll -TypeName DataUnit,UnitCtrlPlayer,UnitCtrlBase,WorldUnitBase -OutputDir .\generated\kep\KEP-004
powershell -ExecutionPolicy Bypass -File .\tools\index-resource-knowledge.ps1 -OutputDir .\generated\kep\KEP-004-resource-index
```

ApiProbe requirement:

- Compile current/max attribute reads for `mp` and `sp` if direct APIs exist.
- Compile a no-op or guarded mutation sample only if the API shape is clear.
- If only `ModFunction` config actions exist, keep runtime C# write path `Unknown`.

Expected output:

- Candidate C# API table for current/max `mp` and `sp`.
- Boundary notes for stage 2/4 resource design.
- Runtime trace checklist for confirming battle-safe reads/writes.

Entry condition for DWT:

- At least current-value reads compile, or resource spending remains deferred.

## Current Priority

Run KEP-001 and KEP-002 before the next gameplay fix to avoid using DWT as a general reverse-engineering container. AIT-007 already provides the focused static map; the immediate KEP work is to compile-confirm the hook/call fields and reduce the next DWT trace to the smallest experience and lifesteal attribution questions. Run KEP-003 before any combat-wheel runtime switching implementation.

