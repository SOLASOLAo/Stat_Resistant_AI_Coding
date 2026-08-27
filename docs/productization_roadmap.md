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
3. **P1.3 Windows Runner Host**
   - 将同一 Runner core 托管为稳定后台进程或 Windows Service；
   - 提供安装、启动、停止、状态、日志保留和崩溃恢复；
   - UI/托盘只展示状态，不绕开 Runner 门禁。
4. **P1.4 团队发行**
   - 固定版本、安装包、升级/回滚、兼容矩阵和工作站体检；
   - 新电脑无需手工拼接多个脚本。

实现约束：P1.1 先以 Windows PowerShell 5.1 薄入口复用现有已验证脚本并固定行为契约；
产品 Runner Core/CLI 以 .NET 8 为目标。P1.2 增加运行在交互用户会话中的唯一
Runner Agent/Broker，由它独占 MCP stdio 和 PLE；未来 Windows Service 只负责队列、
策略和证据，通过本地 IPC 调用 Agent，不从 Session 0 直接启动可见 PLE。

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
- 下一步仅推进 P1.2 唯一 session Agent/Broker 与 immutable action 执行器；
- Phase 2–4 暂不展开实现。
