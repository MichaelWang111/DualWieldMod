# DualWieldMod Data Field Research

## Purpose

This document records the current evidence for data fields and MOD APIs needed by the dual-wield combat design. It is based on targeted read-only passes over local official tutorials/configs, decompiled examples, CHM/API indexes, Cecil inventories, dnSpy exports, ApiProbe compile checks, and runtime DWT feedback.

`ideas/` is reserved for human-authored design notes. `resource/` contains local official resources, copied MelonLoader assemblies, decompiled samples, and external DLLs. Both are ignored by Git. Generated reports live under ignored `generated/`. No code implementation is included here.

## Confirmed

| Topic | Confirmed finding | Evidence |
| --- | --- | --- |
| Base attribute keys | `mp` is spirit/lingli, `sp` is mind/nianli, `energy` is original stamina/jingli. | `ideas/modQ&A/配置修改教程/配置（只读）Json格式/RoleAttributeDesc.json`; header: `配置表头/RoleAttributeDesc.xlsx` (`attribute`, `icon`, `desc`). |
| Normal attack config | `BattleSkillAttack.type = 1` is the normal attack pool used for martial/spiritual attack techniques. Samples have `mpCost = 0`, `skillID`, `basType`, `growExp`, and icon/name/desc fields. | `BattleSkillAttack.json`; header `BattleSkillAttack.xlsx`; example `技能配置例子/ModProject/ModExcel/BattleSkillAttack.xlsx`. |
| Skill config chain | Learnable/usable attack entry points go through `BattleSkillAttack.skillID` into `BattleSkillBase.id`; `BattleSkillBase` defines damage, weapon/magic type, `missileID`, `shotCD`, `skillEffect`, and `skillSub`. | `BattleSkillAttack.json`, `BattleSkillBase.json`; `技能配置例子/ModProject/说明.txt`; `BattleSkillBase.xlsx` header. |
| Projectile config | `BattleMissile` controls projectile type/model/size/speed/range/shot/trail/lifecycle/through/resist. `BattleTrailxx` tables control trajectory details. | `BattleMissile.json`; header `BattleMissile.xlsx`; example `BattleMissile.xlsx` and `BattleTrail17.xlsx`. |
| Secondary skill/effect config | `BattleSkillEffect` has `triggerID`, `triggerProb`, `delay`, `target`, `effectID`, `minCD`. `BattleSkillSub` has `delay`, `createSkillDelay`, `skillType`, `subSkillID`, `capacity`, and destroy/chase flags. | `BattleSkillEffect.json`, `BattleSkillSub.json`; headers `BattleSkillEffect.xlsx`, `BattleSkillSub.xlsx`; skill example docs. |
| Skill numeric values | `BattleSkillValue` maps string keys such as `&..._mpCost` or `&..._jnwl` to per-grade values. | `BattleSkillValue.json`; header `BattleSkillValue.xlsx`; example `BattleSkillValue.xlsx`. |
| Individual mastery thresholds | `BattleSkillMastery` defines mastery rows `skill_mastery1` through `skill_mastery12`; each row has `grade1` through `grade10` thresholds. | `BattleSkillMastery.json`; header `BattleSkillMastery.xlsx`. |
| Training mastery gain | `BattleSkillTrain` defines `grade`, `type`, `masteryLevel`, `costItem`, `costNum`, `days`, `mastery`, `talentPara`, `forgetMin`, `forgetMax`. | `BattleSkillTrain.json`; header `BattleSkillTrain.xlsx`. |
| Config functions for mastery and attr | `ModFunction` includes `battleSkillTrainUp`, `addAttr`, `setAttr`, `addCurAttrPercent`, `regainAttr`; `ModCondition` includes `skillGrade`, `skillEquip`, and attr comparison conditions. | `ModFunction.json`, `ModCondition.json`; headers `ModFunction.xlsx`, `ModCondition.xlsx`. |
| Learned/equipped normal attack data path | Decompiled dual-wield seed reads learned normal attacks from `g.world.playerUnit.data.unitData.allActionMartial`, current main normal attack from `skillLeft`, and skill identity from `data.propsInfoBase.baseID`. | `ideas/Mod解包结果/MOD_Addk03/新建 文本文档 (3).txt`. |
| Offhand skill creation | Existing seed creates a `SkillAttack` via `BattleFactory.CreateSkill(2).Cast<SkillAttack>()`, initializes it with `Global.skleft.Init(playerUnitCtrl, propsSkillData)`, and fires with `Global.skleft.Create(...)`. | `MOD_Addk03/新建 文本文档 (2).txt`, `MOD_Addk03/新建 文本文档 (3).txt`. |
| Offhand runtime existence | Runtime game test confirmed `EBattleType.BattleStart` is received, a minimal offhand `SkillAttack` initializes from learned normal attack data, and `SkillAttack.Create(...)` produces visible extra sword/projectile activity. Tested sample logged `skillId=IIER7Z`, `baseId=11452`, and `Offhand fired` counts 1 and 2. | `docs/FLYWHEEL_LOG.md` records `FW-20260627-01` and `FW-20260627-02`; `docs/SERIAL_TEST_PLAN.md` maps this to accepted `DWT-001` through `DWT-003`; user screenshots `codex-clipboard-47d1a09f...png` and `codex-clipboard-0066aab1...png`. |
| Normal attack input key | Existing seed listens to `Input.GetKey(g.data.globle.key.battleSkill1)`, checks `Global.skleft.IsCreate(...)`, and fires offhand. | `MOD_Addk03/新建 文本文档 (3).txt`. |
| Controlled offhand trigger | Runtime game test confirmed the current implementation only fires offhand during normal attack input, produces overlapping second projectile, and deals a second damage instance. | `docs/FLYWHEEL_LOG.md` `FW-20260627-05`; `docs/SERIAL_TEST_PLAN.md` `DWT-004`; user log at 2026-06-27 11:54-11:55. |
| Battle lifecycle | `EBattleType.BattleStart` / `BattleEnd` are available through `g.events.On/Off`; battle update can run through `SceneType.battle.timer.Frame(...)`. | `MOD_Addk03/新建 文本文档 (3).txt`; `代码编写教程/ModMain/Example/Example.cs`. |
| Release build handoff | The game runtime test succeeded after building `bin\Release\MOD_h6Zv8g.dll`; the source sync script now defaults `-Build` to `Release`. | `tools/sync-src-to-game.ps1`; `docs/FLYWHEEL_LOG.md` `FW-20260627-02`; `docs/SERIAL_TEST_PLAN.md` `DWT-001`. |
| Build warning baseline | The generated project emits 6 known optional template-reference warnings. They are ignored when the build has `0 error` and the warning set is exactly `com.unity.multiplayer-hlapi.Runtime`, `DOTweenPro`, `UnityEngine.GridModule`, `UnityEngine.TerrainModule`, `UnityEngine.VRModule`, `UnityEngine.XRModule`. | `docs/DEVELOPMENT_WORKFLOW.md`; repeated successful Release builds through `tools/sync-src-to-game.ps1 -Apply -Build`. |
| Official API CHM | `GGBH_API.chm` decompiles offline with `hh.exe -decompile` into Sandcastle HTML/index files. It contains documented symbol pages for current combat targets such as `UnitCtrlPlayer.AddSkillMartialExp`, `UnitCtrlPlayer.martialUseAddExp`, `DataUnit.UnitInfoData.AddMartialExpInBattle`, `UnitActionRoleBattle.SkillAddExp`, `EBattleType.UnitHitDynIntHandler`, `EBattleType.UnitEffectSkillHpSuck`, `SkillCreateData`, and `SkillDataAttack.actionMartialData`. | `D:\Games\Steam\steamapps\common\鬼谷八荒\Mod\modFQA\代码编写教程\GGBH_API.chm`; `tools/index-ggbh-api-chm.ps1`; generated local `generated/GGBH_API_CHM_INDEX.md`. |
| dnSpy managed-body capability | `dotnet dnSpy.Console.dll --no-color -l C# -t A7T.t7w <SaiLL.dll>` exports full readable C# method bodies for ordinary managed / MelonLoader Mod DLLs, including `namespace A7T`, `internal class t7w : c9f`, `public override GameObject Hgc(GameObject template)`, `foreach (SpriteRenderer ...)`, `ImageConversion.LoadImage`, and `return template;`. `Token/RVA/File Offset` are metadata annotations; `nBB.xBl(int expression)` values are string-obfuscation constants, not native machine code. | `resource/Mod解包结果/SaiLL.dll`; user-provided `resource/Mod解包结果/SaiLL_human_dnspy`; `tools/decompile-dotnet-assembly.ps1`; `docs/API_TOOLCHAIN_TEST_PLAN.md` `AIT-001`. |
| Cecil / ApiProbe distinction | Cecil is the static metadata/IL inventory layer: assembly classification, references, type/method/field discovery, and method-body coverage. ApiProbe is a Roslyn compile-only contract check using game/MelonLoader references; it proves candidate C# calls compile but does not prove runtime behavior. | `tools/inventory-dotnet-assemblies.ps1`; `test/ApiProbe`; `docs/API_TOOLCHAIN_TEST_PLAN.md`; `docs/KEY_EVIDENCE_PROBE_PLAN.md`. |
| Focused system DLL parse | AIT-007 exported focused combat types from both `MelonLoader/Managed/Assembly-CSharp.dll` and `Cpp2IL/cpp2il_out/Assembly-CSharp.dll`, then mapped static symbols to existing DWT observations. The Managed view is IL2CPP wrapper/API-shape evidence; the Cpp2IL view is structure/stub evidence. | `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`; generated ignored `generated/ait/AIT-007-system-dll-parse/`; `docs/API_TOOLCHAIN_TEST_PLAN.md` `AIT-007`. |
| Creation/hit attribution carrier | `SkillCreateData` contains `skillCreateSoleID`, `mainSkillID`, `valueData`, `createSkillBase`, `wings`, `isIngoreShotPosi`, and `isImmortalSkill`; `SkillAttack.Create(...)`, `SkillBase.Create(...)`, `MissileShotData.skillCreateData`, and `MartialTool.HitData.skillCreateData` all expose the creation attribution path. | `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`; AIT-007 focused exports of `SkillAttack`, `SkillBase`, `SkillCreateData`, `MissileShotData`, and `HitData`. |
| Lifesteal attribution event shape | `EBattleTypeData.UnitEffectSkillHpSuck` carries `unit`, `createSkillBase`, `hitData`, and `hpSuck`, so a runtime trace can compare lifesteal source against offhand `SkillCreateData` and hit data. | `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`; AIT-007 focused export `EBattleTypeData.UnitEffectSkillHpSuck.cs`. |
| Native exp mutation surfaces | `UnitCtrlPlayer.AddSkillMartialExp(...)` overloads, `UnitCtrlPlayer.martialUseAddExp`, `DataUnit.UnitInfoData.AddMartialExpInBattle`, `DataUnit.UnitInfoData.AddMartialExp`, `DataUnit.UnitInfoData.GetMartialAddExpRate`, and `UnitActionRoleBattle.SkillAddExp` are confirmed symbols for KEP-001. | `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`; AIT-007 focused exports of `UnitCtrlPlayer`, `DataUnit`, `UnitActionRoleBattle`, and `BattleDataMgr`. |
| Persistence | MOD-local persistence can use `g.data.obj.SetString`, `GetString`, `ContainsKey`, and `DelGroup`; save hook is `EGameType.SaveData`. | `MOD_Addk03/新建 文本文档.txt`, `MOD_Addk03/新建 文本文档 (3).txt`. |
| Offhand save skeleton | A MOD-owned versioned save skeleton using group `MOD_h6Zv8g.DualWield`, keys `schemaVersion` and `offhandSkillId`, load on `EGameType.IntoWorld`, save on `EGameType.SaveData`, and battle-start validation against `allActionMartial` is compile- and runtime-confirmed. User confirmed save/write logs, reload, and battle start `source=saved`. | `src/ModCode/ModMain/DualWield/DualWieldSaveStore.cs`; `docs/FLYWHEEL_LOG.md` `FW-20260627-06`, `FW-20260627-08`; `docs/SERIAL_TEST_PLAN.md` `DWT-005`. |
| No-offhand guardrail | Empty `offhandSkillId` now means offhand mode is disabled. The old `bootstrap-main` proof path is removed so main is not copied into offhand at battle start. | `src/ModCode/ModMain/DualWield/OffhandController.cs`; `docs/FLYWHEEL_LOG.md` `FW-20260627-11`; user design note: no implicit Double Hit without explicit offhand selection. |
| Offhand-to-main promotion | If `skillLeft` is empty but saved `offhandSkillId` is valid on battle start, the saved offhand is written into `skillLeft`, equipped through `UnitActionMartialEquip(..., 0)`, and the MOD offhand key is cleared. | `src/ModCode/ModMain/DualWield/OffhandController.cs`; `docs/FLYWHEEL_LOG.md` `FW-20260627-12`; decompiled `MOD_Addk03` also directly assigned `skillLeft = AKData.aleft` in this scenario. |
| Minimal offhand selection UI | Runtime-confirmed PlayerInfo skill UI button injected through `EGameType.OpenUIEnd` / `UIType.PlayerInfo`. The button can save current `skillLeft` to `DualWieldSaveStore.offhandSkillId`; FW-09 adds toggle behavior, main unequip through `UnitActionMartialUnequip((MartialType)1, 0)`, and hover text from localized `BattleSkillAttack.desc`, awaiting runtime feedback for those refinements. | `src/ModCode/ModMain/DualWield/OffhandSelectionUiController.cs`; `docs/FLYWHEEL_LOG.md` `FW-20260627-08`, `FW-20260627-09`; `docs/SERIAL_TEST_PLAN.md` `DWT-005`, `DWT-006`. |
| UI access and mutation | Official examples show `g.ui.OpenUI`, `g.ui.GetUI<T>`, `UITipItem.AddTip`, `OpenUIEnd` event, cloning UI objects, adding `Button.onClick`, and Harmony patches for UI/resource behavior. | `代码编写教程/ModMain/Example/Example.cs`; `MOD_Addk03/新建 文本文档 (3).txt`; `替换游戏UI、插图例子/ModProject/ModCode/ModMain`. |
| Decompiled offhand UI injection | `MOD_Addk03` adds an offhand button after `EGameType.OpenUIEnd` when `UIType.PlayerInfo` opens: it gets `UIPlayerInfo`, finds `ui.uiSkill.goSkillLeftRoot.transform.Find("Image")`, clones `ui.btnClose.gameObject`, names it `LsButton`, adds a `Button.onClick`, writes `AKData.aleft = skillLeft`, calls normal-attack unequip, and updates icon/tooltip with `SpriteTool` and `UISkyTipEffect`. | `ideas/Mod解包结果/MOD_Addk03/新建 文本文档 (3).txt` lines around `OnOpenUIEnd`, `OnClickLeftBtn`, and `UpdateIcons`. |
| Harmony lifecycle | Official `ModMain` examples call `harmony.PatchAll(Assembly.GetExecutingAssembly())` in `Init()` and stop timers in `Destroy()`. | `代码编写教程/ModMain/ModMain.cs`; `替换游戏UI、插图例子/ModProject/ModCode/ModMain/ModMain.cs`. |
| MOD Excel shape | `ModExcel` tables mirror official table headers. `MID&...` is used in Excel rows to allocate MOD ids, including DLC-prefixed versions such as `DLCBattleSkillAttack`. | `技能配置例子/ModProject/ModExcel/*.xlsx`; `DLC修改配置例子/ModProject/ModExcel/*.xlsx`; `DLC修改配置例子/ModProject/说明.txt`. |

## Candidate / Needs Runtime Verification

| Topic | Current best candidate | Why it matters |
| --- | --- | --- |
| Runtime normal skill object | `SkillAttack` exposes `data : SkillDataAttack`; `SkillDataAttack` exposes `actionMartialData`, `skillData`, `skillAttackItem`, `mpCost`, `cd`, `lastShotTime`, `cdUseTime`, `cdTime`, `reduceCDTime`, `isCreateOne`, and `isUse`. | Metadata inspection of `Assembly-CSharp.dll` through Mono.Cecil on 2026-06-27. This proves object shape, not native method behavior. |
| Learned skill experience holder | `DataUnit.ActionMartialData` exposes `data`, `exp`, `crazyID`, `objData`, and `masteryItem`; `data.soleID` is available through `DataProps.PropsData`. | Metadata inspection of `Assembly-CSharp.dll`; DWT-022 must verify whether MOD-created offhand attacks increase this `exp`. |
| Offhand experience attribution result | Runtime test showed the MOD-created offhand `SkillAttack` has `runtimeBinding=offhand`, `runtimeSoleId=aldsra`, and `runtimeBaseId=14111`, and it creates damaging/killing offhand attacks. However `offhandExp`, `runtimeExp`, and `offhandUseAddExp` stayed at `0`; only main native attack values changed. | User screenshots/logs from `FW-20260627-14` / `DWT-022` at 16:45-16:46. Classification: `no native offhand exp`. |
| Empty-A/main exp pollution guard | `FW-20260627-15` proved a Harmony guard around both `UnitCtrlPlayer.AddSkillMartialExp(...)` overloads can block at least one main-targeted native experience call, but main experience still rose through another pending/delayed path. `FW-20260627-16` adds rollback for main `ActionMartialData.exp` and `martialUseAddExp[mainSkillId]` after offhand-attributed hits. | `src/ModCode/ModMain/DualWield/DualWieldAttributionGuard.cs`, `SkillMartialExpPatch.cs`, `OffhandController.cs`; `docs/FLYWHEEL_LOG.md` `FW-20260627-15` and `FW-20260627-16`; real Release builds passed. |
| Native experience API candidates | `UnitCtrlPlayer` exposes `AddSkillMartialExp(string martialID, int talent, float growExp)` and `AddSkillMartialExp(ActionMartialData actionMartialData, int talent, float growExp)`. | Metadata inspection of `Assembly-CSharp.dll`; parameter semantics and duplicate-exp risk are not yet runtime-verified. |
| Runtime rebuild candidate | `UnitCtrlPlayer` exposes `CreateSkillAttack(MartialType)`, and `UnitCtrlBase.skills` / `allSkills` expose runtime `SkillAttack` lists. | Metadata inspection of `Assembly-CSharp.dll`; possible path for native main-skill rebuild during wheel switching, but not yet tested in combat. |
| Skill creation context details | `SkillBase` exposes `UseSkillCreateData()`, `UseSkillCreateData1(...)`, `onHitUnitCall`, `onMissileShotCall`, `allEffectTrigger`, `lastTriggerSkillSubTime`, and `lastTriggerSkillEffectTime`; `MissileShotData` also contains damage/range/size scales, mouse position, and side marker. | AIT-007 confirms the primary attribution carrier fields; these extra fields still need runtime interpretation before behavior claims. |
| Non-normal category split | `StepBase`, `FieldSkillBase`, `GodEyeSkillBase`, `ImmortalSkillBase`, `AbilityBase`, and `UnitCtrlPlayer.CreateUltimate(...)` are separate runtime surfaces. | Metadata inspection of `Assembly-CSharp.dll`; normal attack correctness cannot be assumed for movement/divine/special categories. |
| Pattern identity for dual mastery | MVP should use `attack_<propsInfoBase.baseID>`. | Existing dual-wield seed already uses `propsInfoBase.baseID` to compare main/offhand identity and fetch `g.conf.battleSkillAttack.GetItem(baseID)`. This is reliable enough for MVP, but later should be replaced or extended by an alias table for same-mode variants. |
| Full individual mastery check | Compare learned skill current mastery against `BattleSkillMastery.skill_mastery12[grade]` or use `ModCondition.skillGrade` if a callable C# helper exists. | Config data confirms thresholds, but current learned-skill runtime field was not found in the available examples. |
| In-combat spirit/mind cost | Use C# runtime attr API if found; fallback candidates are config/drama functions (`addAttr`, `setAttr`, `addCurAttrPercent`, `regainAttr`) only for non-battle or scripted flows. | Stage 2/4 design needs current `mp`/`sp` reads and writes. Config confirms attribute keys and functions, but direct battle-safe C# access is still unconfirmed. |
| Offhand delay | Direct MOD scheduling around `SkillAttack.Create(...)` is the safest MVP route. Config fields `BattleSkillEffect.delay`, `BattleSkillSub.delay`, and `createSkillDelay` prove native delay concepts exist, but they belong to configured skills/effects. | Stage 1 and random instability need delayed offhand firing. For a runtime offhand controller, timer-based delay is likely simpler than mutating config. |
| Damage decay | Best candidate is `EBattleType.UnitHitDynIntHandler`, because official example mutates `edata.dynV.baseValue` and clears callbacks. | Need tag or track offhand-created damage events so the MOD only decays offhand damage. |
| Projectile offset | Best runtime candidate is altering `SkillAttack.Create(position, direction, ...)` position/direction arguments for the offhand attempt. Config alternatives include `BattleMissile`, `BattleTrailxx`, `offsetPosi`, but those are static. | Stage 3 trajectory offset should be per-trigger random, so runtime direction offset is preferred if compatible. |
| Wheel implementation | Use a prebattle PlayerInfo candidate setup UI first, backed by MOD-owned normal candidate pool data. Then use Unity UI objects plus `Input.GetKey/GetKeyDown/GetKeyUp` for Q/left click in combat; inspect hover via UI components/event system during prototype. | Examples prove input polling and UI mutation, but not a complete radial hover surface or input swallowing API. `docs/WHEEL_DESIGN.md` defines the split. |

## Unknowns

These were searched in the available decompiled/example material but are not confirmed yet:

- Exact runtime field for a learned skill instance's current proficiency/mastery value.
- Correct native-compatible way to award offhand proficiency after a MOD-created offhand attack without duplicate growth. `UnitCtrlPlayer.AddSkillMartialExp(...)` is the main candidate, but parameter semantics still need a correction test.
- Whether the `FW-20260627-16` rollback guard fully stops empty-A/main-exp pollution. `FW-20260627-15` proved API blocking alone is not enough.
- Whether offhand hit/effect attribution still leaks main-hand passives such as blade lifesteal after explicit offhand `SkillCreateData` is passed into `SkillAttack.Create(...)`.
- Exact runtime API for battle-safe current/max `mp` and `sp` read/write.
- Exact runtime API for switching unique/movement/divine skills in combat while preserving category cooldown.
- Whether `Input.GetKey(g.data.globle.key.battleSkill1)` can be globally swallowed, or whether the MOD should simply suppress its own offhand handling while the Q wheel is open.
- How to identify an `UnitHitDynIntHandler` event as coming from the offhand `SkillAttack` without false positives.
- Whether `SkillAttack.Create(...)` direction mutation is sufficient for all projectile types, especially melee/trail-based normal attacks.

## Implementation Notes For Dual Wield MVP

- Keep dual wield limited to normal attack (`BattleSkillAttack.type = 1`) for the first prototype.
- Treat right click as the game's unique-skill channel, not offhand attack. The existing offhand seed is tied to `battleSkill1`, which matches the normal attack channel.
- Runtime proof exists for a minimal normal-attack offhand path. Future work can assume battle event registration, `SceneType.battle.timer.Frame`, and `SkillAttack.Create(...)` are viable, but should still validate new behavior through Flywheel game tests.
- Persist MOD state under the MOD namespace with versioned keys using `g.data.obj`, expanding beyond the old single `aleft` string.
- Build loadout from learned skill ids in `allActionMartial`; validate both main and offhand still exist on battle start.
- Use `propsInfoBase.baseID` as the first pattern key and store permanent dual mastery by canonicalized pattern pair.
- Do not consume base-game `energy`; use a MOD-owned battle-only `dualCombatStamina` / `combatFocus` counter.
- Implement early instability outside static config first: timer delay, skip offhand fire, damage decay via hit event, direction offset at `Create(...)`, and short offhand cooldown/sync failure.
- Defer direct `mp`/`sp` spending until battle-safe runtime access is verified. The attribute keys are confirmed, but the write path is not.
- Treat skill trigger consistency as a hard gate: selected skill, runtime object, cooldown owner, resource cost owner, creation context, hit/effect attribution, experience recipient, and UI/input state must stay aligned.
- DWT-022 proves visual damage alone is not enough proof that the game recognizes the offhand skill as used for proficiency. Add an explicit offhand proficiency correction before combat wheel switching or mastery growth.
- DWT-023 must be accepted before wheel work resumes: main-skill experience must not increase from MOD-caused empty-A/offhand-only conditions, and hit logs must classify whether passive/effect attribution still leaks from main to offhand.
- Use `AIT` for tool capability and `KEP` for combat-kernel evidence before broad DWT probes. The next evidence priorities are `KEP-001` skill experience mutation and `KEP-002` hit/effect/lifesteal attribution.
- AIT-007 is enough static evidence to start those KEPs without another broad parse. Use it to select compile probes and runtime trace fields; do not treat wrapper/stub method bodies as original game logic.

## Priority Tables Read

First-pass data fields:

- `RoleAttributeDesc`: attribute keys and labels.
- `BattleSkillAttack`: skill entry, type, cost, base skill linkage, aptitude, growth.
- `BattleSkillBase`: damage, cooldown, projectile/effect/subskill linkage.
- `BattleSkillMastery`: mastery thresholds.
- `BattleSkillTrain`: training gain/cost.
- `BattleSkillValue`: keyed per-grade numeric values.
- `BattleSkillCost`, `BattleSkillLevel`, `BattleSkillCombine`, `ItemSkill`, `RoleMartialGradeGrid`: generation, book, grade, and slot context.

Second-pass combat behavior fields:

- `BattleMissile`, `BattleSubMissileTrigger`, `BattleSkillEffect`, `BattleSkillSub`, `BattleStepBase`, `BattleStepCombine`, `SpecificSkillAttack`, `SpecificBattleSkill`, `FieldSkillBase`, `GodEyeSkills`, `ModCondition`, `ModFunction`, `DefaultKeys`.

Example MOD areas read:

- `ideas/modQ&A/代码编写教程/ModMain`: lifecycle, timers, events, battle, UI, config, data, tool APIs.
- `ideas/modQ&A/MOD模板例子/技能配置例子`: skill table linkage and `ModExcel` table shape.
- `ideas/modQ&A/MOD模板例子/DLC修改配置例子`: DLC-prefixed config table shape and `MID&...` use.
- `ideas/modQ&A/MOD模板例子/替换游戏UI、插图例子/ModProject/ModCode`: Harmony, UI open-event handling, input polling, sprite/resource patches.

## Acceptance Answers

- Attribute keys: `mp`, `sp`, and `energy` are confirmed in `RoleAttributeDesc`.
- Individual proficiency: config thresholds and training gains are confirmed; runtime current mastery field is still unknown.
- Attack pattern key: use `propsInfoBase.baseID` as MVP pattern id because the existing dual-wield seed already relies on it.
- Damage/cost/projectile/effect tables: `BattleSkillBase`, `BattleSkillValue`, `BattleMissile`, `BattleSkillEffect`, `BattleSkillSub`, and `BattleTrailxx` are the key chain.
- Battle APIs: `SceneType.battle`, `g.events`, `g.timer`, `BattleFactory.CreateSkill`, `SkillAttack.Init/Create/IsCreate`, `UnitHitDynIntHandler`, and `AddEffect` are available in examples.
- Offline API lookup: `GGBH_API.chm`, the Cecil static report, and dnSpy type exports are now a repeatable first pass for symbol discovery, but only runtime DWT tests can promote behavior to confirmed.
- dnSpy lookup: managed MOD DLLs can be fully decompiled through `tools/decompile-dotnet-assembly.ps1`; IL2CPP wrapper/stub assemblies require body-coverage classification through Cecil before treating output as logic evidence.
- Tooling tracks: `AIT` validates tools, `KEP` produces narrow evidence maps, and `DWT` stays focused on real in-game MOD behavior.
- Save/UI/input APIs: `g.data.obj`, `EGameType.SaveData`, `OpenUIEnd`, `g.ui`, cloned Unity UI components, `Button.onClick`, and Unity `Input` polling are available.
- Wheel: examples provide the ingredients. Prebattle candidate setup should be implemented first; combat hover selection and full attack input swallowing still need a prototype before being called confirmed. Offhand remains disabled until explicitly chosen by the offhand slot or future wheel selection.
