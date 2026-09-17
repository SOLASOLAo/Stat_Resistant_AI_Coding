# 本地原生组件候选包安装

本包用于隔离工程验证，版本来自 RELEASE.json，与 Station010 的 component-versions.json 无关。仅核验 CpStudio V5.11 / ctrlX PLC 2.6.8；原厂 Std、设备固件、现场负载与实际 HMI runtime 验收不由本包替代。

1. 解压到新目录，运行 `scripts/Test-ComponentPackage.ps1 -PackageRoot <解压目录>`。
2. 包内 reference/Consumer.project 是本库最小 PLC 消费工程；reference/CpStudio 是已保存的共用集成参考模型，包含四组件及两个 ForceTrace 实例。PrjExt、StationTemplate、外部 Std 同级。Std 由已有合规安装提供，不包含在本包；集成参考中的自有 PrjExt 及模型引用的 HMI 页面已齐备。先复制 reference/CpStudio 到新的工作目录，保留原解包目录供清单校验。
3. 关闭目标模型，运行 `scripts/Install-NativeComponent.ps1 -PackageRoot <解压目录> -PrjExtRoot <隔离工程/PrjExt>`。只复制本组件的 Objects/Peripherals，遇到不同内容会停止。已安装且字节相同的文件只核对，不覆盖。
4. 唯一 PLE 会话中安装 PrjExt 对象 Library 目录的 compiled-library。查看 DEPENDENCIES.json 中的实际解析版本。源库在 plc 目录，消费工程在 reference/Consumer.project；不要用 IO 工程代替 PLC 工程。
5. CpStudio 中 Reload object definitions，插入本组件并完成参数/Channel 选择。按组件 README 接线后 Save All；关闭、重开核对，再执行 PLC Fast export 和 HMI 单独 Export。
6. 检查 PLE Symbol Configuration：ForceTrace 数据实例及其四个整数组成员为 Read；原厂 Burster Unit/Extension 按原厂模型配置。不要发布每个数组元素为独立 Item。执行新的 Generate code/Build，核对错误与警告签名。

参考环境的完整 PLC Export 存在原厂 Symbol REST JSON 流错误。本次通过 Fast export、独立 HMI Export、原生 Symbol 配置及新编译完成验证；不能把完整 Export 标为通过，也不要盲目重复失败请求。验证记录包含这一限制。

ForceTrace HMI 0.2.0.0 的 HAD 位于 hmi 目录，仅在获准的本地工程 HMI add-ons 中注册。运行时需要原厂 Hmi_V5_11；本安装脚本不修改 Std，不注册 HMI，不部署 IPC。原厂 Burster Unit/HMI 从 Std 使用，不随包复制原厂 DLL。

升级、回退均在新参考目录选择对应候选包进行；旧包保留。现场部署、设备参数确认和实体测试另按项目授权安排。
