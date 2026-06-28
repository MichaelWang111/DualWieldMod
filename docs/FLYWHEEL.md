# Flywheel

This document owns the DualWieldMod iteration protocol. It defines how a request becomes a scoped round, how the real MOD build is verified, and how user runtime feedback is recorded.

It does not own historical round records or the detailed test ladder:

- Historical records live in `docs/FLYWHEEL_LOG.md`.
- Stable serial test cases live in `docs/SERIAL_TEST_PLAN.md`.

The core idea: Codex can compile and reason, but only the game runtime can prove combat behavior. Every code-bearing round must therefore end with a compiled build, an expected behavior report, and a waiting state for in-game feedback.

## Delivery Contract

Each development round follows this loop:

1. Intake
   - Capture the user's current request.
   - Decide the smallest useful scope for this round.
   - Bind the round to one or more serial test IDs from `docs/SERIAL_TEST_PLAN.md` when runtime behavior is involved.
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
   - State which serial test IDs are being advanced or rechecked.

5. Await Game Test
   - Stop the round after reporting the built result.
   - The user enters the game and tests the described behavior.
   - Runtime status remains unverified until the user reports back.

6. Feedback And Next Turn
   - Record the user's observed behavior in `docs/FLYWHEEL_LOG.md`.
   - Mark the round accepted, needs rework, or blocked.
   - Update `docs/SERIAL_TEST_PLAN.md` only when a test status or acceptance evidence changes.
   - Use the feedback plus project plan to choose the next iteration.

## Status Values

Use one status per Flywheel record:

- `Planned`: scoped but not implemented.
- `Built`: code/docs changed and required compile checks passed.
- `Awaiting Game Test`: built and handed to the user for runtime verification.
- `Feedback Received`: user has reported game behavior; decision still pending.
- `Accepted`: behavior matched the expected result closely enough to keep.
- `Needs Rework`: behavior diverged or a bug was found; continue in a new round.
- `Blocked`: cannot progress without user input, missing external state, or unavailable runtime evidence.
- `Docs Only`: documentation/process change with no MOD build required.

## Definition Of Done Per Code Round

A code-bearing Flywheel round is not complete until all of these are true:

- Source changes are made in `src/` first.
- A Flywheel record exists in `docs/FLYWHEEL_LOG.md`.
- The record names one or more serial test IDs from `docs/SERIAL_TEST_PLAN.md`, unless the round is pure diagnostics or research.
- Real project sync/build has been run.
- Build has `0 error`.
- Expected in-game behavior is documented in the final handoff.
- User test checklist is explicit.
- The Flywheel record is updated with status `Awaiting Game Test` or a clear blocked reason.

Runtime behavior is not called confirmed until the user reports a successful in-game test.

## Serial Test Binding

Serial tests prevent the project from jumping ahead into attractive features before the base combat contract is stable.

Rules:

- Use `DWT-###` IDs from `docs/SERIAL_TEST_PLAN.md`.
- A Flywheel round may advance one test or recheck several earlier tests as regression coverage.
- A later test can be researched before earlier tests pass, but it should not be promoted to accepted runtime behavior until its prerequisites are accepted.
- If a user report fails a previous accepted behavior, open a new Flywheel round against that earlier test ID and mark the regression in the log.

## Alternatives Considered

The Flywheel is intentionally lighter than a full issue tracker.

- GitHub Issues: useful later after the repo is pushed and work becomes multi-threaded, but heavier for quick local iteration.
- CHANGELOG only: good for release history, but too weak for expected behavior and failed runtime tests.
- Kanban board: useful for many parallel tasks, but this MOD currently needs tight serial compile/runtime feedback.
- Test-only workflow: insufficient because the most important behavior is inside the game runtime and cannot be fully automated yet.

The current best workflow is Flywheel protocol plus serial test cases plus compile probes plus user runtime smoke tests.

## Record Template

Copy this template into `docs/FLYWHEEL_LOG.md` for each new round.

```markdown
### FW-YYYYMMDD-NN - Short Title

- Status: Planned | Built | Awaiting Game Test | Feedback Received | Accepted | Needs Rework | Blocked | Docs Only
- Date: YYYY-MM-DD
- User Request:
- Test Case IDs:
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

## Log Location

Historical Flywheel records are stored in `docs/FLYWHEEL_LOG.md`.

Current accepted runtime milestones:

- `FW-20260627-01 - Minimal Offhand Attack Existence`
- `FW-20260627-02 - Runtime Load Visibility Probe`
- `FW-20260627-05 - Cleanup And Controlled Offhand Trigger`

Next recommended code-bearing round:

```text
FW-20260627-06 - Offhand Loadout Persistence Skeleton
```
