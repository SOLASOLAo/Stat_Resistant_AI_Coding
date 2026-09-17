# ForceTrace 0.2.1.0

PLC 采集/滚动统计/v2 数据帧 + NxAddonBase 对象，配套 HMI 0.2.1.0。新增可配置的 PLC 采样周期及界面下方中英文采样、计算和判稳说明；保留 0.2.0.1 的防闪烁修复。HMI 只消费 PLC 缓冲，不要求先打开页面。自有对象安装到 PrjExt/Objects/ForceTrace/V0.2；Company 为 Internal Engineering。

CpStudio 目录显示名为 **Force Trace**，使用曲线图标。库、对象与 HMI add-on 均使用通用名称；已在 CpStudio V5.11 / ctrlX PLC 2.6.8 完成新编译和实际 Station010 接入。

## CpStudio 绑定

对象实例有八个参数，通过原生变量选择器连接或配置允许的常量：

| 参数 | 类型 | 来源及含义 |
| --- | --- | --- |
| ForceN | REAL | 工艺力值，N |
| QualityGood | BOOL | 力值通信/采样质量有效 |
| Measuring | BOOL | 工艺采集状态，START 确认到 END/取消/首错 |
| ThresholdN | REAL | StationData 门槛，参考 2500 N |
| LimitN | REAL | StationData 3σ 标准，参考 0 表示未配置 |
| WindowMs | DINT | StationData 滚动统计窗口，参考 1000 ms |
| TimeoutMs | DINT | StationData 总判稳超时，参考 30000 ms，必须大于窗口 |
| SamplePeriodMs | DINT | 实际调用任务的名义周期，ms；默认 6，范围 1–1000 |

导出 StartupParams 使用 REF= 连接七个信号/工艺参数来源及本实例数据；SamplePeriodMs 赋给本实例 ParCfg.SamplePeriodMs。参数不会复制到另一套 HMI 可写变量。应用在每个位置首次 preflight 调用一次 PreparePosition，锁存四个工艺参数及采样周期；后续扫描使用已锁存值。途中修改从下一位置生效；无效参数不能放行测量。表内为独立示例值，本站保存初值及实际引用见 STATION010-NATIVE-20260916.md。

SamplePeriodMs 必须匹配实际调用任务周期，它不会创建或改变 PLC 任务，也不是 HMI 刷新周期。直接使用 Recorder 时，在 Configure 中传入同名 UDINT 参数。采样仍为每次 PLC 调用最多一次，时轴保留实际毫秒时间戳；可接受间隔上限为 ceil(2.5 × SamplePeriodMs)，默认 6 ms 时为 15 ms。统计窗口还必须不大于 min(60000, 10000 × SamplePeriodMs) ms，防止窗口超过固定环形缓冲容量。

对象生成 LeftFrame/MiddleFrame/RightFrame（各 DWORD[0..30035]）和 StatisticsFrame（DWORD[0..209]）。随附视图从对象数据变量的 HmiFullName 生成四个整数组 Item，不写死 Station010 路径。本站本次验证的实例数据为 Station.ForceTrace；数组含义仍按夹具左/中/右。Station.ForceTrace 与 Wp100.Trace2 的改名、换父节点、双实例验证来自旧 Bpp rev3 隔离参考，属于历史证据；本通用命名包没有重新交付该双实例 CpStudio 模型。

实例改名后需要同时重新导出 PLC 和 HMI。Fast export 只更新 PLC 代码，HMI 单独 Export 才重新生成页面中的 Item；再核对新数据父节点的 Symbol Read 权限、四数组成员及旧符号。当前完整 PLC Export 的原厂流问题仍存在；本站通过原生 Symbol Configuration Update 完成库类型迁移，并以保存重开后的新编译、配置回读、新生成 XML 和实际 SFC 核对。

## PLC 调用顺序

OpCon 框架（NxBase >=1.0.100）通过 protected OnCallEnter 周期调用采集器，并在发布时更新本实例数据。应用不要再次直接调用 Addon/Recorder 的 FB body。工艺流程负责显式生命周期方法：父循环开始调用 Recorder.BeginCycle；每位置首次 preflight 调用 PreparePosition 并检查返回值；采集 START 确认后调用 Recorder.Start(Position, InitialForceN)。下压到位后的每扫描调用 Recorder.Evaluate(ValueN, Healthy, AtWork)，只有 TRUE 才允许电阻仪启动。测量期间继续 Evaluate，首错优先于正常完成。

正常结束先 FreezeStatistics、RequestEnd，再等待仪表 END/状态完成；Finish(Reason, LastForceN) 保留原因。取消与异常按照应用的已确认流程结束采集，不能据 FALSE 自动抬缸或重放测量。方法定义及调用骨架随源码提供；Kistler 联锁、Station 自动流程、TypeData 判定属于应用参考，不进入通用库。

## 首版数据能力

三位置，每位置保留开始后的前 60 s / 10001 点；采样周期通过 SamplePeriodMs 配置，默认 6 ms，100 ms 发布，记录实际 PLC elapsed_ms。采样受调用周期约束，须在目标 PLC 验证任务时间和负载，库本身不创建实时任务。超出容量标记截断，统计继续。

统计使用完整时间窗口与样本标准差（n−1）：3σ = 3 × sqrt(Σ(Fi−F̄)²/(n−1))，单位 N。下压到位、数据健康、力严格大于门槛且完整窗口的 3σ 严格小于标准才判稳，等于边界不放行。力不高于门槛或数据异常会重置窗口。密度直方图使用同一 PLC 窗口；正态 PDF 是参考线，不声明实际数据服从正态分布。统计和测量许可始终由 PLC 计算，HMI 页面与 PDF 绘制不参与放行。

界面下方的中英文说明读取同一记录的参数；无统计窗口时，分布区域显示“尚无可用的统计窗口数据 / No usable statistical window data”，不再把已有力曲线误报为无曲线。有效力曲线仍保留显示。

保存提供完整记录、首次判稳点起两种 CSV；无判稳点或该点已超出保留容量时提示且不生成文件。晚开页面/重连读取 PLC 保留帧；新父循环清空旧循环。统计 FB 可单独用于 PLC，不依赖 HMI。

0.2.1.0 独立库和最小消费工程新编译均为 0 errors / 0 warnings；20 个库对象回读通过。847 项数值模型检查、685 项帧/晚开/重连/密度/CSV 检查通过；安装 DLL 与本站导出 SFC 通过原生加载、四个 Item 编辑器、2001 点对照、50 组刷新及两种 CSV。中英文说明按记录动态显示，检查了无统计窗口状态和实际导出页面边界。合成检查不代表 PLC 实际执行、HMI runtime 或实体工艺验收。升级和证据见[本次说明](../reviews/forcetrace-sampling-20260916.md)。

本次已构建并安装 PrjExt、compiled-library、HAD，保留源码与最小 PLC Consumer.project；按用户要求不追加完整 ZIP 和哈希收尾。实际 CpStudio 接入证据来自保存重开的 Station010。旧四组件 CpStudio 隔离参考模型仍在此前 rev3 包中，未把它冒充本次重新生成的最小模型。
