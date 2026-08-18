# TODO.md — 任务清单

> 完成即勾选;优先级 🔴 高 / 🟡 中 / 🟢 低。大项完成后把结论写进 docs/ 或 AGENTS.md。

## 当前阶段:阶段 0 项目初始化
- [ ] 🔴 解析 ../电阻测试台.pdf,整理工艺需求 → docs/requirements.md(验收标准:需求清单覆盖测量流程/IO/判定标准,并经用户确认)
- [ ] 🔴 create_project(templatePath=Standard.project) 建 src/ResistantStation.project,compile_project errors=0(验收标准:结构化错误为 0,警告基线记录在案)
- [ ] 🟡 应用架构设计:对齐 OpCon Station/Module/Command 层级 + SqM/SqS 状态机 → docs/architecture.md(验收标准:经用户确认)

## Backlog(以后再说)
- [ ] 🟢 HMI 界面(OpCon Modulo 或路线②自研)
- [ ] 🟢 测量数据记录(CSV/数据库)与追溯
- [ ] 🟢 对接 OpCon DataSetAccess / EventRecorder 接口
- [x] 🟢 硬件组态 IO 侧:按图纸页4核对树 + 删坏节点 _100A740_BL(2026-08-18,AI 经 scripts/ioe_ipc.ps1 驱动 IOE 完成;通道符号在 PLC 侧已存在)

## 已完成(近期)
- [x] 从 vibe-coding-templates 派生仓库骨架 + git init(2026-08-17)
- [x] 吸收 ctrlx-ai-coding 方法论;环境体检(CRLF 补丁/模板/库仓库)通过(2026-08-17)
## 补充(2026-08-18 夜 转接)
- [x] 🔴 清理 3 个非 ST 残留并编译到 0 errors：最终定位为 A1 的旧 I/O 映射，离线重映射后为 0 errors / 7 warnings(2026-08-18)
- [ ] 🟡 用户决定:是否在 CpStudio 删除 Wp100A740* 站(Engineering_Data.xml 残留,不删则重新生成会带回)
- [ ] 🟡 CpStudio 重新生成后 git diff 分析 → docs/cpstudio_generation_analysis.md
- [x] 🟡 建立 CpStudio→Git→MCP 协同规范 + 确定性 PLC 文本快照/校验工具(2026-08-18;`scripts/export_plc_snapshot.py`,`scripts/verify_plc_snapshot.ps1`)
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
- [ ] 🔴 真机专项验证操作按钮：确认 `FlashBits.Pulse500ms` 的现场闪烁观感、按下后步骤跳转，以及切换模式/CANCEL/ERROR/DONE 时 `_000P610` 必定熄灭；决定按钮在步骤激活前已被按住时是否允许立即完成
- [ ] 🔴 真机专项验证主气压时序：确认 `_000B085A_LOW/HIGH` 电气逻辑、5 s 阈值、故障下电及恢复流程；补充两个事件的中文文本，并决定是否新增独立的“高低压信号同时出现”事件
- [ ] 🟡 利用 CpStudio 5.11 官方 `Pre-export script` / `Post-export script` 钩子实现导出后自动审计：Git 差异、旧 Symbol 引用、PLC 编译与结果摘要；不直接改写 `Engineering_Data.xml`
- [ ] 🔴 后续配置并验证 Burster HostName，放行 `SetRange/StartMeas` 手动功能；设备稳定后逐条实现 Homing/Changeover/Auto Chains
- [x] 🔴 重载 Codex/VS Code 恢复 MCP transport；单一 persistent 调用链完成最小骨架快照和编译(2026-08-18)

## 已完成(近期)补充
- [x] Station010_0708 GitHub 私有备份 Stat_Resistant_Station010(基线+快照,本地已同步 origin/main)(2026-08-18)
