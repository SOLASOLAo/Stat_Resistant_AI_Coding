# 当前交接

> **Git 备份提交（2026-09-17）**：按用户要求，保存当前 Station010 工程与 McpCoding 自研源码，沿用各自现有开发分支。只读核对确认本地 HMI DLL、AddonDesc 及两份生成配置已为 0.2.1.1，实际 SFC 保留 Station.ForceTrace 四数组绑定；PLC 库/对象仍为 0.2.1.0。现场安装与显示效果未独立确认。工程提交中的连接密码与 HMI 管理密码置空，本机文件保留；本机连接 INI、许可证状态、旧快照 ZIP 和忽略的构建/运行记录不纳入本次提交。复用既有验证，不重新编译或打包。

> **HMI 布局补丁 0.2.1.1 已在本地注册，待现场确认**：按用户现场反馈，将状态文字从 y=496 上移至 445，采样说明从 y=535 上移至 470；图表高度收紧 40 px，全部内容落在 944×572 可见区域内。中英文原生预览、文字完整性和既有帧/CSV 检查通过。[HAD](data/components/native/forcetrace-hmi-0.2.1.1/ForceTrace.Hmi.had)。2026-09-17 只读核对本地 DLL 与生成引用为 0.2.1.1；尚未确认 IPC 版本与现场显示。PLC 库/对象仍为 0.2.1.0，本布局补丁不需再次下载 PLC。没有追加哈希或完整组件 ZIP。

> **当前本地版本：ForceTrace 0.2.1.0（2026-09-16）**。PLC 库、CpStudio 对象及 HMI 已配套升级，完成实际 Station010 导出、保存重开、新 Generate code **0 errors / 5 原有 warnings**，CpStudio Validate **0 / 2 原有 Burster warnings**。新增 SamplePeriodMs（默认 6 ms）、页面下方中英文采样/3σ 计算与判稳说明，分布空提示改为“尚无可用的统计窗口数据”，保留防闪烁修复。本次需要用户配套更新 **PLE、生成 HMI 和 0.2.1.0 扩展 DLL**；AI 未下载 PLC、部署 IPC 或推送。详见[升级说明](docs/reviews/forcetrace-sampling-20260916.md)及[新编译结果](data/reports/hmi/forcetrace-sampling-20260916/station-reopened-final.json)。

用户收尾要求：停止额外/重复的哈希、清单、打包和报告工作；已通过且没有新改动的检查不重复。本次已完成库/HAD/工程，未另打完整组件 ZIP，旧包保留。finalize-local.py 为未执行草稿，不作为收据。

> **历史 HMI 闪烁修复**：此前 0.2.0.1 本地安装和“仅更新 HMI”步骤保留在[补丁说明](docs/reviews/forcetrace-hmi-flicker-20260916.md)。当前 0.2.1.0 已包含该修复，旧步骤不用于本次配套升级。

> **最新用户改动（2026-09-16 13:31 导出）**：Burster Hostname 已绑定 `Station.StationData.BursterSetting.HostName`，必须作为用户可配置地址保留。模型变量引用和当前唯一 PLE 的 `PeripheralRoot.OnApplyParameters` 只读回读均已确认。离线核对脚本已取消固定 IP 条件，改查该变量绑定。用户同时报告一次导出异常弹窗，原文未找到，当前 Output 为空，不能直接认定是历史 Symbol 缺陷或宣告完整导出成功。证据见[本次回读](data/reports/cpstudio/20260916-hostname-readback.json)；未执行新编译、下载或 runtime 操作。

> **2026-09-16 接续收尾已完成。** 总索引、发布清单和两个仓库的交接已同步；新文档修订为 Burster rev5、ForceTrace rev2、MachineCommon rev2，Danikor rev3 原包未变。三包解包、哈希和隔离重复安装通过；库、对象、HMI、消费工程与已编译版本一致。见[收尾校验](data/station-native-integration/20260916/documentation-closeout/CLOSEOUT-VERIFICATION.json)。[暂停记录](docs/components/PAUSED-20260916.md) 保留为历史。

更新：2026-09-16。**实际电阻台 Station010 已接入原生 ForceTrace、MachineCommon、Burster2316**。本次在用户修改 Hostname 后的保存工程上接入 ForceTrace 0.2.1.0；当前工程与新编译证据以本页顶部采样周期升级记录为准。原导出弹窗原文仍未恢复，本次 Fast PLC / HMI 单独导出通过不代表历史完整 Export 缺陷已经修复。

| 组件 | 当前实际接入 |
| --- | --- |
| ForceTrace 0.2.1.0 | Station.ForceTraceAddon 负责周期采集，Station.ForceTrace 保存四数组；本地 HMI ForceTrace.Hmi 0.2.1.1 |
| MachineCommon 0.1.0.0 | 原生压力/门 FB；Home、Run 按钮保持独立实例，原调用顺序与物理联锁保留 |
| Burster2316 0.1.0.2 | 一个 Burster2316Peripheral 连接原厂 IBursterResis2316 Unit；选程、测量、清理共用实例 |

通用名称已去掉 BPP 前缀，Company 为 Internal Engineering，最低 CpStudio/OES 5.11。独立库和最小消费工程均新编译 0/0。当前选择见 [原生选用记录](config/station010-native-selection-20260916.json)，三套新候选与未改的 Danikor 包见[总索引](docs/components/LOCAL-PACKAGES-20260916.md)。旧 component-versions.json、rc.4、Bpp rev3 包保留为历史，不能再据此认定本站仍使用旧源码候选。

通用命名包附最小 PLC Consumer.project；原生 CpStudio 验证使用实际 Station010。新版最小 CpStudio 隔离参考模型尚未随包提供，旧 Bpp 双实例参考及模拟证据已明确标为历史，不能混作本次新验证。

## 本站核对结果

- CpStudio Fast PLC export、HMI 单独 Export、保存关闭重开后的 Validate：0 errors / 原有 2 条 Burster 兼容性提示。完整 PLC Export 的原厂 Symbol REST 流缺陷仍未修复。
- 最终保存重开后 Generate code 为 **0 errors / 5 既有 warnings**：4×OPC.UA.DA 属性未知、1×ErrorCodes DWORD 枚举基型。通过原生 Symbol Configuration Update 将 ForceTraceData 引用改为 0.2.1.0；全体已配置 Symbol 回读一致，仅库版本改变。全量 datatype 枚举的 duplicate-key 及 REST 流缺陷仍保留为原厂问题。
- 17 个应用对象迁移、9 个重复本地根退役；最终回读 274 个 PLC 对象。ForceTrace 周期入口为 OnCallEnter，位于 Station OnCall 后、步骤链前；应用只管理生命周期，不重复调用采样体。
- HMI 页面 ForceTraceForceTrace 的四个 Item 指向 Ch1.L1.Station.ForceTrace.LeftFrame/MiddleFrame/RightFrame/StatisticsFrame。父节点 Read，类型成员保留原选择；三个曲线数组各 30036 个 DWORD，统计 210 个。当前导出仍存在旧 HMIForce* 遗留 Symbol 选择，本次保留，运行代码与页面不使用它们；旧手工页面登记及 v1 startup 已退出。
- 安装 DLL + 实际导出 SFC：原厂加载器 0 errors，2001 点、50 组刷新、四个 Item 编辑器及两种 CSV 通过；新增中英文动态说明、无统计窗口及页面边界检查通过。847 项数值模型与 685 项帧/CSV 检查通过。实际 runtime 切换语言、现场传输与负载未验收。
- 78 个受保护文件哈希不变，包括 IO 工程、主界面 UserDefined.sfc、StationData/TypeData 导出 DAT 和原厂 DLL；模型既有业务值及用户权限保留。模型仅升级 ForceTrace、增加采样周期和五项中英文资源，另有原生序号重排。此前首次接入补入的中文保持。

## 参数与工艺事实

接入前用户已保存的初值为：门槛 **2500 N**、3σ 标准 **5 N**、窗口 **1000 ms**、总超时 **10000 ms**；本次保留。未读取现场活动 DAT，初值不等于现场当前值。独立参考的 3σ=0 仍表示未配置、禁止放行。

四个 StationData 工艺参数与 SamplePeriodMs 在每位置首次 preflight 锁存。采样周期在 CpStudio 的 Station → Parameters → ForceTrace 配置，默认 6 ms，与当前实际 MainTask 一致；配置不会改变任务调度。完整统计窗口、健康数据、下压到位、力严格大于门槛、3σ 严格小于标准才放行；等于边界不放行。测量中继续监控，首错优先于 DONE，掉力不重启总超时。采集从 Kistler START 确认/下压前起，100 ms 发布；保留每位置前 60 s/10001 点，截断后仍统计。新父循环清空旧记录；两种 CSV 分别保存完整保留段和首次判稳点起的段，无判稳点则提示且不生成文件。

电阻上下限与原始结果为 Ω，按包含边界的范围与量程有效性判断；HMI mΩ 显示，OK/NOK 不取 Kistler 输出。夹具左/中/右对应工件右/中/左，主界面按工件命名；曲线与 CSV 保留夹具语义。Burster 地址由 Station.StationData.BursterSetting.HostName 配置，端口 5555，测量超时 30000 ms，程序取活动 TypeData；原固定地址 192.168.0.103 已由用户改为变量引用，不能再按固定 IP 验收。同一设备只有一个连接所有者，不自动重放测量。

## 恢复与接续

详细绑定、调用顺序和证据见 [本站接入记录](docs/components/STATION010-NATIVE-20260916.md)。恢复点 data/station-native-integration/20260916/before（310 个已核对文件）、before-plc-source（307 个对象）必须配套使用；最终收据 FINAL-VERIFICATION.json、after-final、hmi-installed-final 保留。历史阶段说明见 [原交接](docs/archive/2026-09-16-before-station-native/HANDOVER.md)。

0.2.1.0 的本次恢复点为 data/reports/hmi/forcetrace-sampling-20260916/before 与 before-install，按 baseline.json / install-recovery.json 配套恢复；不要将中间 before-symbol-migration.project 当作升级前完整基线。当前本地 0.2.1.0 构建与旧 0.2.0.0 ZIP 分开记录。

此前私有 GitHub 基线：tag baseline-before-force-3sigma-20260915，commit b93d44a8a57ac33a9d73c2af9496f9e0280dc34a。2026-09-17 备份提交范围见页首；旧 tag 保留。用户先前现场更新可运行的陈述属于旧部署基准，不能作为本版验收。

下一步按 [TODO](TODO.md) 在另行授权的现场更新中配套更新 PLE、HMI、原生库/扩展，核对活动参数、真实采样/CPU/watchdog、三位置两轮、晚开重连、CSV 与安全联锁。Std 的已批准例外仅用于自有 add-on 注册及搜索路径，原厂 DLL 未改；automation-2 仍暂停，没有新自动跟进。
