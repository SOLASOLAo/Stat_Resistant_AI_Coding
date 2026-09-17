# 电阻测试台

基于 Bosch OpCon V5.11 / ctrlX 的三位置电阻测试工位。CpStudio 维护模型与 Modulo HMI，本仓库保存 PLC 应用逻辑、HMI 自有扩展、规格和工程辅助工具。独立 Windows HMI 保留为 A/B 原型。

## 日常入口

- 接续现场工作：[当前交接](HANDOVER.md)；选择工作：[待办与验收条件](TODO.md)。
- 规则与工程定位：[AGENTS](AGENTS.md)、[config/project.yaml](config/project.yaml)。
- PLC 修改：先定位对应 specs / ai 归属 / src/plc 源码，再由唯一 PLE 的正式 MCP/REST 修改、保存回读并做相关新编译。
- 模型、生成接口或 HMI 结构变化：走 CpStudio；只核对受影响的生成代码、绑定、资源和符号。
- 文档与只读问答：直接完成相应内容或检查，不运行工程编译/导出流程。

当前本地版本与现场版本可能不同，以 HANDOVER 的已验证记录为准；离线编译不代表已下载或现场验收通过。

当前本地已接入 ForceTrace、MachineCommon、Burster2316 原生组件，ForceTrace PLC 库、对象和 HMI 为 0.2.1.0：PLC 保存三位置数据并计算滚动 3σ；HMI 约 100 ms 更新曲线、密度直方图和正态参考线，并在页面下方显示中英文采样与判稳说明。采样周期在 CpStudio 的 Station → Parameters → ForceTrace → SamplePeriodMs 配置，当前 6 ms，必须匹配实际 MainTask。压力门槛、3σ 标准、统计窗口和总超时来自 StationData，与采样周期在每个位置开始时锁存。本站保存的 3σ 初值为 5 N，保留用户活动数据，0 仍表示未配置、禁止放行。本次需配套更新 PLE、HMI 和扩展 DLL；四数组绑定、两种 CSV 及更新步骤见[力曲线扩展](docs/hmi_force_trace_addon.md)。

## 按需资料

| 需要做什么 | 入口 |
| --- | --- |
| 新同事 / 新电脑安装 | [TEAM_SETUP](TEAM_SETUP.md) |
| CpStudio 导出、Symbol、BMK 或 I/O 同步 | [工程工作流](docs/cpstudio_git_mcp_workflow.md)、[当前完整 Export 缺陷](docs/reviews/cpstudio-symbol-stream-20260911.md) |
| HMI 电阻显示 / 力曲线 / 中文 | [电阻接入](docs/hmi_resistance_cpstudio_steps.md)、[力曲线扩展](docs/hmi_force_trace_addon.md)、[本地化](docs/hmi_localization.md) |
| 工程控制台 | [控制台说明](docs/engineering_console.md)；[启动脚本](scripts/workbench/Start-CtrlXOpconWorkbench.ps1) |
| Runner / Host / Project Pack | [产品路线与工具说明](docs/productization_roadmap.md)、[Runner 入口](scripts/runner/Invoke-CtrlXOpconRunner.ps1) |
| 离线导出检查器 | [工作流中的使用条件](docs/cpstudio_git_mcp_workflow.md#断网时的本地检查)、[检查器入口](scripts/cpstudio/Run-OfflinePostExportCheck.cmd) |
| 独立原生组件包与源码候选 | [四套本地包总索引](docs/components/LOCAL-PACKAGES-20260916.md)、[组件说明](components/README.md)、[Station010 使用入口](components/station010/START-HERE.md) |
| 独立 Windows HMI A/B | [原型与验收说明](docs/self_hmi_parallel_poc.md) |
| 跨项目复用 | [目录约定](docs/project_structure_standard.md)、[初始化器](ctrlx-ai-coding/scripts/New-CtrlXOpconProject.ps1) |
| 历史结论与旧版完整操作说明 | [归档](docs/archive/2026-09-14-framework-simplification/README.md) |

控制台、Runner 和离线检查器是各自任务的可选入口，不要求日常修改依次跑完。哈希、清单和请求编号留在需要它们的工具内部。启动独占检查器前须满足其无既有 PLE/MCP 会话条件，不为使用它而强关当前工程。

## 目录

| 位置 | 内容 |
| --- | --- |
| ../Station010 / ../Std | 受控集成工程 / 原厂只读组件 |
| config / specs / ai | 环境、需求、对象归属及混合钩子 |
| src/plc / src/hmi | PLC 可读源码、Modulo 自有扩展和独立 HMI 原型 |
| catalog / scripts / tests | 已验证接口、工程入口、按改动选择的检查 |
| components / docs / data | 组件说明、技术资料、本地恢复点和证据 |

协作规则参考 [vibe-coding-templates 0.2](https://github.com/SOLASOLAo/vibe-coding-templates/blob/main/docs/TEMPLATE_GUIDE.md) 按需合并；已有 Git 历史、工程目录和工具保持原有管理方式。OpCon / Nexeed / ctrlX 相关闭源组件仅限许可范围内使用，不随本项目源码分发。
