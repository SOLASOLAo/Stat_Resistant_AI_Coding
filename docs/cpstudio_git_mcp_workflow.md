# CpStudio + Git + MCP 协同工作流

## 目的

CpStudio 继续作为 OpCon 工程模型、层级、Handler、HMI 和符号配置的事实源；Git 记录模型与生成结果；AI 通过 codesys-persistent MCP 读取、编写和编译底层 PLC ST。三者各司其职，避免 CpStudio 重新生成时无声覆盖 AI 逻辑。

## 所有权边界

| 内容 | 事实源 / 修改入口 | 说明 |
|---|---|---|
| Station/Module/Command 层级、Handler、HMI、生成符号 | CpStudio | 先在 CpStudio 修改，再生成 |
| `Engineering_Data.xml`、HMI、公开配置和生成快照 | Git | 用于审计和生成机制分析，不直接代替 CpStudio |
| AI 自定义 POU、SqM/SqS 工艺细节、ST 修复 | `specs/` + `ai/` + `src/plc/` → PLE MCP/REST | `../Station010` 已获用户授权作为受控集成工作工程；完整 AI-owned 对象和混合生成钩子分开管理 |
| EtherCAT/IO 工程 | IOE 2.6.4 | PLE 不得打开 IO 工程 |
| 真机连接、下载、启停、FORCE | 用户批准后执行 | 默认只做离线编译和仿真 |

## 一次 CpStudio 生成的标准闭环

1. 确认相关仓库工作区状态，并验证 Git/工程归档能恢复精确起点；无法恢复时只建立一个内容寻址 checkpoint。
2. 每次在 CpStudio 中只做一类可描述的改动。
3. CpStudio 重新生成后，先执行 `git diff`，不要立即修补生成物。
4. AI 通过 MCP 对 PLC `Application` 生成稳定文本快照。
5. 对比 CpStudio 模型、Symbolconfiguration、HMI/config 和 PLC 文本快照。
6. 把变化分成 CpStudio 所有、AI 所有和需要人工决策三类。
7. AI 只通过 MCP 写回 PLC，随后重新编译，以 `errors=0` 为验收标准。
8. 提交模型变化、可读生成物、PLC 文本快照、编译基线和分析结论。

### EtherCAT BMK 改名闭环（2026-08-22 实测）

对已映射的 EtherCAT 通道修改 BMK，按以下顺序执行：

`CpStudio Save → Write peripheral and I/O designators to PLC IDE → Export #1 → Link I/O with variables in PLC IDE → 审计/合并 mixed ST 引用 → PLE Build 0 errors → 条件 Export #2 → final Build`

各步骤职责不同：

- Save 只更新 CpStudio 模型和公开 BusConfig。
- Write designators 更新 IO Engineering 工程，不会同步 PLC connector mapping。
- Export #1 更新 PLC `BinIo` 声明及 HMI/Event 生成物；旧 connector mapping 可能暂时导致 `bus_<旧名> is no component of BinIo`。
- Link I/O 才把物理通道映射切换到新的 `BinIo` 成员。
- CpStudio 不会替换 mixed/AI ST 中对旧 BMK 的直接引用；只能按 ownership/hooks 清单做受保护的语义合并。
- Build 必须先恢复到 0 errors。若 Export #1 的 OPC UA Method、PersistentVars 或 Symbol 后处理失败，或目标 Symbol 未正确发布，再执行 Export #2 和最终 Build；双 Export 不是所有 CpStudio 改动的固定规则。

CpStudio Export 期间不得并发读取、打开或更新 Symbol Configuration。若出现 `This object is already in use`，先停止并发访问；锁仍存在时，在同一个 PLE 进程内 Save → Close → Open，重新 Build 后再 Export，禁止启动第二个 PLE。

“界面无红字”不足以作为成功标准；必须核对完整 Output、I/O 映射、mixed 引用、Symbol 后处理和最终 Build。普通变量的条件二次 Export 与失效签名处理见 `docs/symbol_configuration_export_cycle.md`。

### 断网时的本地检查

断网但仍需继续 CpStudio 工作时，先完成 Export，再保存并关闭所有 PLE 以及
占用 `codesys-persistent` 的 Codex/VS Code 窗口，然后双击
`scripts/cpstudio/Run-OfflinePostExportCheck.cmd`。它不是 Post-export hook，
不会在导出期间与 Symbol Configuration 抢锁。

检查器只在全机 0 个 PLE、0 个既有 MCP 时启动一个自己拥有的本地会话，依次
执行 `open_project → compile_project → get_compile_messages → shutdown_codesys`；
它不调用修改或保存工具；已验证的 MCP no-save 补丁会在工程为 dirty 时拒绝
Build，并在 Build 前后核对 `.project` SHA-256。它不调用任何真机在线能力。
结果写入 `data/reports/offline-post-export/`，联网后可直接作为 AI 诊断输入。

离线判断规则保持简单：

- Build 有 errors：先修 Build，不做 Export #2；`bus_* ... BinIo` 且尚未 Link I/O
  时先做 Link I/O；若已经做过仍报错，不重复 Link，等待 AI 检查 mixed/旧映射。
- Build 为 0 且 Export #1 明确出现 OPC UA/PersistentVars/Symbol 后处理失败：做 Export #2。
- Build 为 0 且 CpStudio Output 无红字：完成，不固定要求 Export #2。
- `This object is already in use`：关闭并发占用后重试当前 Export，不把它误算成新一轮 Export。
- fresh Build 仍报告旧 Symbol 签名：停止猜测，等待 AI/工程师审查清理。
- Export #2 必须能关联到上一份 `NEEDS_EXPORT_2` 报告和随后产生的新 request；
  对象占用、导出次数误选、Output 待确认或 Link I/O 中断会携带同一个 Export #2
  anchor，重试不增加次数。Export #2 一旦真正进入 Build，anchor 即被消费，不会被后续
  新流程误复活。
- Export #1 没有带时间戳的 Post-export request 时，不创建 Export #2 anchor；先确认
  signal-only Post-export 脚本并重新执行 Export #1。
- 全局检查器锁覆盖 anchor 读取到报告写入；锁竞争、权限、文件或目录异常均不执行 Build、
  不写报告，避免未持锁的运行破坏 anchor 顺序。
- Export #2 后仍有 Symbol 错误，或 Build 汇总无法验证：停止循环，等待 AI。

报告把 fresh Build 决策证据与缓存诊断分栏；缓存只作附录。该报告是方便离线
工作的 advisory evidence，不会直接推进 Stage 2 ledger，也不会替代联网后的
ownership、warning 签名和最终验收；`DONE_OFFLINE` 也只表示无需继续 Export。

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
  -ProjectPath ..\Station010\Plc\Stat010_V5.11_CtrlX_PLC.project
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
- `../Station010` 已由用户批准作为 CpStudio + MCP 受控集成工作工程；任何 PLC 写入都必须先确认可恢复起点、导出文本快照，并且只经 MCP/正式 PLE REST 执行。
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
