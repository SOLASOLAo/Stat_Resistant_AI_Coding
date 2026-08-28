# 团队交接与工作站部署指南

> 适用项目：BPP Resistant Station / Station010
> 适用流程：CpStudio V5.11 + ctrlX PLC Engineering + persistent MCP + Codex
> 验证基线：2026-08-19

## 1. 这份文件解决什么问题

本文件用于让一名新同事在新的 Windows 电脑上复现当前开发环境，并安全接手项目。

文档职责保持分离：

| 文件 | 用途 |
|---|---|
| `TEAM_SETUP.md` | 新电脑安装、仓库克隆、MCP 配置和首次验收；稳定、少改 |
| `HANDOVER.md` | 当前项目进度、最近修改和遗留问题；每次重要会话更新 |
| `AGENTS.md` | AI 在仓库内必须遵守的权限和安全规则 |
| `TODO.md` | 下一步任务和验收条件 |
| `config/project.yaml` | 当前 Station、工程文件和工具版本的机器可读定位 |

完成本指南后，同事应能：

1. 同时取得 AI 工程仓库、Station010 集成工程和只读 `Std`；
2. 启动唯一的 persistent MCP 会话；
3. 经 MCP 打开 PLC 工程并完成离线编译；
4. 明确 CpStudio、PLC Engineering 和 IO Engineering 的工作边界；
5. 不连接、不下载、不启停实体 PLC，完成纯离线交接验收。

## 2. 部署前必须取得的内容

### 2.1 Git 仓库

| 本地目录 | GitHub 仓库 | 权限 |
|---|---|---|
| `McpCoding` | `https://github.com/SOLASOLAo/Stat_Resistant_AI_Coding.git` | AI 框架和可读源码 |
| `Station010` | `https://github.com/SOLASOLAo/Stat_Resistant_Station010.git` | 私有集成工程，需要仓库授权 |
| `McpCoding/ctrlx-ai-coding` | `https://github.com/SOLASOLAo/ctrlx-ai-coding.git` | MCP 方法论和 ctrlX 兼容补丁 |

### 2.2 不能从本仓库分发的公司资产

- `Std/`：OpCon/Nexeed 标准 Objects、Peripherals 和闭源手册，只能通过公司授权渠道复制；
- CpStudio V5.11、ctrlX WORKS/PLC Engineering/IO Engineering 安装介质和许可证；
- Bosch/OpCon 托管库。目标电脑安装完成后必须存在
  `C:\ProgramData\Rexroth\PLE-V-0206\0\Studio\Managed Libraries`；
- 现场 PLC 凭据、设备证书、IP 配置和任何生产数据。

不要把上述资产、许可证、密码、Token 或个人 `config.toml` 提交到 GitHub。

### 2.3 HMI 本机字段

Station010 仓库中的 `Hmi/OpCon.HMI.Modulo.vwn` 只保存脱敏项目元数据，HMI 管理密码和项目
密钥字段在 Git 版本中为空。新电脑如确需这些字段，由项目负责人通过公司批准的本地渠道提供，
再使用官方工程工具写入本机副本；不要通过 Git、聊天记录或交接文档分发。

本机配置后 `.vwn` 可能长期显示为 modified，这是预期现象。提交 HMI 时必须逐文件暂存并做
字段级审阅；禁止把 `.vwn`、`Hmi/PlcHandlerL1.ini` 或其他连接配置随整体暂存重新上传。
具体画面文件和注册边界见 `docs/hmi_userdefined_integration.md`。

## 3. 标准工作区布局

根目录可以放在任意本地磁盘，但三个项目之间的相对层级必须保持一致：

```text
<WorkspaceRoot>/
├── Station010/               CpStudio/PLC/HMI 受控集成工程
├── Std/                      供应商标准对象，只读
└── McpCoding/                AI 工程仓库
    └── ctrlx-ai-coding/      独立方法论/补丁仓库
```

示例克隆命令：

```powershell
$projectWorkspace = 'C:\Engineering\BPP_ResistantStation'
New-Item -ItemType Directory -Path $projectWorkspace -Force | Out-Null
Set-Location $projectWorkspace

git clone https://github.com/SOLASOLAo/Stat_Resistant_AI_Coding.git McpCoding
git clone https://github.com/SOLASOLAo/Stat_Resistant_Station010.git Station010
git clone https://github.com/SOLASOLAo/ctrlx-ai-coding.git McpCoding\ctrlx-ai-coding
```

随后由项目负责人通过公司授权渠道把 `Std` 放到同级目录。不要自行从其他项目拼凑不同版本的
`Std`。

## 4. 已验证的软件基线

新电脑首次部署优先使用以下精确版本，升级必须单独验证：

| 组件 | 已验证版本/要求 | 默认路径或标识 |
|---|---|---|
| Windows / PowerShell | Windows 开发工作站；PowerShell 7.5+ | `%ProgramFiles%\PowerShell\7\pwsh.exe`，必须支持 `ConvertFrom-Json -DateKind` |
| CpStudio | V5.11 / 5.11.0.169 | `C:\Nexeed\Automation\CSV5_11\Bosch.Nexeed.Automation.CpStudio.exe` |
| ctrlX PLC Engineering | PLE-V-0206.8 | profile 必须精确为 `ctrlX PLC 2.6.8` |
| ctrlX IO Engineering | IOE-V-0206.4 | `C:\ctrlXWORKS\ctrlXIOEngineering\IOE_V_0206\Studio\Common\ctrlX-IO-Engineering.exe` |
| Node.js / npm | 当前验证 24.18.0 / 11.16.0 | 命令必须进入 `PATH` |
| `codesys-mcp-persistent` | 固定 0.6.3 | 必须使用 `persistent` 模式 |
| Git for Windows | 含 Git Credential Manager | 私有仓库账号须获授权 |
| Codex | 桌面、CLI 或 IDE 扩展 | 本地主机上的客户端共享 MCP 配置 |

PLC Engineering 可执行文件默认路径：

```text
C:\ctrlXWORKS\ctrlXPLCEngineering\PLE_V_0206\StudioPlc\Common\ctrlX-PLC-Engineering.exe
```

### Station010 项目专用 EtherCAT ESI

Kistler maXYmos BL `5867C001` 的 ESI 和 quick-start guide 属于外部技术资料，不进入 Git。它们必须按
`config/project.yaml` 中的相对路径放在同级 `Technical Docs/`。首次部署或 IOE 设备仓库丢失时，先关闭手动打开的
ctrlX IO Engineering，然后在 `McpCoding` 根目录运行：

```powershell
.\scripts\ioe\Install-EtherCatEsi.ps1 `
  -EsiPath '..\Technical Docs\5867c-maxymos-bl-fieldbus-descr-ec-pn-eip-25.1.0\EtherCAT\Kistler_Type_5867C_V1.xml' `
  -SearchTerm '5867' `
  -ExpectedName 'maXYmos BL 5867C' `
  -ExpectedVendor 'Kistler' `
  -ExpectedDeviceId '58A_0000E52F00000001' `
  -ExpectedVersion 'Revision=16#00000001'
```

脚本只通过 ctrlX IO Engineering 2.6.4 的官方设备仓库接口导入并回读 ESI，不打开或修改 PLC/IO 工程，也不连接
控制器。PLE 2.6.8 的设备仓库不带 EtherCAT XML 转换插件，不要把同一 ESI 导入 PLE。

EtherCAT Peripheral 的正确建立顺序是：先用 ctrlX IO Engineering 在同一 Station 目录的 `*_CtrlX_IO.project` 中完成从站组态并保存，
再在 CpStudio 中点击“读取/导入 ctrlX IDE EtherCAT IO 组态”。CpStudio 会依据导入的 IO 设备自动匹配标准
Peripheral；不在 CpStudio 工具箱中手动拖 EtherCAT Peripheral。Station010 的 Kistler 节点为 `_100A104`，真实设备由 ESI
显示为 `maXYmos BL 5867C`；CpStudio 自动匹配的 `Kistler MaXYmos BL5867B TL5877B0` 是旧标准适配器标题，不应通过修改
只读 `Std` 来改名。

## 5. 安装 persistent MCP 和 ctrlX 补丁

以普通用户 PowerShell 安装固定版本：

```powershell
npm install -g codesys-mcp-persistent@0.6.3
codesys-mcp-persistent --version
```

然后应用本项目已经验证的 ctrlX 兼容补丁：CRLF、connector I/O Mapping，以及有界编译消息读取：

```powershell
Set-Location '<WorkspaceRoot>\McpCoding\ctrlx-ai-coding\patches\codesys-mcp-persistent-crlf'
.\apply-crlf-patch.ps1 -Check
.\apply-crlf-patch.ps1
.\apply-crlf-patch.ps1 -Check
```

最终一次 `-Check` 必须全部通过。每次重新安装或升级 npm 包后都要重新执行补丁；未经验证不要擅自
升级 0.6.3。

## 6. 配置 Codex MCP

OpenAI 官方说明：Codex 默认从 `~/.codex/config.toml` 读取 MCP 配置；同一主机上的 Codex
桌面客户端、CLI 和 IDE 扩展可以共享该配置。官方页面：
<https://developers.openai.com/codex/mcp/>。

本仓库提供不含账号、模型供应商和 API Key 的干净片段：
`config/codex-mcp.toml.example`。

操作方法：

1. 打开 `%USERPROFILE%\.codex\config.toml`；不存在则新建；
2. 只把样例中的 `[mcp_servers.codesys-persistent]` 段合并进去；
3. 把 `--workspace` 改成自己的 `<WorkspaceRoot>`；
4. 核对 `--codesys-path` 和 profile；
5. 重启 Codex/IDE 扩展，在 MCP 页面或 `/mcp` 中确认服务器存在。

不要覆盖同事已有的模型、账号或其他 MCP 配置，也不要复制项目负责人的整份个人
`config.toml`。

安装团队版本的 ctrlX/OpCon Skill（只同步该 Skill，不修改 MCP 或个人账号配置）：

```powershell
Set-Location '<WorkspaceRoot>\McpCoding\ctrlx-ai-coding'
.\scripts\Install-CtrlXOpconSkill.ps1 -Force
.\scripts\Install-CtrlXOpconSkill.ps1 -Check
```

安装或更新后重新加载 Codex。以后可显式使用 `$ctrlx-opcon-engineering` 进入新项目初始化、
CpStudio 导出审计、PLC 离线开发或故障诊断流程。

## 7. 一键只读体检

在 `McpCoding` 根目录运行：

```powershell
.\scripts\setup\Test-TeamWorkstation.ps1
.\tests\static\Test-ProjectFramework.ps1
.\tests\cpstudio\Test-PostExportQueue.ps1
```

第一条检查：三仓库布局、`Std`、两个工程文件、三套 IDE、托管库、Node/npm、MCP 版本、
兼容补丁和 Codex MCP 配置。它不会启动 IDE、不会修改工程、不会连接 PLC。

如果安装路径不同，可查看参数：

```powershell
Get-Help .\scripts\setup\Test-TeamWorkstation.ps1 -Detailed
```

## 8. 首次离线验收

完成体检后，只保留一个使用 `codesys-persistent` 的 Codex 窗口，然后按顺序执行：

1. MCP `get_codesys_status`，等待状态为 ready；
2. MCP 打开 `config/project.yaml` 指向的 PLC 工程；
3. 执行一次完整 `compile_project`；
4. 当前 Station010 正式离线验收基线为 **0 errors / 4 warnings**；
5. 回读一个 AI-owned POU，例如 `Application/Fbs/FB_OperatorButton`；
6. 核对可读源 `src/plc/common/FB_OperatorButton.st`；
7. 关闭/交接前确认两个 Git 工作树没有未知改动。

首次验收不需要实体 PLC。禁止为了“测试环境”执行连接、下载、启动、停止或变量写入。

### 8.1 可选 P1.3a Runner Host

P1.3a Host 是当前用户交互会话中的状态/生命周期进程，可选注册为 AtLogOn Scheduled Task。
它不会启动 Broker、MCP、PLE、Node 或在线 PLC 操作；同会话 Agent 不存在时显示
`WAITING_FOR_AGENT`。自动 action 消费尚未实现，因此不应把它当作无人值守工程执行器。

```powershell
dotnet build .\ctrlx-ai-coding\src\runner\CtrlX.OpCon.Runner.Host\CtrlX.OpCon.Runner.Host.csproj -c Release
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Status
.\scripts\runner\Invoke-CtrlXOpconRunnerHost.ps1 -Command Install -WhatIf
```

确认预览目标正确后才去掉 `-WhatIf` 完成安装；之后 `-Command Start` 默认只通过这条已验证的
Scheduled Task 启动。`-DevelopmentProcess` 仅供显式开发测试使用。安装是可选项，不影响手动运行
既有 P1.1/P1.2 流程。

## 9. 三套工程软件的边界

| 修改内容 | 唯一入口 |
|---|---|
| Station/Mode/Command 层级、标准 Unit/AddOn/Peripheral、HMI、Event、StationData、BMK | CpStudio |
| PLC ST、独立 FB、Chain Action/Method、SFC 图形属性 | PLC Engineering MCP/REST |
| EtherCAT 硬件树和 IO 工程 | ctrlX IO Engineering 2.6.4 / 受控 IOE IPC |
| 可读需求、AI 归属、Catalog、工具和测试 | `McpCoding` Git 仓库 |

严禁：

- 用 PLC Engineering 打开 `*_IO.project`；
- 直接修改加密 `.project` 文件字节；
- 修改、删除或移动 `Std`；
- 同时开多个使用同一 PLE profile 的 MCP/Codex 会话；
- 未经现场负责人批准连接、下载、启停或 FORCE 实体 PLC。

## 10. 团队日常交接流程

由于 `.project` 是不可文本合并的加密容器，同一个 Station 同一时间只允许一名工程师作为写入者。

接手前：

```powershell
git -C <WorkspaceRoot>\McpCoding pull --ff-only
git -C <WorkspaceRoot>\Station010 pull --ff-only
```

开始工作前阅读：`AGENTS.md` → `HANDOVER.md` → `TODO.md` → 本次相关 `specs/`。

完成一个受控批次后：

1. CpStudio 生成批次与 AI/MCP 修复批次尽量分开；
2. 检查 Station 工程 Git diff 和 PLC 文本快照；
3. 回读 AI-owned POU/混合 hook；
4. 完整离线编译；
5. 更新 `HANDOVER.md` 和 `TODO.md`；
6. 提交并推送两个仓库中各自的修改；
7. 告知下一位同事提交号、编译结果、未提交噪声和是否存在打开的 IDE/锁文件。

不要尝试手工合并两个不同版本的 `.project`。出现二进制冲突时停止写入，由项目负责人选择明确
基线后重新应用另一批可读规格/源码。

## 11. 常见问题

| 症状 | 处理 |
|---|---|
| 私有 Station 仓库反复要求登录 | 使用公司批准的 GitHub 账号和 Git Credential Manager 完成一次浏览器登录；不要把 PAT 写入仓库 |
| `codesys-mcp-persistent` 找不到 | 核对 `npm root -g` 与 npm 全局 bin 是否在当前用户 `PATH` |
| MCP 一直不 ready | 核对 PLE exe、精确 profile、是否有第二个 Codex/MCP 实例，以及 `%TEMP%\codesys-mcp-persistent` 日志 |
| 编译工具报 `unexpected token '\r'` | 重新执行 ctrlX 兼容补丁并运行最终 `-Check` |
| PLE Build 已完成但 MCP 编译超过 300 s | 重新执行 ctrlX 兼容补丁并重启已卡住的 persistent 会话；补丁后 Station010 实测约 7.6 s |
| OpCon 库无法解析 | 核对 PLE 版本和 Managed Libraries；不要从其他版本目录随意复制单个库 |
| IO 工程提示版本转换或 PLE 崩溃 | 立即停止；IO 工程只能用 IOE 2.6.4 打开 |
| 工程提示 `already being edited` | 先确认是否有活的 PLE/IOE 进程；不得在活进程持锁时删除 `.~u` |
| CpStudio 改名后出现旧 `bus_*` 错误 | 同时审计 I/O Mapping 与 Symbol Configuration，按既有工作流修复后重新编译 |

## 12. 交接验收清单

- [ ] 三个 Git 仓库均克隆到标准相对位置；
- [ ] 私有 Station 仓库可以 pull/push；
- [ ] `Std` 由公司授权渠道提供且保持只读；
- [ ] CpStudio 5.11、PLE 2.6.8、IOE 2.6.4 和 Managed Libraries 均存在；
- [ ] `codesys-mcp-persistent --version` 为 0.6.3；
- [ ] ctrlX 兼容补丁最终 `-Check` 通过；
- [ ] Codex 能看到 `codesys-persistent` MCP；
- [ ] 工作站体检和目录静态测试通过；
- [ ] Station010 离线编译达到 0 errors / 6 warnings；
- [ ] ctrlX/OpCon Skill 安装后的 `-Check` 与 Post-export 队列自测通过；
- [ ] 未进行任何未经批准的真机操作；
- [ ] 新同事知道谁拥有当前 Station 写入权。
