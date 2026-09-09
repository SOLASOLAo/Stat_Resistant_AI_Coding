# N045 Burster 程序选择 NAK 修复 · 2026-09-09

## 证据与原因

- 修改前通过用户现有 PLE 只读观察：自动链停在 N045；安全门工作位、压缸原位及相关 READY/继电器条件满足，尚未进入压缸下降分支。
- active TypeData `Burster.ProgramNo=0`；选择器 `Done=FALSE`、`Error=TRUE`、`ErrorCode=6`、`_state=200`。
- 实际报文为 `$040000sr$02*RCL P0$0A$03$0D`，长度 18；接收两个字节 `21,13`，即 NAK + CR。错误清理后连接已关闭。不是以“网络可能不通”代替这一实测拒绝证据。
- [Burster 2316 官方手册](https://www.burster.it/fileadmin/user_upload/redaktion/Documents/Products/Manuals/Section_2/BA_2316_EN.pdf) 第 113 页 / §8.15.11 中 `*RCL P1` 的 P1 是数值参数占位符，取值 0..15，不是字面量 P 前缀。本机同版资料为 `../Technical Docs/BA_2316_EN.pdf`。
- 因此程序 0 应发送 `*RCL 0`；完整 Ethernet 帧为 `$040000sr$02*RCL 0$0A$03$0D`，长度 17。程序 0 合法，不能改 TypeData 程序号来掩盖协议错误。

## 最小修改

1. `FB_Wp100BursterProgramSelect`：删除命令参数前的字面量 P，并注明手册占位符含义。没有改变其声明、程序范围、超时、ACK/NAK、EOT/关闭、标准驱动连接交接。
2. `SqS_Wp100_Run._aN045_active`：程序选择失败时清空黄色“正在测量”提示；两个分支继续 HAS_ERROR，绝不假设成功或直接放行压缸。

没有新增 FB、服务或运行依赖。位置 In 输入、安全继电器、Kistler 启停、压缸到位后 >2500 N 连续 2 s、测量中掉力保持及 StationData 超时逻辑不变。SFC 图、CpStudio 声明、模型、HMI 配置和标准库不变。

专用 HMI 红字报警本次**未实现**：当前 CpStudio Wp100 事件中没有“Burster 程序选择失败”，不能复用压力/缺料事件，也不能在 PLE 伪造生成常量。若要实现，由用户在 CpStudio 添加事件并 Export 后再接入；现有选择器 ErrorCode 保留，错误时只消除误导提示。

## 写入与验证

- 使用现有唯一用户 PLE、精确工程路径/profile `ctrlX PLC 2.6.8`；REST 确认 Application offline。没有另起 MCP/PLE。
- 写前内容寻址 checkpoint：`data/checkpoints/plc/3b43f7916b0939748aaf05abaeccfbfaf873f6b4a39752b02e65ab300bb100e2.project`，复制后 SHA-256 校验一致；原工程保留。
- 现有 REST writer 仅增加已审阅 FB implementation 基线的受控升级能力；未知实现/声明继续拒绝，保留完整事务和回滚。实际 Plan SHA：`e50030638365830b39ed4c35a0c45a195487a57b57896ef031af59bdbaf02f72`。
- 实际只执行两个 implementation PUT + 一次 Save；请求前后除 implementation 之外的字段完全相同。所有目标保存前后完整回读通过，27 步 Run 图保持不变。
- 七组回归通过：Burster（实际 ST 字符串的 0..15 全范围报文字节、NAK 阻止放行）、REST PlanOnly（含既有 FB 升级、未知更改拒绝、保存后损坏回滚、重复执行零修改）、REST 事务、框架、operator guidance、force 时序模型、SFC 完成契约。
- Project Pack Build/Check 通过；内容 ID 仍为 `4f0eaab92c8f3f7657180c669d4a84d3c1804f6ffb567f5dcf7a2c514cff2ace`。这些测试不是标准库仿真或仪表现场验收。
- 本次新 F11 于 16:24:58 发起，观察到 Build started 后完成：**0 errors / 5 warnings**；附加代码检查 0 errors。逐条读取为 4 × C0351 `OPC.UA.DA`、1 × C0373 `SymbolConfig ErrorCodes/DWord`，与修改前签名一致；不扩大正式 warning 基线，不冒充 Runner 结构化或现场证据。
- 编译后再次 PlanOnly 为 **0 操作**，SHA `c7746be7de9c0d3bd59833e77c1c2f0744177d0b74360c587aab8791ec14f648`；保存工程 SHA `36081bfcc0c2e259c1a610aa9dffbb1c7a741f6c878a3c5cdccba215111d83c3`，仍为 offline。

本地详细记录：`data/reports/plc/burster-rcl-numeric-20260909-{before,plan,apply,verification}.json`。

## 用户下一步

本次只改 PLC 实现，无需再次 CpStudio Export。确认本次编译通过和现场安全后，由用户下载，按正常复位/重新发起自动的流程测试：程序 0 选择收到 ACK → N045 放行 → 压缸/Kistler 分支 → 到位后力稳定 → 电阻测量 → 回升，并继续中/右位置。

如仍卡 N045，保留现场状态并读取选择器 ErrorCode / 实际响应；不能跳过程序确认、强制气缸输出或放宽力联锁。**AI 本轮未连接实体 PLC、下载、启停或写变量/FORCE；现场是否消除 NAK 和完成循环尚未验证。**
