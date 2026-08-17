# AGENTS.md — BPP_ResistantStation(电阻测试台)AI Agent 工作指南

> 任何 AI 编码代理在本仓库工作前,先读完本文件。方法论母本见 `ctrlx-ai-coding/`(先读其 AGENTS.md 与 docs/ctrlX_AI_project_baseline.md)。

## 1. 项目一句话
基于 Bosch OpCon V5.11 / ctrlX 架构开发"电阻测试台"(Resistance Test Bench)工位软件:PLC 逻辑 + 测量流程 + 数据记录;AI 经 codesys-persistent MCP 直接写 PLC 代码(PLC 侧完全绕开 CpStudio);参考实现为旁级 `Station010_0708`。

## 2. 分工
| 角色 | 职责 |
|---|---|
| **用户** | 架构决策、工艺/电气需求定义、CpStudio 骨架(若走该路线)、硬件接线与组态、真机安全确认、下载部署批准 |
| **AI** | ctrlX PLC 编码(set_pou_code → compile 结构化错误 → 修复闭环)、仿真与变量级测试、IO 映射辅助、文档;**不**擅自连真机/下载/启停 runtime,**不**修改参考工程 |

## 3. 红线(违反会出事故)
1. **`.project` 是加密容器**——绝不手改文件字节,只能经 MCP 工具(IDE 脚本引擎)修改;`.project` 二进制不入库。
2. **真机操作必须先与用户确认**:`connect_to_device` 到实体 PLC、`download_to_device`、`start_stop_application`、`write_variable`(**FORCE 强制,不解除一直生效**);仿真模式(set_simulation_mode)不受限。
3. `../Station010_0708/` 与 `../Std/` 为只读参考:不修改、不删除、不移动。
4. **npm 升级 `codesys-mcp-persistent` 会覆盖 CRLF 补丁** → 升级后必重跑 `ctrlx-ai-coding/patches/codesys-mcp-persistent-crlf/apply-crlf-patch.ps1`(先 `-Check`)。
5. **同一时间只开一个使用 codesys MCP 的 Codex 窗口**(多实例抢 profile 致 IDE 退出)。
6. CpStudio 重新生成会覆盖 AI 代码:生成前必备份 + diff;AI 自定义代码放独立 POU 并带项目前缀。
7. 不入库:编译缓存与用户配置(*.precompilecache/*.Sync.json/*.opt/*.Backup/*.~u)、.compiled-library、data/ 日志大文件、*.zip/*.pdf 原始资料。
8. `eval_python` 仅作审计用途;勿对已打开工程裸调 `se.projects.open()`(卡死 IDE UI 线程)。

## 4. 环境关键事实(已实测,改前核对)
| 项 | 值 |
|---|---|
| PLC IDE | ctrlX WORKS / ctrlX PLC Engineering PLE_V_0206;profile 必须精确 `ctrlX PLC 2.6.8` |
| MCP | codesys-persistent(persistent 唯一可行,ctrlX 品牌 IDE headless 不可用);CRLF 补丁 ✅(2026-08-17 -Check 全 OK) |
| 库仓库 | `C:\ProgramData\Rexroth\PLE-V-0206\0\Studio\Managed Libraries`(OpCon 全套,占位符编译时自动解析) |
| 工程模板 | `C:\ctrlXWORKS\ctrlXPLCEngineering\PLE_V_0206\Studio\Templates\Standard.project`(TrainingStation 拷贝,含 OpCon 骨架 + 34 库占位符) |
| 新建工程 | `create_project(templatePath=Standard.project)` → `src/ResistantStation.project` |
| 编译 | `compile_project`(基准 errors=0;`get_compile_messages` 是缓存,改代码后先编译再取) |
| 测试 | `set_simulation_mode(true)` → `connect_to_device` → `read_variable`/`write_variable`/`monitor_variables` |
| 参考工程 | `../Station010_0708/Plc/Stat010_V5.11_CtrlX_PLC.project` |

## 5. 文档与提交约定
- 事实源:README(是什么)/ docs(技术细节)/ HANDOVER.md(当前状态)/ TODO.md(下一步);权威方法论 = ctrlx-ai-coding/docs/ctrlX_AI_project_baseline.md
- 会话循环:进场读 AGENTS → HANDOVER → TODO;收场更新 HANDOVER + TODO 勾选 + 提交推送
- 提交前缀:`feat:` `fix:` `docs:` `test:` `tools:` `refactor:`

## 6. 当前状态快照
- [x] 克隆 vibe-coding-templates + ctrlx-ai-coding,派生本仓库骨架(2026-08-17)
- [x] 环境体检:CRLF 补丁已打、Standard.project 与库仓库就位、MCP ready
- [ ] 从 Standard.project 建 src/ResistantStation.project,编译 errors=0
- [ ] 电阻测量工艺需求清单(docs/requirements.md)