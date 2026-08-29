# TODO.md — 任务清单

> 完成即勾选;优先级 🔴 高 / 🟡 中 / 🟢 低。大项完成后把结论写进 docs/ 或 AGENTS.md。

## 当前阶段：Phase 2/3 离线实现已完成，等待现场验收

### 四阶段总进度（给项目成员看的简版）

- [x] **Phase 1 · 稳定受控 Runner（开发基线完成）**：P1.1、P1.2、正式 Station010 基线、P1.3c 和 P1.4a 精简团队离线包已完成；AtLogOn Bootstrap 延期到商业化/无人值守部署阶段，不阻塞开发
- [x] **Phase 2 · 项目目录与流程生成（离线实现完成）**：Project Pack、Schema、初始化器、流程事实源、确定性工程计划和 Runner 漂移门禁已完成（2026-08-29）
- [x] **Phase 3 · HMI 产品化（离线产品基线完成）**：同一 Windows HMI 已由完整 JSON 配置驱动；Station010 与独立 ExampleCell 均通过编译、配置和 UI 冒烟（2026-08-29）
- [ ] **Phase 4 · 商业交付（未开始）**：安装、许可、升级回滚、诊断包、DemoStation、交付与合规；前三阶段稳定后再做

详细范围和验收标准见 `docs/productization_roadmap.md`；这里保持短清单，后续每完成一个里程碑直接更新状态。

- [x] 🔴 Phase 2 Project Pack：`project-pack.json` 汇总 Station/I/O/Event/Unit/Process/HMI/Catalog/ownership 事实源；PowerShell 7 Build/Check 生成内容寻址的 `generated/engineering-plan.json`，Runner 在执行前拒绝缺失、draft 或漂移计划（2026-08-29）
- [x] 🔴 Phase 2 Station010 流程：`SqC_Wp100_Run` + `SqS_Wp100_Run` 共 35 个步骤、14 条双语提示、13 条需求和 9 个验收用例；所有生成 POU 接口仍归 CpStudio（2026-08-29）
- [x] 🔴 Phase 3 配置驱动 HMI：品牌、Overview、Manual Unit/动作/字段、模式 Chain、EtherCAT role/device-data group 全部进入 schema v2 配置；新增不含 Station010/Wp100/Kistler/Burster 名称的 ExampleCell 配置（2026-08-29）
- [ ] 🔴 Phase 3 现场验收：在用户单独批准真机操作后，与 Nexeed HMI 做只读与模式请求 A/B；Station/Manual/参数写入继续保持锁定，不能用离线 UI 冒烟代替现场结论

- [x] 🔴 固化四阶段产品路线：Runner → 项目目录与流程生成 → HMI 产品化 → 商业交付；唯一产品计划见 `docs/productization_roadmap.md`（2026-08-27）
- [x] 🔴 P1.1 Runner 控制面：统一 CLI、OS 级单 owner 租约、项目/profile/manifest 预检、Stage 1/Stage 2 编排和结构化 run manifest（2026-08-27）
- [x] 🔴 P1.2a Action Client：.NET 8 Core/CLI、action/hash/fingerprint 门禁、client/action 双租约、幂等终态、Named Pipe v1、NoSession 失败关闭和 evidence 封口；本客户端不启动 PLE/MCP（2026-08-27）
- [x] 🔴 P1.2b Broker 基础：显式 interactive Broker、单 owner、current-user registration/Named Pipe v2、typed action allowlist、durable submit/query、幂等/崩溃恢复、external PLE 不关闭；纯 fake-MCP 离线回归通过（2026-08-27）
- [x] 🔴 P1.2b 真实 PLE 技术通道：本机受控 adapter 已应用并通过 `-Check`；Station010 immutable action 完成 same-call 普通 Build（0 errors / 101 条可见 warnings）、typed warning、多重 ownership/readback/Git 基线证据、456 条 mapping facts 与 Symbol 指纹采集，工程及结构哈希不变，无在线动作（2026-08-28）
- [x] 🔴 P1.2b 提交前失败关闭加固：截断 warning 全链路阻断、一次明确用户确认且不采集姓名/工号、同字节有界 hash/parse、畸形请求脱敏、敏感值/预算扫描、semantic 最终 dirty probe、REST 全程超时/8 MiB 流式上限，以及 patch 语法失败回滚均完成离线回归（2026-08-28）
- [x] 🔴 P1.2b 隔离 REST 门禁：同 SHA 隔离副本已通过官方 REST 完成 `maxCompilerWarnings: 100 → <no limit> → 100` 的 GET/PUT/readback/回滚验证，`.project` 字节未变；确认 REST PUT 即使回滚也会令 PLE 内存工程变脏，因此必须关闭不保存并重开，不能直接交给 Build（2026-08-28）
- [x] 🔴 P1.2b 显式 Clean Build 工具：新增并安装 `clean_compile_project`，契约固定为恰好一次 `application.clean()` + 一次 `application.build()`，禁止 save/clean_all/generate_code；隔离安装、语法、失败回滚和 typed-warning 回归通过（2026-08-28）
- [x] 🔴 P1.2b 告警完整性实测：扩展重启后只在可丢弃隔离副本持久化 `<no limit>`，关闭重开并连续两次显式 Clean Build；两次均为 0 errors / 4 条完全一致的 `OPC.UA.DA` warning，无截断 sentinel，工程身份/dirty/SHA 门禁全通过，Station010 源工程 SHA 未变且没有在线操作（2026-08-28）
- [x] 🔴 P1.2b Clean Build 执行闭环：Broker/evidence 已改为受控调用 `clean_compile_project`，相关离线测试已统一在 PowerShell 7 下通过；本项只证明执行与证据合同，不代表已创建新的正式 immutable action/candidate（2026-08-28）
- [x] 🔴 P1.2b 正式基线验收：request `839ff68c-6ac8-4764-8258-7cef4aa10406` 的全新 immutable action 已在真实 PLE 离线闭环中完成；Clean Build 0 errors / 4 warnings，456 mapping、Symbol 与正式 baseline 全部匹配。Build 前本机内容寻址 checkpoint 已创建并回读同 SHA，工程/结构哈希前后不变，无在线操作（2026-08-28）
- [x] 🟡 P1.3a current-user interactive Host：单实例、心跳/状态、受控停止、限定日志保留和可选 AtLogOn Scheduled Task；本机已完成真实 Install/Start/重复 Start/Status/Logs/Stop/再次 Start 验收，不启动 Broker/MCP/PLE/Node/在线操作；P1.3b 下仅在存在待处理 action 且无同会话 Agent 时保持 `WAITING_FOR_AGENT`（2026-08-28）
- [x] 🟡 P1.3b 自动 action 消费：Host 只消费首次激活后由 operation ledger 指向的 immutable `currentAction`；无 Agent 等待、单 action 执行、历史终态隔离、open claim 恢复、结果保持 `WAITING_FOR_COORDINATOR`；本机 Install/Start/Stop/Restart 验收后为 `WAITING_FOR_ACTION`，后台任务已改用无控制台 apphost，不再弹空白终端；5 个历史终态隔离且既有 22 个 claim/result 标记不变，全程未启动 Broker/MCP/PLE/Node/在线操作（2026-08-28）
- [x] 🟡 P1.3c result/evidence coordinator：验证 result/evidence SHA、immutable action 与 ledger 后自动推进；合法 `UNKNOWN`/`FAILED` 无 evidence 保持人工复核，busy 有界退避，畸形 ledger 失败关闭；production ingestor 默认装配 6 项 fixture E2E 和真实 ledger lock busy 均通过（2026-08-28）
- [x] 🟡 P1.3c durable 稳定部署：`LocalAppData` 下 5 文件内容寻址不可变 release、pending journal/reconcile、幂等 Install/升级、Rollback 和失败升级恢复已实现；AtLogOn action 精确指向 release exe，description 记录 release/manifest。显式生命周期命令校验 5 个文件和 self-check，登录任务本身不做 prelaunch manifest 校验（2026-08-28）
- [x] 🟡 P1.3c 本机生命周期：源任务禁用/已删除、`STATE_COMMITTED`、强杀后默认 `Start` 恢复、新 release 升级、同版本 no-op、回滚、损坏候选拒绝，以及 deployment 丢失时基于精确任务的安全 `Uninstall` 均通过；主 Host active `faa27c...0f1`、previous `ac89b...4b51`、状态 `WAITING_FOR_ACTION`（2026-08-28）
- [x] 🟡 P1.3c 技术实现与本机验收完成；Host 未启动 Broker/MCP/PLE/Node 或任何在线操作（2026-08-28）
- [x] 🟡 P1.4a 精简团队离线包：固定封装安装入口、canonical wrapper/module、包 manifest 与 Host 五文件；接收工位无需 Git/源码/SDK/build，支持完整性校验、首装/升级、精确回滚、安全卸载与状态查询；fresh Install 默认停止，升级保留原运行状态（2026-08-29）
- [ ] 🟢 P1.4b（延期，不阻塞开发）独立 AtLogOn prelaunch Bootstrap：仅在进入商业化或明确需要无人值守登录自启时实施；开发期继续显式启动 Host
- [ ] 🟢 P1.4c（有团队工位时执行）团队验收：固化最小兼容矩阵，在一台全新同事电脑完成包传递、安装、显式启动、升级、回滚、卸载和诊断复验；默认不自定义 ACL，签名按商业/IT 要求延期

## 项目工程待办
- [ ] 🔴 解析 ../电阻测试台.pdf,整理工艺需求 → docs/requirements.md(验收标准:需求清单覆盖测量流程/IO/判定标准,并经用户确认)
- [x] 🔴 使用 `../Station010` 作为 CpStudio + MCP 受控集成工程，不再另建 `src/ResistantStation.project`；2026-08-28 已证明同一 `.project` 字节在原路径普通 Build 为 101 条可见 warnings、隔离路径普通 Build 为 4 条 warnings，二者都不是正式语义基线；正式基线必须来自显式 Clean Build
- [ ] 🟡 应用架构设计:对齐 OpCon Station/Module/Command 层级 + SqM/SqS 状态机 → docs/architecture.md(验收标准:经用户确认)

## Backlog(以后再说)
- [x] 🟢 自研 HMI Phase 1/1.1 离线实现：.NET 8 WPF + 官方 OPC UA Client；133 个只读 Symbol 节点，PublicEventList、9-Slave EtherCAT 拓扑、38 个命名 DI/DO、Kistler 语义值、StationData/TypeData 分页、keepalive 自动重连与 3 s 会话健康超时遮罩；Release Build 0 errors / 0 warnings，离线 UI smoke 通过（2026-08-25）
- [x] 🟢 自研 HMI Phase 1.2 操作界面：增加 Auto/Home/Change-over Chain 启停、Auto 步进/下一步、Station/Wp100 Unit 与 16 个单动功能、真实 Release/Running 状态，以及 Master→EK1100→EL/Kistler 分层 EtherCAT 拓扑；所有新控制仅在 DEMO 可执行，真机写入保持锁定（2026-08-25）
- [x] 🟢 自研 HMI Phase 1.3 Unit 详情：按 Nexeed SmartForms 补齐 Burster 5 个输入参数 + 4 个状态/结果，以及 Kistler 3 个输入参数 + 9 个状态 + 3 个结果；150 个只读 Symbol 路径校验、Release Build 和离线 Unit 切换 UI smoke 均通过，真机参数写入仍保持锁定（2026-08-25）
- [x] 🟢 自研 HMI 导航信息架构纠正：Automatic/Manual/Homing/Change-over 固定在左侧模式栏，Overview/Events/I/O/Data 固定在顶部页面栏；Manual Unit 单动作为 Manual 模式下的 Overview，模式与页面状态彼此独立（2026-08-25）
- [ ] 🟡 自研 HMI 真机只读验收：关闭 Nexeed HMI 后验证 PublicEventList ExtensionObject 表示、活动/清除事件过滤、EtherCAT 9 元素数组索引、38 个 I/O 与 Kistler 力/位移；本步骤不得写变量
- [x] 🔴 自研 HMI 最小模式控制协议离线实现：APQ token=1；只允许 TokenRequest 与 ModeIdRequest；模式仅 1/3/4/5，带安全反馈、Changeover IsEmpty、Token/ModeId 回读和超时；不写 Heartbeat/TokenChangeResponse/物理 I/O/Chain（2026-08-25）
- [ ] 🔴 自研 HMI 模式切换真机验收：只读验收通过后另行明确授权，依次验证 Automatic/Manual/Home/Changeover 请求与拒绝路径；Nexeed HMI 必须关闭，不做多面板 Token 转移
- [ ] 🔴 自研 HMI 扩展控制真机验收：另行批准后验证 Start/Stop/Step request-bit 回零、PanelActive、Unit Exec 按住运行、Heartbeat challenge/ack、断线/失焦/退出强制释放；验收前不得开放 StationCommands/ManualFunctions capability
- [x] 🟢 依据 `docs/hmi_userdefined_integration.md` 更新 AI Coding 展示 HTML：明确 AI-first / 最低人工边界，加入 PLC、CpStudio、EtherCAT/BMK、HMI、断网五条操作流程和 UserDefined 案例；修正 Post-export runner/checker 状态并保留官方工具限制（2026-08-23）
- [ ] 🟢 测量数据记录(CSV/数据库)与追溯
- [ ] 🟢 对接 OpCon DataSetAccess / EventRecorder 接口
- [x] 🟢 硬件组态 IO 侧:按图纸页4核对树 + 删坏节点 _100A740_BL(2026-08-18,AI 经 `scripts/ioe/ioe_ipc.ps1` 驱动 IOE 完成;通道符号在 PLC 侧已存在)

## 已完成(近期)
- [x] 🟡 完成 HMI `OverView → UserDefined` 受控迁移：`OverView` 仅保留 `Mod_SmartControlHost1`，原状态灯、Station/Type 编号、设备图片和自动信息栏共 5 个控件及图片资源迁入 `UserDefined`；经 CpStudio 5.11 内置 HMI Configurator 分别加载 `UserDefined` 和宿主 `OverView`，显示及绑定正常；Station010 安全提交 `84d1577`（2026-08-23）
- [x] 🟡 实现用户双击运行的本地离线 Post-export 检查器：只启动一组自有 MCP/PLE，执行 strict no-save fresh Build，保存不可变报告并判断 `DONE_OFFLINE/NEEDS_EXPORT_2/NEEDS_LINK_IO/RETRY/WAITING/BLOCKED`；Export #2 anchor 可跨对象占用、次数纠正和 Build 前 Link I/O 恢复，无可关联 request 时不建 anchor，任何全局锁获取失败均不落报告；根项目与通用模板各 458 项自测通过（2026-08-23）
- [ ] 🔴 用户正常关闭现有 PLE/MCP owner 并释放 `.project.~u` 后，对 Station010 完成一次真实“启动 → fresh Build → 正常退出”离线检查器验收；不得强杀既有会话或手删活动锁
- [x] 🔴 完成真实 CpStudio Post-export Stage2 闭环：唯一 persistent PLE 会话执行只读审计与 fresh Build（0 errors / 6 warnings），哈希绑定 evidence 经 producer/consumer 验证后 operation 到 `DONE`；确认本批无需 Export #2，并补齐 `open_project` 离线能力白名单(2026-08-23)
- [x] 🔴 纠正 CpStudio/AI 接口所有权：生成 POU 的接口与 OES Declaration 仅由 CpStudio 配置，AI 只读消费；旧的整声明 REST 写入器在完成接口保持改造前标记为 blocked(2026-08-22)
- [x] 🔴 增加 Station010 提交安全门：禁止整体暂存，含实体连接凭据的生成配置必须字段级审阅/脱敏，当前脏生成批次不上传(2026-08-22)
- [x] 🟡 用 `DummySymbolProbe : BOOL` 完成新增与删除双向验证：新增第一遍即 available/selected；删除后同一 PLE 会话虽二次 Export 仍有 2 条旧签名警告，保存关闭并重开后 Build 恢复 0 errors / 6 warnings。门禁改为“条件二次 Export → 必要时重开验证”，禁止对 REST GET 不可见的失效签名构造精确 UnSelect(2026-08-22)
- [x] 🔴 完成 EtherCAT 单通道 BMK 双向实验：验证 Save → Write designators → Export #1 → Link I/O → mixed 引用语义合并 → Build → 条件 Export #2 → final Build；识别并规避 Symbol Configuration 并发对象锁，恢复原 BMK 后最终 Build 0 errors / 9 warnings(2026-08-22)
- [x] 从 vibe-coding-templates 派生仓库骨架 + git init(2026-08-17)
- [x] 吸收 ctrlx-ai-coding 方法论;环境体检(CRLF 补丁/模板/库仓库)通过(2026-08-17)
- [x] 🔴 修复 persistent MCP 编译完成后超时：去除重复 Build 和全类别×严重级别消息扫描，统一使用有界 Build summary 读取；Station010 实测编译约 7.6 s、缓存读取约 0.8 s，0 errors / 7 warnings(2026-08-20)
- [x] 🔴 修复 PLE `Bit type at the wrong position!` 与 501 条级联错误：补齐 3 个 AI 生成 SFC 的 39 个 Transition 内部名、修复 Home 两个陈旧 Transition 名、恢复 Symbol Configuration，并隔离损坏的 `Stat010_V5.precompilecache`；正式工程关闭重开后 Clean Build 0 errors / 7 warnings(2026-08-20)
- [x] 🔴 修复 persistent MCP 误接管复用 PID：启动器同时校验 PLE 可执行文件身份和 watcher 握手，避免旧 `ready.signal` 指向无关进程；补丁检查及实际重启通过(2026-08-20)
- [x] 🟡 清除 C0198：把 `CheckPartPresent` 双路产品传感器 AdditionalInfo 从 79 字符缩为 60 字符，满足 OpCon `SetEvent.STRING(63)`；增加静态长度门禁及 REST Transition 名称读回标准化，Clean Build 0 errors / 6 warnings(2026-08-20)
## 补充(2026-08-18 夜 转接)
- [x] 🔴 清理 3 个非 ST 残留并编译到 0 errors：最终定位为 A1 的旧 I/O 映射，离线重映射后为 0 errors / 7 warnings(2026-08-18)
- [ ] 🟡 用户决定:是否在 CpStudio 删除 Wp100A740* 站(Engineering_Data.xml 残留,不删则重新生成会带回)
- [ ] 🟡 CpStudio 重新生成后 git diff 分析 → docs/cpstudio_generation_analysis.md
- [x] 🟡 建立 CpStudio→Git→MCP 协同规范 + 确定性 PLC 文本快照/校验工具(2026-08-18;`scripts/plc/export_plc_snapshot.py`,`scripts/plc/verify_plc_snapshot.ps1`)
- [x] 🔴 建立可跨项目复制的目录标准：`config/specs/ai/src/catalog/scripts/tests/data/docs`，录入 Station010 当前规格、AI 归属、通用 FB 源码和已验证 Unit Catalog；加入结构冒烟测试与自定义 Post-export 信号脚本(2026-08-18)
- [x] 🔴 把目录标准产品化为 `New-CtrlXOpconProject.ps1`：事务化创建新 AI 旁车、统一相对路径、拒绝覆盖且不复制 `.project`/Std/闭源资料；50 项离线断言通过(2026-08-20)
- [x] 🔴 新增并安装 `$ctrlx-opcon-engineering` Codex Skill：按初始化、CpStudio 导出、PLC 离线开发和故障诊断组合流程；独立前向测试及安装一致性测试通过(2026-08-20)
- [x] 🟡 建立 MCP 产品化路线：受控 fork → 租约/operation → `project_health`/`compile_project_v2`/`apply_change_set` → 正式 Symbol/I/O/SFC 工具(2026-08-20)
- [x] 🟡 建立团队工作站交接：新增 `TEAM_SETUP.md`、无个人账号的 Codex MCP 配置样例和只读环境体检脚本，区分长期部署说明与会话型 HANDOVER(2026-08-19)
- [x] 🟡 将受控集成工程目录去日期化为 `Station010`，同步配置、脚本、规格、测试和部署文档；关键工程哈希与既有 Git 状态保持不变(2026-08-20)
- [x] 🟢 新增离线 AI Coding 展示页：覆盖 CpStudio/AI/ctrlX 分工、标准目录、两类开发闭环、对象归属、Home Chain、主气压联锁、BMK 改名复盘和验收证据；支持交互演示与打印 PDF(2026-08-19)
- [x] 🟡 在 CpStudio `Engineering settings → Export` 配置官方 Post-export hook 为 `..\McpCoding\scripts\cpstudio\post_export_signal.bat`；真实普通导出已生成 schema-v2 请求，Stage 1 完成只读审计并进入 Stage 2 `WAITING_FOR_RUNNER`（2026-08-22）
- [x] 🟡 实现 export request 第一阶段消费者：独立请求队列、排他锁、只读 Git diff、关键文件指纹、ownership 清单、JSON/Markdown 报告和失败留痕；不会启动 PLE/MCP(2026-08-20)
- [x] 🟡 实现 Stage 2 PlanOnly operation ledger：消费 Stage 1 报告，生成幂等/哈希绑定 action，持久化 `WAITING_FOR_RUNNER/WAITING_FOR_CPSTUDIO/WAITING_FOR_EXPORT_2/DONE/BLOCKED/FAILED`，并校验 runner evidence；协调器不启动 PLE/MCP/REST(2026-08-22)
- [x] 🟡 实现 runner evidence 封装边界：复核 action/Stage 1/ownership/所需关键 Station 指纹和当前 PLC SHA，要求显式离线/lease/验收事实，按固定算法生成 warning 签名多重集；封装器不调用 PLE/MCP/REST，PS5.1 根项目/模板自测通过（2026-08-23）
- [x] 🟡 实现受控 Runner P1.1 控制面：单 owner、Stage 1/Stage 2 编排、immutable action hash 复核和 run manifest（2026-08-27）
- [x] 🔴 实现 P1.2a .NET action client：严格 action 合同、双层租约、崩溃后 UNKNOWN 阻断、Named Pipe v1 Broker 客户端和不可变 evidence；P1.2b 唯一 session Agent/Broker 继续按本页当前阶段待办推进（2026-08-27）
- [x] 🔴 最小骨架只读基线:删除 Wp100 下全部 5 个 Unit 已获确认;导出 215 个文本对象并记录编译 66 errors/40 warnings(2026-08-18)
- [x] 🔴 PLC 写入落点决策:用户授权 `../Station010` 作为 CpStudio + MCP 受控集成工作工程(2026-08-18)
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
- [x] 🟡 完成 Run Chain 操作提示：用户在 CpStudio 追加并导出 `AutoInfoLineEnum` 4–16；AI 经官方 PLE REST 验证实际枚举顺序，按确定性 Plan SHA 事务写入 SqS/SqC 提示与 14-step 图，接口原样保留；fresh Build 0 errors / 4 managed-library warnings(2026-08-24)
- [x] 🔴 定位 Nexeed License Server 61863 故障：确认 App 在 `DENIED net_admin → StatusCode 999 → SIGSEGV` 后循环重启，端口关闭是结果；记录包权限边界并加入只读诊断脚本（2026-08-24）
- [ ] 🔴 由 Bosch/Nexeed 提供适配 ctrlX CORE X3 / OS 2.6 的修正版或正式处置；安装后验证 Logbook 无 crash-loop、61863 连续 60 s 可达、CpStudio `Read from target` 成功
- [x] 🟡 StationData 的 `LineNo`、`TestMode`、`NokCounter`、`Wp100.Active` 已经本次 CpStudio 导出从 PLC 主结构与数据检查中正式移除；生成后编译正常(2026-08-18)
- [ ] 🟡 决定是否删除当前仅剩自声明、无任何业务引用的 `StationSdNokCounter` 与 `Wp100StationDataStruct` DUT；在 CpStudio 不再生成它们前先保留
- [ ] 🔴 真机专项验证操作按钮：确认 `FlashBits.Pulse500ms` 的现场闪烁观感、按下后步骤跳转，以及切换模式/CANCEL/ERROR/DONE 时 `_000P610` 必定熄灭；决定按钮在步骤激活前已被按住时是否允许立即完成
- [ ] 🔴 真机专项验证主气压时序：两路物理压力输入已取消接线；确认 `_000K085A` 最终命令变化后 1 s 虚拟 HIGH/LOW 切换、5 s 诊断及故障恢复；覆盖维修门放行延迟、正常 Control On/Off 和联锁中途撤销；补充两个事件的中文文本
- [ ] 🔴 真机专项验证 Home 原子操作：覆盖压缸已/未在原位、安全门已/未在原位四种分支，确认 `_000S610/_000P610`、WRKPOS/BASPOS 顺序、Unit 超时/报错和模式切换 CANCEL 后所有输出复位
- [ ] 🔴 真机专项验证 Run 原子操作：覆盖 LEFT/MIDDLE/RIGHT 一取一联锁、按钮、门/压缸动作、安全反馈、PressDelayTime、Burster/Kistler 时序、测量失败及 CANCEL 后输出复位；真机操作前另行确认下载与运行授权
- [ ] 🔴 真机专项验证维修门联锁：确认按 `_000S901` 后 `_000K980/_000K981` 上电并由 ControlOn 状态保持；任一 `_000K980_A/_000K981_B` 缺失时 `_000K085A` 立即不上电，持续 5 s 后触发 `EVENT_MAINTENANCE_DOOR_NOT_LOAKED`，Control Off 后报警正确清除；同时验证模式不放行及故障恢复
- [x] 🟡 P1.1 `ProcessOne` 已把 Post-export 请求、Stage 1 离线审计和 Stage 2 PlanOnly ledger 串成受控入口；CpStudio hook 继续只发 signal，不自动启动 Broker/PLE/MCP，也不直接改写 `Engineering_Data.xml`（2026-08-27）
- [ ] 🔴 后续配置并验证 Burster HostName，放行 `SetRange/StartMeas` 手动功能；设备稳定后逐条实现 Homing/Changeover/Auto Chains
- [x] 🔴 重载 Codex/VS Code 恢复 MCP transport；单一 persistent 调用链完成最小骨架快照和编译(2026-08-18)

## 已完成(近期)补充
- [x] Station010 GitHub 私有备份 Stat_Resistant_Station010(基线+快照,本地已同步 origin/main)(2026-08-18)
- [x] 🔴 Kistler 5867C EtherCAT ESI 仓库闭环：经 IOE 官方 ScriptEngine 导入新 ESI，精确回读 `58A_0000E52F00000001 / Revision=1`；新增幂等安装脚本、Catalog、规格与同事部署检查(2026-08-19)
- [x] 🔴 在 IOE 受控工程中添加 Kistler `_100A104`：位于 `_000SA620_X1` 下并与 EK1100 同级，保存后重开精确回读 `58A_0000E52F00000001 / Revision=1`(2026-08-19)
- [x] 🔴 CpStudio 一键读取 ctrlX IDE EtherCAT IO 组态：`_100A104` 已自动匹配旧标题 `Kistler MaXYmos BL5867B TL5877B0`；Peripheral 已成功生成到 PLC/HMI(2026-08-19)
- [x] 🔴 Kistler Peripheral 导出闭环：修复同批 Burster BMK 改名的 PLC/Symbol 双层旧引用；经 IOE EtherCAT 离线导出 + PLE `keepExisting` 导入同步从站，400 个 PDO byte 全部映射且回读零差异；PLC 快照 234 objects，离线编译 0 errors / 7 warnings(2026-08-19)
- [x] 🔴 在 CpStudio 添加 `NexeedKistlerForceStroke` Unit，放到 `Wp100` 下并把 `IKistlerForceStroke` Channel 绑定到 `_100A104` Peripheral；PLC 侧 8 个手动功能均为 `CommonManRelease AND TRUE`，400/400 PDO 映射零差异，离线编译 0 errors / 7 warnings(2026-08-19)
- [x] 🔴 CpStudio 模型中 `Wp100A104Kistler` 的 8 个对象级手动条件已改为 `TRUE` 并重新导出；HMI 回读 8 个 TRUE、0 个 FALSE，与 PLC OnManRelease 一致(2026-08-19)
- [x] 🔴 维修门/安全回路反馈闭环：维修门 A/B 缺失与 `_000K981_Y32` 1 s 超时共用 `EVENT_MAINTENANCE_DOOR_NOT_LOAKED` 并写入具体 BMK AdditionalInfo；安全门、压缸手动与 Home 关门步骤加入 `_000K981_Y32/_000K913_Y32/_000K912_Y32` 联锁；四种 Mode Release 加入急停和维修门继电器反馈，离线编译 0 errors / 7 warnings(2026-08-19)
- [ ] 🔴 真机专项验证维修门安全继电器：两门关闭后 `_000K981_Y32` 应在 1 s 内成立；分别断开 A 门、B 门和继电器反馈，核对 AdditionalInfo BMK、主气压禁止、模式释放与 Control Off 恢复流程
- [x] 🔴 真实 Export `08bd1cc9-f16d-4903-99ff-7d83a88b0dae` 已经 Runner 执行：完整 Clean Build 0 errors / 4 warnings；action 因 Clean Build 后首次 Symbol REST 瞬态响应而失败关闭，sealed evidence 与 warning candidate 已生成（2026-08-28）
- [x] 🔴 第二次真实 Export `fa0c5fa1-3fff-4b3c-a8d3-05f590538fb4` 已经 Runner 执行：完整 Clean Build 0 errors / 4 warnings、工程/结构 SHA 不变；action 停在合并式 semantic stability 错误门禁，审查发现并修复 raw mapping 表示噪声与 Symbol 多阶段重建两个缺陷，新 warning candidate 已生成（2026-08-28）
- [x] 🔴 semantic adapter 已改为三组 Mapping/Symbol 交叉权威读取 + Symbol 最多 4 次有界 settle + 最终 Mapping/dirty guard；逐条 mapping 完整性与末端 Symbol TOCTOU 反例均纳入回归，补丁、全局安装和 `-Check` 通过（2026-08-28）
- [x] 🔴 已经 CpStudio 官方 Export 生成 request `cb1af562-25e6-4523-b2d8-037751d9433d`，修复版 Runner 取得稳定 semantic canonical facts 并生成 warning/semantic candidates（0 errors / 4 complete warnings；456 mapping records）（2026-08-28）
- [x] 🔴 用户已确认当前 candidates：18 个 unbound EtherCAT 通道当前不用，4 条相同 `OPC.UA.DA` managed-library warning 暂不处理；baseline 不采集姓名/工号，改用 `confirmedByUser` 与机器生成元数据（2026-08-28）
- [x] 🔴 已由 `Approve-PostExportBaselines.ps1` 原子建立两个正式 baseline 和无身份确认记录；未收集姓名/工号（2026-08-28）
