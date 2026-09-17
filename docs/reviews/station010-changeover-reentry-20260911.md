# Changeover 第二次不弹 TypeData 对话框

2026-09-11，CHANGEOVER-REENTRY-20260911。已完成最小离线修复和编译，尚未下载、现场复测。

## 现场证据

用户第一次 Changeover 能选文件，第二次卡住。现有 CpStudio-owned PLE 已在线时，先只读保留 N010 代码及 Watch4：

| 项目 | 读值 |
|---|---|
| 当前步骤 | `SqS_Station_ChangeOverFile._aN010_active` |
| `_retVal` | `RUNNING`（1） |
| `Station.ChgOvGuidance.ParImm.CurrentStep` | `INIT`（0） |
| `Station.Extension.StationViewRequest` | `'ChgOvGuidanceView'` |
| `Station.Extension.StationDialogRequest` | `''` |

旧 N010 只在视图请求为空时进入，然后将它置为 `ChgOvGuidanceView`。旧 N999 仅报告 DONE，`_reset` 为空；已存在的取消/错误回调虽然调用 `_reset`，也没有释放请求。因此残留的本链请求让第二次停在 N010，尚未进入实际打开文件选择框的 N030。这条证据直接解释当前卡住状态。

本机原厂 HMI `OpconUnit._vwItemRequestView_Change/RequestViewChange` 的只读 IL 核对显示其读取请求并处理页面导航，没有向 PLC 写回空字符串。不要依赖 HMI 自动确认/清除该请求。

## 修复范围

仅修改 `Application/Station/_this/Chains/Sub/SqS_Station_ChangeOverFile` 的 3 个已有实现：

- `_aN010_active`：接受空请求或本链已有的 `ChgOvGuidanceView`；其他页面请求仍等待其所属流程处理。
- `_reset`：仅清除本链使用的 `DataFileDialog` 和 `ChgOvGuidanceView` 请求名。
- `_aN999_active`：先调用 `_reset`，再报告 DONE。既有 OnChainCancel/OnChainError 继续复用该清理。

N030 的文件路径/扩展名/当前文件初始化、N040 的文件结果处理保持；SFC 图、全部声明及其他 20 个子对象逐一回读一致。没有改变 TypeData 加载应用、回原位、测量或运动命令。

源码位于 `src/plc/project/Station010/SqS_Station_ChangeOverFile/`；归属登记在 `ai/ownership.yaml`、`ai/hooks.yaml`，契约为 `specs/hmi/changeover_requests.yaml`。CpStudio 再生成后应先核对这 3 个实现，不要整链覆盖。

## 执行与验证

1. 通过 PLE 正常 Logout，并由 REST 确认 `Application.isOnline=false`；未停止 PLC runtime。
2. 当前 `.project` 备份 SHA-256 `512D49A6A90957ADB982CF918059047DA4814F2DCAD3FDE9D491010E68F5F9DD`，复制后校验一致。
3. `apply_changeover_requests_rest.ps1` 的 PlanOnly 冻结 24 个对象，只计划 3 个实现 PUT；检查点及匹配计划哈希门禁通过后 Apply、Save、回读成功。
4. 新 F11：**0 errors / 原 5 warnings**（4×C0351：OPC.UA.DA 属性；1×C0373：Symbol ErrorCodes 的 DWORD 枚举基础类型）。最终 PlanOnly **0 操作**。
5. `Test-ChangeoverRequests.ps1` 的 10 项离线 ST 条件/生命周期契约检查通过：空/本链/其他视图、连续两次完成、取消/错误重试以及其他视图/对话框保护。这是契约检查，未执行实体 PLC 换型。
6. 共享 SFC REST 事务检查、工程框架检查通过，Project Pack Build/Check 为 VALID；仅 sources/contentId 更新，计划流程和 I/O 保持。旧 Project Pack 测试的 23/27 步基线差异仍是既有待办，未以本次通过概括所有仓库测试。

保存后 `.project` SHA-256 `2E876C9CED6ABEA660E5473918A4F8164DCFF205B11895B9830DC0DD99B1A6DA`；Symbol SHA-256 `9FFCAB1160993733A711D6C18BC978E4B7541C33F19E3D5263CF751ADFDBC9D6` 保持。

证据目录：`data/reports/hmi/hmi-zh-en-changeover-20260911/`，含 `changeover-live-before.jpg`、前置源码 JSON、检查点、plan/apply/final-plan、`changeover-offline-build.jpg` 与最终哈希记录。没有字节编辑 `.project`，没有创建第二个 PLE/MCP owner。

## 待现场验收

另行授权下载后，在正常操作流程中连续完成两次 TypeData 选择；取消一次文件选择再重试；取消或错误退出换型链后重试。核对旧 TypeData 应用和回原位选择仍按原流程工作。

当前现场仍运行旧版本。不要通过强写空请求掩盖问题；本批未下载、在线修改、写值、FORCE、停止 runtime、触发测量或运动、部署 IPC、提交或推送 GitHub。PLE 保留打开且已 Logout。
