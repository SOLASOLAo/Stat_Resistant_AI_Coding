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

本地 `NexeedControlOnAddon` OOD/CHM 明确区分：

- `_000S901`：用户按下 Control On 的原始按钮输入；
- `ControlOn.OutImm.IsCtrlOn`：来自 `_000K911_Y32` 的“电气控制已经上电”反馈；
- `ControlOn.ParImm.UserEnableControlOn`：应用侧允许条件，运行中变为 FALSE 时标准 AddOn 会撤销 Control On；
- `ControlOn.ParImm.UserControlOn`：仅用于按下过程中的附加上电条件，本批次不需要修改。

因此主气阀不能直接由 `_000S901` 驱动，也不应由自定义代码抢写 `_000K911`。本实现用 `OutImm.IsCtrlOn` 启动气路，并在压力故障时通过 `UserEnableControlOn` 请求标准 AddOn 下电。ControlOn 手册推荐的完全标准化方案是使用 MainValve AddOn；当前 Std 对象集中没有对应对象包，所以本项目暂用独立 FB 实现同一集成边界。

### `FB_Stat010MainPressureControl` 行为

FB 位于 `Application/Fbs`，实例位于 `Station.MainPressureControl`，由 `StationUnit.OnCall` 每周期调用。监控只在 Station 为 OPERATIONAL 且 EtherCAT BusOk 时启用；其他状态主动关闭主气阀并禁止 Control On。

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

最终离线编译为 **0 errors / 7 warnings**；文本快照从 224 增至 225 个对象，仅新增 `FB_Stat010MainPressureControl`，并改变 EventList designator、Station、StationUnit、StationUnit.OnApplyParameters 与 OnCall。快照校验通过，project SHA-256=`A099CD4649D4BB9C4311627986FC33E0908B2742F6118BAF54CCB89E5CD8F90E`；AI 逻辑提交为 `123845d`。本逻辑只是标准控制与诊断层，不能代替硬件安全继电器/安全 PLC；真机下载和 I/O 时序验证仍需用户批准。

### 减少 CpStudio 手工工作的可行边界

CpStudio 5.11 随附英文帮助明确提供两个官方能力：

1. `Engineering > Export` 可配置相对路径形式的 `Pre-export script` 与 `Post-export script`，脚本类型为批处理或 Python，每次导出前后自动执行；
2. 目标系统右键菜单提供 `Fast export (code only)`，仅重新导出 PLC 代码。

当前安装帮助和文本配置中没有发现受支持的无界面项目编辑/命令行导出接口。`DDP.CommandLineRegex.dll` 只是桌面框架组件，不能据此认定存在公开 CLI；`CpStudio_Export_Classes.chm` 描述的是导出模板可读取的数据接口，不是外部项目编辑 API。因此暂不采用 UI 自动点击或直接改写 `Engineering_Data.xml`，这两种方式都容易破坏闭源生成器的数据一致性。

推荐把工作边界固定为：CpStudio 仅负责模型层级、标准 Unit/AddOn/Peripheral、BMK 与 I/O 绑定、HMI/Event 和 StationData；项目专用联锁、状态机和设备算法由 AI 经 MCP 写入独立 FB 及 CpStudio 合并区外代码。Post-export 脚本可进一步自动触发 Git 差异检查、旧 Symbol 引用审计、PLC 编译和摘要输出，让人工动作缩减为“在 CpStudio 做必要声明式配置并点击导出”。如果后续取得标准 MainValve AddOn 对象包，应优先用标准对象替代本项目专用主气压 FB 的框架部分。
