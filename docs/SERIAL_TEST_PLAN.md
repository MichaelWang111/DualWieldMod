# Serial Test Plan

This document owns the serial runtime test ladder for DualWieldMod.

`docs/FLYWHEEL.md` owns the delivery protocol. `docs/FLYWHEEL_LOG.md` owns per-round history. This file owns stable `DWT-###` test case IDs so future implementation rounds can advance one small behavior at a time without burying acceptance logic inside the Flywheel log.

## How To Use

- Each code-bearing Flywheel round should name one or more `DWT-###` IDs.
- Earlier accepted tests become regression checks for later rounds.
- A test can be split if the expected behavior becomes too large for one safe runtime check.
- Do not mark a runtime test `Accepted` until the user confirms in-game behavior.
- Compile-only or docs-only work may reference no test IDs.

## Status Values

- `Not Started`: no implementation round has targeted this test yet.
- `Built`: code exists and real MOD build passed, but user has not tested in game.
- `Awaiting Game Test`: handed to the user with expected behavior and checklist.
- `Accepted`: user confirmed the runtime behavior.
- `Needs Rework`: user saw a runtime mismatch or bug.
- `Blocked`: cannot be tested until a dependency is resolved.
- `Deferred`: intentionally postponed.

## Regression Smoke Pack

Every code-bearing round after the first playable prototype should recheck these unless the round is pure compile/API probing:

- MOD loads without startup error.
- Entering battle does not crash.
- Main normal attack still works.
- Leaving battle stops MOD battle timers/state.
- No new save corruption or obvious UI break.

## Serial Ladder

### DWT-001 - MOD Load And Init Visibility

- Status: Accepted
- Dependency: None.
- Purpose: Prove the Release DLL built from this repo is actually loaded by the game.
- Implementer Setup: Build via `tools/sync-src-to-game.ps1 -Apply -Build`.
- User Runtime Steps:
  - Start or reload the game with module `h6Zv8g` enabled.
  - Watch for `[DualWieldMod]` init diagnostics or logs.
- Acceptance:
  - The game loads the module without startup crash.
  - A DualWieldMod init/battle diagnostic can be observed.
- Evidence: `FW-20260627-02` user screenshot/log showed runtime diagnostics.
- Regression Risk: Release/Debug output mismatch, wrong generated project, or stale DLL.

### DWT-002 - Battle Lifecycle Hook

- Status: Accepted
- Dependency: `DWT-001`.
- Purpose: Prove battle start/end events and battle-frame timers are usable.
- Implementer Setup: Register battle lifecycle handlers and sparse diagnostics.
- User Runtime Steps:
  - Enter battle.
  - Exit battle.
  - Check visible/log diagnostics.
- Acceptance:
  - `EBattleType.BattleStart` is received.
  - Battle logic initializes only inside battle.
  - Battle state stops on battle end or leaving battle.
- Evidence: `FW-20260627-02` confirmed `[DualWieldMod] BattleStart event received`.
- Regression Risk: Duplicate event handlers, timers continuing after battle, or null battle map access.

### DWT-003 - Minimal Offhand Attack Creation

- Status: Accepted
- Dependency: `DWT-002`.
- Purpose: Prove an extra normal attack can be created by MOD code.
- Implementer Setup: Initialize a secondary `SkillAttack` from a valid current normal attack and create it through the battle API.
- User Runtime Steps:
  - Enter battle with a valid normal attack equipped.
  - Observe whether a second projectile/effect appears.
  - Observe whether hit feedback or damage appears when it connects.
- Acceptance:
  - A visible extra normal attack effect appears.
  - Main normal attack remains available.
  - No crash on battle start/end.
- Evidence: `FW-20260627-01` and `FW-20260627-02` confirmed offhand fired counts and visible second sword/projectile.
- Regression Risk: Offhand firing too often, same skill identity confusion, projectile direction mismatch.

### DWT-004 - Cleanup And Controlled Normal-Attack Trigger

- Status: Accepted
- Dependency: `DWT-003`.
- Purpose: Replace the temporary fixed-interval offhand proof with a controlled trigger tied to normal attack input or a guarded equivalent.
- Implementer Setup:
  - Reduce temporary visible tips/log spam.
  - Keep sparse logs for init, battle start, offhand init failure, and first few offhand triggers.
  - Remove or disable the every-60-frame autonomous trigger.
- User Runtime Steps:
  - Enter battle and do nothing for several seconds.
  - Press/hold/click normal attack.
  - Stop attacking and observe whether offhand stops.
  - Exit battle.
- Acceptance:
  - Offhand does not fire while the player is idle.
  - Offhand fires only when normal attack input is active or an explicitly documented controlled trigger is active.
  - Main normal attack still works.
  - Logs/tips are readable and not spammy.
- Should Not Happen:
  - No continuous autonomous offhand firing while idle.
  - No Q wheel or persistence scope creep.
- Likely Flywheel: `FW-20260627-05`.
- Evidence: Release build passed in `FW-20260627-05`; user confirmed in-game that offhand fires only during normal attack input, produces overlapping second projectile, and deals a second damage instance.

### DWT-005 - Offhand Loadout Persistence Skeleton

- Status: Accepted
- Dependency: `DWT-004`.
- Purpose: Store and load the selected offhand normal attack id through MOD-owned save data.
- Implementer Setup:
  - Add versioned save payload or scoped keys under `g.data.obj`.
  - Use an explicit selection path, currently the PlayerInfo offhand button and later the wheel, to write `offhandSkillId`.
  - Validate saved id against learned normal attacks on load and battle start.
- User Runtime Steps:
  - Configure or trigger a temporary offhand selection.
  - Save the game.
  - Reload and enter battle.
  - Verify selected offhand is restored or safely cleared if invalid.
- Acceptance:
  - Valid offhand selection survives save/load.
  - Invalid/missing offhand data fails closed with a log and no crash.
  - Existing save data outside MOD keys is untouched.
- Should Not Happen:
  - No permanent corruption if the selected skill is forgotten or replaced.
  - No broad `g.data.obj` cleanup outside MOD-owned keys.
- Evidence: `FW-20260627-07` confirmed the historical bootstrap save diagnostics and visible `0.05s` offhand delay; that bootstrap path was later removed by `FW-20260627-11` to avoid implicit double hit. `FW-20260627-08` built a minimal PlayerInfo offhand selection button that writes current main normal attack to `offhandSkillId`; user confirmed save/write logs, save/reload, and battle start `source=saved`.

### DWT-006 - Distinct Main And Offhand Normal Attack

- Status: Accepted
- Dependency: `DWT-005`.
- Purpose: Prove that main hand and offhand can use two different learned normal attack skills.
- Implementer Setup:
  - First create a minimal offhand selection entry from the player skill UI, using `MOD_Addk03` as reference.
  - Use the minimal UI entry to write a saved offhand id before testing distinct main/offhand behavior.
  - Locate at least two learned normal attack candidates.
  - Initialize offhand from the saved/offhand candidate, not always `skillLeft`.
  - Guard against main/offhand same-base accidental duplication unless explicitly allowed for testing.
- User Runtime Steps:
  - Equip or select one normal attack as main and another as offhand.
  - Enter battle and attack.
  - Observe whether both visual patterns can appear.
- Acceptance:
  - Main normal attack remains the equipped main skill.
  - Offhand uses a different valid learned normal attack.
  - If offhand is invalid, main still works and offhand stays disabled.
  - If no offhand was explicitly selected, only main attack fires; the MOD must not copy main into offhand.
  - If main is empty but saved offhand is valid, saved offhand is promoted to main before battle initialization, offhand is cleared, and the promoted main attack is usable in that same battle.
- Should Not Happen:
  - No forced replacement of the player's equipped main skill.
  - No `bootstrap-main` double-hit behavior.
  - No dual attack from a skill that was just promoted from offhand to main.
  - No promoted-main battle where the skill is only applied after leaving combat.
  - No crash from mismatched skill config or missing learned skill data.
- Evidence: `FW-20260627-08` compiled a minimal selection entry and user confirmed battle start from saved offhand. User also observed main/offhand cooldowns appear independent in combat. `FW-20260627-09` was accepted for UI toggle behavior: setting offhand unequips main, clicking current offhand clears it, and hover shows a first-pass skill description.
- Follow-up: User accepted FW-20260627-09 behavior and noted only skill description polish remains. FW-20260627-11 is accepted: empty offhand stays empty and cannot become an implicit double hit. FW-20260627-12 confirmed the main-empty/offhand-saved state transition but exposed that BattleStart is too late for same-battle usability. FW-20260627-13 moved promotion into a `WorldBattleMgr.IntoBattle` prefix; user later confirmed the former offhand can become main and be used in that same battle.

### DWT-007 - Basic Offhand Cooldown And Guarding

- Status: Not Started
- Dependency: `DWT-006`.
- Early Probe: `FW-20260627-07` added a narrow `0.05s` offhand fire delay for visual separation only. This does not complete the full DWT-007 cooldown/guarding test.
- Purpose: Make offhand firing cadence stable enough for real combat testing.
- Implementer Setup:
  - Respect `SkillAttack.IsCreate(...)` and any observed cooldown gate.
  - Add MOD-side throttling only if the game API allows repeated create too quickly.
  - Log skip reasons sparsely.
- User Runtime Steps:
  - Hold or repeatedly click normal attack for a short fight.
  - Observe offhand cadence and whether it respects pauses/cooldowns.
- Acceptance:
  - Offhand does not create unbounded projectile spam.
  - Offhand cadence feels linked to skill cooldown/guarding.
  - Long fights do not accumulate duplicate timers or handlers.
- Should Not Happen:
  - No exponential fire rate after re-entering battle.
  - No permanent offhand lock unless a documented guard blocks it.

### DWT-008 - Q Wheel Open/Close And Input Suppression

- Status: Not Started
- Dependency: `DWT-021`; `DWT-004` regression.
- Purpose: Prove the core wheel interaction can open while holding `Q`, close on release, and suppress normal attack during the wheel.
- Implementer Setup:
  - Add minimal wheel UI or debug substitute with stable open/closed state.
  - Detect `Q` hold/release.
  - Suppress or ignore normal attack/offhand trigger while the wheel is open.
- User Runtime Steps:
  - Hold `Q` during battle.
  - Try normal attack while the wheel is open.
  - Release `Q` without hovering a valid option.
- Acceptance:
  - Wheel opens while `Q` is held.
  - Normal/offhand attack does not trigger during wheel hold.
  - Releasing `Q` without a valid selection closes wheel and keeps loadout unchanged.
- Should Not Happen:
  - No stuck wheel after release.
  - No accidental loadout change on empty release.

### DWT-009 - Q Hover Release Replaces Main Normal Attack

- Status: Not Started
- Dependency: `DWT-008`; `DWT-022` must prove a consistent runtime switch/experience path before this becomes a real main replacement.
- Purpose: Prove `Q + hover + release` changes main normal attack selection.
- Implementer Setup:
  - Provide a candidate pool of 1-6 learned normal attacks.
  - Detect hover target.
  - On `Q` release over a valid target, replace main hand only.
- User Runtime Steps:
  - Hold `Q`.
  - Hover a candidate.
  - Release `Q` without left clicking.
  - Attack after wheel closes.
- Acceptance:
  - Main normal attack changes to the hovered candidate.
  - Offhand remains unchanged or disabled according to current loadout.
  - Wheel closes cleanly.
- Should Not Happen:
  - No offhand replacement from hover-release.
  - No selection if the release happens outside a valid option.

### DWT-010 - Q Left Click Replaces Offhand Normal Attack

- Status: Not Started
- Dependency: `DWT-008`; `DWT-022` must prove offhand experience attribution or define a corrected attribution path.
- Purpose: Prove `Q + left click option` changes offhand normal attack and closes the wheel.
- Implementer Setup:
  - Candidate pool supports up to 6 entries.
  - Left click on a valid option while wheel is open assigns offhand.
  - Persist selected offhand if `DWT-005` is already accepted.
- User Runtime Steps:
  - Hold `Q`.
  - Left click a valid candidate.
  - Confirm wheel closes.
  - Attack in battle.
- Acceptance:
  - Offhand changes to the clicked candidate.
  - Main remains unchanged.
  - Wheel closes immediately after click.
- Should Not Happen:
  - No main replacement from left click.
  - No normal attack fires from the click used to select offhand.

### DWT-011 - Candidate Pool Size And Layout Stability

- Status: Not Started
- Dependency: `DWT-021`, `DWT-008`.
- Purpose: Verify the wheel behaves correctly for 1-6 candidate counts.
- Implementer Setup:
  - Support candidate counts from 0 to 6.
  - Use stable layouts per count rather than a shifting generic list.
- User Runtime Steps:
  - Test candidate counts 0, 1, 2, 3, 4, 5, and 6 if data is available.
  - Open/close wheel and select options.
- Acceptance:
  - 0 candidates shows no selectable attack and closes safely.
  - 1-6 candidates are selectable without overlap or ambiguous hover.
  - No text/UI overlap at the target game resolution.
- Should Not Happen:
  - No seventh visible candidate.
  - No inaccessible or mislabeled option.

### DWT-012 - Individual Mastery Gate For Dual Wield

- Status: Not Started
- Dependency: `DWT-006`; runtime mastery field must be found.
- Purpose: Require both selected normal attacks to be fully individually mastered before true dual wield is enabled.
- Implementer Setup:
  - Locate runtime learned-skill mastery/proficiency field.
  - Compare against confirmed config thresholds in `BattleSkillMastery` / `BattleSkillTrain`.
  - Fail closed when the field is missing or ambiguous.
- User Runtime Steps:
  - Try selecting an unmastered skill as offhand.
  - Try selecting two mastered skills.
  - Enter battle and attack.
- Acceptance:
  - Unmastered pair cannot dual wield; selection becomes main replacement or offhand disabled according to design.
  - Mastered pair can dual wield.
  - Diagnostic explains why offhand is disabled when mastery is insufficient.
- Should Not Happen:
  - No false claim of mastery if runtime field is unverified.
  - No crash for skills without mastery data.

### DWT-013 - Pattern Pair Key And Permanent Dual Mastery Save

- Status: Not Started
- Dependency: `DWT-006`; preferably after `DWT-012`.
- Purpose: Save dual mastery by normalized attack pattern pair, not concrete learned skill instance id.
- Implementer Setup:
  - MVP pattern key: `attack_<propsInfoBase.baseID>`.
  - Canonicalize pair key so A+B equals B+A.
  - Store versioned mastery values in MOD-owned save data.
- User Runtime Steps:
  - Use a pair in battle or trigger a controlled training increment.
  - Save/reload.
  - Verify pair mastery remains.
  - Swap main/offhand order and verify same pair is recognized.
- Acceptance:
  - Pair mastery persists across save/load.
  - Pair key is order-independent.
  - Concrete skill instance changes do not lose pattern mastery when base pattern is identical under current MVP key.
- Should Not Happen:
  - No duplicate mastery record for reversed order.
  - No write outside MOD-owned save namespace.

### DWT-014 - Combat Stamina Runtime Resource

- Status: Not Started
- Dependency: `DWT-007`.
- Purpose: Add MOD-owned battle stamina/focus that drains during dual wield and resets per battle.
- Implementer Setup:
  - Add battle-only resource state; do not reuse base `energy` directly.
  - Drain only when dual wield/offhand activity is active.
  - Expose temporary debug readout or sparse logs for stage transitions.
- User Runtime Steps:
  - Enter battle and dual wield.
  - Observe stamina stage changes over time.
  - Stop attacking and observe whether drain stops or recovery behaves as documented.
  - Exit and re-enter battle.
- Acceptance:
  - Stamina starts full each battle.
  - Dual wield drains stamina.
  - Stage transitions are observable through debug output.
  - New battle resets the resource.
- Should Not Happen:
  - No impact on original game `energy` unless explicitly implemented later.
  - No drain while idle without offhand activity.

### DWT-015 - Stage 1 Delay Instability

- Status: Not Started
- Dependency: `DWT-014`.
- Purpose: At reduced combat stamina, offhand becomes slower rather than immediately failing.
- Implementer Setup:
  - Add stage calculation.
  - Stage 1 applies offhand delay or cooldown stretch.
- User Runtime Steps:
  - Drain stamina into Stage 1.
  - Continue attacking.
  - Observe offhand delay compared with full stamina.
- Acceptance:
  - Offhand still fires but slower/delayed.
  - Main attack remains responsive.
- Should Not Happen:
  - No sudden offhand disable at Stage 1.

### DWT-016 - Stage 2 Extra Spirit Pressure

- Status: Not Started
- Dependency: `DWT-014`; runtime `mp` API must be confirmed.
- Purpose: At lower combat stamina, dual wield begins adding spiritual-energy pressure.
- Implementer Setup:
  - Confirm battle-safe current/max `mp` read/write API.
  - Apply a small, visible/logged extra cost or fail closed if unavailable.
- User Runtime Steps:
  - Drain into Stage 2.
  - Attack and observe spirit changes or diagnostics.
- Acceptance:
  - Extra `mp` pressure is applied only in the documented stage.
  - If insufficient `mp`, behavior is stable and documented.
- Should Not Happen:
  - No negative or corrupted resource values.
  - No use of unconfirmed resource API.

### DWT-017 - Stage 3 Random Offhand Instability

- Status: Not Started
- Dependency: `DWT-014`.
- Purpose: Add unpredictable but bounded instability after神念不稳 begins.
- Implementer Setup:
  - Randomly choose among delay, missed trigger, damage decay, trajectory offset, or sync failure.
  - Keep effects bounded and debuggable.
- User Runtime Steps:
  - Drain into Stage 3.
  - Attack repeatedly and observe varied offhand behavior.
- Acceptance:
  - Multiple instability outcomes can occur across attacks.
  - Instability affects offhand/sync behavior, not main attack reliability.
  - Effects do not crash projectile creation.
- Should Not Happen:
  - No permanent lock from a temporary instability result.
  - No wild projectile direction that makes the game unstable.

### DWT-018 - Stage 4 Mind Power Overdraw And Offhand Lockout

- Status: Not Started
- Dependency: `DWT-014`; runtime `sp` API must be confirmed.
- Purpose: At exhaustion, dual wield consumes mind power and eventually disables offhand mode when mind power is depleted.
- Implementer Setup:
  - Confirm battle-safe current/max `sp` read/write API.
  - Main hand cooldown trends toward 70% while mind overdraw is active, per design.
  - Offhand mode locks when mind power is exhausted.
- User Runtime Steps:
  - Drain into Stage 4.
  - Continue attacking until mind power is low/depleted.
  - Observe main-hand speed effect and offhand lockout.
- Acceptance:
  - Stage 4 consumes `sp` only while dual wield pressure is active.
  - Main-hand cooldown change is observable or logged.
  - Once mind power is depleted, offhand mode is disabled for the rest of battle.
- Should Not Happen:
  - No offhand fire after mind depletion.
  - No permanent save-level lockout unless explicitly added later.

### DWT-019 - Hit Attribution And Dual Mastery Growth

- Status: Not Started
- Dependency: `DWT-013`; hit attribution strategy must be verified.
- Purpose: Award pair mastery from combat events such as offhand fire, synchronized hit, same-target hit, or kill contribution.
- Implementer Setup:
  - Verify whether `UnitHitDynIntHandler` or another event can distinguish offhand damage.
  - Add conservative growth rules with debug counters.
- User Runtime Steps:
  - Fight enemies with dual wield active.
  - Observe mastery debug increments.
  - Save/reload and verify persistence.
- Acceptance:
  - Mastery growth occurs from documented combat events.
  - Growth is tied to pattern pair, not concrete skill id.
  - No growth occurs when offhand is disabled.
- Should Not Happen:
  - No uncontrolled mastery farming from unrelated hits.
  - No duplicate increments from the same hit event.

### DWT-020 - Unique/Movement/Divine Switch-Only Boundaries

- Status: Not Started
- Dependency: Q wheel foundation should exist; specific skill APIs must be verified.
- Purpose: Preserve the design boundary that only normal attacks dual wield, while other categories may switch with shared cooldown.
- Implementer Setup:
  - Add or probe category-specific switching without dual firing.
  - Implement shared cooldown per non-normal category only after API shape is proven.
- User Runtime Steps:
  - Switch unique, movement, or divine candidate in combat.
  - Use the switched category.
  - Confirm no dual simultaneous casting occurs.
- Acceptance:
  - Non-normal category switches are possible only in the intended UI path.
  - Shared cooldown prevents chained abuse.
  - Left-click dual wield remains limited to normal attacks.
- Should Not Happen:
  - No right-click/offhand confusion.
  - No simultaneous unique skill dual casting.

### DWT-021 - Prebattle Normal Wheel Candidate Setup

- Status: Not Started
- Dependency: `DWT-006`; no-offhand bootstrap guard from `FW-20260627-11`; offhand-promotes-to-main guard from `FW-20260627-12`.
- Purpose: Configure the 0-6 normal attack candidates used later by the combat Q wheel from the player skill UI before battle.
- Implementer Setup:
  - Add a MOD-owned normal candidate pool save key, such as `normalWheelPool_v1`, under the existing DualWield save group.
  - Add a compact candidate setup strip or small preview near the normal attack/offhand area in PlayerInfo skill UI.
  - Clicking an empty slot stores current main normal attack into that candidate slot.
  - Clicking a filled slot with a different current main replaces that candidate slot.
  - Clicking a filled slot with no current main clears that candidate slot.
  - Validate against `allActionMartial`, remove duplicates, and cap the pool at 6.
- User Runtime Steps:
  - Open player info / skill UI.
  - Add one or more learned normal attacks into candidate slots.
  - Save/reload and reopen the UI.
  - Try clearing a filled slot.
- Acceptance:
  - Candidate slots persist across save/load.
  - Candidate order remains stable.
  - Invalid/missing skills do not crash the UI and are safely removed or disabled.
  - Existing main/offhand slot behavior remains intact.
- Should Not Happen:
  - No battle Q wheel yet.
  - No automatic main/offhand replacement from editing the candidate pool.
  - No more than six candidates are saved or shown.
- Evidence: Planned from `docs/WHEEL_DESIGN.md`.

### DWT-022 - Runtime Skill Trigger Experience Attribution

- Status: Accepted
- Dependency: `DWT-006`; compile-visible metadata for `SkillAttack`, `SkillDataAttack`, and `ActionMartialData`.
- Purpose: Prove whether runtime skill triggering attributes experience/proficiency to the skill that visually fires, especially for MOD-created offhand attacks and future wheel main switching.
- Implementer Setup:
  - Add diagnostics only; do not change damage, cadence, resource cost, or loadout behavior.
  - On battle start, log main/offhand learned ids, base ids, and starting `ActionMartialData.exp` values.
  - After initializing offhand `SkillAttack`, log `offhandSkill.data.actionMartialData.data.soleID`, base id if available, and exp.
  - Around the first few offhand fires, log exp deltas for main learned instance, saved offhand learned instance, and `offhandSkill.data.actionMartialData`.
  - On battle end, log final deltas.
- User Runtime Steps:
  - Prepare distinct learned normal attacks A and B.
  - Equip A as main and set B as offhand.
  - Enter battle and use normal attack enough times for both main and offhand to hit.
  - Exit battle and report `[DualWieldMod] DWT-022` logs.
- Acceptance:
  - Logs clearly show whether offhand runtime `actionMartialData` points to B, A, or neither.
  - If B fires and base game experience is awarded, B's `ActionMartialData.exp` increases and A does not receive B's offhand gain.
  - If experience does not increase, the result is classified as `no native offhand exp` and the next implementation must choose a corrected path.
  - If A increases from B's offhand fire, the result is classified as `wrong recipient` and must be fixed before wheel switching/mastery growth.
  - No duplicate experience is introduced by the diagnostic itself.
- Should Not Happen:
  - No manual experience writes in this diagnostic round.
  - No cooldown reset exploit, extra fire cadence change, or main/offhand selection change.
  - No claim that visual damage proves proficiency correctness.
- Evidence: Planned from the skill trigger consistency contract in `docs/DUAL_WIELD_DESIGN_MVP.md` and metadata findings in `docs/DATA_FIELD_RESEARCH.md`.
- Build: `FW-20260627-14` adds read-only diagnostics and passed the real Release MOD build with the known 6-warning baseline.
- Result: Runtime test showed `runtimeBinding=offhand`, so the MOD-created `SkillAttack` is correctly bound to the saved offhand martial data. Offhand projectile/damage/kill behavior works. However `offhandExp`, `runtimeExp`, and `offhandUseAddExp` stayed at `0`, while main values changed through native main attacks. Classification: `no native offhand exp`, not `wrong recipient`.
- Follow-up: Add a separate correction test before wheel switching or mastery growth: award or trigger offhand proficiency through the smallest native-compatible path, likely `UnitCtrlPlayer.AddSkillMartialExp(...)`, only after confirmed offhand use and without duplicate growth.

### DWT-023 - Offhand Hit Attribution Isolation And Empty-A Exp Guard

- Status: Needs Rework
- Dependency: `DWT-022`; user-reported main/offhand mismatch with main blade and offhand sword.
- Purpose: Stop MOD-caused empty-A/main-skill experience pollution during offhand windows and diagnose whether offhand hit/effect/damage attribution still carries main-hand state such as lifesteal or attack type.
- Implementer Setup:
  - Arm an attribution guard only when main and offhand normal attacks are both selected and distinct.
  - Patch both `UnitCtrlPlayer.AddSkillMartialExp` overloads.
  - During a short offhand queue/create/hit window, skip positive experience whose target is the current main martial, and log the skipped target/talent/growExp.
  - Keep explicit offhand `SkillCreateData` and hit attribution logs for `UnitHitDynIntHandler`.
- User Runtime Steps:
  - Equip two distinct normal attacks with visibly different categories/effects, such as main blade and offhand sword.
  - Enter battle and perform several left-click attacks, including hits and at least one obvious empty main swing if practical.
  - Report `DWT-023 attribution guard armed`, `DWT-023 blocked main exp`, and `DWT-023 hit attribution` lines.
  - Compare main/offhand skill experience before and after the fight if convenient.
- Acceptance:
  - Offhand still fires and damages as in `DWT-004`.
  - Main empty-A / offhand-only MOD pollution no longer increases main skill experience, or logs clearly prove the native experience write happens outside this guard and needs a lower-level patch.
  - Hit attribution logs classify whether offhand damage is using offhand skill context or leaking main skill context.
- Should Not Happen:
  - No global block of normal main experience outside offhand windows.
  - No offhand experience correction yet; missing offhand exp remains a separate follow-up.
  - No Q wheel or candidate pool work until attribution pollution is understood.
- Evidence: Built in `FW-20260627-15` with `0 error` and only the known 6-warning baseline.
- Result: Partially effective but insufficient. Runtime logs proved offhand hit attribution can be clean (`matchesOffhandSkill=True`, `suspiciousMainSkill=False`) and the Harmony patch can block `AddSkillMartialExp(actionData)` calls targeting main. However a later offhand-bound hit still produced `main=237->243` while offhand/runtime stayed `0`, so main exp or pending use exp is also being modified through another path or delayed settlement.
- Follow-up: `DWT-024` adds rollback of main `ActionMartialData.exp` and `martialUseAddExp[mainSkillId]` after offhand-attributed hits.

### DWT-024 - Main Exp Rollback After Offhand-Attributed Hits

- Status: Awaiting Game Test
- Dependency: `DWT-023` partial result.
- Purpose: Prevent main skill experience/pending-use-exp from retaining gains caused only by offhand-attributed hits.
- Implementer Setup:
  - Snapshot main `ActionMartialData.exp` and `UnitCtrlPlayer.martialUseAddExp[mainSkillId]` before offhand queue/create.
  - Continue direct blocking of positive `AddSkillMartialExp(...)` calls targeting main during offhand windows.
  - On offhand-attributed hit events, schedule a short rollback window that restores main exp and pending use exp if they changed.
  - Do not stop behavior guarding when the diagnostic hit-log limit is reached.
  - If a hit is clearly main-attributed, refresh the baseline and temporarily suppress rollback so legitimate main hit experience survives.
- User Runtime Steps:
  - Use the same distinct main/offhand setup that reproduced the issue.
  - Attack until several offhand hits occur and compare main/offhand/runtime exp logs.
  - Report `DWT-024 blocked main exp`, `DWT-024 rolled back main exp pollution`, and later `DWT-022 exp change` lines.
- Acceptance:
  - Offhand still fires and damages.
  - Main exp and `mainUseAddExp` no longer retain increases caused only by offhand hits.
  - Legitimate main-attributed hits can still increase main experience.
- Should Not Happen:
  - No rollback of real main hit experience.
  - No offhand experience award yet.
  - No Q wheel work before this attribution fix is accepted.
- Evidence: Built in `FW-20260627-16` with `0 error` and only the known 6-warning baseline.

## Near-Term Recommended Sequence

The next practical sequence is:

1. `DWT-024`: verify main exp rollback after offhand-attributed hits.
2. Offhand proficiency correction: award or trigger offhand proficiency through the smallest native-compatible path after attribution is isolated.
3. `DWT-021`: prebattle normal wheel candidate setup in the player skill UI.
4. `DWT-008`: Q wheel open/close and input suppression.
5. `DWT-009`: Q hover release replaces main normal attack only after runtime switching/experience attribution is proven.
6. `DWT-010`: Q left click replaces offhand normal attack with correct offhand experience attribution.
7. `DWT-011`: 0-6 candidate layout stability.
8. `DWT-007`: cooldown and repeated battle stability can run before or after the wheel shell if combat cadence needs attention.

Do not start stamina, resources, random instability, or mastery growth until the basic loadout, controlled offhand trigger, and skill attribution contract are stable in-game.

## Test Case Template

```markdown
### DWT-### - Short Title

- Status: Not Started | Built | Awaiting Game Test | Accepted | Needs Rework | Blocked | Deferred
- Dependency:
- Purpose:
- Implementer Setup:
- User Runtime Steps:
- Acceptance:
- Should Not Happen:
- Evidence:
- Regression Risk:
```
