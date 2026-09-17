# CpStudio＋ctrlX 本地组件包索引

2026-09-16 本地候选交付。仅核验 CpStudio V5.11 / ctrlX PLC 2.6.8；未发布 GitHub、未操作实体 PLC 或 IPC。Station010 工程、源码快照、参数权限和选用版本锁保持原样，88 个保护文件 SHA-256 核对一致；旧候选与 rc.4 保留。

## 四套交付

编译栏为“errors / warnings”，记录封装阶段的原生新编译和解包消费验证。rev3 仅补齐图标、统一目录显示名和整理参考实例名；未改的 PLC/HMI 二进制沿用这些证据，改名后的集成参考另行新编译通过。

| 组件 | 版本 / 包修订 | 交付 | 独立库编译 | 消费/参考编译 |
| --- | --- | --- | --- | --- |
| DanikorScrewer | 1.1.0.0 / rev3 | [本地 ZIP](<C:/A_Documents/A_Projects/A_Software/DankerScrewer/Project/DanikorScrewer-Colleague-Handoff-1.1.0.0-local-rev3-20260915.zip>) | 0 / 0 | 0 / 4 |
| BppBurster2316 | 0.1.0.2 / rev3 | [本地 ZIP](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/components/native/burster2316-0.1.0.2-local-rev3.zip>) | 0 / 0 | 0 / 0 |
| BppForceTrace | 0.2.0.0 / rev3 | [本地 ZIP](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/components/native/bpp-forcetrace-0.2.0.0-local-rev3.zip>) | 0 / 0 | 0 / 0 |
| BppMachineCommon | 0.1.0.0 / rev3 | [本地 ZIP](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/components/native/bpp-machinecommon-0.1.0.0-local-rev3.zip>) | 0 / 0 | 0 / 0 |

Danikor 保持 DanikorScrewerLib 发布身份和原库字节；三个 BPP 库使用 BPP Internal Engineering。所有候选只声明已验证的工具链，设备固件兼容和实体 FAT 另验。BPP RELEASE.json 使用独立 schema 3 清单，不改 Station010 的 component-versions.json。

每套含自有 CpStudio 对象、compiled-library、参考工程、说明、依赖和构建证据；ForceTrace 另含 HMI 0.2.0.0 DLL/HAD。原厂 Std 不在新包中。三个 BPP 包共用同一集成参考模型，并各带一个只消费本库的最小 PLC 工程。

## 图标与目录命名

| CpStudio 显示名称 | 图标 | PLC 库身份 |
| --- | --- | --- |
| BPP Burster 2316 | [电阻仪](../../src/cpstudio/components/BppBurster2316/V0.1/Common/Picture.png) | BppBurster2316 0.1.0.2 |
| BPP Force Trace | [力曲线](../../src/cpstudio/components/BppForceTrace/V0.2/Common/Picture.png) | BppForceTrace 0.2.0.0 |
| BPP Machine Common | [按钮、压力表与维修门](../../src/cpstudio/components/BppMachineCommon/V0.1/Common/Picture.png) | BppMachineCommon 0.1.0.0 |

三种图标使用同一黑白线条风格，200×200 PNG。图标、目录名称和功能说明均经 CpStudio 原生加载检查。参考实例 `a` / `a_1` 已改为 `Station.ForceTrace` / `Wp100.Trace2`，保存重开与两张实际 HMI 页面加载通过。重新 HMI Export 后，八个 Item 自动使用新名称；新父节点和四数组成员的 Symbol 权限均为 Read，旧符号已清除。Danikor 名称、图标和本地包不变，三个 BPP 的旧 rev2 包仍保留。

## 安装与接口

先校验解包目录，再把 reference/CpStudio 复制到新的工作目录，提供同级外部 Std；按 [INSTALL](INSTALL.md) 安装到 PrjExt。导出前确认唯一 PLE 打开的完整路径就是该参考工程，不能只按同名标题判断。三个 BPP 安装器首次分别核验并复制 6、9、6 个文件，重复执行复制数为 0。参考模型包含 22 张 HMI 页面，避免重新导出时丢失页面引用。

- [Burster](BppBurster2316.md)：项目配置地址、程序号和超时，通过标准 IBursterResis2316 Channel 连接原厂 Unit/HMI。单连接、首错、Ω 和不重放测量保持原样。
- [ForceTrace](BppForceTrace.md)：七个原生变量选择参数，四个整数组 Item；已验证改名、换父节点和两个实例。三位置、名义 6 ms 采样、100 ms 发布、前 60 s/10001 点、完整/首次判稳后两种 CSV，v2 协议保持原样。统计 FB 可单独消费。
- [MachineCommon](BppMachineCommon.md)：按钮、气压、维修门三个 FB 原接口和行为不变，压力模拟仅在 examples。CpStudio 外壳不代替应用调用与安全联锁。
- Danikor：按 ZIP 内 docs/MANUAL.md 安装，使用标准 NexeedIpDataStream Channel；原 1.1.0.0 接口和库不变。

## 验证结果与边界

独立参考完成对象插入、参数选择、Channel/变量绑定、保存重开和重新导出。rev3 名称调整后，CpStudio Fast PLC export + HMI 单独 Export 并重新 Validate：0 errors / 4 条原有兼容性提示。参考工程重新 Generate code 为 0 errors / 5 条原有警告（4×OPC.UA.DA、1×ErrorCodes 枚举基型）。rev2 解包参考及 Danikor 消费工程的 Build 为 0/4；不同命令的计数分别保留。新包内参考工程与本次编译后保存的工程字节一致，未重复做实体或最小消费测试。

Burster 协议模型 18 项、ForceTrace 数值/边界 844 项通过；原厂 Burster HMI 加载器 0 errors、9 个实际绑定。ForceTrace 原生加载器 0 errors、4 个 Item 编辑器，29 个帧/重连/保存断言与 2001 点绘图/CSV 对照通过。三位置两轮、晚开、重连、截断及两种 CSV 使用合成 PLC 帧验证；中英文离线预览已检查，HMI runtime 语言切换未验收。

MachineCommon 在本地 PLC 模拟器执行 19 项检查，失败位为 0，覆盖按钮完成、气压转换超时、维修门反馈缺失和复位。原始报告中的 passed=false 来自报告脚本对 INT#19 / DWORD#0 的旧字符串比较；原始值、独立数值判定与 SHA 一并保留，没有把该汇总字段改成成功。PLC 模拟执行不等于实体 I/O 验收。

完整 PLC Export 仍有原厂 Symbol JSON 流错误，未标为通过。本次通过 Fast export、HMI 单独 Export、原生 Symbol 回读和新编译验证。导出曾自动打开额外 PLE，已正常关闭后在唯一会话完成剩余参考验证；没有抢锁或强关 IDE。

Station010 的现场更新、3σ 工艺标准、真实采样周期/任务负载、HMI runtime 和实体设备验收继续见 [TODO](../../TODO.md)。独立 WPF HMI、工程脚本与 Kistler/自动流程参考保持各自用途。

## 校验与证据

当前 rev3：[最终校验收据](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/icons-naming/FINAL-VERIFICATION.json>) · [解包与重复安装](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/icons-naming/package-verification.json>) · [图标、改名、编译与绑定](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/icons-naming/cpstudio-proof.json>)。以下原封装阶段记录保留为历史证据。

[最终校验收据](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/FINAL-VERIFICATION.json>) · [解包及重复安装](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/final-unpack-install.json>) · [四套消费编译](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/unpacked-consumers-01.json>) · [重新导出参考编译](<C:/A_Documents/A_Projects/A_Software/BPP_ResistantStation/McpCoding/data/native-packages/20260915/unpacked-reference-02.json>)

首次消费批次的总状态因最后一个参考工程锁被取消而为 false；前四个消费工程均已新编译通过。最后一个参考工程在后续独立报告中通过，最终收据逐项核对两个报告，不覆盖失败记录。

| ZIP | SHA-256 |
| --- | --- |
| DanikorScrewer-Colleague-Handoff-1.1.0.0-local-rev3-20260915.zip | `E18E9D9B7A97C9C99421C5352AF77C3322A808739BADDB8E0491CC917995C854` |
| burster2316-0.1.0.2-local-rev3.zip | `7C84FFF5E47B8B1BEFACF74904F5717ABE8E241CAD7A8222A3E0E1F6DFDD53DD` |
| bpp-forcetrace-0.2.0.0-local-rev3.zip | `30C0CFB5DF4090E90D560E8C1FAD7E1D1B356E82EDE1CEABDC002D0699F2BC57` |
| bpp-machinecommon-0.1.0.0-local-rev3.zip | `93B6D1A9DB81034AE7A013DFC9DC5DA509C509D2E2C78CD3433E346C1DE11A49` |
