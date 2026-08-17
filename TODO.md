# TODO.md — 任务清单

> 完成即勾选;优先级 🔴 高 / 🟡 中 / 🟢 低。大项完成后把结论写进 docs/ 或 AGENTS.md。

## 当前阶段:阶段 0 项目初始化
- [ ] 🔴 解析 ../电阻测试台.pdf,整理工艺需求 → docs/requirements.md(验收标准:需求清单覆盖测量流程/IO/判定标准,并经用户确认)
- [ ] 🔴 create_project 建立 src/ResistantStation.project 并编译通过(验收标准:compile_project 0 错误)
- [ ] 🟡 应用架构设计:状态机 + 模块划分 → docs/architecture.md(验收标准:对齐 Station010 OpCon 规范,经用户确认)

## Backlog(以后再说)
- [ ] 🟢 HMI 界面(OpCon Modulo)
- [ ] 🟢 测量数据记录(CSV/数据库)与追溯
- [ ] 🟢 对接 OpCon DataSetAccess / EventRecorder 接口

## 已完成(近期)
- [x] 从 vibe-coding-templates 派生仓库骨架 + git init(2026-08-17)