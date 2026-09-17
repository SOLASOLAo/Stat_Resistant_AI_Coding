# 每次电阻测量的上下限判定

2026-09-11，用户已将 TypeData 上下限单位改为 Ω，并明确要求每次测量完成后判断是否在上下限范围内。

## 当前行为

- 本地导出的 `TypeDataSetManagerL1.dat` 中 UpperLimit、LowerLimit 的 Label2 均为 Ω，已按 CP936 正确读取；未修改用户配方。模板默认值 0 不代表活动配方数值。
- N080 在启动每次 SINGLE_MEAS 前，将 active TypeData 的两个 Ω 限值复制到 Unit.ParCmd。该步骤启动后不会重复复制参数。
- N090 保留原 CheckPressForce、CheckUnitDone、RepeatOnError=FALSE 和错误处理。在命令成功完成、结果尚未捕获时，复制原始 Ω 电阻值，并明确计算：`NOT OutOfLimit AND LowerLimit <= Resistance <= UpperLimit`。使用本次命令的 ParCmd，包含上下边界，不从四舍五入后的 HMI mΩ 值判定。
- 完成但超公差：Valid=TRUE、Ok=FALSE；在范围内且无量程越界：Valid=TRUE、Ok=TRUE。通讯失败或力故障不进入有效结果捕获。OutOfLimit 仍表示仪表量程状态，不混作公差超限。
- 新增首次捕获保护，单步停留不重判；每次新的子链执行仍清空结果。父链 LEFT/MIDDLE/RIGHT 原有锁存及 HMI 的 Valid/Ok 映射保持，各位置独立显示结果。

本次以应用层显式比较满足产品判定要求，不依赖尚未核实的闭源 ResistOk 比较实现。标准 Unit、驱动、命令握手和 OutCmd 均未改写；未新增整件汇总、超差停机或自动重测策略。

## 修改和验证

- PLC 仅一个目标：`Application/Station/Wp100/_this/Chains/Sub/SqS_Wp100_Run/_aN090_active`。现有事务脚本 PlanOnly 为 1 个 PUT；保存前后回读 41 个目标，声明和 SFC 图保持；最终 PlanOnly 为 0 操作。
- 复用现有 N090 源码、应用脚本和 Burster 测试文件；规格及工程计划同步。未改生成接口，没有新建 FB 或变量。
- 12 个用例直接执行从 N090 提取的布尔表达式，输入按 REAL 精度：下限外、等于下限、范围内、等于上限、上限外、量程错误、反向限值、上下限相等、NaN 数值/限值。全部通过。
- 力联锁、Kistler 生命周期、SFC 完成契约及工程框架检查通过；三个冻结组件源清单检查仍通过，既有包未更新。Project Pack 为 VALID，contentId `315b56e72fec669c34733a82974664168e23292db6dea9be3f63d78e74093a40`。
- 原有 PLE、profile `ctrlX PLC 2.6.8`，离线执行一次新 F11（2026-09-11 17:51:02）：**0 errors / 5 warnings / Ready for download**。仍为 4×C0351（OPC.UA.DA 属性）及 1×C0373（ErrorCodes/DWord），无新增告警签名。

证据：`data/reports/plc/resistance-grading-20260911-174805/` 的 plan、apply、post-plan、verification。修改前工程已保存一份 SHA 校验一致的内容寻址 checkpoint，SHA `8cd1f26a683f9df4c58d7c45b9c0d4fa68d5e8415f5f6ff9c58534e90677b6fc`。

## 现场边界

本次没有连接实体 PLC、下载、触发测量、启停、FORCE、部署 IPC 或上传 GitHub。现场仍需在用户授权部署后，核对实际活动配方的 Ω 数值，并分别验证左/中/右的合格、超差和重复周期。离线表达式测试及编译不代表真机判定已验收。
