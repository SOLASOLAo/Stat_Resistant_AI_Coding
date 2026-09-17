# ForceTrace — 源码包 0.1.0-rc.2 / 原生扩展 0.1.0.2

给 OpCon Modulo 5.11 的原生力曲线/CSV 扩展；复用 VisiWinNET Item 和 Mod_Chart，不增加 OPC 客户端、PLC 控制命令或独立 HMI 平台。
交付自有 DLL/HAD、唯一源码、原生双语文本、参数化页面/启动模板、PLC 发布器及帧协议。标准 DLL/库由使用方已有环境提供，不随包分发。

## 本版变化与状态

.1 到打开曲线页时才订阅，自动已经开始时打开会错过先前位置。.2 的隐藏 SmartForm 在 HMI 启动预加载时建立共享记录器，页面打开、隐藏、销毁再创建不改变该记录器的生命周期。
已验证原厂 Gui.config 预加载路径和先录三位置后开页面的合成帧场景；当前 Station010/CpStudio 和只读核对的 IPC 安装仍是 .1。
候选不是已部署版本，源码包版本和 DLL 四段版本是两层编号。

## 接入新项目

1. 在 CpStudio 配置项目自己的只读 `ARRAY[0..13] OF DWORD` HMI/OPC 接口；保留模型所有权。安装包不会创建 PLC 接口或替换设备。
2. 通过 PLE 导入 `FB_HmiForceTrace` 和 `U_HmiForceWord` 的对象/声明/实现；原始 `.st` 中有 OBJECT 标记，应按方法边界导入，不能将整文件粘成单一实现。新项目只实例化一个发布器，周期调用 Measuring/QualityGood/ForceN 并将 Frame 复制到上述接口。
3. 合理的生命周期调用为 `BeginCycle()` → `Start(Position, InitialForceN)` → 正常结束前 `RequestEnd()`；真实 Measuring 下降才产生 Completed。取消调用 `Finish(Reason := 3, LastForceN := 实际力)`，首个过程故障 Reason=4、数据无效=5，保留首个终态；不修改运动、力阈值或标准驱动状态。参数与签名以打包源为准。
4. 在 CpStudio HMI add-ons 原生安装 `native/Bpp.ForceTrace.had`。升级时先备份已有自有扩展/注册引用，按项目正常关闭流程释放设计器程序集，再原生移除旧版/安装新版并确认 Gui/Toolbox 各一个 .2 引用。不要在正在运行的 HMI 中替换 DLL。
5. Windows PowerShell 运行 `scripts/hmi/New-ForceTraceTexts.ps1 -OutputPath '<新文件>.cpsds'`，生成 18 个 Text。先检查目标组内同名资源；选中自己的 HMI 父组，在 CpStudio 原生 Import 中导入一次并保存。已有资源用原生语言字段更新，不重复导入。生成器不写工程；新项目 native Import/保存/导出须单独验收。
6. 运行 `New-ForceTraceViews.ps1 -FrameItemName '<实际 Item>' -TextGroup '<导入 Text 所在组>' -SaveDirectory '<IPC 本地目录>' -OutputPath '<新目录>'`。创建本机 Machine view 后保存并关闭设计页，精确使用生成的曲线 WFML；由原厂加载器/CpStudio 验证，不盲写打开的设计页。
7. HMI Export 后运行 `New-ForceTraceStartupOverlay.ps1`，参数为导出 Gui.config、实际曲线 SFC、匹配 DLL、新输出目录；审阅唯一自有引用和隐藏 `BppForceTraceStartup` 增量。每次再次 Export 均重生成 overlay，启动页 FrameItemName 必须与视图相同。
8. 部署时把匹配 DLL/HAD、资源、视图、启动 SFC 和 Gui 配置作为同一 HMI 版本审核。只更换 DLL 不能修好晚开问题。示例参数包含的 Station/Ch1/路径仅是项目参考。

不要将曲线 SmartControl 的 loadOnStartup 改为 True；原厂预加载要求 SmartForm。一个 Item 配置一个启动页。HMI 需在周期前建立有效订阅；在 HMI 启动/断线前丢失的历史不会补录。

## 接口、单位与限制

`FrameItemName` 是既有原生 Item 名，不是 OPC URL；`TextGroup` 是项目资源组；`SaveDirectory` 是 HMI 所在机器目录。没有固定 IP 或驱动 BMK。`ForceTrace.sfc` 为本站参考，参数化生成命令会替换其三项项目值；启动模板默认空绑定，空绑定不采集。
帧 v1：一次 14 DWORD，序号/重复序号/FNV 校验、周期号、采集号、位置 1/2/3、状态 0..5、PLC 毫秒、REAL 位模式的 N、质量和启动标识。完整偏移、结束原因与保存格式见 `docs/hmi_force_trace_addon.md`。
名义发布 100 ms，500 ms 无新帧或坏质量结束记录，超过 250 ms 标空缺；恒定力值照常记录。不将 UI 记录用于安全控制或产品质量裁决。
一轮左中右各最多 6000 点；新轮清旧内存，退出 HMI 失去未保存内存。CSV 由明确保存按钮触发，每次选中位置同一快照；不是自动每轮保存。UTF-8、秒、N、UTC，固定小数点；最多 1000 文件或 512 MiB，失败保留原文件，不自动删旧文件。

## 离线检查和回滚

先运行包内 `scripts/components/Test-ComponentPackage.ps1 -PackageRoot .`，记录 contentId。核心记录/帧测试为 `scripts/hmi/Test-ForceTrace.ps1 -OutputPath '<包外新报告目录>'`（59 项，不连 PLC）。原厂控件检查用 `Test-ForceTraceNative.ps1 -RuntimePath '<已安装 Modulo 目录>' -OutputPath '<包外新报告目录>'`；隐藏启动测试用 Windows PowerShell x86 运行 `tests/hmi/Test-ForceTraceStartup.ps1 -AssemblyPath '<本包 DLL>' -RuntimePath '<Modulo 目录>' -OutputPath '<包外报告目录>'`。所有测试输出放包外，保持冻结包完整；重编译产物不覆盖随包已验证的 DLL/HAD。
本次实际构建和有限证据见 `specs/hmi/force_trace_build_evidence.json`；源码与二进制分别锁 SHA，不用旧编译结果替代新源编译。运行时语言切换/实际 OPC 质量/节拍、未开页面的一整轮和重新打开、取消/断线/第二轮、IPC CSV 权限仍需受控现场验收。
回滚须成套恢复此前 HMI 自有 DLL、注册引用、Gui、SFC 和语言导出；回到 .1 时移除 .2 的隐藏启动入口，否则旧 DLL 没有该类。保留已有 CSV。此版本帧协议未改，单独 HMI 回滚不需要改 PLC 的测量顺序。
