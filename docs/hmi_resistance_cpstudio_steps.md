# 三位置电阻显示：已生成画面与检查清单

2026-09-15：主界面名称现按**工件自身位置**显示。夹具左/中/右分别测工件右/中/左，三行顺序为右侧电阻、中间电阻、左侧电阻；标题和未完成提示共同调整。现有 PLC 成员、控件 ID 仍沿用夹具位置，数值/Valid/Ok 绑定不变。只改 UserDefined 四处文字引用，复用现有双语资源；原厂加载、离线分步预览和 CpStudio 保存重开通过。本次未部署 IPC，曲线及 CSV 名称未调整。

2026-09-11。**三组控件、变量绑定、状态门控和坐标已由 AI 写入 `UserDefined.sfc`，无需再逐项创建。** 原厂加载器 0 错误，CpStudio 已重新打开该设计页。原来的站号、型号、原位灯、图片和提示栏保留；两个试放的副本已替换为电阻显示区。

**2026-09-11 双语接入记录：电阻区中英文资源已原生接入，保存、HMI 单独 Export 和设计器重开通过。** 6 个名称/未完成文本绑定 Station TextGroup，菜单为“测量结果 / Measurement results”，OK/NOK 复用标准资源。数值、Valid/Ok 绑定、原控件及坐标不变；当时 UserDefined SHA `7ab00c…89bc`，详见 [双语接入记录](hmi_localization.md)。电阻父结构和 9 个成员 Symbol 均为 Read。完整 PLC Export 仍受原厂异步流缺陷影响，详见 [导出异常记录](reviews/cpstudio-symbol-stream-20260911.md)。设计器中的 `ABCDEFGHI…` 是原厂数值占位文字；实际数据切换仍待现场验收。

PLC 显示赋值已接入，曲线集成后的最终新 F11 为 **0 errors / 5 warnings**（4×C0351，1×C0373）。本轮已保存并完成 HMI 单独导出，未下载、部署 IPC 或推送 GitHub。

## 1. 现有结构与发布属性

打开 **Model → Station → Variables → Station → HMIResistance**。结构类型为 `HMIResistanceStruct`，9 个成员已经存在，**不要在 Wp100 再建一组**。

| 属性 | 目标值 |
|---|---|
| OpcUaAccess | `Read` |
| OpcUaVisible | `True` |
| UseInHmi | `True` |
| create sub elements | 勾选 |
| Retain / Persistent | 不启用 |

最初生成符号为 `ReadWrite`；本轮已在 CpStudio 模型确认 `Read`，再通过 PLE 原生编辑器/官方精确 Symbol REST 完成父结构和 9 成员的 Read 设置。最终 XML 仅这 10 个 access 属性改变。恢复完整导出后仍需验证保存往返不会恢复旧权限。

属性左侧是可添加项，右侧才是已配置项；不要因为左侧列表显示 `Persistent=True` 就认为已启用。

## 2. 已完成的三组绑定（供核对）

设计入口是 **Station → HMI configuration → UserDefined**。文件为 `Hmi/SmartForms/17ad895f-b172-4b13-8b11-8fde8b79013f/UserDefined.sfc`，外层 `OverView` 是宿主。

HMI 变量选择器的完整前缀统一为：

```text
Ch1.L1.Station.HMIResistance.
```

| 界面行 / 夹具位置 | 工件显示位置 | 数值（REAL，mΩ） | 有效（BOOL） | 判定（BOOL） |
|---|---|---|---|---|
| 第一行 / 左侧 | 右侧 | `_HmiResistanceLeft_mOhm` | `_HmiResistanceLeftValid` | `_HmiResistanceLeftOk` |
| 第二行 / 中间 | 中间 | `_HmiResistanceMiddle_mOhm` | `_HmiResistanceMiddleValid` | `_HmiResistanceMiddleOk` |
| 第三行 / 右侧 | 左侧 | `_HmiResistanceRight_mOhm` | `_HmiResistanceRightValid` | `_HmiResistanceRightOk` |

例如第一行（夹具左、工件右）的数值完整绑定为 `Ch1.L1.Station.HMIResistance._HmiResistanceLeft_mOhm`。VWN 中的名字省略了 `Ch1.`；九个绑定均已按现有变量池核对。

## 3. 已写入的控件和属性（无需重配）

每组已有一个 `Mod_VarOut`、一个判定 `Mod_Label` 和一个未完成 `Mod_Label`，名称为 `AI_ResistanceLeft/Middle/Right` 加 `Value/Status/Pending`。数值和判定只在对应 `Valid=True` 时显示；未完成提示在 `Valid=False` 时显示。

**数值 Mod_VarOut：**

| 属性 | 值 |
|---|---|
| VWItem.Name | 表中对应数值的完整路径 |
| UseItemText | `False` |
| NumericFormat | `{0:F4}`（仅显示格式） |
| RegionLayout | `LabelLeft` |
| Label.Text.Text（第一至第三行） | `ResistanceRight` / `ResistanceMiddle` / `ResistanceLeft` |
| Label.Text.TextGroup | `Station` |
| Unit.Text.Text | `mΩ` |
| PropertyBindings | `VWDigitalItemBinding`：`PropertyName=Visible`，`VWItem=对应 Valid 完整路径`，`Invert=False` |

PLC 已乘以 1000，HMI **不再缩放**。使用输出控件，不放可编辑的 `Mod_VarIn`。

**判定 Mod_Label：**

- 默认文本 `—`、灰色。
- `PropertyBindings` 中的 `VWDigitalItemBinding`：`PropertyName=Visible`，`VWItem=对应 Valid`，`Invert=False`。
- `TextBinding`：`PropertyName=Text`，`VWItem.Name=对应 Ok`，`Texts[0].Text=Nok`、`Texts[1].Text=Ok`，两项 `TextGroup=NexeedStateAddon`；显示为标准 NOK/OK。
- `ColorBinding`：`PropertyName=ForeColor`，`VWItem.Name=对应 Ok`，`Colors[0]=226,0,21`（红）、`Colors[1]=120,190,32`（绿）。

**未完成 Mod_Label：**

- `LocalizedText.Text` 从第一至第三行为 `ResistanceRightPending` / `ResistanceMiddlePending` / `ResistanceLeftPending`，`TextGroup=Station`、`ForeColor=Gray`；中英文由 CpStudio Text 资源提供。
- `PropertyBindings` 中的 `VWDigitalItemBinding`：`PropertyName=Visible`，`VWItem=对应 Valid`，`Invert=True`。

这些绑定类型来自本站现有 Kistler 视图的 `Visible` 绑定和 `StateTile.sfc` 的 `TextBinding/ColorBinding`，不是新增自定义控件。

## 4. 实际位置

当前 UserDefined 画布保留你刚保存的 `944×572`；设备图片占 `x=15..341, y=42..464`，自动提示栏为 `(15,502)`、`889×46`。画面共 14 个控件（原有 5 个，电阻显示 9 个）。

| 控件 | 夹具左 / 工件右 | 夹具中 / 工件中 | 夹具右 / 工件左 | Size |
|---|---|---|---|---|
| 数值 Mod_VarOut | `360,100` | `360,212` | `360,324` | `390,48` |
| 判定 Mod_Label | `768,100` | `768,212` | `768,324` | `136,48` |
| 未完成 Mod_Label | `360,100` | `360,212` | `360,324` | `544,48` |

未完成标签与数值区域重合是有意设计，两者由相反的 Valid 门控显示。原厂控件离线渲染和矩形范围核对已通过，未遮挡原有内容。

## 5. 保存、导出阻点

1. 已保存模型并执行三次完整 Export 尝试；失败点均为 PLC 符号 JSON 解析，不能标记通过。
2. 同一 PLE 内重开工程、新 Build，以及正常重启唯一 PLE 后均未解决。已停止重复 Export。
3. UserDefined 文件、显示钩子及应用流程已回读核对，最后新 Build 0 errors / 原 5 warnings。
4. 后续已通过官方精确 Symbol Select 完成 Read，代码专用 Fast export、HMI 单独 Export 与画面往返也已验证。完整 PLC Export 仍需原厂修复或受支持恢复方法；不要反复重试或手改生成接口。

原始画面备份、精确 SHA 和验证记录位于 `McpCoding/data/reports/hmi/resistance-view-20260911/`；`UserDefined.resources` 未改。本次新异常和导出后核对位于 `data/reports/hmi/cpstudio-integration-20260911-104241/`。

## 6. 验收目标（尚未现场验证）

- 新一轮开始时，三组均为“— 未完成”，不能把清零后的 0 显示为测量值。
- 夹具左位置完成只更新第一行“右侧电阻”；夹具中、右位置完成分别更新“中间电阻”“左侧电阻”。取消时保留已完成位置供查看，未完成位置不能显示 OK/NOK。
- `0.001 Ω` 应显示 `1.0000 mΩ`；OK/NOK 来自原 PLC 判定，不能按显示舍入值重新计算。
- 断线必须有明确的原生通讯质量失效提示。Valid 是测量有效位，**不能代替通讯质量**；上述 Visible 绑定本身不证明断线处理。IPC 断线后的缓存/状态显示仍需专项验收，若仍显示绿色 OK，应先核对受支持的质量绑定接口再交付。
- 后续现场测试、PLC 下载和 IPC 部署需要另行明确安排，本清单不包含执行授权。
