# AI Context

## Project

DualWieldMod is a Guigubahuang / Tale of Immortal MOD project evolving an existing decompiled dual-wield DLL into a fuller combat subsystem.

The repo tracks documentation, a clean `src/` source overlay, helper tools, and compile probes. Raw decompiled files, idea notes, official MOD Q&A/tutorial resources, and API references live under `ideas/`, which is intentionally ignored by git.

## Current Git State

- Remote: `git@github.com:MichaelWang111/DualWieldMod.git`
- Branch: `master`
- `.gitignore` ignores `ideas/`, build outputs, copied refs, DLL/PDB/cache artifacts, and `.csproj.user` files.
- Allowed tracked areas: `.gitignore`, `dual_wield_mod_skill.md`, `docs/`, `src/`, `tools/`, and `test/`.
- The real game-generated project under `D:\Games\mods\guigubahuang\ModProject_h6Zv8g` is a build/debug target, not a Git source tree.
- Code-bearing rounds must follow `docs/FLYWHEEL.md`: implement, compile the real MOD project, report expected behavior, wait for user in-game testing, record feedback, then iterate.

## Key Docs

- `docs/DUAL_WIELD_DESIGN_MVP.md`: current gameplay/design/MVP spec.
- `docs/DATA_FIELD_RESEARCH.md`: confirmed/candidate/unknown data fields and API evidence.
- `docs/MOD_QA_TUTORIAL_INDEX.md`: direct `.docx` tutorial index from `ideas/modQ&A`.
- `docs/DEVELOPMENT_WORKFLOW.md`: source overlay, sync/build, compile-probe, and runtime smoke-test runbook.
- `docs/FLYWHEEL.md`: required iteration log and delivery protocol.
- `docs/AI_CONTEXT.md`: compact context snapshot.
- `dual_wield_mod_skill.md`: project-local agent workflow and upload guardrails.

## Important Source Material

- `ideas/Mod解包结果/MOD_Addk03`: decompiled dual-wield seed implementation.
- `ideas/Mod解包结果/MOD_nXbfml`: decompiled official/example API code.
- `ideas/modQ&A`: official MOD tutorials, config tables, resources, examples, and API material.
- `ideas/mod想法.md`: conversation/design history.
- `src/ModCode/ModMain/`: clean source overlay for intentional MOD code changes.
- `tools/sync-src-to-game.ps1`: copies the overlay into the real MOD project and can build it.
  - `-Build` defaults to `Release`; runtime testing succeeded with `bin\Release\MOD_h6Zv8g.dll`.
- `test/ApiProbe`: compile-only API surface probe for uncertain game-kernel symbols.

## Existing Decompiled Behavior

`MOD_Addk03` proves a player-side secondary normal attack can work at MOD level.

Current project runtime proof: `FW-20260627-01` and `FW-20260627-02` confirmed in game that `EBattleType.BattleStart` fires, a minimal offhand `SkillAttack` can initialize from the current normal attack, and `SkillAttack.Create(...)` produces a visible second sword/projectile. User screenshots showed `[DualWieldMod] Offhand fired` counts 1 and 2 with `skillId=IIER7Z`, `baseId=11452`.

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
- Right click: unique skill, not offhand attack.
- Movement skill: switchable, not dual wielded.
- Divine skill: switchable, not dual wielded.

Wheel pools:

- Every category can have 0-6 candidate skills.
- Normal attack has main + offhand + 0-6 candidates.
- Unique, movement, and divine have current + 0-6 candidates.
- Non-normal categories should use shared cooldown per category if switching is implemented.

## Q Wheel Rules

Normal attack wheel:

- Hold `Q`: open wheel and disable/ignore attack input.
- Hover option and release `Q`: replace main normal attack.
- Hold `Q` and left click option: replace offhand normal attack and close wheel.
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
- Battle-safe runtime API for current/max `mp` and `sp` read/write.
- Runtime actions for unique/movement/divine skill switching and shared cooldown.
- Complete Q wheel implementation details: hover detection and attack input swallowing.
- Reliable way to tag `UnitHitDynIntHandler` events as offhand damage only.
- Whether changing the direction argument to `SkillAttack.Create(...)` works for every normal attack projectile/trail type.

## API Evidence

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

Recommended implementation order:

1. Open the next Flywheel record for cleanup/control.
2. Reduce temporary runtime visibility noise from FW-02 while keeping useful debug logging gated or sparse.
3. Replace temporary same-as-main offhand probe with controlled offhand selection/loadout behavior.
4. Preserve the accepted minimal offhand path while adding guardrails one at a time.
5. Add versioned save data for loadout and pattern mastery.
6. Resolve skill pattern from `propsInfoBase.baseID`.
7. Add combat stamina and stage calculation.
8. Locate runtime skill proficiency field.
9. Locate runtime `mp` / `sp` APIs.
10. Prototype Q wheel only after hover/input blocking are verified.
