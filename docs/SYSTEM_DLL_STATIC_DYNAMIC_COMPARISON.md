# System DLL Static/Dynamic Comparison

## Purpose

`AIT-007` validates that the current offline toolchain can parse focused game-system DLL surfaces and turn them into a reusable evidence map for later `KEP` and `DWT` work.

This report deliberately records conclusions and reproducible commands, not large decompiled source blocks. Generated source output remains ignored under `generated/`.

## Verdict

The toolchain is now sufficient for focused offline combat-system inspection:

- Cecil can inventory assemblies, classify managed/native/wrapper/stub outputs, and find candidate types/methods/fields quickly.
- dnSpy can export readable focused type views from both `MelonLoader/Managed/Assembly-CSharp.dll` and `Cpp2IL/cpp2il_out/Assembly-CSharp.dll`.
- Il2CppDumper output can provide native IL2CPP structure, headers, addresses, metadata dumps, dummy DLLs, and string literal tables from `GameAssembly.dll + global-metadata.dat`.
- ApiProbe can then verify whether a candidate call or hook shape compiles in MOD code.
- Runtime `DWT` traces are still required for event order, mutation ownership, delayed settlement, and side effects.

AIT-008 adds one important boundary: direct dnSpy C# decompilation of the native `GameAssembly.dll` is rejected by dnSpy Console with `GameAssembly.dll 不是 .NET 文件`. The PE view can parse headers and sections, and Cpp2IL can generate dummy DLLs from `GameAssembly.dll + global-metadata.dat`, but those dummy DLL method bodies are mostly empty/default stubs. They are structure evidence, not source-level game logic.

Il2CppDumper output is now available under `generated/app/official/game-root/decompiled/Il2CppDumper_output/`. It adds `dump.cs`, `il2cpp.h`, `script.json`, `stringliteral.json`, and `DummyDll/66` assemblies. This improves native/static discovery, but it still does not prove runtime behavior or original C# branch logic.

AIT-010 adds the broad local source corpus for `MelonLoader/Managed`: the full wrapper/API layer, including `Assembly-CSharp.dll`, is now searchable under ignored `generated/ait/AIT-010-managed-source/`. This makes symbol discovery much faster, but the `Assembly-CSharp` files are still IL2CPP wrapper source, not original game branch logic.

In short: static parsing is strong enough to stop blind reverse engineering for the current combat questions, but it does not replace in-game evidence.

## Generated Output

Ignored generated outputs:

- `generated/ait/AIT-007-system-dll-parse/managed/`
- `generated/ait/AIT-007-system-dll-parse/cpp2il/`
- `generated/ait/AIT-010-managed-source/` full `MelonLoader/Managed` wrapper/source-like corpus
- `generated/app/official/game-root/decompiled/Il2CppDumper_output/` native IL2CPP structure dump

Source assemblies:

- Managed wrapper: `resource/app/MelonLoader/Managed/Assembly-CSharp.dll`
- Cpp2IL structure/stub output: `resource/app/MelonLoader/Dependencies/Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out/Assembly-CSharp.dll`
- Native IL2CPP binary tested in AIT-008: `resource/app/GameAssembly.dll` plus `resource/app/global-metadata.dat`

Focused type set exported:

```text
UnitCtrlPlayer
BattleDataMgr
UnitActionRoleBattle
SkillAttack
SkillBase
SkillDataAttack
DataUnit
EBattleTypeData.UnitEffectSkillHpSuck
EBattleTypeData.OneUnitHitSkill
EBattleTypeData.OneUnitUseSkillAttack
EBattleTypeData.UnitHitDynIntHandler
SkillCreateData
MissileShotData
HitData
UnitCtrlBase
WorldUnitBase
DataUnit.UnitInfoData
DataUnit.ActionMartialData
```

Nested selectors `DataUnit.UnitInfoData` and `DataUnit.ActionMartialData` return selector exit code `1` in the focused export, but their actual nested type members are present inside `DataUnit.cs`. Treat this as a dnSpy selector limitation, not missing evidence.

## Reproduction Commands

```powershell
$types = @(
  'UnitCtrlPlayer','BattleDataMgr','UnitActionRoleBattle','SkillAttack','SkillBase','SkillDataAttack','DataUnit',
  'EBattleTypeData.UnitEffectSkillHpSuck','EBattleTypeData.OneUnitHitSkill','EBattleTypeData.OneUnitUseSkillAttack',
  'EBattleTypeData.UnitHitDynIntHandler','SkillCreateData','MissileShotData','HitData','UnitCtrlBase','WorldUnitBase',
  'DataUnit.UnitInfoData','DataUnit.ActionMartialData'
) -join ','

powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 `
  -AssemblyPath .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll `
  -TypeName $types `
  -OutputDir .\generated\ait\AIT-007-system-dll-parse\managed

powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 `
  -AssemblyPath .\resource\app\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL\cpp2il_out\Assembly-CSharp.dll `
  -TypeName $types `
  -OutputDir .\generated\ait\AIT-007-system-dll-parse\cpp2il
```

## Assembly Interpretation

| Source | What it is good for | What it cannot prove |
| --- | --- | --- |
| `MelonLoader/Managed/Assembly-CSharp.dll` | MOD-callable IL2CPP wrapper shape: public/private members, properties, fields, native method tokens, `CallerCount`, `CachedScanResults`, and wrapper signatures. | Original game branch logic, event order, or mutation side effects. Most method bodies invoke native IL2CPP methods. |
| `AIT-010` full `MelonLoader/Managed` corpus | Fast local `rg` search across `205` managed DLLs, including `Assembly-CSharp.dll`, Unity modules, System libraries, and IL2CPP wrapper support assemblies. | Runtime truth and original native game branch logic. Treat `Assembly-CSharp` output as wrapper/API-shape evidence. |
| `Cpp2IL/cpp2il_out/Assembly-CSharp.dll` | Game class structure, fields, signatures, tokens, offsets, and simpler readable stubs. | Complete original logic. Many methods are default/stub bodies. |
| `GameAssembly.dll` direct in dnSpy Console | PE header/section inspection in dnSpy UI or PE parser; confirms native x64 PE and `il2cpp` section. | Direct C# decompilation. This installed dnSpy Console rejects it as `不是 .NET 文件`; `.NET` data directory/CLR runtime header is zero. |
| `Cpp2IL --game-path ... --output-as dummydll` | Uses `GameAssembly.dll + global-metadata.dat` to reconstruct managed type/field/method signatures into dummy DLLs. AIT-008 mapped `139476` method definitions and produced `65` assemblies. | Original C# bodies. Focused exports show empty methods or `return default(...)` for key combat methods such as `AddSkillMartialExp` and `SkillAttack.Create`. |
| `Il2CppDumper_output` | Uses `resource/app/GameAssembly.dll + resource/app/global-metadata.dat` to produce `dump.cs`, `il2cpp.h`, `script.json`, `stringliteral.json`, and `DummyDll/66` assemblies. Good for native IL2CPP structure, offsets, addresses, metadata, and string literal searches. | Original C# bodies or runtime behavior. Treat it as structure/native-analysis evidence only. |
| CHM/API index | Official symbol and member pages. | Runtime behavior. |
| ApiProbe | Whether a MOD can compile against a symbol/call shape. | Runtime behavior. |
| DWT trace | Event order, mutation ownership, delayed settlement, and real gameplay side effects. | Broad static discovery by itself. |

## Static/Dynamic Comparison

| Surface | Static evidence from AIT-007 | Dynamic evidence already observed | Current conclusion | Next probe |
| --- | --- | --- | --- | --- |
| `SkillAttack.Init`, `IsCreate`, `Create` | `SkillAttack` exposes `Init(UnitCtrlBase, PropsSkillData)`, `IsCreate(...)`, and `Create(Vector2, Vector2, Action, Action<MissileShotData>, SkillCreateData)`. | DWT accepted that the offhand attack initializes, fires, creates projectile/visual damage, and can use a 0.05s delay. | Runtime creation is viable for an offhand normal attack object. | Do not infer proficiency or passive attribution from visual damage alone. |
| `SkillAttack.data` and `SkillDataAttack.actionMartialData` | `SkillAttack.data` returns `SkillDataAttack`; `SkillDataAttack` has `actionMartialData`. | DWT-022 showed the runtime offhand binding points to the saved offhand learned skill. | The visual/runtime skill object can be bound to the offhand learned instance. | Trace whether native use/hit events read this same binding for exp. |
| `SkillCreateData` | Fields include `skillCreateSoleID`, `mainSkillID`, `valueData`, `createSkillBase`, `wings`, `isIngoreShotPosi`, and `isImmortalSkill`; constructor accepts `(string skillCreateSoleID, int mainSkillID, BattleSkillValueData valueData)`. | DWT-023 create snapshot showed explicit offhand create data with offhand base id and matching sole id. | `SkillCreateData` is the main attribution carrier from create to projectile/hit/effect. | KEP-002 should log it on use, missile, hit, damage, and lifesteal events. |
| `MissileShotData.skillCreateData` | `MissileShotData` contains `skillCreateData`. | Offhand projectile path exists, but missile event attribution has not been separately traced. | Projectile attribution can probably be carried through `MissileShotData`. | Add compile-confirmed event/log reads before DWT-025 if used. |
| `MartialTool.HitData` | Constructor accepts `(UnitCtrlBase attackUnit, SkillCreateData skillCreateData, int weaponType, int magicType, int hitValue)`. Fields include `skillCreateData`, `weaponType`, `magicType`, `hitValue`, `skillBase`, and `basCoefficient`. | DWT-023 hit attribution showed offhand base `14111`, `weaponType=3`, `magicType=0`, and `suspiciousMainSkill=False` for an early offhand hit. | Hit attribution has multiple independent fields; matching `SkillCreateData` alone is necessary but may not be sufficient. | KEP-002 must compare `hitData.skillCreateData`, `hitData.skillBase`, event `skill`, and lifesteal `createSkillBase`. |
| `EBattleTypeData.OneUnitUseSkillAttack` | Event data contains `SkillAttack skill` and `SkillCreateData skillCreateData`. | Not yet traced directly in DWT logs. | Good earliest event to prove use attribution. | Compile event subscription and field reads. |
| `EBattleTypeData.OneUnitHitSkill` | Event data contains `SkillBase skill`, `UnitCtrlBase hitUnit`, `MartialTool.HitData hitData`, and `BulletBase bullet`. | DWT-023 hit logs already classify offhand hits through nearby hit data. | Good hit-level attribution event. | Use alongside `UnitHitDynIntHandler` to connect attribution to damage mutation. |
| `EBattleTypeData.UnitHitDynIntHandler` | Event data contains `hitData`, `hitUnit`, and `dynV`. | Current rollback guard uses hit/damage classification; DWT-024 awaits game test. | Best current surface for damage decay and exp-pollution rollback windows. | Keep DWT logs narrow; compare before/after damage and exp state. |
| `EBattleTypeData.UnitEffectSkillHpSuck` | Constructor and fields include `unit`, `createSkillBase`, `hitData`, and `hpSuck`. | User observed offhand sword damage may inherit main blade lifesteal, but no dedicated lifesteal event trace exists yet. | Lifesteal attribution is traceable; static evidence points to both `createSkillBase` and `hitData`. | KEP-002 should produce DWT-025 lifesteal log format. |
| `UnitCtrlPlayer.AddSkillMartialExp` | Overloads exist for `(string martialID, int talent, float growExp)` and `(ActionMartialData actionMartialData, int talent, float growExp)`. | DWT-023 proved one `actionData` overload call targeting main can be blocked, but main exp still rose later. | This is one exp path, not the whole chain. | KEP-001 should hook/cross-check lower-level and settlement writers. |
| `UnitCtrlPlayer.martialUseAddExp` | Field exists as `Dictionary<string, float>`. | DWT-022 saw `mainUseAddExp` change while offhand values stayed zero. DWT-024 rolls it back after offhand-attributed hits. | High-value pending-exp state, likely involved before final exp settlement. | Trace writes and battle-end flush behavior. |
| `DataUnit.UnitInfoData` exp methods | `AddMartialExpInBattle(string id, int exp)`, `AddMartialExp(string id, int exp)`, and `GetMartialAddExpRate(ActionMartialData data)` exist inside `DataUnit.cs`. | Not yet directly traced in DWT. | Candidate lower-level learned-skill exp writer and multiplier layer. | ApiProbe/Harmony compile confirmation for KEP-001. |
| `UnitActionRoleBattle.SkillAddExp` and `BattleDataMgr.OnBattleEndCall` | Both methods exist; `BattleDataMgr` also has `OnUnitHit`. | Battle end is observed, but exp settlement chain has not been traced there. | Candidate delayed settlement path for main exp pollution. | Add minimal hook list only if KEP-001 cannot decide from compile/static evidence. |
| `UnitCtrlPlayer.CreateSkillAttack`, `UnitCtrlBase.skills`, `UnitCtrlBase.allSkills` | Normal-attack rebuild and skill-list surfaces exist. | Prebattle promotion to main works; in-combat replacement is not proven. | Candidate route for combat wheel switching, but direct object swapping must preserve cooldown/cost/exp/event attribution. | KEP-003 before any wheel runtime switching implementation. |

## Completeness Assessment

For the current DualWieldMod questions, the toolchain is enough to support a disciplined workflow:

1. Use Cecil/CHM to find candidate symbols.
2. Use dnSpy focused exports to inspect type shape and wrapper/stub evidence.
3. Use ApiProbe to prove the MOD can compile the intended call/hook/read.
4. Use DWT only for the remaining behavior question.

If a question truly needs original native branch logic, add a separate native-analysis spike rather than treating dnSpy PE view, Cpp2IL dummy bodies, or Il2CppDumper output as C# source. That spike should start from `resource/app/GameAssembly.dll`, `resource/app/global-metadata.dat`, Cpp2IL/Il2CppDumper method addresses/tokens, and a native disassembler/decompiler, then still validate the result in game.

This covers the needed API discovery layer for `KEP-001` through `KEP-003`. It does not cover runtime truth by itself. The most important remaining unknowns are:

- Which exact path mutates `martialUseAddExp` and final `ActionMartialData.exp` after offhand-attributed hits.
- Whether lifesteal reads from event `skill`, `hitData.skillBase`, `SkillCreateData.createSkillBase`, equipped main passive lists, or a combination.
- Whether combat-time normal attack replacement can rebuild the native runtime skill object without breaking cooldown, cost, events, and proficiency.

## Next Work

Proceed in this order:

1. `KEP-001`: compile-confirm and map exp mutation surfaces: `AddSkillMartialExp`, `martialUseAddExp`, `AddMartialExpInBattle`, `AddMartialExp`, `SkillAddExp`, and `OnBattleEndCall`.
2. `KEP-002`: compile-confirm hit/effect/lifesteal trace fields and produce the smallest DWT-025 log format.
3. `KEP-003`: test whether `CreateSkillAttack(MartialType)` and skill-list access can support runtime wheel switching.
4. Resume DWT only with a narrow trace or implementation target derived from the KEP result.

