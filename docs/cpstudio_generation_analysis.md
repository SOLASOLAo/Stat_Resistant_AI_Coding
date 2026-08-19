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
- 需要在用户关闭当前 PLE 后，用 `scripts/plc/export_plc_snapshot.py` 导出文本快照，才能补齐 PLC POU 层的精确变化。

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

## 样本 4：Wp100 下依次加入两个 BasMove Standard Unit

### 已验证的 OpCon Plus 层级与生成边界

CpStudio 是 OpCon Plus 的闭源低代码生成平台，公司用它生成标准化的自动化设备状态机框架。当前工程中已经直接观察到的层级是：`Station`（Mode Handler）包含 `Wp100`（Command Handler），`Wp100` 再包含标准设备 Unit。设备先以成熟 Unit 封装，自动 Chains 后续再按工艺顺序调用 Unit；这也是本项目采用“先设备、后 Chains”增量策略的原因。

用户分两次 CpStudio 导出，在 `Wp100` 下依次加入：

| 实例 | 类型/版本 | InstanceID | Base/B 端 | Work/A 端 |
|---|---|---:|---|---|
| `Wp100K101SafetyDoor` | BasMove Standard 2.1.11.0 | 4 | `_100B101B` 原位传感器；`_100K101B` 原位电磁阀 | `_100B101A` 工作位传感器；`_100K101A` 工作位电磁阀 |
| `Wp100K102PressingCylinder` | BasMove Standard 2.1.11.0 | 5 | `_100B102B` 上位传感器；`_100K102B` 上升电磁阀 | `_100B102A` 下位传感器；`_100K102A` 下降电磁阀 |

当前 BMK 规律得到两个样本的共同验证：末尾 `B` 表示 Base/原位，末尾 `A` 表示 Work/工作位；中间 `B` 表示传感器，中间 `K` 表示电磁阀。实际物理映射也已通过 PLE connector 接口逐条回读：安全门输入位于 A3 通道 6/7、输出位于 C2 通道 6/7；压缸输入位于 A4 通道 6/7、输出位于 C2 通道 4/5。

第二次导出前后的 PLC 文本快照从 218 个对象增加到 221 个对象，只新增压缸本体、Extension 和 `OnManRelease` 三个对象；没有删除对象。除这三个新增对象外，CpStudio 只更新了 `BinIo`、`StateOverview`、`EventListAddon.OnGetDesignator`、`Wp100.OnApplyParameters` 和 `Wp100.OnInitHierarchy`。这说明新增一个标准 BasMove Unit 的 PLC 生成边界已经可以稳定识别。

### 本次 MCP 集成逻辑

在第二次导出后的 221 对象快照上，AI 只修改了两个 ST 对象：

1. `Wp100K101SafetyDoorExtension.OnManRelease`：保持框架级 `CommonManRelease`，把两个附加条件由 `FALSE` 改为 `TRUE`；安全门手动去原位/工作位不再依赖其他设备或联锁信号。
2. `Wp100Unit.OnApplyOutputs`：把 `IsInHomePosition := TRUE` 改为 `IsInHomePosition := Wp100K101SafetyDoor.Unit.OutImm.IsInBasPos`，使 Wp100 Home 直接跟随安全门 Unit 已配置的原位状态。

压缸 `Wp100K102PressingCylinderExtension.OnManRelease` 仍保留生成值 `CommonManRelease AND FALSE`，所有自动 Chains 仍保持 pass-through，等待后续逐步放行。MCP 修改前后快照无新增、无删除，恰好只有上述两个对象哈希变化。最终离线编译为 **0 errors / 7 warnings**，PLC project SHA-256=`8DFB10EA386B7DC0733F67A1D5D636E739D5371DBD7CCD5D059A072379877286`。全程未连接、下载、启停或写入实体 PLC，也没有创建额外 `.project` 备份。两次 CpStudio 生成结果与两处 MCP 集成逻辑已一并提交并推送到 Station010 私有仓库：`972cfcb`（`feat: add Wp100 BasMove units and home integration`）。

## 样本 5：Burster Resistomat 2316 Unit + IP Peripheral

### 生成结构与依赖绑定

用户在 `Wp100` 下新增电阻仪 Unit。CpStudio 生成的实际实例名为 `Wp100K103ResistantDetector`，类型是 `BursterResis2316Unit`，Extension 继承 `BursterResis2316Extension`，InstanceID 为 6。`ObjectVersions.xml` 同时加入三个闭源标准对象：

- Burster 2316 Peripheral `1.0.3.0`；
- BursterResis2316Base `1.0.1.0`；
- Burster Resistomat 2316 Unit `1.0.4.0`。

Unit 与通信 Peripheral 的 PLC 绑定链如下：

```text
Wp100K103ResistantDetector.Unit
  .ParCfg.iBursterResis2316
       → _Wp100K103ResistantInterface : IpBurster2316
       → .ParCfg.Hostname := Station.StationData.BursterSetting.HostName
```

`_Wp100K103ResistantInterface` 被加入 `Peripherals` GVL 和 `PeripheralRoot`，并由 `PeripheralRoot.OnInitHierarchy` 注册。其 Hostname 在 `OpconApplyParReason.CONFIGURATION`（Station 每次进入 OPERATIONAL）时从 StationData 应用；`UseAutoRange` 当前固定为 `TRUE`。

Peripheral OOD 将它定义为 `NonBus`、接口 `IP`，继承 `NxSocketSysDep`，并把 Hostname 描述为“IP server 的地址”。这与“PLC 侧作为 socket/TCP 客户端，Burster 2316 作为 server”的工程模型一致。具体连接状态机、端口和报文协议封装在 compiled-library 中，当前源码层无法继续审计。值得注意的是，该 Peripheral OOD 对 ctrlX/CXA 的支持状态标记为 `NotTested`；离线编译通过只证明接口兼容，后续真机联调仍需单独验证。

### StationData 的准确语义

`StationDataStruct` 原先已经包含：

```st
BursterSetting : StationDataTcpIpGeneralSettingStruct;
```

其中 `HostName : STRING(128)`、`PortNo : DWORD`。本次真正新增的是 Peripheral 对 `BursterSetting.HostName` 的消费绑定，StationData 类型本身没有发生变化。当前生成的 HMI/DataSet 配置允许用户编辑该字段；`StationDataSetManager` 把文件数据加载/校验/应用到 `Station.StationDataNew` 与 `Station.StationData`，并配置了本地二进制文件 `StationData/StationDataSetManager.bin`。因此它在概念上确实是“硬盘数据进入 PLC 内存”，但实现上是 DataSetManager 的加载、反序列化与应用，不是操作系统意义上的逐字节 memory-mapped file。

当前 `Hmi/StationDataSetManagerL1.dat` 中 Burster HostName 默认值仍为空，真机通信前必须由用户配置有效地址。通用结构虽然还有 `PortNo`，但 `IpBurster2316` 当前生成参数只消费 Hostname 和 UseAutoRange，未消费 `BursterSetting.PortNo`；端口未通过该 StationData 路径开放。

### Unit 能力与本轮集成范围

本地技术手册确认该 Unit 提供两个命令：

| 命令 | 输入 | 输出 |
|---|---|---|
| `SET_RANGE` | `UpperRange`、`LowerRange` | 无命令结果 |
| `SINGLE_MEAS` | `UpperLimit`、`LowerLimit`、`ReadTemperature` | `OutOfLimit`、`ResistOk`、`Resistance`、`Temperature` |

新 Unit 的 HMI 同步新增 `Overview.sfc`，其手动功能 `SetRange` 和 `StartMeas` 仍保持 `CommonManRelease AND FALSE`，自动 Chains 也未调用电阻仪。

相对上一个 221 对象快照，本次 CpStudio 导出得到 224 个对象：只新增电阻仪本体、Extension、`OnManRelease` 三个对象；无删除；改变了 PeripheralRoot 四个对象、StateOverview、事件 Designator、Wp100 参数和层级初始化共八个已有对象，其他 213 个对象不变。首次离线编译即为 **0 errors / 7 warnings**。

按用户要求，AI 随后只补两条既定联锁：

1. 压缸 `MoveBasPos` 和 `MoveWrkPos` 均要求 `CommonManRelease AND Wp100K101SafetyDoor.Unit.OutImm.IsInWrkPos`，即安全门确认下降到位后压缸才允许手动动作；
2. `Wp100.IsInHomePosition` 要求安全门与压缸两个 Unit 的 `OutImm.IsInBasPos` 同时成立。

AI 修改前后 224 对象快照无新增、无删除，恰好只有上述两个 ST 对象变化；离线编译仍为 **0 errors / 7 warnings**。最终 PLC project SHA-256=`B1DF6EDE55E20FBCD472FF2A4309CFC903B3639B8C317F97DB3B31C42AD92E71`。全程未连接、下载、启停或写入实体 PLC，也未创建额外 `.project` 备份。生成结果与两处联锁已提交并推送到 Station010 私有仓库：`8014419`（`feat: add Burster resistance unit and motion interlocks`）。

## 样本 6：EmergencySwitch 绑定 + 项目专用主气压控制 FB

### CpStudio 生成边界

本批次 CpStudio 首先完成三路 AddOn 绑定：

| 用途 | AddOn 参数 | BinIo / 实际通道 |
|---|---|---|
| 急停 1 | `EmergencySwitch.ParStart.IdxIsEmSwitchPressed[1]` | `_000S900A` / A2 Channel 1 |
| 急停 2 | `EmergencySwitch.ParStart.IdxIsEmSwitchPressed[2]` | `_000S900B` / A2 Channel 2 |
| Control Off | `EmergencySwitch.ParStart.IdxIsControlOffButtonPressed` | `_000S902` / A1 Channel 2 |

两路急停均为 `IsEmSwitchInverted=FALSE`，符合 AddOn OOD 对标准 `S900` 常开/“按下为 TRUE”信号的定义；第二路 `DependsOnPreviousSignal=FALSE`，表示两个独立反馈，不是无独立反馈触点的串联诊断。Control Off 延时为 300 ms，只用于避免按下下电按钮时短暂误报急停。原 `_000S901` 已从 EmergencySwitch HMI 中移除，但仍正确绑定到 `ControlOn.ParStart.IsCtrlOnBtnPressedIndex`。

CpStudio 同时在 Station 增加两个事件常量和 HMI 文本：

```st
EVENT_PRESSURE_NOT_HIGHER : DINT := -4; // The pressure is not higher than 4.5bar
EVENT_PRESSURE_NOT_LOWER  : DINT := -5; // The pressure is not lower than 0.3bar
```

中文事件文本目前为空。该生成批次未改变三个压力 I/O 的物理映射：`_000B085A_LOW/HIGH` 位于 A1 Channel 6/7，`_000K085A` 位于 C1 Channel 8。首次离线编译即为 **0 errors / 7 warnings**，生成边界提交为 `77abe3c`。

### ControlOn 的正确集成接口

本地 `Std/Objects/NexeedControlOnAddon/V2.0/Documentation/NexeedControlOnAddon_TechnicalManual_EN.chm` 及同版本 OOD 明确区分：

- `_000S901`：用户按下 Control On 的原始按钮输入；
- `ControlOn.OutImm.IsCtrlOn`：来自 `_000K911_Y32` 的“电气控制已经上电”反馈；
- `ControlOn.ParImm.UserEnableControlOn`：应用侧允许条件，运行中变为 FALSE 时标准 AddOn 会撤销 Control On；
- `ControlOn.ParImm.UserControlOn`：仅用于按下过程中的附加上电条件，本批次不需要修改。

因此主气阀不能直接由 `_000S901` 驱动，也不应由自定义代码抢写 `_000K911`。本实现用 `OutImm.IsCtrlOn` 启动气路，并在压力故障时通过 `UserEnableControlOn` 请求标准 AddOn 下电。ControlOn 手册推荐的完全标准化方案是使用 MainValve AddOn；当前 ctrlX/Std 对象集中确认没有对应对象包，所以本项目使用独立 FB 实现同一集成边界。

### `FB_MainPressureControl` 行为

FB 位于 `Application/Fbs`，实例位于 `Station.MainPressureControl`，由 `StationUnit.OnCall` 每周期调用。FB 接口本身只有布尔量和时间，不引用 `Station`、`Peripherals` 或任何项目 BMK，因而可复制到其他项目；具体 ControlOn、I/O 和事件接线保留在调用处。监控只在 Station 为 OPERATIONAL 且 EtherCAT BusOk 时启用；其他状态主动关闭主气阀并禁止 Control On。

| 条件 | 结果 |
|---|---|
| Control On 反馈为 FALSE | `_000K085A=FALSE`，5 s 内等待“仅 LOW” |
| Control On 反馈为 TRUE，且当前“仅 LOW” | `_000K085A=TRUE`，开始 5 s 高压到位计时 |
| 阀为 TRUE，5 s 内变成“仅 HIGH” | 压力 Ready，保持阀输出 |
| 阀为 TRUE，5 s 后仍非“仅 HIGH” | 锁存 `EVENT_PRESSURE_NOT_HIGHER`，关闭阀并撤销 UserEnableControlOn |
| 阀为 FALSE，5 s 后仍非“仅 LOW” | 锁存 `EVENT_PRESSURE_NOT_LOWER`，保持阀关闭并撤销 UserEnableControlOn |
| LOW 与 HIGH 同时为 TRUE | 立即锁存两个事件并关闭阀 |
| Control On 已撤销且恢复“仅 LOW” | 复位故障、解锁并清除事件，等待下一次人工 Control On |

两个压力事件使用 `OpconEventClass.ERROR` 和锁定事件句柄，防止状态未恢复时被提前确认删除。当前 NxBase 编译接口要求两参数 `UnlockEvent(Class, Index)`，随后再调用 `ClearEvent(Class, Index)`；这与本地 CHM 中记录的较新三参数 `UnlockEvent(..., Clear)` 不一致，实际编译接口优先。

首次实现时离线编译为 **0 errors / 7 warnings**；文本快照从 224 增至 225 个对象，新增的 POU 最初名为 `FB_Stat010MainPressureControl`，AI 逻辑提交为 `123845d`。随后按跨项目复用要求，经 MCP 将其重命名为 `FB_MainPressureControl`：旧名引用为 0、新名引用为 2，225 对象对比仅有旧 FB 路径删除、新 FB 路径增加以及 Station 类型引用变化，行为代码不变；再次编译仍为 **0 errors / 7 warnings**。重命名后 project SHA-256=`FE8610EA5946FEA657788D9A6B143ADC96F55E89403A8DFAFAB8E99A317DBC68`，Station010 提交为 `4db6c8a`。本逻辑只是标准控制与诊断层，不能代替硬件安全继电器/安全 PLC；真机下载和 I/O 时序验证仍需用户批准。

### 减少 CpStudio 手工工作的可行边界

CpStudio 5.11 随附英文帮助明确提供两个官方能力：

1. `Engineering > Export` 可配置相对路径形式的 `Pre-export script` 与 `Post-export script`，脚本类型为批处理或 Python，每次导出前后自动执行；
2. 目标系统右键菜单提供 `Fast export (code only)`，仅重新导出 PLC 代码。

当前安装帮助和文本配置中没有发现受支持的无界面项目编辑/命令行导出接口。`DDP.CommandLineRegex.dll` 只是桌面框架组件，不能据此认定存在公开 CLI；`CpStudio_Export_Classes.chm` 描述的是导出模板可读取的数据接口，不是外部项目编辑 API。因此暂不采用 UI 自动点击或直接改写 `Engineering_Data.xml`，这两种方式都容易破坏闭源生成器的数据一致性。

推荐把工作边界固定为：CpStudio 仅负责模型层级、标准 Unit/AddOn/Peripheral、BMK 与 I/O 绑定、HMI/Event 和 StationData；项目专用联锁、状态机和设备算法由 AI 经 MCP 写入独立 FB 及 CpStudio 合并区外代码。Post-export 脚本可进一步自动触发 Git 差异检查、旧 Symbol 引用审计、PLC 编译和摘要输出，让人工动作缩减为“在 CpStudio 做必要声明式配置并点击导出”。当前 ctrlX 没有 MainValve AddOn，继续使用接口通用、项目接线外置的 `FB_MainPressureControl`。

## 样本 7：通用操作按钮 FB + SFC 取消复位

### 原始生成逻辑与缺口

`SqS_Wp100_Home._aN010_active` 原来直接写 I/O：按钮 `_000S610=TRUE` 时令 `_retVal=OK` 并熄灭 `_000P610`，否则令 `_000P610=FlashBits.Pulse500ms`。这个逻辑覆盖正常步骤跳转，但状态和输出散落在 Action 中；如果模式切换使 Chain 在该步骤被 CANCEL，活动 Action 不再运行，原 `OnChainFinish` 又没有熄灯代码。

### `FB_OperatorButton` 接口与生命周期

FB 位于 `Application/Fbs`，只包含通用接口：

| 接口 | 方向 | 含义 |
|---|---|---|
| `Execute` | 输入 | TRUE 开始/保持请求；FALSE 结束并初始化 |
| `ButtonPressed` | 输入 | 物理按钮状态 |
| `Blink500ms` | 输入 | 调用方提供的 500 ms 闪烁相位 |
| `Done` | 输出 | 检测到按钮后锁存，直到 `Execute=FALSE` |
| `LampOn` | 输出 | 等待时跟随闪烁相位，完成或复位时为 FALSE |

FB 不引用 `Station`、`BinIo`、SFC 基类或项目 BMK，因此其他项目只需更换调用处的按钮、灯和闪烁位。当前语义与原逻辑一致：步骤激活时按钮若已经为 TRUE，会立即完成；若工艺要求必须“先松开再重新按下”，后续应增加释放/上升沿资格判断。

### 首个 SFC 集成

`SqS_Wp100_Home` 在 CpStudio 合并区外增加 `_startButton : FB_OperatorButton`。Action 每周期以 `Execute=TRUE` 调用，接入 `_000S610` 与 `FlashBits.Pulse500ms`；`Done=TRUE` 时先设置 `_retVal=OK`，再用 `Execute=FALSE` 完成握手并初始化实例，随后将 `LampOn` 写入 `_000P610`。

`OnChainFinish` 在调用 `SUPER^.OnChainFinish(Reason)` 后无条件以 `Execute=FALSE` 调用实例并更新灯输出。因此不仅 CANCEL，ERROR、DONE 以及未来新增的其他结束原因也都会把 `_000P610` 置为 FALSE。静态引用检查确认 `_000P610` 的业务写入仅位于该 Action 和复位方法，没有其他 Chain 抢写。

离线编译结果为 **0 errors / 7 warnings**。快照从 225 增至 226 个对象：新增 `Application/Fbs/FB_OperatorButton`，无删除，只改变 Chain 声明、`_aN010_active` 和 `OnChainFinish`。project SHA-256=`C85EAED6C36559BE97CD6D6C89202700D53BCF7CD30BBEC20A076072F51828C5`，Station010 提交为 `1531e71`。SFC Action 与 `OnChainFinish` 可能被后续 CpStudio 导出覆盖，必须纳入 post-export 差异审计；不得直接脚本改写 `Engineering_Data.xml`。

## 样本 8：Wp100 Run SubChain 骨架 + Burster 手动放行

### CpStudio 生成的 SubChain 结构

新增对象 `SqS_Wp100_Run EXTENDS OpconSfcChain` 位于 `Wp100/_this/Chains/Sub`，全局实例为 `Wp100.SqS_Run`。CpStudio 同步完成四层接线：

1. `Wp100` 声明 `SqS_Run : SqS_Wp100_Run`；
2. `Wp100Unit.OnApplyParameters` 在 STARTUP 与 ONLINE_CHANGE 中执行 `Wp100.SqS_Run.rUnit REF= THIS^`；
3. `Wp100Unit.OnInitHierarchy` 以 `AddSubChain(Wp100.SqS_Run, 2)` 注册；
4. StateOverview 与 HMI ChainAnalysis 加入 ExecState/SFCCurrentStep。

PLC 快照从 226 增至 231 个对象，新增恰好 Chain、本体的 N000/N100/N999 三个 Action 和 `OnChainFinish`，删除为 0。此前两个通用 FB、按钮 Action 和取消复位代码全部保持哈希不变。CpStudio 基线编译为 **0 errors / 7 warnings**，生成提交为 `9d4f9b0`。

当前它还不是可工作的原子工艺：唯一输入是 `rUnit`，N100 直接 `_retVal := OK`，并且没有调用方设置 `Wp100.SqS_Run.Execute := TRUE`。要实现“同一原子操作以不同参数/条件重复复用”，推荐固定调用协议：

```st
// Start action: only write parameters while the SubChain is READY
IF Wp100.SqS_Run.ExecState = OpconExecState.READY
THEN
  // Wp100.SqS_Run.<InputParameter> := ...;
  Wp100.SqS_Run.Execute := TRUE;
  _retVal := OK;
END_IF

// Following action: wait for DONE/ERROR/CANCEL with the framework helper
_retVal := CheckSubChainDone(Wp100.SqS_Run);
```

工艺输入应在 READY→RUNNING 边界一次性写入，并在 N000 复制到内部快照，避免父 Chain 运行中改变参数；设备命令、按钮灯等资源必须在 `OnChainFinish` 对 DONE/ERROR/CANCEL 统一复位。同一个 SubChain 实例适合多个调用方顺序复用，不应被两个并发 Chain 同时启动；确需并行时应建立两个实例。

### Burster 手动功能

CpStudio 导出时，`Wp100K103ResistantDetectorExtension.OnManRelease` 的两个对象级条件仍为 FALSE。AI 经 MCP 改为：

```st
ReleaseSetRange := CommonManRelease AND TRUE;
ReleaseStartMeas := CommonManRelease AND TRUE;
```

保留 `CommonManRelease` 很重要：它继续执行 Mode Handler 的全局手动功能互斥，不允许绕过模式层直接运行。AI 前后 231 对象快照新增/删除为 0，唯一变化对象为 OnManRelease；最终编译 **0 errors / 7 warnings**，project SHA-256=`81199BDB36D5E65381190CD9C0973D65D1A2BB9CE36D68831F016618B5D50D9C`，Station010 提交为 `6a2121f`。

由于 HMI 配置是在该 MCP 修改之前由 CpStudio 生成，其条件分析树仍包含旧 Constant FALSE，虽然 `ReleaseSetRange/ReleaseStartMeas` OPC 变量本身已经存在。样本 9 的后续完整导出已验证该分析树不会从 PLE 反向同步；继续遵守不直接改写 `Engineering_Data.xml` 的边界。

## 样本 9：安全回路描述、停用参数与 StationData 公开字段

### 本次 CpStudio 模型变化

本次导出中的安全回路有效变化为：

| 变量 | 变化 |
|---|---|
| `_000K980_A` | 英文描述 `Safety door A closed` → `Maintenance door A closed` |
| `_000K981_B` | 英文描述 `Safety door B closed` → `Maintenance door B closed` |
| `_000K913_Y32` | 英文描述 `Loading door Ok` → `Safety door Ok` |
| `_000K912_Y32` | 英文描述 `All ready` → `All door ready` |
| `_000K980D` | 名称、英文和中文描述清空，即停用该参数 |

对应变化已一致传播到 BusConfig、EventRecorder、HMI 语言文件和 PLC `BinIo` 注释。工程文本中不再存在 `_000K980D`、`Safety door D closed` 或 `门锁D`。

同一批模型还从 StationData 公开结构中移除了 `LineNo`、`TestMode`、`NokCounter`，并移除了 `Wp100StationDataStruct.Active`。DataSetAccess、HMI 数据集及 PublicInterface 均已同步删除这些条目；PLC 的 `StationDataStruct`、`StationSdNokCounter` 和 `Wp100StationDataStruct` 暂时仍保留原字段。该差异不会造成编译错误，但说明 CpStudio 模型/HMI 的公开接口收缩并不必然删除已有 PLC 类型成员，因此后续必须先确认这些字段是否永久弃用，再决定是否经 MCP 清理 PLC 兼容残留。

### 快速审计结果

- 导出后 PLC 文本仍为 231 个对象，相对 `station010_after_subchain_burster_manual_release` 无新增、无删除，唯一变化对象为 `Application/Peripherals/BinIo`，且只改了上述注释；
- Burster `ReleaseSetRange/ReleaseStartMeas := CommonManRelease AND TRUE`、两个通用 FB、按钮 SFC Action/取消复位、主气压周期调用及 Wp100 Home 联锁均未被覆盖；
- Symbol Configuration 的 `BinIo` 为 62 个已选成员，实际权限全部 `ReadWrite`；`_000K980D` 为 0，四个仍使用成员各为 1；
- 完整离线编译为 **0 errors / 7 warnings**，没有旧 I/O Mapping 或失效 Symbol 警告，因此本次不需要调用 REST/MCP 修复；
- project SHA-256=`FCDF252C1D4E6B0D65EA3230B0A133418FF3B8EDF5A1E51827E199A5BD573067`，14 个有效生成文件提交为 Station010 `7c4422e`。

本次完整导出还验证了一个边界：CpStudio 没有从 PLE 回读 Burster OnManRelease 的 `AND TRUE`，HMI 条件分析树仍生成 `<Constant state="False">`。因此该 HMI 元数据不能靠下一次导出自动恢复，必须在 CpStudio 模型中设置对应对象级条件；继续禁止直接修改 `Engineering_Data.xml`。

## 样本 10：Wp100 Home 原子操作 + 维修门主气压联锁

### Home SubChain 的条件分支

用户定义的 Home 原子操作已落到 `SqS_Wp100_Home`。N010 先通过 `FB_OperatorButton` 等待 `_000S610`，并用 `_000P610` 显示 500 ms 闪烁；确认后按设备初态执行：

| 压缸 Base | 安全门 Base/Work | 实际动作 |
|---|---|---|
| TRUE | Base | 全部动作跳过 |
| TRUE | 非 Base | 安全门 BASPOS |
| FALSE | Work | 压缸 BASPOS → 安全门 BASPOS |
| FALSE | 非 Work | 安全门 WRKPOS → 压缸 BASPOS → 安全门 BASPOS |

N110/N130/N150 只在目标 Unit 为 READY 且 `StepPulse` 有效时发起标准 BasMove 命令；N120/N140/N160 只对本轮真正发起的命令调用 `CheckUnitDone(..., RepeatOnError := TRUE)`。三个 started 标志使“已在目标位而跳过”不会误进入等待。`OnChainFinish` 无条件撤销按钮 Execute、熄灭 `_000P610`、撤销两个 BasMove Unit 的 Execute 并清除标志，因此模式切换产生的 CANCEL 与 DONE/ERROR 使用同一清理路径。

### 维修门锁和主气压许可

CpStudio 本轮把 `_000K980/_000K981` 的英文描述细化为 A/B door lock；AI 没有在生成 XML 中写逻辑，而是经 PLC MCP 新增通用 `FB_MaintenanceDoorControl`。该 FB 不引用 Station 或具体 BMK，接口由 Control On 请求/确认、A/B 关闭反馈和 A/B 锁命令组成。

当前 Station 周期接线如下：

1. `_000S901` 按下时立即请求 `_000K980/_000K981=TRUE`；
2. `Station.ControlOn.OutImm.IsCtrlOn=TRUE` 后保持两路门锁输出；
3. 只有 `_000K980_A AND _000K981_B` 且两路锁命令均为 TRUE，`xMainPressureRelease` 才为 TRUE；
4. `FB_MainPressureControl` 仅在该许可成立后允许 `_000K085A` 上电，任一门反馈丢失会在同一扫描周期撤销许可；
5. 原 `BinIo._dummyFlagIsEveryDoorLockClosed := TRUE` 改为真实 `xAllDoorsClosed`，既有 Mode Handler 的 AUTO/MANUAL/HOME/CHANGEOVER 放行同步受两扇维修门约束。

这里没有擅自增加“门未关闭”超时报警，因为需求只定义了禁止主气压上电；后续真机验证门锁反馈时序后，再决定是否需要独立事件和延时。主气压原有 5 s HIGH/LOW 诊断与 `ControlOn.ParImm.UserEnableControlOn` 故障下电接口保持不变，只新增前级 `xValveRelease`。

### 审计边界

相对 `station010_cpstudio_param_rename_before_ai` 的 231 对象基线，最终快照为 232 个对象：新增恰好 `Application/Fbs/FB_MaintenanceDoorControl`，删除为 0；改变 13 个既有目标对象，未影响 N010、Burster 手动放行或其他 Chain。三个现场输出 `_000K980/_000K981/_000K085A` 的业务写入各只有 `StationUnit.OnCall` 一处（生成的 `BinIo.SetState` 通用接口除外）。完整离线编译为 **0 errors / 7 warnings**，project SHA-256=`EB76CF911AE933D33B3CFFF77024B61060198C78995BB954B237ADDD8D16A0E4`，Station010 提交为 `bb853e5`。

CpStudio 后续导出可能覆盖 SFC Action、`OnChainFinish`、Station 调用接线或 FB 接口，因此 post-export 审计至少应验证上述 14 个新增/改变对象、三个输出的唯一业务写入点和编译结果；仍不得直接编辑 `.project` 字节或生成 XML 来补 PLC 逻辑。

## 样本 11：维修门未锁事件 + 5 s 诊断

### CpStudio 生成边界

本次导出新增 `Station.EVENT_MAINTENANCE_DOOR_NOT_LOAKED : DINT := -2` 及 HMI/EventRecorder 文本 `The maintenance door should be locked!!`。`LOAKED` 虽然不是标准英文拼写，但它是 CpStudio 当前生成的正式 PLC 接口名，因此应用代码必须精确使用该名称，不能在 PLE 中私自重命名。2052 中文资源目前同样是英文，后续翻译应回到 CpStudio 修改。

相对样本 10，导出后 PLC 仍为 232 个对象，无新增/删除，只改变四个生成对象：

- `Station`：新增事件常量，且完整保留两个 AI-owned FB 实例；
- `BinIo`：同步 A/B door lock 注释；
- `StationDataStruct`：移除 `Wp100/LineNo/TestMode/NokCounter`；
- `StationDataSetManagerAddon.OnCheckData`：移除对应 NokCounter 检查。

同一批导出把 Burster `SetRange/StartMeas` 的对象级条件从 FALSE 正式改为 TRUE，HMI `config.xml` 的两个 ReleaseCondition 已同步，解决了此前 MCP 手动放行与 HMI 条件树不同步的问题。旧 `StationSdNokCounter` 和 `Wp100StationDataStruct` DUT 仍存在，但静态引用各只有自身声明，暂作为待确认的生成残留保留。

### AI 诊断逻辑

`FB_MaintenanceDoorControl` 新增可配置输入 `tLockMonitoringTime`（当前调用传 `T#5S`）、内部 TON 与 `xFaultDoorNotLocked`：

1. `_000K980/_000K981` 两路锁命令均为 TRUE 且 A/B 反馈未同时成立时启动计时；
2. 门反馈缺失会立即令 `xMainPressureRelease=FALSE`，因此 `_000K085A` 无需等待 5 s 就会关闭；
3. 条件持续 5 s 后锁存 `xFaultDoorNotLocked=TRUE`；
4. 即使门反馈随后恢复，锁存仍保持并继续禁止主气压；只有 Control Off 使两路锁命令都撤销后才复位；
5. `StationUnit.OnCall` 使用 `SetEvent(OpconEventClass.ERROR, Station.EVENT_MAINTENANCE_DOOR_NOT_LOAKED, '', Lock := TRUE)` 建立事件，并沿用主气压的 `UnlockEvent + ClearEvent` 清除流程。

这种分层使安全输出和报警时间彼此独立：门信号一丢就撤销气压许可，5 s 仅用于避免门锁机械动作期间产生误报警。当前没有让门锁故障直接写 `ControlOn.ParImm.UserEnableControlOn=FALSE`，避免报警瞬间撤销门锁输出而破坏恢复路径；事件和模式层仍会显示/处理 ERROR，实际电气时序留待真机验证。

### 验证结果

CpStudio 后、AI 前快照 SHA-256=`4F5522E919E3B8CA504D0981CB788E9D0F01CFC037DA6C947C476B456B5BD2CE`。AI 后对象数仍为 232，新增/删除均为 0，唯一改变的三个对象为 `FB_MaintenanceDoorControl`、`StationUnit` 和 `StationUnit.OnCall`；最终 SHA-256=`5E364DD99EDA0786055A3E11211D41F70C6DFE8026A977AD2C3E3A40EED816B0`。事件常量只有声明和调用各一次，完整离线编译为 **0 errors / 7 warnings**，Station010 提交为 `93379fd`。

## 样本 12：StationLamp AddOn + SFC Step Comment 接口化

### CpStudio 生成边界

CpStudio 在 Station 层新增 Station Lamp V2.3.1.0：PLC 实例为 `Station.StationLamp : StationLampUnit`，InstanceId 为 7，经 `AddAddOn` 纳入 Station 层级。硬件类型为 `MULTIPLE_LEDS`，黄色、绿色、红色依次使用 `_000P960_1/_000P960_2/_000P960_3`；标准 AddOn 自行根据 Mode、ControlOn、EmergencyStop 与错误状态生成灯态，应用侧本轮没有另写灯色状态机。

### 图形 SFC 属性的正式写入路径

SFC Step 的 Comment 不属于 Action ST，因此 `set_pou_code` 不是正确落点。此次使用 PLC Engineering 自带的本地 REST 扩展接口，对下列对象先 GET、再以完整对象 PUT：

```text
http://localhost:9002/plc/engineering/api/v2/devices/Device/Plc%20Logic/Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Home
```

在返回的 SFC XML 中，按 Step `name` 精确定位，并只替换 Comment 属性 `7d894980-aeea-405c-a0f6-e2b26429c58f` 的文本。写入前校验当前 implementation 哈希，写入后再次 GET 回读；把 9 个新 Comment 反向替换为旧值并统一 CRLF/LF 后，可逐字复现写入前 implementation。由此确认 Step 数 9、Transition 数 9、Jump 数 1，以及所有 Action 引用和图形顺序均未改变。

这类图形属性后续统一优先使用官方 REST/扩展接口，不手改 `.project` 二进制，也不依赖逐项 UI 自动化。界面只用于可视确认，F11 用于完整离线编译；本次结果为 **0 errors / 7 warnings**，Station010 提交 `6399377`。

## 样本 13：Kistler Peripheral 导入 + Burster BMK 改名失败闭环

本批 CpStudio 先从同目录 ctrlX IO 工程读取 `_100A104`，自动匹配标准对象 `Kistler MaXYmos BL5867B TL5877B0`；同时把既有 Burster Unit/Peripheral 的 BMK 语义从 `K103` 改成 `A103`。首次导出时，GVL 已生成 `_Wp100A103ResistantInterface`，但 `PeripheralRoot`、`OnInitHierarchy`、`OnApplyParameters` 仍引用旧 `_Wp100K103ResistantInterface`，因此代码生成、OPC UA method publish 和 PersistentVars instance path 刷新连续失败。

修复规则可以跨项目复用：

1. 新旧名字同时搜索声明、Hierarchy、周期调用、参数应用、HMI 和 Symbol Configuration，不能只看 GVL；
2. 把旧对象中 AI 验证过的 implementation 语义合并到新对象，本例为 Burster 两个 `CommonManRelease AND TRUE`；
3. 确认旧 POU 外部引用为 0 后再删除；
4. 对 REST 清单已不可见、但编译仍报警的 Symbol 幽灵项，先快照所有有效选择，执行 `UnSelectAll`，再用快照 `Select` 恢复；
5. 复测 `PublishMarkedMethodsJob` 与 `AddAllInstancePaths`，最后完整编译。

Kistler 另暴露了一个与代码生成无关的工具缺陷：IOE 2.6.4 对 200-byte input + 200-byte output 的设备生成 REST JSON 时，在大 `subChannels` 数组中插入 `stream is currently in use` Critical 对象，导致 CpStudio 的“写 I/O designator 到 PLC IDE”解析失败。正式替代路线为 IOE EtherCAT 离线导出、PLE `keepExisting` 导入，再经 MCP connector mapping 绑定 400 个父 BYTE；最终读回 400/400、零差异，编译 **0 errors / 7 warnings**。不得为规避该缺陷修改供应商 ESI 或直接编辑 `.project`。
