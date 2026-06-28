# DualWieldMod

DualWieldMod 是一个面向《鬼谷八荒》的双持普通攻击 MOD 研发仓库。

这个仓库不是游戏生成的完整 MOD 工程，而是一个干净的开发与知识仓库：这里保存可维护源码、设计文档、API 调研、编译探针和同步脚本；真正由游戏生成的 MOD 工程只作为本地编译与进游戏测试目标。

## 项目目标

DualWieldMod 的目标不是做第二套快捷栏，而是做一个可以成长的双持战斗体系。

当前设计约束：

- 只有普通攻击允许双持。
- 左键普通攻击通道可以同时触发主手和副手普通攻击。
- 右键是绝技，不是副手普通攻击。
- 身法、神通后续可以做战斗中切换，但不做双持同步攻击。
- 后续系统会围绕熟练度、攻击模式默契度、战斗精力、灵力/念力消耗和神念不稳阶段展开。

## 当前状态

首个运行时原型已经在真实游戏中通过验证。

已确认：

- 真实游戏生成工程可以从本仓库的 `src/` 源码覆盖构建。
- Release 构建产物可以被游戏加载。
- `EBattleType.BattleStart` 事件可以被 MOD 收到。
- 最小副手 `SkillAttack` 可以从当前普通攻击初始化。
- `SkillAttack.Create(...)` 已在游戏中产生可见的第二道剑气/弹道效果。
- `DWT-004` 已确认副手只在普通攻击输入期间触发，并能产生第二弹幕和第二次伤害。
- `DWT-005` 已确认：最小玩家技能 UI 副手选择按钮可以写入 `offhandSkillId`，保存/重载后进战斗能以 `source=saved` 启动副手。
- `FW-20260627-09` 已确认：副手按钮 toggle 和主手卸下逻辑效果不错，技能说明还需后续优化但不阻塞。
- `FW-20260627-10` 已完成轮盘架构设计：轮盘系统拆成战前候选池设置 UI 和战中 Q 轮盘。
- `FW-20260627-11` 已编译通过：未设置副手时不再自动复制主手，避免无意 Double Hit。
- `FW-20260627-12` 已编译通过：主手为空但副手有效时，副手会升为主手并清空副手。

已接受的 Flywheel 记录：

- `FW-20260627-01 - Minimal Offhand Attack Existence`
- `FW-20260627-02 - Runtime Load Visibility Probe`
- `FW-20260627-05 - Cleanup And Controlled Offhand Trigger`
- `FW-20260627-08 - Minimal Offhand Selection Entry`
- `FW-20260627-09 - Offhand Toggle And Main Unequip`

等待进游戏测试的 Flywheel 记录：

- `FW-20260627-11 - No Offhand Bootstrap Patch`
- `FW-20260627-12 - Promote Saved Offhand To Main When Main Empty`

当前原型仍然是验证性质：双手普通攻击触发链路已经成立，副手不再自动空放，只会随普通攻击输入触发。最小副手选择、持久化、toggle 和主手卸下逻辑已经成立；正在等待验证两个 loadout guardrail：未设置副手就不双持，主手为空但副手有效时副手升主手并清空副手。通过后应先做技能界面的战前轮盘候选池设置 UI，再做战中 Q 轮盘。熟练度、战斗精力、资源消耗和不稳定攻击还未实现。

## 仓库结构

```text
src/       干净源码覆盖层，同步到真实 MOD 工程后编译
docs/      设计、API 调研、Flywheel 协议/日志、串行测试计划、开发流程文档
tools/     同步、构建等确定性辅助脚本
test/      编译探针和小型验证项目
ideas/     人类设计笔记，只读参考，已被 Git 忽略，绝不上传
resource/  本地官方教程、app 运行时副本、解包结果、外源 DLL，只读参考，已被 Git 忽略，绝不上传
generated/  可复现的索引、反编译、扫描输出，已被 Git 忽略，绝不上传
```

真实游戏生成 MOD 工程当前位于：

```text
D:\Games\mods\guigubahuang\ModProject_h6Zv8g\ModProject
```

当前 MOD 命名空间/程序集：

```text
MOD_h6Zv8g
```

## 开发流程

所有涉及 MOD 代码的交付都必须走 Flywheel：实现、真实工程编译、报告预期表现、等待用户进游戏测试、记录反馈，再进入下一轮。运行时行为还需要绑定 `DWT-###` 串行测试用例，避免一次迭代跨太多系统。

详见 [docs/FLYWHEEL.md](docs/FLYWHEEL.md)、[docs/FLYWHEEL_LOG.md](docs/FLYWHEEL_LOG.md)、[docs/SERIAL_TEST_PLAN.md](docs/SERIAL_TEST_PLAN.md) 和 [docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md)。

从仓库根目录执行 dry run：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1
```

同步源码到真实 MOD 工程并构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-src-to-game.ps1 -Apply -Build
```

`-Build` 默认使用 `Release`，因为当前游戏内验证已经确认 Release 产物会被加载。

## API 编译探针

`test/ApiProbe` 用于验证不确定的游戏内核 API 是否能通过编译。它只能证明符号和签名存在，不能证明运行时行为正确。

```powershell
powershell -ExecutionPolicy Bypass -File .\test\ApiProbe\build.ps1
```

如果需要手动指定游戏托管程序集目录，可传入 `-ReferenceDir`，指向本机游戏安装目录下的 `MelonLoader\Managed`。

## 离线 API 检索

底层调研拆成两条前置轨道：`AIT` 验证工具链能力，`KEP` 用已验证工具回答关键战斗证据问题；`DWT` 只负责真实 MOD 行为和进游戏测试。官方 `GGBH_API.chm`、Cecil、dnSpy、资源索引和 ApiProbe 都只提供符号/编译/静态证据，不能单独证明运行时行为。

本地 app 运行时副本位于 `resource/app/`：根目录保存 `GameAssembly.dll`、`global-metadata.dat`、`UnityPlayer.dll` 等 native IL2CPP 文件，`resource/app/MelonLoader/` 保存 MelonLoader、Managed wrapper 和依赖。Il2CppDumper 结果位于 `generated/app/official/game-root/decompiled/Il2CppDumper_output/`，用于结构/偏移/字符串等 native 静态证据。

当前官方静态语料扫描结论见 [docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md](docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md)：没有发现原生副手/双持普通攻击机制；但 `SkillAttack`、`SkillDataAttack`、`SkillCreateData`、`MissileShotData`、经验写入、命中/吸血事件、角色资源和 UI/输入表面已经足够支撑自建双持的一致性探针。

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\index-ggbh-api-chm.ps1
powershell -ExecutionPolicy Bypass -File .\tools\inspect-combat-system.ps1
powershell -ExecutionPolicy Bypass -File .\tools\export-dnspy-types.ps1
powershell -ExecutionPolicy Bypass -File .\tools\decompile-dotnet-assembly.ps1 -AssemblyPath .\resource\Mod解包结果\SaiLL.dll -TypeName A7T.t7w -OutputDir .\generated\ait\AIT-001
powershell -ExecutionPolicy Bypass -File .\tools\inventory-dotnet-assemblies.ps1 -Path .\resource\app,.\resource\Mod解包结果\SaiLL.dll -OutputDir .\generated\ait\AIT-003
powershell -ExecutionPolicy Bypass -File .\tools\index-resource-knowledge.ps1
```

这些命令输出到本地 `generated/`，该目录可复现且已被 Git 忽略。正式仓库只保留脚本和结论文档。

## 关键文档

- [docs/FLYWHEEL.md](docs/FLYWHEEL.md)：迭代交付协议和记录模板。
- [docs/FLYWHEEL_LOG.md](docs/FLYWHEEL_LOG.md)：每轮 Flywheel 历史记录。
- [docs/SERIAL_TEST_PLAN.md](docs/SERIAL_TEST_PLAN.md)：串行运行时测试用例和验收梯子。
- [docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md)：源码覆盖、同步构建、编译探针和运行时测试流程。
- [docs/COMBAT_SYSTEM_INSPECTION_PLAN.md](docs/COMBAT_SYSTEM_INSPECTION_PLAN.md)：CHM、Cecil、dnSpy 和运行时 trace 的战斗系统检查流程。
- [docs/API_TOOLCHAIN_TEST_PLAN.md](docs/API_TOOLCHAIN_TEST_PLAN.md)：AIT 离线工具链能力测试。
- [docs/KEY_EVIDENCE_PROBE_PLAN.md](docs/KEY_EVIDENCE_PROBE_PLAN.md)：KEP 关键战斗证据探针计划。
- [docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md](docs/OFFICIAL_DUAL_WIELD_STATIC_SCAN.md)：官方静态语料中与双持相关的可用表面、排除项和 KEP 影响。
- [docs/DUAL_WIELD_DESIGN_MVP.md](docs/DUAL_WIELD_DESIGN_MVP.md)：当前玩法设计和 MVP 范围。
- [docs/WHEEL_DESIGN.md](docs/WHEEL_DESIGN.md)：战前轮盘候选池设置 UI 与战中 Q 轮盘架构。
- [docs/DATA_FIELD_RESEARCH.md](docs/DATA_FIELD_RESEARCH.md)：配置字段、候选 API 和证据索引。
- [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md)：供后续 AI 会话快速恢复上下文的精简状态。
- [docs/MOD_QA_TUTORIAL_INDEX.md](docs/MOD_QA_TUTORIAL_INDEX.md)：本地官方 MOD 教程资料索引。

## 当前测试轮次

当前等待进游戏测试的 Flywheel：

```text
FW-20260627-12 - Promote Saved Offhand To Main When Main Empty
```

目标：确认主手为空但副手有效时，副手会自动升为主手并清空副手；主手副手都为空时不处理。

测试范围：

- 先设置一个副手，再确保主手为空，进入战斗后副手应变成主手。
- 升主手后副手应清空，同一场战斗不应触发副手弹幕/伤害。
- 主手副手都为空时进入战斗，MOD 不应改动 loadout 或报错。
- 主手副手都有效且不同技时，仍应以 `source=saved` 正常双持。
- 这一轮仍不做战前候选池、战中 Q 轮盘、熟练度、战斗精力、资源消耗、不稳定攻击。

## 提交守则

不要提交：

- `ideas/`
- `resource/`
- `generated/`
- 游戏生成工程目录 `D:\Games\mods\guigubahuang\ModProject_h6Zv8g`
- `bin/`、`obj/`、`refs/`
- `*.dll`、`*.pdb`、`*.cache`、`*.csproj.user`
- 导出的 MOD 包、复制出来的游戏 DLL 或其他二进制构建产物

上传前建议检查：

```powershell
git status --short
git diff --check
git diff -- .gitignore dual_wield_mod_skill.md docs src tools test README.md
```

只暂存明确允许进入仓库的文件。

