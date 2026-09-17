# ForceTrace 0.2.1.0：采样周期配置与中英文说明

2026-09-16，本地 Station010 已完成接入、原生 HMI 安装、Fast PLC export、HMI 单独 Export、保存重开及新编译。PLC 库、CpStudio 对象和 ForceTrace.Hmi 均为 0.2.1.0。当前交付未下载实体 PLC、未部署 IPC、未推送 GitHub。

## 用户可见变化

- 分布区域没有统计窗口时显示“尚无可用的统计窗口数据 / No usable statistical window data”。已有的力—时间曲线继续显示。
- 曲线页下方增加中英文说明：每 PLC 任务周期采样一次、本记录采用的周期、压力门槛、完整窗口、3σ 标准、计算公式、窗口重置和结束冻结。
- 说明读取所选位置记录中的锁存参数；没有记录参数时显示“—”。切换位置后显示该位置采用的值，不拿当前可编辑参数替代历史值。
- 保留 0.2.0.1 防闪烁处理和两种 CSV 保存范围。

## 采样周期与实际绑定

配置位置：**CpStudio → Station → Parameters → ForceTrace → SamplePeriodMs**。DINT、ms，默认 6，允许 1–1000。实际 MainTask 配置已只读核对为 6 ms；未改任务调度或 watchdog。

CpStudio 生成 `Station.ForceTraceAddon.ParCfg.SamplePeriodMs := 6`，在启动/在线变更初始化时应用。单独使用库的 Recorder 时，可在 Configure 中传同名 UDINT 输入；通过 Addon 使用时，由 PreparePosition 锁存。本站 CheckPressForce 在每位置首次 preflight 读取并锁存该参数，再传给 Recorder。

**这个值必须匹配实际调用任务周期，它不会自动修改 PLC 任务。** 采样仍是每次实际调用最多一次，保留 PLC 实际毫秒时间戳；6 ms 也不表示仪表一定每 6 ms 提供一个新转换值。真实仪表刷新、任务抖动和 CPU 负载仍需现场核对。

可接受间隔上限为 `ceil(2.5 × SamplePeriodMs)`，默认 6 ms 对应 15 ms。统计窗口须满足 `WindowMs <= min(60000, 10000 × SamplePeriodMs)`，超过容量或周期无效时禁止放行。

原有七项引用保留：

| 对象参数 | 本站来源 |
| --- | --- |
| ForceN | Wp100A104Kistler.Unit.OutImm.ForceAct |
| QualityGood | Station.ForceTraceQualityGood |
| Measuring | Station.ForceTraceMeasuring |
| ThresholdN | Station.StationData.PressForceThreshold |
| LimitN | Station.StationData.PressForce3SigmaLimit |
| WindowMs | Station.StationData.PressForceStableTime |
| TimeoutMs | Station.StationData.PressForceTimeout |

四个 HMI Item 仍指向 `Ch1.L1.Station.ForceTrace.LeftFrame / MiddleFrame / RightFrame / StatisticsFrame`。采样周期使用既有 v2 帧元数据字段传输，按位置保留；没有新增可写 HMI 参数客户端。PLC 拥有采集、统计和放行判定。

## 3σ 计算与判稳

采用完整滚动时间窗口的样本标准差：

`3σ = 3 × sqrt(Σ(Fi − F̄)² / (n − 1))`，单位 N，n 为窗口样本数。

下压到位、数据健康、力严格大于门槛、窗口时间完整且 3σ 严格小于标准，才允许启动电阻仪。力等于门槛会重置窗口，3σ 等于标准不放行；总超时不因掉力重启。统计和测量许可在 PLC 中运行，不依赖 HMI 页面或 PDF 绘制。

分布为同一 PLC 窗口的 20 桶密度直方图，加正态概率密度参考线：`f(F) = exp(-(F−μ)²/(2σ²)) / (σ × sqrt(2π))`，不是 KDE。σ=0 时显示集中标记。正态参考线不作为判稳条件，不表示实际样本必然服从正态分布。

## 本地验证

| 层次 | 结果 |
| --- | --- |
| 0.2.1.0 独立 PLC 库 / 最小消费工程 | 新编译均 0 errors / 0 warnings；20 个库对象回读 |
| 实际 Station010 PLE | 保存重开后新 Generate code：0 errors / 5 原有 warnings |
| 实际 CpStudio | Fast PLC export、HMI 单独 Export、重开 Validate：0 errors / 2 原有 Burster 兼容性 warnings |
| 数值模型 / HMI 帧与 CSV | 847 / 685 项检查通过，含可变周期与边界 |
| 安装 DLL + 实际导出 SFC | 原厂加载器 0 errors、4 个 Item 编辑器、2001 点、50 组刷新、两种 CSV 通过 |
| 中英文与布局 | 动态记录参数、无统计窗口提示、实际 944×680 页面内说明区域通过；两种预览已目视核对 |

5 条 PLE 警告为 4×OPC.UA.DA 属性未知、1×ErrorCodes 的 DWORD 枚举基型。升级时通过 PLE 原生 Symbol Configuration 的 Build → Update 将旧 ForceTraceData 引用迁移至 0.2.1.0；新增的四条旧库引用警告已消除。全部已配置 Symbol 选项与修改前一致，仅库身份版本改变；Station.ForceTrace 父节点仍为 Read，类型成员保留原选择。没有重试已知有缺陷的全量 Symbol REST 流来掩盖问题。

模型按 Guid 比较，既有业务值和权限不变；差异为 ForceTrace 版本、新参数及五项中英文资源和原生序号重排。78 个受保护文件哈希不变，包含原厂 DLL、IO 工程、StationData/TypeData DAT、主界面及其他自有组件。用户 Burster Hostname 的 StationData 引用保留。

证据目录为 `data/reports/hmi/forcetrace-sampling-20260916`：`station-reopened-final.json` 为最终新编译，`installed-native/native-check.json` 为 HMI 加载检查，`model-diff.json` 为模型差异，`plc-plan-reopened.json` 为零操作回读。CpStudio 参数页和重开后的 0/2 结果已在本任务中核对。独立库/消费编译在 `data/native-packages/20260915/forcetrace-0.2.1.0-20260916/build-01-final.json`。中间失败记录保留，不替代最终通过记录。

按用户收尾要求，停止追加哈希、汇总收据和新 ZIP；保留已完成的库、HAD、工程与证据。本次没有生成新的完整组件包，旧 0.2.0.0 ZIP 不代表当前本地 0.2.1.0。收尾草稿 finalize-local.py 未执行，不作为验证结果。

## 更新与恢复

本地工程与扩展已就绪。现场由用户**配套更新本次 PLE、生成 HMI 和 ForceTrace.Hmi 0.2.1.0 DLL**，保持现场活动 StationData/TypeData 文件与权限。不能沿用旧 0.2.0.1 补丁“只更 HMI”的步骤。

恢复点在上述证据目录的 `before`、`before-install`，由 `baseline.json`、`install-recovery.json` 索引；恢复时使用同一版本的工程、PrjExt、PLC 库和 HMI 扩展，不混用新旧载荷。不覆盖原厂 DLL。`before-symbol-migration.project` 仅是升级过程中的中间恢复点，不是升级前完整工程。

现场尚待确认：实际采样和任务负载、三位置两轮、晚开页面/重连、运行时中英文切换、真实门槛与 3σ 边界、两种 CSV 及运动联锁。本次编译和合成测试不等于 PLC 实际执行或实体验收。本次构建提供最小 PLC Consumer.project，CpStudio 升级证据来自实际 Station010；未声称新增隔离双实例模型已验证。
