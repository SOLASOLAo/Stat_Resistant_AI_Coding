# 2026-09-14 文档精简归档

用户明确触发本地文档与协作规则整理。这里的 before 文件均为修改前逐字节副本，包含当时未提交内容；原相对路径按原文件所在目录解释，未改写历史正文或删除旧包。它们是历史资料，不是当前指令。当前入口为 [AGENTS](../../../AGENTS.md)、[HANDOVER](../../../HANDOVER.md)、[TODO](../../../TODO.md)、[README](../../../README.md)。

| 原文 | 用途 |
| --- | --- |
| [AGENTS.before.md](AGENTS.before.md) | 原规则、环境事实、临时授权及进度快照 |
| [HANDOVER.before.md](HANDOVER.before.md) | 完整历次交接，含 2026-09-14 PartCounter 离线收尾 |
| [TODO.before.md](TODO.before.md) | 全部旧待办、已完成项及技术流水 |
| [README.before.md](README.before.md) | 旧版完整导出、Runner/Host、初始化与交付说明 |
| [ctrlx-ai-coding.AGENTS.before.md](ctrlx-ai-coding.AGENTS.before.md) | 本地母工程原规则 |
| [ctrlx-opcon-engineering.SKILL.before.md](ctrlx-opcon-engineering.SKILL.before.md) | 仓库 Skill 原入口 |
| [project-contract.before.md](project-contract.before.md)、[plc-offline-development.before.md](plc-offline-development.before.md) | 原工程约束与验证说明 |
| [cpstudio_git_mcp_workflow.before.md](cpstudio_git_mcp_workflow.before.md) | 原本站工程工作流 |

合并参考已读取的 [0.2 模板说明](https://github.com/SOLASOLAo/vibe-coding-templates/blob/main/docs/TEMPLATE_GUIDE.md)、[模板 AGENTS](https://github.com/SOLASOLAo/vibe-coding-templates/blob/main/AGENTS.md) 和 [协作说明](https://github.com/SOLASOLAo/vibe-coding-templates/blob/main/docs/MODEL_GUIDANCE.md)（2026-09-13）。只合并按需资料、已有授权持续有效、验证与改动匹配及 Git 范围规则，未重新初始化 Git 或替换工程架构。

待办处理原则：

- PartCounter 更新、三位置电阻、晚开曲线/CSV/语言、换型及故障场景保留为当前现场验收。
- 按钮、力、Home/Run、位置反馈、主气压和维修门的重复验证合并，旧位号与详细步骤保留在原清单。
- 旧双连接候选、旧单次 MP1 命令和“首次完整自动未完成”等中间状态，由后续单连接接入、选程恢复及一轮完成记录承接；不重新执行已消耗的单次授权，也不把一轮成功当作全部验收。
- Burster 独立库、完整 Export、Project Pack 旧测试、请求归档、检查器、新电脑、P2–P4、自研 HMI 与商业交付仍有对应条目。已延期工作不自动启动。
- DeleteWpcData、遗留模型清理和专用事件保留为待需求决定；旧提案编号不视为已批准实现。READ_DATA 完整仪表曲线保留为追溯需求条件项。
- 原“逐个设备生成→提交”的实验方式转为适用的工程检查规则；已有生成分析保留在原文及相关 review，不作为重复待办。

仅调整仓库内的 Skill 源和项目读取边界，未安装 Skill、未修改个人全局配置。已安装副本的旧措辞不能扩大用户明确限定的本站任务范围；纯文档工作不要求工程启动或全套测试。

本轮只检查文档、链接、规则、待办归属、归档完整性和工程文件保持情况，没有编译、启动/接管 IDE、PLC 操作、IPC 部署或 GitHub 推送。内部核对记录位于 data/reports/framework-simplification-20260914（相对 McpCoding 根），不构成新的日常流程。等待用的 automation-2 已暂停，不再安排跟进。
