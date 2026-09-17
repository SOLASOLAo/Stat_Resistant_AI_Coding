# 当前交接

> 2026-09-16 当前接入更新：已将 Force Trace、Machine Common、Burster 2316 原生对象加入实际 Station010，通用组件已去掉 BPP 前缀，最低 CpStudio/OES 为 5.11。四个力工艺参数与标准 Burster Channel 已生成；17 个应用对象已迁移、回读并保存，9 个重复本地 FB/GVL 根已退役。正在完成新编译、HMI 导出和最终校验，尚不能标为整体验收完成。恢复点与详细状态见 [本站接入记录](docs/components/STATION010-NATIVE-20260916.md)。以下隔离包记录是此前阶段，不能再据此认定本站未修改。

更新：2026-09-16。独立组件封装在隔离参考工程完成，本地交付 Danikor 1.1.0.0、BppBurster2316 0.1.0.2、BppForceTrace 0.2.0.0、BppMachineCommon 0.1.0.0，入口见[本地包总索引](docs/components/LOCAL-PACKAGES-20260916.md)。BPP 包使用独立 schema 3 发布清单，未更改 Station010 选用版本锁及 rc.4。

Station010 继续保持 2026-09-15 20:19 的本地 PLC 力采样、滚动 3σ 判稳和 HMI 0.2.0.0 集成基准。**本次封装未修改其工程、源码快照和参数权限，未下载 PLC、未部署 IPC、未提交或上传 GitHub**。3σ 工艺标准尚未收到，PressForce3SigmaLimit 保留 0（未配置），自动测量不会放行。

## 独立组件交接

- 三个 BPP 库与各自最小消费工程均通过新的原生编译，0 errors / 0 warnings，实际依赖及对象回读随包提供。Company 统一为 BPP Internal Engineering；Danikor 保持原发布身份与二进制。
- CpStudio 隔离模型完成插入、参数选择、Burster 标准 Channel 绑定、ForceTrace 改名/换父节点/第二实例、导出与保存重开。ForceTrace 数据生成四个整数组 Item；框架在 OnCall 调度采集，应用只显式管理每位置生命周期。
- Burster 协议模型 18 项、ForceTrace 数值检查 844 项及原生 HMI 帧/保存检查 29 项通过。BppMachineCommon 在本地 PLC 模拟器实际执行 19 项检查，失败位为 0。模型测试、PLC 模拟执行和实体设备验收分别记录；尚未进行本次实体 FAT。
- 解包参考模型包含 22 张持久化 HMI 页面；Fast PLC export 和 HMI 单独 Export 为 0 errors / 4 条参考对象兼容性 warnings。完整 PLC Export 的原厂 JSON 流问题仍存在，不标为通过。
- 三套 BPP 已更新为 local-rev3：补齐曲线、电阻仪、公共控制图标，目录显示名统一为 BPP Force Trace、BPP Burster 2316、BPP Machine Common；Danikor 的 local-rev3 保持不变。旧包保留，库版本、二进制和接口未改。隔离安装只向 PrjExt 写入自有对象，重复安装校验通过且不覆盖；原厂 Std 为外部依赖。
- 参考曲线实例改为 Station.ForceTrace、Wp100.Trace2；已保存重开、Fast PLC export、HMI 单独 Export、实际 SFC 加载与绑定核验。HMI 模板随导出自动更新名称，旧 Symbol 选择已移除，新父节点与四数组成员均为 Read。
- rev2 解包消费编译为三个 BPP 0/0、Danikor 0/4；本次复用未改的库与最小消费工程，改名后的集成参考重新 Generate code 为 0 errors / 原有 5 warnings（4×OPC.UA.DA、1×ErrorCodes 枚举基型）。rev3 解包和重复安装通过，88 个保护文件 SHA 全部一致。CpStudio 与唯一 PLE 均停留 data/native-packages/20260915/reinstalled-reference 下的同一隔离工程，未返回 Station010。

以下为 Station010 应用基准及其未完成的现场验收，与独立组件发布版本分别管理。

## 当前状态

| 项目 | 已完成 | 下一步 |
| --- | --- | --- |
| 改动前 GitHub 备份 | 私有 SOLASOLAo/Stat_Resistant_Station010；备份分支 backup/force-3sigma-20260915，tag baseline-before-force-3sigma-20260915，commit b93d44a8a57ac33a9d73c2af9496f9e0280dc34a。含保存工程、自有源码及旧 .2 扩展；恢复字节已核对，原工作分支未切换 | 当前 v2 实现留在本地，没有额外推送 |
| StationData 参数 | CpStudio 原生添加 PressForceThreshold REAL/N（2500）、PressForce3SigmaLimit REAL/N（0）；PressForceStableTime 改为“压力统计窗口”，DINT/ms，初值 1000；每位置锁存四参数 | 工艺给出有效 3σ 标准；现场确认活动参数及总超时 >窗口，不能以模型初值代替活动 DAT |
| PLC 采样/判稳 | MainTask 名义 6 ms，PLC 保存三位置各前 60 s/10001 点；100 ms 发布；完整滚动窗口、力严格 >门槛、3σ 严格 <标准才放行；测量中继续监控，首错优先于 DONE | 实体任务周期、仪表更新率、CPU/12 ms watchdog 裕量及过程验收 |
| HMI v2 | 原生 add-ons 注册 0.2.0.0；四个整数组 Item；力曲线、密度直方图+正态参考线；41 项中英文；完整/首次判稳后两种 CSV。保存重开、原生选择器、安装 DLL + 实际 SFC 加载均通过 | 配套更新 PLE/HMI/扩展后验证晚开、重连、两轮、语言切换和 IPC 保存 |
| 导出与编译 | Fast export + HMI 单独 Export：CpStudio 0 errors/原有 2 warnings；20:19 新 F11：0 errors/原有 5 warnings；两个 PLC writer PlanOnly 零操作 | 完整 Export 原厂流缺陷仍待修复；后续生成仍核对符号 |
| 保留范围 | 原 StationData/TypeData 权限保留；IO 工程、TypeData 导出和 UserDefined 与改动前 tag 字节相同；四个新数组及九个电阻成员均为 Read | 现场活动数据、上下限与原有专项验收继续保留 |
| 组件候选 | station010-set-20260911-rc.4 未改；本次新增独立原生组件候选，未升级 Station010 的组件选用锁 | Kistler 工艺仍为集成示例；本站选型/现场升级另行安排 |

## 接续时必须保留的事实

- 电阻：TypeData 两限与原始结果为 Ω，每次按下限≤电阻≤上限判定，包含边界且要求无量程越界。HMI 数字为 mΩ，OK/NOK 来自电阻判定，不来自 Kistler Unit 输出。本次数值/量程/边界回归通过。
- 位置：夹具左/中/右对应工件右/中/左。UserDefined 按工件位置；PLC Result、HMIResistance、曲线和 CSV 保持夹具语义。
- 参数：PressForceStableTime 现为统计窗口，旧固定保持 2 s 已退出使用。四参数在每位置 preflight 锁存，修改从下一位置生效。3σ 标准默认 0 必须由工艺配置；总超时大于窗口。旧现场 DAT 可能仍保留 2000 ms，不自动覆盖活动数据。
- 判稳：样本标准差 n−1，LREAL 计算；完整时间窗口后才比较。力等于门槛重置窗口，3σ 等于标准不放行，掉力不重启总超时。测量中掉力、3σ 超限、数据或位置异常保持首错，结果无效；不自动抬缸或绕过安全联锁。
- 曲线：采集从 Kistler START 确认、下压前 t=0 起，到正常 END、取消或首错。PLC 独立记录，页面晚开读取保留数组；超过容量标记截断但继续统计。下一父级循环/PLC 重启清空旧曲线，长期记录依赖显式 CSV。
- HMI：四个 Item 使用实际生成的 Ch1.L1.Station.HMIForceTraceLeft/Middle/Right 和 HMIForceStatistics。参数随 PLC 快照一起传入，无另一套可写参数绑定/OPC 客户端。分布用同一 PLC 窗口，DONE/首错冻结；正态 PDF 仅参考。
- 保存：完整记录或首次判稳点起（含该点）；无判稳点/点超出保留容量时中文提示、不创建文件。运行中保存固定快照并标记 Running；CSV 保留 PLC elapsed_ms、质量、参数和截断。默认 C:\OpconData\ForceTraces。
- 旧 HMI 后台采集已退役：无 BppForceTraceStartup 条目/启动 SFC；post-export hook 只发布请求。Restore-ForceTraceStartup.ps1 遇 v2 返回 NOT_REQUIRED_PLC_BUFFERED、不写。旧 .2 组件和 startup 工具为历史恢复材料。
- 完整 PLC Export 的 Symbol REST 流缺陷仍存在。两次精确 Select（新增四数组、恢复九个电阻成员）均只发一次；响应损坏时等待、保存并用新 F11/XML 核对，没有重放 PUT。最终四数组及电阻父节点/九成员为 Read。九成员恢复之外，Symbol XML 无额外变化。
- 接续前核对当时窗口/会话：本轮结束时 CpStudio 与唯一 PLE 保持打开，PLE 离线。不要据旧状态启动第二实例、强关 IDE 或运行独占检查器。

## 验证证据

- [最终模型/权限/符号审计](data/checkpoints/force-3sigma-baseline-20260915/final-audit.json)：新增 234 行，无既有行删除；忽略原生 Num/PlcExportId 后，旧行只改统计窗口标题和 2000→1000 初值。
- [GitHub 基线备份收据](data/checkpoints/force-3sigma-baseline-20260915/receipt.json)。
- [安装 DLL + 已保存 SFC 原生验证](data/reports/hmi/force-3sigma-v2-installed-final/native-check.json)：2001 点 Mod_Chart 坐标与 CSV 逐项一致、29 个帧/重连/保存断言、4 个原生 Item 编辑器、SFCLoader 0 errors；双语离线预览通过。实际 runtime 语言切换未验收。
- tests/static/test_force_statistics.py：844 数值/边界对照；Test-ProjectFramework、Test-Wp100ForceInterlock、Test-Wp100BursterProgramRange 通过。属于离线检查，不冒充物理 PLC 采样/设备动作验收。
- F11 警告签名：4×C0351（OPC.UA.DA 属性未知）和 1×C0373（ErrorCodes 枚举基型 DWord）；无新增警告。CpStudio 2 条为既有 Burster 类型兼容性提示。
- 详细绑定、协议、参数和更新顺序见[力曲线说明](docs/hmi_force_trace_addon.md)。完整 Export 故障见[原厂流缺陷](docs/reviews/cpstudio-symbol-stream-20260911.md)。

## 现场基准与授权

用户在本版实施前确认已更新 HMI/PLE、可运行自动，但晚开曲线页会漏首段；这是旧现场基准，不能当作 v2 已部署。此前 PartCounter 移除、主界面按工件命名、电阻判定和换型重入改动继续保留。

本轮获准做本地 CpStudio 模型、应用 PLC/HMI、导出编译和改动前私有 GitHub 备份。Std 例外仅限自有 Addons/Bpp.ForceTrace 及 OpCon.HMI.Modulo.exe.config 搜索路径，原厂 DLL 只读。未执行实体 PLC 连接/下载/启停/写值/FORCE、IPC 部署或动作。

下一步是工艺确定 3σ 标准，并在明确现场更新范围后配套更新、按 [TODO](TODO.md) 验收；本版需要新 PLE 与新 HMI，不沿用旧“只补 HMI 启动项、无需更新 PLC”的路线。automation-2 仍暂停，本轮未创建任何自动跟进。
