# DualWieldMod Wheel Design

## Purpose

This document defines the wheel system as two connected surfaces:

1. Prebattle wheel setup UI in the player skill interface.
2. In-combat Q wheel for fast selection.

The wheel should not become a second inventory screen during combat. Combat should only choose from a prepared 0-6 candidate pool. The skill interface owns slower setup, ordering, validation, and cleanup.

## Current Baseline

Accepted runtime behavior before wheel work:

- DWT-004: offhand fires only during normal attack input.
- DWT-005: offhand id persists through save/load and battle can start with `source=saved`.
- DWT-006: main/offhand normal attacks can be distinct; user observed independent cooldown behavior.
- FW-09: the PlayerInfo offhand button is acceptable for now. Tooltip text still needs polish later, but the slot behavior can stand.
- FW-11: empty offhand must remain empty. The battle controller must not copy main into offhand when no explicit offhand is saved.

The next system should build on this instead of replacing it.

## Core Principle

Split responsibilities:

- Prebattle setup UI decides what can appear on a wheel.
- Combat Q wheel decides which prepared candidate becomes main or offhand.
- Battle controller only consumes current main/offhand state and should not know how candidates were configured.

This gives the player deliberate preparation without making combat setup too busy.

## Candidate Pools

Every wheel category supports 0-6 configured candidates:

- Normal attack: main + offhand + 0-6 candidates.
- Unique skill: current + 0-6 candidates.
- Movement skill: current + 0-6 candidates.
- Divine skill: current + 0-6 candidates.

MVP should implement normal attack first. Non-normal categories stay design-only until switching and cooldown APIs are verified.

Candidate rules:

- Candidate ids are learned skill instance ids, not base ids.
- Invalid or forgotten candidates are disabled or removed safely on load/open.
- Duplicates are collapsed; first occurrence wins.
- Candidate order is player controlled and stable.
- A candidate can be the same as current main or current offhand; the wheel should visually mark that state.
- The configured pool is not required to include every learned skill. This is a deliberate combat loadout.

## Save Shape

Keep the existing offhand string for compatibility during early iterations, then add a versioned wheel config group.

Recommended MOD-owned keys:

```text
Save group: MOD_h6Zv8g.DualWield
schemaVersion = 1
offhandSkillId = current accepted offhand slot
normalWheelPool_v1 = serialized ordered skill ids, max 6
```

Future target JSON shape:

```json
{
  "version": 1,
  "normal": {
    "pool": ["skill-a", "skill-b"],
    "lastHoverIndex": -1
  },
  "unique": { "pool": [] },
  "movement": { "pool": [] },
  "divine": { "pool": [] }
}
```

For MVP, storing `normalWheelPool_v1` as a compact delimiter-separated string is acceptable if code stays wrapped in `WheelConfigStore` and validation is centralized.

## Prebattle Setup UI

Location:

- Player info / skill UI, near the current normal attack slot and offhand button.
- It should feel like a loadout editor, not a combat wheel preview.

Normal attack MVP layout:

- Keep the existing main normal attack slot from the game.
- Keep the current DualWield offhand slot/button.
- Add a compact six-slot candidate strip or small radial preview near the normal attack area.
- Each slot shows skill icon, grade background, and a tiny slot number 1-6 if practical.
- Empty slots use a neutral empty state.
- Hovering a filled slot shows the skill tooltip.
- Hovering an empty slot says it can accept the current main normal attack.

MVP interaction:

- Equip/select a normal attack as current main in the original skill UI.
- Click an empty candidate slot to store the current main into that slot.
- Click a filled candidate slot while a different main is equipped to replace that slot with current main.
- Click a filled candidate slot while no main is equipped to clear that slot.
- If current main equals the filled slot, clicking can clear or no-op; choose clear for symmetry with the offhand toggle.
- Candidate setup should not automatically unequip main. Only the offhand slot does that, because moving main into offhand means it leaves the main hand.

Nice-to-have later:

- Drag reorder slots.
- Clear icon per slot.
- Category tabs for normal/unique/movement/divine.
- Show current main/offhand badges on candidate slots.

## Combat Q Wheel

Normal attack combat wheel rules remain:

1. Hold `Q` to open the wheel.
2. While open, suppress or ignore attack input.
3. Hover an option and release `Q` to replace main normal attack.
4. Left click an option while holding `Q` to replace offhand normal attack and close the wheel immediately.
5. Release `Q` with no valid hover target to close without changing loadout.

Wheel candidates come only from the configured normal candidate pool.

Visual behavior:

- 0 candidates: open a harmless empty state and close on release.
- 1 candidate: one prominent option.
- 2 candidates: opposite anchors.
- 3 candidates: triangle.
- 4 candidates: cross.
- 5 candidates: five-point layout.
- 6 candidates: six-point layout.

Slot state indicators:

- Current main marker.
- Current offhand marker.
- Invalid/missing marker, if stale data survives until UI open.
- Hover highlight.
- Click feedback before close.

## Input And Selection Semantics

Main replacement path:

- Trigger: release `Q` while hovering a valid candidate.
- Action: equip candidate as main normal attack.
- Offhand: unchanged unless it becomes invalid by game rules.
- Persistence: main is base game equip state; no new MOD key needed for current main.

Offhand replacement path:

- Trigger: left click a valid candidate while `Q` is held.
- Action: save candidate as `offhandSkillId`.
- Main: unchanged.
- Wheel: closes immediately.
- Persistence: write MOD save key immediately.

No offhand path:

- Trigger: no saved offhand exists before battle.
- Action: offhand controller stays disabled.
- Main: works normally by itself.
- Persistence: do not write `offhandSkillId` automatically.
- Reason: implicit main-to-offhand copy creates a pure double-hit damage boost and bypasses the player's loadout decision.

Offhand promotion path:

- Trigger: no main normal attack exists, but a saved offhand exists.
- Action: promote saved offhand into main normal attack and clear `offhandSkillId`.
- Main: becomes the former offhand.
- Offhand: empty after promotion.
- Combat result: single-hand main only; do not initialize offhand in the same battle.
- Wheel implication: the offhand/current slot represented by that saved id becomes blank until the player assigns another offhand.

No selection path:

- Trigger: release `Q` with no valid hover target.
- Action: close only.
- Main/offhand: unchanged.

Input suppression risk:

- The MOD can always suppress its own offhand handling while the wheel is open.
- The base game's main attack may still fire if UI raycast or input blocking is insufficient.
- DWT-008 must explicitly test this. If UI alone cannot block base input, use a narrow Harmony/input patch only for the wheel-open window.

## Runtime Switching Constraint

Combat wheel switching must obey the skill trigger consistency contract from `docs/DUAL_WIELD_DESIGN_MVP.md`.

Directly changing `g.world.playerUnit.data.unitData.skillLeft` is loadout state, not a proven in-combat hot-switch API. After battle initialization, the game also has runtime objects and caches such as `UnitCtrlBase.skills`, `SkillAttack.data`, `SkillDataAttack.actionMartialData`, `UnitPlayerInputCtrl`, and `AIHumanState.ActionSkillLeft`. A wheel selection is valid only if the skill that visually fires, owns cooldown, spends resources, drives hit/effect context, and receives experience is the selected learned skill.

Before implementing `Q + hover + release` main replacement, `DWT-022` must prove the normal attack switch/offhand path has correct experience attribution. If the current MOD-created offhand `SkillAttack` does not award offhand experience, the design must either call the original experience API in a controlled way or adopt a more native runtime replacement path.

## Validation Rules

When opening setup UI, opening wheel, entering battle, or loading save:

- Remove or disable candidates not found in `allActionMartial`.
- Remove duplicate ids after the first occurrence.
- Keep pool length <= 6.
- If saved offhand is invalid, clear offhand and leave main untouched.
- If main is empty and saved offhand is valid at battle start, promote offhand to main and clear offhand.
- If main/offhand/candidate share the same base pattern, allow it for now; later mastery gates can decide whether this is useful.

## Implementation Order

Recommended Flywheel sequence:

1. FW-10: docs-only wheel architecture and test plan update.
2. FW-11: add `WheelConfigStore` for `normalWheelPool_v1`, validation, and diagnostics; no UI yet.
3. FW-12: add prebattle normal candidate setup strip in PlayerInfo skill UI.
4. FW-13: battle Q wheel shell open/close with input suppression probe; no selection yet.
5. FW-14: `DWT-022` experience attribution diagnostic for offhand and any runtime main-switch candidate.
6. FW-15: `Q + hover + release` replaces main normal attack only after DWT-022 proves a consistent runtime path.
7. FW-16: `Q + left click` replaces offhand normal attack, preserving offhand experience attribution.
8. FW-17: layout stability for 0-6 candidates.

Do not start combat stamina, mastery growth, or non-normal category switching until normal candidate setup, Q wheel semantics, and DWT-022 attribution are stable in game.

## Acceptance Map

- DWT-021: Prebattle normal wheel candidate setup UI.
- DWT-022: Runtime skill trigger experience attribution.
- DWT-008: Q wheel open/close and input suppression.
- DWT-009: Q hover release replaces main normal attack.
- DWT-010: Q left click replaces offhand normal attack.
- DWT-011: candidate pool size and layout stability.

## Open Questions

- Whether the prebattle setup UI should use a strip first or a miniature radial preview. Strip is easier and likely better for MVP.
- Whether candidate slot click should clear when current main equals the slot, or no-op. Current recommendation: clear.
- Whether base-game UI raycasts can fully block main attack during Q wheel. This must be runtime-tested.
- Whether non-normal categories should share the same setup UI now as disabled tabs, or be hidden until their APIs are known.
