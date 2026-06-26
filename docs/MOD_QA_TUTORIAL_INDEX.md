# MOD Q&A Tutorial Index

This file summarizes the `.docx` tutorial files found directly under `ideas/modQ&A/*/`. It is meant as a fast lookup layer before opening the original documents.

Direct child directories checked:

- `MOD模板例子`: no direct `.docx` tutorial file at this level; contains nested examples and project files.
- `代码编写教程`: contains `代码编写教程.docx` and `GGBH_API.chm`.
- `资源修改教程`: contains `资源修改教程.docx`.
- `配置修改教程`: contains `配置修改教程.docx`.
- `鬼谷八荒MOD使用指南基础版 1.0`: contains `鬼谷八荒MOD使用指南基础版 1.0.docx`.

## 代码编写教程.docx

Purpose: explains how the MOD code project is created, built, debugged, and loaded.

Key points:

- The MOD editor creates a Visual Studio project and a required main class named `ModMain`.
- Default namespace is `MOD_XXXXXX`, where `XXXXXX` is the MOD id.
- If the code namespace is changed, the assembly name and MOD editor UI namespace must also be changed, or the DLL can fail to load.
- Visual Studio version: 2022.
- Target framework: `.NET Framework 4.7.2`; this is mandatory.
- Write code from the `ModMain.cs` entry point and refer to the Guigubahuang API document.
- Default DLL references should keep `Copy Local = False`.
- If adding other DLL references from the game/MelonLoader folder, also set `Copy Local = False`; otherwise extra DLLs may be copied into Release and cause MOD failure.
- Build should produce `bin/Release/MOD_XXXXXX.dll` and should not contain extra DLLs unless they are truly required plugin DLLs.
- The MOD editor's `进入游戏调试` copies all Release DLLs into the game and loads them.
- After debugging, the MOD can be uploaded to the workshop.
- The game includes MelonLoader.
- MelonLoader console can be enabled with launch option `--melonloader.showconsole`.
- Harmony patches require manual activation, for example:

```csharp
var item = new HarmonyLib.Harmony("MOD_hK0uXK");
item.PatchAll(Assembly.GetExecutingAssembly());
```

Relevance to DualWieldMod:

- Use `.NET Framework 4.7.2` when reconstructing source.
- Keep referenced game/MelonLoader DLLs `Copy Local = False`.
- Use `ModMain.Init()` / `Destroy()` as lifecycle boundary.
- Harmony is available, but should be reserved for places where events/timers/UI hooks are not enough.

## 资源修改教程.docx

Purpose: explains how to modify or add game resources such as skill effects, monster models, sounds, and UI prefabs.

Key points:

- Resource modification can replace or add existing game resources.
- `Resources（资源对照）` contains directory descriptions and resource names for in-game resources.
- `ResBuildABProject` is the Unity project template used to build resources.
- `ResBuildABProject_Example` contains example Unity projects.
- Unity version: `2020.3.9`.
- `AssetBundle`: update AB in Unity, generated AB files go under this folder.
- `Resources`: resources here are packed into AB. Prefab dependencies such as textures/materials should generally not be placed under `Resources`; follow the examples.
- To replace a game resource, keep the same path and name. The game prioritizes MOD custom resources when loading.
- To add a new resource, add it under the same directory structure; config tables can reference it.
- Example: adding a prefab under `Effect/Battle/Skill` allows `BattleMissile.model` to reference the new resource.
- Skill effects under `Skill` must have a root-level `Box` 2D collider for hit detection.
- `ResBuildABProject` must live under the MOD's `ModRes` directory for game debug discovery:

```text
ModProject_XXXXXX\ModProject\ModRes\ResBuildABProject\Assets\AssetBundle
```

Battle/skill effect notes:

- `BattleHuman`: battle character model example. Copy existing PNG/meta/prefabs when making parts because meta contains skeleton data.
- `PortraitHuman`: character portrait parts; new hair/clothes/back/head ornaments may also need battle character parts.
- `BattleMonst`: monster model example.
- If `BattleSkillAttack` has the relevant attack-animation field set to `1`, the attack animation needs an `Attack` broadcast value.
- Small monsters can use rigidbody mass `150`; boss mass should be `1000000` to avoid being pushed.
- Monster models need mount points (`Posi`), hit area boxes, size, root rigidbody, and box data.
- Adding monsters involves at least: monster attribute table, martial skill table, skill base table, missile table, and default monster AI table.
- More complex skills may also involve effect tables and halo tables.
- `BattleScenesUnit` explains battle scene obstacles and scene parts.
- `BattleSkillEffect` explains skill effects:
  - `Skill` effects require first-level `Box` for projectile hit detection.
  - `Skill` effects correspond to missile and halo config tables.
  - `Unit` effects require `EffectUnitNodeCtrl`, e.g. slowdown uses `NodeType=Down`, `IsTarget=true`.
  - `Unit` effects correspond to effect config tables.
  - Effects must support scaling and selection.
  - `PlaySoundsCtrl` can play effect sounds; behavior depends on `IsBG`.
  - `EffectLoopActivedBoxCtrl` can toggle a collider for persistent damage areas; `AttackCount=-1` means unlimited hits, `AttackDelay=0_333` means three hits per second, prefix `0_` is fixed.
  - `Resources/Effect/Map` and `Resources/Effect/UI` can be created with `GameEffectTool.CreateGo` from code.
- UI resource creation:
  - A custom UI prefab can be created in Unity, but opening it requires code.
  - Use `g.ui.OpenUI`.
  - Add the UI script component manually in code.
  - UI script should inherit `UIBase`.
  - Because MOD code is dynamically loaded DLL, Mono scripts in custom resources must be manually `AddComponent` from code.
  - Non-game-directory resources can be loaded with `g.res.Load`.

Relevance to DualWieldMod:

- A polished Q wheel can be implemented as a custom UI prefab, but a code-driven prototype may be faster.
- Hover/click wheel UI should likely inherit `UIBase` if built as a custom prefab.
- Skill visual changes can use existing resource names first; new wheel art/effects can be added later through AB.
- Offhand instability visual feedback could reuse effect resources or later add custom effects under `Effect/Battle/Skill` or UI effects.

## 配置修改教程.docx

Purpose: explains how to add or modify config tables, avoid ID conflicts, use commands/conditions, and export debug data.

Key points:

- Config modification can adjust existing game config or add new config.
- The `配置` folder contains most original game configs and field descriptions.
- Config tables use `int` ids, not string ids, so ID conflicts are possible between MODs.
- Local MOD load order is top to bottom; lower MOD config can override upper MOD config.
- The MOD editor assigns a random int when initialized, excluding the reserved game range `-1,000,000` to `100,000,000`.
- In Excel configs, custom ids must use `MID&XXXX`, for example `MID&101`.
- Linked config fields can reference multiple custom ids, e.g. `MID&101|MID&102`.
- Game ids do not need the `MID&` prefix.
- Prefer custom id offsets under 10,000 and keep them consecutive.
- During export, the editor adds the MOD random int to the `MID&` offset, producing the true runtime id.
- If referencing another MOD's data, manually calculate the true id.
- Some config table id fields are meaningless, such as localization table ids; start at `MID&1` and increment.
- `MID&XXXX` can only be used in Excel, not JSON.

Config directory rules:

- MOD config directory:

```text
ModProject_xxxxxx\ModProject\Excel
```

- Header directory:

```text
<Game Install>\StreamingAssets\modFQA\配置表修改教程\配置表头
```

- To modify a table, copy its header file to the config directory and edit.
- Multiple folders are allowed under the config directory.
- Excel file name and sheet/table name must match.
- Export traverses all `*.xlsx` files.

Modify vs add:

- To modify existing config: use the original config id and fill only fields to change; leave other fields blank.
- To add new config: id must be `MID&XXXX`; blank fields default to `0`.
- When game updates add new fields, blank defaults are `0`, so new configs should fill required data deliberately.
- Debug and export can be checked under generated debug/Excel data.
- JSON config is supported, but JSON and XLSX in the same folder cannot share the same table name; use subfolders if needed.

Common reference tables:

- `配置对照 -> 配置对照表 -> 剧情条件及影响`: command/effect descriptions.
- Fields named `function` or described as commands can usually execute command strings; multiple commands can use `|`.
- Ignore `mod未支持` prefixes in command docs; they are hints and do not block use.
- `配置对照 -> 配置对照表 -> 条件说明表`: condition descriptions.
- Conditions use `A` and `B` parameters. If not provided, `A` is player and `B` is empty.
- Dynamic text/calls include patterns such as `{name|A}` and `{call|B|A}`.
- `配置对照 -> 配置对照表 -> 字体颜色`: rich text, colors, icons, and TextMeshPro-supported formatting.
- In text, icons can be embedded, e.g. `这是一个骰子{icon_gailv}图标`.
- `配置对照 -> 配置对照表 -> 副本作用功能`: dungeon-only commands/effects.

Relevance to DualWieldMod:

- Any new config tables for wheel UI, mastery curve, pattern aliases, or effects should use Excel `MID&` ids, not JSON `MID&` ids.
- Pattern alias data may be easier as MOD-owned JSON in `g.data.obj` or a code dictionary at first; if moved to config tables, follow `MID&` rules.
- Skill/effect additions should use copied table headers and match file/sheet names.
- Rich text/icon syntax can support in-game tips for dual stages.

## 鬼谷八荒MOD使用指南基础版 1.0.docx

Purpose: broad beginner guide for MOD capabilities and editor workflows.

High-level capability list:

- Add new playable elements.
- Customize or add story content and large encounters.
- Add custom NPCs.
- Create fortuitous events.
- Create destinies/lucks.
- Add small sects or customize existing sects.
- Add normal sects.
- Add mounts.
- Add items.
- Customize dungeons.
- Share MODs through Fanbook MOD site or file copy.

Function categories described:

- Game commands: produce items, add luck/destiny, increase attributes, create map events, enter dungeons, etc. Commands can run from many places such as fortuitous event triggers and dialogue options.
- Game conditions: conditions over player realm, attributes, relationships, possession, etc. Some are single-character checks and some are two-character checks.
- Luck/destiny: create innate luck, acquired luck, and breakthrough destiny changes.
- Luck special effects: special behaviors such as creating NPCs or monthly item output.
- Fortuitous events: trigger mechanism that can open story or execute commands directly.
- Drama/dialogue: custom story UI and dialogue flows.
- Items: custom story items, mounts, pills, etc.
- Map points: objective target lookup, such as finding an event point.
- Tasks: support event/story flows.
- Map events: custom overworld events, such as caves.
- Custom NPCs: name, attributes, portrait, sect, etc.
- Game output: custom item/manual outputs.

Examples summarized:

- Custom destiny MOD:
  - Create a destiny/luck.
  - Add effects such as modifying sword aptitude and producing an artifact/item.
  - Save and enter game debug.
- Create NPC:
  - Configure initial position, realm, gender, age, name.
  - Configure innate luck.
  - Configure portrait, personality, custom attributes, and relationships.
- Create small sect:
  - Configure base sect info and required innate luck.
- Custom item via fortuitous event:
  - Create event.
  - Create dialogue.
  - Configure dialogue option command to produce item.
  - Configure monthly repeated event based on owning an item.
- Create/custimize normal sect.
- Custom mount:
  - Create item.
  - Configure icon, level/quality, stack/drop rules.
  - Configure mount effects, UI model image, map model image, animation types, effects, and sounds.
  - Create event/story output for the mount.
- Custom dungeon:
  - Can be generated by map movement, map event + story command, fortuitous event branch, operation end, or designated area placement.
  - Dungeon config can include map icon, scene, size, route type, room count, monster waves, normal/elite/boss monsters, drops, and advanced settings.
- Custom NPC capture/story linking:
  - Use NPC capture conditions and display captured NPCs in dialogue.
  - Link dialogue sections through dialogue option buttons.

Relevance to DualWieldMod:

- Confirms MOD framework is broad enough for code, config, resources, events, commands, items, and UI flows.
- Most of DualWieldMod's core should be code-first because it modifies battle input and runtime skill firing.
- Cultivation growth for pattern mastery could later be represented as a custom event, item, story interaction, or UI flow.
- Debug workflow is consistently `保存项目` / `进入游戏调试`.

## Useful Follow-Up Files

When a concrete implementation question comes up, use these resources before guessing:

- API and code examples:
  - `ideas/modQ&A/代码编写教程/GGBH_API.chm`
  - `ideas/modQ&A/代码编写教程/ModMain/Example/Example.cs`
  - `ideas/modQ&A/代码编写教程/ModMain/ModMain.cs`
- Config field tables:
  - `ideas/modQ&A/配置修改教程/配置表头/*.xlsx`
  - `ideas/modQ&A/配置修改教程/配置（只读）Json格式/*.json`
  - `ideas/modQ&A/配置修改教程/配置对照/*.xlsx`
- Skill config examples:
  - `ideas/modQ&A/MOD模板例子/技能配置例子/ModProject/说明.txt`
  - `ideas/modQ&A/MOD模板例子/技能配置例子/ModProject/ModExcel/*.xlsx`
- UI/resource examples:
  - `ideas/modQ&A/MOD模板例子/替换游戏UI、插图例子/ModProject/ModCode/ModMain/`
  - `ideas/modQ&A/资源修改教程/ResBuildABProject_Example/`
- Decompiled seed implementation:
  - `ideas/Mod解包结果/MOD_Addk03/`

## Confirmed Attribute Keys From Config

From `RoleAttributeDesc.json`:

```text
energy = 精力
mp = 灵力
sp = 念力
```

These are config attribute keys, not yet verified runtime read/write fields.

From skill mastery configs:

```text
BattleSkillMastery.name = skill_mastery1 .. skill_mastery12
BattleSkillTrain.masteryLevel = target/current mastery tier used by training config
BattleSkillTrain.mastery = mastery amount gained by training config
```

These are config keys/thresholds, not yet verified runtime fields on a learned skill instance.

## Open Runtime Questions

The tutorials help narrow the search but do not answer these directly:

- What is the exact runtime field for a learned normal attack's current proficiency/mastery?
- What is the exact runtime API for current and max `mp` / `sp` during battle?
- What is the exact runtime action/API for unique skill, movement skill, and divine skill switching?
- Can a custom wheel UI swallow base left-click input through UI raycast alone, or does it need Harmony patching?
- Does hover require Unity `EventTrigger`, pointer interfaces, or an existing game UI component pattern?
