# Station010 原生组件接入

2026-09-16，实际 Station010 本地原生接入已完成离线验证。目标为 `Station010/Engineering/Stat010_V5.11_CtrlX.cpsp` 和唯一 PLE 的 `Station010/Plc/Stat010_V5.11_CtrlX_PLC.project`。

| 组件 | 本站实例与数据 |
| --- | --- |
| ForceTrace 0.2.0.0 | `Station.ForceTraceAddon`、`Station.ForceTrace`；四数组 `LeftFrame/MiddleFrame/RightFrame/StatisticsFrame` |
| MachineCommon 0.1.0.0 | `Station.MachineCommonPressure`、`Station.MachineCommonDoor`；Home/Run 各自的按钮实例使用 `MachineCommon.FB_OperatorButton` |
| Burster2316 0.1.0.2 | `Peripherals._Burster2316`，类型 `Burster2316Peripheral`；标准 `IBursterResis2316` 接原厂 Unit |

通用组件的对象显示名、PLC 库与 HMI add-on 不带 BPP 前缀。Company 为 Internal Engineering；最低 CpStudio/OES 为 5.11。XSD 文件名中的 V4_11 是原厂 schema 标识，不代表最低软件版本。已验证 PLE profile 为 ctrlX PLC 2.6.8；不扩大兼容声明。Danikor 保持原发布身份。

Force Trace 参数在 CpStudio 原生选择：力值为 Kistler 的 ForceAct，质量与测量状态为 Station 两个桥接 BOOL；门槛、3σ 限值、窗口、总超时引用当前 StationData。每位置首次 preflight 锁存四参数，未配置引用或无效参数不放行。本站接入前已保存的初值为 2500 N、5 N、1000 ms、10000 ms，接入后全部保留；未读取或修改现场活动 DAT。独立组件参考的 3σ=0 表示未配置，不代表本站当前初值。

原厂框架顺序为 StationUnit.OnCall → Add-on.OnCallEnter → 步骤链与子 Unit。新采集使用 OnCallEnter，保留原来的扫描时序；要求 NxBase 至少 1.0.100，实际为 OpconBase 1.0.102.0。应用不再调用 recorder 循环体，仅管理 BeginCycle/Start/Evaluate/Freeze/End/Finish。

维修门、虚拟气压反馈、主气压按原顺序执行。虚拟反馈仍读前一扫描最终阀命令，1 s 延迟；原 5 s/1 s 监视、物理 BMK 和诊断逻辑保留。按钮不共享跨流程的内部状态。

Burster 地址仍为 192.168.0.103，端口 5555，测量超时 30000 ms，程序号取活动 TypeData。Unit 与选程包装器共用这个 Peripheral，不新增 socket，不自动重放测量。原厂旧库仍可能保留在工程依赖中，因此自有类型使用唯一名称，避免 `IpBurster2316` 歧义。

恢复点：`data/station-native-integration/20260916/before` 和 `baseline.json`（310 个已核对文件）。`before-plc-source` 保存原 307 个对象；`after-native-export` 保存首次原生导出后 308 个对象。应用迁移计划及收据保存在同目录，17 个对象回读并保存；9 个重复本地根退役。恢复应使用保存工程与匹配的 PrjExt/HMI 扩展，不重新运行旧驱动或旧 HMI startup 工具。

最终证据：原生模型 Fast export、HMI 单独 Export，以及保存关闭重开后的 Validate 均为 0 errors / 原有 2 条 Burster 兼容性警告。本站新 Build 为 0/4；最终 Generate code 为 0/5（4×OPC.UA.DA、1×ErrorCodes 枚举基型），与既有警告签名一致。初次编译同名冲突已用唯一 Burster2316Peripheral 类型解决；Burster 消费工程也已验证与原厂 NexeedIpBurster2316 库共存。

新符号为 Station.ForceTrace（Read），包含 LeftFrame/MiddleFrame/RightFrame 各 30036 个 DWORD，StatisticsFrame 210 个 DWORD；HMI 页面 ForceTraceForceTrace 由对象自动生成。实际安装 DLL 与实际 SFC 通过原厂加载器、29 项帧/重连/CSV 检查，2001 个曲线点与 PLC 合成帧逐项一致。旧自定义 ForceTrace 页面及 Smart project 登记已清理。旧 HMIForce* 声明暂保留为未用模型字段，已取消发布，应用不再赋值、HMI 不再订阅。

最终回读 274 个 PLC 对象，20 个数据结构源码与接入前相同；StationData/TypeData 的权限、导出 DAT、IO 工程和主界面 UserDefined.sfc 保持字节一致。原生对象重新载入补入 1160 个原先为空的中文资源，没有改已有非空翻译；模型另有原生展开/收起状态变化。两个应用恢复脚本 PlanOnly 均为零操作。完整 PLC Export 的原厂 REST 流缺陷仍未修复。最终 Generate code 后的全量 datatype 只读枚举曾报 duplicate-key；编译本身通过，后续用新生成的 XML、受保护类型对比及原厂 HMI 加载器独立核对。

恢复和证据在 McpCoding/data/station-native-integration/20260916：FINAL-VERIFICATION.json、after-final、hmi-installed-final。当前选用记录为 config/station010-native-selection-20260916.json；旧 component-versions.json 与 rc.4 作为历史保留。通用命名候选为 Burster2316 0.1.0.2 local-rev5、ForceTrace 0.2.0.0 local-rev2、MachineCommon 0.1.0.0 local-rev2，Company 均为 Internal Engineering；三个库及最小消费工程各为 0/0。

上述包修订只修正文档并补入既有解包新编译收据。程序源码、PLC 库、CpStudio 对象、HMI 和 Consumer.project 与上一修订逐文件哈希一致，因此编译结论沿用同一载荷的已完成新编译。本轮文档收尾没有启动 IDE 或重新导出，实际工程不变。新包包含最小 PLC 消费工程；新版最小 CpStudio 隔离参考模型尚未随包提供，实际安装验证来自本站，旧 Bpp rev3 参考保留为历史。

本次未连接或下载实体 PLC、未部署 IPC、未上传 GitHub；没有实体 FAT 结论。用户既有 StationData/TypeData 权限、电阻三行显示、原始 Ω 判定和夹具位置语义必须保留。
