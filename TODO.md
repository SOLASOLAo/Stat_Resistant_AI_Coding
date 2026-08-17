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
- [ ] 🟢 硬件组态:ctrlX + EtherCAT IO(阶段 2,用户主导)

## 已完成(近期)
- [x] 从 vibe-coding-templates 派生仓库骨架 + git init(2026-08-17)
- [x] 吸收 ctrlx-ai-coding 方法论;环境体检(CRLF 补丁/模板/库仓库)通过(2026-08-17)