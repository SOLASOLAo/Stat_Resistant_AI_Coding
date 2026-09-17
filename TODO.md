# 待办与完成条件

状态基准见 [HANDOVER](HANDOVER.md)。只保留已确定的未完成工作；延期项不自动启动。完整旧清单及过程见 [归档](docs/archive/2026-09-14-framework-simplification/README.md)。

## 当前现场工作

- [ ] **HMI 0.2.1.1 布局补丁现场实测**：2026-09-17 只读确认本地 DLL、AddonDesc 和生成 HMI 引用均为 0.2.1.1，本站已选版本记录已同步。用户确认 IPC（含 DLL）更新及底部中英文说明完整可见。本地构建和 944×572 预览已通过；[HAD](data/components/native/forcetrace-hmi-0.2.1.1/ForceTrace.Hmi.had)。PLC 0.2.1.0 保持，布局补丁不需再次下载 PLC；现场结果尚未确认。

2026-09-16 本地 ForceTrace PLC 库、对象和 HMI 均为 **0.2.1.0**，新增采样周期配置及中英文采样/3σ 说明，包含原防闪烁修复。实际 PLE 保存重开后新编译 0/5，CpStudio 0/2；用户负责现场配套更新，现场版本未独立读取。此前超时截图为 LEFT FORCE_WAIT_TIMEOUT，力 2544.037 N 低于该记录门槛 2559 N，不是页面未打开导致 PLC 不计算。本站保存初值 3σ=5 N 不代表现场当前值；保留用户活动数据。详见 [HANDOVER](HANDOVER.md) 及[绑定/使用说明](docs/hmi_force_trace_addon.md)。

- [ ] **0.2.1.0 配套现场更新与确认**：本地已接入，用户更新本次 PLE、生成 HMI 及 ForceTrace.Hmi 0.2.1.0 扩展 DLL，核对实际加载版本和 SamplePeriodMs 与真实任务一致。检查中英文底部说明、切换位置后的记录参数、无统计窗口提示及不闪烁；旧 0.2.0.1“仅更 HMI”步骤不适用于本版。见[升级/证据/恢复说明](docs/reviews/forcetrace-sampling-20260916.md)。

- [ ] **电阻与显示验收**：下次同步主界面后，核对夹具左/中/右依次更新工件右/中/左的三行名称（2026-09-15 本地修正已完成）。核对活动 TypeData 的 Ω 数值；各位置每次测量验证合格、超差、上下边界和第二轮。检查清零、独立锁存、取消、mΩ 换算及通讯质量；通讯/力故障不得显示有效 OK，判定不取 Kistler 输出。核对仪表程序/量程、Auto Range=False、单连接清理和重连，无重复 INIT/旧结果；不恢复已失败的双连接候选。
- [ ] **PLC 曲线现场验收**：核对现场为配套 0.2.1.0 和 v2 四数组接口；AI 尚未操作现场。核对四个整数组、父节点 Read、无旧后台启动项。保持曲线页未打开，完成三个位置后再查看；第二轮、重开、断线重连、结束/取消/首错不得混入旧循环。核对实际 MainTask 时间、SamplePeriodMs、CPU/12 ms watchdog 裕量、大数组传输和 100 ms 刷新、下压前 t=0、60 s/10001 点截断后统计仍运行。检查分布与 PLC 同窗、DONE 冻结、历史窗口提示、零方差显示；实际切换 zh→en→zh。
- [ ] **两种 CSV 现场验收**：当前位置完整记录、首次 3σ 判稳点起的记录；无稳定点或稳定点超出保留容量时不生成文件并中文提示。覆盖运行中保存、判稳后掉力/故障、重复保存、IPC 目录权限及配额；文件与显示来自同一快照，保留 PLC 时间及该位置实际参数。
- [ ] **换型验收**：连续完成两次 TypeData 选择；取消文件选择、取消换型及错误退出后均可重试，不残留视图请求。
- [ ] **3σ 与运动联锁验收**：由工艺确定 PressForce3SigmaLimit 的 N 值；现场活动 StationData 中核对门槛（模型初值 2500 N）、3σ 标准 >0、统计窗口（模型初值 1000 ms）及总超时 >窗口。保留用户现有活动数据与权限，不以导出 DAT 代替。验证完整窗口才放行、力等于门槛重置、3σ 等于标准不放行、参数每位置锁存、掉力不重启总超时、总超时与判稳同扫描时超时优先。测量中掉力/σ超限/数据异常/位置丢失须保持首错并优先于 DONE；无自动抬缸旁路。覆盖三个位置、两轮、取消重启及 Kistler watchdog。原位置/阀反馈、左603/中602/右601、并行汇合和 Home 分支验收继续保留。
- [ ] **按钮、主气压与维修门验收**：按钮灯 500 ms 亮/灭，按下或离开步骤后灭；确认步骤前已按住按钮的处理需求。两路压力输入已取消接线，核对气压命令后 1 s 虚拟 HIGH/LOW、5 s 诊断及恢复。核对维修门继电器保持、Y32 在 1 s 内成立、A/B 门及反馈缺失时主气压禁止、模式不放行、5 s 报警和 Control Off 恢复；补齐相关中文。
- [ ] **设备/服务故障证据**：若再现 Kistler 启动未就绪、IPC 服务报警、ctrlX 黄色事件或 License Server 故障，保留首错/日志和部署配置，按对应诊断结论处理。Kistler MP000 Active 的现场恢复经验不推广到所有固件；License Server 待原厂正式修复后验证无 crash-loop、61863 连续 60 s 可达及 Read from target。端口可达或一轮自动完成不代表长期稳定。

## 已确定的离线与维护工作

- [x] **可配置采样周期与中英文判稳说明**：ForceTrace PLC/对象/HMI 0.2.1.0 本地安装、导出、保存重开和新编译通过；独立库/消费 0/0，本站 0/5，CpStudio 0/2，847 数值检查、685 帧/CSV 检查及实际 SFC 原生中英文预览通过。StationData/TypeData 权限、Hostname 与 78 个受保护文件保持。见[升级说明](docs/reviews/forcetrace-sampling-20260916.md)。

- [x] **HMI 闪烁本地修复及安装**：接收错误包保留有效快照；重复帧和已完成记录不重画；实际 SFC 原生加载、2001 点、50 组交替错误/重复包、中英文和两种 CSV 通过。原生安装 0.2.0.1，旧版引用已清理，HMI 单独 Export 0/2；仅更新自有扩展、生成 HMI 配置及独立 HMI 选用记录，旧完整组件包不变。未操作实体 PLC 或 IPC。见[安装收据](data/reports/hmi/forcetrace-flicker-20260916/local-install/installation.json)。

- [ ] **用户最新导出弹窗核查（2026-09-16 13:31）**：Hostname 的模型引用与生成 PLC 赋值已确认正确，离线检查脚本已同步。此次弹窗原文尚未恢复，当前 Output 为空；导出类型待用户确认，不能用旧编译收据或 Messages 的 0 errors / 2 warnings 宣告本轮完整导出成功。若再现应保留异常 Details 和 Output，再按失败阶段处理，不直接重复 Export。见[只读回读](data/reports/cpstudio/20260916-hostname-readback.json)。

- [x] **暂停后接续收尾**：按用户“可以继续了”更新总索引、文档与两个仓库交接；交付 Burster rev5、ForceTrace rev2、MachineCommon rev2 文档修订，Danikor rev3 不变。新包解包/哈希/重复安装通过；代码与已新编译 0/0 的消费载荷一致，实际工程哈希未变。见 [收尾校验](data/station-native-integration/20260916/documentation-closeout/CLOSEOUT-VERIFICATION.json)。

- [x] **本站原生库接入**：实际模型、PLC 与 HMI 已接入，完成新 Generate code 0/5、四数组绑定、保存重开、权限/差异核对，交付通用命名候选包及独立原生选用记录。详见 [本站接入记录](docs/components/STATION010-NATIVE-20260916.md)。

- [ ] **通用命名最小 CpStudio 参考模型**：当前三包只有最小 PLC Consumer.project，CpStudio 安装证据来自实际 Station010。后续在隔离模型重新生成通用对象，验证改名、换父节点、双实例及保存重开/导出/编译，再以新修订交付；旧 Bpp rev3 双实例证据不代替这项完成条件。

- [ ] **完整 PLC Export 恢复**：等待原厂修复或受支持的替代方式；验证完整 JSON、CpStudio 导出及 Symbol 权限。当前不盲目重试相同失败。
- [ ] **原生组件现场验收与正式发布**：实际 Station010 本地接入已完成，见[当前包索引](docs/components/LOCAL-PACKAGES-20260916.md)。待现场固件、实体 FAT、HMI runtime、任务负载及配套部署验收；当前选择为 config/station010-native-selection-20260916.json，旧锁、rc.4、Bpp rev3 保留为历史。
- [ ] **Project Pack 测试基线**：按已审阅 SFC 汇合步同步步骤/并行断言，并核对旧 ASC 固定基线；保留真实流程/I/O，不能为了通过测试替换现场事实。
- [ ] **历史请求/operation 维护**：先列清单再按授权归档 stale pending；不自动认领、重跑或删除不可变证据。
- [ ] **离线检查器实际生命周期验收**：另行安排无既有 PLE/MCP owner 的窗口，验证启动→新 Build→正常退出；不得强杀现有会话或删除活动锁。
- [ ] **需求与架构文档收敛**：对照原始电阻台 PDF 与已实现流程，形成经用户确认的需求/IO/判定标准及 OpCon Station/Module/Command 架构说明。

## 保留的后续计划

- [ ] **工程自动化 P2–P4**：P2 以模块顺序/型号 manifest 完成 IOE Plan→恢复点→Apply→重开回读；P3 验证正式 Link I/O 接口，不能证明支持时保留原生操作；P4 取得真实运行时 DAT 后再做校验/生成/备份/受控部署，不能用导出定义猜格式。ASC 只负责 designator/描述。
- [ ] **自研 HMI A/B 验收**：按独立授权安排。先关闭 Nexeed HMI，验 PublicEventList、ExtensionObject、活动/清除事件、EtherCAT 9 元素数组、38 个 I/O 和力/位移只读；再批准 Automatic/Manual/Home/Changeover 请求及拒绝路径，不做多面板 Token 转移。扩展控制还须验证 request-bit 回零、PanelActive、按住执行、Heartbeat、断线/失焦/退出释放，验收前保持 capability 锁定。
- [ ] **数据记录与追溯**：明确测量结果 CSV/数据库需求后接入现有 DataSetAccess/EventRecorder；若要求仪表完整曲线，再确认 Kistler READ_DATA 分页范围。力曲线显式 CSV 保存不等于测量追溯已完成。
- [ ] **新电脑/团队工位验收**：从固定版本和 OneDrive 资产包恢复工具与配置，完成体检及离线 Build；保留旧电脑到验收通过。在新同事电脑验证包传递、安装、显式启动、升级、回滚、卸载和诊断。
- [ ] **商业交付（延期）**：前三阶段稳定后安排安装、许可、回滚、诊断包、DemoStation 和合规；AtLogOn prelaunch Bootstrap 仅在商业化/明确无人值守需求时实施。兼容矩阵在有团队工位时做，ACL/签名按实际商业或 IT 要求安排。

## 仍需需求决定

- [ ] **DeleteWpcData 与模型遗留项**：用户明确清哪些数据或是否取消该命令后再处理 N110/N120/N130/N140；不能删掉空模板后报告清理成功。另核对 Wp100A740*、StationSdNokCounter、Wp100StationDataStruct 的生成来源及引用，再决定是否删除。
- [ ] **专用事件方案**：确认选程/测量/清理、参数和力故障的事件需求及编号，再通过 CpStudio 配置、导出并接首错/复位及中文。旧 20–28 编号仅为提案，尚未授权按该方案实现。
