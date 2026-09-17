# Burster2316 0.1.0.2

自有通信 Peripheral + PLC 库；Company 为 Internal Engineering，Author 为 WANG Zhi (RBCD\TEF2)。通过标准 IBursterResis2316 Channel 连接原厂 Burster Resistomat 2316 Unit/HMI。自有对象放在 PrjExt/Peripherals/Burster2316/V0.1。

CpStudio 的 Measurement → Internal Engineering 目录显示名为 **Burster 2316**，使用电阻仪图标。库与 Peripheral 使用通用名称；已在 CpStudio V5.11 / ctrlX PLC 2.6.8 完成新编译和实际 Station010 接入。

在 Peripheral 参数中配置 Hostname、RequestedProgramNo（0..15）、MeasurementTimeoutMs（正整数）。原生生成器会配置唯一 Burster2316Peripheral 实例。选择原厂 Unit 的通信接口时，选择该 Peripheral 的 Channel；本站实际为 Peripherals._Burster2316 连接 Wp100A103ResistantDetector 的原厂 Unit。旧隔离参考中的 Burster23161 / BursterResistomat23161 是示例实例名。

库中的 Burster2316Peripheral 继承既有单连接驱动，并实现框架 IOpconPeripheral 生命周期；这些生命周期入口不发测量命令。业务只通过原有通信方法执行。保留通信方法、错误码、Ω 单位、首错锁存、取消清理和未知结果不自动重放行为。同一仪表只能有一个驱动实例负责连接、选程、测量及清理，不能同时启用原厂 IP 驱动或本站旧并行选程驱动。

本库不含本站左右位置、压缸控制、TypeData 上下限或结果合格判定。参考地址为 127.0.0.1，不代表现场设备地址；Consumer.project 仅验证接口与依赖，不主动打开连接。

当前独立源库、独立消费工程及解包消费工程新编译均为 0 errors / 0 warnings；消费工程同时引用原厂 NexeedIpBurster2316，已验证类型名可共存。本站原生 Peripheral / Channel 绑定、导出保存重开证据在 evidence/cpstudio-native.json、station-native.json。此前原厂 HMI 的 9 个变量绑定和 18 项协议模型作为历史验证保留，覆盖正常测量、选程失败、超时、取消、断线、旧结果隔离；不等于本次连接实体仪表验收。

安装见 INSTALL-GENERIC.md，实际依赖与警告见 DEPENDENCIES.json 和 evidence。旧候选保留；Station010 已选择本通用命名候选，见 STATION010-NATIVE-20260916.md。

包内 evidence/unpacked-consumers.json 保存当前解包新编译收据，evidence/package-revision.json 说明本次文档修订与未变的程序载荷。

本次通用命名包提供本组件 PrjExt、compiled-library、源码与最小 PLC Consumer.project；实际 CpStudio 接入证据来自保存重开的 Station010。旧四组件 CpStudio 隔离参考模型仍在此前 rev3 包中，未把它冒充本次重新生成的最小模型。
