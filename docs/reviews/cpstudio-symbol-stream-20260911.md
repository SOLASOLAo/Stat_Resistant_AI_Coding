# CpStudio 导出：PLC 符号接口响应中断

2026-09-11。本轮完整 Export **未通过**。HMI 文件生成和 PLC 编译成功不能替代 Symbol 更新成功。

## 已确认的错误

CpStudio 5.11 在 `CtrlXPlcEditor.UpdateSymbolConfig` 解析 JSON 时弹出
`Newtonsoft.Json.JsonReaderException: Invalid character after parsing property name. Expected ':' but got: s.`
三次完整导出的出错位置分别在 `types[34].variables[4].comment`、
`types[221].variables[10].name` 和 `types[484].variables[13].accessRights`，并不固定在一个变量或中文文本。

通过只读检查已安装 CpStudio 接口程序集的调用信息，确认其符号请求包含以下参数：

```text
GET http://localhost:9002/plc/engineering/api/v2/devices/Device/Plc%20Logic/Application/symbol-config
?showProjSymbols=true&showLibSymbols=false&showExpAttrSymbols=false&includeMaxAccessNone=false&includeAllTypes=true
```

在 CpStudio 导出结束后，独立发送同样的只读请求也失败：HTTP 200、196918 字符、JSON 无法解析。
正常 JSON 中间被插入以下错误对象；200 状态不能当作成功：

```text
severity: Critical
type: NotFound
status: 404
mainDiagnosisCode: 080E0200
detailedDiagnosisCode: 0C7A0205
dynamicDescription: The stream is currently in use by a previous operation on the stream.
```

因此，已确认问题存在于本机 PLE 符号 REST 响应路径，不需要假定是某条 HMI 文本或 PLC 语法导致。
后续独立复现已确认本机组件中的异步流生命周期问题，见下节；适用的原厂修复版本尚未确认。
没有修改安装目录 DLL、网络/代理、标准库或 `.project` 字节。

## 独立复现与替代路径核查

只读检查本机 `Studio.RestApi.Webserver.Impl.dll`（程序集版本 `3.3.2.1183`）发现，
`Rexroth.Studio.RestApi.Webserver.RoutingComponent.WriteResponseSuccess` 调用
`WriteAsync` 后，在等待返回任务结束前释放 `StreamWriter`。在独立 PowerShell 进程中，用自行编写的
延迟内存流和合成字典调用该方法，复现了完全相同的流占用异常。此实验没有网络请求、工程写入或安装文件修改。
证据：`data/reports/hmi/cpstudio-integration-20260911-104241/isolated-response-repro.json`。

CpStudio 原生 **Fast export (code only)** 已执行完毕，随后新 F11 为 **0 errors / 原 5 warnings**。
这证明代码导出可继续使用，不代表完整 Export 恢复。随后在 PLE 原生 Symbol 编辑器将
`Station.HMIResistance` 父节点设为 Read，并通过官方 Symbol REST 的 `Select` 精确设置该类型的
9 个成员为 Read。没有使用 `UnSelectAll` 或 `UpdateAll`，没有修改 PLC 接口或其他 Symbol。

该一次 PUT 触发了 PLE 内部编译，客户端 25 秒超时；没有重复 PUT。等待 PLE 恢复响应后以原生
Ctrl+S 保存，再执行新 F11，最终 **0 errors / 原 5 warnings**。生成 XML 中父节点和 9 个成员
全部为 Read；把这 10 个 access 属性恢复为操作前值后，整个 Symbol XML 与操作前完全一致。
所以本次权限更新已完成，但后续完整 CpStudio Export 往返仍需复核。
`symbol-members-read-request.json`、工程检查点与最终审计留在同一证据目录。
只读 GET 仍可能返回损坏 JSON，不能根据 HTTP 200 或未捕获的转换异常后的脚本输出认定成功。

曲线原生扩展入口也已查明：HMI 目标设置 → HMI add-ons，接受包含 `AddonDesc.xml` 和自有 DLL 的
`.had` ZIP 包。这个入口固定向 `Std/Hmi_V5_11/Addons` 安装，并更新 Std 内的启动配置。
该有限 Std 例外已获用户明确批准，0.1.0.1 原生注册已完成；变更范围、旧版引用清理及验证见 `docs/hmi_force_trace_addon.md`。

## 14:14 曲线接口及 HMI 单独 Export

CpStudio 创建 HMIForceFrame 后经 Fast export 生成声明；PLC 发布器和记录钩子已离线接入。
精确 Select 一次 PUT 客户端 55 秒超时，未重复。等待恢复后原生 Save、新 F11 为
0 errors / 原 5 warnings；XML 仅新增 Station.HMIForceFrame Read 节点及 ARRAY[0..13] OF DWORD 类型，
原电阻 10 个 Read 权限和其余内容全部保持。

APQ/HMI 右键 **Export** 可单独导出 HMI，本次已完成，0 errors / 两条既有 Burster 平台 warning。
VWN 确认新数组为 Ch1.L1.Station.HMIForceFrame、VT_UI4/Cnt=14，原 9 电阻 Item 保留；
PLC .project 与 Symbol XML 哈希保持。此路径完成 HMI 变量生成，不代表完整 PLC Export 缺陷已修复。
证据：`data/reports/hmi/force-trace-registration-20260911/symbol-after.audit.json`、`hmi-export.audit.json`。
## 恢复尝试及其限度

1. 无并发 Symbol 访问；原进程内关闭并重新打开同一工程，重新 Build，完整 Export 仍失败。
2. 一个较小的过滤请求曾返回完整可解析数据（2013569 字符、14 symbols / 358 types）；其参数与 CpStudio 不同，不能据此宣布 Export 恢复。
3. 正常退出旧 PLE 进程，再由 CpStudio 的 `Open ctrlX PLC Engineering` 打开同一工程；只保持一个实例。重载库和新 Build 后，完整 Export 仍失败。
4. 停止重复 Export。后续应先确认原厂修复或受支持的符号导出恢复方法，再验证完整 JSON、CpStudio Export 与目标 Symbol 权限。不以手改生成接口或跳过 Symbol 阶段宣称完成。

## 已保留和验证的工作

- UserDefined 14 控件、9 个电阻显示变量和绑定保持；三次导出尝试后 SFC SHA-256 仍为
  `8e60d9e82af1b9c09efb2be25430d9ad28df76ea6654b2e317181a057f1c2e5f`。
- CpStudio 模型内 `Station.HMIResistance` 的 `OpcUaAccess=Read`、Visible/UseInHmi 已确认；
  后续通过原生 Symbol 配置/精确 REST 已完成父结构及 9 个成员的 Read 更新，详见上节。
- 电阻显示、SqS Run、SqC Run、Station Home 的 PlanOnly 均为 0 操作。
- Burster 15 对象只读回读与 canonical 源码内容一致。整体 writer 因 SelectProgram 的原有末尾空行差异拒绝 Plan；
  独立核对确认仅该方法多一个末尾换行，没有回写或以旧版本覆盖修复。
- 最后一次完整导出尝试后的新 F11：**0 errors / 5 warnings**；4×C0351 OPC.UA.DA，1×C0373 ErrorCodes/DWord line2378。
- 全程没有实体 PLC 登录、下载、运行写入、设备动作、FORCE、IPC 部署或 GitHub 推送。

## 原生批量创建文本已验证

先在 CpStudio 创建一个 Text，再用 `Send data to file...` 导出 `.cpsds`，据该原厂格式准备新对象 GUID、
中英文值及引用，并以 .NET DataSet 验证，最后用 CpStudio `Insert data from file...` 导入。
这条途径已成功批量创建剩余 17 个 ForceTrace 文本。全部 18 个文本位于 `Station` 文本组，名为 `ForceTrace*`。

保存后的模型和两份生成 `.lng` 中，18 条中英文逐条匹配。现有模型内容行无变化；
只有导出元数据 `PlcExportId` 更新。它证明原生文本批量导入可用，不等于自定义曲线视图/程序集已经注册。

力曲线候选位于 `src/hmi/Bpp.ForceTrace/`。记录/CSV 28 项检查已通过；最新原厂控件离线验证目录
`data/reports/hmi/force-trace-native-20260911-113008-271/`：SFCLoader 0 错误，121 合成样本的坐标及 CSV
逐项一致，缺口为空点。后续已完成 PLC 接口/发布、画面/程序集注册及 HMI 单独 Export；真实订阅、运行时语言切换及 IPC 验收仍待完成。最新证据见上述 14:14 节。

本次本地证据目录：`data/reports/hmi/cpstudio-integration-20260911-104241/`，包括检查点、原始 REST 响应、
导入候选/逐项验证、各 Plan 和 Burster 只读源码核对。原始模型检查点可能含工程连接配置，仅保留本地。
