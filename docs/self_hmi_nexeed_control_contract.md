# 自研 HMI 与 Nexeed PLC 控制契约

本文记录 Station010 / OpCon 5.11 当前已静态证实的公开交互契约。自研 HMI 与原 Nexeed HMI **择一运行**；PLC 继续使用 CpStudio 生成并由 PLE 集成的现有程序，不为自研 HMI 增加旁路控制。

## 1. OPC UA 地址规则

- Namespace URI：`http://www.boschrexroth.com/OpcUa/Datalayer`
- 符号根路径：`plc/app/Application/sym`
- NodeId 形式：`ns=<运行时索引>;s=plc/app/Application/sym/<符号路径>`
- 客户端必须按 Namespace URI 在会话建立后解析索引，禁止硬编码 `ns=2` 等索引。
- 下文使用 `P` 代表 `plc/app/Application/sym`。

Symbol Configuration 允许写入不等于业务上允许写入。只有下文明确列出的请求输入可进入写白名单；状态、Chain 内部量和物理 I/O 均只读。

## 2. Station ModeHandler

模式编号：Automatic=`1`、Manual=`3`、Home=`4`、Change-over=`5`。

控制输入位于 `P/Station/Extension/`：

| 字段 | 类型 | 用途 |
|---|---:|---|
| `ModeIdRequest` | Byte | 请求切换模式 |
| `Start` | Boolean | 启动当前模式的 Chain |
| `Stop` | Boolean | 停止当前模式的 Chain |
| `Step` | Boolean | 切换运行/步进状态 |
| `StepPulse` | Boolean | 步进模式下执行下一步 |
| `RunEmpty` | Boolean | 请求空运行 |
| `TokenRequest` | Byte | 请求当前操作面板的控制 Token |
| `TokenChangeResponse` | Byte | 回答其他面板的 Token 请求：`0` 未定义、`1` 允许、`2` 拒绝 |

主要状态同样位于 `P/Station/Extension/`，只读使用：

| 字段 | 类型 | 含义 |
|---|---:|---|
| `ModeId` | Byte | 当前模式 |
| `ModeRelease` | Boolean | PLC 对当前模式的最终释放 |
| `IsRunning` / `IsStopping` | Boolean | 运行/停止过程状态 |
| `IsStepping` / `IsRunningEmpty` | Boolean | 步进/空运行状态 |
| `StartVisible` / `StopVisible` | Boolean | 官方 HMI 按钮可见性 |
| `StepVisible` / `RunEmptyVisible` | Boolean | 官方 HMI 步进/空运行按钮可见性 |
| `ManualFunctionsActive` | Boolean | 当前允许使用手动功能 |
| `ManualFunctionRunning` | Boolean | 有手动功能正在运行 |
| `ModeRunning` | Boolean | ModeHandler 正在运行 |
| `Token` | Byte | 当前控制 Token；`255` 表示公共控制 |
| `TokenChangeCountdown` | Int32 | Token 变更倒计时 |
| `ExecState` | UInt16 | Station 执行状态 |

`Station.Extension.StartButton` 是现场物理启动按钮的应用输入，不是 HMI 的 `Start` 请求，禁止自研 HMI 写入。

## 3. 官方 Start / Stop / Step 行为

官方 Nexeed HMI 的行为已从现有 HMI 配置和程序集静态确认：

- 模式按钮只写 `ModeIdRequest=<模式编号>`，不会自动索取 Token。
- Start：若当前 `IsStepping=TRUE`，先请求 `Step=TRUE`；随后当 `( IsRunning=FALSE ) OR ( IsStepping=FALSE )` 时请求 `Start=TRUE`。
- Stop：请求 `Stop=TRUE`。
- Pause：运行中且尚未步进时，请求 `Step=TRUE`，进入步进状态。
- Next step：
  - 已运行且处于步进状态：请求 `StepPulse=TRUE`；
  - 尚未运行：必要时先请求 `Step=TRUE`，再请求 `Start=TRUE`；
  - 官方手动步进分支在 `StartVisible=FALSE`、`StepVisible=TRUE` 且 `ManualFunctionsActive=TRUE` 时，请求 `StepPulse=TRUE`。

### 请求位握手

`Start`、`Stop`、`Step`、`StepPulse`、`RunEmpty` 是 PLC 消费的请求位：

1. HMI 只写一次 `TRUE`，不主动写 `FALSE`，也不自行制造定时脉冲。
2. 写入后持续读取该位，等待 PLC 将其复位为 `FALSE`。
3. 回零前禁用同类重复请求；超时则提示通信/PLC 未响应，不连续重写。
4. 断线时不得猜测请求是否已执行；重连后先重新读取全部状态。

## 4. Token 规则

- Station010 当前面板编号：APQ=`1`，Laptop=`2`。
- 面板拥有控制权的条件为 `( Token = PanelNo ) OR ( Token = 255 )`。
- 请求控制权时写 `TokenRequest=PanelNo`；原 Nexeed HMI 使用独立的 Cluster/锁按钮处理 Token，模式按钮本身不请求 Token。
- 当前持有者收到其他面板请求后，通过 `TokenChangeResponse` 回答允许或拒绝。
- 自研 HMI 替代 APQ 运行时使用 PanelNo=`1`，发送任何控制请求前必须确认 Token 有效。
- 禁止自动抢占 Token；Token 不满足时界面保持只读并明确提示。

## 5. Unit 手动功能契约

选择 Unit 只是 HMI 本地导航，不存在需要写 PLC 的 `SelectedUnit` 字段。每个手动功能使用对应 Unit 的 `Extension` 接口：

| 字段形式 | 类型 | 方向 | 语义 |
|---|---:|---|---|
| `P/<Unit>/Extension/Exec<Name>` | Boolean | HMI → PLC | 按住执行手动功能 |
| `P/<Unit>/Extension/Release<Name>` | Boolean | PLC → HMI | PLC 对该功能的释放 |
| `P/<Unit>/Extension/Running<Name>` | Boolean | PLC → HMI | 功能正在执行 |
| `P/<Unit>/Extension/ExecTime<Name>` | TIME（传输为 UInt32） | PLC → HMI | 本次执行时间 |
| `P/<Unit>/Extension/ExecState` | UInt16 | PLC → HMI | Unit 执行状态 |

执行必须采用 hold-to-run：按下写 `Exec<Name>=TRUE`；松开、失焦、切页、窗口关闭或通信异常时立即写 `FALSE`；随后等待 `Running<Name>=FALSE`。启用按钮至少同时检查有效 Token、`ManualFunctionsActive`、Unit 可用、`Release<Name>` 以及 CpStudio/HMI 配置的附加条件。

当前已识别的手动函数如下：

| Unit | 函数 |
|---|---|
| `Wp100` | `Home`、`DeleteWpcData`（当前 HMI 条件为常量 FALSE，禁用） |
| `Wp100K101SafetyDoor` | `MoveBasPos`、`MoveWrkPos` |
| `Wp100K102PressingCylinder` | `MoveBasPos`、`MoveWrkPos` |
| `Wp100A103ResistantDetector` | `SetRange`、`StartMeas` |
| `Wp100A104Kistler` | `Measure`、`LockKeyboard`、`UnlockKeyboard`、`SetProgram`、`ZeroX`、`TareY`、`ReadData`、`WriteData` |

带参数的函数继续使用对象自身公开的参数节点，例如 Burster 的 `InHmi/...`，以及 Kistler 的 `ParCmd/SetProgram/ProgNo`、`ParCmd/Measure/MeasuringTimeout`、`ParImm/EndMeasurement`；具体写白名单需逐项确认后开放。

## 6. Remote-caller Heartbeat

Heartbeat 是 PLC 发起、HMI 应答的 challenge/ack，不是 HMI 自己周期翻转：

1. 执行某 Unit 手动功能期间，订阅 `P/<Unit>/Extension/Heartbeat`。
2. PLC 将 `Heartbeat` 置为 `TRUE` 后，HMI立即写回 `FALSE` 作为确认。
3. 手动功能结束时停止该订阅，并确保 `Exec<Name>=FALSE`。
4. 框架默认 remote-caller 超时为约 1 秒，调试配置可放宽至约 5 分钟；丢失调用方对应错误码为 `REMOTE_CALLER_LOST=512`。

`Root.EnableRcHeartbeatCheck` 的当前运行值尚未真机确认，因此客户端仍应完整实现该握手，不能依赖其被关闭。

## 7. 明确禁止的写入

- 禁止直接写 Automatic、Home、Change-over 或 Subchain/SFC 的内部变量、步骤、Action 和跳转条件。Chain 状态（如 `ChainExecState`、`SFCCurrentStep`）仅用于显示；控制统一经过 `Station.Extension` 请求。
- 禁止写 `Peripherals`、`BinIo`、EtherCAT 映射变量及任何物理 DI/DO。操作员动作只能使用 ModeHandler 请求和 Unit `Exec<Name>` 接口。
- 禁止写 `Station.Extension.StartButton`，禁止 FORCE，禁止把只读输出加入控制白名单。
- 安全、门锁、气压和产品检测信号只用于显示/释放判断；`ModeRelease` 和各 `Release<Name>` 始终以 PLC 结果为准。

## 8. 尚待真机验收

- 最终 CpStudio Export → PLE Build → CpStudio Export 后，浏览确认 Namespace URI、全部 NodeId、数据类型和访问权限。
- 使用专用 OPC UA 账户验证：只允许上述已批准输入写入，状态、Chain 和物理 I/O 拒绝写入。
- 验证 Token 的请求、允许/拒绝、切换 HMI 后的初值和控制门禁。
- 分别验证 `Start`、`Stop`、`Step`、`StepPulse`、`RunEmpty` 的 TRUE 请求、PLC 回零时间和超时处理。
- 在安全隔离条件下验证 Automatic、Home、Change-over 的启动、暂停、单步、继续和停止。
- 验证每个 Unit 的 hold-to-run、`Release`、`Running`、`ExecTime`、Heartbeat TRUE→FALSE 应答，以及断线/关闭窗口后的安全撤销。
- 在线确认 `Root.EnableRcHeartbeatCheck`，并验证 remote-caller 超时是否会可靠终止手动动作。
- 对照原 Nexeed HMI 验证附加显示/启用条件，但不得在自研 HMI 中绕过 PLC 的 `ModeRelease` 或 `Release<Name>`。

## 9. 只读审计来源

- `../Station010/Hmi/config.xml`
- `../Station010/Hmi/OpCon.HMI.Modulo.vwn`
- `../Station010/Plc/Stat010_V5.11_CtrlX_PLC.Device.Application.xml`
- `../Station010/PublicConfig/PublicInterface_Stat010_V5.11_CtrlX.xml`
- `../Std/Hmi_V5_11/OpCon.HMI.Modulo.Shared.dll`
- `../Std/Hmi_V5_11/OpCon.HMI.Modulo.Forms.dll`
- `../Std/Hmi_V5_11/OpCon.HMI.Modulo.exe`

本文中的按钮、请求位、Token、Unit 和 Heartbeat 行为为静态证实；第 8 节内容在完成真机验收前不得标记为运行时已验证。
