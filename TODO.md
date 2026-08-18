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
- [ ] 🔴 清理 3 个陈旧 SymbolConfig 条目(bus_000S900 / bus_000SK010A1_Channel_6 / _7),编译 → 0 errors(路线①:用户 PLE Symbols 编辑器手删;路线②:AI 试 import_xml 整表)
- [ ] 🟡 用户决定:是否在 CpStudio 删除 Wp100A740* 站(Engineering_Data.xml 残留,不删则重新生成会带回)
- [ ] 🟡 CpStudio 重新生成后 git diff 分析 → docs/cpstudio_generation_analysis.md
- [x] 🟡 建立 CpStudio→Git→MCP 协同规范 + 确定性 PLC 文本快照/校验工具(2026-08-18;`scripts/export_plc_snapshot.py`,`scripts/verify_plc_snapshot.ps1`)
- [ ] 🔴 最小骨架基线:删除 Wp100 下全部 5 个 Unit 已获用户确认;关闭持锁 PLE 后导出首份 PLC 文本快照并编译
- [ ] 🔴 受控增量实验:每次只添加 1 个设备并完成生成→Git diff→ST 快照→编译→提交;设备稳定后再逐条添加自动 Chains
- [ ] 🔴 重载 Codex/VS Code 恢复已关闭的 MCP transport；恢复后用单一 persistent 调用链完成最小骨架快照和编译(工程备份/哈希见 HANDOVER 恢复点)

## 已完成(近期)补充
- [x] Station010_0708 GitHub 私有备份 Stat_Resistant_Station010(基线+快照,本地已同步 origin/main)(2026-08-18)
