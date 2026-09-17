# PLC 实时力曲线、CSV 与事件补充

日期：2026-09-10。状态：**控件核实与接入规格，尚未改 HMI/PLC，也未实现 CSV 按钮**。

## 已确认的范围

用户选择 PLC 实时力曲线，不取 Kistler 内部完整测量曲线；在运行 HMI 的 IPC（.50）本地保存 CSV，左/中/右分开，按钮触发保存。当前规格见 [plc_force_curve.yaml](../../specs/hmi/plc_force_curve.yaml)。100 ms 为拟定观察级采样默认值，不是已测得的刷新周期或用户额外要求。

## CpStudio 已有控件

| 控件 | 本机文档/工程确认 | 本项目选择 |
|---|---|---|
| `Mod_Chart` | 标准 Kistler 的 `Chart` 页已经在用；当前为 `Writer`，绑定 `Extension.OutHmi.ValueArrayX/Y` | 沿用，先验证现有页的时间轴与实时值 |
| `Mod_Chart.WriterHistory` | 保留移出窗口的历史，X 回退会清空；普通 Writer 会丢弃左侧移出的点 | 适合查看单次过程，但不是文件存储或跨循环档案 |
| `Mod_ScopeView` | 有开始/停止/保存，文档依赖 TwinCAT Scope Server，记录为 `.svd`、配置为 `.sv2` | 没有本项目 ctrlX + CSV 的支持证据，不直接引入 |

`WriterInterval`/`WriterOffset` 是 X 轴窗口宽度/滚动步长，不是采样周期。`Append/AppendPersistent` 在该文档中只支持 OMC，不当作 PLC 模式推荐。X/Y 是单元素趋势数组，不是已缓存的完整仪表曲线。`Mod_Chart` 页面未记录 CSV 导出按钮；不能把 Scope 保存按钮或“导出配置 XML”误当 CSV 保存。

### CpStudio 人工配置位置

1. `Model → Station → Wp100 → Wp100A104Kistler → HMI configuration → Chart`，打开现有标准视图，确认 `Mod_Chart`。若该标准视图只读，在本站 HMI 创建自有视图使用同一控件，不修改 `Std` 的原厂视图。
2. 检查 Smart Properties 的 `DataMode` 及 `Channels` 中 `VWItemXData/VWItemYData`，沿用生成的符号。观察阶段可选 `WriterHistory`，但先核实 X 的真实时间单位/重置规律。
3. CSV 需要一个自有“保存当前曲线”按钮及受支持的导出处理。先核对 HMI SDK 能否读取曲线样本；若不能，则显示与 CSV 共用一份受限采样缓存。不要再造一套后台平台，也不要从截图恢复曲线。
4. 若需要新 PLC 缓冲或 HMI 变量，先在 CpStudio 增加并 Export，再由 AI 接应用逻辑；保存路径拟为 IPC `C:\OpconData\ForceTraces`，部署时验证 HMI 身份的写权限。

时间与力来自同一采样记录；每个文件带循环号、位置、时间、力、数据质量和结束原因。观察级 HMI 采样可能漏掉两个刷新之间的瞬态，不能代替 PLC 内 `>2500 N` 连续 2 s 与测量中 `<=2500 N` 的实时判定。发生断线/缓冲满/文件失败要明确显示，不补零、不改联锁、不自动抬缸。

## 建议新增的应用事件（未创建/未占用）

从本次生成的 `Station010/EventRecorder/Events.xml` 确认：`Wp100` 已使用 **1、2、3、4、5、12**；`Station` 已使用 **1、2、4、5、60、61**。数字必须结合 owner 识别；XML 正号对应 PLC 用户事件常量通常是负号，例如 `Wp100.EVENT_PRESS_FORCE_INVALID = -5`。实际以 CpStudio 导出的符号为准，不手写数字代替生成常量。

以下均建议放在 **Model → Station → Wp100 → Events**；添加前再核对 CpStudio 当前未导出的内容，避免冲突。

| 建议显示号 | 建议符号 | 中文 / English | 触发依据 |
|---|---|---|---|
| 20 | `EVENT_MEASURE_CONFIG_INVALID` | 测量参数无效 / Invalid measurement configuration | 现有超时、程序号或上下限校验失败，注明参数和值 |
| 21 | `EVENT_FORCE_WAIT_TIMEOUT` | 压紧力等待达标超时 / Press force qualification timeout | 已压下到位，规定时间内未达到 >2500 N 连续 2 s |
| 22 | `EVENT_FORCE_LOST_DURING_MEAS` | 电阻测量期间压紧力不足 / Insufficient force during resistance measurement | 已开始测量后任一扫描力 <=2500 N |
| 23 | `EVENT_FORCE_DATA_INVALID` | Kistler 测量状态或力数据无效 / Invalid Kistler measurement state or force data | 采力状态、标准报警或数值无效；不把力值不变化当断线 |
| 24 | `EVENT_PRESS_WORK_POS_LOST` | 压缸工作位信号丢失 / Press work-position feedback lost | 力监控期间 `IsInWrkPosIn` 丢失 |
| 25 | `EVENT_KISTLER_PREP_FAILED` | Kistler 程序选择或就绪失败 / Kistler program selection or readiness failed | 准备阶段失败，附目标/实际程序及状态 |
| 26 | `EVENT_BURSTER_PROGRAM_FAILED` | 电阻仪程序确认失败 / Burster program verification failed | 自研驱动选程未完成，附首错与程序号 |
| 27 | `EVENT_BURSTER_MEASURE_FAILED` | 电阻仪测量或结果读取失败 / Burster measurement or result read failed | 测量命令/读取协议失败；普通电阻 NOK 仍是质量结果，不混为通信报警 |
| 28 | `EVENT_BURSTER_CLEANUP_FAILED` | 电阻仪退出或通信清理失败 / Burster cancellation or communication cleanup failed | 清理无法结束，保留最早原因而非覆盖它 |

这些是应用诊断，拟沿用现有力故障的 `SOFTERROR`/锁存行为；是否同级显示由 CpStudio 配置审核。每项要映射到实际失败分支，不能只新增名称。旧 Wp100 5 保留兼容：新的精确事件接好后，不再同一故障同时抛“5 + 精确事件”；尚未映射的旧路径仍有故障提示，不能出现空窗。

- 力异常保持当前步骤及下压，只有现有安全/取消/复位流程可处理；恢复力值不能自行消警续跑。
- 仪表标准事件不屏蔽。若标准事件已清楚表达同一个故障，不重复弹应用事件；应用层补缺失的上下文，优先保留首错。
- CSV 保存失败/缓冲满先显示 HMI 本地提示，不因此增加运动停机事件。需要进入统一 EventRecorder 时，再通过 CpStudio 增加明确的反馈接口。
- 等待操作者移动 fixture/拍按钮属于正常提示，不增加等待时间报警。
- 旧 `wp130`/`AOI` 文本看起来像模板遗留，但未经全调用核对，不删除或复用其号码。

## 证据与未完成项

本机厂商帮助（只读，发布日 2025-05-13）：`Control_plus_Studio_English.chm` 的 `Mod_Chart`、`Channels`、`Mod_ScopeView`、`TcScope recording`、`Recording (manually) via HMI`。可复查的本地解包页位于 `data/vendor-help/cpstudio-5.11-en/`，分别为 `8af0d59d-d555-4081-9773-dc762043300b.htm`、`c1a4a15d-fe08-4758-b3f3-14dc939fc3b8.htm`、`c61a2cc0-e52f-43ef-aaf7-402e9be18d8a.htm`、`883e2a9a-b866-49ec-a923-58ba33015697.htm`、`d77c5b96-84ed-455d-939c-45e2237449d7.htm`。不向 Git 分发帮助原文/DLL。

本轮仅核实控件/生成文件、整理规格与事件提案；没有调用现场设备、修改标准库/Station010、Export 或部署。CSV 保存适配、CpStudio 配置及事件触发代码都未实施。后续应先完成一个曲线页面与一次本地保存，再接专用事件，不一次改动全部流程。
