# AGENTS.md — BPP_ResistantStation(电阻测试台)AI Agent 工作指南

> 任何 AI 编码代理在本仓库工作前,先读完本文件。

## 1. 项目一句话
基于 Bosch OpCon V5.11 / ctrlX 架构开发"电阻测试台"(Resistance Test Bench)的工位软件:PLC 逻辑 + 测量流程 + 数据记录,当前处于 AI 辅助(MCP)原型开发阶段;参考实现为旁级 `Station010_0708`(OpCon V5.11 ctrlX 标准工位)。

## 2. 分工
| 角色 | 职责 |
|---|---|
| **用户** | 架构决策、工艺/电气需求定义、硬件接线与操作、真机安全确认、下载部署批准、许可证 |
| **AI** | CODESYS PLC 编码(经 codesys MCP)、编译修复、仿真与变量级测试、文档、调试辅助;**不**擅自连真机、不擅自下载/启停 runtime、不修改参考工程 |

## 3. 红线(不可做)
1. `../Station010_0708/` 与 `../Std/` 为只读参考工程:不修改、不删除、不移动,只允许读取与复制导出。
2. 真机操作必须先经用户明确确认:`connect_to_device` 到实体 PLC、`download_to_device`、`start_stop_application`、`write_variable` 强制真实输出;仿真模式(set_simulation_mode)不受限。
3. 不入库的内容:CODESYS 编译缓存与用户配置(*.precompilecache/*.Sync.json/*.opt/*.Backup/*.~u)、.compiled-library、data/ 日志与大文件、密钥与许可证文件。
4. `../BPP_ctrlX.zip` 与 `../电阻测试台.pdf` 为原始资料(体积大),不入 git,只引用。

## 4. 环境关键事实
| 项 | 值 |
|---|---|
| 语言/运行时 | IEC 61131-3 ST(CODESYS);后期 C#/.NET(OpCon HMI) |
| PLC IDE | CODESYS V3.5,本机运行 codesys_persistent MCP(状态 ready) |
| 参考工程 | `../Station010_0708/Plc/Stat010_V5.11_CtrlX_PLC.project` |
| 新建工程 | `create_project` → `src/ResistantStation.project` |
| 编译 | `compile_project` |
| 测试 | `set_simulation_mode(true)` → `connect_to_device` → `read_variable` / `write_variable` / `monitor_variables` |
| 目标平台 | Bosch ctrlX Core(_ctrlXCore.nxdc);本地调试用 _Laptop 目标 |

## 5. 文档与提交约定
- 事实源:README(是什么)/ docs(技术细节)/ HANDOVER.md(当前状态)/ TODO.md(下一步)
- 会话循环:进场读 AGENTS → HANDOVER → TODO;收场更新 HANDOVER + TODO 勾选 + 提交推送
- 提交前缀:`feat:` `fix:` `docs:` `test:` `tools:` `refactor:`
- 每次会话结束:更新 HANDOVER.md + TODO.md 勾选 + 提交推送

## 6. 当前状态快照
- [x] 克隆 vibe-coding-templates 并派生本仓库骨架(2026-08-17)
- [x] git init + 首次提交
- [ ] 在 src/ 建立 CODESYS 工程并编译通过
- [ ] 电阻测量工艺需求清单(docs/requirements.md)