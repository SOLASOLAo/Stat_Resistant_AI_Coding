# BppMachineCommon 0.1.0.0

只包含 FB_OperatorButton、FB_MainPressureControl、FB_MaintenanceDoorControl 三个 FB；输入输出及运行行为与本站原始源码逐字节一致。Company 为 BPP Internal Engineering。压力模拟 FB 位于 examples，不编入库。

CpStudio 目录显示名为 **BPP Machine Common**，使用按钮、压力表和维修门组合图标。local-rev3 补齐图标并统一目录命名；库版本、二进制和接口不变。

PLC 直接消费时使用 BppMachineCommon 命名空间。CpStudio 可插入 PrjExt/Objects/BppMachineCommon/V0.1 对象，生成 Button、Pressure、Door 三个变量及一个最小 OpconAddonBase 派生对象。应用在已归属的 OnCall 钩子中按原有顺序调用三个 FB、连接实际输入输出；对象不会自行驱动阀或把缺失反馈当成正常。

本库直接依赖只有 Standard 3.5.18.0；CpStudio 外壳依赖参考工程的 NxAddonBase。独立消费工程包含 19 项自检，覆盖按钮完成/复位、气压转换超时/恢复、维修门反馈缺失/保持/复位。执行结论见 evidence/common-simulation.json；PLC 模拟执行不替代实际按钮、阀、安全继电器和门反馈验收。

Consumer.project 是无 I/O、无通信的测试工程。FB_PressureFeedbackSimulation.st 仅用于离线示例，不能隐式替代现场反馈。安装见 INSTALL.md。
