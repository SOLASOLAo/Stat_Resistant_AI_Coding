# TODO.md — 任务清单

> 完成即勾选;优先级 🔴 高 / 🟡 中 / 🟢 低。大项完成后把结论写进 docs/ 或 AGENTS.md。

## 当前阶段:阶段 0 项目初始化
- [ ] 🔴 解析 ../电阻测试台.pdf,整理工艺需求 → docs/requirements.md(验收标准:需求清单覆盖测量流程/IO/判定标准,并经用户确认)
- [x] 🔴 使用 `../Station010_0708` 作为 CpStudio + MCP 受控集成工程，不再另建 `src/ResistantStation.project`；当前离线基线 0 errors / 7 warnings(2026-08-18)
- [ ] 🟡 应用架构设计:对齐 OpCon Station/Module/Command 层级 + SqM/SqS 状态机 → docs/architecture.md(验收标准:经用户确认)

## Backlog(以后再说)
- [ ] 🟢 HMI 界面(OpCon Modulo 或路线②自研)
- [ ] 🟢 测量数据记录(CSV/数据库)与追溯
- [ ] 🟢 对接 OpCon DataSetAccess / EventRecorder 接口
- [x] 🟢 硬件组态 IO 侧:按图纸页4核对树 + 删坏节点 _100A740_BL(2026-08-18,AI 经 `scripts/ioe/ioe_ipc.ps1` 驱动 IOE 完成;通道符号在 PLC 侧已存在)

## 已完成(近期)
- [x] 从 vibe-coding-templates 派生仓库骨架 + git init(2026-08-17)
- [x] 吸收 ctrlx-ai-coding 方法论;环境体检(CRLF 补丁/模板/库仓库)通过(2026-08-17)
- [x] 🔴 修复 persistent MCP 编译完成后超时：去除重复 Build 和全类别×严重级别消息扫描，统一使用有界 Build summary 读取；Station010 实测编译约 7.6 s、缓存读取约 0.8 s，0 errors / 7 warnings(2026-08-20)
## 补充(2026-08-18 夜 转接)
- [x] 🔴 清理 3 个非 ST 残留并编译到 0 errors：最终定位为 A1 的旧 I/O 映射，离线重映射后为 0 errors / 7 warnings(2026-08-18)
- [ ] 🟡 用户决定:是否在 CpStudio 删除 Wp100A740* 站(Engineering_Data.xml 残留,不删则重新生成会带回)
- [ ] 🟡 CpStudio 重新生成后 git diff 分析 → docs/cpstudio_generation_analysis.md
- [x] 🟡 建立 CpStudio→Git→MCP 协同规范 + 确定性 PLC 文本快照/校验工具(2026-08-18;`scripts/plc/export_plc_snapshot.py`,`scripts/plc/verify_plc_snapshot.ps1`)
- [x] 🔴 建立可跨项目复制的目录标准：`config/specs/ai/src/catalog/scripts/tests/data/docs`，录入 Station010 当前规格、AI 归属、通用 FB 源码和已验证 Unit Catalog；加入结构冒烟测试与自定义 Post-export 信号脚本(2026-08-18)
- [x] 🟡 建立团队工作站交接：新增 `TEAM_SETUP.md`、无个人账号的 Codex MCP 配置样例和只读环境体检脚本，区分长期部署说明与会话型 HANDOVER(2026-08-19)
- [x] 🟢 新增离线 AI Coding 展示页：覆盖 CpStudio/AI/ctrlX 分工、标准目录、两类开发闭环、对象归属、Home Chain、主气压联锁、BMK 改名复盘和验收证据；支持交互演示与打印 PDF(2026-08-19)
- [ ] 🟡 在 CpStudio 工程中配置官方 Post-export hook 指向 `scripts/cpstudio/post_export_signal.bat`，完成一次真实导出信号验证
- [ ] 🟡 实现 export request 消费器：diff → 快照 → ownership/hooks/graphical 审计 → I/O/Symbol 审计 → 编译 → 报告；保持唯一 persistent MCP 会话
- [x] 🔴 最小骨架只读基线:删除 Wp100 下全部 5 个 Unit 已获确认;导出 215 个文本对象并记录编译 66 errors/40 warnings(2026-08-18)
- [x] 🔴 PLC 写入落点决策:用户授权 `../Station010_0708` 作为 CpStudio + MCP 受控集成工作工程(2026-08-18)
- [x] 🔴 经 MCP 清理最小骨架的 10 个旧 ST 对象，编译由 66 errors 降到 3 errors(2026-08-18)
- [x] 🔴 Symbol/I/O 联合审计完成：用户清理 25 个失效 Symbol 签名；AI 修正 A1 三条旧映射并编译到 0 errors(2026-08-18)
- [x] 🔴 CpStudio I/O BMK 改名批次：修正 16 个有效映射、清空 17 个停用映射；经 PLE REST Symbol Configuration 接口同步 18 个新名/清零 33 个旧名，编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 提交并推送 Station010 已验证的 I/O BMK 改名批次（15 个生成/工程文件，`78f91e8`）
- [x] 🔴 CpStudio C1 小改动快速闭环：清除 `Channel_6.Output` 旧映射 + REST `UnSelect` 旧 Symbol，编译恢复 0 errors / 7 warnings；Station010 `482c77a`，方法论补丁 `142721c`(2026-08-18)
- [ ] 🔴 受控增量实验:每次只添加 1 个设备并完成生成→Git diff→ST 快照→编译→提交;设备稳定后再逐条添加自动 Chains
- [x] 🔴 BasMove 受控增量：依次加入 `Wp100K101SafetyDoor` 与 `Wp100K102PressingCylinder`，核对 2I2O、层级和快照边界；安全门手动放行并绑定 `Wp100.IsInHomePosition`，编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 压缸手动联锁：安全门 `IsInWrkPos` 后才允许压缸两个手动动作；Wp100 Home 同时要求安全门和压缸 `IsInBasPos`(2026-08-18)
- [x] 🔴 Burster 2316 受控增量：加入 `Wp100K103ResistantDetector` + `_Wp100K103ResistantInterface`，核对 Unit/Peripheral/StationData HostName 绑定并编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 EmergencySwitch 受控增量：两路急停绑定 `_000S900A/_000S900B`，Control Off 绑定 `_000S902`；核对 AddOn 参数、HMI 与物理通道并编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 主气压控制 FB：新增可跨项目复用的 `Application/Fbs/FB_MainPressureControl`，由 `StationUnit.OnCall` 周期调用；联动 `ControlOn.OutImm.IsCtrlOn`、`ControlOn.ParImm.UserEnableControlOn`、`_000K085A` 和两路压力反馈，5 s 超时/互斥诊断后编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 操作按钮 FB：新增可复用 `Application/Fbs/FB_OperatorButton`，以 `Execute` 管理初始化/执行生命周期；接入 `SqS_Wp100_Home` 的 `_000S610/_000P610` 步骤，并在 `OnChainFinish` 强制复位，编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 SubChain 受控增量：CpStudio 新增 `Wp100.SqS_Run : SqS_Wp100_Run`，核对实例、SubChain ID=2、rUnit 引用、状态概览及 5 个新增 PLC 对象，基线编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 Burster 手动放行：`Wp100K103ResistantDetector` 的 `SetRange/StartMeas` 均改为 `CommonManRelease AND TRUE`，AI 前后快照仅改变 `OnManRelease`，编译 0 errors / 7 warnings(2026-08-18)
- [x] 🔴 CpStudio 参数/描述改动快速闭环：核对 4 条安全回路英文描述、停用 `_000K980D`、StationData 公开字段变化；Symbol Configuration 无旧成员，既有 AI 代码未被覆盖，编译 0 errors / 7 warnings；Station010 `7c4422e`(2026-08-18)
- [x] 🔴 Wp100 Home 原子操作：`SqS_Wp100_Home` 实现拍按钮后按状态跳过/执行“安全门到工作位 → 压缸回原位 → 安全门回原位”，并在 `OnChainFinish` 复位按钮灯、两个 Unit Execute 与本轮标记；编译 0 errors / 7 warnings，Station010 `bb853e5`(2026-08-18)
- [x] 🔴 维修门—主气压联锁：新增通用 `FB_MaintenanceDoorControl`，由 `_000S901`/ControlOn 状态驱动 `_000K980/_000K981`，仅在 `_000K980_A AND _000K981_B` 时向 `FB_MainPressureControl.xValveRelease` 放行；原门锁 dummy 条件同步改为真实反馈，Station010 `bb853e5`(2026-08-18)
- [x] 🔴 维修门未锁报警：使用 CpStudio 生成的 `EVENT_MAINTENANCE_DOOR_NOT_LOAKED=-2`；门锁请求后 5 s 内 A/B 反馈未同时到位则锁存报警并保持主气压禁止，Control Off 后按 `UnlockEvent + ClearEvent` 清除；编译 0 errors / 7 warnings，Station010 `93379fd`(2026-08-18)
- [x] 🔴 StationLamp AddOn 受控增量：CpStudio 新增 Station Lamp V2.3.1.0（InstanceId 7），黄/绿/红绑定 `_000P960_1/_000P960_2/_000P960_3`，层级、参数、HMI 和输出映射核对完成(2026-08-18)
- [x] 🔴 Home Chain 步骤检索注释：经 PLC Engineering 官方 REST 扩展接口为 `SqS_Wp100_Home` 的 9 个 Step 写入简短 Comment；标准化差异确认 Action/Transition/顺序均未改变，编译 0 errors / 7 warnings，Station010 `6399377`(2026-08-18)
- [x] 🔴 实现 `SqS_Wp100_Run` 首个可复用原子工艺：位置改为正式 `VAR_INPUT MeasurePos`，三位置 DI 一取一联锁，拍按钮，关门/安全反馈；下压+Kistler 启动及抬压+Kistler 结束均为可诊断的 SFC 同步分支，按 OpCon 约定分别使用 `_retVal/_retVal2`，结构化保存结果并统一处理 DONE/ERROR/CANCEL；离线编译 0 errors / 6 warnings，Additional code checks 0 errors(2026-08-20)
- [x] 🔴 `SqC_Wp100_Run` 顺序调用原子操作：LEFT→MIDDLE→RIGHT，每轮仅在 READY 写 `Wp100.SqS_Run.MeasurePos` 并以 `CheckSubChainDone` 等待；每轮开始前检查 `_100B701 AND _100B702`，缺失时用 `EVENT_PART_DETECT_SENSOR` 和具体 BMK AdditionalInfo 阻塞提示；三位置结果分别保留，编译 0 errors / 6 warnings(2026-08-20)
- [x] 🟡 统一 AI-owned PLC ST 条件排版：独立条件加括号且括号内侧留空格，换行 `AND`/`OR` 放上一行末尾；静态门禁、REST 哈希迁移、幂等回读及 Application Build 0 errors / 8 warnings 完成(2026-08-20)
- [ ] 🔴 确认产品参数来源：把 Burster 上下限/温度开关与 Kistler 程序号从当前 Unit 参数正式接入 TypeData；补充范围校验和产品切换验收
- [ ] 🟡 若追溯要求保存 Kistler 完整曲线，另行设计 `READ_DATA` 分页读取与数据记录；当前 `Result.Kistler` 保存 OK/NOK、NoPass、程序号及压缸上升前锁存的循环力/位移
- [x] 🟡 CpStudio 模型中的 Burster `SetRange/StartMeas` 对象级手动放行已设为 TRUE，本次导出已同步 HMI 条件树(2026-08-18)
- [ ] 🟡 补充 `SqS_Run` 当前为空的中英文显示文本
- [x] 🟡 StationData 的 `LineNo`、`TestMode`、`NokCounter`、`Wp100.Active` 已经本次 CpStudio 导出从 PLC 主结构与数据检查中正式移除；生成后编译正常(2026-08-18)
- [ ] 🟡 决定是否删除当前仅剩自声明、无任何业务引用的 `StationSdNokCounter` 与 `Wp100StationDataStruct` DUT；在 CpStudio 不再生成它们前先保留
- [ ] 🔴 真机专项验证操作按钮：确认 `FlashBits.Pulse500ms` 的现场闪烁观感、按下后步骤跳转，以及切换模式/CANCEL/ERROR/DONE 时 `_000P610` 必定熄灭；决定按钮在步骤激活前已被按住时是否允许立即完成
- [ ] 🔴 真机专项验证主气压时序：确认 `_000B085A_LOW/HIGH` 电气逻辑、5 s 阈值、故障下电及恢复流程；补充两个事件的中文文本，并决定是否新增独立的“高低压信号同时出现”事件
- [ ] 🔴 真机专项验证 Home 原子操作：覆盖压缸已/未在原位、安全门已/未在原位四种分支，确认 `_000S610/_000P610`、WRKPOS/BASPOS 顺序、Unit 超时/报错和模式切换 CANCEL 后所有输出复位
- [ ] 🔴 真机专项验证 Run 原子操作：覆盖 LEFT/MIDDLE/RIGHT 一取一联锁、按钮、门/压缸动作、安全反馈、PressDelayTime、Burster/Kistler 时序、测量失败及 CANCEL 后输出复位；真机操作前另行确认下载与运行授权
- [ ] 🔴 真机专项验证维修门联锁：确认按 `_000S901` 后 `_000K980/_000K981` 上电并由 ControlOn 状态保持；任一 `_000K980_A/_000K981_B` 缺失时 `_000K085A` 立即不上电，持续 5 s 后触发 `EVENT_MAINTENANCE_DOOR_NOT_LOAKED`，Control Off 后报警正确清除；同时验证模式不放行及故障恢复
- [ ] 🟡 利用 CpStudio 5.11 官方 `Pre-export script` / `Post-export script` 钩子实现导出后自动审计：Git 差异、旧 Symbol 引用、PLC 编译与结果摘要；不直接改写 `Engineering_Data.xml`
- [ ] 🔴 后续配置并验证 Burster HostName，放行 `SetRange/StartMeas` 手动功能；设备稳定后逐条实现 Homing/Changeover/Auto Chains
- [x] 🔴 重载 Codex/VS Code 恢复 MCP transport；单一 persistent 调用链完成最小骨架快照和编译(2026-08-18)

## 已完成(近期)补充
- [x] Station010_0708 GitHub 私有备份 Stat_Resistant_Station010(基线+快照,本地已同步 origin/main)(2026-08-18)
- [x] 🔴 Kistler 5867C EtherCAT ESI 仓库闭环：经 IOE 官方 ScriptEngine 导入新 ESI，精确回读 `58A_0000E52F00000001 / Revision=1`；新增幂等安装脚本、Catalog、规格与同事部署检查(2026-08-19)
- [x] 🔴 在 IOE 受控工程中添加 Kistler `_100A104`：位于 `_000SA620_X1` 下并与 EK1100 同级，保存后重开精确回读 `58A_0000E52F00000001 / Revision=1`(2026-08-19)
- [x] 🔴 CpStudio 一键读取 ctrlX IDE EtherCAT IO 组态：`_100A104` 已自动匹配旧标题 `Kistler MaXYmos BL5867B TL5877B0`；Peripheral 已成功生成到 PLC/HMI(2026-08-19)
- [x] 🔴 Kistler Peripheral 导出闭环：修复同批 Burster BMK 改名的 PLC/Symbol 双层旧引用；经 IOE EtherCAT 离线导出 + PLE `keepExisting` 导入同步从站，400 个 PDO byte 全部映射且回读零差异；PLC 快照 234 objects，离线编译 0 errors / 7 warnings(2026-08-19)
- [x] 🔴 在 CpStudio 添加 `NexeedKistlerForceStroke` Unit，放到 `Wp100` 下并把 `IKistlerForceStroke` Channel 绑定到 `_100A104` Peripheral；PLC 侧 8 个手动功能均为 `CommonManRelease AND TRUE`，400/400 PDO 映射零差异，离线编译 0 errors / 7 warnings(2026-08-19)
- [x] 🔴 CpStudio 模型中 `Wp100A104Kistler` 的 8 个对象级手动条件已改为 `TRUE` 并重新导出；HMI 回读 8 个 TRUE、0 个 FALSE，与 PLC OnManRelease 一致(2026-08-19)
- [x] 🔴 维修门/安全回路反馈闭环：维修门 A/B 缺失与 `_000K981_Y32` 1 s 超时共用 `EVENT_MAINTENANCE_DOOR_NOT_LOAKED` 并写入具体 BMK AdditionalInfo；安全门、压缸手动与 Home 关门步骤加入 `_000K981_Y32/_000K913_Y32/_000K912_Y32` 联锁；四种 Mode Release 加入急停和维修门继电器反馈，离线编译 0 errors / 7 warnings(2026-08-19)
- [ ] 🔴 真机专项验证维修门安全继电器：两门关闭后 `_000K981_Y32` 应在 1 s 内成立；分别断开 A 门、B 门和继电器反馈，核对 AdditionalInfo BMK、主气压禁止、模式释放与 Control Off 恢复流程
