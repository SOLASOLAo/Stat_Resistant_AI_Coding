# ForceTrace HMI 0.2.0.1：曲线闪烁修复

2026-09-16，已按用户“安装下，我来下载”完成本地原生安装及 HMI 单独导出，待用户更新 IPC。PLC 库、CpStudio 对象和 v2 四数组接口继续使用 0.2.0.0；仅 HMI 程序集升级到 **0.2.0.1**。

[HAD 安装包](../../data/components/native/forcetrace-hmi-0.2.0.1/ForceTrace.Hmi.had) · [补丁离线验证](../../data/reports/hmi/forcetrace-flicker-20260916/verification.json) · [安装收据](../../data/reports/hmi/forcetrace-flicker-20260916/local-install/installation.json) · [安装 DLL 的实际页面检查](../../data/reports/hmi/forcetrace-flicker-20260916/local-install/native/native-check.json)

## 原因与修复

用户两张现场截图的右侧均值、3σ、样本数及分布一致，左侧在已完成曲线和“本轮此位置尚无曲线记录”间变化。原 HMI 把曲线帧的长度、首尾序号或校验和错误直接当成清空记录；下一完整帧又恢复曲线。向原代码注入一帧首尾序号不一致的数据，已复现曲线被删除。现场没有抓取原始传输帧，所以具体是哪项校验失败仍未实测。

接收层现在丢弃未通过校验的数据包，并保留最后一份通过校验的快照；被拒绝的统计包不刷新 500 ms 心跳。真正的 Item 质量异常、统计心跳超时、已确认的新循环/启动身份以及有效空记录仍会清除旧显示。旧身份且序号落后的曲线包不能覆盖当前记录；PLC 重启时重新附加所选曲线 Item，以处理曲线先于统计到达的情况。

v2 的一个采集记录在首次结束原因确定后不可变，PLC 后续发布只推进序号。重复帧和已结束记录的重复发布不再替换快照，因此不会反复清空并重画全部点。运行中的新样本仍正常更新。HMI 不采样、不计算判稳、不改变 CSV 内容和绑定。

## 已完成验证

- 修复前回归失败：`torn trace must not erase a verified completed curve`；修复后通过。完整测试共 675 次断言，其中包含三位置、两轮及重复接收循环，并非 675 个现场工况。
- 新 C# 程序集编译成功，无编译错误或警告；帧、序号、采样时间、质量、晚开、重连、清空及两种 CSV 测试通过。
- 使用实际 Station010 导出的 `ForceTraceForceTrace.sfc` 和新 DLL，原厂 SFCLoader 0 errors，四个原生 Item 编辑器可用，绑定仍为 `Ch1.L1.Station.ForceTrace.LeftFrame/MiddleFrame/RightFrame/StatisticsFrame`。
- 原生 Mod_Chart 的 2001 点逐项匹配 PLC 模拟时间/力值；连续 50 组破损帧与正常重复发布交替注入，曲线保持同一快照；统计超时后仍清空。
- [中文预览](../../data/reports/hmi/forcetrace-flicker-20260916/station010-native/preview-2052.png)、[英文预览](../../data/reports/hmi/forcetrace-flicker-20260916/station010-native/preview-1033.png)已查看；两种保存范围与快照 CSV 一致。HAD 解包后程序集身份和文件字节与已验证构建一致。

这是离线模拟、编译和原厂控件加载证据；尚未验证 IPC 上的实际刷新。首次离线补丁阶段没有安装或导出，原 verification.json 保留该阶段事实。其间 `Engineering_Data.xml` 由外部操作更新于 13:56:41；之后的安装以用户当前工程为基准，不回滚该修改。

## 本地安装结果

- CpStudio 原生 HMI add-ons 显示 ForceTrace.Hmi **0.2.0.1**；安装 DLL 的 SHA-256 与已验证构建一致。原厂 DLL 未变，搜索路径仍只有 `Addons/ForceTrace.Hmi`。
- 使用原生扩展管理器清除旧版本引用后重新安装，Gui.config、VisiWinNETSmart.config 与 csproj 均只保留一个正确扩展引用；没有新旧目录并存。最终 APQ HMI 单独 Export 完成，Messages 为 0 errors / 原有 2 条 Burster 兼容性提示；不代表历史完整 PLC Export 弹窗已修复。
- 安装 DLL 配合实际 Station010 SFC 完成原厂加载、675 次帧/CSV 断言、2001 点及 50 组交替发布检查；最终导出后 DLL 和实际 SFC 字节仍与该次检查相同。
- 本次工程侧仅变更生成的 HMI csproj、Gui.config、VisiWinNETSmart.config 和 VWN；四个整数组类型/长度与实际页面绑定复核通过。Engineering XML/cpsp、PLC/IO 工程、页面 SFC、StationData/TypeData 导出 DAT 均未变。本站选用记录独立更新 HMI 版本，PLC 组件锁保持。
- 恢复清单为 local-install/recovery.json，复用已校验的旧 DLL，并保留旧版 HAD。未连接/下载 PLC，未操作 IPC、GitHub 或现场数据。

## 更新与恢复

1. 本机已经安装，无需再导入。其他工程安装时，先备份并通过 CpStudio 原生 HMI add-ons 移除旧 ForceTrace.Hmi，再导入本页 HAD；文件名须为 **ForceTrace.Hmi.had**，版本号保留在父目录。原厂导入器按 HAD 文件名建立目录，直接用带版本号的文件名会产生另一条扩展；直接覆盖旧版也可能残留旧程序集全名，单独 HMI Export 不会清理这些引用。核对只有一个 0.2.0.1 引用后执行 HMI 单独 Export。
2. 按既有 HMI 发布流程更新 IPC 上的自有扩展并重新启动 HMI，核对实际加载程序集版本为 0.2.0.1。仅导出页面或刷新浏览界面不能证明扩展 DLL 已更新。本补丁不要求 PLC 下载、模型重新绑定或修改 StationData/TypeData；现场活动参数与 CSV 保留。
3. 三个位置各完成记录后停留曲线页，确认不再切换为“无曲线”；随后确认下一轮清空、晚开页面、重连和两种 CSV。若仍闪烁，再取现场 Item 质量、序号/校验失败证据，不能把本次模拟当成现场已修复。

需要回退时，在 HMI 停止的更新窗口经同一原生扩展流程恢复原 0.2.0.0。此次包只含自有程序集和 add-on 描述，旧 ForceTrace 0.2.0.0 rev2 完整组件包没有覆盖。

| 文件 | SHA-256 |
| --- | --- |
| forcetrace-hmi-0.2.0.1/ForceTrace.Hmi.had | `C3DBAF7084DC6C3BD3C445E4506BA62512F8DB1890336D7CB7524800B300DBAA` |
| ForceTrace.Hmi.dll | `B752DEC3572AA3FFFA0D703C4C886BAA8A36A2F72AC6339085FEE53AEFA2720B` |
