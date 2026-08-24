# Nexeed License Server 61863 故障诊断

## 已确认结论

2026-08-24 在实体 ctrlX CORE X3（ctrlX OS 2.6、arm64）上验证：CpStudio 的
`LicenseServer → Read from target` 失败，不是 PLC 工程、CpStudio 配置或电脑到 ctrlX 的
基本网络故障，而是目标上的 Bosch Nexeed Automation Licensing 服务反复崩溃。

- ctrlX HTTPS `443` 可连接；Nexeed OPC UA 端口 `61863` 被目标主动拒绝。
- 手动重启 App 后约两分半内完整复现 9 次启动/崩溃循环。
- 每个循环均按同一顺序出现：

  ```text
  all required slots and plugs connected
  → AppArmor DENIED capability=12 capname="net_admin"
  → Realtime information error. StatusCode: 999
  → Main process exited, status=11/SEGV
  → systemd 延迟约 10 s 后重新启动
  ```

因此 `61863=False` 是服务没有存活到监听阶段的结果，不是根因。端口探测本身不能判断
App 为什么退出，必须结合 ctrlX Logbook。

## App 包审计

项目只读标准包 `../Std/LicServerCxa/ctrlx-bosch-nexeed-automation-licensing-2.2.0.app`
的 arm64 snap 元数据为：

- `version: 2.2.0`
- `architecture: arm64`
- `base: core22`
- `confinement: strict`
- daemon：`automationlicensing`
- `restart-condition: always`，`restart-delay: 10s`
- daemon plugs：`network`、`network-bind`、`active-solution`、`log-observe`

包内没有声明 `network-control` 或 `network-manager`，但运行日志中的进程稳定请求
`CAP_NET_ADMIN` 并被 AppArmor 拒绝。该权限不匹配是目前最强的根因线索；仅凭日志仍不能
证明它是 SIGSEGV 的唯一原因，但应用没有正确处理失败并发生 native crash，本身也属于
供应商签名 snap 的缺陷。

包内 OPC UA 配置明确指定外部端点 `opc.tcp://[NodeName]:61863`。六项 Control plus S/M/L
许可的 manifest 标志均为 `required: false`，因此“许可证尚未读出”不能解释服务完全不监听。

官方发布说明称 License Server 2.2.0 支持 ctrlX CORE X3/X5/X7 和 ctrlX OS V2：

- [Bosch Control plus V2.9 / License Server 2.2.0](https://community.bosch-connected-industry.com/nexeed-automation/releasenotes/post/update-for-control-plus-v2-9-ZT3UCZTUamDjB8B)
- [Snap `network` / `network-bind` 接口边界](https://snapcraft.io/docs/reference/interfaces/network-interface/)
- [Snap `network-control` 接口](https://snapcraft.io/docs/reference/interfaces/network-control-interface/)

## 处理边界

该问题不能通过修改 PLC、Symbol Configuration、CpStudio Export 或 Windows 防火墙解决。
不要手改 ctrlX AppArmor，也不要修改/重签供应商 `.app`；接口权限属于签名 App 的发布边界。

向 Bosch/Nexeed 支持提交以下最小证据：

1. ctrlX CORE X3、ctrlX OS 2.6、arm64；
2. Bosch Nexeed Automation Licensing 2.2.0；
3. `443=True`、`61863=actively refused`；
4. 上述四步 Logbook 时间链；
5. snap 未声明 `network-control`，同时出现 `DENIED net_admin`；
6. 当前两份 developer Logbook CSV 和本地端口诊断报告。

设备序列号、账户信息、原始 CSV 和本机网络列表不进入 Git；需要时只通过公司批准的支持
渠道发送。

## 只读端口诊断

断网现场可运行：

```powershell
powershell.exe -ExecutionPolicy Bypass -File `
  .\scripts\diagnostics\Test-CtrlXLicenseServer.ps1 `
  -TargetIp 192.168.0.51
```

报告默认保存到桌面 `DiagnosisFiles`。脚本只读取网卡、IPv4、路由和邻居状态，并测试
`443/61863` TCP 连接；不登录 PLC、不下载、不启停 runtime、不写变量、不 FORCE，也不更改
电脑或 ctrlX 网络配置。诊断报告可能包含本机网络信息，禁止提交 GitHub。

## 修正版验收

供应商提供兼容 App 后，按以下顺序复验：

1. App 在 Operating 状态持续运行，Logbook 不再出现上述循环；
2. 连续观察至少 60 s，`61863=True`；
3. CpStudio `Read from target` 能返回 Hardware ID 和许可证列表；
4. 再继续 PLC 下载与设备调试。真机下载、启停和变量写入仍需单独安全确认。
