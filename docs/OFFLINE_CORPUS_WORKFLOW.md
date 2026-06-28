# 离线代码语料库工作流

## 目的

`generated/app/` 是本项目本地 dnSpy 代码语料库入口。它只用于本机检索、证据整理和 MOD 开发参考，已经被 Git 忽略，不上传 GitHub。

旧路径 `docs/generated/` 已迁移到仓库根目录下的 `generated/`。后续不要再向 `docs/generated/` 写入生成内容。

## 信任分级

- `official/`：游戏本体、MelonLoader、`Managed`、`Dependencies`、GGBH_MOD loader bridge、Il2CppDumper native 输出等官方或运行时表面。优先用于确认 API 形状、类名、字段、方法签名、loader 行为和 IL2CPP 结构证据。
- `community/`：社区 MOD 样例。可参考写法、UI 注入、Harmony patch、资源路径、混淆字符串处理，但不能直接当成游戏机制真相。
- `unclassified/`：能反编译但来源/性质未完全确认的 DLL。先用于证据收集，等有更强 provenance 后再移动到 `official` 或 `community`。

运行时行为仍以 DWT 游戏内测试为准。IL2CPP wrapper、Cpp2IL stub、Il2CppDumper 输出、dnSpy 输出都不能单独证明事件顺序或状态变更归属。

## 当前布局

```text
generated/app/
  README.md
  CORPUS_INDEX.md

  official/
    game-root/
      decompiled/Il2CppDumper_output/
    GGBH_MOD/
      decompiled/main/
    MelonLoader/
      Managed/
      Dependencies/
      root/

  community/
    SaiLL/
      decompiled/main/
      decompiled/deps/
      annotations/
      failures/
      source-map.json
    ChatGuigu/
      decompiled/main/
      annotations/
      source-map.json

  unclassified/
    README.md
```

关键入口：

- `generated/app/CORPUS_INDEX.md`
- `generated/app/official/game-root/decompiled/Il2CppDumper_output/manifest.json`
- `generated/app/official/GGBH_MOD/manifest.json`
- `generated/app/official/MelonLoader/Managed/manifest.json`
- `generated/app/official/MelonLoader/Dependencies/manifest.json`
- `generated/app/community/SaiLL/manifest.json`
- `generated/app/community/ChatGuigu/manifest.json`

## 待批处理社区 MOD 来源

以下目录存放大量 MOD，已记录为后续 `community/` 批处理来源；当前只登记路径，不扫描、不解包、不写入 `generated/app/community/`：

```text
D:\Games\Steam\steamapps\common\鬼谷八荒\ModExportData
D:\Games\Steam\steamapps\workshop\content\1468810
```

批处理原则：有 `.cs` 源码的 MOD 优先索引源码；无源码时才用 dnSpy 反编译 DLL；默认只保留 `.cs`、`manifest.json`、`source-map.json`、程序化 `README.md` / `SOURCE_SUMMARY.md` / `OBFUSCATION_CANDIDATES.md`，不生成或保留 `.sln` / `.csproj`。未知混淆字符串先进入队列和缓存，不把解码任务绑死在 dnSpy 主流程里。

## 常用命令

刷新官方语料：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-dnspy-corpus.ps1 `
  -SourceKind official `
  -SourcePath 'D:\Games\Steam\steamapps\common\鬼谷八荒' `
  -OutputRoot '.\generated\app' `
  -PackageName game `
  -ThrottleLimit 10
```

刷新社区 MOD 语料：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-dnspy-corpus.ps1 `
  -SourceKind community `
  -SourcePath 'D:\Games\Steam\steamapps\common\鬼谷八荒\Mods\SaiLL.dll' `
  -OutputRoot '.\generated\app' `
  -PackageName SaiLL `
  -IncludeDependencies `
  -ThrottleLimit 10
```

GGBH_MOD 当前已作为 official loader bridge 维护；新来源未定 DLL 才使用 `unclassified`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-dnspy-corpus.ps1 `
  -SourceKind unclassified `
  -SourcePath '<unknown-package-main-dll>' `
  -OutputRoot '.\generated\app' `
  -PackageName '<package-name>' `
  -ThrottleLimit 10
```

检索示例：

```powershell
rg -n "AddSkillMartialExp" .\generated\app\official
rg -n "Button.onClick" .\generated\app\community
rg -n "OpenAiClient|UnityWebRequest|HarmonyPatch" .\generated\app\community\ChatGuigu
rg -n "GameCMDMelonLoader|LoadDll|InitModMain" .\generated\app\official\GGBH_MOD
rg -n "SkillAttack|UnitEffectSkillHpSuck|UnitHitDynIntHandler" .\generated\app\official\game-root\decompiled\Il2CppDumper_output
rg -n "nBB.xBl|cMj.FMl|eSA.UDi" .\generated\app\community
```

## 混淆字符串标注

字符串标注和 dnSpy 反编译是两个步骤。

已确认的包内解码器：

- `SaiLL.dll`：`KBR.nBB.xBl(...)`。
- `SaiLL/AI/ChatGuiGuLocal.dll`：`qMY.cMj.FMl(...)`，需要 `tools/StringDecoderHost`。
- `ChatGuigu.dll`：`WS3.eSA.UDi(...)`。

规则：

- `nBB`、`cMj`、`eSA` 都是社区 MOD 包内辅助方法，不是游戏 API。
- 新 MOD 如果出现新的混淆器，需要单独识别、单独缓存。
- 解码缓存放在对应包的 `annotations/string-cache.json`。
- 注解报告放在 `annotations/reports/`。
- 为了直接浏览源码，已解码 `.cs` 会复制回对应 `decompiled/` 目录。

## 当前包结论

`ChatGuigu.dll` 放在 `community/ChatGuigu`：

- `MelonInfo(typeof(ChatGuiguMain), "ChatGuigu", "0.0.1.0", "RTF", null)`。
- 代码包含 AI/chat、OpenAI 兼容请求、UI/剧情 patch、本地进程和网络管理。
- 判定为社区 MOD 样例。

`GGBH_MOD.dll` 放在 `official/GGBH_MOD`：

- DLL 位于游戏 `Mods` 根目录，但不像普通玩法 MOD。
- 只包含 `ModMain`、`ModItem`、`Patch_EventsMgr_Init` 等很小的桥接表面。
- patch `EventsMgr.Init` 后注册 `GameCMDMelonLoader`。
- 处理 `LoadDll` / `InitModMain`，调用 `MelonHandler.LoadFromFile(...)`，反射 `<namespace>.ModMain.Init()` / `Destroy()`。
- 写入 `MelonLoader/GGBH_MOD_LOAD_COMPLETE.txt`，像 loader readiness marker。

按当前项目约定，它已经被采纳为 `official/loader-bridge`。

`Il2CppDumper_output` 放在 `official/game-root/decompiled/Il2CppDumper_output`：

- 来源是 `resource/app/GameAssembly.dll` 与 `resource/app/global-metadata.dat`。
- 工具是 `D:\Games\tools\解包\Il2CppDumper-win-v6.7.46`。
- 输出包括 `dump.cs`、`il2cpp.h`、`script.json`、`stringliteral.json` 和 `DummyDll/`。
- 用于 IL2CPP 结构、偏移、地址、字符串和 native 分析入口；不能当作原始 C# 逻辑。

## 失败记录

native 或不可读 DLL 是正常情况，不视为缺失工作。失败记录位于各包 `failures/` 中。

当前典型例子：

- `official/game-root/failures/FAILED_ASSEMBLIES.md`：`GameAssembly.dll`、`UnityPlayer.dll` 等 native 文件。
- `official/game-root/decompiled/Il2CppDumper_output/`：`GameAssembly.dll + global-metadata.dat` 的 native IL2CPP 结构输出。
- `official/MelonLoader/Dependencies/failures/FAILED_ASSEMBLIES.md`：native bootstrap/haptics/capstone 文件。
- `community/SaiLL/failures/DEPENDENCY_FAILURES.md`：native AI/LLama 支持库。

## Agent 使用规则

- 从 `generated/app/CORPUS_INDEX.md` 开始。
- API/字段/loader 形状优先查 `official`。native IL2CPP 结构/偏移/字符串查 `official/game-root/decompiled/Il2CppDumper_output`。
- MOD 写法和 UI/Harmony 示例查 `community`。
- 来源不清的 DLL 查 `unclassified`，不要过早定性。
- 有新语料、解码器、分类判断时，同步更新 `docs/AI_CONTEXT.md`、`docs/API_TOOLCHAIN_TEST_PLAN.md` 和 `docs/FLYWHEEL_LOG.md`。
- 所有大体量生成源码继续留在 `generated/`，不要提交。
