# PLC 力采样、3σ 判稳与 HMI 曲线

**布局补丁 0.2.1.1 已在本地注册，待现场确认**：[HAD](../data/components/native/forcetrace-hmi-0.2.1.1/ForceTrace.Hmi.had) · [中文预览](../data/components/native/forcetrace-hmi-0.2.1.1/preview-2052.png)。底部说明上移 65 px，内容适配 944×572；中英文文字完整性和原生加载通过。2026-09-17 只读核对确认本地 DLL、AddonDesc 及生成 HMI 引用均为 0.2.1.1，实际页面仍绑定 Station.ForceTrace 四数组。用户确认现场 HMI 与 DLL 更新及显示效果。本补丁仅改布局，配合现有 PLC/对象 0.2.1.0，不需再次下载 PLC。

2026-09-17 本地注册版本：**ForceTrace.Hmi 0.2.1.1**，配合 **0.2.1.0** 原生 ForceTrace PLC 库与 CpStudio 对象。PLC 负责记录、统计和启动电阻仪的条件；HMI 显示 PLC 已保存的记录，并按操作者选择保存 CSV。用户此前现场截图已显示曲线与分布；AI 未执行现场部署，当前现场版本及完整实体验收待确认。

**0.2.1.0 新增可配置采样周期和中英文判稳说明，需要配套更新 PLC 与 HMI（含扩展 DLL）**。分布无数据提示改为“尚无可用的统计窗口数据”，与左侧力曲线是否存在分开判断。保留 0.2.0.1 防闪烁行为：拒绝的传输帧保留最后有效快照，已完成记录的重复发布不再重画；真正质量异常、心跳超时、新循环和有效空记录仍清除。v2 四数组协议和原始测量判定不变。见[本次升级说明](reviews/forcetrace-sampling-20260916.md)。

## 使用与参数

在 StationData 中配置以下四项。每个夹具位置开始前锁存一次，中途修改从下一位置生效；界面显示的是该次记录实际采用的值。

| StationData 成员 | 中文名称/单位 | 初始设置及要求 |
| --- | --- | --- |
| PressForceThreshold | 压力判定门槛，N | 2500；实际力必须严格大于此值 |
| PressForce3SigmaLimit | 压力3σ标准值，N | 本站保存初值 5 N；0 表示未配置，禁止放行；现场值由工艺确认 |
| PressForceStableTime | 压力统计窗口，ms | 1000；范围 1–60000；已从原连续保持时间改为统计窗口 |
| PressForceTimeout | 压力等待总超时，ms | 保留现有参数；必须大于统计窗口 |

生成模型的初始值不等于 IPC 已保存的活动 StationData。更新现场后应确认活动值，特别是旧参数可能仍为 2000 ms。不要将导出 DAT 的占位值当作现场设置，或覆盖用户现有数据文件。

采样周期在 **CpStudio → Station → Parameters → ForceTrace → SamplePeriodMs** 配置，DINT/ms，默认 6，允许 1–1000。导出后赋给 `Station.ForceTraceAddon.ParCfg.SamplePeriodMs`，每位置与工艺参数一起锁存，并随该位置曲线/统计帧传给 HMI。该值必须等于实际调用任务的名义周期；它不会改变 MainTask 扫描周期。当前本地 MainTask 为 6 ms。统计窗口还需满足 `WindowMs <= min(60000, 10000 × SamplePeriodMs)`。

下压到位且数据健康后，只有力持续高于门槛、窗口已装满、当前 3σ 严格小于 PressForce3SigmaLimit，PLC 才启动电阻仪。门槛相等会清空窗口；3σ 等于标准值不会放行。掉力清空窗口，但不会重启等待总超时。

这里 **3σ = 3 × 窗口内样本标准差**，单位为 N。计算采用 n−1 分母和 LREAL 累加。它描述窗口内压力的波动大小；它不是压力门槛，也不是平均力。统计窗口要求完整时间跨度，例如 6 ms 名义采样下，1000 ms 窗口首次满足约需 1002 ms、168 点；绝非第一个样本的 σ=0 就启动。

界面下方中英文说明显示同一记录的实际参数及公式 `3σ = 3 × sqrt(Σ(Fi−F̄)²/(n−1))`，并说明完整窗口、严格边界、窗口重置及测量结束冻结。没有可用记录参数时显示“—”；不会用当前可编辑参数伪装历史记录的实际参数。HMI 的直方图/正态 PDF 绘制不控制 PLC 判稳。

电阻测量期间继续检查力、3σ、到位及数据质量。首个故障保持，结果无效，结束/取消仪表且不自动抬缸；故障优先于同一扫描的 DONE。电阻 Ω 上下限判定、边界包含关系和原有安全联锁保持。电阻正常 DONE 后冻结分布，卸压过程继续显示在完整力曲线上，但不污染测量统计。

## 采样和保留范围

- 采样来自 Wp100A104Kistler.Unit.OutImm.ForceAct，当前 MainTask 名义 **6 ms**，SamplePeriodMs 与之匹配，每扫描最多一次。时轴使用 PLC 实际经过的毫秒数；HMI 约 **100 ms** 更新一次。
- Kistler START 已确认、下压动作之前记录 t=0；结束点为该位置 Kistler 正常结束、取消或首错。
- PLC 分别保留夹具左、中、右三个位置，每处前 60 s、最多 10001 点。达到容量后标记截断，统计和测量联锁仍继续运行。
- 下一父级自动循环开始时清空旧循环。缓冲在 PLC RAM 中，PLC 重启不保留；长期追溯需显式保存 CSV。
- 曲线页晚开或重新连接时读取 PLC 已保留的数组，不依赖 HMI 页面提前打开。过去由 v1 漏采的数据不能补回。
- 超过 `ceil(2.5 × SamplePeriodMs)` 的采样间隔记为异常（6 ms 配置对应 15 ms）；HMI 统计心跳超过 500 ms 则清除实时显示并提示。编译和合成检查不能证明现场任务抖动、仪表更新周期或通讯带宽，需现场验收。

曲线和 CSV 按**夹具位置**命名。主界面电阻三行按**工件右、中、左**命名，原数值/Valid/OK 绑定没有交换。

## 四个原生绑定

CpStudio → Station → Add-ons → ForceTrace 中选择力值、质量、测量状态和四个 StationData 参数。页面 ForceTraceForceTrace 随 HMI Export 自动生成，四个 Item 使用数据实例的 HmiFullName，无需逐个手工绑定；均为**整个数组**。

| 控件属性 | 实际生成 Item | PLC 类型 |
| --- | --- | --- |
| LeftTraceItem | Ch1.L1.Station.ForceTrace.LeftFrame | ARRAY[0..30035] OF DWORD |
| MiddleTraceItem | Ch1.L1.Station.ForceTrace.MiddleFrame | ARRAY[0..30035] OF DWORD |
| RightTraceItem | Ch1.L1.Station.ForceTrace.RightFrame | ARRAY[0..30035] OF DWORD |
| StatisticsItem | Ch1.L1.Station.ForceTrace.StatisticsFrame | ARRAY[0..209] OF DWORD |

四项由 CpStudio 模型创建、导出到 VWN，PLE Symbol 的 Station.ForceTrace 父节点为 Read；类型成员保留原选项。扩展通过现有 Ch1.L1 的原生 Item 订阅，运行时只订阅所选位置的大数组及共享统计数组，不增加另一套 OPC UA 客户端、地址或登录配置。

门槛、3σ 标准、窗口、超时从 StationData 在 PLC 中锁存，再随这四个数组传到 HMI。因此扩展无需单独绑定四个可写参数，也不会在用户中途改参数时显示与该次判定不一致的设置。旧 HMIForceFrame 仅作为遗留模型成员保留，本版不使用。

## 界面与保存

左侧为力—时间曲线；右侧为**同一 PLC 统计窗口**的实际密度直方图，共 20 桶，叠加橙色正态概率密度参考线。纵轴为 1/N，柱面积归一化。正态曲线只是参考，PLC 判稳不要求样本服从正态分布。σ=0 时显示集中标记，不计算除零的 PDF。

界面显示均值、3σ、样本数、实际采用的参数，以及填充、稳定、冻结、历史窗口或无效状态。窗口因掉力/异常重置时保留最后有效分布并标记“历史”，不会把它冒充实时稳定值。测量结束后分布冻结，切换位置可查看各位置自己的记录。

判稳标记直接采用 PLC 的 LREAL 计算结果；HMI 接收的 REAL 及显示小数位可能把略低于标准的 3σ 舍入成相等，因此 HMI 不用显示值再次判稳，也不因此丢弃有效数据。

“保存当前位置”提供两种范围：

| 选择 | 内容 |
| --- | --- |
| 从记录开始的全部曲线 | 当前位置已保留的全部样本 |
| 3σ稳定后的曲线 | 从 PLC 首次判稳点开始，含该点，到已保留终点；之后掉力或故障的样本仍保留 |

不存在判稳点、或判稳发生在已截断数据以外时，不创建文件，并提示“当前位置没有可保存的3σ稳定后曲线，未生成文件。”运行中可以保存，文件标记 Running，采用点击时的不可变快照。

默认目录为 C:\OpconData\ForceTraces，由 SaveDirectory 属性设置。异步保存、唯一文件名、原子发布，不覆盖旧文件；1000 文件或 512 MiB 达到限额时提示，不自动删除。CSV 为 UTF-8，数字小数点不随系统语言变化。

CSV schema 2 保存：循环、采集编号、夹具位置、所选范围、样本序号、PLC elapsed_ms、力值、质量、结束原因、截断状态、四个锁存参数、名义采样间隔、首次判稳序号/时间及快照终点。snapshot_received_at_utc 是 HMI 接收快照的时间，**不是每个样本的 UTC 时间**。质量 0=无效、1=正常、2=采样间隔异常；不伪造零力样本。

## 导出、安装与版本边界

本地 Std 自有扩展已通过 CpStudio 原生 HMI add-ons 注册为 0.2.1.0，原厂 DLL 未改。实际模型已保存、关闭重开；实际导出页面通过原厂加载器及四个原生数组选择器检查。46 项中英文文字已通过 HMI 单独 Export 生成，页面高度为 680，说明区域在导出页面内。

v2 不再需要 BppForceTraceStartup 或 ForceTraceStartup.sfc。本地旧启动项已移除；post_export_signal.bat 恢复为仅发布请求。旧 Restore-ForceTraceStartup.ps1 遇到 v2 直接返回 NOT_REQUIRED_PLC_BUFFERED，不写文件。旧 startup 源码/测试及组件 rc.4 仅用于旧版恢复，不作为 v2 入口。

完整 PLC Export 的原厂 Symbol REST 流缺陷仍存在。本次使用 Fast export + HMI 单独 Export，并通过 PLE 原生 Symbol Configuration 的 Update 将 ForceTraceData 类型引用升级为 0.2.1.0。全部已配置 Symbol 选择与修改前一致，仅库版本改变；Station.ForceTrace 父节点 Read 保留。保存重开后重新 Generate code 为 0 errors / 5 原有 warnings。后续模型导出后核对数据父节点、四个数组和九个电阻成员，不盲目重试完整 Export。

升级到 **0.2.1.0 需要配套更新本次 PLE、HMI 导出和扩展 DLL**。此前 0.2.0.1 仅更新 HMI 的说明只适用于旧闪烁补丁。AI 未执行现场下载、启停或 IPC 部署；保留现场活动 StationData/TypeData，按 TODO 继续验收任务周期、CPU/watchdog 裕量、实际数组传输、晚开页面、两轮循环和保存权限。

## 协议维护说明

协议均使用 DWORD 数组，REAL 按原始位表示。Trace 固定 30036 字：头 0–31；有效点从 32 开始，每点三字 elapsed_ms / force_bits / quality；末字 30035 重复序号。头包含版本 2、启动/循环/采集/位置身份、状态、点数、截断、首次判稳标记、四个参数和采样周期。未用尾部不参与有效点数，不当成样本。

Trace 校验先对有效点数据、再对头 0–30 计算 FNV，保存于 31。Statistics 共 210 字：头 0–15，三位置各 64 字（16/80/144 起），208 为 0–207 的 FNV，209 为重复序号。每个位置包含统计量、参数、时间、判稳标记、20 桶及状态位。状态位为 Healthy=1、Full=2、Stable=4、Frozen=8、Historical=16。FNV 初值 2166136261，每字异或后乘 16777619，按 32 位溢出。

解析器校验版本、长度、身份、序号/重复序号、校验和、时间单调及质量；拒绝旧循环、撕裂帧和无效值。权威字段定义见 [PLC recorder](../src/plc/libraries/ForceTrace/FB_HmiForceTrace.st) 与 [HMI decoder](../src/hmi/ForceTrace.Hmi/ForceTraceFrames.cs)。

## 本地验证与恢复点

- 新 F11：**0 errors / 5 warnings**，为原有 4×C0351 OPC.UA.DA 属性及 1×C0373 ErrorCodes DWORD 枚举。
- CpStudio HMI Export：**0 errors / 原有 2 条 Burster 兼容性 warnings**。
- 统计离线模型：847 个数值对照与边界断言；HMI 帧与 CSV：685 项检查，含 1/6/10 ms 参数。这是合成检查，不是实体 PLC 实测。
- 安装 DLL + 本站导出 SFC：2001 点实际 Mod_Chart 坐标逐点匹配、50 组刷新、两种 CSV 一致、4 个原生 Item 编辑器、SFCLoader 0 errors。新增中英文动态说明、无统计窗口仍保留力曲线、页面内布局检查通过。见[收据](../data/reports/hmi/forcetrace-sampling-20260916/installed-native/native-check.json)、[中文预览](../data/reports/hmi/forcetrace-sampling-20260916/installed-native/preview-2052.png)。
- 本次原有 StationData/TypeData 参数、权限及 Burster Hostname 引用保留；IO 工程、导出 DAT、主界面和原厂 DLL 受保护。备份、差异和本地安装检查见[升级说明](reviews/forcetrace-sampling-20260916.md)。
- 用户要求的改动前备份已推送至私有 SOLASOLAo/Stat_Resistant_Station010：tag baseline-before-force-3sigma-20260915，commit b93d44a8a57ac33a9d73c2af9496f9e0280dc34a。原工作分支未切换。备份含当时保存的工程及自有 McpCoding/.2 扩展快照；恢复读取已验证。见[备份收据](../data/checkpoints/force-3sigma-baseline-20260915/receipt.json)。

本版实现保存在本地，未额外推送；冻结组件候选 rc.4 保留原样，当前原生组件候选与本站选择见 [接入记录](components/STATION010-NATIVE-20260916.md)，未发布正式版本。
