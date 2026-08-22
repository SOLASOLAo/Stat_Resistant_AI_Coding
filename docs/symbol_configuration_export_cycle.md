# CpStudio 与 Symbol Configuration 导出周期

## 当前结论

CpStudio 5.11 的普通 PLC Export 会先写入新增 PLC 对象，随后立即发布 OPC UA 方法、刷新 PersistentVars 实例路径，并读取/更新 PLE 的 Symbol Configuration；这条链路中没有 Build。

CODESYS 官方说明 Build 会编译项目，并且是 Symbol Configuration 编辑器准备当前变量列表的前提。这里要区分两层状态：Build 刷新“当前可用的变量/类型/签名”，Symbol Configuration 另行保存“要发布哪些签名”。CpStudio Export 负责协调这两层，Build 本身不会自动删除已经配置但已失效的签名。

因此不能把“所有 CODESYS 项目都必须导出两次”当成规则，也不能把第二次 Export 当成清理失效签名的保证。CpStudio 5.11 + PLE 2.6 的长会话还可能保留旧 Symbol/编译上下文；若磁盘工程已经正确而同一会话仍报警，保存并重开 PLE 后再 Build 是正式修复前的最小诊断步骤。

官方依据：

- [CODESYS Symbol Configuration 创建要求](https://content.helpme-codesys.com/en/CODESYS%20Communication/_cds_symbolconfiguration.html)
- [CODESYS Symbol Configuration 对象：Build 是当前变量准备的前提](https://content.helpme-codesys.com/en/CODESYS%20Communication/_cds_obj_symbolconfiguration.html)
- [CODESYS Symbol Configuration Scripting API](https://content.helpme-codesys.com/en/ScriptingEngine/ScriptSymbolConfigObject.html)

## 单变量最小实验

探针统一使用 `DummySymbolProbe : BOOL`。由用户在 CpStudio 的 `Model → Station → Wp100` 已发布变量区域创建，OPC UA 可见，访问权限与同层现有公开变量保持一致；不设 Persistent、不绑定 HMI、不写业务逻辑。

每完成一步就停下通知 AI，不要连续做完：

1. CpStudio 只创建并保存 `DummySymbolProbe`，暂不 Export。
2. AI 只读确认模型变化。
3. 用户执行一次普通 PLC Export（不是 Fast export），保留 Output，暂不 Build。
4. AI 立即检查一次，等待 30–60 秒后再检查一次，以区分后台刷新和 Build 依赖。
5. AI在 PLE 执行一次普通离线 Build，并检查探针是否已成为可用 Symbol。
6. 用户回 CpStudio 执行第二次普通 PLC Export，保留 Output。
7. AI检查探针是否已选中、Export 是否干净，并做最终 Build。

验收只看四件事：CpStudio Output、PLE Build 结果、探针在 Symbol Configuration 中是否“可用/已选中”、关键文件指纹。实验不连接或下载 PLC。

实验结束后由用户只在 CpStudio 删除探针，再按同一闭环清理；AI不在 PLE 中单独删除它。

## 实验结果（2026-08-22）

在 `Wp100` 新增 `DummySymbolProbe : BOOL`，设置 OPC UA 可见后完成分阶段验证：

- 保存但未 Export：探针只存在于 CpStudio 模型，PLC 与 Symbol 均未变化。
- Export #1、尚未 Build：PLE 声明已有探针，Symbol Configuration 已显示 `BOOL / ReadWrite / selected=true`，CpStudio Output 无红字。
- PLE Build：`0 errors / 6 warnings`，探针状态不变。
- Export #2：语义状态仍完全相同；加密 `.project` 因再次保存而容器哈希变化，但大小和外部快照未变。最终 Build 仍为 `0 errors / 6 warnings`。

删除探针时又完成了反向验证：

- CpStudio 删除后 Export #1 无红字；PLC 声明和 REST“当前可用 Symbol”中均已没有探针，但同一 PLE 会话 Build 为 `0 errors / 8 warnings`，新增两条“变量已不存在但仍配置在 Symbol Configuration”警告。
- Build 后执行 Export #2 仍无红字；时间线确认完整 HMI/PLC Export 确实执行，但同一会话再次 Build 仍为 `0 errors / 8 warnings`。
- 保存、关闭并重新打开 PLE 后，对 Export #2 生成的同一份 `.project`（SHA-256=`761ECD38F811C545CBA5791B8E31CA872D44C9688C1A0442BB45EB5B8332CC55`）重新 Build，结果恢复为 `0 errors / 6 warnings`，两条探针警告消失。

结论：普通 OPC UA 可见 BOOL 的新增第一遍就成功，不能把第二次 Export 设为所有新增变量的强制步骤；删除样本则证明同一 PLE 会话可能继续持有旧配置/编译上下文，第二次 Export 本身也不保证即时清掉警告。最终事实必须以“必要时重开后的新 Build”为准。

本实验还验证了一个 REST 边界：失效签名不会出现在 Symbol Configuration GET 的当前可用清单中，不能根据推测的最小请求对它执行精确 `UnSelect`。一次隔离尝试把警告扩大到 101 条后，已用操作前的内容寻址检查点完整回滚；正式工程最终没有留下该尝试的变化。此类条目优先重开验证，仍存在时使用编辑器黄色提示条的 `Remove...`；只有完整快照并能恢复全部有效选择时，才考虑 `UnSelectAll → Select` 重建。

## 正式工作流

普通描述/HMI 文本等不改变发布 Symbol 拓扑的修改：

`CpStudio Export #1 → 检查 Output/目标 Symbol → PLE Build 0 errors`

发生以下任一情况时，再执行：

`PLE Build → CpStudio Export #2 → PLE final Build`

- CpStudio 报 OPC UA Method 发布、PersistentVars instance path 或 Symbol Configuration 错误；
- 新目标在第一次 Export 后未出现在 PLE 声明或可用 Symbol 列表；
- 目标已存在但未按 CpStudio 请求选中；
- 新增/改变了可调用对象签名或持久化实例路径，并且第一次后处理没有完成。

若 Export #2 后只剩 `not available ... still configured`，不要继续盲目重复 Export，也不要对 REST GET 不可见的旧签名构造精确 `UnSelect`。固定顺序为：

`保存并关闭 PLE → 重新打开同一工程 → Build`

重开后仍存在才进入 Symbol Configuration 的 `Remove...`，随后普通 Export 和最终 Build。这样既不把偶发会话缓存升级成复杂修复，也不会误伤仍有效的 Symbol 选择。

以后不必再造复杂 dummy；在下一次真实新增 Unit/Chain/接口时沿用同一取证即可继续缩小触发条件。
