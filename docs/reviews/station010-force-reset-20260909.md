# Station010 自动初始化卡住：旧力报警复位 · 2026-09-09

已修正、离线保存并完整回读；**本轮新 F11：0 errors / 5 warnings**。
没有下载、启停或写 PLC 变量；现场复测仍由用户操作。

## 现场证据与原因

- 修改前只读观察用户 PLE：`Wp100.SqS_Run.N000` 持续活动，
  `_retVal=RUNNING`；`CheckPressForce` 保留 `_fault=TRUE`、`_eventIndex=2`、
  `_reason='INVALID_TIMEOUT_MS'`、`_timeoutMs=2000`。
- 同时 active `Station.StationData.PressForceTimeout=10000`。这是在线值，
  不是 REST 工程源码；HMI 没有红色报警不代表链内旧事件句柄已清除。
- Phase 0 在 `UnlockEvent` 或 `ClearEvent` 返回 FALSE 时提前 RETURN，
  因而没有释放旧句柄/故障，也读不到新的 active 参数，N000 一直等待。
  没有单独捕获到底是哪一个调用返回 FALSE，不做进一步猜测。
- 最初 2000 ms 被 `<=2000` 参数检查拒绝，与“压下后检测实际力”不是同一个检查。
  本次保持原有 >2500 N、连续 2 s 与总等待时间规则，未修改 StationData。

## 最小修复

只改 AI-owned `SqS_Wp100_Run.CheckPressForce` 的 Phase 0 实现：存在自己的
非零句柄时依次调用 UnlockEvent、ClearEvent，随后释放句柄、清理本次执行状态、
读取 active 超时值并返回 OK。两者的 BOOL 不是 SFC 命令完成握手。

复位入口仍仅为显式取消/结束及新初始化；力恢复不会自动复位或重试。
保留所有位置输入、稳定时间、测量中掉力/无效数据保护、故障保持及标准取消逻辑。
没有修改 SFC 图、生成声明、I/O、标准库或仪表参数，没有增加 FB/周期钩子。
若事件仍待框架读取，解锁后仍可确认；不保证 HMI 消息当周期立即消失。

依据本机只读官方资料：`Std/Objects/NxBase/V1.0/Documentation/` 下
`Control_plus_Framework_TechnicalManual_EN.chm`（2025-02-24），
OpconBaseChain 的 ClearEvent 页面 `52bdebfb-f2fe-4fca-a897-8c7430f291aa`：
FALSE 也包含无效句柄或尚未被读取的事件。UnlockEvent 页面
`55bb5d41-44dc-406f-8831-dcf7dbf8a417` 的示例会在解锁后释放自己的句柄。
保留当前项目编译通过的两参数接口，不照抄较新版文档的第三参数。

## 实施与验证

- 用户确认已退出在线；REST 重新核对工程路径、profile、Application offline。
  复用原有 PLE，不启动第二个 MCP/IDE 实例。
- checkpoint SHA-256：`c5d5ec1c67b9a1bedf78a0228edc2c71fa28ca024062ffc207d2716c26306356`。
- Apply Plan：`b8899e088eb5ccab94001a95e848edf27c68b88ef522e0388fc42da9c3174b03`；
  恰好一个 implementation PUT、一次 Save；39 个目标按 writer 完整回读。
- 保存后工程 SHA-256：`3b43f7916b0939748aaf05abaeccfbfaf873f6b4a39752b02e65ab300bb100e2`。
  新 F11 后磁盘 SHA 不变，最终 PlanOnly **0 操作 / 39 个目标**。
- AI 在当前用户 PLE 按 F11，观察到本轮 Build started → Build complete：
  **0 errors / 5 warnings**，附加代码检查 0 errors。MCP 无会话所有权，
  因此这里是 UI 新编译证据，不冒充 Runner 结构化 Build evidence。
- 五条 warning 已通过当前 PLE 消息树逐条读取：4 × **C0351**
  `OPC.UA.DA` 属性不被编译器识别；1 × **C0373**
  `SymbolConfig: Enumeration ErrorCodes has unsupported base type DWord`。
  记录明细但不擅自扩大正式 warning 基线，也不因此承诺运行时 Symbol 验收。
- PowerShell 7 回归通过：ForceInterlock、ProjectFramework、RunOperatorGuidance、
  Wp100BursterProgramRange、SfcRestWriterPlanOnly、SfcRestWriterTransaction、
  SfcCompletionContracts；Project Pack Build/Check 为 VALID。
  新增四种 cleanup BOOL 组合、重复复位及 N000/OnChainFinish 调用合同检查；
  独立模型不是供应商库仿真，更不是现场测试。

本地可恢复 checkpoint：`data/checkpoints/plc/<修改前 SHA>.project`。
本地详细证据：`data/reports/plc/force-reset-20260909-{plan,apply,verification}.json`。
二进制与原始日志不入 Git；提交代码、规格、回归和本记录。

## 用户复测

本次只改 PLC 方法实现，**无需 CpStudio Export**。用户确保机器安全后下载，
核对实际加载的 PressForceTimeout 仍为 10000 ms，再发起新的一轮自动：
先确认 N000 → N010 正常进入治具提示；随后验证左中右正常流程。
故障测试仍须独立受控进行，不能用强制步骤/强制 I/O 绕过联锁。
当前结果仅到离线编译，尚未证明真机卡住已消除。
