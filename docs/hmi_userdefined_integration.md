# UserDefined HMI 集成记录

> 项目：Station010
> 工具：CpStudio / OpCon V5.11 HMI Configurator
> 当前批次：2026-08-23，Station010 commit `84d1577`

## 1. 结构与所有权

`OverView` 是主界面中的宿主画面，只保留一个 `Mod_SmartControlHost1`；实际内容位于
`UserDefined`。CpStudio 继续负责 View 注册、语言文本和完整 Export，AI 可以在可恢复检查点、
精确 diff 和官方加载验证下维护 WFML (`*.sfc`) 与图片资源。

```text
OverView
└─ Mod_SmartControlHost1 → UserDefined
   ├─ Home LED
   ├─ StationNo
   ├─ TypeNo
   ├─ Machine Picture
   └─ Auto information line
```

当前没有已验证的 CpStudio HMI 写入 API 或 headless CLI。可用的官方可视化验证入口是
CpStudio 5.11 内嵌 HMI Configurator；独立 VisiWinNET Smart 与当前 OpCon 程序集不兼容。
因此不能把这套能力描述为“AI 通过官方 API 自动画面”，准确表述是“AI 受控维护画面文件，
CpStudio 官方编辑器负责加载、预览和保存验证”。

## 2. 当前画面配置

父画布为 `944 × 624`。以下坐标是工程事实，后续在 CpStudio 中调整后应同步更新本表；展示
HTML 不必呈现这些易变坐标。

| 画面 | 控件 ID | Location | Size | 绑定 / 资源 |
|---|---|---:|---:|---|
| OverView | `Mod_SmartControlHost1` | `3, 0` | `944, 624` | `SmartControlName=UserDefined` |
| UserDefined | `Mod_EnumDisplay1` | `4, 561` | `889, 32` | `Ch1.L1.Station._AutoInfoline` |
| UserDefined | `Mod_VarOut2` | `564, 4` | `291, 32` | `Ch1.L1.Station.State.Data.Cur[1].DataSetName` |
| UserDefined | `Mod_VarOut3` | `243, 4` | `291, 32` | `Ch1.L1.Station.StationData.StationNo` |
| UserDefined | `Mod_Led1` | `15, 10` | `220, 24` | `Ch1.L1.Station.Unit.IsInHomePosition` |
| UserDefined | `Mod_PictureBox1` | `38, 42` | `448, 491` | `Mod_PictureBox1.Images.0` |

图片资源位于 `UserDefined.resources`，读回为 `551 × 761 / Format32bppArgb`。原
`OverView.resources` 与新资源的 Git blob 完全一致，因此这是资源归属迁移，不是图片重编码。

## 3. CpStudio 注册文件

一个可在干净工作区中识别的 UserDefined View 涉及以下文件，提交时必须逐个审阅，不能使用
`git add .` 或 `git add -A`：

| 文件 | 用途 |
|---|---|
| `Hmi/OpCon.HMI.Modulo.Gui.config` | SmartForm 名称与 SFC 路径注册 |
| `Hmi/OpCon.HMI.Modulo.csproj` | SFC 与 `.resources` 项目关联 |
| `Hmi/config.xml` | Station View 注册 |
| `Hmi/OpCon.HMI.Modulo.1033.lng` / `2052.lng` | View 文本 ID |
| `Hmi/OpCon.HMI.Modulo.vwn` | Designer 文本索引与项目元数据 |
| `OverView.sfc` / `UserDefined.sfc` | 宿主和内容画面 |
| `UserDefined.resources` | PictureBox 图片资源 |

Git 提交版 `.vwn` 的 HMI 管理密码和项目密钥字段必须为空；现场值只通过公司批准的本地渠道
配置，不能进入 Git。本机工作文件可以保留现场配置，但它会持续显示为未提交修改，严禁整体
暂存。`Hmi/PlcHandlerL1.ini` 同样包含本机连接字段，本批明确排除。

仓库较早历史曾包含非空字段，当前提交只能保证新的 HEAD 已脱敏；项目负责人仍应轮换相关
凭据，并单独决定是否需要历史清理。历史重写属于破坏性仓库操作，不在本批执行。

## 4. 已完成验证

- CpStudio 官方 HMI Configurator 直接打开 `Station/UserDefined`，5 个控件和图片均可见；标签页
  无未保存标记。
- 宿主 `Station/OverView` 通过唯一 SmartControlHost 显示相同内容。
- 两份 SFC XML 可解析，控件 ID 唯一，4 条 VWItem 绑定保持不变，临时 Probe 已移除。
- `UserDefined.resources → UserDefined.sfc` 关联正确，旧 `OverView.resources` 引用已删除。
- 当前 CpStudio 为 0 errors；3 条既有 Burster/PLC 类型兼容 warning 与本次画面无关。

本批没有执行完整 CpStudio Export。当前存在 PLE 会话，强行 Export 可能再次争用 Symbol
Configuration；应在释放 PLE/Symbol 占用后再做 Export 往返审计。没有调用 PLC MCP，也没有
连接、下载、启停、写变量或 FORCE 实体 PLC。

## 5. 后续展示 HTML 的事实源

更新 `docs/ai_coding_showcase.html` 时，只增加一个克制的“HMI 工作边界与验证案例”区：

1. CpStudio 管模型、View 注册和完整 Export；AI 维护受控 WFML/resources。
2. `OverView` 是宿主，`UserDefined` 是内容画布；展示 5 个控件迁移即可，不展示坐标细节。
3. 官方 Configurator 加载与保存验证已通过；完整 Export 尚待释放 PLE 后验证。
4. 不宣称存在官方 HMI 写 API；不展示现场密码、项目密钥、内部连接信息或 Git 历史内容。
5. 同时修正旧 HTML 中“Post-export 消费器待完成”的过时说法：Stage 2 runner 和本地离线
   checker 已经落地。
