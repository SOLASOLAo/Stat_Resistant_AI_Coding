# CpStudio＋ctrlX 本地组件包索引

2026-09-16：实际电阻台 Station010 已接入 ForceTrace、MachineCommon、Burster2316 原生组件。本页列出当前本地候选；Danikor 保持原 1.1.0.0 身份和原包。仅声明已验证的 CpStudio V5.11 / ctrlX PLC 2.6.8，不代表实体设备验收。

## 当前 ForceTrace 本地升级

Station010 已接入 **ForceTrace PLC/对象/HMI 0.2.1.0**，采样周期可配置，页面增加中英文判稳说明，包含旧防闪烁修复。实际 PLE 新编译 0/5，CpStudio 0/2，独立库/消费新编译 0/0。已安装到本地 PrjExt 和自有 HMI add-on，需用户配套更新 PLE、HMI 和 DLL。

[升级与配置说明](../reviews/forcetrace-sampling-20260916.md) · [已生成 HAD](../../data/components/native/forcetrace-hmi-0.2.1.0/ForceTrace.Hmi.had) · [新库/消费构建](../../data/native-packages/20260915/forcetrace-0.2.1.0-20260916/build-01-final.json)

按用户要求不追加哈希和完整 ZIP。以下四套 ZIP 及验证为此前封包，保持原样；其中 ForceTrace 0.2.0.0 包不代表当前本地 0.2.1.0。

## 此前已封包的四套 ZIP

编译栏为 errors / warnings，来自已完成的原生新编译。Burster rev5、ForceTrace rev2、MachineCommon rev2 只修正文档并补入既有证据；程序、compiled-library、CpStudio 对象、HMI 和 Consumer.project 均与上一修订哈希相同，未为文档修订重复编译。

| 组件 | 版本 / 修订 | 本地交付 | 库编译 | 消费 / 参考编译 |
| --- | --- | --- | --- | --- |
| DanikorScrewer | 1.1.0.0 / rev3 | [ZIP](<C:/A_Documents/A_Projects/A_Software/DankerScrewer/Project/DanikorScrewer-Colleague-Handoff-1.1.0.0-local-rev3-20260915.zip>) | 0 / 0 | 参考 0 / 4 |
| Burster2316 | 0.1.0.2 / rev5 | [ZIP](../../data/components/native/burster2316-0.1.0.2-local-rev5.zip) | 0 / 0 | 消费 0 / 0 |
| ForceTrace | 0.2.0.0 / rev2 | [ZIP](../../data/components/native/forcetrace-0.2.0.0-local-rev2.zip) | 0 / 0 | 消费 0 / 0 |
| MachineCommon | 0.1.0.0 / rev2 | [ZIP](../../data/components/native/machinecommon-0.1.0.0-local-rev2.zip) | 0 / 0 | 消费 0 / 0 |

三个通用组件的 Company 为 Internal Engineering，目录显示名分别为 Burster 2316、Force Trace、Machine Common；图标已进入当前 PrjExt 和包。Danikor 继续使用 DanikorScrewerLib 原发布身份。旧 Bpp 候选、此前修订及 rc.4 均保留。

每个通用包包含自有 PrjExt、compiled-library、源码、最小 PLC Consumer.project、安装/依赖说明和证据；ForceTrace 另含 ForceTrace.Hmi 0.2.0.0 HAD。原厂 Std 是外部依赖，不在新包中。

另提供 **ForceTrace.Hmi 0.2.0.1 闪烁修复 HAD**：[安装包](../../data/components/native/forcetrace-hmi-0.2.0.1/ForceTrace.Hmi.had) · [本次证据与更新说明](../reviews/forcetrace-hmi-flicker-20260916.md)。已通过原生管理器安装到本地，完成 HMI 单独导出，待用户更新 IPC。兼容现有 PLC/对象 0.2.0.0；旧 ForceTrace rev2 完整包保留，本站独立选用记录只更新 HMI 补丁版本。导入时保留文件名 ForceTrace.Hmi.had，版本放在父目录名中。

**参考范围：**本通用命名修订没有新版最小 CpStudio 隔离模型；原生安装、参数/Channel、导出和保存重开验证来自实际 Station010。旧 Bpp rev3 包中的双实例 CpStudio 参考继续保留为历史，不作为本修订重新验证的模型。Danikor 包仍带自己的完整参考工程。

## 接口与使用入口

- [Burster2316](Burster2316.md)：自有通信 Peripheral，通过标准 IBursterResis2316 Channel 接原厂 Unit/HMI；同一驱动负责连接、选程、测量和清理，保留 Ω、首错和不重放测量的行为。
- [ForceTrace](ForceTrace.md)：PLC 负责采集、滚动统计和 v2 数据帧，CpStudio 通过七个变量选择参数接入，HMI 绑定四个整数组。统计 FB 可单独用于 PLC；页面显示与 CSV 使用 PLC 保留记录。
- [MachineCommon](MachineCommon.md)：按钮、主气压、维修门三个 PLC FB，加 CpStudio 生成外壳；应用负责原顺序调用与实际 I/O，压力模拟只作示例。
- Danikor：按包内 docs/MANUAL.md 安装，使用标准 NexeedIpDataStream Channel；1.1.0.0 接口和库字节保持原样。

[通用包安装](INSTALL-GENERIC.md) · [本站绑定、调用顺序与恢复点](STATION010-NATIVE-20260916.md) · [本站选用清单](../../config/station010-native-selection-20260916.json) · [现场待验项目](../../TODO.md)

当前组件发布清单使用 schema 3，包修订独立于 PLC 库版本。Station010 使用独立 native-selection 记录；旧 component-versions.json 是历史源码选用锁。通用包只能先安装到隔离 PrjExt，安装脚本不会修改本站或 Std。

## 当前验证与限制

- 三库、三个最小 PLC 消费工程及三个解包消费副本均新编译 0/0。文档修订包重新解包核验，首次分别复制 6、9、6 个自有 PrjExt 文件，重复安装复制数均为 0；旧 ZIP 哈希未变。
- 实际 Station010 经 Fast PLC export、HMI 单独 Export、保存关闭重开，Validate 为 0/2（原有 Burster 兼容性提示）；Build 0/4，最终 Generate code 0/5（4×OPC.UA.DA、1×ErrorCodes 枚举基型）。完整 PLC Export 的原厂 REST 流问题仍存在；Generate code 后的全量 datatype 审计曾报 duplicate-key，编译本身通过，已另用新 XML、受保护类型和原生 HMI 加载器核对。
- 实际安装 HMI DLL 与实际 SFC：原生加载器 0 errors、4 个 Item 编辑器、29 项帧/晚开/重连/密度/CSV 断言、2001 点对照通过；中英文离线预览已核验。
- Burster 的 18 项协议模型、ForceTrace 的 844 项数值检查及旧 BppMachineCommon 的 19 项 PLC 模拟执行属于历史算法/运行证据。本次未把这些记作新通用二进制的实体运行。Common 原始 typed-value 汇总错误及独立数值判定一起保留在包内 evidence/historical。
- 本站参数权限、20 个数据结构、IO 工程、StationData/TypeData 导出 DAT 和主界面保持；原生重载补入 1160 个原先为空的中文资源，未改已有非空翻译。此次文档收尾的实际模型与 PLE 文件哈希也未变。

未下载实体 PLC、未部署 IPC、未推送 GitHub。仍需现场核对活动 StationData、实际采样/任务负载、三位置两轮、晚开/重连、两种 CSV、HMI runtime 与 I/O 联锁；新最小 CpStudio 参考模型和团队工位移交验证另列待办。此前用户报告旧版现场正常，不作为本版验收。

## 校验与证据

[本站最终工程校验](../../data/station-native-integration/20260916/FINAL-VERIFICATION.json) · [解包消费新编译](../../data/native-packages/20260915/generic-20260916/unpacked-consumers-final.json) · [本修订解包/安装校验](../../data/station-native-integration/20260916/documentation-closeout/package-verification.json) · [文档收尾总校验](../../data/station-native-integration/20260916/documentation-closeout/CLOSEOUT-VERIFICATION.json)

| ZIP | SHA-256 |
| --- | --- |
| DanikorScrewer-Colleague-Handoff-1.1.0.0-local-rev3-20260915.zip | `E18E9D9B7A97C9C99421C5352AF77C3322A808739BADDB8E0491CC917995C854` |
| burster2316-0.1.0.2-local-rev5.zip | `0E1B3561C963DD1B15E0ED506C9490D291D3E0FFD1932540B0672FBAB1113895` |
| forcetrace-0.2.0.0-local-rev2.zip | `30764B0263FDAC41D4F4EF0297EDCEFEF829B6BC6B8F506A06D1F527503731A4` |
| machinecommon-0.1.0.0-local-rev2.zip | `03F580A6B0E5291FAC8FCAC10414F6E120E88CB2DAE801F081FE4652CE8FF606` |
