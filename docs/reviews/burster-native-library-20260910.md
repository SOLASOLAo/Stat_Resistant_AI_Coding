# Burster 原生库隔离验证（未通过，禁止用于现场）

日期：2026-09-10。源码候选仍为 `burster2316 0.1.0-rc.1`，固定 `d37918a4863bdaaf7937df5daa3b948ef124e22d`。现有源码包是第一阶段的不可变记录，其中 `nativeLibrary.status=not-built` 不充当实时库盘点；本页记录后续试构建结果。**没有可交付的已通过原生库，也没有替换 Station010 驱动。**

## 已做

- 唯一 `ctrlX PLC 2.6.8` MCP/REST 会话中创建隔离 `BppBurster2316.library`，只复制既有 FB/方法/属性共 15 对象；源码逐对象回读一致。无本站 GVL、设备绑定、SFC 或 2500 N 工艺参数。
- 身份为 `BppBurster2316`、版本 `0.1.0.1`、命名空间 `BppBurster2316`、`Released=false`。Company 使用临时内部标识 `BPP Internal Engineering`，不是 Bosch 官方发布者身份；正式命名仍需确认。
- 官方 REST `SaveAsCompiledLibrary` 返回成功并产生文件，但这一步**不证明代码通过编译**。
- 仅为消费验证临时安装到开发机库仓库，在 `Standard.project` 派生的隔离 `BursterConsumer.project` 引用它；从未把该引用添加到 Station010，从未下载这个测试工程。

## 独立消费 Build 结果

第一次 Build `fa0b8b55deba4c91be7091ee6e830dfc`：184 errors / 32 warnings。测试 POU 自己用了保留标识符 `ret`，已修正为 `_ret`。

修正后新 Build `dbc7c9fd43664e81ba0654b92c83cedb`（UTC 14:59:33–14:59:36）仍失败，Build 摘要 **500 errors / 2 warnings**；达到错误计数上限，细节仅返回前 100 条，warning 明细完整性未验证。不能说全量只有这些根因，也不能与 Station010 的 5 个 warning 作比较。原始摘要保存在 `data/component-native/consumer-validation.json`。

已确认的阻点：新加的库引用全部 `qualified_only=True`，而本站稳定 FB 使用未限定的 `IBursterResis2316`、`OpconDeviceError`、`OpconTcpClientIpV4`、`TON`、`RUNNING/OK/HAS_ERROR` 等。因此报未知类型/标识符并级联。修订前还看到空白库的 `Tc2_System` 平台占位符未解析；需正确使用 ctrlX 平台解析，不能安装 TwinCAT 依赖硬凑。

实际加入的直接依赖与只读查得 namespace：

| 库 | 版本 | namespace |
|---|---|---|
| OpconBase | 1.0.102.0 | OC_OpconBase |
| OpconBaseCommonDef | 1.0.7.0 | OC_OpconBaseCommonDef |
| OpconTcpDDL | 1.2.19.0 | OC_OpconTcpDDL |
| NexeedBursterResis2316Base | 1.0.0.0 | OC_NexeedBursterResis2316Base |
| Standard | 3.5.18.0 | Standard |

CpStudio 生成模型另列 `NxSocketSysDep_CXA 1.0.7.0`；具体 socket 类型归属、需不需要直接引用及所有有效平台依赖仍待核清。**上表不是已验证的最小依赖清单。**

## 收尾与恢复

- 只保存并关闭我们创建的 `data/component-native/burster-consumer/BursterConsumer.project`。Close job `65739f1c5c673af8` 已 Done；没有关闭用户的 Station010 工程或停止 PLC。
- 经官方库仓库 DELETE 精确卸载本轮安装的 `BppBurster2316, 0.1.0.1 (BPP Internal Engineering)`；随后查询已无此库。其他库不变。
- 恢复文件保留在 `data/component-native/burster2316-0.1.0-rc.1/BppBurster2316.library`，对应 `.compiled-library` 也只是失败候选，**不要安装/发布**。无需回滚现场程序，因为未动 Station010。
- 原有两个源码包/版本锁不变，未创建 tag/Release 或推送 GitHub。

## 下一次继续

在隔离库工程通过正式支持的库设置接口/IDE 修正命名空间访问与平台占位符；不要用审计用 `eval_python` 绕过写入约束，不直接修改库二进制或背景依赖工程。若选择改为全限定源码，采用可追溯的新候选版本且不改本站稳定驱动来迁就打包。然后重新生成、安装、消费 Build 成功，补齐依赖/接口/诊断检查，再考虑现场替换。原生库未通过不影响当前源码驱动使用。
