# CpStudio + Git + MCP 协同工作流

## 目的

CpStudio 继续作为 OpCon 工程模型、层级、Handler、HMI 和符号配置的事实源；Git 记录模型与生成结果；AI 通过 codesys-persistent MCP 读取、编写和编译底层 PLC ST。三者各司其职，避免 CpStudio 重新生成时无声覆盖 AI 逻辑。

## 所有权边界

| 内容 | 事实源 / 修改入口 | 说明 |
|---|---|---|
| Station/Module/Command 层级、Handler、HMI、生成符号 | CpStudio | 先在 CpStudio 修改，再生成 |
| `Engineering_Data.xml`、HMI、公开配置和生成快照 | Git | 用于审计和生成机制分析，不直接代替 CpStudio |
| AI 自定义 POU、SqM/SqS 工艺细节、ST 修复 | `specs/` + `ai/` + `src/plc/` → PLE MCP/REST | `../Station010_0708` 已获用户授权作为受控集成工作工程；完整 AI-owned 对象和混合生成钩子分开管理 |
| EtherCAT/IO 工程 | IOE 2.6.4 | PLE 不得打开 IO 工程 |
| 真机连接、下载、启停、FORCE | 用户批准后执行 | 默认只做离线编译和仿真 |

## 一次 CpStudio 生成的标准闭环

1. 确认相关仓库工作区干净，并对 `.project` 做本地备份或工程归档。
2. 每次在 CpStudio 中只做一类可描述的改动。
3. CpStudio 重新生成后，先执行 `git diff`，不要立即修补生成物。
4. AI 通过 MCP 对 PLC `Application` 生成稳定文本快照。
5. 对比 CpStudio 模型、Symbolconfiguration、HMI/config 和 PLC 文本快照。
6. 把变化分成 CpStudio 所有、AI 所有和需要人工决策三类。
7. AI 只通过 MCP 写回 PLC，随后重新编译，以 `errors=0` 为验收标准。
8. 提交模型变化、可读生成物、PLC 文本快照、编译基线和分析结论。

## PLC 文本快照

内置 `get_all_pou_code` 会从项目根递归。在 Station010 上它会进入庞大的设备树并超过 120 秒。因此本仓库提供 `scripts/plc/export_plc_snapshot.py`：

- 使用已经打开的 primary PLC 工程，绝不自行 `se.projects.open()`；
- 只遍历 `Application` 分支；
- 不调用 save、compile 或任何在线/设备 API；
- 每个有文本内容的对象生成一个稳定命名的 `.st` 文件；
- `manifest.json` 不包含时间戳，记录对象路径、文件名和 SHA-256；
- 只删除上一版 manifest 明确拥有、而本次已经消失的旧快照文件。

### 通过 MCP 执行

先用正规 MCP `open_project` 打开目标 PLC 工程，再将下面三个全局量注入只读审计调用：

```python
SNAPSHOT_PROJECT_PATH = r"C:\path\Station.project"
SNAPSHOT_OUTPUT_DIR = r"C:\path\snapshot"
execfile(r"C:\path\McpCoding\scripts\plc\export_plc_snapshot.py")
```

导出后在 PowerShell 验证：

```powershell
.\scripts\plc\verify_plc_snapshot.ps1 `
  -SnapshotDirectory .\data\plc_snapshots\station010 `
  -ProjectPath ..\Station010_0708\Plc\Stat010_V5.11_CtrlX_PLC.project
```

连续导出同一工程应保持 `manifest.json` 和所有 `.st` 文件逐字不变。只有 PLC 对象路径、声明或实现发生变化时，Git diff 才应变化。

## 标准目录与 Post-export 信号

所有新项目采用 `docs/project_structure_standard.md` 定义的旁车结构。CpStudio
官方提供 Post-export script 挂钩；本项目自定义脚本
`scripts/cpstudio/post_export_signal.bat` 只发布被忽略的
`data/requests/export_request.json`，不启动 PLC Engineering/MCP、不编译也不执行
在线操作。当前唯一 persistent MCP 会话读取请求后，再根据
`ai/ownership.yaml`、`ai/hooks.yaml` 和 `ai/graphical.yaml` 串行完成审计与写回。

## Station010 当前基线

- `Plc/Stat010_V5.11_CtrlX_PLC.Struct.json` 中有 350 个 POU/GVL/DUT/Method/Action 类型对象；实际文本快照只收录声明或实现非空的对象。
- 当前私有仓库已经跟踪 CpStudio 模型、HMI/config、Symbolconfiguration 和两个 `.project`，但此前没有纯文本 ST 镜像。
- `../Station010_0708` 已由用户批准作为 CpStudio + MCP 受控集成工作工程；任何 PLC 写入仍必须先备份、导出文本快照，并且只经 MCP 执行。
- `.project` 是否作为 Station010 私有备份仓库的受控例外继续纳管，需要单独形成项目决策；不能依赖二进制 diff 理解 PLC 逻辑。

### 2026-08-18 当前未提交生成批次

检查期间发现 Station010 工作区已不再是 `b9b1161` 的干净状态；这些变化由外部 PLE/CpStudio 操作产生，不是快照工具写入：

- 共 26 个文件变化；`Engineering_Data.xml` 有大规模重排/删减；
- `ObjectVersions.xml` 移除了 BasMove、Kistler Maxymos、Scanner 和 Burster Resistomat 2316 对象版本；
- 11 个 HMI SmartForms 文件被删除，HMI 语言、视图和 config 同步变化；
- PLC `.project` 从 1,738,192 B 变为 1,597,120 B；
- 当前仍有用户 PLE 实例持有 PLC 工程锁，因此未执行 MCP 文本导出或编译。

用户已确认这批删除是有意建立最小干净框架。它将作为第一个完整的“生成前基线 → CpStudio 改动 → 生成后 diff → PLC 文本快照 → 编译”分析样本；此后逐个添加设备，设备层稳定后再增加自动 Chains。

## 生成机制实验记录

每次实验只改变一个 CpStudio 概念，并记录以下信息：

| 日期 | CpStudio 单一改动 | 模型/XML 变化 | PLC ST 变化 | HMI/符号变化 | 结论 |
|---|---|---|---|---|---|
| 待执行 | 示例：新增一个 Module 变量 | 待记录 | 待记录 | 待记录 | 待记录 |
