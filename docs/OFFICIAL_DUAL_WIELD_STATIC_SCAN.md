# 官方静态语料双持能力扫描

## 目的

本文件记录 2026-06-28 对 `generated/app/official` 的定向静态检索结果，问题是：官方语料中是否存在可直接支持 DualWieldMod 的“双持”功能或足够接近的战斗逻辑。

静态语料只证明符号、字段、方法、事件表面存在。是否真正按预期运行，仍需要 ApiProbe 编译确认和 DWT 进游戏 trace。

## 2026-06-28 纠偏说明

上一轮实际完成的是 `official` 语料的符号/字段/事件表面扫描，不是完整的方法内部调用链反编译。

已检查到的语料分层如下：

- `generated/app/official/game-root/`：直接 dnSpy 扫描根目录 DLL 时，`GameAssembly.dll`、`UnityPlayer.dll` 等是 native/unreadable；可用内容主要来自用户放入的 `Il2CppDumper_output`，即 `dump.cs`、`script.json`、`il2cpp.h`、`stringliteral.json`、`DummyDll/`。它提供 IL2CPP 结构、地址、token、字符串和 dummy 类型，不提供原始 C# 方法体。
- `generated/app/official/MelonLoader/Managed/decompiled/source/`：已重新生成 canonical Managed 语料，包含 41,380 个 `.cs` 文件。它主要是 MelonLoader/Unhollower 生成的 IL2CPP wrapper C#，能显示 MOD 可调用包装、`NativeMethodInfoPtr_*`、`CallerCount`、`CachedScanResults`、`XrefRangeStart/End` 等交叉引用线索，但游戏核心方法体通常仍是 `IL2CPP.il2cpp_runtime_invoke(...)` 包装，不是游戏原始业务逻辑。
- `generated/app/official/MelonLoader/Dependencies/.../cpp2il_out_Assembly-CSharp/`：包含 Cpp2IL 产出的 `Assembly-CSharp` 结构/stub C#。它能确认类、字段、方法签名、地址、部分事件数据形状，但核心战斗方法多为 `{ }`、`return null`、`return default(...)`，不能直接读出方法内部逻辑。
- `generated/app/official/MelonLoader/root/decompiled/`：MelonLoader 根目录托管库，例如 Harmony、MelonLoader、Mono.Cecil、MonoMod。这里更接近普通 managed 反编译，可用于理解 loader/hook/toolchain 行为，但不是游戏战斗内核。

当前 `Managed` 与 `Dependencies` 之所以都能检索到 `Assembly-CSharp`，不是因为目录写错，而是来源不同：`Managed/Assembly-CSharp.dll` 是 MOD 可调用 wrapper；`Dependencies/Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out/Assembly-CSharp.dll` 是 Cpp2IL 结构/stub。完整本地统计见 ignored 报告 `generated/app/official/MelonLoader/METHOD_BODY_QUALITY_REPORT.md`。

因此，本文件的结论应理解为“官方静态 API/结构证据层”，而不是“完整源码调用链层”。如果要做方法内部探测，需要进入 native IL2CPP 分析或运行时 trace，而不是只读这些 C# stub/wrapper。

## 结论

没有发现原生“副手普通攻击 / 双持普通攻击”系统。

`dual`、`LeftHand`、`RightHand` 等命中大多来自 Unity XR、InputSystem、Steam 输入、Socket `DualMode` 等通用库，不是《鬼谷八荒》的武技双持机制。因此当前双持仍应视为 MOD 自建系统，而不是打开某个官方隐藏开关。

但官方静态语料已经足够丰富，可以支撑自建双持的一致性验证：技能对象、冷却、弹道归因、命中事件、吸血事件、经验写入、角色资源、UI 和输入表面都能找到对应入口。

更准确地说：它足够支撑 KEP 的 ApiProbe/Hook 设计和 DWT trace 设计；尚不足以单独证明战斗核心内部调用顺序。

## 可借力表面

| 模块 | 静态证据 | 对双持的意义 | 可信等级 |
| --- | --- | --- | --- |
| 普通攻击对象 | `SkillAttack.Init(...)`, `SkillAttack.IsCreate(...)`, `SkillAttack.Create(...)` | 副手普通攻击对象可以按 learned skill 初始化并创建弹道。当前 DWT 已运行时验证可见弹道与伤害。 | Runtime Confirmed for create |
| 冷却/消耗绑定 | `SkillDataAttack.actionMartialData`, `SkillDataAttack.mpCost`, `SkillDataAttack.cd`, `SkillDataAttack.lastShotTime` | 技能的一致性核心应落在 `SkillDataAttack`，不能只改弹道。 | Confirmed Symbol |
| 技能创建归因 | `SkillBase.UseSkillCreateData()`, `SkillCreateData.skillCreateSoleID`, `mainSkillID`, `valueData`, `createSkillBase` | 可以追踪本次攻击创建源，后续用于判定命中/吸血/经验归属。 | Confirmed Symbol |
| 弹道归因 | `MissileShotData.skillCreateData`, `dmgRata`, `isLeft`, `phycicalDmg`, `magicDmg` | 弹道携带 `SkillCreateData`，是检查副手是否继承主手效果的关键证据点。 | Confirmed Symbol |
| 角色技能槽 | `UnitCtrlBase.skills`, `allSkills`, `step`, `ultimate`, `fieldSkill` | 原生战斗单位区分普通攻击列表、身法、绝技、领域等；非普通攻击切换要分类处理。 | Confirmed Symbol |
| 玩家技能重建 | `UnitCtrlPlayer.CreateSkillAttack(MartialType)` | 可能是战斗中重建普通攻击的候选入口，但是否可安全在局内调用未知。 | Candidate |
| 已学技能数据 | `DataUnit.UnitInfoData.skillLeft`, `skillRight`, `allActionMartial`, `GetActionMartial(s)` | 战前候选池、主手/副手选择、满熟练度检查都应从 learned action martial 数据出发。 | Confirmed Symbol |
| 装备/卸下 | `UnitActionMartialEquip`, `UnitActionMartialUnequip` | 战前 UI 切换仍应优先用原生 action，而不是直接改存档字段。 | Runtime Confirmed for current use |
| 经验链 | `UnitCtrlPlayer.AddSkillMartialExp(...)`, `martialUseAddExp`, `DataUnit.UnitInfoData.AddMartialExpInBattle`, `AddMartialExp`, `GetMartialAddExpRate`, `UnitActionRoleBattle.SkillAddExp` | 官方表面足够追踪经验写入链，但当前副手经验归属仍未修正。 | Confirmed Symbol / Runtime issue |
| 命中事件 | `EBattleType.OneUnitHitSkill`, `OneUnitHitSkillFront`, `UnitHitDynIntHandler`, `UnitHitDynIntHandlerInAttack*` | 可作为 DWT-025 归因 trace 的事件层。 | Confirmed Symbol |
| 使用事件 | `EBattleType.OneUnitUseSkill`, `OneUnitUseSkillInBase`, `OneUnitUseSkillAttack`, `OneUnitUseSkillAttackFront` | 可记录每次技能释放的 `skill` 与 `SkillCreateData`。 | Confirmed Symbol |
| 吸血事件 | `EBattleType.UnitEffectSkillHpSuck(unit, skill)`, `EBattleTypeData.UnitEffectSkillHpSuck.createSkillBase`, `hitData`, `hpSuck` | 可验证副剑是否错误继承主刀吸血。 | Confirmed Symbol |
| 资源字段 | `UnitDataBase.mp/sp/maxMP/maxSP`, `WorldUnitDynData.mp/mpMax/sp/spMax/mpRestore/spRestore`, `SkillDataAttack.mpCost` | 灵力/念力读取和阶段消耗有静态字段基础，但写入边界需 ApiProbe + DWT。 | Candidate |
| 输入/UI | `DataGloble.KeyData.battleSkill1`, `UnitPlayerInputCtrl`, `UIPlayerInfoSkill`, `UIPlayerInfoBase.Skill.goSkillLeftRoot`, `Button.onClick`, `UISkyTipEffect`, `UITipItem` | 当前 PlayerInfo 副手按钮与未来战前候选池 UI/战中轮盘都有官方表面可参考。 | Runtime Confirmed for minimal UI |

## 关键边界

1. 没有官方双持普通攻击开关。DualWieldMod 的双持是 MOD 自建，并需要自建一致性契约。
2. 只调用 `SkillAttack.Create(...)` 能产生视觉与伤害，但不自动保证经验、吸血、词条、资源消耗都归属副手。
3. 后续切换不能只改 `SkillCreateData` 或弹道对象，至少要保证这些对象一致：`SkillAttack`、`SkillDataAttack.actionMartialData`、`SkillCreateData.createSkillBase/mainSkillID`、`MissileShotData.skillCreateData`、命中事件中的 `skill/hitData`、经验写入目标。
4. `UnitCtrlPlayer.CreateSkillAttack(MartialType)` 是局内切换最值得验证的候选入口，但静态语料不能证明它能在战斗中安全重建技能列表。
5. `DualMode` 不是战斗双持，它属于 `System.Net.Sockets.Socket`，应排除。

## 对 KEP 的影响

新增分层要求：KEP 结论应标注证据来源是 wrapper、Cpp2IL stub、Il2CppDumper native metadata、CHM、ApiProbe，还是 DWT runtime。只有 wrapper/stub 命中时，不得写成“已读到原始函数体”。

- `KEP-001` 经验链应优先围绕 `UnitCtrlPlayer.AddSkillMartialExp(...)`、`martialUseAddExp`、`DataUnit.UnitInfoData.AddMartialExpInBattle/AddMartialExp`、`UnitActionRoleBattle.SkillAddExp` 设计 ApiProbe 和 DWT trace。
- `KEP-002` 吸血/效果归因应同时记录 `OneUnitUseSkillAttack`、`OneUnitHitSkill`、`UnitHitDynIntHandler`、`UnitEffectSkillHpSuck`，并输出 `skillCreateSoleID/mainSkillID/createSkillBase`、`hitData`、`hpSuck`。
- `KEP-003` 局内切换应先验证 `UnitCtrlPlayer.CreateSkillAttack(MartialType)`、`UnitCtrlBase.skills/allSkills`、`SkillAttack.data.actionMartialData` 是否可编译访问，再做最小运行时 probe。
- `KEP-004` 资源访问应先编译确认 `UnitDataBase` / `WorldUnitDynData` 当前值和最大值字段，再决定是否写入 `mp/sp`。

## 常用检索

优先检查 MelonLoader/Unhollower wrapper 和 Cpp2IL `Assembly-CSharp`，`game-root/Il2CppDumper_output` 作为 native metadata/地址补充：

```powershell
rg -n "CreateSkillAttack|AddSkillMartialExp|UnitEffectSkillHpSuck" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official\MelonLoader\Managed\decompiled\source\Assembly-CSharp" --glob "*.cs"
rg -n "CreateSkillAttack|AddSkillMartialExp|UnitEffectSkillHpSuck" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official\MelonLoader\Dependencies\decompiled\Il2CppAssemblyGenerator_Cpp2IL_cpp2il_out_Assembly-CSharp" --glob "*.cs"
rg -n "CreateSkillAttack|AddSkillMartialExp|UnitEffectSkillHpSuck" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official\game-root\decompiled\Il2CppDumper_output"
```

原有广义检索：

```powershell
rg -n "dual|offhand|副手|双持|LeftHand|RightHand" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official" --glob "*.cs"
rg -n "CreateSkillAttack|SkillAttack|SkillDataAttack|SkillCreateData|MissileShotData" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official" --glob "*.cs"
rg -n "AddSkillMartialExp|martialUseAddExp|AddMartialExpInBattle|SkillAddExp" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official" --glob "*.cs"
rg -n "UnitEffectSkillHpSuck|OneUnitHitSkill|UnitHitDynIntHandler|OneUnitUseSkillAttack" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official" --glob "*.cs"
rg -n "mpMax|spMax|mpRestore|spRestore|battleSkill1|goSkillLeftRoot" "D:\WorkSpace\Codex\DualWieldMod\generated\app\official" --glob "*.cs"
```

## 证据索引

| 结论 | 主要证据路径 |
| --- | --- |
| 无直接双持机制 | `generated/app/official/game-root/decompiled/Il2CppDumper_output/dump.cs` 中 `DualMode` 属于 Socket；`LeftHand/RightHand` 命中多为 Unity XR/InputSystem。 |
| Managed 与 Dependencies 没有混放 | `generated/app/official/MelonLoader/Managed/decompiled/source/source-roots.txt`, `generated/app/official/MelonLoader/Dependencies/decompiled/source-roots.txt`, `generated/app/official/MelonLoader/METHOD_BODY_QUALITY_REPORT.md` |
| 普通攻击对象与冷却字段 | `generated/app/official/MelonLoader/Managed/decompiled/source/Assembly-CSharp/Assembly-CSharp/Assembly-CSharp/SkillAttack.cs`, `generated/app/official/MelonLoader/Dependencies/decompiled/Il2CppAssemblyGenerator_Cpp2IL_cpp2il_out_Assembly-CSharp/Assembly-CSharp/Assembly-CSharp/SkillAttack.cs`, `SkillDataAttack.cs` |
| 技能创建归因 | `SkillBase.cs`, `SkillCreateData.cs`, `MissileShotData.cs` |
| 战斗单位技能槽 | `UnitCtrlBase.cs`, `UnitCtrlPlayer.cs` |
| 已学技能和经验写入 | `DataUnit.cs`, `UnitCtrlPlayer.cs`, `UnitActionRoleBattle.cs`, `BattleDataMgr.cs` |
| 命中/吸血事件数据 | `EBattleType.cs`, `EBattleTypeData/OneUnitUseSkillAttack.cs`, `OneUnitHitSkill.cs`, `UnitHitDynIntHandler.cs`, `UnitEffectSkillHpSuck.cs` |
| 灵力/念力字段 | `UnitDataBase.cs`, `WorldUnitDynData.cs`, `SkillDataAttack.cs` |
| UI/输入 | `DataGloble.cs`, `UnitPlayerInputCtrl.cs`, `UIPlayerInfoSkill.cs`, `UIPlayerInfoBase.cs`, `UITipItem.cs`, `UISkyTipEffect.cs` |
