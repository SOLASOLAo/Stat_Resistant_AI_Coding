# Station010 组合 0.1.0-rc.4

本地开发候选，2026-09-11。根目录 `Verify.ps1 -PackageRoot .` 可在 Windows PowerShell 5.1 或 PowerShell 7、无 Git 的接收目录核对所有文件。校验完成不执行安装、PLC 写入或设备动作。

| 层 | 固定版本 | 交付边界 |
|---|---|---|
| Burster 2316 | 0.1.0-rc.2 | 单 TCP owner 自研驱动源码；独立原生库消费曾失败，无合格 `.library` / `.compiled-library` |
| Kistler 5867C | 0.1.0-rc.2 | 标准 EtherCAT 驱动集成说明、调用钩子；原厂驱动/Unit 不再分发 |
| Bpp.ForceTrace | 0.1.0-rc.2，DLL/HAD 0.1.0.2 | 原生控件、双语 Text、视图和 Frame v1 PLC 发布器；隐藏启动采集候选 |
| Station010 接入层 | **0.1.0-rc.4** | 最新单次电阻判定、左中右结果/HMI、换型清理、本站参数与验证证据 |

三个核心包逐字节复用冻结 rc.2。本次只升级工位接入层，不覆盖此前 rc.1、rc.2 包或 ZIP。组件包内旧的 Station rc.2 参考说明保留历史状态；**当前工位行为和工程身份以本说明、`Station010-reference/reference.json`、组合锁及 BUILD-EVIDENCE 为准**。

rc.3 首次增加工位层后，Windows PowerShell 5 接收校验暴露 NLS/ICU 文档路径排序差异。rc.4 的组合 Verify 沿用既有校验模板，只去掉再次排序，按清单已固定的顺序计算摘要；路径、重复、大小、逐文件哈希、总摘要与额外文件检查全部保留。构建器同时运行 PowerShell 7 与 Windows PowerShell 5 接收校验。rc.3 原样保留作失败验收记录，不交付为通过版本；核心三个 rc.2 包与 DLL 内容均未变。

## 最新电阻判定与 HMI

每个位置复用 `SqS_Wp100_Run`。N080 在开始本次 SINGLE_MEAS 前复制活动 TypeData 的 LowerLimit/UpperLimit 到该命令 ParCmd；N090 在命令成功完成且结果尚未 Valid 时锁存原始电阻、温度与量程标志，并判定：

```text
Ok = NOT OutOfLimit AND LowerLimit <= Resistance.Value <= UpperLimit
```

值与两限统一为 **Ω**，等于任一边界算 OK。OutOfLimit 是仪表量程故障，不替代上下限比较。Unit/通讯故障、未完成或力门禁失败不产生新的合格电阻结果。每次只捕获一次，单步停留不因配方变化重判；新周期清空，父链分别保留左、中、右结果。该修改不增加整件总判定或 NOK 停机/重测策略。

UserDefined 的三个状态文字和颜色只绑定 `_HmiResistanceLeftOk`、`_HmiResistanceMiddleOk`、`_HmiResistanceRightOk`，可见性由各自 Valid 控制。OnCall 的来源是对应 `Resistance.Valid AND Resistance.Ok`。**Kistler Unit 的 OK/NOK 不参与这三个电阻状态**；Kistler 力采集和既有力门禁保留。

数值显示仍为 **mΩ = 原始 Ω × 1000**；不要用显示舍入值重算 OK/NOK。TypeData 界面上下限已标 Ω；活动配方的实际数值及真机边界验收仍待现场确认，导出模板默认 0 不是活动配方证据。

## 接口、状态和归属

- `Station010-reference/src/plc/project/Station010/` 是本站调用参考及验收快照。BMK、事件号、2500 N、气缸/门反馈和程序号策略由 Station010 工艺拥有，不能直接成为通用组件默认参数。
- CpStudio 继续拥有模型、Unit、变量/类型、生成声明和 SFC 图；自有 ST 仅按归属合并实现。包内声明是核对合同，不授权覆盖 CpStudio 接口。
- Burster 通用能力、0..15 程序范围、Ω/温度、单 owner 生命周期、错误与取消见其组件 README；本站调用先完成选择/readback，再下发标准 SINGLE_MEAS。错误保持，不自动重试未知结果。
- Kistler 保留标准 maXYmos 驱动与 Unit；力为 N，Ready/Alarm/ExecState 与程序确认门禁仍在原链中。生产 MP001 及 Active 0/1 是本站观察，固件未知，不能推广为所有设备约定。
- ForceTrace Frame v1 为 14 DWORD；PLC 毫秒计时，曲线/CSV 横轴秒，纵轴 N；100 ms 采样，500 ms 无新帧标陈旧，250 ms 缺口不连线。每位置最多 6000 样本。详细数据/状态/错误契约及通用模板见 ForceTrace 组件说明。
- 换型 `_aN010_active` 允许空请求或本链已有请求；reset/finish 只释放本链拥有的画面/对话框请求，保留其他请求。三个实现及 10 项离线条件/清理用例随包提供。

## 双语资源与原生视图

自有 18 项 ForceTrace Text 在其组件包中；本站额外 6 项电阻 Text 的规范位于 `Station010-reference/specs/hmi/resistance_texts.json`，原生导入片段为 `Station010-reference/native/ResistanceTexts.cpsds`。片段已按这 6 项逐一核对英文/中文值，含原生表结构，无整站语言库/连接凭据。

复用时在 CpStudio 选择目标模型的 Text 位置再通过原生导入；核对名称、GUID 冲突和父对象，已有同名项在原项上更新，不能重复追加。本站模式和菜单的 10 个中文增量在 `menu-texts.json`，其 GUID 属于 Station010；新工位应按语义映射自己的模式/视图后填写语言行。用户展示的模式 Description 底部 English/Chinese 编辑区同样适用，不直接改导出语言文件充当模型源。

`native/UserDefined.sfc` 保留本站有效绑定与布局，供原厂加载器/CpStudio 核对。它依赖本站 9 个 HMIResistance 只读成员；其他工位先建接口、映射 Item/TextGroup，再导出视图。

## 依赖与证据

站内核验环境为 CpStudio V5.11、ctrlX PLC **2.6.8**。实际库依赖锁见核心包 component.json 及 `specs/hmi/station_component_dependencies.json`：Kistler Peripheral 2.0.1.0、Unit 1.2.2.0、Base 1.2.1.0；它们不是 CpStudio 对象描述版本。ForceTrace 要求既有 VisiWinNET 6.5 / OpCon Modulo 5.11 / TeeChart 运行时，具体程序集版本和哈希见其包，原厂文件需自行合法安装。

Station PLC SHA 为 `1762C81B21D37EE994568E3134BF7ECF3F023BCBC3B4CF3FD957A9A8B81C6F81`，Symbol SHA 为 `9FFCAB1160993733A711D6C18BC978E4B7541C33F19E3D5263CF751ADFDBC9D6`。17:51:02 的实际 F11 为 **0 errors / 5 原有 warnings**，并有 N090 保存/41 目标回读证据。本轮仅把完全相同的工程字节与该证据关联，**没有重新编译在线 PLE**。CpStudio 模型和 TypeData 导出在 18:01 又保存过，哈希已不同；本轮记录其最新身份，不把旧编译结论扩展到后续模型变化。UserDefined 绑定、PLC 和 Symbol 字节仍与各自已核验证据一致。

本次包内 .2 DLL 已用原厂加载器与合成帧再次验证：先记录三位置后开页/重开页、121 点图形/CSV 对齐、48 项双语资源与 36 项动态文字通过；运行时语言管理器、OPC 真机时序及现场自动未在这些测试中启动。另含每次电阻 12 项边界/量程/NaN 检查、力门禁、Kistler 生命周期及换型检查。

Burster 原生库此前独立 consumer fresh Build 未通过，错误首先涉及库引用 qualified-only 和 ctrlX 占位符解析；失败二进制不交付。当前 CpStudio 的 PLE 已在线，本任务不退出/接管它，也不启动第二个 profile writer。续做需要空闲独立离线库会话，先解决引用可见性与平台依赖，再 fresh consumer Build，通过后才能形成新原生库候选。源码合同/本站 F11 都不能替代该证据。

参考 Danikor 仓库的源码、库、BUILD-EVIDENCE 与 ARTIFACT-MANIFEST 关联方法，未复制其实现。只读本地分支 `agent/danikor-mvp-protocol-simulator` 的 HEAD 为 `ec0866805fb4b499863e4c7f279fb3f90182c552`；该分支 GitHub 上的 Build-DanikorIntegrationKit.ps1 blob 与本地均为 `a7e3db8ba2d23f81ffbc712fd5fad099b02afa95`。不把它的旧原生库归到当前 HEAD，也不宣称已核对远端 HEAD。

## 安装、升级与回滚

1. 先校验组合和三组件清单，再核对目标站依赖/接口/实际设备固件。这里只提供开发候选，未发布 Git tag/Release；唯一可编辑源仍在 McpCoding，包目录只作不可编辑快照。
2. PLC 合并按 CpStudio/PLE 所有权执行。包内 Station REST 脚本是带工程/离线/计划哈希门禁的本站参考，不在安装/校验时执行；新工位不能直接调用。先生成目标接口、审阅差异、离线保存与 fresh Build，再走另行授权的下载验收。
3. 晚开曲线修复必须同时使用 `.2` HAD/DLL 和 `Station010-reference/startup-overlay` 的隐藏 SmartForm 启动项。先原生注册自有 HMI add-on、HMI Export，再以目标最新 Gui.config 重新生成 overlay 并审阅差异。不能把原 SmartControl 的 loadOnStartup 改为 True，单换 DLL 也不足。本站 Frame v1 发布器无需为此修复变化。
4. 校验 Text、三状态绑定及中文模式后，再另行授权部署 IPC。先运行 HMI，保持未开曲线页，现场再执行左中右测量、开页/重开、下一周期、取消/断线、zh→en→zh、CSV 保存及电阻边界验收。
5. 回滚保存的完整 HMI 组合和精确 PLC 源/依赖版本。退回 .1 时同时移除 .2 隐藏启动项；它不识别新启动类。不要在线热换 DLL、PLC Socket 或删历史 CSV。老 rc.2 的 Station 引用早于显式电阻判定，回退需重新评估质量要求。

当前候选 **未安装/部署 .2，未下载 PLC、触发动作、FORCE 或上传 GitHub**。此前本机/IPC 观察仍为 .1，现场若尚未升级，依旧需要先开曲线页。组合可交付为本地开发候选，不能标成正式原生 PLC 库或现场合格版本。
