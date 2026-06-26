# Flywheel

This document defines the DualWieldMod iteration flywheel. It is the project-management and QA memory for each development round.

The core idea: Codex can compile and reason, but only the game runtime can prove combat behavior. Every round must therefore end with a compiled build, an expected behavior report, and a waiting state for in-game feedback.

## Delivery Contract

Each development round follows this loop:

1. Intake
   - Capture the user's current request.
   - Decide the smallest useful scope for this round.
   - Name explicit non-goals so the round does not expand silently.

2. Implement
   - Edit only intentional source under `src/`, docs, tools, or tests.
   - Keep `ideas/` read-only and ignored.
   - Sync source into the real game project only through `tools/sync-src-to-game.ps1`.

3. Compile Verify
   - Run the real game project build before handing off any code-bearing round:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1 -Apply -Build
```

   - Use `test/ApiProbe` when checking uncertain game-kernel API shapes:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1 -ReferenceDir "D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed"
```

4. Report Expected Behavior
   - Tell the user exactly what should happen in game.
   - Include what should not happen.
   - Include a short user test checklist.
   - State compile result and any warnings.

5. Await Game Test
   - Stop the round after reporting the built result.
   - The user enters the game and tests the described behavior.
   - Runtime status remains unverified until the user reports back.

6. Feedback And Next Turn
   - Record the user's observed behavior.
   - Mark the round accepted, needs rework, or blocked.
   - Use the feedback plus project plan to choose the next iteration.

## Status Values

Use one status per record:

- `Planned`: scoped but not implemented.
- `Built`: code/docs changed and required compile checks passed.
- `Awaiting Game Test`: built and handed to the user for runtime verification.
- `Feedback Received`: user has reported game behavior; decision still pending.
- `Accepted`: behavior matched the expected result closely enough to keep.
- `Needs Rework`: behavior diverged or a bug was found; continue in a new round.
- `Blocked`: cannot progress without user input, missing external state, or unavailable runtime evidence.
- `Docs Only`: documentation/process change with no MOD build required.

## Definition Of Done Per Code Round

A code-bearing flywheel round is not complete until all of these are true:

- Source changes are made in `src/` first.
- Real project sync/build has been run.
- Build has `0 error`.
- Expected in-game behavior is documented in the final handoff.
- User test checklist is explicit.
- The flywheel record is updated with status `Awaiting Game Test` or a clear blocked reason.

Runtime behavior is not called confirmed until the user reports a successful in-game test.

## Alternatives Considered

The flywheel is intentionally lighter than a full issue tracker.

- GitHub Issues: useful later after the repo is pushed and work becomes multi-threaded, but heavier for quick local iteration.
- CHANGELOG only: good for release history, but too weak for expected behavior and failed runtime tests.
- Kanban board: useful for many parallel tasks, but this MOD currently needs tight serial compile/runtime feedback.
- Test-only workflow: insufficient because the most important behavior is inside the game runtime and cannot be fully automated yet.

The current best workflow is Flywheel plus compile probes plus user runtime smoke tests.

## Record Template

Copy this template for each new round.

```markdown
### FW-YYYYMMDD-NN - Short Title

- Status: Planned | Built | Awaiting Game Test | Feedback Received | Accepted | Needs Rework | Blocked | Docs Only
- Date: YYYY-MM-DD
- User Request:
- Scope:
- Non-Goals:
- Files Changed:
- Compile Verification:
  - ApiProbe:
  - Real MOD build:
- Expected In-Game Behavior:
- Should Not Happen:
- User Test Checklist:
  - [ ]
- User Feedback:
- Decision:
- Next Round:
```

## Flywheel Log

### FW-20260627-00 - Establish Flywheel Process

- Status: Docs Only
- Date: 2026-06-27
- User Request: Define a repeatable delivery loop where Codex implements, compiles the real project, reports expected behavior, waits for user in-game testing, then iterates from feedback.
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
