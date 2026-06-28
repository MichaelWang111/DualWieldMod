# Flywheel Log

This document owns the historical delivery records for DualWieldMod Flywheel rounds.

`docs/FLYWHEEL.md` owns the process contract and record template. `docs/SERIAL_TEST_PLAN.md` owns stable test case IDs and acceptance ladders. Each new record here should reference one or more serial test IDs when the round changes runtime behavior.

## Records

### FW-20260627-00 - Establish Flywheel Process

- Status: Docs Only
- Date: 2026-06-27
- User Request: Define a repeatable delivery loop where Codex implements, compiles the real project, reports expected behavior, waits for user in-game testing, then iterates from feedback.
- Test Case IDs: None; process setup only.
- Scope: Add the Flywheel process and connect it to existing development workflow docs.
- Non-Goals: No gameplay implementation; no runtime game test.
- Files Changed: `docs/FLYWHEEL.md`, `docs/DEVELOPMENT_WORKFLOW.md`, `docs/AI_CONTEXT.md`, optionally project-local agent workflow docs.
- Compile Verification:
  - ApiProbe: Not required for docs-only process work.
  - Real MOD build: Not required for docs-only process work.
- Expected In-Game Behavior: No change.
- Should Not Happen: No MOD behavior change, no generated game-project files committed, no `ideas/` upload.
- User Test Checklist:
  - [ ] Confirm the flywheel loop matches the desired collaboration rhythm.
- User Feedback: Pending.
- Decision: Use Flywheel as the default iteration protocol going forward.
- Next Round: Start the next code-bearing MVP iteration under the Flywheel contract.

### FW-20260627-01 - Minimal Offhand Attack Existence

- Status: Accepted
- Date: 2026-06-27
- User Request: Start the first code-bearing Flywheel round from `ideas/chats/flywheel_start_suggest.md`: prove that an offhand normal attack can exist in battle without expanding into synchronization, UI, resource, or mastery systems.
- Test Case IDs: `DWT-001`, `DWT-002`, `DWT-003`.
- Scope:
  - Build the smallest readable offhand controller under `src/ModCode/ModMain/`.
  - On battle start, locate a valid learned normal attack candidate and initialize an offhand `SkillAttack`.
  - During battle, trigger offhand attack on a conservative interval or guarded condition sufficient to prove visible existence.
  - On battle end, stop timers/state cleanly.
- Non-Goals:
  - No Q wheel.
  - No main/offhand synchronization model.
  - No combat stamina, spirit/mind cost, instability, damage formula, mastery gain, or permanent pattern-pair progression.
  - No UI for selecting offhand skills unless strictly required to create a testable default.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `docs/FLYWHEEL.md`; synced into the real MOD project with `tools/sync-src-to-game.ps1 -Apply -Build`.
- Compile Verification:
  - ApiProbe: Not run this round; no new API shape beyond previously compile-verified battle events, `allActionMartial`, and `SkillAttack` path.
  - Real MOD build: Passed with `0 error`, `6 warnings` from existing missing optional template references (`com.unity.multiplayer-hlapi.Runtime`, `DOTweenPro`, `UnityEngine.GridModule`, `UnityEngine.TerrainModule`, `UnityEngine.VRModule`, `UnityEngine.XRModule`).
- Expected In-Game Behavior:
  - Entering battle with a valid current main normal attack should start the minimal offhand controller.
  - The controller currently uses the current main normal attack as the temporary offhand existence probe.
  - About once every 60 frames, if the offhand `SkillAttack.IsCreate(...)` guard allows it, a second attack should be created from the player bullet position/direction.
  - Damage numbers or hit feedback should appear if the extra attack connects.
  - The player log should include `[DualWieldMod] Offhand minimal controller started...`; the first three successful fires log `[DualWieldMod] Offhand fired...`.
  - Leaving battle should stop the controller and log `[DualWieldMod] Offhand minimal controller stopped...`.
- Should Not Happen:
  - The game should not crash on battle start or battle end.
  - Main-hand normal attack should not disappear.
  - Offhand should not fire infinitely without cooldown/guarding.
  - No UI or save data should be corrupted.
  - This round should not show a Q wheel, offhand selection UI, stamina drain, mastery gain, or persistent dual-wield data.
- User Test Checklist:
  - [ ] Enter battle.
  - [ ] Confirm main-hand normal attack still works.
  - [ ] Observe whether a second/offhand attack effect appears.
  - [ ] Observe whether damage or hit feedback appears from the offhand attack.
  - [ ] Check logs for `[DualWieldMod] Offhand minimal controller started` and, if attacks fire, `[DualWieldMod] Offhand fired`.
  - [ ] Exit battle and confirm offhand activity stops.
- User Feedback: Initially the h6Zv8g module appeared loaded but no `[DualWieldMod]` diagnostics were visible. After FW-02 Release build and stronger diagnostics, in-game logs showed `[DualWieldMod] BattleStart event received`, `Offhand minimal controller started. skillId=IIER7Z, baseId=11452`, and `Offhand fired` counts 1 and 2. Screenshot also showed a visible second sword/projectile effect.
- Decision: Accepted. The minimal offhand existence path is proven in the game runtime: battle event received, offhand `SkillAttack` initialized, and offhand attack created visibly.
- Next Round: Remove or reduce visibility probe noise, then proceed to controlled offhand trigger rules or basic loadout persistence.

### FW-20260627-02 - Runtime Load Visibility Probe

- Status: Accepted
- Date: 2026-06-27
- User Request: Continue after FW-01 showed no visible `[DualWieldMod]` logs despite h6Zv8g module load; prove the new code is actually loaded and event hooks fire at runtime.
- Test Case IDs: `DWT-001`, `DWT-002`, `DWT-003`.
- Scope:
  - Add `DualWieldLog` helper that writes through `Debug.Log`, `Console.WriteLine`, and optional `UITipItem.AddTip`.
  - Add visible diagnostics to `ModMain.Init`, `ModMain.Destroy`, `OffhandController.Init`, `BattleStart`, `BattleEnd`, skip paths, start/stop, and first offhand fires.
  - Change sync/build helper so `-Build` defaults to `Release`, matching the likely game debug load path.
  - Keep the existing minimal offhand behavior unchanged except for diagnostics.
- Non-Goals:
  - No Q wheel, UI selection, persistence, resource costs, mastery, or synchronization.
  - No attempt to tune offhand attack cadence until runtime load visibility is proven.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `src/ModCode/ModMain/DualWield/DualWieldLog.cs`, `tools/sync-src-to-game.ps1`, `docs/DEVELOPMENT_WORKFLOW.md`, `docs/FLYWHEEL.md`.
- Compile Verification:
  - ApiProbe: Not run this round; no new game API shape beyond `UITipItem.AddTip`, already present in official examples.
  - Real MOD build: Passed Release build with `0 error`, `6 warnings` from existing missing optional template references. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - On MOD load/init, the player should see or log `[DualWieldMod] FW-20260627-02 ModMain.Init entered. Assembly=MOD_h6Zv8g`.
  - On entering battle, the player should see or log `[DualWieldMod] BattleStart event received.`.
  - If player/battle/skill data is not ready, a visible skip reason should appear.
  - If offhand initializes, visible/log messages should show controller started and first fires.
  - On battle end, a visible/log message should show the event and controller stop when applicable.
- Should Not Happen:
  - The game should not crash or spam unbounded tips every frame.
  - Main-hand normal attack should not disappear.
  - No new gameplay systems should appear beyond the existing minimal offhand probe.
- User Test Checklist:
  - [ ] Re-enter game or reload the MOD after the Release build.
  - [ ] Confirm whether a `[DualWieldMod] FW-20260627-02 ModMain.Init entered` tip or log appears.
  - [ ] Enter battle and check for `[DualWieldMod] BattleStart event received`.
  - [ ] If no offhand appears, note any visible skip reason.
  - [ ] Exit battle and check for `[DualWieldMod] BattleEnd event received`.
- User Feedback: Confirmed in game. Visible log lines included `[DualWieldMod] BattleStart event received`, `[DualWieldMod] Offhand minimal controller started. skillId=IIER7Z, baseId=11452`, and `[DualWieldMod] Offhand fired. count=1/2`. Screenshot showed the extra sword/projectile effect.
- Decision: Accepted. Runtime visibility is confirmed, and Release build output is the correct default for handoff/testing.
- Next Round: Start a cleanup/control round: reduce temporary visible tips/log spam, then introduce controlled offhand trigger/loadout behavior without expanding into Q wheel or mastery yet.

### FW-20260627-03 - Add Project README

- Status: Docs Only
- Date: 2026-06-27
- User Request: Add a root `README.md` for the GitHub project.
- Test Case IDs: None; docs-only GitHub entrypoint.
- Scope: Create a concise project entry document covering project purpose, current runtime status, repository model, sync/build commands, ApiProbe, key docs, next Flywheel step, and upload guardrails.
- Non-Goals: No MOD gameplay change, no source sync/build, no new runtime test.
- Files Changed: `README.md`, `docs/FLYWHEEL.md`.
- Compile Verification:
  - ApiProbe: Not required for docs-only work.
  - Real MOD build: Not required for docs-only work.
- Expected In-Game Behavior: No change.
- Should Not Happen: No change to MOD runtime behavior, no generated files committed, no `ideas/` upload.
- User Test Checklist:
  - [ ] Review README on GitHub/local repo for clarity.
- User Feedback: Pending.
- Decision: README added as project entrypoint.
- Next Round: Completed by `FW-20260627-04 - Decouple Flywheel Log And Serial Test Plan`; code cleanup/control now moves to `FW-20260627-05`.

### FW-20260627-04 - Decouple Flywheel Log And Serial Test Plan

- Status: Docs Only
- Date: 2026-06-27
- User Request: Design a serial test suite for gradual iteration and decouple Flywheel records out of the protocol document.
- Test Case IDs: None; this round creates and organizes the test ladder.
- Scope:
  - Move historical Flywheel records from `docs/FLYWHEEL.md` into `docs/FLYWHEEL_LOG.md`.
  - Keep `docs/FLYWHEEL.md` focused on protocol, status values, and record template.
  - Add `docs/SERIAL_TEST_PLAN.md` with stable `DWT-###` test IDs from current runtime proofs through future Q wheel, mastery, stamina, and resource stages.
  - Update README, AI context, development workflow, data research references, and project-local agent workflow to point at the new split.
- Non-Goals: No MOD gameplay change, no source sync/build, no runtime game test.
- Files Changed: `README.md`, `dual_wield_mod_skill.md`, `docs/FLYWHEEL.md`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `docs/DEVELOPMENT_WORKFLOW.md`, `docs/DATA_FIELD_RESEARCH.md`.
- Compile Verification:
  - ApiProbe: Not required for docs-only process work.
  - Real MOD build: Not required for docs-only process work.
- Expected In-Game Behavior: No change.
- Should Not Happen: No MOD runtime behavior change, no generated files committed, no `ideas/` upload.
- User Test Checklist:
  - [ ] Review `docs/SERIAL_TEST_PLAN.md` for whether the serial order matches the intended development rhythm.
- User Feedback: Pending.
- Decision: Serial tests now use `DWT-###`; Flywheel history is separated from protocol.
- Next Round: Use `FW-20260627-05` for `DWT-004 - Cleanup And Controlled Normal-Attack Trigger`.

### FW-20260627-05 - Cleanup And Controlled Offhand Trigger

- Status: Accepted
- Date: 2026-06-27
- User Request: Continue according to the DWT serial test plan.
- Test Case IDs: `DWT-004`; regression recheck `DWT-001`, `DWT-002`, `DWT-003`.
- Scope:
  - Reduce FW-02 visible tip/log noise while keeping sparse diagnostics.
  - Remove the every-60-frame autonomous offhand proof trigger.
  - Attempt offhand creation only while the normal attack input key `g.data.globle.key.battleSkill1` is active.
  - Keep using the current main normal attack as the temporary offhand skill source for this test.
- Non-Goals:
  - No Q wheel.
  - No offhand selection UI.
  - No save/load persistence.
  - No distinct main/offhand skill selection.
  - No mastery, combat stamina, spirit/mind resource costs, damage tuning, or instability.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `README.md`.
- Compile Verification:
  - ApiProbe: Not run; `Input.GetKey(g.data.globle.key.battleSkill1)` was already compile-evidenced in `test/ApiProbe` and decompiled seed code.
  - Real MOD build: Passed Release build with `0 error`, `6 warnings` from existing missing optional template references (`com.unity.multiplayer-hlapi.Runtime`, `DOTweenPro`, `UnityEngine.GridModule`, `UnityEngine.TerrainModule`, `UnityEngine.VRModule`, `UnityEngine.XRModule`). Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD should load without the old FW-02 visible init tip spam.
  - Entering battle should initialize the offhand controlled trigger using the current main normal attack as the temporary offhand probe.
  - If the player stands idle and does not use normal attack, offhand should not fire.
  - While the player uses normal attack, offhand should attempt to fire through `SkillAttack.IsCreate(...)` and `SkillAttack.Create(...)`.
  - The first few successful offhand fires should show/log `Offhand fired from normal attack input...`; later fires should not spam visible tips.
  - Leaving battle should stop the offhand controller.
- Should Not Happen: No autonomous offhand firing while idle; no Q wheel; no UI or save data writes; no distinct offhand selection yet; no main-hand normal attack loss.
- User Test Checklist:
  - [x] Enter battle and do not attack for several seconds; offhand should not fire.
  - [x] Use normal attack; offhand should attempt to fire only during normal attack input.
  - [x] Stop attacking; offhand should stop.
  - [x] Confirm main normal attack still works.
  - [x] Exit battle and confirm no continued offhand activity.
- User Feedback: Accepted in game. User log showed `BattleStart event received`, `Offhand controlled trigger started. skillId=IIER7Z, baseId=11452`, three `Offhand fired from normal attack input...` messages, `BattleEnd event received`, and `Offhand controlled trigger stopped... fired=7`. User observed two overlapping projectiles and two attack damage instances. Offhand now triggers only when clicking/using normal attack; no autonomous idle firing was reported.
- Decision: Accepted. Controlled normal-attack-triggered offhand logic is valid; current dual-hand firing path has no known logic issue.
- Next Round: Proceed to `DWT-005 - Offhand Loadout Persistence Skeleton`.

### FW-20260627-06 - Offhand Loadout Persistence Skeleton

- Status: Awaiting Game Test
- Date: 2026-06-27
- User Request: Continue with the next DWT round.
- Test Case IDs: `DWT-005`; regression recheck `DWT-001` through `DWT-004`.
- Scope:
  - Add a MOD-owned, versioned save skeleton for offhand normal attack id.
  - Register `EGameType.IntoWorld` and `EGameType.SaveData` handlers for load/save lifecycle.
  - Use current main normal attack as a temporary offhand selection bootstrap if no saved offhand id exists yet.
  - Validate saved offhand id against learned normal attacks on battle start.
  - Keep DWT-004 controlled normal-attack trigger behavior unchanged.
- Non-Goals:
  - No Q wheel.
  - No selection UI.
  - No distinct main/offhand skill requirement yet.
  - No mastery, combat stamina, resource spending, damage tuning, or instability.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `src/ModCode/ModMain/DualWield/DualWieldSaveStore.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `README.md`.
- Compile Verification:
  - ApiProbe: Not run; persistence/event APIs were already compile-evidenced in `test/ApiProbe` and decompiled seed code.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD should load and register `IntoWorld`, `SaveData`, battle start, and battle end handlers without startup errors.
  - On first battle after no saved offhand exists, the current main normal attack should bootstrap into MOD-owned save keys and the start log should include `source=bootstrap-main`.
  - Saving the game should write `schemaVersion=1` and `offhandSkillId=<id>` under the MOD-owned save group.
  - After reload, entering battle should load the saved offhand id, validate it against learned normal attacks, and the start log should include `source=saved`.
  - DWT-004 behavior should remain: offhand fires only during normal attack input.
  - If a saved offhand id is missing from learned normal attacks, the MOD should clear only its own offhand key, skip offhand for that battle, and avoid crashing.
- Should Not Happen: No broad `g.data.obj` cleanup; no writes outside MOD-owned keys; no changed main-hand equip behavior.
- User Test Checklist:
  - [ ] Enter world and battle; if no saved offhand exists, current main normal attack should bootstrap into the MOD save skeleton.
  - [ ] Save the game.
  - [ ] Reload and enter battle again.
  - [ ] Confirm the first run logs `source=bootstrap-main` and the post-reload run logs `source=saved`.
  - [ ] Confirm DWT-004 still holds: offhand fires only during normal attack input.
- User Feedback: Pending.
- Decision: Built and handed off for DWT-005 runtime verification.
- Next Round: If accepted, proceed to `DWT-006 - Distinct Main And Offhand Normal Attack`; if not, open a rework round against `DWT-005`.

### FW-20260627-07 - DWT-005 Persistence Diagnostics And Offhand Delay

- Status: Feedback Received
- Date: 2026-06-27
- User Request: DWT-005 did not visibly prove save/load; add a 0.05s offhand delta so two projectiles are easier to see, and inspect decompiled UI selection references for later work.
- Test Case IDs: Rework `DWT-005`; small visual probe for future `DWT-007`; UI research note for future `DWT-006`/`DWT-008`.
- Scope:
  - Make save/load/bootstrap/saved persistence diagnostics visible enough for game testing.
  - Add a 0.05 second offhand create delay after normal attack input passes `IsCreate(...)`.
  - Record the discovered `MOD_Addk03` UI injection approach as evidence for later offhand selection UI work.
- Non-Goals:
  - No full UI implementation yet.
  - No Q wheel.
  - No distinct main/offhand selection logic yet.
  - No broad cooldown/resource/mastery system.
- Files Changed: `src/ModCode/ModMain/DualWield/DualWieldSaveStore.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/DATA_FIELD_RESEARCH.md`, `docs/AI_CONTEXT.md`.
- Compile Verification:
  - ApiProbe: Not run; no new uncertain API shape beyond Unity `Time.time`, existing timers, and already compiled persistence APIs.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - `Save loaded...` and `Save written...` diagnostics should now be visible tips as well as logs.
  - On the first no-save path, the player should see `Offhand save updated... reason=bootstrap-main` and `source=bootstrap-main`.
  - After saving/reloading, entering battle should show a loaded `offhandSkillId` and `source=saved` if the saved skill remains learned.
  - When normal attack is used, the offhand attack should queue first, then fire about `0.05s` later.
  - DWT-004 should still hold: no idle offhand firing.
- Should Not Happen: No idle offhand firing; no UI appears yet; no save writes outside MOD-owned keys.
- User Test Checklist:
  - [x] Enter world/battle and confirm visible bootstrap diagnostics.
  - [ ] Save and reload, then confirm visible loaded `offhandSkillId` and `source=saved`.
  - [x] Attack and confirm logs/tips show `Offhand queued... delay=0.05s` then `Offhand fired after delay...`.
  - [x] Confirm the offhand projectile appears about 0.05s after the main attack.
  - [x] Confirm offhand still does not fire while idle.
- User Feedback: Runtime log showed `Save written. version=1, offhandSkillId=aJ3P5u`, `Offhand save updated... reason=bootstrap-main`, `Offhand controlled trigger started... source=bootstrap-main`, and queued/fired pairs with `delay=0.05s`. User confirmed the delay is visible. User also noted there is still no way to choose an offhand attack, so the expected result is unclear beyond bootstrap behavior.
- Decision: Partial success. The visual delay and bootstrap write path are confirmed. Full DWT-005 remains incomplete until a real offhand selection path exists and reload can show `source=saved` for a user-selected offhand id.
- Next Round: Build the minimal offhand selection entry using the `MOD_Addk03` `OpenUIEnd`/`UIPlayerInfo` button injection pattern, then re-test DWT-005 and advance DWT-006.

### FW-20260627-08 - Minimal Offhand Selection Entry

- Status: Accepted
- Date: 2026-06-27
- User Request: Proceed with the next step after confirming delay and bootstrap behavior: add a way to choose offhand attack.
- Test Case IDs: Rework `DWT-005`; begin `DWT-006`; UI foundation for later `DWT-008`.
- Scope:
  - Add a minimal PlayerInfo skill UI button using the `MOD_Addk03` `OpenUIEnd` / `UIPlayerInfo` injection pattern.
  - Button stores the current main normal attack id into `DualWieldSaveStore.offhandSkillId`.
  - Update the button icon/tooltip from the saved offhand id when possible.
  - Preserve existing DWT-004 controlled trigger and 0.05s delay behavior.
- Non-Goals:
  - No Q wheel.
  - No candidate pool UI.
  - No automatic switching of the player's main skill.
  - No mastery/resource/stamina systems.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandSelectionUiController.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`.
- Compile Verification:
  - ApiProbe: Not run; the UI symbols were compile-verified directly in the real MOD project.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD should load with `FW-20260627-08` diagnostics.
  - Opening the player info / skill UI should inject one minimal DualWield offhand button near the normal attack slot.
  - Clicking the button should save the current main normal attack id as `offhandSkillId`, show/log `Offhand selected from current main normal attack`, and write the MOD save keys.
  - Reopening the player info / skill UI should not duplicate the button; it should replace/update the existing injected control.
  - After saving/reloading, entering battle should load the saved offhand id and start with `source=saved` if the skill is still learned.
  - Normal attack behavior remains from DWT-004/FW-07: offhand fires only during normal attack input and fires about `0.05s` after queueing.
- Should Not Happen: No battle behavior change except using the selected saved offhand id; no Q wheel; no candidate pool; no forced main-hand replacement; no broad UI mutation outside PlayerInfo skill UI; no duplicate injected buttons after reopening the UI.
- User Test Checklist:
  - [x] Open player info / skill UI and confirm a minimal DualWield offhand button appears near the normal attack slot.
  - [x] Equip/select a normal attack as current main, click the offhand button, and confirm a visible save/update message.
  - [x] Switch main normal attack to another learned normal attack if possible.
  - [x] Save/reload, enter battle, and confirm `source=saved`.
  - [x] Attack and confirm offhand can use the saved id path while main attack still works.
- User Feedback: Accepted with requested UI refinements. Runtime logs showed repeated `Offhand selected from current main normal attack`, `Save written. version=1, offhandSkillId=aJ3P5u`, and battle start `Offhand controlled trigger started... source=saved`. In battle, queued/fired offhand logs continued with `delay=0.05s`; the user observed correct dual firing and noted main/offhand cooldowns appear independent, so fast low-damage attacks do not drive slow high-damage attacks.
- Decision: Accepted for DWT-005 persistence and saved offhand battle start. Minimal selection works, but UX needs a small follow-up: selecting current main into offhand should unequip main, clicking current offhand should clear offhand, and offhand hover should show skill details.
- Next Round: `FW-20260627-09 - Offhand Toggle And Main Unequip`.

### FW-20260627-09 - Offhand Toggle And Main Unequip

- Status: Accepted
- Date: 2026-06-27
- User Request: Small UI interaction update: when setting current main as offhand in the main/player skill UI, unequip main as if clicking the main slot once; allow clicking the offhand button to remove the current offhand; show skill description when hovering the offhand button.
- Test Case IDs: Follow-up for `DWT-006`; UI foundation for later `DWT-008` to `DWT-010`; regression recheck `DWT-005`.
- Scope:
  - Change PlayerInfo offhand button click into a toggle.
  - If a current main normal attack exists and differs from saved offhand, save it as offhand and call `UnitActionMartialUnequip((MartialType)1, 0)` to clear main.
  - If there is no current main but an offhand exists, clear saved offhand.
  - If current main equals saved offhand, clear saved offhand rather than writing the same id again.
  - Build hover tooltip from saved offhand skill name plus localized `BattleSkillAttack.desc` when available.
- Non-Goals:
  - No Q wheel.
  - No candidate pool UI.
  - No change to battle firing/cooldown logic.
  - No mastery/resource/stamina systems.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandSelectionUiController.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `README.md`.
- Compile Verification:
  - ApiProbe: Not run; this uses previously compile-proven equip APIs plus real-project compile for `GameTool.LS` and tooltip string building.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-09`.
  - When a normal attack is equipped as main and the offhand button is clicked, that skill becomes saved offhand and the main normal attack slot should be unequipped/empty.
  - If the offhand button is clicked while no main normal attack is equipped but an offhand is saved, the saved offhand should clear and the button should visually empty.
  - If the current main is already the saved offhand, clicking the button should clear offhand instead of repeatedly saving the same id.
  - Hovering the offhand button should show the saved skill name and description when the saved skill is valid.
  - Battle behavior should remain as FW-08: saved offhand starts with `source=saved` and fires only during normal attack input.
- Should Not Happen: No forced re-equipping of an old offhand into main; no duplicate buttons; no battle fire-rate change; no Q wheel; no save writes outside MOD-owned keys.
- User Test Checklist:
  - [ ] Equip a normal attack as main, open player skill UI, click offhand button, and confirm main normal attack slot becomes empty.
  - [ ] Hover the offhand button and confirm skill name/description appears.
  - [ ] Click the offhand button again while no main is equipped and confirm offhand clears.
  - [ ] Select a saved offhand, save/reload, enter battle, and confirm `source=saved` still appears.
  - [ ] Attack and confirm offhand still fires under the existing normal-attack-input rule.
- User Feedback: Accepted. User reported the effect is very good. Skill description still needs polish, but can remain as-is for now.
- Decision: Accepted. The offhand slot behavior is good enough to start wheel design.
- Next Round: `FW-20260627-10 - Wheel Architecture And Prebattle Setup Design`.

### FW-20260627-10 - Wheel Architecture And Prebattle Setup Design

- Status: Docs Only
- Date: 2026-06-27
- User Request: Start designing the wheel. The skill setup screen should also have a wheel setup UI for prebattle configuration.
- Test Case IDs: Plan `DWT-021`, then prepare `DWT-008` through `DWT-011`.
- Scope:
  - Split the wheel system into prebattle setup UI and in-combat Q wheel.
  - Define normal attack candidate pool behavior, capped at 0-6 entries.
  - Add a serial test for prebattle candidate setup before combat Q wheel implementation.
  - Update MVP design and context docs to make the new sequence explicit.
- Non-Goals:
  - No MOD code changes.
  - No real project build required.
  - No Q wheel UI implementation yet.
  - No combat stamina, mastery, resource, or instability implementation.
- Files Changed: `docs/WHEEL_DESIGN.md`, `docs/DUAL_WIELD_DESIGN_MVP.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/FLYWHEEL_LOG.md`, `docs/AI_CONTEXT.md`, `README.md`.
- Compile Verification:
  - ApiProbe: Not required; docs-only design work.
  - Real MOD build: Not required; no source changes.
- Expected In-Game Behavior: No change.
- Should Not Happen: No generated game-project files, no `ideas/` upload, no runtime behavior change.
- User Test Checklist:
  - [ ] Review whether the prebattle setup UI plus combat Q wheel split matches the desired workflow.
  - [ ] Confirm whether candidate setup should start as a six-slot strip or a miniature radial preview.
- User Feedback: Pending.
- Decision: Docs-only design round completed. Next code-bearing round should implement `DWT-021` before the combat Q wheel.
- Next Round: `FW-20260627-11 - Prebattle Normal Wheel Candidate Store` or direct UI setup if store shape is simple enough.

### FW-20260627-11 - No Offhand Bootstrap Patch

- Status: Accepted
- Date: 2026-06-27
- User Request: If the player did not set an offhand before battle, the MOD must not copy main into offhand. Otherwise it becomes a pure double-hit damage boost. Future Q wheel selection may still assign a new offhand.
- Test Case IDs: Regression/guardrail for `DWT-005`, `DWT-006`, and prerequisite for `DWT-021` / wheel work.
- Scope:
  - Remove the battle-start `bootstrap-main` fallback.
  - If `DualWieldSaveStore.OffhandSkillId` is empty, skip offhand initialization for that battle.
  - Keep manual offhand selection via PlayerInfo button and future Q wheel paths intact.
  - Update runtime diagnostics to show `source=saved` only when an offhand was explicitly saved.
- Non-Goals:
  - No prebattle candidate pool UI yet.
  - No Q wheel implementation.
  - No battle cadence or cooldown changes.
  - No tooltip polish.
- Files Changed: `src/ModCode/ModMain/DualWield/OffhandController.cs`, `src/ModCode/ModMain/ModMain.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `README.md`, `docs/WHEEL_DESIGN.md`, `docs/DUAL_WIELD_DESIGN_MVP.md`.
- Compile Verification:
  - ApiProbe: Not run; no new API surface.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-11`.
  - If no offhand is saved, entering battle should log `Offhand skipped: no saved offhand selected.` and no offhand projectile/damage should occur.
  - Normal main attack should continue working by itself.
  - If the player explicitly selects an offhand before battle, entering battle should start offhand with `source=saved` and retain existing DWT-004 behavior.
  - Future Q wheel offhand selection may still write `offhandSkillId` and enable offhand.
- Should Not Happen: No `source=bootstrap-main`; no automatic main-to-offhand copy; no double hit unless offhand was explicitly selected.
- User Test Checklist:
  - [x] Clear current offhand from the PlayerInfo offhand button.
  - [x] Enter battle and attack; confirm only main attack fires.
  - [x] Check logs for `Offhand skipped: no saved offhand selected.` and absence of `source=bootstrap-main`.
  - [ ] Select an offhand manually, enter battle, and confirm `source=saved` still enables offhand.
- User Feedback: Accepted. User tested the main-only case after clearing offhand. Runtime log showed `Offhand skipped: no saved offhand selected.` and the main attack behavior was correct.
- Decision: Accepted. Empty offhand now stays empty and does not copy main into offhand.
- Next Round: Continue loadout guard testing through `FW-20260627-12` / `FW-20260627-13` before wheel work.

### FW-20260627-12 - Promote Saved Offhand To Main When Main Empty

- Status: Partial
- Date: 2026-06-27
- User Request: If entering battle with no main normal attack but a saved offhand, promote the offhand into main and clear the offhand setting. If both main and offhand are empty, do nothing. Future wheel slots may become blank after this replacement.
- Test Case IDs: Guardrail for `DWT-006`; prerequisite behavior for `DWT-021` and future wheel loadout cleanup.
- Scope:
  - On battle start, when `skillLeft` is empty and `offhandSkillId` is valid, set `skillLeft` to the saved offhand id.
  - Also call `UnitActionMartialEquip(..., 0)` for the promoted normal attack.
  - Clear `offhandSkillId` after promotion so this becomes single-hand main, not dual wield.
  - If both main and offhand are empty, skip without changing anything.
  - If saved offhand is missing/invalid, clear only the MOD offhand key.
  - If saved offhand equals current main, clear offhand and skip to avoid same-skill double hit.
- Non-Goals:
  - No prebattle candidate pool UI yet.
  - No Q wheel implementation.
  - No battle cadence or cooldown changes.
  - No tooltip polish.
- Files Changed: `src/ModCode/ModMain/DualWield/OffhandController.cs`, `src/ModCode/ModMain/ModMain.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `README.md`, `docs/WHEEL_DESIGN.md`, `docs/DUAL_WIELD_DESIGN_MVP.md`, `docs/DATA_FIELD_RESEARCH.md`.
- Compile Verification:
  - ApiProbe: Not run; uses previously compile-proven `UnitActionMartialEquip` path.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-12`.
  - If main is empty and offhand is saved, entering battle should equip/promote saved offhand as main and clear offhand.
  - The same battle should not initialize offhand or fire dual attacks from that promoted skill.
  - If both main and offhand are empty, the MOD should not change loadout and should skip offhand.
  - If main and offhand are both valid and distinct, existing `source=saved` dual wield behavior remains.
- Should Not Happen: No same-skill double hit; no saved offhand remains after promotion; no crash if both slots are empty.
- User Test Checklist:
  - [x] Set a skill as offhand, then make the main normal attack slot empty.
  - [x] Enter battle and confirm the former offhand becomes main after the transition.
  - [x] Confirm offhand is cleared and no offhand projectile/damage fires in that same battle.
  - [x] Enter with both main/offhand empty and confirm the MOD does not change loadout or crash.
  - [x] Enter with distinct main/offhand and confirm `source=saved` still works.
- User Feedback: Partially accepted with one timing defect. User confirmed distinct main/offhand is correct and both-empty is correct. In the offhand-only case, logs showed the saved offhand was promoted and cleared, and after leaving battle the main slot had become the former offhand. However, during that same battle the martial skill did not display and normal attack could not be used.
- Decision: Partial. Save/load and loadout state transitions are correct, but doing the promotion inside `EBattleType.BattleStart` is too late for the current battle's skill UI/control initialization.
- Next Round: `FW-20260627-13 - Pre-Battle Offhand Promotion Prefix`.

### FW-20260627-13 - Pre-Battle Offhand Promotion Prefix

- Status: Accepted
- Date: 2026-06-27
- User Request: Fix the offhand-only case: entering battle after promoting saved offhand to main should make that promoted skill usable in the same battle, not only after exiting.
- Test Case IDs: Rework `DWT-006` loadout guard; regression recheck `DWT-004`, `DWT-005`, and `FW-20260627-11`.
- Scope:
  - Add a shared `DualWieldLoadoutGuard` for main-empty/offhand-saved promotion.
  - Add a Harmony prefix on all `WorldBattleMgr.IntoBattle` overloads so promotion happens before battle objects and UI/skill controllers initialize.
  - Keep the old battle-start path as a fallback only.
  - Update visible MOD diagnostics to `FW-20260627-13`.
- Non-Goals:
  - No Q wheel implementation.
  - No prebattle candidate pool UI yet.
  - No changes to offhand firing cadence, cooldown, mastery, stamina, or resource systems.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `src/ModCode/ModMain/DualWield/DualWieldLoadoutGuard.cs`, `src/ModCode/ModMain/DualWield/WorldBattleLoadoutPatch.cs`, `docs/FLYWHEEL_LOG.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `README.md`, `docs/DEVELOPMENT_WORKFLOW.md`.
- Compile Verification:
  - ApiProbe: Not run; `WorldBattleMgr.IntoBattle` overloads were inspected from the real generated `Assembly-CSharp.dll` with `Mono.Cecil` and compile-verified directly in the real MOD project.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-13`.
  - If main is empty and offhand is saved, the saved offhand should promote to main before the battle scene initializes.
  - In that same battle, the promoted main skill should display and normal attack should be usable.
  - Offhand should be cleared after promotion, so the same battle should remain single-hand and should not fire offhand projectiles/damage.
  - Main-only, both-empty, and distinct main/offhand cases should remain as previously confirmed.
- Should Not Happen: No `source=bootstrap-main`; no same-skill double hit; no offhand projectile in the promoted-single-hand battle; no crash from patching battle entry.
- User Test Checklist:
  - [x] Confirm startup/init logs show `FW-20260627-13`.
  - [x] Set a skill as offhand, leave main empty, enter battle, and confirm the promoted skill appears in the battle UI.
  - [x] Attack in that same battle and confirm normal attack works as main.
  - [x] Confirm offhand is cleared and no second/offhand projectile fires in that battle.
  - [x] Recheck main-only, both-empty, and distinct main/offhand cases if convenient.
- User Feedback: Accepted. User clarified that the FW-13 change works very well: the saved offhand can become the main normal attack and can be used in that same battle. The remaining concern is future in-combat wheel switching, not the pre-battle promotion guard.
- Decision: Accepted. Pre-battle offhand promotion through the `WorldBattleMgr.IntoBattle` prefix is the correct timing for the offhand-only loadout guard.
- Next Round: `FW-20260627-14 - DWT-022 Experience Attribution Diagnostic` before combat wheel main/offhand switching.

### FW-20260627-14 - DWT-022 Experience Attribution Diagnostic

- Status: Accepted
- Date: 2026-06-27
- User Request: Before wheel switching and mastery growth, verify whether the current offhand `SkillAttack.Create(...)` path gives experience to the offhand skill, gives it to main, or gives no experience.
- Test Case IDs: `DWT-022`; regression check for `DWT-004`, `DWT-005`, and `DWT-006`.
- Scope:
  - Document the skill trigger consistency contract: selected learned instance, runtime object, cooldown owner, resource-cost owner, creation context, hit/effect attribution, experience recipient, and UI/input/action state must agree.
  - Add read-only diagnostics around offhand battle initialization and the first few offhand fires.
  - Log main/offhand learned ids, base ids, `ActionMartialData.exp`, runtime `offhandSkill.data.actionMartialData` binding, and `UnitCtrlPlayer.martialUseAddExp` values.
  - Log a battle-end summary for the same fields.
- Non-Goals:
  - No manual experience writes.
  - No combat wheel, candidate setup, stamina, resource, damage, cooldown, or cadence changes.
  - No fix yet for missing/wrong offhand experience; this round only classifies the runtime behavior.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, `docs/DUAL_WIELD_DESIGN_MVP.md`, `docs/WHEEL_DESIGN.md`, `docs/DATA_FIELD_RESEARCH.md`, `docs/SERIAL_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `docs/FLYWHEEL_LOG.md`.
- Compile Verification:
  - ApiProbe: Not run; real project compile verifies the used runtime properties.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-14`.
  - Existing offhand behavior should remain the same: no offhand unless selected, distinct offhand still fires from normal attack input with the existing delay.
  - When entering battle with distinct main/offhand, logs should include `DWT-022 start` and `DWT-022 runtime binding`.
  - For the first few offhand fires, logs should include `DWT-022 fire snapshot`; if exp or pending-use-exp values change later, logs should include `DWT-022 exp change`.
  - On battle end/destroy, logs should include `DWT-022 summary`.
- Should Not Happen: No change in damage, projectile cadence, loadout selection, save shape, or manual proficiency gain. No duplicate experience created by the diagnostic.
- User Test Checklist:
  - [x] Confirm startup/init logs show `FW-20260627-14`.
  - [x] Prepare two distinct learned normal attacks: A as main, B as offhand.
  - [x] Enter battle and attack until offhand fires several times and preferably hits.
  - [ ] Exit battle so the `DWT-022 summary` line appears.
  - [x] Report the `DWT-022 start`, `runtime binding`, `fire snapshot`, and `exp change` log lines.
- User Feedback: Accepted as diagnostic. User observed both main-left-click and offhand-left-click attacks causing damage and kills. Logs show `runtimeBinding=offhand`, `runtimeSoleId=aldsra`, and `runtimeBaseId=14111`, so the MOD-created `SkillAttack` is bound to the saved offhand runtime martial data. However `offhandExp`, `runtimeExp`, and `offhandUseAddExp` remained `0`, while `mainExp` and `mainUseAddExp` changed through the fight.
- Decision: DWT-022 successfully classified the current behavior as `no native offhand exp`. The visual/projectile/damage path is correct, and the offhand runtime binding is correct, but `SkillAttack.Create(...)` alone does not make the base game award proficiency to the offhand learned skill. The main experience growth in the logs is consistent with the native main attack path and does not prove that offhand experience was added to main.
- Next Round: Add a narrow correction test for offhand experience attribution before wheel main/offhand switching. Candidate path: call or hook the native `UnitCtrlPlayer.AddSkillMartialExp(...)` only after a confirmed offhand create/use event, with guards against duplicate growth.

### FW-20260627-15 - DWT-023 Offhand Attribution Guard

- Status: Awaiting Game Test
- Date: 2026-06-27
- User Request: DWT-022 exposed that empty main swings can still increase main skill experience during dual wield, and main blade lifesteal/effects may leak onto offhand sword damage. Empty A experience is a MOD bug and must be blocked, not merely hidden in logs.
- Test Case IDs: `DWT-023`; rechecks `DWT-004`, `DWT-005`, `DWT-006`, and the `DWT-022` diagnostic fields.
- Scope:
  - Keep explicit offhand `SkillCreateData` on `SkillAttack.Create(...)` so hit attribution can report `createSkillBase`, `skillCreateSoleID`, `mainSkillID`, weapon/magic type, and damage values.
  - Add hit attribution diagnostics through `EBattleType.UnitHitDynIntHandler` for offhand or near-offhand hit events.
  - Add `DualWieldAttributionGuard`, armed only while distinct main/offhand normal attacks are active.
  - Harmony-patch both `UnitCtrlPlayer.AddSkillMartialExp(...)` overloads and skip positive experience only when the target is the current main skill during a short offhand queue/create/hit protection window.
  - Restore DWT-022 exp-change logging for main changes too, so pollution remains visible during the test.
- Non-Goals:
  - No manual offhand experience award yet.
  - No Q wheel, candidate pool, stamina, resource, damage-balance, or mastery growth implementation.
  - No broad disabling of all main skill experience; the guard is intentionally narrow and may need another pass if the game writes empty-A experience before the offhand window opens.
- Files Changed: `src/ModCode/ModMain/DualWield/DualWieldAttributionGuard.cs`, `src/ModCode/ModMain/DualWield/SkillMartialExpPatch.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, plus docs.
- Compile Verification:
  - ApiProbe: Not run; the real MOD project compile verified the Harmony patch signatures and new runtime references.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-15`.
  - Distinct main/offhand normal attacks should still fire as before, with the existing 0.05s offhand delay.
  - Battle start should log `DWT-023 attribution guard armed` when both main and offhand are valid and distinct.
  - If the offhand hit path tries to add positive experience to the main skill during the guarded window, the log should show `DWT-023 blocked main exp during offhand window` and main empty-swing experience should stop increasing from that MOD path.
  - `DWT-023 hit attribution` logs should help classify whether offhand hits still look like main hits, including `suspiciousMainSkill`, `weaponType`, `magicType`, `hitSkill`, and `createSkill`.
  - Offhand experience is still expected to remain missing until a later explicit offhand proficiency correction test.
- Should Not Happen: No crash on battle start/end; no offhand when `offhandSkillId` is empty; no same-skill double hit; no global blocking of normal main experience outside the guarded offhand windows.
- User Test Checklist:
  - [ ] Confirm startup/init logs show `FW-20260627-15`.
  - [ ] Equip main blade and offhand sword as before; enter battle and attack with hits and with at least one observable empty main swing if possible.
  - [ ] Report whether `DWT-023 attribution guard armed` appears.
  - [ ] Report any `DWT-023 blocked main exp during offhand window` lines.
  - [ ] Report `DWT-023 hit attribution` lines, especially `suspiciousMainSkill`, `weaponType`, `magicType`, `hitSkill`, and `createSkill`.
  - [ ] Check whether the main skill experience still rises from empty A / offhand-only hits.
- Runtime Feedback 1:
  - User reported the first offhand hit after `FW-20260627-15`.
  - Battle start correctly logged `DWT-023 attribution guard armed` for `mainSkillId=qorQok` and `offhandSkillId=aldsra`.
  - `DWT-023 create snapshot` and `DWT-023 hit attribution` both showed offhand base `mainSkillID=14111`, `phy=83`, `weaponType=3`, and `magicType=0`.
  - Hit attribution showed `matchesOffhandSkill=True`, `createSoleMatches=True`, `nearOffhandCreate=True`, and `suspiciousMainSkill=False`.
  - The first `DWT-022 fire snapshot` showed `main=0->0`, `offhand=0->0`, `runtime=0->0`, so this first offhand fire did not add main or offhand experience.
  - Interim reading: first offhand hit attribution looks clean and does not support SkillBase-level main-hand leakage. Need more samples to confirm whether empty-A main exp still rises, whether `blocked main exp` appears, and whether observed blade lifesteal is from another hit/effect path.
- Runtime Feedback 2:
  - User reported a later offhand-hit result: `DWT-022 exp change` at `fired=36` showed `runtimeBinding=offhand`, `main=237->243`, `offhand=0->0`, and `runtime=0->0`; the main key caused no damage, yet main experience increased.
  - User screenshot also showed `DWT-023 blocked main exp during offhand window` for `overload=actionData`, `target=qorQok`, `talent=23`, `growExp=1.4`, proving the Harmony patch caught at least one native experience API call.
  - However main experience still rose after blocking, and `mainUseAddExp` changed in DWT-022 logs. Classification: DWT-023 partially works but is insufficient; another path or delayed pending-exp state still pollutes main experience.
  - Rework direction: add a main `ActionMartialData.exp` and `martialUseAddExp[mainSkillId]` rollback after offhand-attributed hits, while preserving real main-hit baselines when hit attribution clearly belongs to main.
- Decision: Pending runtime feedback.

### FW-20260628-01 - Offline API Library Inspection Tooling

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Check whether the official `GGBH_API.chm` is useful as a higher-level API calling library and whether it can join the no-manual-operation investigation workflow.
- Test Case IDs: None; supports future `DWT-025` BattleTrace and API research.
- Scope:
  - Added `tools/index-ggbh-api-chm.ps1` to decompile/index the official CHM into local generated output.
  - Added `generated/` to `.gitignore` because CHM/dnSpy/Cecil outputs are reproducible, large, local, and include machine paths.
  - Updated `README.md`, `docs/DEVELOPMENT_WORKFLOW.md`, `docs/COMBAT_SYSTEM_INSPECTION_PLAN.md`, `docs/DATA_FIELD_RESEARCH.md`, `docs/AI_CONTEXT.md`, and `dual_wield_mod_skill.md` with the CHM/Cecil/dnSpy offline inspection layer.
- Verification:
  - `tools/index-ggbh-api-chm.ps1 -SkipDecompile` completed and generated `generated/GGBH_API_CHM_INDEX.md` plus JSON from about 110k CHM files.
  - PowerShell parser checks passed for `index-ggbh-api-chm.ps1`, `inspect-combat-system.ps1`, and `export-dnspy-types.ps1`.
  - `git check-ignore` confirms `generated/` outputs are ignored.
  - `git diff --check` passed; only CRLF normalization warnings were reported.
- Findings:
  - The CHM is useful for symbol/signature discovery and confirms pages for `AddSkillMartialExp`, `martialUseAddExp`, `AddMartialExpInBattle`, `SkillAddExp`, `UnitHitDynIntHandler`, `UnitEffectSkillHpSuck`, `OneUnitHitSkill`, `OneUnitUseSkillAttack`, `SkillCreateData`, `MissileShotData`, and `SkillDataAttack.actionMartialData`.
  - The CHM does not prove runtime event order or state mutation; ApiProbe and in-game DWT traces remain required for behavior.
- Compile Verification: Not run; no MOD source behavior changed in this tooling/docs round.
- Decision: CHM joins the standard offline first pass before ApiProbe and runtime BattleTrace.
- Next Round: If main empty-A experience is still rising without `blocked main exp` logs, move the guard earlier or identify the native experience source. If blocking works, continue investigating leaked main passive/effect attribution before adding offhand experience correction.

### FW-20260627-16 - DWT-024 Main Exp Rollback Guard

- Status: Awaiting Game Test
- Date: 2026-06-27
- User Request: DWT-023 still allows main experience to increase from offhand-bound hits even when the main key caused no damage. Screenshot proves `AddSkillMartialExp(actionData)` can be blocked, but another pending/settlement path still changes main experience or `martialUseAddExp`.
- Test Case IDs: `DWT-024`; rechecks `DWT-022` and `DWT-023`.
- Scope:
  - Upgrade `DualWieldAttributionGuard` from API-blocking only to API-blocking plus rollback.
  - Snapshot main `ActionMartialData.exp` and `UnitCtrlPlayer.martialUseAddExp[mainSkillId]` before offhand queue/create.
  - When `UnitHitDynIntHandler` classifies a hit as offhand-attributed, schedule a short rollback window that restores main exp and pending use exp if they changed.
  - Keep the guard active even after the hit diagnostic log limit is reached; logging can stop, behavior cannot.
  - If a hit is clearly attributed to main runtime skill, refresh the baseline and skip rollback briefly so real main hits are not erased.
  - Bump visible diagnostics to `FW-20260627-16` and guard logs to `DWT-024`.
- Non-Goals:
  - No offhand experience award yet.
  - No Q wheel or candidate setup.
  - No attempt to solve lifesteal/passive leakage unless the new hit logs still show attribution mismatch.
- Files Changed: `src/ModCode/ModMain/ModMain.cs`, `src/ModCode/ModMain/DualWield/DualWieldAttributionGuard.cs`, `src/ModCode/ModMain/DualWield/OffhandController.cs`, plus docs.
- Compile Verification:
  - ApiProbe: Not run; real project compile verified dictionary read/write/remove and the expanded guard.
  - Real MOD build: Passed Release build with `0 error` and only the known 6-warning baseline. Output: `D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject\ModCode\ModMain\bin\Release\MOD_h6Zv8g.dll`.
- Expected In-Game Behavior:
  - MOD init logs should show `FW-20260627-16`.
  - Battle start should log `DWT-024 attribution guard armed` for distinct main/offhand skills.
  - Offhand still fires and damages as before.
  - If main exp or `mainUseAddExp` changes after an offhand-attributed hit, logs should show `DWT-024 rolled back main exp pollution`.
  - After rollback, later `DWT-022 exp change` lines should not retain main experience increases caused only by offhand hits.
  - `DWT-024 blocked main exp during offhand window` may still appear for API calls that are caught directly.
- Should Not Happen: No crash; no offhand disablement; no rollback of legitimate main-hit experience when the main attack actually hits and is attributed to main runtime skill.
- User Test Checklist:
  - [ ] Confirm startup/init logs show `FW-20260627-16`.
  - [ ] Enter battle with the same main blade/offhand sword setup.
  - [ ] Attack enough times to reproduce the earlier offhand-bound main exp gain.
  - [ ] Report any `DWT-024 blocked main exp` and `DWT-024 rolled back main exp pollution` lines.
  - [ ] Report a later `DWT-022 exp change` line after several offhand hits.
  - [ ] Check whether main experience still increases when only the offhand hit dealt damage.
- Decision: Pending runtime feedback.

### FW-20260628-02 - AIT/KEP Toolchain Separation

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Split low-level API/core/source investigation out of DWT into `AIT` and `KEP`; automate dnSpy/Cecil/resource indexing capability checks; keep `resource/` and generated decompilation output out of Git.
- Test Case IDs: None; this is a pre-DWT evidence/tooling round.
- Scope:
  - Added `docs/KEY_EVIDENCE_PROBE_PLAN.md` with `KEP-001` through `KEP-004` and evidence levels: `Confirmed Symbol`, `Compile Confirmed`, `Runtime Confirmed`, `Rejected`, and `Unknown`.
  - Added/finished AIT tooling: `tools/decompile-dotnet-assembly.ps1`, `tools/inventory-dotnet-assemblies.ps1`, and `tools/index-resource-knowledge.ps1`.
  - Updated `.gitignore`, `README.md`, `docs/API_TOOLCHAIN_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, `docs/DEVELOPMENT_WORKFLOW.md`, `docs/COMBAT_SYSTEM_INSPECTION_PLAN.md`, `docs/DATA_FIELD_RESEARCH.md`, and `dual_wield_mod_skill.md` for the new `AIT -> KEP -> DWT` boundary.
  - Kept `resource/` and `generated/` as local ignored material; no external decompiled MOD business logic was absorbed into project design.
- Verification:
  - PowerShell parser checks passed for `decompile-dotnet-assembly.ps1`, `inventory-dotnet-assemblies.ps1`, `index-resource-knowledge.ps1`, `index-ggbh-api-chm.ps1`, `inspect-combat-system.ps1`, `export-dnspy-types.ps1`, and `test/ApiProbe/build.ps1`.
  - `AIT-001` passed: dnSpy exported `resource/Mod解包结果/SaiLL.dll -> A7T.t7w` with `exitCode=0`; output contains `namespace A7T`, `internal class t7w : c9f`, `public override GameObject Hgc(GameObject template)`, `foreach (SpriteRenderer ...)`, image-load calls as `texture.LoadImage(...)`, and `return template;`.
  - `AIT-002` passed: full `SaiLL.dll` export produced `80` files, `75` C# source files, `35` namespaces, and `91` types plus `source-manifest.json`.
  - `AIT-003` passed: MelonLoader census scanned `387` DLLs; `381` managed and `6` native/unreadable. Focus assemblies were found: `MelonLoader.dll`, `0Harmony.dll`, `MonoMod.RuntimeDetour.dll`, `Assembly-CSharp.dll` from both Managed and Cpp2IL, and `SaiLL.dll`.
  - `AIT-004` passed: Cecil inventory classified `MelonLoader/Managed/Assembly-CSharp.dll` as an IL2CPP interop wrapper with method bodies that are not original game logic, and `Cpp2IL/cpp2il_out/Assembly-CSharp.dll` as Cpp2IL structure/stub output. `inspect-combat-system.ps1` regenerated the combat static report.
  - `AIT-005` passed: `test/ApiProbe/build.ps1 -ReferenceDir .\resource\app\MelonLoader\Managed` compiled successfully, proving ApiProbe remains a compile contract rather than a decompiler.
  - `tools/index-resource-knowledge.ps1` generated the local resource knowledge index under ignored `generated/resource-knowledge-index/`.
- Findings:
  - dnSpy is confirmed as a full C# body decompiler for ordinary managed / MelonLoader MOD DLLs in this environment.
  - Cecil and dnSpy have distinct roles: Cecil is best for fast inventory and body coverage; dnSpy is best for readable function bodies when the assembly actually contains useful managed logic.
  - ApiProbe is not Cecil; it is a Roslyn compile validator for candidate MOD call sites.
  - `SaiLL_human_dnspy` is valid as a capability comparison sample. `Token/RVA/File Offset` are metadata comments; `nBB.xBl(...)` constants are string-obfuscation/decryption inputs, not machine code.
- Compile Verification: No real MOD build was required because no gameplay source was changed. ApiProbe compiled successfully.
- Decision: AIT is established as the offline capability layer. Next low-level work should run `KEP-001` and `KEP-002` before opening a new DWT runtime trace.

### FW-20260628-03 - AIT-006 SaiLL String Annotation

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Extend AIT so `SaiLL` `nBB.xBl(...)` string-obfuscation constants can be resolved and annotated back into the decompiled source, while remembering that `nBB` is a `SaiLL` helper method and only a methodological reference.
- Test Case IDs: `AIT-006`; no DWT gameplay behavior changed.
- Scope:
  - Added `tools/annotate-obfuscated-strings.ps1`.
  - Added `AIT-006 - Obfuscated String Annotation` to `docs/API_TOOLCHAIN_TEST_PLAN.md`.
  - Updated `docs/AI_CONTEXT.md` to record the boundary: `nBB` is a `SaiLL` helper/embedded-resource string decoder, not a game-kernel API or DualWieldMod business conclusion.
- Verification:
  - PowerShell parser check passed for `tools/annotate-obfuscated-strings.ps1`.
  - Ran `tools/annotate-obfuscated-strings.ps1 -AssemblyPath .\resource\Mod解包结果\SaiLL.dll -InputDir .\generated\ait\AIT-002\SaiLL\SaiLL -OutputDir .\generated\ait\AIT-006-string-annotations\SaiLL`.
  - Result: scanned `75` C# files, annotated `53` files, found `1346` `nBB.xBl(...)` calls, decoded `1346`, errors `0`, with `440` unique decoded values.
  - Sample output `generated/ait/AIT-006-string-annotations/SaiLL/A7T/t7w.cs` now shows comments such as `/* "Load:" */`, `/* "/" */`, `/* ".png" */`, `/* ".dat" */`, `/* "没有修改部位" */`, and `/* "已经修改部位：" */`.
- Findings:
  - `nBB.xBl(int)` maps integer expressions to offsets in a `SaiLL.dll` embedded resource-backed Unicode string table.
  - The tool uses a local reflection call against `SaiLL.dll` and sets the sample-local `KR9` guard counter to avoid the first-call caller-assembly check. It does not modify the DLL and does not launch the game.
  - This capability is useful for reading external MOD code more efficiently, especially paths, UI names, log strings, and environment/system-value access patterns.
- Compile Verification: No real MOD build was required. This was offline AIT tooling only.
- Decision: AIT can now produce an annotated readable copy of the `SaiLL` decompilation. Treat annotations as external sample evidence only.

### FW-20260628-04 - AIT-007 Focused System DLL Parse

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Decide whether the toolchain is now enough, given dnSpy's richer system DLL output, and begin parsing focused system DLL surfaces so static evidence can be compared with dynamic DWT logs.
- Test Case IDs: `AIT-007`; no DWT gameplay behavior changed.
- Scope:
  - Exported focused combat-system types from `resource/app/MelonLoader/Managed/Assembly-CSharp.dll` and `resource/app/MelonLoader/Dependencies/Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out/Assembly-CSharp.dll` into ignored `generated/ait/AIT-007-system-dll-parse/`.
  - Added tracked report `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md` with the static/dynamic evidence table.
  - Updated `docs/API_TOOLCHAIN_TEST_PLAN.md`, `docs/COMBAT_SYSTEM_INSPECTION_PLAN.md`, `docs/KEY_EVIDENCE_PROBE_PLAN.md`, `docs/DATA_FIELD_RESEARCH.md`, and `docs/AI_CONTEXT.md` to point future KEP work at the AIT-007 report.
- Verification:
  - Managed wrapper export completed for key focused types including `UnitCtrlPlayer`, `BattleDataMgr`, `UnitActionRoleBattle`, `SkillAttack`, `SkillBase`, `SkillDataAttack`, `DataUnit`, `SkillCreateData`, `MissileShotData`, `HitData`, `UnitCtrlBase`, `WorldUnitBase`, and key `EBattleTypeData` types.
  - Cpp2IL structure/stub export completed for the same focused type set.
  - Nested selectors `DataUnit.UnitInfoData` and `DataUnit.ActionMartialData` returned selector exit code `1`, but their members are present in the exported `DataUnit.cs`; this is recorded as a selector limitation rather than missing evidence.
  - Generated outputs remain under ignored `generated/`.
- Findings:
  - The current toolchain is sufficient for focused offline combat-system inspection: Cecil/CHM for discovery, dnSpy for readable type views, ApiProbe for compile contracts, and DWT for runtime truth.
  - AIT-007 statically confirms the main attribution surfaces needed by KEP-001/002: `SkillAttack.Create(..., SkillCreateData)`, `SkillDataAttack.actionMartialData`, `SkillCreateData`, `MissileShotData.skillCreateData`, `MartialTool.HitData`, `UnitEffectSkillHpSuck`, `UnitCtrlPlayer.AddSkillMartialExp`, `martialUseAddExp`, `DataUnit.UnitInfoData.AddMartialExpInBattle`, and `UnitActionRoleBattle.SkillAddExp`.
  - The Managed assembly is IL2CPP wrapper/API-shape evidence and the Cpp2IL assembly is structure/stub evidence. Neither proves original branch logic, event order, delayed exp settlement, or passive-effect attribution without runtime trace.
- Compile Verification: No real MOD build was required because no gameplay source was changed. ApiProbe was not rerun in this round; AIT-005 remains the current compile-contract baseline.
- Decision: Use `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md` as the shared static evidence entry point. Next low-level work should run KEP-001 and KEP-002 compile probes before opening another DWT runtime trace.

### FW-20260628-05 - AIT-008 GameAssembly Native Boundary

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Test whether `GameAssembly.dll` can be decompiled directly by dnSpy, using the PE view evidence as a starting point.
- Test Case IDs: `AIT-008`; no DWT gameplay behavior changed.
- Scope:
  - Located real game `GameAssembly.dll` and `global-metadata.dat`.
  - Ran .NET assembly manifest check, direct dnSpy focused type export, direct dnSpy full export, PE header/CLR data-directory checks, and Cpp2IL dummy DLL generation.
  - Updated `docs/API_TOOLCHAIN_TEST_PLAN.md`, `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`, and `docs/AI_CONTEXT.md` with the native-boundary result.
- Verification:
  - `.NET AssemblyName.GetAssemblyName(GameAssembly.dll)` failed: module expected to contain an assembly manifest.
  - Direct dnSpy Console command `-t UnitCtrlPlayer GameAssembly.dll` failed with `GameAssembly.dll 不是 .NET 文件`.
  - Direct dnSpy full export of `GameAssembly.dll` failed with the same `不是 .NET 文件` error.
  - PE evidence from the user paste and local parser: `Machine=0x8664`, `PE32+`, has an `il2cpp` section, `.NET.VirtualAddress=0`, `.NET.Size=0`, `HasClrRuntimeHeader=False`.
  - Cpp2IL successfully read `GameAssembly.dll + global-metadata.dat`, detected Unity `2020.3.9`, metadata `27.1`, found `codereg`/`metareg`, mapped `139476` method definitions, and generated `65` dummy DLL assemblies under ignored `generated/ait/AIT-008-cpp2il-gameassembly/`.
  - dnSpy focused export from the Cpp2IL dummy `Assembly-CSharp.dll` works, but key methods such as `UnitCtrlPlayer.AddSkillMartialExp` and `SkillAttack.Create` have empty/default bodies.
- Findings:
  - The pasted PE text is useful PE structure evidence, not C# function-body decompilation.
  - This installed dnSpy Console cannot directly decompile native `GameAssembly.dll` into C# source. It can parse managed DLLs and Cpp2IL-generated dummy DLLs.
  - Cpp2IL is the correct installed offline path for reconstructing IL2CPP managed type/field/method shapes from `GameAssembly.dll`, but its dummy DLL output is not original game logic.
  - If exact native branch logic is needed later, open a separate native-analysis spike using Cpp2IL method addresses/tokens plus a native disassembler/decompiler, then still verify through DWT runtime trace.
- Compile Verification: No real MOD build was required because no gameplay source was changed.
- Decision: Keep using AIT/KEP static evidence for symbol discovery and hook design, but do not treat dnSpy PE view or Cpp2IL dummy DLL bodies as accurate source-level logic.

### FW-20260628-06 - AIT-009 MelonLoader Managed Source Corpus

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Batch-decompile readable managed DLLs under the real `MelonLoader` directory so future static source search can be automated.
- Test Case IDs: `AIT-009`; no DWT gameplay behavior changed.
- Scope:
  - Added `tools/batch-decompile-managed-assemblies.ps1`.
  - Generated an ignored high-value source corpus under `generated/ait/AIT-009-melonloader-managed-source/`.
  - Updated `docs/API_TOOLCHAIN_TEST_PLAN.md` and `docs/AI_CONTEXT.md` with the corpus location, counts, and search commands.
- Verification:
  - Parser check passed for `tools/batch-decompile-managed-assemblies.ps1`.
  - Smoke run decompiled `0Harmony.dll`, `MelonLoader.dll`, and `Mono.Cecil.dll` successfully.
  - High-value corpus currently includes `28` managed DLLs, `4575` C# source files, `5069` types, and `0` failed assemblies.
  - Included core search targets: `MelonLoader.dll`, `0Harmony.dll`, `Mono.Cecil*`, `MonoMod.RuntimeDetour`, `MonoMod.Utils`, `UnhollowerBaseLib`, `UnhollowerRuntimeLib`, `Cpp2IL.Core`, `LibCpp2IL`, `AsmResolver*`, `Il2CppAssemblyGenerator`, `AssetsTools.NET`, and related support DLLs.
  - `rg` search against the generated corpus finds expected source such as `Harmony.PatchAll`, `MonoMod.RuntimeDetour`, and `MelonLoader.UnhollowerSupport`.
- Generated Output:
  - `generated/ait/AIT-009-melonloader-managed-source/SOURCE_INDEX.md`
  - `generated/ait/AIT-009-melonloader-managed-source/batch-manifest.json`
  - `generated/ait/AIT-009-melonloader-managed-source/source-roots.txt`
- Findings:
  - The managed MelonLoader/toolchain layer is now searchable locally as source-like C#.
  - This corpus is useful for understanding MOD loading, Harmony patching, runtime detours, Unhollower/Il2Cpp wrapper support, and Cpp2IL processing internals.
  - It does not replace game business-logic runtime traces; it explains the loader/toolchain layer.
- Compile Verification: No real MOD build was required because no gameplay source was changed.
- Decision: Use the AIT-009 corpus as the first static-search target for loader/toolchain/API mechanics before reaching for broader decompilation or runtime experiments.

### FW-20260628-07 - AIT-010 MelonLoader Managed Parallel Corpus

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Extend the batch decompiler to cover the much larger real `MelonLoader/Managed` directory with parallel parsing, because that directory has about two hundred managed files and includes the important game wrapper assemblies.
- Test Case IDs: `AIT-010`; no DWT gameplay behavior changed.
- Scope:
  - Upgraded `tools/batch-decompile-managed-assemblies.ps1` with `-Parallel` and `-ThrottleLimit`.
  - Generated a full ignored source corpus under `generated/ait/AIT-010-managed-source/`.
  - Updated `docs/API_TOOLCHAIN_TEST_PLAN.md`, `docs/AI_CONTEXT.md`, and `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md` to record the new corpus and its boundary.
- Verification:
  - Parallel smoke run succeeded for `0Harmony.dll`, `MelonLoader.dll`, and `Mono.Cecil.dll`.
  - Full incremental run over `D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed` completed in about `132` seconds after resuming from the first long run.
  - Corpus totals: `206` DLLs considered, `205` managed DLLs, `1` native/unreadable skipped, `40361` C# source files, and `58292` indexed types.
  - `Assembly-CSharp.dll` decompiled successfully into wrapper source with `7960` C# files and `15035` types.
  - `20` UnityEngine module wrapper assemblies are `manifest-missing`; this is not blocking for current combat/API investigation.
- Generated Output:
  - `generated/ait/AIT-010-managed-source/SOURCE_INDEX.md`
  - `generated/ait/AIT-010-managed-source/batch-manifest.json`
  - `generated/ait/AIT-010-managed-source/source-roots.txt`
- Findings:
  - The project now has a local, searchable source-like corpus for the full `MelonLoader/Managed` wrapper/API layer.
  - This corpus is especially useful for fast `rg` searches over `Assembly-CSharp`, Unity/System support assemblies, and IL2CPP wrapper support code.
  - `Assembly-CSharp` output remains wrapper/API-shape evidence, not original native game branch logic; DWT runtime traces are still required for event order and state mutation truth.
- Compile Verification: No real MOD build was required because no gameplay source was changed.
- Decision: Use `AIT-010` for broad wrapper/API symbol search before KEP compile probes; continue using `AIT-009` for loader/toolchain internals.

### FW-20260628-08 - AIT-011 Official/Community dnSpy Corpus

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Reorganize generated dnSpy output into a reusable local corpus split as `app/official` and `app/community`, include `MelonLoader/Dependencies`, create `community/SaiLL`, decouple string annotation from decompilation, and raise default dnSpy concurrency to `10`.
- Test Case IDs: `AIT-011`; no DWT gameplay behavior changed.
- Scope:
  - Updated `tools/batch-decompile-managed-assemblies.ps1`: default `ThrottleLimit=10`, added `-NoRecurse`, normalized native status to `native-or-unreadable`.
  - Added `tools/build-dnspy-corpus.ps1` to build `generated/app/official` and `generated/app/community` packages.
  - Added `docs/OFFLINE_CORPUS_WORKFLOW.md` and updated `docs/API_TOOLCHAIN_TEST_PLAN.md` / `docs/AI_CONTEXT.md`.
  - Generated `generated/app/CORPUS_INDEX.md` and package manifests under ignored `generated/app/`.
- Verification:
  - Official `game-root` scan records native failures for `GameAssembly.dll`, `UnityPlayer.dll`, `baselib.dll`, and `version.dll`.
  - Official `MelonLoader/Managed` package reuses AIT-010 by generated link/reference and manifest.
  - Official `MelonLoader/Dependencies` scan completed: `169` DLLs, `164` managed, `5` native/unreadable, `19686` C# files, `22993` types.
  - Official `MelonLoader/root` scan completed: `11` managed DLLs.
  - Community `SaiLL` main DLL decompiled under `generated/app/community/SaiLL/decompiled/main/`.
  - SaiLL dependency scan completed: `10` DLLs, `3` managed, `7` native/unreadable.
  - SaiLL string annotation completed: `1346` `nBB.xBl(...)` calls decoded, `0` errors; cache written to `annotations/string-cache.json`.
- Findings:
  - `generated/app/` is now the canonical local corpus entry point for future source searches.
  - `official` should be preferred for API/wrapper shape. `community` should be used for examples and patterns, not behavior truth.
  - dnSpy failures are explicit package evidence, not missing work.
- Compile Verification: No real MOD build was required because no gameplay source was changed.
- Decision: Future KEP/AIT source searches should start from `generated/app/CORPUS_INDEX.md`; keep AIT-* folders as historical outputs unless cleanup is explicitly requested.

### FW-20260628-09 - AIT-012 SaiLL Dependency String Annotation

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Decode obfuscated strings under `generated/app/community/SaiLL/decompiled/deps`, not only the main SaiLL DLL output.
- Test Case IDs: `AIT-012`; no DWT gameplay behavior changed.
- Scope:
  - Generalized `tools/annotate-obfuscated-strings.ps1` so it can annotate configurable decoder call patterns such as `nBB.xBl(...)` and `cMj.FMl(...)`.
  - Added idempotent annotation detection so reruns do not stack duplicate comments.
  - Added `tools/StringDecoderHost`, a tiny .NET host for decoder assemblies that Windows PowerShell cannot load directly.
  - Updated `tools/build-dnspy-corpus.ps1` so SaiLL corpus builds queue and apply both main-DLL and dependency-DLL decoders.
  - Updated `docs/OFFLINE_CORPUS_WORKFLOW.md`, `docs/API_TOOLCHAIN_TEST_PLAN.md`, and `docs/AI_CONTEXT.md`.
- Verification:
  - `dotnet build tools/StringDecoderHost/StringDecoderHost.csproj` succeeded with `0` warnings and `0` errors.
  - Rebuilt `community/SaiLL` corpus successfully.
  - Main SaiLL annotation remained successful: `1346/1346` `nBB.xBl(...)` calls decoded.
  - Dependency annotation succeeded for `AI\ChatGuiGuLocal.dll`: `158/158` `cMj.FMl(...)` calls decoded, `0` errors, `10` `.cs` files annotated.
  - Annotated dependency source was copied back to `generated/app/community/SaiLL/decompiled/deps/AI_ChatGuiGuLocal/ChatGuiGuLocal/`.
  - Count check over that dependency source reported `TotalFMlLines=134`, `AnnotatedFMlLines=134`, `UnannotatedFMlLines=0`.
  - `annotations/string-cache.json` now contains both `KBR.nBB.xBl` (`440` unique entries) and `qMY.cMj.FMl` (`69` unique entries).
- Findings:
  - SaiLL dependency string obfuscation is package-local `qMY.cMj.FMl`, not the main DLL's `KBR.nBB.xBl`.
  - `ChatGuiGuLocal.dll` targets `net8.0`; Windows PowerShell reflection cannot load it in this environment, but the .NET host path can decode it offline.
  - These decoders are community-MOD implementation details and must not be treated as game API truth.
- Compile Verification: Tooling build only; no real MOD gameplay build was required.
- Decision: Future community corpus builds may add new package-local decoder tasks to `annotations/queue.json`, using `StringDecoderHost` when runtime binding requires modern .NET.

### FW-20260628-10 - AIT-013 Generated Root Migration And Additional MOD Corpus

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Move `docs/generated` to root `generated`, decompile `ChatGuigu.dll` into `community`, initially stage `GGBH_MOD.dll`, and judge whether `GGBH_MOD.dll` is official or community.
- Test Case IDs: `AIT-013`; no DWT gameplay behavior changed.
- Scope:
  - Migrated generated output to `generated/` and removed old `docs/generated/` after verifying no source-only files remained there.
  - Updated `tools/build-dnspy-corpus.ps1` so `-SourceKind` supports `official`, `community`, and `unclassified`.
  - Made `generated/app/CORPUS_INDEX.md` dynamically list discovered package manifests and report markdown files.
  - Decompiled `D:\Games\Steam\steamapps\common\鬼谷八荒\Mods\ChatGuigu.dll` into `generated/app/community/ChatGuigu/`.
  - Decompiled `D:\Games\Steam\steamapps\common\鬼谷八荒\Mods\GGBH_MOD.dll`; this was initially staged as unclassified and later promoted to `generated/app/official/GGBH_MOD/` in AIT-014.
  - Updated `docs/OFFLINE_CORPUS_WORKFLOW.md`, `docs/API_TOOLCHAIN_TEST_PLAN.md`, and `docs/AI_CONTEXT.md`.
- Verification:
  - `tools/build-dnspy-corpus.ps1` parser check passed.
  - `robocopy /L` showed all old `docs/generated` files were already present under `generated`; old directory was then removed.
  - `generated/` is ignored by Git.
  - ChatGuigu dnSpy manifest reports `46` source files, `23` namespaces, and `60` types.
  - ChatGuigu string annotation reports `2205` `WS3.eSA.UDi(...)` calls decoded with `0` errors; browsable source check reports `1726/1726` `eSA.UDi(...)` lines annotated.
  - GGBH_MOD dnSpy manifest reports `3` source files, `1` namespace, and `3` types.
- Findings:
  - `ChatGuigu.dll` is classified as `community`: metadata identifies `ChatGuigu`, and code implements AI/chat, UI/drama patches, local process/network management, and OpenAI-compatible request code.
  - `GGBH_MOD.dll` was first judged as leaning `official/loader-bridge`: it writes `MelonLoader/GGBH_MOD_LOAD_COMPLETE.txt`, patches `EventsMgr.Init`, registers `GameCMDMelonLoader`, handles `LoadDll` / `InitModMain`, calls `MelonHandler.LoadFromFile(...)`, and reflects `<namespace>.ModMain.Init()` / `Destroy()`.
  - AIT-014 supersedes this staging decision and treats `GGBH_MOD` as `official/loader-bridge`.
- Compile Verification: Tooling/parser checks only; no real MOD gameplay build was required.
- Decision: `generated/app/` is now the single local corpus root. Use `official` for trusted API shape, `community` for MOD examples, and `unclassified` for readable but not-yet-classified bridge/runtime DLLs.

### FW-20260628-11 - AIT-014 resource/app And Il2CppDumper Corpus Update

- Status: Docs/Tooling Only
- Date: 2026-06-28
- User Request: Rename local runtime resource root from `resource/MelonLoader` to `resource/app`, account for root native modules, record Il2CppDumper availability/output, and treat `GGBH_MOD` as official.
- Test Case IDs: `AIT-014`; no DWT gameplay behavior changed.
- Scope:
  - Updated tracked docs/tools from `resource/MelonLoader` to `resource/app`.
  - Added `resource/app` itself to dnSpy/string-annotation search paths, in addition to `resource/app/MelonLoader` and managed/dependency subdirectories.
  - Updated `tools/export-dnspy-types.ps1` to prefer local `resource/app/MelonLoader/...` assemblies before falling back to the installed game directory.
  - Promoted `GGBH_MOD` to `generated/app/official/GGBH_MOD/` as `official/loader-bridge` and rebuilt its 3-file dnSpy source corpus.
  - Registered user-generated Il2CppDumper output under `generated/app/official/game-root/decompiled/Il2CppDumper_output/`.
- Verification:
  - `resource/app` contains `GameAssembly.dll`, `global-metadata.dat`, `UnityPlayer.dll`, native support DLLs, and the `MelonLoader/` subdirectory.
  - Il2CppDumper output contains `dump.cs`, `il2cpp.h`, `script.json`, `stringliteral.json`, and `DummyDll/66` assemblies.
  - `GGBH_MOD` corpus contains `ModMain.cs`, `Patch_EventsMgr_Init.cs`, and `Properties/AssemblyInfo.cs`; project files were removed from generated output.
  - No tracked file still references `resource/MelonLoader`.
- Findings:
  - `resource/app` is now the stable local app/runtime evidence root.
  - Il2CppDumper improves native IL2CPP structure, offset, address, metadata, and string literal search, but it still is not original source-level C# and cannot replace DWT runtime traces.
  - `GGBH_MOD` is now official runtime loader bridge evidence, not community sample code and not unclassified.
- Compile Verification: Parser and documentation/tooling checks only; no real MOD gameplay build was required.
- Decision: Future native/static searches should start from `generated/app/CORPUS_INDEX.md`, using `official/game-root/decompiled/Il2CppDumper_output` for native IL2CPP structure and `official/MelonLoader/Managed` for wrapper/API shape.

### FW-20260628-12 - KEP-Prep Official Dual Wield Static Scan

- Status: Docs/Research Only
- Date: 2026-06-28
- User Request: Record two large MOD source directories for future community batch processing, but do not process them now; search the richer official static corpus for dual-wield-needed functions and logic.
- Test Case IDs: KEP-prep; no DWT gameplay behavior changed.
- Scope:
  - Recorded pending community batch roots: `D:\Games\Steam\steamapps\common\鬼谷八荒\ModExportData` and `D:\Games\Steam\steamapps\workshop\content\1468810`.
  - Added `docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md` to summarize official static evidence for dual-wield feasibility.
  - Updated `docs/OFFLINE_CORPUS_WORKFLOW.md`, `README.md`, and `docs/AI_CONTEXT.md` with the new source paths and scan entry point.
- Verification:
  - Searched `generated/app/official` for direct dual-wield/offhand terms; relevant hits were Unity/InputSystem/Socket false positives, not martial dual wield.
  - Confirmed official symbols for `SkillAttack`, `SkillDataAttack.actionMartialData`, `SkillCreateData`, `MissileShotData`, `UnitCtrlBase.skills/allSkills`, `UnitCtrlPlayer.CreateSkillAttack`, learned martial APIs, experience APIs, hit/use/lifesteal battle events, mp/sp resource fields, and PlayerInfo/input UI surfaces.
- Findings:
  - No native offhand or dual-normal-attack feature was found; DualWieldMod remains a MOD-built system.
  - The official corpus is now sufficient for KEP-001/002/003 static evidence gathering and ApiProbe design.
  - `SkillAttack.Create(...)` alone cannot be treated as a complete trigger; visual/damage, cooldown, resource cost, hit/effect attribution, and experience recipient must be verified as one consistency contract.
- Compile Verification: Not applicable; documentation and static search only.
- Decision: Run KEP-001/002/003 from `docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md` before more DWT gameplay changes that touch experience, passive effects, lifesteal, or combat wheel runtime switching.

### FW-20260628-13 - Static Corpus Source-Layer Correction

- Status: Docs/Research Correction
- Date: 2026-06-28
- User Request: Clarify whether the previous official scan really inspected `MelonLoader` and `game-root`, and whether it checked method internals/call chains rather than just symbols.
- Test Case IDs: KEP-prep correction; no DWT gameplay behavior changed.
- Scope:
  - Rechecked `generated/app/official/game-root`, `generated/app/official/MelonLoader/Managed`, `generated/app/official/MelonLoader/Dependencies`, and historical `generated/ait/AIT-010-managed-source`.
  - Updated `docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md` and `docs/AI_CONTEXT.md` to clarify evidence layers.
- Findings:
  - `game-root` direct dnSpy scan has no managed C# bodies; root DLLs are native/unreadable. The useful `game-root` material is the user-generated Il2CppDumper output, which is metadata/address/string/native-structure evidence.
  - `MelonLoader/Dependencies/.../cpp2il_out_Assembly-CSharp` contains Cpp2IL stub C# for `Assembly-CSharp`; it confirms types, fields, methods, tokens, and addresses, but core battle methods usually have empty/default bodies.
  - Historical `generated/ait/AIT-010-managed-source/Assembly-CSharp` contains Unhollower wrapper C# with `IL2CPP.il2cpp_runtime_invoke(...)`, `NativeMethodInfoPtr_*`, `CallerCount`, and xref ranges. This helps compile/hook/xref planning, but is not original game logic source.
  - At the time of this correction, canonical `generated/app/official/MelonLoader/Managed/decompiled/source` was stale/empty. FW-20260628-14 supersedes that local corpus state by regenerating it.
  - Therefore FW-20260628-12 should be read as an official symbol/field/event surface scan, not as a complete method-internal call-chain analysis.
- Decision: For true call-chain investigation, KEP should combine wrapper xref metadata, Cpp2IL/Il2CppDumper addresses, ApiProbe/Harmony hook compilation, and DWT runtime traces; if native branch logic is required, open a separate native-analysis spike instead of treating stub C# as source.



### FW-20260628-14 - AIT-015 Canonical Managed Corpus Regeneration

- Status: Docs/Research/Tooling Only
- Date: 2026-06-28
- User Request: Check whether content that should be in `official/MelonLoader/Managed` had been written into `official/MelonLoader/Dependencies`; if not, regenerate it into Managed, then inspect `official/MelonLoader` code and method-body quality.
- Test Case IDs: `AIT-015`; no DWT gameplay behavior changed.
- Scope:
  - Verified `generated/app/official/MelonLoader/Managed/decompiled` initially contained `0` `.cs` files while `Dependencies` contained many `cpp2il_out_*` source directories.
  - Regenerated `resource/app/MelonLoader/Managed` into `generated/app/official/MelonLoader/Managed/decompiled/source` using `tools/batch-decompile-managed-assemblies.ps1 -Parallel -ThrottleLimit 10 -Force`.
  - Replaced stale `Managed/manifest.json` with the new canonical batch manifest and scrubbed top-level generated manifests from old `docs/generated` paths.
  - Added local ignored method-body quality report: `generated/app/official/MelonLoader/METHOD_BODY_QUALITY_REPORT.md`.
  - Updated `docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md` and `docs/AI_CONTEXT.md` to point future searches at canonical `generated/app/official/MelonLoader/Managed`.
- Verification:
  - Managed regeneration considered `206` DLLs: `205` managed decompiled, `1` native/unreadable skipped, `0` dnSpy failures.
  - Managed output now contains `41380` `.cs` files, `1603` namespaces, and `60751` types.
  - `rg` against canonical Managed finds `CreateSkillAttack`, `AddSkillMartialExp`, and `UnitEffectSkillHpSuck` wrapper symbols.
  - Top-level corpus entry files no longer point to `docs/generated`.
- Findings:
  - Managed output was not accidentally written into Dependencies. The confusion came from `Dependencies/Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out/Assembly-CSharp.dll`, which naturally resembles `Managed/Assembly-CSharp.dll`.
  - `Managed` is MOD-callable wrapper/API shape evidence: many methods call `IL2CPP.il2cpp_runtime_invoke(...)`.
  - `Dependencies` Cpp2IL outputs are structure/signature/token/RVA evidence: key combat methods are often empty/default stubs.
  - `MelonLoader/root` contains ordinary managed loader/hook/toolchain libraries and is better for real managed method-body reading.
- Compile Verification: Not applicable; documentation and generated corpus only.
- Decision: Future KEP searches should use `generated/app/official/MelonLoader/Managed/decompiled/source` for wrapper/API shape, `generated/app/official/MelonLoader/Dependencies/.../cpp2il_out_*` for Cpp2IL structure, and `generated/app/official/MelonLoader/root/decompiled` for loader/hook implementation details.
