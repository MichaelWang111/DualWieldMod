# API Toolchain Test Plan

## Purpose

`AIT` is the API/Assembly Inspection Toolchain track. It verifies offline tooling before any dual-wield gameplay test depends on that tooling.

`KEP` is the Key Evidence Probe track. It uses AIT-proven tools to answer narrow combat-kernel questions before a runtime DWT round is opened.

`DWT` is reserved for real game MOD behavior. `AIT` is its evidence foundation.

## Tool Roles

- CHM index: official documented symbols and member pages.
- Cecil inventory/static scan: assembly classification, metadata, references, type/method/field discovery, and method-body coverage.
- dnSpy Console: readable C# or IL decompilation, including function bodies for managed DLLs.
- ApiProbe: Roslyn compile probe against game/MelonLoader references. It is not Cecil; it proves candidate C# calls compile, not runtime behavior.

## Generated Output Policy

- `resource/` is local read-only source material and must not be committed.
- `generated/` is local reproducible output and must not be committed.
- Tool scripts and summary docs are tracked.

## AIT-001 - dnSpy Full Body Export

- Goal: Prove automated dnSpy can reproduce a full function body from a managed MelonLoader Mod DLL.
- Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\Mod解包结果\SaiLL.dll -TypeName A7T.t7w -OutputDir .\generated\ait\AIT-001
```

- Required output: `generated/ait/AIT-001/A7T.t7w.cs`.
- Acceptance snippets:
  - `namespace A7T`
  - `internal class t7w : c9f`
  - `public override GameObject Hgc(GameObject template)`
  - `foreach (SpriteRenderer spriteRenderer in template.GetComponentsInChildren<SpriteRenderer>())`
  - image load call, either `ImageConversion.LoadImage` or dnSpy's extension-method form `texture.LoadImage(...)`
  - `return template;`
- Reference comparison: `resource/Mod解包结果/SaiLL_human_dnspy/A7T`.

## AIT-002 - dnSpy Full Assembly Export

- Goal: Prove full assembly export and manifest generation.
- Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\Mod解包结果\SaiLL.dll -FullAssembly -OutputDir .\generated\ait\AIT-002
```

- Required output: `generated/ait/AIT-002/SaiLL/` and `manifest.json`.
- Acceptance:
  - Full export exit code is `0`.
  - Output directory contains C# files or project files produced by dnSpy.
  - `source-manifest.json` records exported namespace/type counts for quick lookup.
  - Generated files remain ignored by Git.

## AIT-003 - MelonLoader Assembly Census

- Goal: Classify managed/native DLLs and identify whether assemblies have real method bodies.
- Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\inventory-dotnet-assemblies.ps1 -Path .\resource\app,.\resource\Mod解包结果\SaiLL.dll -OutputDir .\generated\ait\AIT-003
```

- Required output: `ASSEMBLY_INVENTORY.md` and `assembly-inventory.json`.
- Acceptance focus assemblies:
  - `MelonLoader.dll`
  - `0Harmony.dll`
  - `MonoMod.RuntimeDetour.dll`
  - `MelonLoader/Managed/Assembly-CSharp.dll`
  - `Cpp2IL/cpp2il_out/Assembly-CSharp.dll`
  - `SaiLL.dll`
- Required distinction: `Assembly-CSharp.dll` from `Managed` must be marked as IL2CPP interop wrapper; `Cpp2IL` output must be marked separately.

## AIT-004 - Cecil Static Index

- Goal: Prove Cecil can generate fast automatic evidence without producing readable source.
- Commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\inventory-dotnet-assemblies.ps1 -Path .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll,.\resource\app\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL\cpp2il_out\Assembly-CSharp.dll -OutputDir .\generated\ait\AIT-004
powershell -ExecutionPolicy Bypass -File .\tools\inspect-combat-system.ps1
```

- Acceptance:
  - Type/method/field/method-body counts are generated.
  - Findings are treated as symbol/static evidence only.

## AIT-005 - ApiProbe Compile Contract

- Goal: Prove ApiProbe is a compile validator and not a static decompiler.
- Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1 -ReferenceDir .\resource\app\MelonLoader\Managed
```

- Acceptance:
  - Probe compiles or reports missing references clearly.
  - The result is classified as compile evidence, not runtime evidence.

## AIT-006 - Obfuscated String Annotation

- Goal: Generate a readable annotated copy of managed dnSpy output by resolving known sample-local string decoder calls such as `nBB.xBl(...)`.
- Boundary: `nBB` is a `SaiLL` helper method, not a game-kernel API and not a universal decoder for every DLL. It is useful as a reference pattern showing how an external MOD can hide and later read strings, paths, UI names, or environment-derived values through helper methods and embedded resources.
- Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\annotate-obfuscated-strings.ps1 -AssemblyPath .\resource\Mod解包结果\SaiLL.dll -InputDir .\generated\ait\AIT-002\SaiLL\SaiLL -OutputDir .\generated\ait\AIT-006-string-annotations\SaiLL
```

- Required output:
  - `generated/ait/AIT-006-string-annotations/SaiLL/` annotated C# copy.
  - `manifest.json` summary.
  - `string-map.json` mapping file/line/expression/value/decoded string.
  - `STRING_ANNOTATION_REPORT.md` sample report.
- Acceptance:
  - `A7T/t7w.cs` contains comments such as `/* "Load:" */`, `/* "/" */`, `/* ".png" */`, and Chinese log strings.
  - All decoded output remains under ignored `generated/`.
  - Conclusions treat decoded strings as external sample evidence only, not DualWieldMod design knowledge.

## AIT-007 - Focused System DLL Parse

- Goal: Prove the same offline toolchain can parse focused game-system surfaces and produce a static/dynamic evidence map for combat questions.
- Commands:

```powershell
$types = @(
  'UnitCtrlPlayer','BattleDataMgr','UnitActionRoleBattle','SkillAttack','SkillBase','SkillDataAttack','DataUnit',
  'EBattleTypeData.UnitEffectSkillHpSuck','EBattleTypeData.OneUnitHitSkill','EBattleTypeData.OneUnitUseSkillAttack',
  'EBattleTypeData.UnitHitDynIntHandler','SkillCreateData','MissileShotData','HitData','UnitCtrlBase','WorldUnitBase',
  'DataUnit.UnitInfoData','DataUnit.ActionMartialData'
) -join ','

powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Managed\Assembly-CSharp.dll -TypeName $types -OutputDir .\generated\ait\AIT-007-system-dll-parse\managed
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\app\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL\cpp2il_out\Assembly-CSharp.dll -TypeName $types -OutputDir .\generated\ait\AIT-007-system-dll-parse\cpp2il
```

- Required tracked output: `docs/SYSTEM_DLL_STATIC_DYNAMIC_COMPARISON.md`.
- Generated output:
  - `generated/ait/AIT-007-system-dll-parse/managed/`
  - `generated/ait/AIT-007-system-dll-parse/cpp2il/`
- Acceptance:
  - Focused exports complete for `UnitCtrlPlayer`, `BattleDataMgr`, `UnitActionRoleBattle`, `SkillAttack`, `SkillBase`, `SkillDataAttack`, `DataUnit`, `SkillCreateData`, `MissileShotData`, `HitData`, and key `EBattleTypeData` classes.
  - The report distinguishes `MelonLoader/Managed/Assembly-CSharp.dll` as IL2CPP wrapper evidence and `Cpp2IL/cpp2il_out/Assembly-CSharp.dll` as structure/stub evidence.
  - The report maps static symbols to current DWT observations for offhand creation, experience mutation, and lifesteal attribution.
  - Conclusions do not claim event order or mutation ownership without runtime DWT traces.

## AIT-008 - GameAssembly Native Boundary

- Goal: Verify whether `GameAssembly.dll` can be decompiled by dnSpy like a managed DLL, and identify the correct offline path for IL2CPP native output.
- Source files:
  - `resource/app/GameAssembly.dll`
  - `resource/app/global-metadata.dat`
  - Real game originals may also exist under `D:\Games\Steam\steamapps\common\鬼谷八荒`, but `resource/app` is the project-local offline copy.
- Direct dnSpy commands:

```powershell
dotnet D:\Games\tools\解包\dnSpy-net-win64\bin\dnSpy.Console.dll --no-color -l C# -t UnitCtrlPlayer D:\Games\Steam\steamapps\common\鬼谷八荒\GameAssembly.dll
dotnet D:\Games\tools\解包\dnSpy-net-win64\bin\dnSpy.Console.dll --no-color -l C# -o .\generated\ait\AIT-008-gameassembly-full-dnspy --no-resources --no-resx --no-baml D:\Games\Steam\steamapps\common\鬼谷八荒\GameAssembly.dll
```

- Direct dnSpy result: rejected with `GameAssembly.dll 不是 .NET 文件`.
- PE evidence from dnSpy/PE view or header parser:
  - `Machine = 0x8664`, `PEKind = PE32+`.
  - The file has an `il2cpp` section.
  - `.NET.VirtualAddress = 0` and `.NET.Size = 0`, equivalent to no CLR runtime header.
- Cpp2IL command:

```powershell
& D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL\Cpp2IL.exe --game-path D:\Games\Steam\steamapps\common\鬼谷八荒 --output-as dummydll --output-to .\generated\ait\AIT-008-cpp2il-gameassembly
```

- Cpp2IL result:
  - Detected Unity `2020.3.9` and IL2CPP metadata `27.1`.
  - Found binary `codereg` and `metareg`.
  - Mapped `139476` method definitions.
  - Generated `65` dummy DLL assemblies, including `Assembly-CSharp.dll`.
- Il2CppDumper result:
  - Tool path: `D:\Games\tools\解包\Il2CppDumper-win-v6.7.46`.
  - Output path: `generated/app/official/game-root/decompiled/Il2CppDumper_output/`.
  - Output includes `dump.cs`, `il2cpp.h`, `script.json`, `stringliteral.json`, and `DummyDll/66` assemblies.
  - Treat as native IL2CPP structure, offsets, addresses, metadata, and string literal evidence.
- Acceptance:
  - Treat direct dnSpy `GameAssembly.dll` C# decompilation as rejected for this installed dnSpy Console.
  - Treat Cpp2IL dummy DLLs as structure/signature/token/RVA evidence, not original C# method bodies.
  - Treat Il2CppDumper output as native IL2CPP structure evidence, not original source-level game C#.
  - If original native branch logic is needed, use a native IL2CPP analysis path such as Cpp2IL metadata plus Ghidra/IDA-style native disassembly, then validate conclusions with DWT runtime traces.

## AIT-009 - MelonLoader Managed Source Corpus

- Goal: Batch-decompile high-value managed DLLs from the real `MelonLoader` directory into an ignored local source corpus for fast static source search.
- Tool:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\batch-decompile-managed-assemblies.ps1 -RootPath D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader -OutputDir .\generated\ait\AIT-009-melonloader-managed-source <filters>
```

- Generated output:
  - `generated/ait/AIT-009-melonloader-managed-source/`
  - `SOURCE_INDEX.md` summary and search commands.
  - `batch-manifest.json` machine-readable manifest.
  - `source-roots.txt` list of decompiled source roots.
- Current corpus:
  - `28` managed DLLs from MelonLoader/Harmony/Cecil/MonoMod/Unhollower/Cpp2IL support libraries.
  - `4575` C# source files and `5069` indexed types.
  - `0` failures in the high-value filtered run.
- Example searches:

```powershell
rg -n "PatchAll|HarmonyPatch" .\generated\ait\AIT-009-melonloader-managed-source
rg -n "RegisterTypeInIl2Cpp|UnhollowerSupport|Il2CppObjectBase" .\generated\ait\AIT-009-melonloader-managed-source
rg -n "codereg|metareg|global-metadata|MethodDefinition" .\generated\ait\AIT-009-melonloader-managed-source
```

- Acceptance:
  - Corpus stays under ignored `generated/`.
  - Batch tool skips native/unreadable DLLs and can rerun incrementally by reading existing manifests.
  - Conclusions from this corpus apply to the managed loader/toolchain layer, not to original game business logic.

## AIT-010 - MelonLoader Managed Full Parallel Corpus

- Goal: Decompile the full real `MelonLoader/Managed` directory with parallel jobs so the IL2CPP wrapper/API surface and Unity/System support assemblies are locally searchable.
- Relationship to `AIT-009`: `AIT-009` is the high-value loader/toolchain subset; `AIT-010` is the full managed corpus, including `Assembly-CSharp.dll`.
- Tool parameters added to `tools/batch-decompile-managed-assemblies.ps1`:
  - `-Parallel`: run dnSpy exports in background jobs.
  - `-ThrottleLimit <n>`: cap concurrent dnSpy jobs.
  - Incremental reruns still skip assemblies with successful child manifests unless `-Force` is used.
- Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\batch-decompile-managed-assemblies.ps1 `
  -RootPath 'D:\Games\Steam\steamapps\common\鬼谷八荒\MelonLoader\Managed' `
  -OutputDir '.\generated\ait\AIT-010-managed-source' `
  -Parallel -ThrottleLimit 4
```

- Generated output:
  - `generated/ait/AIT-010-managed-source/SOURCE_INDEX.md`
  - `generated/ait/AIT-010-managed-source/batch-manifest.json`
  - `generated/ait/AIT-010-managed-source/source-roots.txt`
- Current corpus:
  - `206` DLLs considered.
  - `205` managed DLLs.
  - `1` native/unreadable DLL skipped.
  - `40361` C# source files.
  - `58292` indexed types.
  - `20` manifest-missing failures, all UnityEngine module wrapper assemblies; this is not blocking for the current combat/API questions.
  - `Assembly-CSharp.dll` decompiled successfully into wrapper source with `7960` C# files and `15035` types.
- Example searches:

```powershell
rg -n "class UnitCtrlPlayer|class SkillAttack|AddSkillMartialExp|martialUseAddExp" .\generated\ait\AIT-010-managed-source\Assembly-CSharp
rg -n "il2cpp_runtime_invoke|RegisterTypeInIl2Cpp|MelonMod" .\generated\ait\AIT-010-managed-source
rg -n "UnitEffectSkillHpSuck|SkillCreateData|MissileShotData" .\generated\ait\AIT-010-managed-source\Assembly-CSharp
```

- Acceptance:
  - Full corpus remains ignored under `generated/`.
  - Script can resume after timeout by reading per-assembly manifests.
  - `Assembly-CSharp.dll` wrapper source is searchable for API shape, fields, wrappers, and callable symbols.
  - Conclusions still treat `Assembly-CSharp.dll` as IL2CPP wrapper/API-shape evidence, not original native branch logic.

## AIT-011 - Offline Official/Community dnSpy Corpus

- Goal: Turn one-off AIT outputs into a reusable local corpus split by trust/source: `official` for game/MelonLoader surfaces and `community` for external MOD samples.
- Tool: `tools/build-dnspy-corpus.ps1`.
- Default batch throttle: `10` in `tools/batch-decompile-managed-assemblies.ps1`.
- Generated root: `generated/app/`.
- Entry docs:
  - `docs/OFFLINE_CORPUS_WORKFLOW.md`
  - `generated/app/CORPUS_INDEX.md`
- Official outputs:
  - `official/game-root`: direct game-root DLL scan; native files such as `GameAssembly.dll` are recorded as non-managed.
  - `official/MelonLoader/Managed`: reuses AIT-010 via generated junction/reference and manifest.
  - `official/MelonLoader/Dependencies`: `169` DLLs, `164` managed, `5` native/unreadable, `19686` C# files, `22993` types.
  - `official/MelonLoader/root`: direct MelonLoader root DLLs.
- Community outputs:
  - `community/SaiLL`: main `SaiLL.dll` decompiled under `decompiled/main/`.
  - SaiLL dependencies: `10` DLLs, `3` managed, `7` native/unreadable.
  - SaiLL string annotation: `1346` `nBB.xBl(...)` calls decoded, `0` errors, cache at `annotations/string-cache.json`.
- Acceptance:
  - `rg -n "AddSkillMartialExp" generated/app/official` finds official static evidence.
  - `rg -n "Button.onClick" generated/app/community` finds community examples.
  - Native/unreadable DLLs appear in package failure reports.
  - Generated corpus remains under ignored `generated/`.

## AIT-012 - Community Dependency String Annotation

- Goal: Extend community MOD string annotation from the main MOD DLL into managed dependency DLLs.
- Tool changes:
  - `tools/annotate-obfuscated-strings.ps1` now accepts `-CallPrefix`, `-DecoderType`, `-DecoderMethod`, guard parameters, and optional `-UseDotnetHost`.
  - `tools/StringDecoderHost` is a tiny .NET host used when Windows PowerShell cannot load a modern target assembly directly.
  - `tools/build-dnspy-corpus.ps1` now queues and applies both SaiLL main and dependency decoders.
- SaiLL dependency decoder:
  - Assembly: `D:\Games\Steam\steamapps\common\鬼谷八荒\Mods\SaiLL\AI\ChatGuiGuLocal.dll`.
  - Decoder: `qMY.cMj.FMl(int)`.
  - Pattern: `cMj.FMl(...)`.
  - Guard: set static field `EM8` to `75` before invoking.
  - Host: `-UseDotnetHost`, because `ChatGuiGuLocal.dll` targets `net8.0`.
- Generated output:
  - `generated/app/community/SaiLL/annotations/reports/SaiLL-deps-ChatGuiGuLocal-cMj-FMl/`.
  - `generated/app/community/SaiLL/annotations/applied-to-deps-ChatGuiGuLocal.json`.
  - Annotated dependency source copied back to `generated/app/community/SaiLL/decompiled/deps/AI_ChatGuiGuLocal/ChatGuiGuLocal/`.
- Current result:
  - `158` `cMj.FMl(...)` calls decoded.
  - `0` errors.
  - `10` dependency `.cs` files annotated.
  - `69` unique `qMY.cMj.FMl` cache entries merged into SaiLL `annotations/string-cache.json`.
- Acceptance:
  - `rg -n "cMj.FMl" generated/app/community/SaiLL/decompiled/deps/AI_ChatGuiGuLocal` shows inline decoded comments.
  - Full count check reports `UnannotatedFMlLines = 0` for `AI_ChatGuiGuLocal`.
  - `string-cache.json` groups entries for both `KBR.nBB.xBl` and `qMY.cMj.FMl`.

## AIT-013 - Generated Root Migration And Additional MOD Corpus

- Goal: Move generated output from `docs/generated/` to root `generated/`, then add corpus packages for `ChatGuigu.dll` and `GGBH_MOD.dll`.
- Generated root: `generated/`.
- Corpus root: `generated/app/`.
- Tool changes:
  - `tools/build-dnspy-corpus.ps1` accepts `-SourceKind official|community|unclassified`.
  - `CORPUS_INDEX.md` is generated from discovered package manifests instead of a fixed SaiLL-only list.
  - `unclassified/` is a first-class local corpus category for readable but not-yet-classified DLLs.
- Migration result:
  - `docs/generated/` was copied to `generated/` and then removed after `robocopy /L` showed no source-only files.
  - `.gitignore` ignores both `generated/` and historical `docs/generated/` paths.
- ChatGuigu result:
  - Source: `D:\Games\Steam\steamapps\common\鬼谷八荒\Mods\ChatGuigu.dll`.
  - Output: `generated/app/community/ChatGuigu/`.
  - dnSpy source: `46` C# files, `23` namespaces, `60` types.
  - Package-local decoder: `WS3.eSA.UDi(...)`; `2205` calls decoded with `0` errors in the annotation report, and the browsable main source has `1726/1726` `eSA.UDi(...)` lines annotated.
  - Classification: `community`, because assembly metadata identifies `ChatGuigu`, and the code implements AI/chat, UI/剧情 patches, network/process behavior, and OpenAI-compatible calls.
- GGBH_MOD result:
  - Source: `D:\Games\Steam\steamapps\common\鬼谷八荒\Mods\GGBH_MOD.dll`.
  - Output: `generated/app/official/GGBH_MOD/`.
  - dnSpy source: `3` C# files, `1` namespace, `3` types.
  - Classification: `official/loader-bridge`.
  - Evidence: tiny generic bridge; `MelonInfo(typeof(ModMain), "ModName", "1.0.0.0", "GGBH_MOD", null)`; writes `MelonLoader/GGBH_MOD_LOAD_COMPLETE.txt`; patches `EventsMgr.Init`; registers `GameCMDMelonLoader`; handles `LoadDll` / `InitModMain`; calls `MelonHandler.LoadFromFile(...)`; reflects `<namespace>.ModMain.Init()` and `Destroy()`.
- Acceptance:
  - `generated/app/CORPUS_INDEX.md` lists `community\ChatGuigu\manifest.json`, `official\GGBH_MOD\manifest.json`, and `official\game-root\decompiled\Il2CppDumper_output\manifest.json`.
  - `docs/generated/` no longer exists after migration cleanup.
  - `generated/` remains ignored by Git.
  - `tools/build-dnspy-corpus.ps1` parser check passes.

## Current Notes

- `SaiLL_human_dnspy` contains dnSpy metadata comments such as `Token`, `RVA`, and `File Offset`; these are metadata/method body location annotations.
- `nBB.xBl(...)` calls in `SaiLL` are sample-local string-obfuscation/decryption calls. The integer expressions are obfuscation constants, not native machine code.

