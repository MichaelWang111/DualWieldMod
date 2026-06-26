# Source Overlay

`src/` is the clean source overlay for the real game-generated MOD project.

The real project lives at:

```text
D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject
```

This repository should track only intentional source changes, not the full generated project.

## Mapping

```text
src/ModCode/ModMain/ -> ModProject/ModCode/ModMain/
src/ModExcel/        -> ModProject/ModExcel/        optional, only custom config tables
src/ModAssets/       -> ModProject/ModAssets/       optional, only custom assets
```

Use `tools/sync-src-to-game.ps1` to copy source changes into the real project. The script defaults to dry-run and requires `-Apply` before writing files.

## Rules

- Keep raw research in `ideas/`, which is ignored.
- Keep design and API notes in `docs/`.
- Keep generated build outputs out of git.
- Do not commit copied game DLLs, `bin/`, `obj/`, caches, or exported MOD packages.
