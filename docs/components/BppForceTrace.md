# BppForceTrace 0.2.0.0

PLC 采集/滚动统计/v2 数据帧 + NxAddonBase 对象，配套 HMI 0.2.0.0。HMI 只消费 PLC 缓冲，不要求先打开页面。自有对象安装到 PrjExt/Objects/BppForceTrace/V0.2；Company 为 BPP Internal Engineering。

CpStudio 目录显示名为 **BPP Force Trace**，使用曲线图标。local-rev3 补齐图标并统一目录命名；PLC/HMI 库版本、二进制和接口不变。

## CpStudio 绑定

对象实例的七个参数通过原生变量选择器连接：

| 参数 | 类型 | 来源及含义 |
| --- | --- | --- |
| ForceN | REAL | 工艺力值，N |
| QualityGood | BOOL | 力值通信/采样质量有效 |
| Measuring | BOOL | 工艺采集状态，START 确认到 END/取消/首错 |
| ThresholdN | REAL | StationData 门槛，参考 2500 N |
| LimitN | REAL | StationData 3σ 标准，参考 0 表示未配置 |
| WindowMs | DINT | StationData 滚动统计窗口，参考 1000 ms |
| TimeoutMs | DINT | StationData 总判稳超时，参考 30000 ms，必须大于窗口 |

导出 StartupParams 使用 REF= 连接以上原生变量和本实例的数据结构。参数不会复制到另一套 HMI 可写变量。PreparePosition 在每个位置锁存四个工艺参数，途中修改从下一位置生效；无效参数不能放行测量。

对象生成 LeftFrame/MiddleFrame/RightFrame（各 DWORD[0..30035]）和 StatisticsFrame（DWORD[0..209]）。随附视图从对象数据变量的 HmiFullName 生成四个整数组 Item；因此改名、换父节点或第二实例不会依赖 Station010 的固定路径。local-rev3 参考实例为 Station.ForceTrace 和 Wp100.Trace2；数组含义仍按夹具左/中/右。

实例改名后需要同时重新导出 PLC 和 HMI。Fast export 只更新 PLC 代码，HMI 单独 Export 才重新生成页面中的 Item；再核对新实例的 Symbol Read 权限并移除旧名字的选择。当前完整 PLC Export 的原厂流问题仍存在，参考工程已通过原生 Symbol API 完成对应权限迁移，不能省略这一步。

## PLC 调用顺序

OpCon 框架通过 protected OnCall 周期调用采集器，并在发布时更新本实例数据。应用不要再次直接调用 Addon/Recorder 的 FB body。工艺流程负责显式生命周期方法：父循环开始调用 Recorder.BeginCycle；每位置 preflight 调用 PreparePosition 并检查返回值；采集 START 确认后调用 Recorder.Start(Position, InitialForceN)。下压到位后的每扫描调用 Recorder.Evaluate(ValueN, Healthy, AtWork)，只有 TRUE 才允许电阻仪启动。测量期间继续 Evaluate，首错优先于正常完成。

正常结束先 FreezeStatistics、RequestEnd，再等待仪表 END/状态完成；Finish(Reason, LastForceN) 保留原因。取消与异常按照应用的已确认流程结束采集，不能据 FALSE 自动抬缸或重放测量。方法定义及调用骨架随源码提供；Kistler 联锁、Station 自动流程、TypeData 判定属于应用参考，不进入通用库。

## 首版数据能力

三位置，每位置保留开始后的前 60 s / 10001 点；名义 6 ms 主任务采样、100 ms 发布，记录实际 PLC elapsed_ms。采样受调用周期约束，须在目标 PLC 验证任务时间和负载，库本身不创建实时任务。超出容量标记截断，统计继续。

统计使用完整时间窗口与样本标准差（n−1）：力严格大于门槛、3σ 严格小于标准才判稳，等于边界不放行。3σ 是标准差的三倍，单位仍为 N。密度直方图使用同一 PLC 窗口；正态 PDF 是参考线，不声明实际数据服从正态分布。

保存提供完整记录、首次判稳点起两种 CSV；无判稳点或该点已超出保留容量时提示且不生成文件。晚开页面/重连读取 PLC 保留帧；新父循环清空旧循环。统计 FB 可单独用于 PLC，不依赖 HMI。

独立库与消费工程新编译均通过；844 数值检查、原生四个 Item 编辑器、三位置帧/两轮/晚开/重连/截断/两种 CSV 合成测试已记录。原生中文/英文离线预览已检查，实际 HMI runtime 语言切换、实时负载与实体工艺尚未验收。安装见 INSTALL.md。
