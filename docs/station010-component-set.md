# Station010 组件组合 — 2026-09-11 本地候选

BPP-REUSE-PACKAGING-20260911。统一入口 `config/component-versions.json`：Burster/Kistler/ForceTrace 三个源码候选都为 `0.1.0-rc.2`；ForceTrace DLL/HAD 为 `0.1.0.2`。这是本地选择锁，不是在线安装清单。
Git 锚点为 `d37918a4863bdaaf7937df5daa3b948ef124e22d`；各组件包含未提交文件，实际源码由 component.json 中逐文件 SHA 和 sourceSnapshot 摘要锁定。
`ARTIFACT-MANIFEST.json` 覆盖包内所有载荷字节；交付后不得直接编辑冻结包，应回唯一源码修改并形成新候选。

从 McpCoding 用 PowerShell 7 运行 `scripts/components/Build-StationComponentSet.ps1 -NativeArtifactsPath '<已验证的 .2 构建目录>' -DestinationRoot '<McpCoding/data/components/station010-set-新版本名>'`。
它调用现有组件 Build/独立校验，再生成本站单独的启动 overlay 和组合证据，不安装或部署。
收件人运行组合根目录 `Verify.ps1 -PackageRoot .`；目录不是 Git 仓库也可完整校验。先看各 `packages/<组件>-<版本>/components/<组件>/README.md` 的接入说明。
组合内只带自有内容、本站只读引用和菜单文本增量，没有工程凭据、加密 `.project`、原厂 DLL/ESI 或失败原生库。

## 当前应用与候选

| 项目 | 当前观察 | 本次候选 |
|---|---|---|
| PLC 工程/profile | Station010 / ctrlX PLC 2.6.8，CpStudio 拥有当前离线 PLE | 本轮封装未修改 `.project` 或 PLC 源 |
| Burster | 当前源码核心来自 rc.1，本站集成曾 0 errors / 5 warnings；一轮自动观察完成 | rc.2 补版本、依赖、失败原生库的真实状态；无合格 `.library` 交付 |
| Kistler | 标准库 2.0.1.0，Unit 1.2.2.0，Base 1.2.1.0 | rc.2 收纳 ForceTrace 钩子，依赖配套 PLC 发布器 |
| ForceTrace | 本机/只读 IPC 文件均为 DLL .1；现场中间曲线、既有 CSV 可见 | DLL .2 + 隐藏启动页，晚开场景离线通过，尚未升级/部署 |
| 中文 | CpStudio 已保存并 HMI Export，0 errors / 原 2 warnings | 10 处菜单/模式/引导标题更新；原 24 个业务 Text 双语保留 |

本站 PLC SHA：`2E876C9CED6ABEA660E5473918A4F8164DCFF205B11895B9830DC0DD99B1A6DA`；Symbol SHA：`9FFCAB1160993733A711D6C18BC978E4B7541C33F19E3D5263CF751ADFDBC9D6`。本地 Changeover 重入修复在此 PLC 中，另行下载后仍须现场复测；不要把 HMI 封装当成已下载 PLC。

## Station 参考参数（不能作为通用组件默认值）

- Burster 地址来自本站配置；复用时由项目提供 `Hostname`，不把本站地址/账户装入驱动包。一个 TCP owner、程序 0..15、仪表程序控制量程；标准 Unit/HMI/判定继续使用同一实例。
- Kistler 站内 Unit `Wp100A104Kistler`、Peripheral `_100A104`、BusInfo `_000SA620_X1` 是本站绑定。生产 MP001，0/1 Active 是当前设备的已观察组合，不是全部固件通用要求；实际固件仍未知。
- ForceTrace Item `Ch1.L1.Station.HMIForceFrame`，原生 `TextGroup=Station`，IPC 本地 `C:\OpconData\ForceTraces`。原有发布器从 Kistler 的 ForceAct 取 N；质量需 BusOk、Unit OPERATIONAL、无 Alarm/ERROR、有限数值。
- 本站左中右、2500 N、稳定时间、气缸/安全门反馈和事件号由工位工艺拥有。它们只能在标明 station-reference 的文件出现，不进入通用驱动/图表参数或新工位默认动作。

## 使用和变更顺序

1. 按各包说明检查哈希；先核对当前工位实际依赖/固件/配置。新项目通过 CpStudio 建标准 Unit/接口/变量/视图，再用 PLE 合并自有实现；不要整段覆盖生成声明、SFC 或安全联锁。
2. 原站的 PLC 层已接入发布器。本次 HMI 晚开修复沿用 v1 Frame，不需要重新下载 PLC 来启用隐藏采集。HMI 只原生升级 .had，正常 HMI Export，然后生成启动 overlay、核对双语和绑定。
3. 独立离线 Build/原厂加载器检查后，再经另行授权部署。当前完整 PLC Export 有已记录的符号流缺陷，勿用反复全 Export/强制重启排查本次 HMI 问题。
4. 现场从 HMI 已运行且有有效订阅开始，保持未打开曲线页，执行一轮左中右，再打开并逐位置核对 t/力/状态、保存 CSV；另验重开页面、第二轮、取消/断线、zh→en→zh。动作由现场另行授权执行。
5. 回滚使用之前一整套 HMI 文件与准确 PLC 源/依赖组合。HMI .1 不支持隐藏启动类，回退时一并移除该启动项；不要删除 CSV，不热替换运行中的 DLL 或 Socket。

Burster 原生消费验证仍阻塞：上次库引用 qualified-only 与 ctrlX 平台解析未通过。本轮不关闭/重启/接管当前 Station010 PLE，也不启动第二个同 profile writer；交付可校验的源码和依赖证据，空闲独立库窗口再修并做 fresh consumer Build。失败的 compiled-library 不进入任何新包。

组件包/组合包/现场验收是三种证据。包 SHA 相同只证明内容一致；C# 原厂控件合成帧测试不证明 OPC 真机时序；PLC 以前的 0 errors 不证明新原生库可消费。当前没有设备下载、启停、FORCE、IPC 写入、Git 提交/推送或发布。
