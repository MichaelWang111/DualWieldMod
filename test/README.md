# Test Workflows

This directory is for small verification projects, not production MOD code.

The recommended workflow is compile probes first, runtime probes later:

1. Compile probes prove that referenced game/MOD APIs exist and that our source can be compiled against the game's managed assemblies.
2. Runtime smoke probes should only be added after the compile probes pass, because runtime tests require launching the game/MOD environment.
3. Design docs should cite probe results only when the probe is reproducible from this directory.

## Current Assessment

The current documentation research is enough to start MVP prototyping, but not enough to claim that the full API surface is known.

- Normal-attack dual-wield path: roughly 80-85% known.
- Overall API surface for the full design: roughly 65-75% known.
- Static config/data fields for skills, effects, projectiles, mastery, and resources: roughly 80-85% known.
- Runtime fields for current proficiency, battle-safe `mp`/`sp`, Q-wheel input swallowing, and offhand damage tagging are still the main gaps.

## Available Probe

- `ApiProbe`: compile-only API surface probe for the known dual-wield MVP APIs.

Run from repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1
```

If the script reports missing DLLs, point it at the game's managed assembly directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1 -ReferenceDir "D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed"
```

Passing the `Managed` directory is enough locally; the script also adds the sibling `MelonLoader` directory so `0Harmony.dll` is found.

A local `test/ApiProbe/refs/` directory may also be used for copied or junctioned reference DLLs. It is intentionally ignored by git.

Current local status: `ApiProbe` compiles successfully against the local game install.
