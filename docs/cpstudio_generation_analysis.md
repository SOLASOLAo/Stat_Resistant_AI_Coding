# CpStudio 生成差异分析

> 目标：通过“单一 CpStudio 改动 → Git diff → PLC 文本快照 → 编译”逐步建立模型到生成代码的映射。本文件记录事实和推断；未得到用户确认前，不提交或回滚参考工程的生成变化。

## 样本 1：`b9b1161` → 2026-08-18 未提交工作区

### 观察到的生成边界

- 基线提交：`b9b1161`（当前 IDE/CpStudio 状态快照）。
- 当前工作区：26 个文件变化，约 136,895 行增加、186,666 行删除。
- PLE 由外部进程以 `--project=...Stat010_V5.11_CtrlX_PLC.project` 启动，并持有 `.~u` 锁；分析期间未通过 MCP 打开、保存或编译该工程。

### 模型层变化

`Wp100` 层级仍存在，但其五个子 Unit 从 PublicInterface 中移除：

| Unit | 类型/作用 | 可见的连带变化 |
|---|---|---|
| `Wp100K202SafetyDoor` | BasMove / 安全门 | HMI SmartForms 删除，HomePosition 条件移除 |
| `Wp100K201PressCyl` | BasMove / 下压缸 | HMI SmartForms 删除，手动功能与条件移除 |
| `Wp100A830Scanner` | Scanner / 手持扫码枪 | Scanner 对象版本、类型、事件和 HMI 删除 |
| `Wp100A740ForceStroke` | Kistler Maxymos | Kistler 对象版本、类型、事件和 HMI 删除 |
| `Wp100A850BursterResistomat` | Burster 2316 | Burster 对象版本、类型、事件和 HMI 删除 |

`ObjectVersions.xml` 和 HMI `config.xml` 同步移除了以下对象族：

- BasMove Base / BasMove Standard；
- Kistler Maxymos Force Stroke / Base；
- Scanner / Scanner Base；
- Burster Resistomat 2316 / Base。

这说明 CpStudio 在生成时会根据当前实际实例集合裁剪对象版本、类型定义、事件文本、HMI Unit 配置和 SmartForms，而不是始终保留所有曾经使用过的对象依赖。

### PLC 与同步元数据

- PLC `.project`：1,738,192 B → 1,597,120 B；Git 只能确认二进制发生变化，无法判断具体 POU/ST 差异。
- `Stat010_V5.11_CtrlX_PLC.Sync.json` 的 `LastChange` 更新，`MachineName` 保持 `SZHM-C-002YK`。
- PublicInterface 的导出时间更新为 `2026-08-18T03:15:51`。
- 需要在用户关闭当前 PLE 后，用 `scripts/export_plc_snapshot.py` 导出文本快照，才能补齐 PLC POU 层的精确变化。

### 用户确认与实验定位

用户已确认：删除 `Wp100` 下全部五个 Unit 是有意操作，目标是先得到最干净的 OpCon/CpStudio 框架，再逐个添加设备，最后逐步添加自动 Chains。当前工作区应作为“最小骨架候选基线”，不是误删现场。

建议把后续生成实验严格拆成以下提交序列：

1. 最小骨架：无 Wp100 子设备，导出 PLC 文本快照并编译；
2. 每次只新增一个设备/Unit，生成、导出、diff、编译、提交；
3. 为该设备补 Handler、参数、HMI 和手动功能，仍按单一概念拆分提交；
4. 全部设备和手动功能稳定后，再逐条加入 Homing/Changeover/Auto Chains；
5. 每一步都记录模型 XML、PublicInterface/HMI、PLC ST 和编译基线的对应变化。

当前 PLE 仍持有工程锁。在用户完成目视检查并正常关闭 PLE 前：

- 不提交或回滚 `../Station010_0708` 工作区；
- 不启动第二个 PLE/MCP 实例；
- 不对 `.project` 做任何写操作。

### 最小骨架 PLC 文本与编译基线

用户关闭 PLE 并重启 Codex MCP 扩展后，已在单一 persistent 会话中完成两次只读导出和一次离线编译：

- MCP：persistent，PLE PID 24368；没有连接设备、下载或在线写变量；
- 文本快照：215 个有文本对象，输出到被忽略的 `data/plc_snapshots/station010`；
- 快照校验：manifest、215 个对象文件和源 project SHA-256 全部通过；当前文本树 SHA-256=`4e556b44bb2212c91d7c86d260a87b325b7dfeba8fe0f2b9622089a1dab63241`；
- 源 project SHA-256=`24A34D3B7A2B6E6E7E9AE57BE9794221716E75BA580A9E5ED20B3F19C9B4EB5C`，编译后仍与预操作备份一致；
- 编译基线：66 errors / 40 warnings。

66 个错误可归为两类：

1. 3 个非 ST 错误：`bus_000S900`、`bus_000SK010A1_Channel_6`、`bus_000SK010A1_Channel_7`。当时因文本快照中没有这三个精确标识符而暂归为 SymbolConfig 残留；后续实时 ScriptEngine 审计证明实际来源是 A1 的旧 I/O 通道映射，见下节；
2. 63 个错误来自删除 Unit 后仍保留的旧 ST 步骤，集中在 10 个对象：
   - `Application/Station/Wp100/_this/Wp100Unit/OnApplyOutputs`；
   - `SqC_Wp100_Run` 的 `_aN050_active`、`_aN055_active`、`_aN060_active`；
   - `SqS_Wp100_Home` 的 `_aN110_active`、`_aN120_active`、`_aN130_active`、`_aN140_active`、`_aN150_active`、`_aN160_active`。

最小清理方案是把空 Wp100 的 `IsInHomePosition` 设为安全的框架默认值，并把上述 9 个旧设备步骤中和为 `_retVal := OK;`。方案形成时 `../Station010_0708` 仍被定义为只读参考，因此先等待用户作所有权决策；后续授权与执行结果见下节。

### 用户授权后的 ST 清理结果

用户已把 `../Station010_0708` 正式授权为 CpStudio + MCP 受控集成工作工程。AI 经 persistent MCP 完成上述 10 个对象的最小清理：

- `Wp100Unit.OnApplyOutputs`：空 Wp100 的 `IsInHomePosition := TRUE`，保留既有 `IsEmpty` 传感器逻辑；
- 9 个旧设备步骤：改为带说明的 `_retVal := OK;` pass-through，等待后续逐设备重建 Chains；
- 清理前后文本 manifest 对比恰好只有这 10 个对象哈希变化；更新后快照仍为 215 个对象并通过校验；
- project SHA-256 更新为 `619B8B8FBB748AC141FCC5510CE1227D4EE208B7B02434BCF55F688A8FEE8AE7`；
- 编译由 66 errors / 40 warnings 降到 **3 errors / 40 warnings**。此时剩余 3 errors 尚待对 Symbol Configuration 与 I/O 映射分别审计；最终定性与修复见下节。

### 最小骨架 0-error 收口：三条 A1 I/O 映射

用户在 PLE 的 Symbol Configuration 中移除了 25 个已失效签名后，3 个 `BinIo` 错误仍然存在。实时 ScriptEngine 审计得到以下事实：

- Symbol Configuration 对象在脚本树中的内部名称为 `Symbols`；`get_only_configured_signatures()` 返回的 `BinIo` 已不包含三个报错名称，说明符号清理已经生效；
- `BinIo` 声明包含 56 个 `bus_*` 变量，EtherCAT 树也有 56 条映射，但修复前两边集合各有三个差异；
- 三条错误全部位于 `Device/Realtime_Data/ethercat_master_instances_000SA620_X1/_000SK010/_000SK010A1`。

离线修正如下：

| 通道 | 原映射 | 修正后映射 |
|---|---|---|
| `%IX0.2` / `Channel_3.Input` | `bus_000S900` | `bus_000SK010A1_Channel_3` |
| `%IX0.5` / `Channel_6.Input` | `bus_000SK010A1_Channel_6` | `bus_000B085A_LOW` |
| `%IX0.6` / `Channel_7.Input` | `bus_000SK010A1_Channel_7` | `bus_000B085A_HIGH` |

修正后声明集合与映射集合完全一致，离线编译为 **0 errors / 7 warnings**。215 个 PLC 文本对象再次通过 manifest 校验；与 ST 清理前快照相比仍恰好只有既定的 10 个对象变化，说明 I/O 映射修正没有扩散到其他 ST。最终 project SHA-256=`132213CF6B566C255885F036800CD85B5893846704D23DE3ED2555DC8291B9F8`。全过程未连接、下载或启停实体 PLC。

该最小骨架已提交并推送到 Station010 私有仓库：`987d8fb`（`refactor: establish minimal CpStudio skeleton baseline`）。当前不应再次用 CpStudio 全量生成；否则可能覆盖已经完成的 10 处 ST 最小清理。下一次生成应从“每次只增加一个设备”的受控实验开始。

## 样本 2：七个 I/O 模块的 BMK 与描述改名

### 生成范围与首轮故障

用户在 CpStudio 中修改 A1-A4 四个 EL1018（DI）和 C1-C3 三个 EL2008（DO）模块的变量 BMK/描述后重新导出。相对最小骨架提交 `987d8fb`，Station010 有 15 个文件变化，覆盖 Engineering 模型、EventRecorder、HMI、PublicConfig、PLC/IO project 与同步元数据。既有 10 处最小骨架 ST 清理没有被覆盖。

CpStudio 已生成新的 `BinIo` 声明，但没有同步清理 PLC 工程内的 EtherCAT I/O Mapping，导致首次离线编译为 **33 errors / 73 warnings**。修复动作严格限定在映射层：

- 把 16 个仍启用的物理通道重映射到新 `bus_*` 名；
- 清空 17 个已停用通道的旧映射；
- 最终保留 39 条有效映射，变量集合唯一且无重复。

映射修复后编译为 **0 errors / 40 warnings**，说明 33 个编译错误全部来自旧 I/O Mapping，而不是 ST 代码。

### Symbol Configuration 的两层接口结论

映射修复后的 33 条新增警告来自 `BinIo` 内失效的旧公开成员。PLE ScriptEngine 的上层 `get_all_datatypes()` 在本工程会抛出 `An item with the same key has already been added`；底层 `ISymbolConfigObject.GetAvailableDatatypeSignatures(False)` 则能正常返回 599 个数据类型并唯一找到 `BinIo`。因此 duplicate-key 是脚本包装插件缺陷，不是 Symbol Configuration 数据损坏。

最终采用 ctrlX PLC Engineering 2.6.8 自带的正式本地 REST API，而不是跨进程 UI 自动化或私有反射写入：

```text
GET http://localhost:9002/plc/engineering/api/v2/devices/Device/Plc%20Logic/Application/symbol-config
PUT http://localhost:9002/plc/engineering/api/v2/devices/Device/Plc%20Logic/Application/symbol-config?symbolsAction=Select
```

REST `GET` 中已选变量的 `accessRights` 仍显示 `Void`，这是可用编译符号视图的字段语义；底层已保存的 `SelectedTypes` 才是权限事实源。本次底层复核结果为：

- `BinIo` 已选成员：63；
- 18 个当前新 BMK：全部存在；
- 33 个失效旧名：0；
- 63 个成员的实际保存权限：全部 `ReadWrite`。

保存后完整离线编译为 **0 errors / 7 warnings**，回到最小骨架基线。全过程没有连接、下载、启停或写入实体 PLC；按照用户要求，本批次没有再创建额外 `.project` 备份。当前 PLC project SHA-256=`F53548B8C8A12571615DA0C5B7DDC46B3257D0FADC972F016E9843168E6CACBB`。该批次 15 个生成/工程文件已提交并推送到 Station010 私有仓库：`78f91e8`（`fix: sync I/O BMK mappings after CpStudio export`）。

## 样本 3：C1 门锁描述与停用通道的小改动

### Git 差异与故障签名

用户再次从 CpStudio 导出后，相对 `78f91e8` 有 14 个文件变化，但有效模型差异只有三项：

- `_000K980` 中文描述由“安全门上锁”改为 `100K980 door lock`；
- `_000K981` 事件描述中的设备号由 `100K980` 纠正为 `100K981`；
- 生成的 `BinIo` 与事件配置不再包含停用占位成员 `_000SK010C1_Channel_6`。

首次离线编译为 **1 error / 9 warnings**。唯一错误是 C1 `Channel_6.Output` 的旧 I/O Mapping 仍引用 `Application.Peripherals.BinIo.bus_000SK010C1_Channel_6`；额外警告则来自 Symbol Configuration 中同名的失效公开成员。因此样本 2 的“双层残留”不是一次性偶发现象。

### 可复用的快速修复顺序

1. 先做 Git diff，确认 CpStudio 当前声明的新增、改名与删除集合；
2. 用扩展后的正式 `map_io_channel` 工具按 `Channel_6.Output` 定位 connector parameter，清空旧绑定并强制回读；编译变为 **0 errors / 8 warnings**；
3. 调用 `PUT http://localhost:9002/plc/engineering/api/v2/devices/Device/Plc%20Logic/Application/symbol-config?symbolsAction=UnSelect`，以 `BinIo + _000SK010C1_Channel_6` 的最小请求删除旧公开成员；
4. 保存、审计并重新编译，最终为 **0 errors / 7 warnings** 基线；`BinIo` 有 62 个已选成员且权限均为 `ReadWrite`。

ctrlX/DataLayer 的实际通道位于 `device.connectors → connector.host_parameters → parameter.io_mapping`，不是 `device.get_children(False)`。该支持已并入 `ctrlx-ai-coding` 的兼容补丁脚本并推送为 `142721c`。本批次未操作实体 PLC、未创建额外二进制备份；最终 project SHA-256=`E89D8C0732990B572B2B52305D0215F4099AEA550A5779D6D5444B6EE5BD860C`，Station010 提交为 `482c77a`。
