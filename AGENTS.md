# AGENTS.md — BPP_ResistantStation(电阻测试台)AI Agent 工作指南

> 任何 AI 编码代理在本仓库工作前,先读完本文件。方法论母本见 `ctrlx-ai-coding/`(先读其 AGENTS.md 与 docs/ctrlX_AI_project_baseline.md)。

## 1. 项目一句话
基于 Bosch OpCon V5.11 / ctrlX 架构开发"电阻测试台"(Resistance Test Bench)工位软件:CpStudio 维护标准模型/HMI，AI 依据 `specs/` 与 `ai/` 清单，经 codesys-persistent MCP/REST 维护 PLC 应用逻辑；受控集成工程为旁级 `Station010`。

## 2. 分工
| 角色 | 职责 |
|---|---|
| **用户** | 架构决策、工艺/电气需求定义、CpStudio 骨架(若走该路线)、硬件接线与组态、真机安全确认、下载部署批准 |
| **AI** | ctrlX PLC 编码(set_pou_code → compile 结构化错误 → 修复闭环)、仿真与变量级测试、IO 映射辅助、文档;**不**擅自连真机/下载/启停 runtime,**不**修改参考工程 |

## 3. 红线(违反会出事故)
1. **`.project` 是加密容器**——绝不手改文件字节,只能经 MCP 工具(IDE 脚本引擎)修改;`.project` 二进制不入库。
2. **真机操作必须先与用户确认**:`connect_to_device` 到实体 PLC、`download_to_device`、`start_stop_application`、`write_variable`(**FORCE 强制,不解除一直生效**);仿真模式(set_simulation_mode)不受限。
3. `../Station010/` 已由用户批准升级为 **CpStudio + MCP 受控集成工作工程**(2026-08-18):用户经 CpStudio 修改模型/HMI并生成;AI 可在备份 + Git diff/文本快照后经 MCP 修改 PLC ST、经 IOE-IPC 修改 IO 工程。禁止手改 `.project` 字节、禁止无备份覆盖、禁止绕开相应 IDE。`../Std/` 仍为严格只读参考:不修改、不删除、不移动。
4. **npm 升级 `codesys-mcp-persistent` 会覆盖 ctrlX 兼容补丁**（CRLF、connector I/O Mapping、有界编译消息读取）→ 升级后必重跑 `ctrlx-ai-coding/patches/codesys-mcp-persistent-crlf/apply-crlf-patch.ps1`(先 `-Check`)。
5. **同一时间只开一个使用 codesys MCP 的 Codex 窗口**(多实例抢 profile 致 IDE 退出)。
6. CpStudio 重新生成可能覆盖 AI 代码:生成后先 diff，并按 `ai/ownership.yaml`、`ai/hooks.yaml`、`ai/graphical.yaml` 审计；完整 AI-owned POU 的可读源放 `src/plc/`，混合对象只做语义合并。
7. 不入库:编译缓存与用户配置(*.precompilecache/*.Sync.json/*.opt/*.Backup/*.~u)、.compiled-library、data/ 日志大文件、*.zip/*.pdf 原始资料。
8. `eval_python` 仅作审计用途;勿对已打开工程裸调 `se.projects.open()`(卡死 IDE UI 线程)。

## 4. 环境关键事实(已实测,改前核对)
| 项 | 值 |
|---|---|
| PLC IDE | ctrlX WORKS / ctrlX PLC Engineering PLE_V_0206;profile 必须精确 `ctrlX PLC 2.6.8` |
| MCP | codesys-persistent(persistent 唯一可行,ctrlX 品牌 IDE headless 不可用);ctrlX 兼容补丁 ✅(2026-08-20 -Check 全 OK，含编译超时修复) |
| 库仓库 | `C:\ProgramData\Rexroth\PLE-V-0206\0\Studio\Managed Libraries`(OpCon 全套,占位符编译时自动解析) |
| 工程模板 | `C:\ctrlXWORKS\ctrlXPLCEngineering\PLE_V_0206\Studio\Templates\Standard.project`(TrainingStation 拷贝,含 OpCon 骨架 + 34 库占位符) |
| 编译 | `compile_project`(基准 errors=0;`get_compile_messages` 是缓存,改代码后先编译再取) |
| 测试 | `set_simulation_mode(true)` → `connect_to_device` → `read_variable`/`write_variable`/`monitor_variables` |
| CpStudio/MCP 集成工作工程 | `../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project`(写入遵守红线 1/2/3/6) |

## 5. 文档与提交约定
- 事实源:README(是什么)/ TEAM_SETUP.md(同事工作站部署)/ `config/`(路径与门禁)/ `specs/`(确认需求)/ `ai/`(对象归属与钩子)/ `src/plc/`(AI-owned 源码)/ `catalog/`(已验证标准对象接口)/ docs(技术细节)/ HANDOVER.md(当前状态)/ TODO.md(下一步);权威方法论 = ctrlx-ai-coding/docs/ctrlX_AI_project_baseline.md
- 会话循环:进场读 AGENTS → HANDOVER → TODO;收场更新 HANDOVER + TODO 勾选 + 提交推送
- 提交前缀:`feat:` `fix:` `docs:` `test:` `tools:` `refactor:`
- PLC ST 条件格式:每个独立条件都用括号包裹，括号内侧各留一个空格；复合条件换行时 `AND`/`OR` 放在上一行末尾，禁止把逻辑运算符放在续行开头。示例：

  ```st
  IF ( ConditionA ) AND
     ( ConditionB )
  THEN
  ```

  提交前由 `tests/static/Test-ProjectFramework.ps1` 扫描 `src/plc/**/*.st`。

## 6. 当前状态快照
- [x] 克隆 vibe-coding-templates + ctrlx-ai-coding,派生本仓库骨架(2026-08-17)
- [x] 环境体检:ctrlX 兼容补丁已打、Standard.project 与库仓库就位、MCP ready
- [x] Station010 IO 硬件组态修复 + IOE-IPC 工具链(2026-08-18);踩坑归档 ctrlx-ai-coding/docs/ioe_scripting_playbook.md
- [x] 采用 `../Station010` 作为 CpStudio + MCP 受控集成工程并持续保持离线编译 errors=0
- [x] 通用新项目初始化器、Post-export 离线审计队列与 `$ctrlx-opcon-engineering` Skill 已落地并通过离线测试(2026-08-20)
- [ ] 补齐 `specs/` 中尚未定义的电阻测量生产流程

## 7. 踩坑速查(2026-08-18 IO 组态实测;完整版见 ctrlx-ai-coding/docs/ioe_scripting_playbook.md)
1. **IO 工程绝不用 PLE 打开**(2.6.8 版本转换 + 实例崩溃)→ IOE 2.6.4 + `scripts/ioe/ioe_ipc.ps1` 驱动。
2. 模态对话框占住 IDE 主线程 = 一切 IPC 超时:避免触发对话框;疑似时截图诊断(CopyFromScreen)+ SendKeys ENTER 解除。
3. 崩溃/强退残留 `.~u` 锁:确认 0 个存活 ctrlX-*-Engineering 进程后再删;`Environment.Exit(0)` 强退会导致下次打开弹 already being edited,应 `p.close()` + terminate 优雅退出。
4. ready.signal 后插件未装完:`remove()` 报 Value cannot be null → 等 `se.system.background_loading_of_libraries_finished` 为 True 再重试。
5. PowerShell:`Remove-Item` 被策略拦截 → `[System.IO.File]::Delete`/`Copy-Item`;控制台 cp1252 回显中文乱码 ≠ 文件坏 → 一律 ReadAllText/WriteAllText UTF8,勿信回显。
6. IOE ScriptEngine 4.1:`se.projects` 不可迭代;`active_application` 在 IO 工程抛异常;通道符号在 PLC 工程 I/O 映射,IO 侧脚本 API 不可见。
7. git push 的 stderr 是 PowerShell 表面报错,看 exit code;MCP 超时命令可能稍后迟到执行;eval_python 不传 timeoutMs。
8. CpStudio Post-export hook 只写 `data/requests/pending/`；先运行离线消费者审阅报告，再由唯一 persistent MCP 会话执行第二阶段，hook 本身不得启动 PLE/MCP。
