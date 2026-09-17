# 设备组件与版本

> 2026-09-16：实际 Station010 已选择通用命名原生库，当前入口为 [选用记录](../config/station010-native-selection-20260916.json) 与 [本站接入](../docs/components/STATION010-NATIVE-20260916.md)；下文“历史源码候选”及 rc.4 信息保留作历史。
这里管理**自研内容**，不复制 Nexeed 标准库、仪表手册、完整 Station 工程或凭据。
清单引用归属明确的源码，打包到忽略的 `data/components/`。独立库位于 `src/plc/libraries/`；保留 Station010 原有源码快照，不自动替换工位实现。

## 当前独立原生候选（2026-09-16）

交付入口、既有 ZIP 和新编译证据见[总索引](../docs/components/LOCAL-PACKAGES-20260916.md)。本站 ForceTrace 已升级至 0.2.1.0 并新编译、安装，本次按用户要求不另打完整 ZIP。既有完整包仍为 Burster2316 0.1.0.2 rev5、ForceTrace 0.2.0.0 rev2、MachineCommon 0.1.0.0 rev2；不能用旧包覆盖本站新版。Company 为 Internal Engineering，当前源码/构建版本与旧包分开记录。

| 组件 | 库/对象版本 | 本地能力 |
| --- | --- | --- |
| Burster2316 | 0.1.0.2 | 标准 IBursterResis2316 Channel、自有 Peripheral、原厂 Unit/HMI；独立库及消费编译通过 |
| ForceTrace | 0.2.1.0 | PLC 可配置采样/统计/v2 帧、NxAddonBase 对象、HMI 0.2.1.0；独立库及消费新编译通过 |
| MachineCommon | 0.1.0.0 | 三个公共 FB；通用命名库及消费编译通过，旧 Bpp 版本的 19 项 PLC 模拟结果作历史证据 |
| DanikorScrewer | 1.1.0.0 | 另一现有仓库保持发布身份及库字节，新编译参考工程并生成 local-rev3 交接 |

```powershell
pwsh -NoProfile -File scripts/components/Build-DeviceComponent.ps1 -Component burster2316 -Command Check -ReleaseManifestPath components/releases/burster2316-0.1.0.2-local-rev5.json
```

改为 `-Command Build` 才生成包；不同内容必须使用新修订，不覆盖旧候选。原生包安装、外部 Std 和验证边界见[安装说明](../docs/components/INSTALL-GENERIC.md)。本通用命名包提供最小 PLC 消费工程，CpStudio 验证来自实际 Station010，尚未附新版最小 CpStudio 参考模型。本站 rc.4、旧源码候选及冻结清单保持原样；下表与后续旧命令属于历史来源，不代表本次原生包版本。

## 历史源码候选

| 组件 | 版本 | 交付物 | 当前边界 |
|---|---|---|---|
| [Burster 2316](burster2316/README.md) | 0.1.0-rc.2 | 自研驱动源码候选 | 原生库曾试建，独立消费失败，失败二进制不交付 |
| [Kistler 5867C](kistler5867c/README.md) | 0.1.0-rc.2 | 标准驱动集成参考包 | 保留标准 EtherCAT 驱动，包含本站记录钩子 |
| [ForceTrace](bpp-forcetrace/README.md) | 0.1.0-rc.2 | 原生 HMI DLL/HAD 0.1.0.2 + PLC 发布器 + 模板/双语资源 | 后台启动候选通过离线验证，尚未安装/部署 |

## 本站未发布改动（2026-09-11）

用户授权 BPP-REUSE-PACKAGING-20260911：HMI 修复后整理本地复用交付。rc.2 接纳已审阅的
Kistler 记录钩子及 ForceTrace 背景采集，不改 PLC 源、不新增提交/标签/推送。旧 rc.1 两包原样保留。
`sourceRevision` 为 Git 提交锚点；schema 2 逐文件 `sha256` 和 `sourceSnapshot.sha256` 才是当前候选的实际字节。
dirty=true 表示含未提交内容，不冒充该 Git 提交已经包含新版本。检查发现新漂移仍拒绝打包，不能自动重锁。
本站组合与升级/回滚入口见 [使用示例](../docs/station010-component-set.md)。
## 检查、打包

在 McpCoding 根目录运行，PowerShell 7；不访问 PLE/PLC/仪表，不运行接入脚本：

```powershell
pwsh -NoProfile -File scripts/components/Build-DeviceComponent.ps1 -Component burster2316
pwsh -NoProfile -File scripts/components/Build-DeviceComponent.ps1 -Component burster2316 -Command Build
pwsh -NoProfile -File scripts/components/Build-DeviceComponent.ps1 -Component kistler5867c -Command Build
pwsh -NoProfile -File scripts/components/Build-DeviceComponent.ps1 -Component bpp-forcetrace -Command Build -NativeArtifactsPath '<本次已验证的 HMI 构建目录>'
pwsh -NoProfile -File scripts/components/Test-ComponentPackage.ps1 -PackageRoot 'data/components/bpp-forcetrace-0.1.0-rc.2'
pwsh -NoProfile -File tests/static/Test-DeviceComponents.ps1
```

默认 Check 只读，核对清单、工位版本锁、白名单文件及其 Git 基线。Build 输出
`data/components/<组件>-<版本>/`，包含 README、清单、声明的源码/参考/测试以及
`PACKAGE.json`、`ARTIFACT-MANIFEST.json`。清单包含每个文件长度/SHA 和完整 payload contentId；HMI 只允许已锁哈希的自有 DLL/HAD。
同名输出只有内容完全一致才复用，内容变化拒绝覆盖；失败后留下的
不完整目录也不被当成成功。无需新 GUI、后台服务或自动部署。

## 版本规则

- `component.json` 是组件版本与能力事实源，`config/component-versions.json` 是
  Station010 的**源码选用锁**，不是对在线 PLC 已安装库版本的检测或强制。
- 源码基线固定到 Git 锚点和显式审阅的工作树快照，不跟随 HEAD。改动候选文件必须更新版本、快照和说明。
  工位单独升级某个组件，另一个不必跟着升级。
- RC 是开发候选，`releaseEligible=false`，不是稳定版。后续修正用新 RC；正式版按
  主版本（不兼容接口）、次版本（兼容功能）、修订版本（兼容修复）管理。
- 发布时建立 `burster2316-v<版本>` / `kistler5867c-v<版本>` 标签，指向包含完整
  清单和文档的发布提交；代码来源提交可以更早。已发布标签/包不移动、不覆盖。
  本次仅准备本地候选，尚未创建标签或上传 Release。
- 现有库接口/错误码语义/单位也是兼容合同；不能只保持 FB 名称却改变含义。
- 原厂库只记录名称、实际解析版本及依赖，不随自研组件再分发。

## 从源码候选到安装库

2026-09-10 的 `0.1.0.1` 原生库独立消费未通过并已卸载，该失败记录保留。2026-09-16 新 `0.1.0.2` 已在隔离副本修正命名空间和 ctrlX 依赖，通过库及消费新编译；实际 Effective version、Company/Title/Version/namespace 和回读随新包提供。只加入通信对象，不包含工位全局变量/SFC；全程使用唯一 PLE。
不得把 ST 文件改后缀冒充库。新名称、命名空间和
依赖边界都需要新编译，不能直接沿用本站 FB 的编译结论。

项目接入时遵守 CpStudio 模型/接口所有权。旧 Peripheral 禁用/移除、可选 Channel
留空、AI 非生成区绑定与 HMI 放行必须一起检查。附带的 Station010 参考不是通用
安装器，不能照搬固定 IP、BMK、事件号或压缸工艺到新项目。

每次部署记录：组件版本 + 实际依赖版本 + 设备固件/配置 + 工位工程版本 + 验收结果。
回退同样是受控离线变更及新编译/下载；不得在线热替换 Socket 实例，也不得回到
原来的双连接抢占方案。既有机器在本次封装中保持不变。

## 验收边界

2026-09-10 的 Station010 完成过一轮左/中/右自动；不是独立安装库、多设备、
长期运行或产品质量的验收。下一阶段至少补齐结果数值/单位/判定、重复测量、取消、
断线及仪表/PLC重启恢复，验证旧结果不会被当新结果、错误保持且不自动重启测量。
Kistler 另验证选程/Ready、测量Start/End、实际传感器的复位方式和力故障保持。
未知固件/依赖项保持 pending，不能填写“最新版”或假定兼容。

版本元数据沿用官方能力：[Project Information](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_obj_project_information.html)、
[Library Manager](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_obj_library_manager.html)。

早期源码候选以 Danikor 的 `ec086680...` 为参考；本次独立封装使用其 `agent/danikor-mvp-protocol-simulator` 分支 `cf6c6fb...` 及已核验的 1.1.0.0 原字节。Git 提交只是源码锚点，二进制来源由其 BUILD-EVIDENCE 与精确 SHA 单独确认。继续复用两个现有打包器，不将原厂 Std 放进新包。
