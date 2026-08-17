# BPP_ResistantStation — 电阻测试台

一句话定位:电阻测试台(Resistance Test Bench)的工位软件 —— 基于 Bosch OpCon V5.11 / ctrlX,覆盖 PLC 测量流程逻辑、工位状态管理与测量数据记录。

## 功能 / 目标
- 电阻测量工艺逻辑(PLC,IEC 61131-3 ST)
- 工位状态机 / 模式管理(对齐 OpCon 规范,参考 Station010)
- 测量数据记录与追溯
- HMI(OpCon Modulo,后期)

## 快速上手
本项目经 CODESYS MCP 开发,无需手工打开 IDE:
```text
1. 确认 codesys MCP(persistent 模式)状态 ready
2. create_project → src/ResistantStation.project
3. compile_project 验证编译
4. set_simulation_mode(true) + connect_to_device 做仿真测试
```

## 仓库结构
```
├── AGENTS.md      AI Agent 工作指南(先读)
├── HANDOVER.md    会话交接状态
├── TODO.md        任务清单
├── docs/          技术文档(需求/架构/结论)
├── src/           源码(CODESYS 工程将建在此)
├── tests/         测试
├── data/          原始数据(机器生成,大文件入 .gitignore)
├── examples/      示例
└── tools/         辅助脚本
```

## 相关仓库 / 文档
- 参考工位:`../Station010_0708`(OpCon V5.11 ctrlX 标准工位,只读)
- 标准库:`../Std`(OpCon/Nexeed 标准组件,只读)
- 开发模板:`vibe-coding-templates/`(github.com/SOLASOLAo/vibe-coding-templates)
- 原始资料:`../电阻测试台.pdf`、`../BPP_ctrlX.zip`(不入 git)

## 版权说明
- OpCon / Nexeed / ctrlX 为 Bosch 商标,相关参考代码与组件仅限本工程内部使用