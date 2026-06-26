# ApiProbe

`ApiProbe` is a compile-only test project. It does not implement gameplay and should not be packaged as a MOD.

Its purpose is to verify that the APIs used by the dual-wield MVP are present in the referenced game assemblies:

- MOD lifecycle and Harmony patching.
- `g.timer`, `g.events`, and battle lifecycle events.
- `g.data.obj` persistence.
- `SceneType.battle`, `BattleFactory.CreateSkill`, `SkillAttack.Init/Create/IsCreate`.
- `allActionMartial`, `skillLeft`, `propsInfoBase.baseID`.
- `UnitActionMartialEquip` / `UnitActionMartialUnequip`.
- `UnitHitDynIntHandler` damage mutation hook.
- `g.ui`, `OpenUIEnd`, Unity UI clone/button APIs.

## Requirements

- .NET Framework 4.7.2 reference assemblies.
- Roslyn `csc.dll` from the installed .NET SDK.
- Game/MOD managed assemblies, usually from the game's `MelonLoader/Managed` directory or equivalent.

The repository currently contains only partial reference material under `ideas/`; if required game DLLs are missing, the build script reports them clearly instead of producing a misleading success.

## Build

From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1
```

With explicit references:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1 -ReferenceDir "D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed"
```

The script automatically adds the sibling `MelonLoader` directory when a `Managed` path is supplied, which is required for `0Harmony.dll`.

Or place/symlink DLLs into `test/ApiProbe/refs/` and run the default command.

## Interpreting Results

- Missing reference report: environment/setup gap, not a code failure.
- Compile error for a symbol in `ApiSurfaceProbe.cs`: the API assumption needs correction in `docs/DATA_FIELD_RESEARCH.md` before implementation.
- Successful compile: the checked API surface is available at compile time; runtime behavior still needs an in-game smoke test.

Current local status: the probe compiles successfully against the local game install.
