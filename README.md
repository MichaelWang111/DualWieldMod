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

已接受的 Flywheel 记录：

- `FW-20260627-01 - Minimal Offhand Attack Existence`
- `FW-20260627-02 - Runtime Load Visibility Probe`

当前原型仍然是验证性质：日志和提示较多，副手暂时复用当前主手普通攻击，并使用固定间隔自动触发来证明“副手攻击存在”。下一轮应先清理诊断噪声，并改成更接近普通攻击输入的受控触发。

## 仓库结构

```text
src/       干净源码覆盖层，同步到真实 MOD 工程后编译
docs/      设计、API 调研、Flywheel 记录、开发流程文档
tools/     同步、构建等确定性辅助脚本
test/      编译探针和小型验证项目
ideas/     本地研究材料，只读参考，已被 Git 忽略，绝不上传
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

所有涉及 MOD 代码的交付都必须走 Flywheel：实现、真实工程编译、报告预期表现、等待用户进游戏测试、记录反馈，再进入下一轮。

详见 [docs/FLYWHEEL.md](docs/FLYWHEEL.md) 和 [docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md)。

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

## 关键文档

- [docs/FLYWHEEL.md](docs/FLYWHEEL.md)：迭代记录与交付协议。
- [docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md)：源码覆盖、同步构建、编译探针和运行时测试流程。
- [docs/DUAL_WIELD_DESIGN_MVP.md](docs/DUAL_WIELD_DESIGN_MVP.md)：当前玩法设计和 MVP 范围。
- [docs/DATA_FIELD_RESEARCH.md](docs/DATA_FIELD_RESEARCH.md)：配置字段、候选 API 和证据索引。
- [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md)：供后续 AI 会话快速恢复上下文的精简状态。
- [docs/MOD_QA_TUTORIAL_INDEX.md](docs/MOD_QA_TUTORIAL_INDEX.md)：本地官方 MOD 教程资料索引。

## 下一轮建议

推荐下一轮 Flywheel：

```text
FW-20260627-04 - Cleanup And Controlled Offhand Trigger
```

建议范围：

- 减少临时可见提示和日志噪声。
- 保留少量关键 debug 日志，例如 MOD 初始化、战斗开始、副手初始化失败原因。
- 将“每 60 帧自动触发”的验证逻辑改为更接近普通攻击输入的受控触发。
- 暂不加入 Q 轮盘、熟练度、战斗精力、资源消耗、不稳定攻击和永久存档。

## 提交守则

不要提交：

- `ideas/`
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
