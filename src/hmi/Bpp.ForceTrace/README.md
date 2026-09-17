# ForceTrace 原生力曲线组件

最新源码/安装候选 **0.1.0.2**，本地及已只读核对的 IPC 安装仍为 **0.1.0.1**。
新版增加隐藏原生启动页，使记录先于可见曲线页运行；晚开/重开页面三位置记录已通过合成帧测试。
升级必须一起安装新 DLL 和生成启动入口；模板、命令和验证边界见下方接入说明。
以下 .1 记录是上一版本的集成证据，不是新版已部署的证明。

2026-09-11。PLC 发布与记录钩子、CpStudio 接口和 ForceTrace 页面已建立；原生安装自有
扩展包 0.1.0.1，HMI 单独 Export 通过，实际 VWN 为 VT_UI4/Cnt=14。
PLC 新 F11 0 errors / 原 5 warnings，五组 PlanOnly 为 0 操作。
完整 PLC Export 仍有原厂符号响应缺陷；未下载、未部署 IPC，真实订阅和现场数据尚未验收。

18 个原生中英文 Text 已注册。59 项记录/帧检查及实际安装 DLL + 本站 SFC 的帧→原厂图表→CSV
离线检查通过，121 点坐标/CSV 一致。实际设计器已保存、关闭并重开，无加载错误；空记录不显示演示曲线。

协议、精确绑定、注册升级注意事项、证据和剩余限制以
[接入说明](../../../docs/hmi_force_trace_addon.md) 为准。
旧 .1 需先打开 ForceTrace 页；新 .2 正确接入启动页后只需提前运行 HMI 并建立订阅。首次订阅不补录旧采集。
`ForceTraceView` 使用 `ChartChannel.Line` 的公开接口绘制 `ForceTraceStore` 的不可变快照；保存按钮
冻结同一个快照，再在后台写文件。没有从屏幕或 WriterHistory 反读数据，没有设备连接、PLC 写入、
测量或运动命令。此组件不依赖另一个自研 HMI 平台，不分发原厂 DLL。

## 已实现

- 同一轮最多保留左、中、右各一条曲线；新一轮显式清除上一轮内存记录，已保存的文件保留。
- 单位置最多 6000 条记录；容量到限立即停止，不无限增长。100 ms 为 PLC 目标发布与 UI 刷新间隔，
  不是已验证的 PLC 或仪表采样周期。
- 相同力值随真实时间前进继续记录；重复/倒序时间戳不作为新样本。帧适配器以递增序号和 500 ms 超时验证新鲜度。
- 超过预期间隔 2.5 倍标记缺口。无效数值/断线不补零；取消/流程故障/断线/容量有不同结束原因。
- 原厂 FastLine 的空点设置为透明，并设置 `IgnoreNulls=False`；缺口不连接，也不画假回零线。
- CSV 与图使用同一批样本，包含轮次、位置、UTC 时间、经过秒数、力、质量和结束原因。
  无效值/未知经过时间留空；小数点与 Windows 语言无关。
- 每次保存使用唯一文件名和 CreateNew；先写临时文件，再原子发布 `.csv`。最多 1000 个文件或
  512 MiB 的本组件 CSV，达到任一限制时报错，保留现有文件与内存记录。保存按钮在后台写入时禁用。
- UI 文本通过原厂 `LocalizedStateText` 引用 `Station` 组内的 `ForceTrace*` 文本。文本清单在
  `specs/hmi/force_trace_texts.json`，已在 CpStudio 文本模型创建；不是另建运行时语言系统。

## 离线验证

在 McpCoding 目录运行：

```powershell
pwsh -NoProfile -File scripts/hmi/Test-ForceTrace.ps1
pwsh -NoProfile -File scripts/hmi/Test-ForceTraceNative.ps1
```

使用 Windows .NET Framework 编译器和本站只读 `Std/Hmi_V5_11` 依赖；不启动 HMI 或连接 PLC。
输出在 `data/reports/hmi/`，不向 Std 写入文件。

- 28 项记录/CSV 加 31 项帧解码检查通过，包括独立位置、新轮次、取消、重复/倒序样本、稳定值、缺口、NaN、断线、
  容量、重复保存、区域设置与文件错误。
- `ForceTrace.sfc` 经原厂 SFCLoader 加载为 0 错误，C# 编译为 0 errors / 0 warnings。
- 121 条合成样本的原厂坐标逐点等于记录，保存 CSV 逐字等于图上快照；缺口和断线样本均为真正空点。
- 英文、中文离线预览通过。测试临时注入了翻译；**CpStudio 运行时语言切换尚未验证**。
- CSV 只保存到本机报告目录；没有证明 IPC .50 的文件权限、存储或部署。

## 现场验收

确认真实 OPC Item 质量与刷新、t=0 和经过时间、左中右周期归属、断线/取消/重复周期、原生语言切换和 IPC 文件权限；保持既有力与运动联锁。不要以离线测试替代现场验证。
