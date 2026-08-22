# CpStudio 与 Symbol Configuration 导出周期

## 当前结论

CpStudio 5.11 的普通 PLC Export 会先写入新增 PLC 对象，随后立即发布 OPC UA 方法、刷新 PersistentVars 实例路径，并读取/更新 PLE 的 Symbol Configuration；这条链路中没有 Build。

CODESYS 官方说明 Build 会编译项目，并且是 Symbol Configuration 编辑器准备当前变量列表的前提。因此目前最可信的解释是：第一次 Export 已写入声明，但 Symbol 后处理仍可能看到上一次 Build 的语言模型；PLE Build 刷新模型后，第二次 Export 才能选择新符号并完成相关后处理。

这属于 CpStudio 5.11 + PLE 2.6 当前实现的强推断，不应表述为所有 CODESYS 项目天然必须导出两次。实验还要排除“等待后台预编译即可刷新”的可能。

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

结论：普通 OPC UA 可见 BOOL 没有复现双导出故障，因此不能把第二次 Export 设为所有新增变量的强制步骤。用户此前观察仍与 CpStudio 对已编译签名、OPC UA Method 和 PersistentVars 实例路径的依赖一致；更容易在新增对象、可调用接口或持久化路径时出现。

## 正式工作流

默认流程：

`CpStudio Export #1 → 检查 Output/目标 Symbol → PLE Build 0 errors`

只有发生以下任一情况，才执行：

`PLE Build → CpStudio Export #2 → PLE final Build`

- CpStudio 报 OPC UA Method 发布、PersistentVars instance path 或 Symbol Configuration 错误；
- 新目标在第一次 Export 后未出现在 PLE 声明或可用 Symbol 列表；
- 目标已存在但未按 CpStudio 请求选中；
- 新增/改变了可调用对象签名或持久化实例路径，并且第一次后处理没有完成。

以后不必再造复杂 dummy；在下一次真实新增 Unit/Chain/接口时沿用同一取证即可继续缩小触发条件。
