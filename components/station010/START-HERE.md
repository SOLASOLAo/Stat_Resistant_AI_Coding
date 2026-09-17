# Station010 简短使用说明

> 2026-09-16：实际 Station010 已选择通用命名原生库，当前入口为 McpCoding/config/station010-native-selection-20260916.json 与 docs/components/STATION010-NATIVE-20260916.md；以下 rc.4 源码候选信息保留作历史。
**2026-09-14 更新：用户批准后，现场 IPC HMI 已更新到 0.1.0.2 并重启，隐藏启动采集配置已核对，电阻结果及中文菜单正常显示。** 现场原 HMI 已备份；晚开曲线仍需新一轮左中右测量验收，本次未下载 PLC 或触发自动。CpStudio 的 HMI Export 或重新打开设计器会重建启动配置，后续部署仍须最后带上 `data/reports/hmi/force-trace-upgrade-20260914/startup-overlay/` 的 Gui.config 和启动 SFC；若导出又变化，用既有 New-ForceTraceStartupOverlay 脚本按最新文件生成。其余候选包保留原样。

本次已保存，不安排后台任务。开发候选入口仍为 **`McpCoding/data/components/station010-set-20260911-rc.4/`**；当前仅确认上述 HMI 已部署，组合包并非整站现场验收版本，不需要把内部哈希/清单校验作为日常使用步骤。

| 内容 | 目录 | 用法与当前状态 |
|---|---|---|
| Burster 2316 | `packages/burster2316-0.1.0-rc.2/` | 单连接驱动源码及接入说明；通过标准 Unit 接口绑定。独立原生库消费尚未通过，不能当作可安装 PLC 库。 |
| Kistler 5867C | `packages/kistler5867c-0.1.0-rc.2/` | 保留现有标准驱动，参照包内 README 配置 Unit、Channel、程序和调用钩子。 |
| 力曲线 | `packages/bpp-forcetrace-0.1.0-rc.2/` | 自有 DLL/HAD **0.1.0.2**、原生 Text/视图及 PLC 发布器；晚开页修复还需要下行的隐藏启动配置。 |
| 本站调用与界面 | `Station010-reference/` | 最新电阻判定/左中右绑定/换型实现；`native/ResistanceTexts.cpsds` 和 `native/UserDefined.sfc` 是本站原生文本/视图参考；`startup-overlay/` 是曲线隐藏启动配置。 |

接入仍使用 CpStudio 建模型、导入自有 Text/视图和 HMI add-on，按本项目变量绑定，PLC 实现经原有 PLE 合并。依赖既有 OpCon/CpStudio V5.11、ctrlX PLC 2.6.8 和标准 Burster/Kistler 库；不要把本站 BMK、地址及工艺参数直接搬到别的工位。具体字段需要时再查各组件 README。

本次变化：每次成功测量后按本次 Ω 上下限判定并锁存，等于边界算 OK；界面 OK/NOK 取各位置电阻结果，不取 Kistler Unit 的 OK/NOK。数值显示仍为 mΩ。包中保留中文补齐、晚开曲线修复与换型清理。

已经通过的证据：电阻 12 项边界检查、力/Kistler/换型检查、曲线晚开/重开及中英文离线检查；保存的 PLC 工程此前 F11 为 0 errors / 5 原有 warnings。**独立 Burster 安装库和现场验收仍未完成**，本轮没有下载 PLC、部署 IPC 或推送 GitHub。

旧版均保留。rc.3 曾因两种 PowerShell 的清单排序不同而失败，不能当作通过版本；小幅调整后的 rc.4 已通过当前构建与两种 PowerShell 接收校验。相关哈希/日志仅作内部记录。现场确认前继续把 rc.4 当候选，不必围绕校验体系继续扩展。
