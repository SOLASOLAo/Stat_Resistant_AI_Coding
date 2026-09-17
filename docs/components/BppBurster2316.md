# BppBurster2316 0.1.0.2

自有通信 Peripheral + PLC 库；Company 为 BPP Internal Engineering，Author 为 WANG Zhi (RBCD\TEF2)。通过标准 IBursterResis2316 Channel 连接原厂 Burster Resistomat 2316 Unit/HMI。自有对象放在 PrjExt/Peripherals/BppBurster2316/V0.1。

CpStudio 的 Measurement → BPP Internal Engineering 目录显示名为 **BPP Burster 2316**，使用电阻仪图标。local-rev3 补齐图标并统一目录命名；库版本、二进制和接口不变。

在 Peripheral 参数中配置 Hostname、RequestedProgramNo（0..15）、MeasurementTimeoutMs（正整数）。原生生成器会配置唯一 BppIpBurster2316 实例。选择原厂 Unit 的通信接口时，选择该 Peripheral 的 Channel；参考中为 BppBurster23161 → BursterResistomat23161。

库中的 BppIpBurster2316 继承既有单连接驱动，并实现框架 IOpconPeripheral 生命周期；这些生命周期入口不发测量命令。业务只通过原有通信方法执行。保留通信方法、错误码、Ω 单位、首错锁存、取消清理和未知结果不自动重放行为。同一仪表只能有一个驱动实例负责连接、选程、测量及清理，不能同时启用原厂 IP 驱动或本站旧并行选程驱动。

本库不含本站左右位置、压缸控制、TypeData 上下限或结果合格判定。参考地址为 127.0.0.1，不代表现场设备地址；Consumer.project 仅验证接口与依赖，不主动打开连接。

验证包含独立源库新编译、独立消费工程新编译、原生 Peripheral 插入与 Channel 绑定、导出保存重开，以及原厂 HMI 的 9 个实际变量绑定。协议模型覆盖正常测量、选程失败、超时、取消、断线、旧结果隔离；模型结果与 PLC 执行/实体仪表验收分开记录。

安装见 INSTALL.md，实际依赖与警告见 DEPENDENCIES.json 和 evidence。旧 0.1.0.1 与 Station010 当前选用版本均不变。
