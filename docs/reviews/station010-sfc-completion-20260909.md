# Station010 SFC 完成逻辑检查 · 2026-09-09

本批离线修复已保存、回读；用户确认修复后 F11 为 **0 errors / 5 warnings**。
警告明细未提供，真机下载/验收未执行。此结论不代替现场安全验证。

## 修改

- `SqM_Station_Home` 删除无 Action 的 N110 及其多余完成转换。现在是
  `N000 → N100 → N999`。N100 原有 `ExecuteSubChain(Station.SqS_Homing, TRUE)`
  已负责启动并等待子链 DONE；保留这段实现，不以无条件 OK 绕过回原位。
- `SqS_Wp100_Run` 的每个并行分支在真实完成之后进入独立末尾等待步：
  N060 → N065、N061 → N066、N110 → N115、N120 → N125。
  N065/N115 只写 `_retVal := OK;`，N066/N125 只写 `_retVal2 := OK;`。
  前面的命令、完成/错误检查和共同汇合条件全部保留。
- 两张 SFC 图、四个新 Action 是本次唯一 PLC 逻辑差异。原有 Action、Method、
  生成声明、气缸/安全/力联锁、Burster/Kistler 参数和 I/O 均未改变。

## 全量检查

经现有 PLE REST 扫描 Application：修复前 363、修复后 367 个可读取对象，
共 12 条 SFC Chain。唯一不支持读取的是 MainTask 下 MAIN 的 TaskPOUCallObject
（HTTP 501）；它不是 Chain，不影响下面 12 条图及其全部子 Action 的检查。

| Chain | 修复后步骤数 | 结论 |
|---|---:|---|
| SqM_Station_Auto | 4 | N110 有真实子链完成握手，保留 |
| SqM_Station_Manual | 3 | 未发现同类空步骤 |
| SqM_Station_Home | 3 | 删除空 N110 |
| SqM_Station_Changeover | 4 | 未发现同类空步骤 |
| SqS_Station_Homing | 4 | 未发现同类空步骤 |
| SqS_Station_ChangeOverFile | 20 | 选择分支，不是同时执行分支；保留业务检查 |
| SqS_Station_Auto | 4 | 未发现同类空步骤 |
| SqC_Wp100_DeleteWpcData | 6 | N110/N120/N130/N140 只有模板注释，待确认清理范围 |
| SqC_Wp100_Home | 4 | 未发现同类空步骤 |
| SqC_Wp100_Run | 14 | 未发现同类空步骤 |
| SqS_Wp100_Home | 9 | 保留真实运动完成等待 |
| SqS_Wp100_Run | 27 | 两组并行、四个分支末尾增加完成保持 |

未发现未引用的子 Action。Init/Finish 框架步骤及真实等待不是无效步骤。
DeleteWpcData 还没有业务实现；用户未确认不用或明确清除对象前，不擅自
将它变成返回成功的空操作。该项保持 TODO 未完成。

## 验证与恢复

- 写前 `.project` checkpoint SHA-256：
  `aac3e08e7e61afb08e7fbb25fd9f90811c172eee9d4f4678aef7254ba0d6d849`。
  另有完整对象快照；只操作原有 PLE/profile，Application offline，MCP stopped。
- Home 第一次写入遇到 PLE 对 native localId 连续重编号，严格回读不一致而自动
  回滚并核验成功。目标改为连续 ID 后重新 Plan/Apply/Save/readback 全部通过；
  测试已覆盖 ID 连续性，未放宽差异校验。
- Home Apply plan：`1f6e59a60587f3b6e36f8bbff1f6de57b575f8f601253429ab1dab6b815da12f`。
- Run Apply plan：`346bebd3cf1291e37c29858c7debebecedc3531c96ae47f464a95e3fc0f2c44a`。
- 最终 Home、Run、SqC Run 三个 PlanOnly 均为 0 操作；原有 33 个目标对象
  的实现/声明比较，仅两张预期 SFC 图有变化。
- 保存后的 `.project` SHA-256：
  `c5d5ec1c67b9a1bedf78a0228edc2c71fa28ca024062ffc207d2716c26306356`。
- 静态/模拟 REST 检查覆盖：空 Home 步骤、图连接、分支末尾自身返回值、
  A 先完成/B 先完成/同时完成/一支不完成、在线 Apply 拒绝、事务回滚、
  位置/力/量程/提示合同。扫描模型不是标准库或真机仿真。
- 用户随后回复本次 F11 `0error, 5 warnings`；独立记录，不冒充 MCP Build
  或 warning 签名已审阅。工程代码和进度入 Git，原始 `.project` 与日志仅本机备份。

本地证据：`data/reports/plc/sfc-completion-{plans,after,user-build}-20260909.json`；
完整只读快照 `sfc-completion-objects-after-20260909.json`。后续 CpStudio Export
后按 ownership/graphical 清单复查，必要时用同一受控 writer 恢复；不直接改模型 XML。
