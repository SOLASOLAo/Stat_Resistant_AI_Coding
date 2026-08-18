# CpStudio 生成差异分析

> 目标：通过“单一 CpStudio 改动 → Git diff → PLC 文本快照 → 编译”逐步建立模型到生成代码的映射。本文件记录事实和推断；未得到用户确认前，不提交或回滚参考工程的生成变化。

## 样本 1：`b9b1161` → 2026-08-18 未提交工作区

### 观察到的生成边界

- 基线提交：`b9b1161`（当前 IDE/CpStudio 状态快照）。
- 当前工作区：26 个文件变化，约 136,895 行增加、186,666 行删除。
- PLE 由外部进程以 `--project=...Stat010_V5.11_CtrlX_PLC.project` 启动，并持有 `.~u` 锁；分析期间未通过 MCP 打开、保存或编译该工程。

### 模型层变化

`Wp100` 层级仍存在，但其五个子 Unit 从 PublicInterface 中移除：

| Unit | 类型/作用 | 可见的连带变化 |
|---|---|---|
| `Wp100K202SafetyDoor` | BasMove / 安全门 | HMI SmartForms 删除，HomePosition 条件移除 |
| `Wp100K201PressCyl` | BasMove / 下压缸 | HMI SmartForms 删除，手动功能与条件移除 |
| `Wp100A830Scanner` | Scanner / 手持扫码枪 | Scanner 对象版本、类型、事件和 HMI 删除 |
| `Wp100A740ForceStroke` | Kistler Maxymos | Kistler 对象版本、类型、事件和 HMI 删除 |
| `Wp100A850BursterResistomat` | Burster 2316 | Burster 对象版本、类型、事件和 HMI 删除 |

`ObjectVersions.xml` 和 HMI `config.xml` 同步移除了以下对象族：

- BasMove Base / BasMove Standard；
- Kistler Maxymos Force Stroke / Base；
- Scanner / Scanner Base；
- Burster Resistomat 2316 / Base。

这说明 CpStudio 在生成时会根据当前实际实例集合裁剪对象版本、类型定义、事件文本、HMI Unit 配置和 SmartForms，而不是始终保留所有曾经使用过的对象依赖。

### PLC 与同步元数据

- PLC `.project`：1,738,192 B → 1,597,120 B；Git 只能确认二进制发生变化，无法判断具体 POU/ST 差异。
- `Stat010_V5.11_CtrlX_PLC.Sync.json` 的 `LastChange` 更新，`MachineName` 保持 `SZHM-C-002YK`。
- PublicInterface 的导出时间更新为 `2026-08-18T03:15:51`。
- 需要在用户关闭当前 PLE 后，用 `scripts/export_plc_snapshot.py` 导出文本快照，才能补齐 PLC POU 层的精确变化。

### 当前判断与待确认项

从生成物看，本次操作不像只删除 `_100A740`，而是删除了 `Wp100` 下全部五个 Unit。需要用户确认这是否是有意的 CpStudio 骨架裁剪。

确认前：

- 不提交、不回滚 `../Station010_0708` 工作区；
- 不启动第二个 PLE/MCP 实例；
- 不对 `.project` 做任何写操作；
- 仅保留 Git diff 分析结论。

