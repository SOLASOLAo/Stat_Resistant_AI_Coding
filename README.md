# BPP_ResistantStation — 电阻测试台

一句话定位:电阻测试台(Resistance Test Bench)的工位软件 —— 基于 Bosch OpCon V5.11 / ctrlX,覆盖 PLC 测量流程逻辑、工位状态管理与测量数据记录。

## 功能 / 目标
- 电阻测量工艺逻辑(PLC,IEC 61131-3 ST)
- 工位状态机 / 模式管理(对齐 OpCon 规范,参考 Station010)
- 测量数据记录与追溯
- HMI(OpCon Modulo,后期)

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

状态会明确停在 `WAITING_FOR_RUNNER`、`WAITING_FOR_CPSTUDIO` 或
`WAITING_FOR_EXPORT_2`，直到唯一的 persistent Codex 会话提交与 action
哈希绑定的执行证据，或用户完成明确要求的 CpStudio 操作。只有 Export #1
发生 Symbol 缺失/未选中、OPC UA/PersistentVars/Symbol 后处理失败，或 BMK
变更经 Build 后仍需刷新时，才要求 Export #2；它不是每次导出的固定动作。

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
├── catalog/       已验证 Unit/AddOn/Peripheral 知识库
├── scripts/       CpStudio/PLC/IOE/Git 自动化
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
- AI Coding 展示页（离线 HTML，含演示与打印模式）:`docs/ai_coding_showcase.html`
- CpStudio 生成差异分析:`docs/cpstudio_generation_analysis.md`
- Kistler 5867C EtherCAT 集成:`docs/kistler_5867c_ethercat_integration.md`
- 跨项目目录标准:`docs/project_structure_standard.md`
- MCP 产品化路线:`ctrlx-ai-coding/docs/mcp_productization_roadmap.md`
- 团队工作站部署:`TEAM_SETUP.md`

## 版权说明
- OpCon / Nexeed / ctrlX 为 Bosch 商标,相关参考代码与组件仅限本工程内部使用
