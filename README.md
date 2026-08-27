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
interactive Broker 的离线基础：current-user registration、Named Pipe v2、持久化
submit/query、单 owner 和崩溃后人工复核。CLI/P1.1 本身不会启动 PLE/MCP，也不含
真机能力：

```powershell
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Status
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command ProcessOne
.\scripts\runner\Invoke-CtrlXOpconRunner.ps1 -Command Doctor
```

2026-08-28，P1.2b 已通过一次真实 Station010 PLE 离线 action 验证受控 adapter、
same-call 普通 Build、typed warnings 与 semantic snapshot 通道：Build 为 `0 errors / 101 条可见 warnings`，
提取 456 条 I/O mapping facts，工程和结构哈希前后不变。该 action 只调用 status、
compile 与 semantic snapshot，没有修改 PLC/IO/ST，也没有任何在线操作。

当前仍不是 `DONE`：本次 action 终态为 `SEMANTIC_BASELINE_BOOTSTRAP_REQUIRED`；
warning proof 同时尚无正式 baseline，且 warning candidate 含
`PLE_WARNING_OUTPUT_TRUNCATED`。后续实测还证明，同一 `.project` 字节在原路径普通 Build
显示 101 条可见 warnings，在隔离路径普通 Build 只显示 4 条；两者都不能替代语义 Clean
Build。候选文件只用于审阅，禁止自动转成正式 baseline。

隔离副本已通过官方 REST 验证 `maxCompilerWarnings: 100 → <no limit> → 100`，磁盘字节
保持不变；REST PUT 回滚后 PLE 内存工程仍为 dirty，必须关闭不保存并重开。通用补丁现已
新增并安装显式 `clean_compile_project`：恰好一次 `application.clean()` 加一次
`application.build()`，不保存工程。当前只差重启 Codex 扩展加载新工具，然后在可丢弃
隔离副本中完成 `<no limit>` 持久化、重开和连续两次 Clean Build。取得一致且不截断的
告警全集后，才进入人工确认和新 immutable action 复验。完整边界见
`scripts/runner/README.md`。

同日已完成提交前失败关闭加固：warning 截断在 Broker、Stage 1/2 与 evidence 层统一
阻断；人工 review 必须是 `docs/reviews/` 下独立文档，candidate/AI triage 及其改名副本
不能充当人审证据；review、scope 和 baseline 均以同一份有界字节完成校验、SHA 绑定与
解析；semantic adapter 在全部 I/O/Symbol 读取后再次确认工程未变脏，并对 REST 响应实行
30 s 全程超时和 8 MiB 流式上限。敏感值扫描覆盖凭据赋值、连接串、Bearer 与私钥，且
错误不会回显秘密。上述加固不改变当前 baseline-bootstrap `BLOCKED` 结论。

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
