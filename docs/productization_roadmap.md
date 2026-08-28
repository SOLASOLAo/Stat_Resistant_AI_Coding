# ctrlX AI Coding 产品化主路线

> 本文件是产品执行顺序的唯一事实源。`ctrlx-ai-coding/docs/mcp_productization_roadmap.md`
> 只描述第一阶段内部的 MCP/adapter 技术子路线，不另行改变产品优先级。

## 目标

把当前依赖人工编排的 CpStudio、Git、PLE/MCP 和验收脚本，逐步变成可重复、可审计、可在多个自动化项目复用的本地工程产品。

当前只推进一个阶段，不同时扩张 Runner、项目生成、HMI 和商业包装。

## 执行顺序

### Phase 1：稳定受控 Runner（当前）

目标：把零散脚本收拢为一个 Windows 本地执行入口，确定性地消费请求、执行门禁并生成证据。

交付顺序：

1. **P1.1 Runner 控制面**
   - 统一 CLI 入口；
   - OS 级单 owner 租约；
   - 校验 `project.yaml`、Station/PLC 路径、profile、ownership manifests；
   - 串联已有 Post-export Stage 1 审计和 Stage 2 immutable action 生成；
   - 每次运行生成结构化 `run-manifest.json`；
   - 默认不启动 PLE/MCP，不含任何在线能力。
2. **P1.2 工程 action 执行器**
   - 只复用唯一 persistent PLE/MCP owner，不启动第二个 PLE；
   - 校验 action/hash/工程上下文/能力白名单；
   - 执行 snapshot、readback、fresh Build 和 warning 指纹；
   - 生成可由 Stage 2 ledger 验证的 evidence；
   - 相同 action 幂等，失败关闭。

   当前拆为两个可独立验收的小步：

   - **P1.2a Action Client（2026-08-27 已实现）**：.NET 8 Core/CLI、严格
     action 与 `operation.json.currentAction` 绑定、hash/fingerprint 校验、OS 级
     profile-project/action-run 双租约、不可变 claim/result 与重放完整性复核、
     Named Pipe v1 的实际 server PID/Windows session 核验、NoSession 失败关闭，
     以及已发布 evidence producer 的 SHA 封口；
     客户端没有启动 PLE/MCP/Broker 或调用在线能力的入口。
   - **P1.2b Session Agent/Broker（2026-08-28 已完成）**：interactive Broker 的单 owner、
     current-user Pipe/registration、typed allowlist、durable submit/query、崩溃后
     `UNKNOWN_REVIEW_REQUIRED` 和 external PLE 不接管/不关闭均已实现。受控 adapter、
     typed warning、显式 `clean_compile_project`、456 条 mapping 与 Symbol semantic snapshot
     均已在真实 Station010 PLE 离线 action 中验证。正式 warning/semantic baseline 已建立；
     recoverable-baseline 不再要求提交 `.project`，而是在 Build 前创建当前用户、本机、按
     工程 SHA 寻址的不可变 checkpoint，并在损坏或源工程漂移时于 Build 前失败关闭。
     request `839ff68c-6ac8-4764-8258-7cef4aa10406` 的全新 action 最终取得 0 errors / 4 条完整
     `OPC.UA.DA` warning，456 mapping、Symbol、baseline、checkpoint 与工程/结构哈希全部通过。
     不得执行 action 中的自由文本指令。
   - **P1.2b 失败关闭加固（2026-08-28 已实现）**：warning 截断不会进入正式
     baseline；一次明确用户确认即可且不采集姓名/工号，candidate/AI triage（含改名副本）
     不能自动冒充确认；confirmation/scope/baseline 使用同一有界字节完成校验、SHA 与解析；
     semantic snapshot 在最终 REST 读取
     后再次核对 clean/稳定状态，response 使用 30 s 全程超时与 8 MiB 流式上限；畸形请求
     和证据生成器不会持久化或回显凭据。补丁语法检查失败会非零退出并恢复本轮写入。
3. **P1.3 Windows Runner Host**
   - 将同一 Runner core 托管为稳定后台进程或 Windows Service；
   - 提供安装、启动、停止、状态、日志保留和崩溃恢复；
   - UI/托盘只展示状态，不绕开 Runner 门禁。

   当前切片：

   - **P1.3a（2026-08-28 已实现）**：current-user interactive Host 提供单实例、
     心跳/状态、受控停止、限定 JSONL 日志保留和可选 AtLogOn Scheduled Task；只观察同一
     Windows 会话中已验证的 Agent/Broker。Host 永不启动 Broker、MCP、PLE、Node 或在线操作；
     有待处理 action 且 Agent 不存在时保持 `WAITING_FOR_AGENT`；没有 action 时保持 `WAITING_FOR_ACTION`。
   - **P1.3b（2026-08-28 已实现）**：Host 只从 Stage 2 operation ledger 的
     `currentAction` 发现任务，自动消费首次激活后生成的 immutable action；历史已终态任务
     隔离、旧 open claim 可恢复、任一异常/歧义失败关闭。无 Agent 时等待，结果生成后保持
     `WAITING_FOR_COORDINATOR`，不会自行推进 ledger。
   - **P1.3 后续（未完成）**：result/evidence 自动接收与 ledger 推进、稳定安装目录、
     产品级升级/回滚和完整生命周期尚未完成，不能把 P1.3b 标记为整个 P1.3 完成。
4. **P1.4 团队发行**
   - 固定版本、安装包、升级/回滚、兼容矩阵和工作站体检；
   - 新电脑无需手工拼接多个脚本。

实现约束：P1.1 以 PowerShell 7 (`pwsh`) 薄入口复用现有已验证脚本并固定行为契约；
产品 Runner Core/CLI 以 .NET 8 为目标。P1.2 增加运行在交互用户会话中的唯一
Runner Agent/Broker，由它独占 MCP stdio 和 PLE；未来 Windows Service 只负责队列、
策略和证据，通过本地 IPC 调用 Agent，不从 Session 0 直接启动可见 PLE。P1.3 Host
同样只运行在当前用户交互会话；P1.3b 可调用已经存在且身份匹配的 Agent/Broker，但绝不
替代或自动启动它。

Phase 1 验收：

- 双启动只有一个 owner；
- 连续请求不会互相覆盖；
- 同一 action 不重复执行；
- 任一 gate 失败都不会进入 `DONE`；
- 不会启动第二个 PLE；
- 默认不存在 connect、download、start/stop、runtime write 或 FORCE 能力；
- 运行结果可追溯到 request、action、工程 hash、Git commit 和诊断指纹。

### Phase 2：项目目录与流程生成

目标：新设备项目不再靠复制、改名和重复口述完成初始化。

主要交付：

- 标准 Project Pack 与 Schema；
- 新项目初始化器；
- 统一的 I/O、事件、Unit、Chain 和验收规格；
- 从同一流程事实源生成 SFC 计划、步骤提示、测试骨架和追溯关系；
- Runner 对 Project Pack 做确定性校验。

验收：新项目只需填写项目事实和工艺差异即可进入受控工程闭环，目录和流程没有静默漂移。

### Phase 3：HMI 产品化

目标：把当前 Station010 自研 HMI 原型抽象为配置驱动的 Windows HMI 产品。

主要交付：

- 通用壳、模式/事件/I/O/Data/Manual Unit 页面；
- OPC UA 节点 Catalog 与写入白名单；
- StationData/TypeData、Unit 参数和状态页面生成；
- 断线、超时、权限、审计和与 Nexeed HMI 的 A/B 验收；
- 由 Project Pack 生成工位配置，而非每台设备重新开发界面。

### Phase 4：商业交付

目标：把已经稳定的 Runner、Project Pack 和 HMI 组合成可安装、可维护、可售卖的工程产品。

主要交付：

- 安装器、许可证、版本/升级/回滚；
- 支持矩阵、诊断包、审计报告和维护工具；
- DemoStation、试点项目和交付手册；
- 知识产权、第三方许可、信息安全与公司审批。

## 贯穿所有阶段的门禁

- CpStudio 继续拥有模型、标准对象、HMI 配置、事件、StationData 和生成接口；
- `.project` 只能通过相应 IDE/MCP/官方接口维护；
- `Std` 严格只读；
- 实体 PLC 的连接、下载、启停和变量写入始终需要单独即时批准；
- 任何真实密码、客户信息或内部资产不得进入公共产品仓库；
- 编译通过只表示 `COMPILED`，没有确定性行为证据时不得标记为 `VERIFIED`。

## 当前状态

- 2026-08-27：当前可用多仓库基线已标记为 `usable-2026-08-27`；
- 2026-08-27：P1.1 Runner 控制面已完成并通过当前项目、通用模板和新项目初始化器回归；
- 2026-08-28：P1.2a Action Client 与 P1.2b Broker 技术通道已完成；隔离 REST warning-limit
  事务、显式 Clean Build、本机内容寻址 checkpoint、正式 warning/semantic baseline 与全新
  Station010 immutable action 复验均已完成。最终 action 为 0 errors / 4 warnings，456 mapping
  与 Symbol 稳定，工程未改变且无在线操作；P1.2 已关闭；
- 2026-08-28：P1.3b 已完成 activation 后 immutable action 的受控自动消费、历史隔离、
  open-claim 恢复、单 action 和 `WAITING_FOR_COORDINATOR`；自动 ledger 推进、稳定安装与
  升级/回滚仍待 P1.3 后续完成；
- Phase 2–4 暂不展开实现。
