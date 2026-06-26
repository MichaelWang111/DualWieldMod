# Dual Wield Combat Design and MVP

## Purpose

This document is the current canonical design note for the DualWieldMod combat system. It records the agreed gameplay model, the in-world explanation, the minimum viable prototype, and the official/example API evidence currently available from `ideas/modQ&A` and the decompiled `MOD_Addk03` implementation.

The goal is not to build a second hotbar. The goal is to turn dual normal attacks into a cultivable combat discipline: early dual wielding is possible but unstable, and mastery gradually turns it into true synchronized control.

## Current Baseline

The decompiled `MOD_Addk03` already proves that a player-side secondary normal attack can be implemented at MOD level.

Observed baseline behavior:

- Stores an offhand martial skill id in `AKData.aleft`.
- Persists that id through `g.data.obj.SetString/GetString`.
- Adds a button to the player info skill UI by cloning existing UI objects.
- On battle start, validates the stored offhand skill and initializes it as an independent `SkillAttack`.
- On each battle frame, reads the normal attack key and calls `Global.skleft.Create(...)` to fire the offhand skill.
- Applies some existing player luck modifiers to offhand cooldown and range.

This is a working synchronous dual attack seed, but it is too direct: one offhand slot, same-key triggering, no mastery, no stamina, no wheel, no instability, and no tactical switching model.

## Design Summary

Only normal attacks can dual wield.

- Left click / normal attack channel: main normal attack plus optional offhand normal attack.
- Right click: unique skill channel, not offhand attack.
- Movement skill: switchable but not dual wielded.
- Divine skill: switchable but not dual wielded.

Each wheel candidate pool supports 0 to 6 entries. The upper limit is fixed for wheel readability, but players may choose their own count and balance.

- Normal attack wheel: main normal attack, offhand normal attack, and 0-6 candidates.
- Unique skill wheel: current unique skill and 0-6 candidates.
- Movement skill wheel: current movement skill and 0-6 candidates.
- Divine skill wheel: current divine skill and 0-6 candidates.

Unique, movement, and divine skills do not dual wield. They may be switched in combat, but each category should use shared cooldown so the player cannot chain several high-impact skills by rotating the pool.

## Wheel Interaction

The wheel is a combat selection surface, not an inventory screen.

Normal attack wheel rules:

1. Hold `Q` to open the wheel.
2. While the wheel is open, normal attack input is disabled or ignored by the MOD controller.
3. Hover an option and release `Q` to replace the main normal attack.
4. Left click an option while holding `Q` to replace the offhand normal attack and close the wheel immediately.
5. If `Q` is released with no valid hover target, close the wheel and keep the current loadout unchanged.

Combat meaning:

- `Q + hover + release`: shift the focused/main technique.
- `Q + left click`: assign the selected technique to offhand control.

The same 0-6 candidate limit applies to all wheel categories. Layout should be stable per count rather than a generic rotating list:

- 1: single prominent option.
- 2: two opposite anchors.
- 3: triangular layout.
- 4: cross layout.
- 5: five-point layout.
- 6: six-point layout.

## Dual Wield Eligibility

Dual wielding should feel earned.

Minimum rule:

- Dual normal attack is allowed only when both selected normal attack techniques have full individual proficiency according to the base game's own skill proficiency data.
- If the requirement is not met, assigning a second technique should replace the main normal attack and leave offhand empty.

Reasoning:

- A cultivator who has not fully mastered two individual techniques cannot divide attention between them.
- The player can still use the wheel to switch techniques, but not to gain double output early.

The exact field/API for base game individual skill proficiency still needs to be verified during implementation.

## Pattern Mastery

Dual normal attack mastery is permanent and pattern-based.

It should not be stored against concrete skill instance ids, because two techniques may differ in item id, quality, realm, or affixes while sharing the same attack pattern. The mastery record should be tied to normalized attack pattern pairs.

Recommended key model:

```text
pattern_a|pattern_b
```

The pair should be canonicalized, for example by sorting both pattern keys before building the key. That makes `A main + B offhand` and `B main + A offhand` share long-term mastery. Direction-specific tuning may be added later, but MVP should keep the permanent record unordered.

First implementation can use `propsInfoBase.baseID` as a temporary pattern key:

```text
attack_<baseID>
```

A later implementation should introduce an alias table:

```text
100101 -> sword_wave
100102 -> sword_wave
100103 -> sword_wave
```

This allows different technique instances or variants to share the same dual-wield mastery when their attack mode is functionally the same.

## Mastery Growth

Pattern mastery has two growth sources:

1. Combat growth: increases while fighting monsters with both normal attack patterns participating.
2. Cultivation growth: increases through an out-of-combat cultivation action or UI flow.

Combat growth examples:

- Offhand successfully fires.
- Main and offhand both hit inside a short synchronization window.
- Main and offhand hit the same target.
- A monster is defeated after both patterns contributed damage.

Cultivation growth examples:

- Spend time, focus, resource, or a future cultivation action to train a selected pattern pair.
- Increase mastery without combat randomness.
- Use lower yield or daily/monthly caps if balance needs it.

Mastery should affect control feel more than raw damage.

Possible effects:

- Lower offhand delay.
- Lower offhand cooldown multiplier.
- Lower dual combat stamina consumption.
- Lower instability chance.
- Lower extra spirit/mind pressure.
- Unlock near-synchronous dual attack at high mastery.

## Resource Model

The base game already has spirit power and mind power. The MOD should add only one new runtime resource: combat stamina.

Resource roles:

- Combat stamina: MOD-owned temporary battle resource. Represents short-term control bandwidth for maintaining two normal attack patterns.
- Spirit power: base game resource. Used when dual attacks strain energy circulation.
- Mind power: base game resource. Used only as a late-stage overdraw resource after combat stamina is nearly exhausted.

In-world explanation:

- A single normal martial/spiritual technique appears to cost no spirit because its cooldown time allows natural recovery.
- Dual normal attacks make two energy circuits run in parallel; early on, recovery cannot fully keep up.
- Combat stamina measures moment-to-moment attention and control, not physical stamina.
- Mind power is deeper spiritual reserve and should only be consumed when the player forces dual wielding past normal control limits.

Combat stamina should reset at battle start for MVP. Permanent fatigue can be considered later, but it is not part of the first prototype.

## Battle Stages

Dual wield behavior degrades as combat stamina falls.

Suggested MVP thresholds:

```text
Stage 0: 70%-100% combat stamina
Stage 1: 40%-70% combat stamina
Stage 2: 20%-40% combat stamina
Stage 3: 5%-20% combat stamina
Stage 4: 0%-5% combat stamina, then mind power overdraw
```

Stage 0: stable circulation

- Main normal attack is stable.
- Offhand normal attack follows according to mastery.
- High mastery can approach synchronized dual attack.

Stage 1: delay

- Offhand release slows down.
- Synchronization window narrows.
- Low mastery combinations feel noticeably behind the main hand.

Stage 2: blocked circulation

- Stage 1 penalties remain.
- Extra spirit pressure begins.
- Implementation can use extra spirit cost, reduced spirit recovery, or a cooldown-like penalty depending on confirmed resource APIs.

Stage 3: unstable mind control

- Each offhand attempt rolls one instability effect.
- The effect should be random enough that early dual wielding feels risky and alive.

Instability pool:

- Delay: offhand fires after a random delay.
- Missed trigger: offhand does not fire this attempt.
- Damage decay: offhand fires with lower damage or lower dynamic value.
- Trajectory offset: offhand fires with directional deviation.
- Sync failure: offhand enters a short extra cooldown or fails to align with this attack window.

Mastery should reduce effect severity and probability.

Stage 4: mind power overdraw

- Continuing dual wielding starts consuming base game mind power.
- Main hand cooldown recovery efficiency gradually falls toward 70%, representing dizziness and forced overdraw.
- If mind power is exhausted, offhand mode is forcibly disabled for the rest of the battle in MVP.
- Left click then triggers main normal attack only.

Important wording: main hand does not get a 70% cooldown buff. Its cooldown recovery efficiency falls to 70%, which is equivalent to slower main-hand rhythm.

## Persistence

Permanent MOD data should be stored under the MOD namespace/group, not inside base game skill instances.

Existing `MOD_Addk03` uses:

```csharp
g.data.obj.SetString(ModMain.nid, "aleft", AKData.aleft);
g.data.obj.GetString(ModMain.nid, "aleft");
g.data.obj.ContainsKey(ModMain.nid, "aleft");
g.data.obj.DelGroup(ModMain.nid);
```

Recommended save blob keys:

```text
dual_loadout_v1
pattern_mastery_v1
wheel_config_v1
```

Example mastery JSON shape:

```json
{
  "version": 1,
  "patterns": {
    "fire_orb|sword_wave": {
      "exp": 1280.0,
      "level": 4,
      "combatUseCount": 97,
      "cultivateCount": 3
    }
  }
}
```

Example loadout JSON shape:

```json
{
  "version": 1,
  "normalMain": "skill-instance-id-main",
  "normalOffhand": "skill-instance-id-offhand",
  "normalPool": ["skill-a", "skill-b"],
  "uniqueCurrent": "unique-id",
  "uniquePool": [],
  "movementCurrent": "movement-id",
  "movementPool": [],
  "divineCurrent": "divine-id",
  "divinePool": []
}
```

MVP can continue storing the offhand string separately for compatibility during early refactor, but the target shape should use versioned JSON blobs.

## MVP Scope

The first playable prototype should prove the new dual normal attack loop without implementing every future feature.

MVP includes:

- Keep existing `MOD_Addk03` offhand normal attack behavior as the seed.
- Split runtime timer handles so battle update and delayed UI refresh do not reuse one `corUpdate` field.
- Add a `DualCombatStamina` runtime model.
- Add a `PatternMasteryStore` persisted through `g.data.obj`.
- Use `baseID` as the first pattern key.
- Add stage calculation from combat stamina percentage.
- Apply Stage 1 offhand delay.
- Apply Stage 3 random offhand instability.
- Apply Stage 4 offhand lockout when mind power is unavailable or reaches zero, once mind power API is confirmed.
- Implement the normal attack wheel with up to 6 candidates if UI creation and hover handling are verified.
- Keep unique/movement/divine switching out of MVP unless their equip and trigger APIs are found quickly.

MVP excludes:

- Full wheel art polish.
- Full unique/movement/divine switching.
- Shared cooldown implementation for non-normal categories.
- Cultivation UI for pattern mastery.
- Pattern alias table beyond `baseID`.
- Direction-specific mastery.
- Cross-save or account-wide inheritance.

## Suggested Module Boundaries

When code is created, keep responsibilities small:

```text
ModMain
- Registers and unregisters events.
- Owns high-level lifecycle only.

DualWieldState
- Current main/offhand ids.
- Battle flags and offhand lockout.

DualCombatStamina
- Runtime value, max value, stage calculation, consume/recover.

PatternMasteryStore
- Save/load versioned mastery data.
- Pattern pair key canonicalization.
- Exp/level calculation.

SkillPatternResolver
- Converts skill instance data into a normalized pattern key.
- MVP uses baseID.

DualAttackController
- Initializes offhand SkillAttack on battle start.
- Handles left-click offhand attempts.
- Applies delay, instability, stamina cost, and lockout.

WheelController
- Opens/closes wheel.
- Tracks hover and click selection.
- Calls replace main/offhand actions.
```

This keeps volatile UI and input work outside the persistent mastery model.

## API Evidence From Official Examples

The following APIs are evidenced by `ideas/modQ&A` official examples and/or decompiled `MOD_Addk03`.

Lifecycle and timer:

- `ModMain.Init()` and `ModMain.Destroy()` are called by the MOD loader.
- `g.timer.Frame(new Action(OnUpdate), 1, true)` supports repeated update loops.
- `g.timer.Stop(coroutine)` stops a timer.
- `g.timer.Time(...)` is used in `MOD_Addk03` for delayed UI refresh.
- Official notes say many game classes do not inherit `MonoBehaviour`, so `g.timer` is the normal way to do delayed or frame calls.

Events:

- `g.events.On(...)` and `g.events.Off(...)` are official event hooks.
- Event groups include `EGameType`, `EMapType`, and `EBattleType`.
- Useful observed events include `EGameType.IntoWorld`, `EGameType.OpenUIEnd`, `EGameType.SaveData`, `EBattleType.BattleStart`, `EBattleType.BattleEnd`, and `EBattleType.UnitHitDynIntHandler`.
- Event data is read via `e.Cast<SpecificEventData>()`.

Battle access:

- `SceneType.battle` is the battle-scene manager entry.
- `SceneType.battle.battleMap.playerUnitCtrl` gives the player battle unit.
- Official example uses `AddEffect(...)`, `CreateUnitHuman(...)`, and `CreateUnitMonst(...)` from battle context.
- Decompiled `MOD_Addk03` uses `BattleFactory.CreateSkill(2).Cast<SkillAttack>()`, `SkillAttack.Init(...)`, `SkillAttack.IsCreate(...)`, and `SkillAttack.Create(...)`.

World and unit actions:

- `g.world.playerUnit` gives the player world unit.
- Unit actions are used for game-state changes.
- Decompiled `MOD_Addk03` uses `UnitActionMartialUnequip` and `UnitActionMartialEquip` for normal attack skill swapping.

UI:

- `g.ui.OpenUI(...)`, `g.ui.GetUI<T>(...)`, and `g.ui.CloseUI(...)` are available.
- Official example uses `UITipItem.AddTip(...)` and popup UIs.
- `OpenUIEnd` can be observed to inspect or modify opened UI objects.
- Decompiled `MOD_Addk03` clones existing UI objects, adds `Button.onClick`, and uses `UISkyTipEffect` for tooltip text.
- Official UI replacement example shows scanning `Image` components under an opened UI and replacing sprites.
- Custom UI can be opened with `new UIType.UITypeBase("UI prefab name", UILayer.UI)`, assuming the prefab/resource exists.

Resources and sound:

- `g.res.Load<GameObject>("Effect/Battle/Skill/jueyingjian")` loads game resources.
- `g.sounds.PlayEffect("Battle/jineng/jian/jueyingjian", ...)` plays effect sounds.
- `SpriteTool.GetSprite(...)`, `SpriteTool.GetMartialBG(...)`, and resource replacement via Harmony are evidenced by examples/decompiled code.

Configuration and data:

- `g.conf` exposes configuration tables.
- Official skill config example identifies `BattleSkillAttack`, `BattleSkillBase`, `BattleSkillEffect`, `BattleSkillSub`, `BattleMissile`, and trail/effect tables as relevant to skill behavior.
- `g.data` exposes save data.
- `g.data.obj` is already proven by `MOD_Addk03` for MOD-specific persistence.

Harmony:

- Official `ModMain` template initializes `HarmonyLib.Harmony` and calls `PatchAll(Assembly.GetExecutingAssembly())`.
- UI/resource replacement examples use Harmony patches against `SpriteAtlas.GetSprite` and `SpriteTool.GetSpriteBigTex`.
- Harmony should be reserved for places where event/timer/UI APIs cannot intercept behavior cleanly, such as hard input swallowing or right-click/skill trigger interception.

## Unknowns To Verify

These are not blockers for the dual normal attack MVP, but they matter for the full system.

- Exact fields for individual martial/spiritual technique proficiency.
- Exact data fields and actions for unique skill, movement skill, and divine skill switching.
- Exact APIs for spirit power and mind power read/write.
- Whether a custom wheel UI can block the base game's left-click input reliably through UI raycast alone.
- Whether hover can be implemented through Unity `EventTrigger` or pointer interfaces in the game's IL2CPP environment without extra registration work.
- Best normalized attack pattern field beyond `propsInfoBase.baseID`.
- Whether damage decay is best applied by modifying skill data before create, listening to hit dynamic value, or applying a temporary effect.
- How to slow main-hand cooldown recovery in Stage 4 without corrupting base skill state.

## Acceptance Criteria For MVP

A prototype is good enough when the following can be observed in battle:

1. A valid offhand normal attack can be assigned and persists through save/load.
2. Left click triggers main normal attack and attempts offhand normal attack.
3. A pattern pair mastery record is created and saved using pattern keys, not concrete item ids.
4. Combat stamina starts full at battle start and decreases while dual wielding.
5. Stage 1 visibly delays offhand attacks.
6. Stage 3 visibly produces random offhand instability.
7. Stage 4 disables offhand mode when the overdraw condition is reached.
8. Battle end stops all battle timers and resets runtime-only state.
9. Destroy unregisters events and stops timers without leaving repeated callbacks behind.

## Implementation Order

1. Refactor the decompiled Addk03 logic into readable source modules.
2. Preserve current behavior with no new balance changes.
3. Add versioned save/load data structures.
4. Add pattern key resolution using `baseID`.
5. Add combat stamina and stage calculation.
6. Add offhand delay and instability inside `DualAttackController`.
7. Add minimal debug logging or tips for current stage.
8. Prototype normal attack wheel only.
9. Verify input blocking and hover/click semantics.
10. Only after that, investigate unique/movement/divine switching and shared cooldowns.

## Notes On Balance

The system should avoid pure damage inflation.

Prefer penalties and rewards that affect control:

- Timing.
- Stability.
- Recovery.
- Resource pressure.
- Skill switching decisions.

High mastery can eventually remove extra costs, but early dual wielding should be tempting, risky, and technically expressive.
