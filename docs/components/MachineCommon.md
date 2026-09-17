# MachineCommon 0.1.0.0

只包含 FB_OperatorButton、FB_MainPressureControl、FB_MaintenanceDoorControl 三个 FB；保留本站原始输入输出、计时和运行行为。Company 为 Internal Engineering。压力模拟 FB 位于 examples，不编入库。

CpStudio 目录显示名为 **Machine Common**，使用按钮、压力表和维修门组合图标。库与对象使用通用名称；已在 CpStudio V5.11 / ctrlX PLC 2.6.8 完成新编译和实际 Station010 接入。

PLC 直接消费时使用 MachineCommon 命名空间。CpStudio 可插入 PrjExt/Objects/MachineCommon/V0.1 对象，生成 Button、Pressure、Door 三个变量及一个最小 OpconAddonBase 派生对象。应用在已归属的 OnCall 钩子中按原有顺序调用三个 FB、连接实际输入输出；对象不会自行驱动阀或把缺失反馈当成正常。

本库直接依赖只有 Standard 3.5.18.0；CpStudio 外壳依赖工程中的 NxAddonBase。独立消费工程包含 19 项自检，覆盖按钮完成/复位、气压转换超时/恢复、维修门反馈缺失/保持/复位。本通用命名库、独立消费及解包消费均新编译 0 errors / 0 warnings，本轮未执行 PLC 模拟或实体 I/O。

此前 BppMachineCommon 版本曾在本地 PLC 模拟器执行 19 项，失败位为 0。原始报告与数值判定在 evidence/historical/common-simulation-05.json、common-simulation-evaluated.json；原报告 passed=false 来自 INT#19 / DWORD#0 的字符串比较，原始记录未改写。这是历史 PLC 模拟证据，不能记作本通用命名二进制的新执行或现场验收。

Consumer.project 是无 I/O、无通信的测试工程。FB_PressureFeedbackSimulation.st 仅用于离线示例，不能隐式替代现场反馈。安装见 INSTALL-GENERIC.md。

包内 evidence/unpacked-consumers.json 保存当前解包新编译收据，evidence/package-revision.json 说明本次文档修订与未变的程序载荷。

本次通用命名包提供本组件 PrjExt、compiled-library、源码与最小 PLC Consumer.project；实际 CpStudio 接入证据来自保存重开的 Station010。旧四组件 CpStudio 隔离参考模型仍在此前 rev3 包中，未把它冒充本次重新生成的最小模型。
