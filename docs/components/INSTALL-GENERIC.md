# 通用命名候选包安装

仅验证 CpStudio V5.11 / ctrlX PLC 2.6.8。原厂 Std 为外部依赖；此包不包含原厂 DLL，不执行下载或 IPC 部署。

1. 解包到新目录，运行 `scripts/Test-ComponentPackage.ps1 -PackageRoot <目录>`。
2. 使用新的隔离 PrjExt，运行 `scripts/Install-NativeComponent.ps1 -PackageRoot <包目录> -PrjExtRoot <参考目录/PrjExt>`。重复安装只校验；已存在不同内容则停止。
3. 在唯一 PLE 会话安装本组件 Library 目录中的 compiled-library；核对 DEPENDENCIES.json。`reference/Consumer.project` 是最小 PLC 消费工程，无物理 I/O。不要使用 IO 工程代替 PLC 工程。
4. 在已有的隔离 CpStudio 5.11 工程加入该 PrjExt 搜索目录，Reload object definitions，插入对象并按 README 选择参数/Channel；保存、关闭、重开后 Fast PLC export，HMI 单独 Export。
5. ForceTrace 数据父节点设为 Read，四个整数组由对象导出；检查实际 Symbol XML 与 SFC。执行新的 Generate code，记录错误和警告。HMI HAD 通过原生 HMI add-ons 注册。

通用库名及命名空间为 ForceTrace、MachineCommon、Burster2316，Company 为 Internal Engineering。旧 Bpp 候选保持归档；同一模型不能同时插入新旧相同 RefId 对象。Burster 驱动类型为 Burster2316Peripheral，避免与原厂 IpBurster2316 重名；原厂 Unit 使用标准 IBursterResis2316 Channel。

当前完整 PLC Export 仍受原厂 Symbol REST 流缺陷影响。只读 datatype 全量枚举在本站也可能报 duplicate-key；这不是新编译的结果，使用已生成 Symbol XML 和原厂 HMI 加载器核验，不重放失败的写入。

实际 Station010 集成记录、版本选择、恢复点和现场待验项目见 STATION010-NATIVE-20260916.md。本包附最小 PLC 消费工程；完整 CpStudio 安装验证使用实际 Station010，旧隔离 CpStudio 参考模型继续保留在上一版包。
