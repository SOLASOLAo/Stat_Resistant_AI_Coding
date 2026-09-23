# 电阻测试台协作约定

本目录是 Station010 的 AI 工程旁车。CpStudio 管模型与生成结构，AI 经正式 PLE MCP/REST 维护声明归属的应用逻辑。当前状态见 [HANDOVER](HANDOVER.md)，任务见 [TODO](TODO.md)。

## 工程边界

- 任务与授权明确时，完成必要的实现、验证、修复和交付，不停在计划或第一版实现。遇到真实阻塞说明具体缺口，并继续不依赖它的工作；不把一次任务扩展为长期后台工作。
- CpStudio 拥有 Station/Mode/Command 层级、标准对象、HMI、事件、StationData/TypeData、BMK 和生成接口，包括 VAR_INPUT/VAR_OUTPUT、类型、方向及 OES Declaration 区。模型或接口缺失时，通过已授权的 CpStudio 操作补齐再导出，不经 PLE 强补生成接口。
- PLC 对象只经预期的 PLE ScriptEngine/MCP、官方 REST 或原生编辑器修改，禁止编辑 .project 字节。IO 工程使用对应 IOE，不能用 PLE 打开。
- 同一工程/profile 只保留一个 PLE 写入者。先确认现有会话与目标，不启动第二实例、不抢锁、不强关用户 IDE。Post-export hook 只发布请求。2026-09-15 的 v1 后台启动自动恢复例外已随 PLC 缓冲版曲线退出使用；v2 不依赖 BppForceTraceStartup，禁止旧恢复工具给 v2 补回 HMI 采集器。
- 工程写入前核对路径、对象归属、已有改动和可恢复起点；已有准确恢复点时复用。保存后回读受影响对象，做相关编译；CpStudio 生成后核对 ownership/hooks/graphical 及受影响的 Symbol/HMI/I/O。混合对象只合并声明的钩子。
- Std 原厂内容只读，不改、不删、不移动。用户明确批准的自有扩展例外按交接中记录的范围执行；例外不扩展到原厂 DLL、其他文件或现场部署。
- 实体 PLC 连接、下载、runtime 启停、写值/FORCE、测量/运动及 IPC 部署须在用户明确授权范围内执行。已有授权对相同任务持续有效，不重复询问已批准的常规步骤；新增目标或超出范围再确认。离线实现授权不代表现场操作授权。
- 超时、断连或结果不明时先核对执行状态，不自动重放写入/运动。write_variable 可能是持续 FORCE，须明确解除；不以强写状态、跳过联锁或清空未实现步骤伪装成功。
- 保护凭据、用户数据和未提交改动。只输出必要字段，工程连接文件先脱敏。Station010 禁止整体暂存；不新增纳管加密工程、闭源库、缓存、原始资料和 data 运行记录。提交/推送按明确授权及已审阅范围进行，不因会话结束而自动执行。

## 环境与定位

| 用途 | 事实或入口 |
| --- | --- |
| 工程路径与版本 | [config/project.yaml](config/project.yaml)；集成工程位于 ../Station010 |
| PLC / IO | PLE_V_0206，profile 精确为 ctrlX PLC 2.6.8；IOE 2.6.4 |
| PLC 工程 | ../Station010/Plc/Stat010_V5.11_CtrlX_PLC.project |
| PLC 通道 | codesys-persistent 或已有唯一 PLE 的官方 REST；本机基址 http://localhost:9002/plc/engineering/api/v2 |
| 编译 | 新 compile_project 或原生 Build/F11；get_compile_messages 只是缓存 |
| 工作站依赖 | [TEAM_SETUP](TEAM_SETUP.md)；MCP 升级后按补丁说明核对兼容性 |

## 按任务读取

| 当前需要 | 读取入口 |
| --- | --- |
| 了解用途和使用方式 | [README](README.md) |
| 接续工作或状态不明 | [HANDOVER](HANDOVER.md)；选择任务时再读 [TODO](TODO.md) |
| PLC / SFC 修改 | 对应 specs、src/plc、[ownership](ai/ownership.yaml)、[hooks](ai/hooks.yaml)、[graphical](ai/graphical.yaml) |
| CpStudio 导出、Symbol 或 I/O 问题 | [工程工作流](docs/cpstudio_git_mcp_workflow.md) 的相关章节和该故障的 review |
| HMI 电阻 / 曲线 / 中文 | [电阻接入](docs/hmi_resistance_cpstudio_steps.md)、[曲线](docs/hmi_force_trace_addon.md)、[本地化](docs/hmi_localization.md) 中与任务有关的部分 |
| Runner、团队部署、组件交付 | 从 README 的按需资料表进入 |
| 历史决策 | [历史归档](docs/archive/2026-09-14-framework-simplification/README.md)，仅查需要的记录 |

母工程 ctrlx-ai-coding 和模板是技术参考，按相关任务查阅；其中的历史进度、示例流程与全局会话要求不自动成为本站操作前提。本项目按用户最新要求和本文件处理范围、授权、验证及 Git。

## 验证与记录

- 验证与实际改动匹配。文档只查内容、链接及规则一致性；PLC 修改做对象回读、相关静态检查和新编译；HMI 修改查绑定、资源及对应加载/导出。涉及组件清单内源码时再做相应组件 Check。
- 检查通过即继续交付；只有新改动、失败或未解决问题才扩大/重复测试。不把只读问答变成编译、导出、打包或平台测试矩阵。
- 区分源码检查、编译、合成测试、部署和现场验收；报告实际结果与未验证内容。新警告按签名审阅，不能只用错误数或旧缓存证明通过。
- Skill 按任务使用。工程 Skill 的工程写入门禁用于实际 CpStudio/PLE/IOE 工作；纯文档整理不触发 IDE、工程检查器或编译。减法审查按需进行，不设每轮或每阶段强制审查，也不成为产品运行依赖。
- 状态、决策、阻塞或下一步变化时更新 HANDOVER/TODO，使用方式变化时更新 README；纯问答无需改交接。历史和详细证据另存，AGENTS 不维护进度流水。哈希/清单保留在需要它们的工具内部。

## PLC 代码约定

- ST 独立条件写成 ( Condition )；复合条件的 AND/OR 放前一行末尾。修改 ST 时按影响运行 [Test-ProjectFramework.ps1](tests/static/Test-ProjectFramework.ps1) 等相关检查。
- 位置反馈使用 OutImm.IsInBasPosIn / OutImm.IsInWrkPosIn，保留 Unit 完成握手、安全继电器及标准诊断；普通位置输入不能代替安全功能。
- SFC 保留真实等待、错误和取消处理。并行分支在动作完成后各自保持完成，再汇合；无 Action 或仅注释的步骤不能等待不存在的完成结果。

## 可读性与模块化原则

**1. Codex 可读性：让人和 Codex 都能快速定位、理解和验证代码。**

- 使用明确、统一的功能命名；入口、调用关系和状态流转应可直接追踪，不依赖历史对话才能理解。
- 对外接口说明输入输出、单位、有效条件、完成条件和错误语义；复杂逻辑的注释解释原因与约束，不重复代码字面意思。
- 保留与工程同步的可搜索 ST 快照；关键逻辑关联对应规范依据和测试入口。文档维护唯一事实源，避免多份说明互相矛盾。

**2. 功能模块化设计：按职责和变化边界拆分，不为拆分而拆分。**

- 按职责区分外部交互、业务规则、项目流程、HMI 展示及工程工具；业务规则由所属模块维护，避免多处重复实现。
- 模块通过明确的公开接口交互，明确状态所有者；不得跨模块直接修改内部状态。PLC 接口需明确触发、忙碌、完成、失败、取消及复位语义。
- 优先复用官方对象、标准库和现有实现；只有独立职责、实际复用或独立验证需求时才新增模块。不强制文件行数，不预建通用框架，不拆成大量薄包装。

### 适用范围

- 两项原则用于后续新增和实际触及的修改，不要求一次性整理整个项目。
- 保持既有 CpStudio/AI 所有权边界及公开接口兼容约束。
