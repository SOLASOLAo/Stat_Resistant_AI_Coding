# Burster 程序选择异步清理修复 · 2026-09-10

## 当前结论

已写入并保存离线 PLE 工程，本批新 F11 为 **0 errors / 5 warnings**；40 个预检目标回读与重复执行零修改检查通过。没有下载、启停 PLC、FORCE 或向仪表发送命令。原始 TCP Open 超时是否消除，仍需现场验证。

**Auto Range 早已由用户关闭并 Export，不是待办。** 本次再次通过现有 PLE REST 回读 `UseAutoRange := False`，没有要求重做配置，也没有改写该生成参数。本批只改 PLC 实现，无需 CpStudio Export。

## 故障证据与边界

- 昨天最后一轮只读现场记录：自动仍停在 N045，active ProgramNo=0；已改成正确的 `*RCL 0`、长度 17，但 ErrorCode=3（Open 超时），发送 offset=0。不能把此前残留的 `bytesWritten=1 / bytesRead=2` 当作这次已发送或收到的响应。
- 当时标准驱动和临时 socket 均显示 CLOSED；未证实标准驱动仍占用 TCP 5555。用户确认没有重启、断网或厂家软件连接。因此本次修复**不能被描述为已证明并排除最初的连接故障原因**。
- 已确认的软件缺陷：等待中的 Open 没有完整 Reset；Close 可能仅凭 `IsOpen=FALSE` 就被视为完成；读写可能仅凭字节数提前转换状态；清理会覆盖首次错误；一次性的 OnChainFinish 调用不足以完成多扫描周期的取消。
- 本机 NxBase 官方技术手册中的 `IOpconAsyncCall`、Read、Write、Close、Reset、ClearError 定义：异步调用须循环至返回值不再是 RUNNING；放弃未完成调用时用 Reset，Reset 自身也要等到完成。只读参考文件 `../Std/Objects/NxBase/V1.0/Documentation/Control_plus_Framework_TechnicalManual_EN.chm`，没有修改或提交标准库/手册内容。
- Burster 正常结束仍遵守先 EOT、后 Close。等待中方法失效时必须 Reset；若连接已经不可用，不能承诺 EOT 仍能送达，也不能据此宣称仪表端会立即恢复。

## 本次修改

1. `FB_Wp100BursterProgramSelect` 仅修改实现，声明不变：
   - Open、Write、Read、EOT、Close 均按方法返回值判断完成；Write 为 RUNNING 时保持发送指针/长度，不能提前推进 offset。
   - 超时或取消后完整调用 Reset；即使 IsOpen 已经 FALSE，也不能跳过 pending 方法清理。Reset 未完成就保持 Busy，不假报 Done。
   - 首次 ErrorCode/LastSocketError 在清理中保留；仅新的显式请求清空旧诊断与收发计数。
   - 正常选择必须依次收到 ACK、完成 EOT、完成 Close 才 Done；错误不自动重试、不放行分支。
2. `StationUnit.OnCall` 保留全部现有生成区、用户逻辑及声明，仅追加带标记的调用片段：选择器 `Execute=FALSE AND Busy=TRUE` 时继续取消清理。这样 OnChainFinish 只调用一次后，后续扫描仍能完成清理。这个调用不启动程序选择、测量或运动。
3. 既有 REST writer 加入该片段的语义追加、未知/重复标记拒绝、精确声明及整个方法回读；支持已审阅的旧选择器实现升级。没有新增工具链、服务或运行依赖。

未改 TypeData 程序号/数据结构、ASC/BMK、量程、标准 Unit、SFC 图或 Action、位置输入、力 >2500 N 连续 2 s、StationData 超时、测量中掉力保持及运动联锁。专用 HMI“程序选择失败”事件仍未实现，不能复用压紧力事件号冒充该错误。

## 写入与验证证据

- 唯一现有 PLE PID 19976，profile `ctrlX PLC 2.6.8`、compiler `3.5.19.70`，工程为受控 `Station010/Plc/Stat010_V5.11_CtrlX_PLC.project`；REST 写前、写后和编译后均确认为 offline。MCP 未接管该用户会话，没有另起第二个 IDE。
- 写前先保存用户当前工程，内容寻址 checkpoint SHA-256：`1fdd8c7b11863cf8d9d4e6323ed48eb7be0f700e902d929cb3392e92b9fe8b4f`；本地 `data/checkpoints/plc/<SHA>.project` 副本校验一致。
- Plan SHA-256：`4e75350ad1776d17335dd419d62be4cbf1e0bca60efc672c13a97cab2ec9f551`。实际仅两个 implementation PUT + 一次 Save；声明和非 implementation 字段不变，40 个目标预检/回读通过，Run 保持 27 步。
- 保存工程 SHA-256：`6a1c0637eda40ac64f477ec7bdbacd0f0c7b63eeb67aa576448acc575bd7a75d`；F11 后未变。最终 PlanOnly 为 0 操作，SHA `4a1481ef8aef3a87d872bfddec23c6546ed275973be765d66a270c7cabff34ff`；最后核对时间 2026-09-10 09:44 +08:00。
- AI 在同一 PLE 执行本次 F11，观察到 Build started 和 Build complete：**0 errors / 5 warnings / 158 messages**。五条实际读取为 4 × C0351（OPC.UA.DA unknown attribute）和 1 × C0373（SymbolConfig ErrorCodes/DWord）。打开工程时的 336 条旧 Symbol 警告不作为本批结果；没有删除 Symbol 配置来压低警告数，也没有更新正式 warning baseline。
- 七组离线回归通过：Burster 源码契约（含 0..15 报文字节、异步门禁、首次错误、取消调用）、REST PlanOnly（含未知 hook 拒绝、原逻辑保留、旧 FB 升级/回滚/幂等）、REST 事务、框架、operator guidance、force 时序模型、SFC 完成契约。
- Project Pack Build/Check 为 VALID，内容 ID `821ac91ce1727a6fc95d641df9f66ca0a0723e599d755ffd9c8ea6c500223270`。这些检查与 UI F11 是离线证据，不是仪表/标准库运行仿真，也不是现场 Symbol 或完整工艺验收。

## 下一次现场测试

由用户在现场确认安全后下载。不要重复设置 Auto Range，也不要用强制输出跳过 N045。

1. 按正常复位/重新发起自动流程，使用 TypeData 中用户设置的程序号 0。
2. 若仍停 N045，保留首次 `ErrorCode`、`LastSocketError`、`Busy`、`_state` 和 `_socketResult`；先定位 Open/响应阶段，不连续重启、裸连 TCP 或重复测量。
3. 收到 ACK 并完成连接释放后，确认标准驱动恢复测量、压缸/Kistler 分支启动、到位后力稳定、电阻结果及回升，再完成中/右位置。
4. 取消/故障时应完成清理或保留 Busy + 原始错误；未完成清理不能假报成功，不允许自动重试或自动升缸。

**现场程序选择 ACK、连接重用、取消恢复和左中右完整循环均未在本批验证。**
