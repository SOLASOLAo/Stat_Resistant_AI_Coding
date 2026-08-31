# CpStudio + ctrlX MCP 项目目录标准

## 目标

该标准用于所有必须保留 CpStudio 的 OpCon/ctrlX 项目。CpStudio 继续承担
供应商模型和标准对象配置，AI 通过 PLC Engineering MCP/REST 维护应用逻辑，
Git 同时记录生成结果和可读工程资产。

标准化的是 AI 工程旁车目录，不移动或重命名 CpStudio 生成的 Station 目录，
也不修改供应商 `Std` 目录。

## 工作区布局

```text
<ProjectRoot>/
├─ <StationDirectory>/          CpStudio/PLC/HMI 集成工程
├─ Std/                         供应商标准对象，只读
└─ McpCoding/                   AI 工程与自动化控制仓库
   ├─ project-pack.json          Project Pack 唯一入口与源文件索引
   ├─ schemas/                   Project Pack/流程 JSON Schema
   ├─ config/                   工程定位与质量门禁
   ├─ specs/                    审核后的项目需求
   ├─ ai/                       AI 对象归属、钩子和图形属性
   ├─ src/plc/                  AI 拥有的可读 PLC 源码
   ├─ catalog/                  已验证 Unit/AddOn/Peripheral 接口
   ├─ generated/                可重建的流程计划，禁止手改
   ├─ scripts/                  CpStudio/PLC/IOE/Git 自动化
   ├─ tests/                    静态、编译和仿真检查
   ├─ data/                     请求、快照、报告和备份，不入 Git
   └─ docs/                     架构、分析和操作文档
```

每个工程旁车根目录还必须有 `TEAM_SETUP.md`，记录团队工作站部署、外部闭源资产、固定工具版本、
MCP 配置和首次离线验收；它与记录开发进度的 `HANDOVER.md` 分离。`scripts/setup/` 保存不会启动
IDE、不会写工程的环境体检脚本。

Station 目录继续保留供应商原始结构，例如 `Engineering/`、`Plc/`、`Hmi/`、
`EventRecorder/` 和 `PublicConfig/`。这些目录可能被 CpStudio 的相对路径和
生成逻辑引用，禁止为了美观重新组织。

## 目录职责

### `config/`

- `project.yaml`：Station、Std、PLC/IO 工程、IDE profile、REST 基地址和仓库地址。
- `quality-gates.yaml`：编译错误基线、对象归属、安全审批和静态检查策略。

每个新项目由 `ctrlx-ai-coding/scripts/New-CtrlXOpconProject.ps1` 渲染这两个文件。
路径统一使用相对于 `McpCoding` 根目录的正斜杠形式，避免把开发者用户名写进仓库。

### `specs/`

结构化记录已经由用户确认的需求：

- `station.yaml`：Mode Handler、Command Handler 和标准 AddOn；
- `io.yaml`：业务使用的 BMK、方向、用途及已验证通道；
- `events.yaml`：事件符号、设计号、类别和复位条件；
- `units/`：实例、类型版本、I/O 绑定、手动联锁和 Home 条件；
- `processes/`：经审阅的流程事实源，包含 Chain 接口归属、Step ID/Kind/Comment、
  中英文操作提示、需求、步骤验收和验收测试；
- `chains/`：步骤、短 Comment、启动/完成/跳过条件与取消清理。

聊天是需求入口，`specs/` 是确认后的长期事实源。未确认内容必须明确标记
`pending`，不能写成已验证事实。

### `ai/`

该目录描述“AI 增量层”，不是第二份 PLC 工程：

- `ownership.yaml`：对象负责人、源码位置和写入模式；
- `hooks.yaml`：CpStudio 生成对象中必须保留的最小集成调用和行为；
- `graphical.yaml`：SFC Step Comment 等通过正式 REST 接口维护的图形属性。

支持四种写入模式：

| 模式 | 用途 |
|---|---|
| `full_object` | 完整 AI-owned POU，经 MCP 写声明和实现 |
| `implementation` | 只替换 Action/Method 实现 |
| `semantic_merge` | 混合对象，只恢复声明的调用/接线，不覆盖整个生成对象 |
| `graphical_attributes` | SFC 图形属性，经 REST GET/hash/PUT/readback |

### `src/plc/`

- `common/`：跨项目通用、执行代码不依赖 Station/BMK/项目事件号的 FB；
- `project/<StationId>/`：整个对象由 AI 拥有的项目专用 POU。

源码文件采用稳定的 Declaration/Implementation 分段格式。它们只能通过 MCP
同步到加密 `.project`，随后必须回读并离线编译。混合生成对象不在这里保存完整
副本，避免旧副本覆盖 CpStudio 的新内容。

PLC ST 的条件排版在各项目中统一：单个条件写成 `IF ( Condition )`；复合条件的
每个独立条件都加括号，括号内侧各留一个空格；条件换行时 `AND`/`OR` 留在上一行末尾。项目静态门禁应
同时拒绝续行开头的逻辑运算符和未以括号开始的 `IF`/`ELSIF` 条件。

### `catalog/`

每个对象按精确名称和版本建目录，例如：

```text
catalog/units/NexeedBasMoveStandard/V2.1/unit.yaml
catalog/addons/NexeedControlOnAddon/V2.0/addon.yaml
catalog/peripherals/NexeedIpBurster2316/V1.0/peripheral.yaml
```

只记录已经核对的命令、参数、反馈、调用协议、清理要求、已知限制和本地只读
文档路径。不复制闭源代码或整本手册。相同资产在两个以上项目验证后，才提升到
独立 `BppAutomationCommon` 仓库和版本化 PLC Library。

### `scripts/`

- `cpstudio/`：官方导出钩子调用的轻量自定义脚本；
- `plc/`：PLE ScriptEngine/MCP/REST 辅助；
- `ioe/`：IO Engineering IPC；
- `git/`：差异、审计、报告和提交辅助。
- `project/`：Project Pack 的 Build/Check 与流程计划生成。
- `setup/`：新电脑所需目录、软件、MCP、补丁和配置的只读体检。

Post-export 脚本只允许向 `data/requests/pending/` 原子发布独立请求，禁止启动第二个
PLC Engineering 或 MCP server。离线消费者以
`pending → processing → done/failed` 串行处理并把 JSON/Markdown 报告写入
`data/reports/cpstudio/`；PLC 写入仍由当前唯一 persistent MCP 会话显式执行。

`scripts/project/Build-CtrlXOpconProjectPack.ps1` 是 Phase 2 的流程计划生成器；它只读取
Project Pack 与其引用的事实源，不启动 CpStudio、PLE、MCP 或 REST。

### `tests/` 与 `data/`

`tests/` 中只放可重复检查；`data/` 中放运行时请求、快照、报告和本地备份，默认
不入 Git。真机连接、下载、启停和 FORCE 不属于自动测试，始终需要用户明确批准。

### Project Pack、Schema 与生成计划

- `project-pack.json`：项目入口，只引用 `config/`、`specs/`、`catalog/`、`ai/` 和 HMI
  配置中的现有事实，不复制一份详细配置；
- `schemas/project-pack.schema.json` 与 `schemas/process.schema.json`：约束包结构、
  流程步骤和追溯字段；
- `generated/engineering-plan.json`：由 Build 确定性生成的 SFC 计划、操作提示、
  测试骨架、需求追溯和源文件指纹；禁止手改。
- 可选 `sources.ioDesignators`：引用当前工位完整 DIDO CSV。配置后，Build 同时生成
  `generated/cpstudio-io-designators.asc`，Check 对 CSV、生成器和 ASC 做逐字节漂移门禁；
  不配置时现有项目行为不变。

Phase 2 标准命令为：

```powershell
pwsh -File scripts/project/Build-CtrlXOpconProjectPack.ps1 `
  -Command Build -EngineeringRoot . -RequireReady -Json

pwsh -File scripts/project/Build-CtrlXOpconProjectPack.ps1 `
  -Command Check -EngineeringRoot . -RequireReady -Json
```

`Build` 校验事实源并重建计划；`Check` 重算并逐字校验已生成计划，源文件漂移或
产物被手改都会失败。Runner 只把 `Check -RequireReady` 作为进入后续工程阶段的
前置门禁。两条命令都不会在 CpStudio 创建接口，也不会向 PLE `.project` 写入代码或图形。
CpStudio Export 后，Stage 1 还会把该 CSV 与 `paths.bus_config` 指向的 BusConfig 做
只读逐通道核对；不一致时以 `IO_DESIGNATOR_EXPORT_MISMATCH` 阻断。Stage 2 将匹配结果、
CSV SHA 和 BusConfig SHA 绑定到 operation/action，后续源文件漂移会失败关闭。

## 日常工作流

### 只改 PLC 工艺逻辑

1. 更新或确认 `specs/`；
2. AI 修改 `src/plc/` 或声明的 mixed hook；
3. 经 MCP/REST 写入并回读；
4. 离线编译、静态检查、报告和提交；
5. 不运行 CpStudio。

### 修改层级、标准 Unit、BMK、HMI、Event 或 StationData

1. 用户在 CpStudio 修改并导出；
2. 官方 Post-export hook 调用项目自定义信号脚本；
3. 运行 `Invoke-PostExportAudit.ps1`，先生成不启动 IDE 的 Git/指纹/ownership 离线报告；
4. 根据 `ownership/hooks/graphical` 审计或恢复 AI 增量；
5. 检查 I/O Mapping、BinIo、Symbol Configuration；
6. 离线编译、生成报告，经确认后提交。

### 新项目初始化

1. 保留供应商 Station 与 `Std` 原始布局；
2. 对共享初始化器执行 `-WhatIf`，核对 Station/Std/输出路径；
3. 运行 `New-CtrlXOpconProject.ps1` 创建全新的 `McpCoding` 旁车，不覆盖已有目录；
4. 建立初始 Station/IO/Unit/Event/Chain 规格；
5. 只登记该项目实际使用且已核对的 Catalog 条目；
6. 导出 PLC 文本基线并记录编译警告基线；
7. 配置 CpStudio Post-export hook；
8. 运行 `tests/static/Test-ProjectFramework.ps1` 与 `tests/cpstudio/Test-PostExportQueue.ps1`。

## 版本和发布

- CpStudio 生成批次和 AI 逻辑批次可以分别提交；如果同一 `.project` 无法拆分，
  提交信息必须同时描述两部分。
- 通用源码使用语义化版本；编译产生的 `.compiled-library` 不进入本仓库，放内部
  制品库或受控 PLE Library Repository。
- README 说明项目是什么，`specs/` 说明要做什么，`ai/` 说明谁维护什么，
  HANDOVER 说明当前状态，TODO 说明下一步。
