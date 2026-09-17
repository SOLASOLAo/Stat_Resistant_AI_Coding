# Burster 2316 驱动 — 0.1.0-rc.2

**源码候选组件，不是已编译安装库。** 原厂通信 Peripheral 不再使用，但 Nexeed
标准 Unit、HMI、上下限判定仍保留。本组件依赖原厂公开接口及 OpCon TCP，不能称为
不依赖 Nexeed 的通用 CODESYS 库。

## 本版内容与不变项

- 相对 rc.1，驱动协议源码逐字未改；本版补齐实际依赖、不可变文件哈希与独立消费失败证据。源码提交锚点加实际快照摘要共同确定版本。
- 一个 `OpconTcpClientIpV4` 实例负责 Open/选程/测量/Close，手动和自动共用。
- `*RCL` ACK + 程序回读 + 无仪表错误才确认选程；测量启动前再次核对程序。
- 解析结果换算为 **Ω**，温度为 **°C**；格式错误、溢出、旧EOC都不能变成有效零值。
- 量程与补偿由仪表程序管理，`SetRangeCmd` 明确返回错误1301；保留HMI禁用设置量程。
- 当前支持范围是 2316 Ethernet 快速选择协议，不包含串口、BCC或任意仪表协议。

保留 `FB_Wp100BursterSingleOwner` 这个已验证 POU 名，首版不因整理目录而重命名。
驱动内部无 `Station.`、`AiWp100.` 或固定站点 IP 访问；Wp100 前缀是历史命名，
不代表驱动只能用于这个工位。未来正式安装库的名称/命名空间调整必须重新编译。

## 调用合同

| 接口 | 作用与约束 |
|---|---|
| `Hostname` | 项目提供地址；操作过程中不得改变 |
| `RequestedProgramNo` | 项目提供0..15程序号；测量中改变则报错 |
| `MeasurementTimeout` | 项目提供1..120秒，默认30秒 |
| `Open()` | 连接并核对仪表身份 |
| `SelectProgram(ProgramNo)` | 选程并回读；只有完成才设置SelectionVerified |
| `MeasCmd(CmdSetting, rResult)` | 标准Unit调用；准备/核对程序，启动一次，等新结果 |
| `Close()/Reset()` | 异步完成待处理I/O，必要时ABOR，再EOT/Close |
| `ClearError()` | 显式恢复入口；先完成清理，不能跳过CleanupBlocked |

方法按既有 OpCon 合同返回 `RUNNING` / `OK` / `HAS_ERROR`；返回RUNNING时保持
参数与缓冲区，后续扫描继续**同一个**方法，不能用IsOpen替代异步完成判断。
FB本体无自动网络动作；不可每扫描并行调用Open、选程和测量。禁止两个实例连接
同一台仪表抢占TCP 5555，禁止为“重试”另起Socket。

`Connected`不等于选程已确认；`ResultValid`不等于产品合格。结果上下限判定仍由
标准Unit与工位TypeData负责。失败保留第一个`ErrorCode/LastError`，不自动重连、
自动重新测量或清警放行。

诊断：1001–1005连接/身份，1010底层I/O，1020–1026帧交换，1101–1107选程，
1201–1213测量，1301不支持设置量程，1401–1403清理/恢复；1501–1503属于本站
选择器适配，不属于驱动协议。以源码为准；保留LastCommand/LastResponse排查，
不在Skill中另写一套错误码逻辑。使用既有通信事件表的映射也属于Nexeed依赖。

## 接入新项目

1. 先核对清单中的依赖与设备协议；固件和部分依赖版本仍待采集，不能假定兼容。
2. 用户在CpStudio保留标准Burster Unit/HMI，清空可选Channel并移除旧通信Peripheral。
3. 新项目只创建一个驱动实例；地址、程序号、超时来自项目配置。库不包含左中右、
   2500N、压缸或事件号。未来若将地址/超时放StationData，由用户在CpStudio加接口。
4. 在声明的非生成区绑定`Unit.ParCfg.iBursterResis2316`，标准Unit与选程共用此实例；
   绑定生命周期和取消后的周期清理参考本包`station-reference`文件，不能整段盲贴。
5. `FB_Wp100BursterProgramSelect`和AiWp100全局变量是**本站适配参考，不属于库核心**。
   新项目需要重绑定引用；本版不提供通用安装器，也不自动移除任何Peripheral。
6. 接入后独立Build/回读、手动测量/取消/故障恢复，再做工位自动。只在明确授权后下载。

## 测试及版本边界

在包根目录执行：

```powershell
python -m unittest discover -s tests/offline -p test_burster_single_owner_protocol.py
```

18项协议参考模型/源码契约测试不是ST执行器。今日一轮自动完成仅属于原工位组合；
结果数值/合格判定、重复运行、取消、断网/重启仍需验收。打包没有改变当前PLE或PLC。
源规格里`integrated_offline_candidate`保留为原提交的历史元数据；本组件的最新交付
状态以`component.json`和本说明为准，不能因源码包检查通过就标为稳定库。

原生库已于 2026-09-10 试建，但独立消费 Build 达到 500 errors 上限，主因包括 qualified-only 的未限定引用及缺少 ctrlX 平台重定向；失败试验库已卸载，本包不包含该二进制。详见 `docs/reviews/burster-native-library-20260910.md`。

2026-09-11 只读回读当前 Station010：OpconBase 1.0.102.0、OpconBaseCommonDef 1.0.7.0、OpconTcpDDL 1.2.19.0、NexeedBursterResis2316Base 1.0.0.0、Standard 3.5.18.0；OpconBaseSysDep→NxBaseSysDep_CXA 1.0.6.0，OpconSocketSysDep→NxSocketSysDep_CXA 1.0.7.0，Tc2_System→IecSfc 4.1.0.0。
这是成功的本站解析组合，并非已验证的最小独立库依赖。后续独立库应使用对应 ctrlX 重定向及公开 namespace 访问设置，不能补装 TwinCAT 库代替。

本轮保留 CpStudio 当前工程及唯一 PLE，不另起/接管库写入会话。正式 Company、独立库与独立消费新 Build、设备固件仍待；源码包可用不代表原生库已合格。

升级：先用包内 `scripts/components/Test-ComponentPackage.ps1` 验 SHA，再对比核心/接口与本站适配；在正常离线窗口通过 PLE 应用并编译。回滚需恢复该工位原有的源码、依赖和配置组合并重新编译，经另行授权后下载；不能只回退一个 FB 或恢复旧双 Socket Peripheral。
详见[公共版本规则](../README.md)。首次RC不允许覆盖发布；修复应形成下一个版本。
