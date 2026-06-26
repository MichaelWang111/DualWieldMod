# DualWieldMod Data Field Research

## Purpose

This document records the current evidence for data fields and MOD APIs needed by the dual-wield combat design. It is based on a targeted read-only pass over `ideas/modQ&A` and the decompiled `MOD_Addk03` / `MOD_nXbfml` examples.

`ideas/` remains reference-only and ignored by git. No code implementation is included here.

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
| Offhand runtime existence | Runtime game test confirmed `EBattleType.BattleStart` is received, a minimal offhand `SkillAttack` initializes from learned normal attack data, and `SkillAttack.Create(...)` produces visible extra sword/projectile activity. Tested sample logged `skillId=IIER7Z`, `baseId=11452`, and `Offhand fired` counts 1 and 2. | `docs/FLYWHEEL.md` records `FW-20260627-01` and `FW-20260627-02`; user screenshots `codex-clipboard-47d1a09f...png` and `codex-clipboard-0066aab1...png`. |
| Normal attack input key | Existing seed listens to `Input.GetKey(g.data.globle.key.battleSkill1)`, checks `Global.skleft.IsCreate(...)`, and fires offhand. | `MOD_Addk03/新建 文本文档 (3).txt`. |
| Battle lifecycle | `EBattleType.BattleStart` / `BattleEnd` are available through `g.events.On/Off`; battle update can run through `SceneType.battle.timer.Frame(...)`. | `MOD_Addk03/新建 文本文档 (3).txt`; `代码编写教程/ModMain/Example/Example.cs`. |
| Release build handoff | The game runtime test succeeded after building `bin\Release\MOD_h6Zv8g.dll`; the source sync script now defaults `-Build` to `Release`. | `tools/sync-src-to-game.ps1`; `docs/FLYWHEEL.md` `FW-20260627-02`. |
| Persistence | MOD-local persistence can use `g.data.obj.SetString`, `GetString`, `ContainsKey`, and `DelGroup`; save hook is `EGameType.SaveData`. | `MOD_Addk03/新建 文本文档.txt`, `MOD_Addk03/新建 文本文档 (3).txt`. |
| UI access and mutation | Official examples show `g.ui.OpenUI`, `g.ui.GetUI<T>`, `UITipItem.AddTip`, `OpenUIEnd` event, cloning UI objects, adding `Button.onClick`, and Harmony patches for UI/resource behavior. | `代码编写教程/ModMain/Example/Example.cs`; `MOD_Addk03/新建 文本文档 (3).txt`; `替换游戏UI、插图例子/ModProject/ModCode/ModMain`. |
| Harmony lifecycle | Official `ModMain` examples call `harmony.PatchAll(Assembly.GetExecutingAssembly())` in `Init()` and stop timers in `Destroy()`. | `代码编写教程/ModMain/ModMain.cs`; `替换游戏UI、插图例子/ModProject/ModCode/ModMain/ModMain.cs`. |
| MOD Excel shape | `ModExcel` tables mirror official table headers. `MID&...` is used in Excel rows to allocate MOD ids, including DLC-prefixed versions such as `DLCBattleSkillAttack`. | `技能配置例子/ModProject/ModExcel/*.xlsx`; `DLC修改配置例子/ModProject/ModExcel/*.xlsx`; `DLC修改配置例子/ModProject/说明.txt`. |

## Candidate / Needs Runtime Verification

| Topic | Current best candidate | Why it matters |
| --- | --- | --- |
| Pattern identity for dual mastery | MVP should use `attack_<propsInfoBase.baseID>`. | Existing dual-wield seed already uses `propsInfoBase.baseID` to compare main/offhand identity and fetch `g.conf.battleSkillAttack.GetItem(baseID)`. This is reliable enough for MVP, but later should be replaced or extended by an alias table for same-mode variants. |
| Full individual mastery check | Compare learned skill current mastery against `BattleSkillMastery.skill_mastery12[grade]` or use `ModCondition.skillGrade` if a callable C# helper exists. | Config data confirms thresholds, but current learned-skill runtime field was not found in the available examples. |
| In-combat spirit/mind cost | Use C# runtime attr API if found; fallback candidates are config/drama functions (`addAttr`, `setAttr`, `addCurAttrPercent`, `regainAttr`) only for non-battle or scripted flows. | Stage 2/4 design needs current `mp`/`sp` reads and writes. Config confirms attribute keys and functions, but direct battle-safe C# access is still unconfirmed. |
| Offhand delay | Direct MOD scheduling around `SkillAttack.Create(...)` is the safest MVP route. Config fields `BattleSkillEffect.delay`, `BattleSkillSub.delay`, and `createSkillDelay` prove native delay concepts exist, but they belong to configured skills/effects. | Stage 1 and random instability need delayed offhand firing. For a runtime offhand controller, timer-based delay is likely simpler than mutating config. |
| Damage decay | Best candidate is `EBattleType.UnitHitDynIntHandler`, because official example mutates `edata.dynV.baseValue` and clears callbacks. | Need tag or track offhand-created damage events so the MOD only decays offhand damage. |
| Projectile offset | Best runtime candidate is altering `SkillAttack.Create(position, direction, ...)` position/direction arguments for the offhand attempt. Config alternatives include `BattleMissile`, `BattleTrailxx`, `offsetPosi`, but those are static. | Stage 3 trajectory offset should be per-trigger random, so runtime direction offset is preferred if compatible. |
| Q wheel implementation | Use Unity UI objects plus `Input.GetKey/GetKeyDown/GetKeyUp` for Q/left click; inspect hover via UI components/event system during prototype. | Examples prove input polling and UI mutation, but not a complete radial hover surface or input swallowing API. |

## Unknowns

These were searched in the available decompiled/example material but are not confirmed yet:

- Exact runtime field for a learned skill instance's current proficiency/mastery value.
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
- Save/UI/input APIs: `g.data.obj`, `EGameType.SaveData`, `OpenUIEnd`, `g.ui`, cloned Unity UI components, `Button.onClick`, and Unity `Input` polling are available.
- Q wheel: examples provide the ingredients, but hover selection and full attack input swallowing need a prototype before being called confirmed.
