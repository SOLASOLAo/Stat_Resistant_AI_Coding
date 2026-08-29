# BPP_ResistantStation — 电阻测试台

一句话定位:电阻测试台(Resistance Test Bench)的工位软件 —— 基于 Bosch OpCon V5.11 / ctrlX,覆盖 PLC 测量流程逻辑、工位状态管理与测量数据记录。

## 功能 / 目标
- 电阻测量工艺逻辑(PLC,IEC 61131-3 ST)
- 工位状态机 / 模式管理(对齐 OpCon 规范,参考 Station010)
- 测量数据记录与追溯
- HMI：保留 OpCon Modulo，并行开发独立 Windows HMI 做 A/B 对比

## 快速上手

本仓库是 `../Station010` 的 AI 工程旁车；CpStudio 负责标准模型，AI 经
PLC Engineering MCP/REST 维护应用逻辑：

```text
1. 阅读 AGENTS.md、HANDOVER.md、TODO.md
2. 运行 tests/static/Test-ProjectFramework.ps1
3. 从 config/project.yaml 定位集成工程和工具版本
4. 模型改动走 CpStudio；应用逻辑走 specs → MCP/REST → readback
5. 完整离线编译，以 0 errors 和已记录 warning 基线验收
```

CpStudio 导出后先运行纯离线审计，不启动第二个 PLE：

```powershell
.\scripts\cpstudio\Invoke-PostExportAudit.ps1 -WhatIf
.\scripts\cpstudio\Invoke-PostExportAudit.ps1
```

离线报告随后交给 Stage 2 计划器。它只建立可追踪的 operation ledger 和
runner action，不自行启动 PLE、MCP 或 REST，也不修改生成工程：

```powershell
.\scripts\cpstudio\Invoke-PostExportEngineering.ps1 `
  -AuditReport .\data\reports\cpstudio\<stage1-report>.json
```

第一阶段统一入口已落在受控 Runner。P1.1 取得 OS 排他租约、检查工程路径/
profile/ownership manifests、串联 Stage 1 和 Stage 2，并保存 `run-manifest.json`；
P1.2a 增加 .NET 8 action client、双租约、幂等终态和 evidence 封口；P1.2b 已完成
interactive Broker、current-user registration、Named Pipe v2、持久化 submit/query、
单 owner 和崩溃后人工复核。CLI/P1.1 本身不会启动 PLE/MCP，也不含真机能力：

```powershell
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Status
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command ProcessOne
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Doctor
```

2026-08-28，P1.2b 已在真实 Station010 PLE 离线 action 中完成受控 adapter、显式 Clean
Build、typed warnings 与 semantic snapshot 验证：`0 errors / 4 warnings`，提取 456 条
I/O mapping facts，工程和结构哈希前后不变，且没有 PLC/IO/ST 修改或在线操作。

warning/semantic candidates 已由用户一次明确确认；受控工具不采集姓名或工号。正式
baselines、Build 前本机内容寻址 checkpoint 和全新 immutable action 已完成最终复验，P1.2
至此关闭。

P1.3b 已让 current-user Host 自动发现并消费首次激活后生成的 immutable `currentAction`：
有待处理 action 且无同会话 Agent 时保持 `WAITING_FOR_AGENT`，执行中保持单 action，终态证据生成后保持
`WAITING_FOR_COORDINATOR`；历史已终态 action 不会重跑，旧 open claim 可恢复。Host 仍永不
启动 Broker、MCP、PLE、Node 或在线操作。

P1.3c 技术实现与本机验收已完成。Host 会校验 result/evidence SHA、immutable action 与 operation
ledger，再调用 Stage 2 coordinator 推进；合法 `UNKNOWN`/`FAILED` 且无 evidence 时保持
`WAITING_FOR_COORDINATOR` 等待人工复核，busy 使用有界退避，畸形 ledger 失败关闭。production
ingestor 默认装配已通过 6 项 fixture E2E 和真实 ledger lock busy 验收。

稳定部署使用 `LocalAppData` 下包含 5 个文件的内容寻址不可变 release，并以 durable pending
journal/reconcile 覆盖中断窗口。显式生命周期命令会验证全部 5 个文件和 apphost self-check；AtLogOn
task 的 action 精确指向 release exe，description 记录 release/manifest，但登录任务自身不会在启动前
执行 manifest 校验。`Install` 对同版本幂等并可升级，`Rollback` 可切回上一版本，失败升级恢复旧任务
及原运行状态。

本机验收还覆盖源任务禁用/已删除、`STATE_COMMITTED`、wrapper 被强杀后由默认 `Start` 窄门禁恢复、
新 release 升级、同版本 no-op、回滚、损坏候选拒绝，以及 deployment 丢失时基于精确任务的安全
`Uninstall`。主 Host 当前 active release 为 `faa27c...0f1`，previous release 为 `ac89b...4b51`，
状态为 `WAITING_FOR_ACTION`。

P1.4a 已完成精简团队离线包：发行端生成包含 `Install.ps1`、canonical wrapper/module、
`package-manifest.json` 和 Host 五文件 payload 的独立目录；接收工位只需 PowerShell 7、.NET 8
runtime 和本 AI 工程根目录，不需要 Git、源码、SDK 或本机 build。安装器会在任何命令前校验
path/length/SHA-256/contentId，支持首装/升级、精确回滚、安全卸载和只读状态查询。fresh
`Install` 默认不启动 Host；升级保留原 running/stopped 状态。当前不增加自定义 ACL，数字签名
延期到商业发行或公司 IT 明确要求。独立 AtLogOn 五文件 prelaunch bootstrap、兼容矩阵和新电脑
验收仍未完成，因此 P1.4 整体保持开放。

Host 的登录任务使用无控制台 apphost，后台运行不再弹出空白终端；人工执行
`Status/Stop/Logs` 时仍通过 `dotnet + DLL` 返回结构化结果。

提交前失败关闭加固保持有效：warning 截断在 Broker、Stage 1/2 与 evidence 层统一阻断；
确认记录、scope 和 baseline 均以同一份有界字节完成校验、SHA 绑定与解析；semantic adapter
在全部 I/O/Symbol 读取后再次确认工程未变脏，并对 REST 响应实行 30 s 全程超时和 8 MiB
流式上限。敏感值扫描覆盖凭据赋值、连接串、Bearer 与私钥，且错误不会回显秘密。

完整产品阶段与当前边界见 `docs/productization_roadmap.md`。

唯一 persistent Codex 会话执行 action 后，用纯离线封装器复核 action/清单/
关键 Station 指纹、Build 新鲜度、工程 SHA 和 warning 签名多重集，再生成不可变
evidence；封装器本身不调用或启动任何工程工具：

```powershell
.\scripts\cpstudio\New-PostExportRunnerEvidence.ps1 `
  -ActionPath <action.json> `
  -ExpectedActionSha256 <ledger-sha256> `
  -ObservationPath <runner-observation.json> `
  -OutputPath .\data\runner-evidence\<action-id>.json `
  -WhatIf
```

其中 session/PID/lease/acceptance 是 active runner 的结构化自证，封装器会
校验必填性和相互一致性，但不会独立查询进程表或 MCP；`workflow-local`
不是跨进程锁，也不是加密证明。

状态会明确停在 `WAITING_FOR_RUNNER`、`WAITING_FOR_CPSTUDIO` 或
`WAITING_FOR_EXPORT_2`，直到唯一的 persistent Codex 会话提交与 action
哈希绑定的执行证据，或用户完成明确要求的 CpStudio 操作。只有 Export #1
发生 Symbol 缺失/未选中、OPC UA/PersistentVars/Symbol 后处理失败，或 BMK
变更经 Build 后仍需刷新时，才要求 Export #2；它不是每次导出的固定动作。

断网时不需要手工猜这个判断。先保存并关闭所有 PLE 和占用 MCP 的
Codex/VS Code 窗口，然后双击：

```text
scripts\cpstudio\Run-OfflinePostExportCheck.cmd
```

检查器取得全局锁后会独占启动一个本地 PLE，执行 fresh Build、保存本地报告，并明确给出
`DONE_OFFLINE`、`NEEDS_EXPORT_2`、`NEEDS_LINK_IO` 或“等待 AI”的下一步。
若全局锁被占用或无法创建，只在控制台给出原因，不执行 Build、也不写报告。
它不调用代码修改或工程保存工具；MCP 的 no-save 补丁会在工程为 dirty 时拒绝
Build，检查器还会复核工程前后哈希。它不执行任何真机在线动作，也没有接入
CpStudio hook。`DONE_OFFLINE` 只表示无需继续 Export，不代表 warning/质量验收通过。

独立 Windows HMI 原型位于 `src/hmi/`。它不改 CpStudio/HMI 或 PLC，使用当前
Symbol Configuration 已发布的 150 个经审阅 ctrlX OPC UA 订阅节点；Overview、Manual、
Events、I/O、Data 五页采用 Nexeed 类似的信息层级。实时数据、设备参数和状态
仍全部只读；唯一的写入能力是明确白名单中的 `TokenRequest` 和 `ModeIdRequest`，
且真机连接默认不允许模式请求：

```powershell
cd src\hmi
dotnet restore .\Bpp.ResistantStation.Hmi.sln --locked-mode
dotnet run --project .\Bpp.ResistantStation.Hmi\Bpp.ResistantStation.Hmi.csproj -- --demo
```

真实连接前关闭 Nexeed HMI；账号和密码只在连接对话框内存中使用。首次真机验收仍只读，
先核对 PublicEventList、EtherCAT 数组及 Unit 参数/状态解码；模式请求另行批准后
才在当次会话开启。详见 `docs/self_hmi_parallel_poc.md`。

新同事或新电脑先按 `TEAM_SETUP.md` 完成软件、三仓库、`Std`、MCP 补丁和首次离线验收；
不要从历史型 `HANDOVER.md` 反推安装步骤。

## 跨项目复用

通用初始化器、项目模板和 Codex Skill 位于 `ctrlx-ai-coding/`。新工站不要复制 Station010 的
BMK、事件或 Chain；先运行初始化器的 `-WhatIf`，再创建独立 AI 旁车：

```powershell
.\ctrlx-ai-coding\scripts\New-CtrlXOpconProject.ps1 `
  -ProjectId 'example-cell' `
  -DisplayName 'Example Cell' `
  -StationId 'Station020' `
  -StationRoot 'C:\Engineering\ExampleCell\Station020' `
  -OutputPath 'C:\Engineering\ExampleCell\McpCoding' `
  -WhatIf
```

Skill 已可版本化安装并校验：

```powershell
.\ctrlx-ai-coding\scripts\Install-CtrlXOpconSkill.ps1 -Force
.\ctrlx-ai-coding\scripts\Install-CtrlXOpconSkill.ps1 -Check
```

## 仓库结构
```
├── config/        工程路径、版本和质量门禁
├── specs/         Station/IO/Event/Unit/Chain 需求事实源
├── ai/            AI 对象归属、混合钩子和 SFC 图形属性
├── src/plc/       AI-owned 通用与项目专用 PLC 源码
├── src/hmi/       独立 Windows HMI（与 Nexeed HMI 并行比较）
├── catalog/       已验证 Unit/AddOn/Peripheral 知识库
├── scripts/       Runner/CpStudio/PLC/IOE/Git 自动化
├── tests/         静态、编译与仿真测试
├── data/          请求、快照、报告和本地备份(不入 Git)
├── docs/          技术文档与生成机制分析
├── TEAM_SETUP.md  团队交接与新电脑部署
├── AGENTS.md      AI Agent 工作指南(先读)
├── HANDOVER.md    会话交接状态
└── TODO.md        任务清单
```

## 相关仓库 / 文档
- 集成工作工程:`../Station010`(OpCon V5.11 ctrlX；CpStudio 生成 + AI 经 MCP 写 PLC ST)
- 标准库:`../Std`(OpCon/Nexeed 标准组件,只读)
- 开发模板:`vibe-coding-templates/`(github.com/SOLASOLAo/vibe-coding-templates)
- 原始资料:`../电阻测试台.pdf`、`../BPP_ctrlX.zip`(不入 git)
- CpStudio/Git/MCP 协同流程:`docs/cpstudio_git_mcp_workflow.md`
- UserDefined HMI 集成与脱敏规则:`docs/hmi_userdefined_integration.md`
- 独立 Windows HMI A/B 原型:`docs/self_hmi_parallel_poc.md`
- AI Coding 展示页（离线 HTML，含演示与打印模式）:`docs/ai_coding_showcase.html`
- CpStudio 生成差异分析:`docs/cpstudio_generation_analysis.md`
- Kistler 5867C EtherCAT 集成:`docs/kistler_5867c_ethercat_integration.md`
- Nexeed License Server 61863 故障诊断:`docs/nexeed_license_server_diagnosis.md`
- 跨项目目录标准:`docs/project_structure_standard.md`
- 产品化主路线（Runner → 项目生成 → HMI → 商业交付）:`docs/productization_roadmap.md`
- Phase 1 的 MCP/adapter 技术子路线:`ctrlx-ai-coding/docs/mcp_productization_roadmap.md`
- 团队工作站部署:`TEAM_SETUP.md`

## 版权说明
- OpCon / Nexeed / ctrlX 为 Bosch 商标,相关参考代码与组件仅限本工程内部使用
