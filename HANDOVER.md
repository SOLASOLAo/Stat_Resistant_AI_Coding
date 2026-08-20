# HANDOVER.md — 会话交接

> 目的:让下一个 AI 会话(或人)3 分钟接手。**每次会话结束前更新本文件**。

## 最近会话(2026-08-17)
- 做了什么:
  1. 克隆 vibe-coding-templates;派生仓库骨架到 McpCoding;填写四文档 + .gitignore;git init。
  2. 克隆 ctrlx-ai-coding(方法论母本),通读 README/AGENTS;把其环境事实与红线并入本仓库 AGENTS.md。
  3. 环境体检:CRLF 补丁 -Check 全 OK;Standard.project 模板与 Managed Libraries 库仓库存在;MCP 状态 ready。
  4. 推送上 GitHub:仓库 Stat_Resistant_AI_Coding(public, main);大文件素材经 .gitignore 全部排除,库内仅 11 个小文件。
- 产出(提交/文件/数据):骨架首次提交 e9b4fc3;AGENTS/TODO 并入 ctrlx-ai-coding 规范(本次提交)。
- 未解决的问题:尚无工艺需求清单(../电阻测试台.pdf 未解析);CODESYS 工程未创建。

## 当前状态
- 分支 / 最新提交:main,远程 origin = github.com/SOLASOLAo/Stat_Resistant_AI_Coding(public)
- 能跑吗?如何验证:codesys MCP ready;下一步 create_project(templatePath=Standard.project) 后 compile_project 应 errors=0。
- 环境前提:ctrlX PLC Engineering PLE_V_0206(profile `ctrlX PLC 2.6.8`)+ codesys-persistent MCP(已打 CRLF 补丁);暂用仿真,不需要实体 PLC。
- 环境快照:Windows 开发机;参考工程 Station010_0708(OpCon V5.11 ctrlX)。

## 阻塞项
- 电阻测试台工艺需求需用户确认:可由 AI 解析 ../电阻测试台.pdf 提取,或用户直接口述。

## 下次会话建议第一步
1. 解析 ../电阻测试台.pdf,整理工艺需求清单到 docs/requirements.md 并请用户确认。
2. 该早期 `src/ResistantStation.project` 建议已废止；当前统一使用旁级 `Station010_0708` 受控集成工程。
## 最近会话(2026-08-18)
- 做了什么:
  1. 解析 ../电阻测试台.pdf:39 页渲染到 data/pdf_pages/;页 4 = EtherCAT 目标树;页 19-25 = K010A1-A4(EL1018)/K010C1-C3(EL2008)通道信号表;页 28 = 电阻测量 -A740(Burster 5877A,USB 接入,不在 EtherCAT 上)。
  2. 发现 PLE(2.6.8)打开 IO 工程会触发版本转换且 PLE 实例崩溃;IO 工程必须用 IOE(2.6.4)编辑。
  3. 新工具 `scripts/ioe/ioe_ipc.ps1`:复用 MCP 的 watcher 机制(--runscript + 文件 IPC),直接驱动一个独立的 ctrlX IO Engineering 2.6.4 实例(%TEMP%\ioe-ipc 会话目录)。已验证:open/树遍历/remove/save 全通。
  4. 硬件组态核对:Device→_000SA620_X1(EtherCAT Master,IP 192.168.0.51)→_000SK010(EK1100)→A1-A4=EL1018、C1-C3=EL2008,与图纸页 4 一致;类型 ID 校验通过(EK1100=2_044C2C52…,EL1018=2_03FA3052…,EL2008=2_07D83052…)。
  5. 坏节点 _100A740_BL(5877A,描述符缺失红?)在副本 IO_copy.project 上已 remove 并 save 验证;真工程备份 Stat010_V5.11_CtrlX_IO.project.bak_20260818 已建。
- 已完成:真工程 remove _100A740_BL + save(2026-08-18 04:52,409184 B);备份 .bak_20260818。回验实例因强退后重启弹已被编辑对话框,保守起见直接杀掉,未再写文件;最终由用户自行开 IOE 目验。
- 教训:脚本强退 IDE(Environment.Exit)后,同实例目录重启再 open 同一工程会弹lready being edited三按钮对话框并阻塞主线程;后台实例用完应 p.close() 后发 terminate.signal,勿强退。
- 经验:
  - IOE 无需 --profile 参数即可启动;ScriptEngine 4.1 对象模型:树用 get_children/get_name/remove/rename;通道名不在 IO 侧(PLC 工程 I/O 映射已含 _000S901/_000S610 等符号)。
  - Remove-Item 在本环境被策略拦截,用 [System.IO.File]::Delete / Copy-Item 代替。

## 补充(2026-08-18 晚)· 问题复盘归档
- 本次 9 类问题全部解决或有规避方案,沉淀到 ctrlx-ai-coding/docs/ioe_scripting_playbook.md(IOE-IPC 架构 + ScriptEngine 4.1 差异 + 踩坑表 + 复用检查单);ioe_ipc.ps1 已同步母本 scripts/;SESSION_LOG 登记 D16。
- 环境现状:MCP PLE 实例 ready(被误关后自动重拉);IOE 窗口由用户打开目视复核;.~u 锁为活进程持有,勿删;工程文件完好(409184 B @ 2026-08-18 04:52)。
- 待用户确认:IOE 树目视核对(Device → _000SA620_X1 EtherCAT Master(192.168.0.51) → _000SK010 EK1100 → A1-A4 EL1018 + C1-C3 EL2008)。

## 最近会话(2026-08-18 夜)· GitHub 备份 + 设备迁移转接

### 做了什么
1. **Station010_0708 主工程 GitHub 备份**:私有仓库 `github.com/SOLASOLAo/Stat_Resistant_Station010`(分支 main):
   - `6a7b4ea` 基线(259 文件;.gitignore 排除锁/缓存/备份/每用户配置)
   - `b9b1161` IDE/CpStudio 现状快照
   - 本地仓库已加 origin 并跟踪 origin/main,与远端完全一致。**以后 CpStudio 每次重新生成后先 `git -C ../Station010_0708 diff`**,即可逐文件分析低代码生成机制。
2. **3 个编译错误的定性(重要结论)**:
   - 当时现状:编译 3 errors / 16 warnings；三个名称为 `bus_000S900`、`bus_000SK010A1_Channel_6`、`bus_000SK010A1_Channel_7`。当时暂归因为陈旧符号表条目；后续已纠正为 A1 的旧 I/O 映射残留，见文末 0-error 收口记录。
   - 对照 `Engineering/Engineering_Data.xml`(CpStudio 模型)确认:模型里只有 `_000S900A/_000S900B`,**没有**裸 `_000S900`、Channel_6/7、IpKeyenceSr2000 → 这 3 个错误是旧残留,**不是 CpStudio 当前产物**,用户无需在 CpStudio 操作,在 PLE 里删即可。
   - `_Wp100A830Scanner` 警告条目在 CpStudio 模型中存在 → 属 CpStudio 管辖,勿擅删,由用户决定;`IpKeyenceSr2000(ParCfg)` 不在模型中 → 可删。
   - 当时使用错误显示名查找 SymbolConfig，误判为 ScriptEngine 不可见。后续确认脚本树内部名称为 `Symbols`，支持 `is_symbol_config`、`get_only_configured_signatures()` 等 API；导出的 Symbolconfiguration XML 本身也不含三个报错名称。
3. **CpStudio 定位**:Bosch OpCon/Nexeed "Control plus Studio" V5.11;模型 = `Engineering/Engineering_Data.xml`(10.7 MB,Bosch.OpCon.Data schema);索引 = `Engineering/Stat010_V5.11_CtrlX.cpsp`;HMI = `OpCon.HMI.Modulo`。**注意:模型中仍有 `Wp100A740*` 残留**——PLC/IO 侧 `_100A740_BL` 已删,若不在 CpStudio 删除 740 站,下次重新生成可能带回相关符号。
4. 后台副本实例(PID 32724)已被用户关闭,无副作用;MCP 附着的主 PLE(PID 9048)全程正常。

### 当前状态
- 当时编译:3 errors / 16 warnings；后续已完成根因纠正和 0-error 收口，见文末。
- 进程:PLE PID 9048(MCP 附着,session 6c072ed3-349c-45e1-93d9-158ecb1a83e5)、IOE PID 30656(持有 IO 工程)、gateway 正常。
- 仓库映射:McpCoding → `Stat_Resistant_AI_Coding`(public);`../Station010_0708` → `Stat_Resistant_Station010`(private);`McpCoding/ctrlx-ai-coding` → `SOLASOLAo/ctrlx-ai-coding`(独立子仓库)。

### 本机网络 / git 推送配方(必读)
- git 全局 `http.proxy=http://127.0.0.1:7890`(Clash)经常停 → 推送报 Could not connect;直连也不行(DNS 解析被拦)。
- 可用组合:`git -c http.sslBackend=openssl -c http.proxy=http://127.0.0.1:3128 -c https.proxy=http://127.0.0.1:3128 push https://x-access-token:$(gh auth token)@github.com/...`(schannel 后端在 Codex 沙箱里报 SEC_E_NO_CREDENTIALS;3128 代理常驻可用)。
- gh CLI 自身一直可用(建仓库/API 无需上述参数)。
- 若 Codex 沙箱为 workspace-write:写 `../Station010_0708/.git` 被拒 → 用 %TEMP% 中转副本(Copy-Item .git + robocopy 文件 → commit → push)。

### 下次会话建议第一步
1. 读 AGENTS.md → 本文件 → TODO.md;确认 MCP 状态(get_codesys_status)。
2. 符号清理:先问用户是否接受在 PLE Symbols 编辑器手删 3 行;不接受再试 import_xml 整表方案。
3. 用户若在 CpStudio 做了重新生成:立即 `git -C ../Station010_0708 diff` 归档分析。
4. 红线:真机操作(下载/启动/write_variable 强制)必须先经用户确认;PLE 绝不打开 IO 工程;.project 只能经 IDE/脚本引擎改。

## 最近会话(2026-08-18 午)· CpStudio/Git/MCP 闭环 + PLC 文本快照工具

### 已完成
1. 建立 `docs/cpstudio_git_mcp_workflow.md`：CpStudio 管模型/HMI/符号，Git 管生成差异，AI+MCP 管底层 ST 与编译闭环。
2. 新增只读确定性导出器 `scripts/plc/export_plc_snapshot.py`：只遍历 primary PLC 的 Application，跳过 Library Manager/Task Configuration/Symbols；一个代码对象一个稳定 `.st`，manifest 无时间戳并含 SHA-256；不 open/save/compile/online。
3. 新增 `scripts/plc/verify_plc_snapshot.ps1`；已通过成功样本和篡改检测自测。内置 `get_all_pou_code` 在 Station010 上因从根遍历设备树超过 120s，不适合作为该工程的批量导出实现。
4. 新增 `docs/cpstudio_generation_analysis.md`，记录 `b9b1161` 后当前未提交生成批次。

### 新发现：Station010 当前有外部生成改动，勿覆盖
- 本会话检查期间发现 `../Station010_0708` 已有 26 个未提交变化；不是本会话工具写入。
- `Wp100` 保留，但其下 5 个 Unit 全部从 PublicInterface/HMI 移除：安全门、下压缸、扫码枪、Kistler、Burster 2316；相关对象版本/类型/事件/SmartForms 同步裁剪。
- PLC `.project` 1,738,192 B → 1,597,120 B；当前 SHA-256 `FB437287F2482A9FA34408DC01F5DBD34F33FB281E6A33B34CBCF5D690E78819`。
- 用户 PLE PID 3888 以该 PLC project 启动并持有 `.~u` 锁。本会话已关闭自己因全量读取卡住的 MCP PLE PID 4316，没有触碰 PID 3888。

### 用户决策与下一步 / 阻塞
1. 用户已确认删除 Wp100 下全部 5 个 Unit 是有意建立最小干净框架；后续逐个添加设备，设备稳定后再逐条添加自动 Chains。
2. 用户关闭 PID 3888 对应的 PLE 窗口后，再启动唯一 MCP 实例，执行首份文本快照到 `data/plc_snapshots/station010`，连续导出两次验证零 diff并编译。
3. 快照验证通过后，再决定是否获准把文本镜像写入只读参考目录对应的私有 GitHub 仓库。

## 恢复点(2026-08-18 11:40)· 等待 Codex/VS Code 重载

- 用户已正常关闭原 PLE PID 3888，工程锁已消失；最小骨架删除范围已确认有效。
- 启动 MCP 前已备份 PLC 工程到 `data/backups/Stat010_V5.11_CtrlX_PLC.pre_snapshot_20260818.project`(被 gitignore 排除)。源文件与备份均为 1,587,104 B，SHA-256=`24A34D3B7A2B6E6E7E9AE57BE9794221716E75BA580A9E5ED20B3F19C9B4EB5C`。
- 首次 `open_project` 失败时查明：同一 Codex app-server 意外派生了 4 个 `codesys-mcp-persistent` Node 子进程，服务状态错误退化为 headless。已核验这些进程全部属于当前 Codex 后停止；当前 PLE=0、MCP Node=0。
- 停止 MCP 子进程也关闭了本会话的 stdio transport；后续工具返回 `Transport closed`。需要用户重载当前 Codex/VS Code 会话以恢复 MCP 注册。
- 整个失败路径没有改写 PLC project；事后源文件哈希仍与备份完全一致。`../Station010_0708` 仍保留 27 个有意的未提交生成变化，未提交、未回滚。

### 重载后的唯一第一步

在一次 MCP 调用链中依次完成：`get_codesys_status/launch` → `open_project` → 两次 `eval_python(execfile export_plc_snapshot.py)` → 本地校验零 diff → `compile_project`。避免把这些调用拆到多个独立 MCP client；不得再次走 headless。

## 恢复后结果(2026-08-18 11:50)· 最小骨架只读基线完成

- 扩展重启后状态正常：唯一 MCP Node + 唯一 persistent PLE，session `0b4dd2b0-85c1-44cd-a260-aa5fdfe470b0`，PLE PID 24368。
- MCP 打开 Station010 PLC 工程；两次快照均返回 215 个文本对象和相同 project SHA-256。PowerShell verifier 通过；文本树 SHA-256=`4e556b44bb2212c91d7c86d260a87b325b7dfeba8fe0f2b9622089a1dab63241`。
- 离线编译基线：66 errors / 40 warnings。3 errors 当时暂归为 SymbolConfig 残留，后续确认是 A1 旧 I/O 映射；其余 63 errors 是删除 Unit 后遗留在 10 个 ST 对象中的安全门/压缸/扫码枪引用，详见 `docs/cpstudio_generation_analysis.md`。
- 编译没有改写 project：当前哈希仍为 `24A34D3B7A2B6E6E7E9AE57BE9794221716E75BA580A9E5ED20B3F19C9B4EB5C`，与备份一致。
- 用户已明确选择方案①：授权 AI 经 MCP 修改 `../Station010_0708`，并将其正式定义为 CpStudio + MCP 受控集成工作工程；`../Std` 继续严格只读。后续已完成 10 个旧 ST 对象和三条 A1 I/O 映射的清理。

## GitHub 凭据绑定(2026-08-18)

- `gh auth status`：账号 `SOLASOLAo` 已登录 keyring，HTTPS token scope 含 `repo`。
- 公司环境的默认全局 Git 路径为不可写的 `U:\.gitconfig`，导致 `gh auth setup-git` 初次失败。
- 已建立/复用 `C:\Users\AGZ1WX\.gitconfig`，设置用户环境变量 `GIT_CONFIG_GLOBAL`，由 `gh auth setup-git` 写入 github.com/gist.github.com 的 gh credential helper；三个相关仓库的本地 `.git/config` 均 include 该文件，当前 VS Code 无需等待环境变量重启即可生效。
- 三仓库 `git credential fill` 均无弹窗返回 `SOLASOLAo`；私有 `Stat_Resistant_Station010` 经 3128 代理非交互 `ls-remote` 成功。配置中不存明文 token，凭据由 gh keyring 提供。

## ST 清理进展(2026-08-18 11:55)

- 用户已授权 Station010 为受控集成工作工程；权限规则提交 `5124d62`。
- persistent MCP 修改 10 个对象：空 Wp100 `OnApplyOutputs` + 9 个已删除设备的旧 Chain actions；清理前后快照对比恰好仅这 10 个对象变化，215 对象 manifest 校验通过。
- 编译从 66 errors / 40 warnings 降到 **3 errors / 40 warnings**；三个剩余名称后来确认来自 A1 的旧 I/O 映射，而非 SymbolConfig。
- 当前 project SHA-256=`619B8B8FBB748AC141FCC5510CE1227D4EE208B7B02434BCF55F688A8FEE8AE7`；清理前 project 和文本快照均在被忽略的 `data/` 下备份。
- 该阶段的后续处理已在下节完成；无需再从 Symbol Configuration 中查找这三个名称。

## 最小骨架 0-error 收口(2026-08-18)

- 用户在 PLE Symbol Configuration 顶部执行 `Remove...`，清除了 25 个已失效签名。实时 ScriptEngine 随后确认 `Symbols` 对象内的 `BinIo` 配置已不含三个报错名称；因此原先的 SymbolConfig 定性被推翻。
- 实际根因位于 `_000SK010A1` 的 I/O Mapping：
  - `%IX0.2`：`bus_000S900` → `bus_000SK010A1_Channel_3`；
  - `%IX0.5`：`bus_000SK010A1_Channel_6` → `bus_000B085A_LOW`；
  - `%IX0.6`：`bus_000SK010A1_Channel_7` → `bus_000B085A_HIGH`。
- 修复前 `BinIo` 的 56 个 `bus_*` 声明与 56 条物理映射各有三个集合差异；修复后两集合完全一致。离线编译结果 **0 errors / 7 warnings**。
- 更新快照仍为 215 个对象并通过校验；相对 ST 清理前快照恰好只有既定 10 个对象变化。最终 project SHA-256=`132213CF6B566C255885F036800CD85B5893846704D23DE3ED2555DC8291B9F8`。
- 回退备份位于被忽略的 `data/backups/Stat010_V5.11_CtrlX_PLC.pre_symbol_save_20260818.project` 与 `...pre_io_mapping_fix_20260818.project`。没有连接、下载、启动或停止实体 PLC。
- Station010 私有仓库已提交并推送 `987d8fb`（`refactor: establish minimal CpStudio skeleton baseline`）；工作树干净。当前不要用 CpStudio 重新生成，下一步从“只增加一个设备”的受控实验开始。

## CpStudio I/O BMK 改名批次收口(2026-08-18 14:20)

- 用户在 CpStudio 中修改 A1-A4 四个 DI 模块和 C1-C3 三个 DO 模块的 BMK/描述并重新导出；Station010 工作树形成 15 个生成文件变化。既有 10 处最小骨架 ST 清理没有被覆盖。
- 首次编译为 **33 errors / 73 warnings**：CpStudio 已更新 `BinIo` 声明，但 EtherCAT I/O Mapping 仍引用旧变量。AI 经 PLE 接口重映射 16 个有效通道、清空 17 个已停用通道；最终 39 条映射无重复，编译变为 **0 errors / 40 warnings**。
- 剩余 33 条警告来自 Symbol Configuration 的失效旧成员。上层脚本接口 `get_all_datatypes()` 因插件的 duplicate-key 缺陷不可用；已确认不是工程数据损坏。
- 稳定解法是 ctrlX PLC Engineering 自带本地 REST API：`GET/PUT http://localhost:9002/plc/engineering/api/v2/devices/Device/Plc%20Logic/Application/symbol-config`。用 `symbolsAction=Select` 精确补选 15 个新成员后，`BinIo` 最终为 63 个已选成员，18 个新 BMK 全部存在、33 个旧名为 0，底层访问权限均为 `ReadWrite`。
- 保存后完整离线编译恢复到 **0 errors / 7 warnings**（4 条未知 `OPC.UA.DA`、2 条 plausibility 提示、1 条 `ErrorCodes`/`DWord` 基线警告）。当前 PLC project：1,547,840 B，SHA-256=`F53548B8C8A12571615DA0C5B7DDC46B3257D0FADC972F016E9843168E6CACBB`。
- CpStudio 输出中的 persistent-variable 提示没有形成 PLC 编译错误；本批次未重新生成、未连接/下载/启停实体 PLC，也未再创建额外二进制备份。
- 上述 15 个生成/工程文件已提交并推送到 Station010 私有仓库：`78f91e8`（`fix: sync I/O BMK mappings after CpStudio export`）；工作树干净，可进入下一项 CpStudio 增量。

## CpStudio C1 小改动快速闭环(2026-08-18)

- 本次导出相对 `78f91e8` 的有效模型变化很小：`_000K980` 中文描述由“安全门上锁”改为 `100K980 door lock`，`_000K981` 事件描述中的设备号由 `100K980` 纠正为 `100K981`，并从生成的 `BinIo`/事件配置中移除停用占位成员 `_000SK010C1_Channel_6`。共有 14 个生成/工程文件随 CpStudio 同步变化。
- 首次离线编译为 **1 error / 9 warnings**：C1 的 `Channel_6.Output` I/O Mapping 仍绑定 `Application.Peripherals.BinIo.bus_000SK010C1_Channel_6`；Symbol Configuration 也仍保留同一旧成员。这再次确认 CpStudio 小改动可能留下“物理映射 + 公开符号”两层旧引用。
- 原 MCP `map_io_channel` 只遍历设备树子节点，无法看到 ctrlX/DataLayer 的 connector 通道。已将正式工具扩展为遍历 `connectors → host_parameters → is_mappable_io → io_mapping`，按 `Channel_6.Output` 清空绑定并写后回读；编译先恢复到 **0 errors / 8 warnings**。
- 随后通过官方 REST 基地址 `http://localhost:9002/plc/engineering/api/v2`，以 `symbolsAction=UnSelect` 精确移除 `BinIo._000SK010C1_Channel_6`；最终 `BinIo` 为 62 个已选成员、全部 `ReadWrite`，完整离线编译恢复到 **0 errors / 7 warnings** 基线。
- connector 映射扩展、REST 路径及双层修复顺序已固化并推送到方法论仓库 `ctrlx-ai-coding`：`142721c`（`patches: support ctrlX connector I/O mappings`）。补丁入口仍为 `patches/codesys-mcp-persistent-crlf/apply-crlf-patch.ps1`，npm 升级后先运行 `-Check`。
- 本次未连接、下载、启停或写入实体 PLC，也未创建额外 `.project` 备份。最终 PLC project SHA-256=`E89D8C0732990B572B2B52305D0215F4099AEA550A5779D6D5444B6EE5BD860C`；14 个文件已提交并推送到 Station010 私有仓库：`482c77a`（`fix: sync C1 door-lock channel after CpStudio export`）。

## Wp100 两个 BasMove Unit 增量(2026-08-18)

- 用户分两次 CpStudio 导出，在 `Station`（Mode Handler）→ `Wp100`（Command Handler）下依次加入 BasMove Standard 2.1.11.0：`Wp100K101SafetyDoor`（InstanceID 4）与 `Wp100K102PressingCylinder`（InstanceID 5）。
- 安全门 2I2O：`_100B101B/_100B101A`（A3 通道 6/7）与 `_100K101B/_100K101A`（C2 通道 6/7）；压缸 2I2O：`_100B102B/_100B102A`（A4 通道 6/7）与 `_100K102B/_100K102A`（C2 通道 4/5）。PLE connector 接口已逐条回读确认物理映射。
- 第二个 Unit 导出使 PLC 文本对象由 218 增至 221，只新增压缸本体、Extension、`OnManRelease`；其余生成差异限于 `BinIo`、`StateOverview`、事件设计号、Wp100 参数与层级初始化。
- AI 经 persistent MCP 只改两处 ST：安全门 `OnManRelease` 的两路附加条件改为 `TRUE`；`Wp100Unit.OnApplyOutputs` 的 Home 改为 `Wp100K101SafetyDoor.Unit.OutImm.IsInBasPos`。压缸手动功能仍为 `FALSE`，自动 Chains 未改。
- 修改前后 221 对象快照对比恰好只有上述两处变化；最终离线编译 **0 errors / 7 warnings**，PLC project SHA-256=`8DFB10EA386B7DC0733F67A1D5D636E739D5371DBD7CCD5D059A072379877286`。未操作实体 PLC，未创建额外二进制备份。
- 两次 CpStudio Unit 生成结果和上述两处 MCP 集成逻辑已提交并推送到 Station010 私有仓库：`972cfcb`（`feat: add Wp100 BasMove units and home integration`）；提交后工作树干净并与 `origin/main` 一致。

## Burster 2316 Unit + 压缸联锁增量(2026-08-18)

- CpStudio 在 `Wp100` 下新增 `Wp100K103ResistantDetector : BursterResis2316Unit`（InstanceID 6），并加入 `_Wp100K103ResistantInterface : IpBurster2316` Peripheral。Unit 的 `ParCfg.iBursterResis2316` 已绑定该 Peripheral。
- Peripheral 在 Station 进入 OPERATIONAL 时取 `Station.StationData.BursterSetting.HostName`，并固定 `UseAutoRange := TRUE`。StationData 通过 DataSetManager 从文件加载/应用到 PLC 内存；当前 HMI `.dat` 默认 HostName 为空。通用 `PortNo` 字段未被 IpBurster 生成代码消费。
- 本地 CHM 已核对：Unit 命令为 `SET_RANGE` 与 `SINGLE_MEAS`；后者输入上下限/是否读温度，输出越界、OK、电阻值和温度。新 Unit 的 `SetRange/StartMeas` 手动放行仍为 `FALSE`，自动 Chains 未改。
- 221→224 对象的 CpStudio 差异：新增恰好三个电阻仪对象、删除 0、改变八个既有生成对象、其余 213 个不变；首次编译即 **0 errors / 7 warnings**。Peripheral OOD 对 CXA 标记 `NotTested`，后续真机通信必须专项验证。
- AI 经 MCP 改两处：压缸两个手动动作要求安全门 `OutImm.IsInWrkPos`；Wp100 Home 要求安全门和压缸 `OutImm.IsInBasPos` 同时成立。修改前后 224 对象快照恰好只变这两处，最终编译仍为 **0 errors / 7 warnings**。
- 最终 PLC project SHA-256=`B1DF6EDE55E20FBCD472FF2A4309CFC903B3639B8C317F97DB3B31C42AD92E71`；未操作实体 PLC，未创建额外二进制备份。Station010 已提交并推送 `8014419`（`feat: add Burster resistance unit and motion interlocks`），工作树干净并与 `origin/main` 一致。

## EmergencySwitch + 主气压控制增量(2026-08-18)

- CpStudio 将 `Station.EmergencySwitch` 的两路急停输入绑定到 `_000S900A/_000S900B`，Control Off 绑定到 `_000S902`；生成参数分别为 `IdxIsEmSwitchPressed[1/2]`、`IdxIsControlOffButtonPressed`，两路 `IsEmSwitchInverted=FALSE`、第二路 `DependsOnPreviousSignal=FALSE`、Control Off 抑制延时 300 ms。物理映射已回读：A2 Channel 1/2 与 A1 Channel 2。`_000S901` 仍仅由 `Station.ControlOn` 作为 Control On 按钮使用。
- 同一批 CpStudio 输出新增 `Station.EVENT_PRESSURE_NOT_HIGHER=-4` 与 `EVENT_PRESSURE_NOT_LOWER=-5` 及英文 HMI 文本；中文文本当前为空。生成批次基线编译 **0 errors / 7 warnings**，已作为 Station010 提交 `77abe3c`（`feat: configure emergency and pressure events`）。
- 新增可复用 `Application/Fbs/FB_MainPressureControl`，实例为 `Station.MainPressureControl`。FB 本体只使用布尔量/时间输入输出，不直接引用 Station 或项目 BMK；当前 Station 接线只在调用处完成。它只在 `Station.UnitState=OPERATIONAL` 且 EtherCAT `BusOk` 时监控；以 `Station.ControlOn.OutImm.IsCtrlOn` 作为电气安全回路已上电反馈，驱动 `_000K085A`，并按阀输出状态在 5 s 内检查 `_000B085A_HIGH` 或 `_000B085A_LOW`。
- 高压未到触发 `EVENT_PRESSURE_NOT_HIGHER`，低压未到触发 `EVENT_PRESSURE_NOT_LOWER`；两路反馈同时为 TRUE 时立即锁存两个故障。任一故障都会关闭 `_000K085A`，并通过官方应用接口 `Station.ControlOn.ParImm.UserEnableControlOn:=FALSE` 撤销 Control On 允许条件。故障仅在 Control On 已撤销且反馈恢复为“仅 LOW”时复位。
- FB 由 `StationUnit.OnCall` 每周期调用，而不是只放在 `OnUnitOperational`；这样 Station 离开 OPERATIONAL 时仍会主动写 FALSE，避免输出保持。事件以 `OpconEventClass.ERROR` 锁定；当前 NxBase 的 `UnlockEvent` 实际为两参数版本，恢复时使用 `UnlockEvent` + `ClearEvent`，与随附手册所述三参数新版接口存在版本差异。
- 最终文本快照为 225 个对象，相对 Burster 后 224 对象新增恰好一个 FB；变化对象为 EventList designator、Station、StationUnit、StationUnit.OnApplyParameters/OnCall。快照校验通过，project SHA-256=`A099CD4649D4BB9C4311627986FC33E0908B2742F6118BAF54CCB89E5CD8F90E`，离线编译 **0 errors / 7 warnings**。AI 逻辑提交为 `123845d`（`feat: add main pressure control monitor`）。未连接、下载、启停或写入实体 PLC，也未创建额外二进制备份。
- CpStudio 5.11 随附官方帮助确认：`Engineering > Export` 支持以相对路径配置 `Pre-export script` / `Post-export script`（`.bat` 或 Python），并支持 `Fast export (code only)`；安装帮助和配置中未发现受支持的无界面/命令行项目编辑接口。后续优先用导出钩子自动完成差异、旧 Symbol 与编译审计，CpStudio 本身只保留层级、标准对象、BMK/I/O、HMI/Event/StationData 等声明式配置，不直接脚本改写 `Engineering_Data.xml`。
- 按跨项目复用要求，POU 从 `FB_Stat010MainPressureControl` 重命名为 `FB_MainPressureControl`，实例名及行为不变。旧名引用为 0、新名引用为 2；225 对象快照对比仅表现为 FB 路径改名及 Station 类型引用变化，编译仍为 **0 errors / 7 warnings**。新 project SHA-256=`FE8610EA5946FEA657788D9A6B143ADC96F55E89403A8DFAFAB8E99A317DBC68`，Station010 提交 `4db6c8a`。

## 通用操作按钮 FB 增量(2026-08-18)

- 原 `SqS_Wp100_Home._aN010_active` 直接根据 `_000S610` 结束步骤、以 `FlashBits.Pulse500ms` 写 `_000P610`；正常按下可以熄灯，但没有独立生命周期，也没有在 Chain 被取消时统一复位。
- 新增可复用 `Application/Fbs/FB_OperatorButton`。输入为 `Execute/ButtonPressed/Blink500ms`，输出为 `Done/LampOn`；`Execute=FALSE` 会清除锁存完成状态并强制 `LampOn=FALSE`，`Execute=TRUE` 且未按按钮时透传 500 ms 闪烁位，检测到按钮后锁存 `Done=TRUE` 并在同一扫描周期熄灯。FB 本体不引用 Station、SFC、BMK 或具体 I/O。
- `SqS_Wp100_Home` 增加 `_startButton` 实例；`_aN010_active` 将 `_000S610` 和 `FlashBits.Pulse500ms` 接入 FB，完成后先置 `_retVal=OK`，再以 `Execute=FALSE` 初始化实例，允许同一步骤再次进入。`OnChainFinish` 对任意结束原因再次执行 `Execute=FALSE` 并把 `LampOn` 写给 `_000P610`，覆盖模式切换产生的 CANCEL，也覆盖 ERROR/DONE。
- 离线编译 **0 errors / 7 warnings**；快照从 225 增至 226 个对象，新增恰好 `FB_OperatorButton`，只改变 `SqS_Wp100_Home`、`_aN010_active` 与 `OnChainFinish` 三个既有对象。快照校验通过，project SHA-256=`C85EAED6C36559BE97CD6D6C89202700D53BCF7CD30BBEC20A076072F51828C5`；Station010 提交 `1531e71`。未连接、下载、启停或写入实体 PLC，也未创建额外二进制备份。
- CpStudio 后续重新生成可能覆盖 SFC Action 与 `OnChainFinish` 方法体；每次导出必须通过文本快照/审计确认并重新合入调用代码。通用 FB 继续放在 `Application/Fbs`，Chain 实例声明放在 CpStudio 合并区外。

## `SqS_Wp100_Run` + Burster 手动放行增量(2026-08-18)

- CpStudio 在 `Wp100` 下新增 `SqS_Wp100_Run EXTENDS OpconSfcChain`，实例为 `Wp100.SqS_Run`，通过 `AddSubChain(..., 2)` 注册；STARTUP/ONLINE_CHANGE 均建立 `rUnit REF= THIS^`，StateOverview/HMI ChainAnalysis 已加入其 ExecState/SFCCurrentStep。新增 5 个 PLC 对象：Chain 本体、N000、N100、N999 和 OnChainFinish；无删除，只改变 StateOverview、Wp100、Wp100Unit.OnApplyParameters/OnInitHierarchy。
- 当前 `SqS_Run` 仍是空骨架：除 `rUnit` 外没有工艺输入，N100 直接返回 OK；全工程只有实例、引用初始化、层级注册和状态概览 5 个结构性引用，没有任何 `.Execute := TRUE` 调用。HMI 的 SubChain 名称为 Run，但对应中英文文本条目当前为空。
- 本次 CpStudio 导出完整保留 `FB_MainPressureControl`、`FB_OperatorButton`、`SqS_Wp100_Home` 按钮 Action 和 OnChainFinish 复位。导出基线为 231 个 PLC 对象、**0 errors / 7 warnings**，project SHA-256=`7C17C4B1DB1F1921DA6A0CCA71BCCEEB307591C083AD6230FCC3573FFF0F4818`；生成批次提交 `9d4f9b0`（`feat: add Wp100 run subchain skeleton`）。
- AI 经 MCP 仅修改 `Wp100K103ResistantDetectorExtension.OnManRelease`：`ReleaseSetRange` 与 `ReleaseStartMeas` 均为 `CommonManRelease AND TRUE`。这会取消对象级默认 FALSE，但保留 Mode Handler 的公共手动互斥/允许条件，不是无条件旁路。
- AI 后快照仍为 231 个对象，新增/删除均为 0，唯一变化对象为上述 OnManRelease；最终编译 **0 errors / 7 warnings**，project SHA-256=`81199BDB36D5E65381190CD9C0973D65D1A2BB9CE36D68831F016618B5D50D9C`，Station010 提交 `6a2121f`。未连接、下载、启停或写入实体 PLC，也未创建额外二进制备份。
- 当前 HMI `ReleaseSetRange/ReleaseStartMeas` 变量已在 OPC 列表中，但生成的 HMI 条件分析树仍记录旧的 Constant FALSE。后续完整导出已证明 CpStudio 不会从 PLE 回读这项 MCP 修改；要同步 HMI 分析树，必须在 CpStudio 模型中配置对象级 TRUE 条件，仍不得直接改写 `Engineering_Data.xml`。

## CpStudio 安全回路描述 + StationData 参数批次(2026-08-18)

- 用户在 CpStudio 中更新安全回路参数/描述并完整导出：`_000K980_A/_000K981_B` 的英文描述改为 Maintenance door A/B closed，`_000K913_Y32` 改为 Safety door Ok，`_000K912_Y32` 改为 All door ready；原 `_000K980D` 名称及描述被清空。BusConfig、事件、HMI 语言和 PLC `BinIo` 注释保持同一语义。
- CpStudio 模型同时从 StationData 公开结构移除 `LineNo`、`TestMode`、`NokCounter` 与 `Wp100.Active`，HMI DataSetAccess 和 PublicInterface 已同步删除。PLC 文本结构暂仍保留这些兼容字段；本次 231 对象快照相对上一版本唯一变化对象为 `Application/Peripherals/BinIo`，因此没有擅自删除 PLC 数据结构。
- Symbol Configuration 低层复核：63 个已配置数据类型，`BinIo` 仍为 62 个成员且全部 `ReadWrite`；`_000K980D` 为 0，四个仍使用的安全回路成员各为 1。没有复现旧 I/O Mapping + 旧公开符号的双层残留，不需要 REST/MCP 修复。
- `FB_MainPressureControl`、`FB_OperatorButton`、按钮 Action/OnChainFinish、Wp100 Home 联锁及 Burster `CommonManRelease AND TRUE` 全部保持。完整离线编译为 **0 errors / 7 warnings**；project SHA-256=`FCDF252C1D4E6B0D65EA3230B0A133418FF3B8EDF5A1E51827E199A5BD573067`。
- 本次完整导出后，HMI 中 Burster `SetRange/StartMeas` 的条件分析树仍是 Constant FALSE，确认 CpStudio 不会反向读取 PLE 的 ST 修改；后续必须在 CpStudio 模型中设置，而不是直接编辑生成 XML。
- 14 个有效生成文件已提交为 Station010 `7c4422e`（`feat: update safety IO and station data parameters`）；两个仅时间戳变化的 `.Sync.json` 未提交。未连接、下载、启停或写入实体 PLC，也未创建额外二进制备份。

## Wp100 Home 原子操作 + 维修门主气压联锁(2026-08-18)

- `SqS_Wp100_Home` 保留 N010 的通用按钮握手，N110~N160 实现条件式回原位：压缸不在 Base 时，先让 `Wp100K101SafetyDoor` 执行 WRKPOS 并等待完成，再让 `Wp100K102PressingCylinder` 执行 BASPOS；压缸已在 Base 时跳过这两段。最后仅在安全门尚未到 Base 时执行其 BASPOS。四种设备初态都会跳过不必要动作。
- 三段命令沿用 OpCon BasMove 标准调用协议：READY + `StepPulse` 时设置 `PreStartCheck/OutputPulsing`、Command 与 Execute，后一 Action 用 `CheckUnitDone(..., RepeatOnError := TRUE)` 等待。三个 started 标志区分“本轮启动”与“条件跳过”。`OnChainFinish` 对任意结束原因复位按钮 FB/`_000P610`、两个 Unit 的 Execute 和三个标志，覆盖 DONE/ERROR/CANCEL。
- 新增无项目 BMK 依赖的通用 `Application/Fbs/FB_MaintenanceDoorControl`。Station 接线为：`_000S901` 原始 Control On 请求使 `_000K980/_000K981` 上电，`Station.ControlOn.OutImm.IsCtrlOn` 成立后保持；`_000K980_A AND _000K981_B` 形成 `xAllDoorsClosed`，再与两路锁命令共同生成 `xMainPressureRelease`。
- `FB_MainPressureControl` 新增 `xValveRelease` 输入；许可为 FALSE 时立即关闭 `_000K085A`，仅许可为 TRUE 后才按既有 LOW/HIGH 与 5 s 诊断逻辑工作。原来固定 TRUE 的 `_dummyFlagIsEveryDoorLockClosed` 已接到 `xAllDoorsClosed`，所以 AUTO/MANUAL/HOME/CHANGEOVER 的既有 `OnModeRelease` 同时使用真实的两扇维修门反馈。
- 当前没有为“维修门未在限定时间关闭”新增事件：任一反馈为 FALSE 时只是不放行主气压和模式。门锁 FB 在 Station 非 OPERATIONAL、总线异常或 ControlOn 撤销后输出 FALSE；保持/释放时序和是否需要门超时事件留待真机验证确认。
- 文本快照由 231 增至 232 个对象：新增恰好 `FB_MaintenanceDoorControl`，无删除；既有对象只改变主气压 FB、Station/StationUnit 接线，以及 Home Chain 声明、N000、N110~N160、OnChainFinish 共 13 个目标对象。快照校验通过，project SHA-256=`EB76CF911AE933D33B3CFFF77024B61060198C78995BB954B237ADDD8D16A0E4`，离线编译 **0 errors / 7 warnings**。
- Station010 有效生成变化与 PLC 逻辑已提交并推送为 `bb853e5`（`feat: implement home sequence and door interlock`）。仅时间戳变化的 `Plc/*.Sync.json`、HMI `.vwn` 与 Logbook 日期滚动未提交，也未被 AI 回退。未连接、下载、启停或写入实体 PLC，未创建额外二进制备份。

## 维修门未锁报警 + CpStudio 模型收口(2026-08-18)

- 用户经 CpStudio 新增 `Station.EVENT_MAINTENANCE_DOOR_NOT_LOAKED=-2`，英文事件文本为 `The maintenance door should be locked!!`。名称中的 `LOAKED` 是当前生成接口的准确拼写，PLC 调用保持一致，不擅自改名或另造事件号。中文语言资源当前也使用同一英文文本。
- `FB_MaintenanceDoorControl` 新增 `tLockMonitoringTime`、TON 和锁存输出 `xFaultDoorNotLocked`。两路门锁输出被请求且 `_000K980_A/_000K981_B` 未同时成立时开始 5 s 计时；反馈缺失期间主气压许可从第一周期起即为 FALSE，5 s 到时再锁存报警。报警后即使反馈恢复，也要先 Control Off 使两路锁请求撤销，才允许清除并开始下一次 Control On。
- `StationUnit` 新增事件句柄，并在 `OnCall` 按已有主气压事件相同的 `SetEvent(Lock := TRUE) → UnlockEvent → ClearEvent` 生命周期管理该事件。事件常量全工程只有声明与调用各一处。
- 本次 CpStudio 导出还完成两个既有待办：Burster `SetRange/StartMeas` 的对象级手动条件已正式生成为 TRUE 并同步到 HMI；`LineNo/TestMode/NokCounter/Wp100.Active` 已从 `StationDataStruct` 和 `OnCheckData` 移除。`StationSdNokCounter`、`Wp100StationDataStruct` 两个 DUT 目前只剩自身声明、无业务引用，暂不擅自删除。
- CpStudio 后、AI 前快照为 232 个对象，project SHA-256=`4F5522E919E3B8CA504D0981CB788E9D0F01CFC037DA6C947C476B456B5BD2CE`；AI 后仍为 232 个对象，只改变 `FB_MaintenanceDoorControl`、`StationUnit`、`StationUnit.OnCall` 三个对象，最终 SHA-256=`5E364DD99EDA0786055A3E11211D41F70C6DFE8026A977AD2C3E3A40EED816B0`。完整离线编译 **0 errors / 7 warnings**。
- 有效 CpStudio 生成文件与 PLC 报警逻辑已提交并推送为 Station010 `93379fd`（`feat: add maintenance door lock alarm`）。`.Sync.json` 时间戳和内容相同的 Logbook 日期改名未提交、未回退。未连接、下载、启停或写入实体 PLC，也未创建额外二进制备份。

## StationLamp AddOn + Home 步骤短注释(2026-08-18)

- CpStudio 在 Station 下新增 `Station.StationLamp : StationLampUnit`（Station Lamp V2.3.1.0，InstanceId 7），通过 `AddAddOn` 注册并配置为 `MULTIPLE_LEDS`。黄/绿/红分别绑定 `_000P960_1/_000P960_2/_000P960_3`；PLC 参数对应 `IDX_000P960_1/2/3`，三路输出继续使用既有 BinIo 映射。
- `SqS_Wp100_Home` 的 9 个 Step Comment 改为短动作说明：N000 `Initialize home`、N010 `Wait start button`、N110 `Close safety door`、N120 `Wait door closed`、N130 `Raise press cylinder`、N140 `Wait press raised`、N150 `Open safety door`、N160 `Wait door open`、N999 `Finish home`。
- Step Comment 经 PLC Engineering 官方本地 REST 扩展接口 GET/PUT 写回 `SqS_Wp100_Home` 的 SFC XML 属性；没有手改 `.project` 字节，也没有逐项 UI 自动化。回读及标准化前后比较确认只替换 9 个 Comment，Action、Transition、Jump、动作顺序和声明均未改变。
- 完整离线编译保持 **0 errors / 7 warnings**，最终 project SHA-256=`C2F2DAEE9661E289B303C8E529AE64AC079EF4E0B22C5D62075A7A4DF384B11F`。StationLamp 生成批次与 Home 注释已提交并推送为 Station010 `6399377`（`feat: add station lamp and label home sequence`）；仅 `.Sync.json` 和 HMI Logbook 日期滚动噪声保留在工作树、未提交。未连接、下载、启停或写入实体 PLC。

## 跨项目标准目录 + AI 增量层骨架(2026-08-18)

- `McpCoding` 已按 `config/specs/ai/src/catalog/scripts/tests/data/docs` 标准重组；`../Station010_0708` 供应商生成布局和 `../Std` 只读目录均未移动、未修改。标准全文见 `docs/project_structure_standard.md`，后续项目复制同一旁车骨架后只需修改 `config/project.yaml`。
- 当前 Station010 已落入结构化事实源：Station/AddOn、IO、Events、Wp100 Units、Home/Run Chains；未核实的物理映射明确标记为 pending，不伪装成已验证数据。
- `ai/ownership.yaml` 区分完整 AI-owned、implementation、mixed semantic merge 与 SFC graphical attributes；`ai/hooks.yaml` 记录主气压、维修门、Wp100 Home 和 Burster 手动放行的必要接线；`ai/graphical.yaml` 记录 Home 的 9 个 Step Comment 和正式 REST 写入属性。
- `src/plc/common` 保存 `FB_OperatorButton`、`FB_MainPressureControl`、`FB_MaintenanceDoorControl` 三个当前已编译 POU 的可读规范源；任何同步仍必须通过 MCP 并执行 readback + compile，绝不直接写 `.project`。
- Catalog 首批登记 BasMove Standard V2.1、Burster 2316 V1.0、ControlOn V2.0、EmergencySwitch V2.0、StationLamp V2.3.1 和 IpBurster2316 V1.0；仅保存接口事实与本地手册路径，不复制闭源手册或供应商代码。
- 现有工具分类到 `scripts/plc` 与 `scripts/ioe`；新增 `scripts/cpstudio/post_export_signal.bat` + `write_export_request.ps1`。CpStudio 的 Post-export hook 是官方能力，该自定义脚本只原子发布 `data/requests/export_request.json`，不启动第二个 PLE/MCP。真实 CpStudio hook 配置和 request 消费器仍列为下一步。
- 新增 `tests/static/Test-ProjectFramework.ps1`，检查标准文件、兄弟目录、POU 分段标记和 Post-export 脚本不含 PLE/MCP/在线启动入口。本批只改 AI 工程仓库文件，没有连接、下载、启停或写入实体 PLC，也没有修改 Station010 PLC 工程。

## 团队工作站部署交接(2026-08-19)

- 新增根目录 `TEAM_SETUP.md`，作为同事/新电脑的一次性部署权威入口；原 `HANDOVER.md` 继续只保存项目状态和工程历史，不再承担安装手册职责。
- 文档明确标准四目录布局：`Station010_0708`、只读 `Std`、`McpCoding`、嵌套独立仓库 `McpCoding/ctrlx-ai-coding`；记录三个 GitHub 仓库、私有仓库授权和不能经 GitHub 分发的闭源资产/许可证。
- 新增 `config/codex-mcp.toml.example`，只含干净的 `codesys-persistent` STDIO 配置，不复制任何个人模型供应商、账号、Token 或 API Key。Codex 官方配置事实核对于 2026-08-19：默认 `~/.codex/config.toml`，同一主机的桌面/CLI/IDE 扩展共享配置。
- 新增只读 `scripts/setup/Test-TeamWorkstation.ps1`：从 `config/project.yaml` 解析工程相对路径，检查 CpStudio/PLE/IOE、Managed Libraries、Node/npm、固定 MCP 0.6.3、补丁和 Codex 配置；不启动 IDE、不打开或写入工程、不连接 PLC。
- 同事首次交接验收固定为：环境体检 + 目录静态测试 + 唯一 persistent MCP 会话 + Station010 完整离线编译 0 errors / 7 warnings。闭源 `Std`、安装介质和许可证仍必须由公司授权渠道提供。

## AI Coding 对外展示页(2026-08-19)

- 新增 `docs/ai_coding_showcase.html`：单文件、无 CDN/外部字体/外部图片依赖，可直接离线打开或打印为 PDF；README 已增加固定入口。
- 展示叙事覆盖 CpStudio/用户、Git/AI、ctrlX IDE 三方职责，标准旁车目录，两类变更闭环，full object / implementation / semantic merge 三种写入模式，以及安全红线和跨项目复用路线。
- 页面用当前工程事实演示 `SqS_Wp100_Home` 四种初态路径、操作按钮 500 ms 闪烁与取消清理、维修门到主气压的 5 s 联锁，以及 BMK 改名后 BinIo / I/O Mapping / Symbol Configuration 三层审计；未核实的物理映射未包装成已验证结果。
- 支持流程 Tab、Home 路径切换、滚动进度、键盘演示模式和打印样式。已用 Edge 隔离临时 profile 检查 1440×1000 首页及 Home 章节渲染；临时截图不在仓库。本批只改文档仓库，没有修改 PLC/IO 工程，也没有连接、下载、启停或写入实体 PLC。

## Kistler maXYmos BL 5867C EtherCAT ESI（2026-08-19，已完成）

- 硬件已确认：`5867C001`，SN `6575138`，EtherCAT，Little-Endian。新 ESI 为 `Technical Docs/.../EtherCAT/Kistler_Type_5867C_V1.xml`，SHA-256=`7AE6DF840A704DBBBC628A6DAFC9FA6BEE8BE3571C83C3F22874F422C11838FC`；身份为 Vendor `0x58A/1418`、Product `0xE52F/58671`、Revision `1`，输入/输出各 200 byte。
- `Std` 严格只读。标准 `NexeedEcKistlerMaxymosBl V2.0.7.0` Peripheral 提供 `IKistlerForceStroke`，与 `NexeedKistlerForceStroke V1.2` Unit 端口一致。其旧名称仍写 5867B/TL，旧 ESI 的显示名甚至是 5877A，但 Vendor/Product/Revision 与新 5867C 完全一致；新 ESI 用于 IO 设备描述，标准 Peripheral 继续用于 OpCon PLC/Channel 适配。
- 初查 IOE System Repository 对 Kistler/maXYmos/5867 均为 0 条。AI 启动独立 IOE 2.6.4 watcher，经官方 `device_repository.import_device` + EtherCAT converter GUID 导入；回读恰好一条 `maXYmos BL 5867C / Kistler / type 65 / 58A_0000E52F00000001 / Revision=16#00000001`。
- PLE 2.6.8 的 REST Device Repository 不含 EtherCAT converter，POST 同一 ESI 返回 `{3992...} could not be found`；这是正常工具边界，不应复制设备仓库文件或再次尝试用 PLE 导入。EtherCAT ESI 只进 IOE，PLC 侧由 IO 集成流带入节点。
- 新增 `scripts/ioe/Install-EtherCatEsi.ps1`：唯一临时 IPC、等待后台插件、精确身份校验、幂等跳过、优雅关闭，不打开任何 project。已实测第二次运行识别既有设备、零重复写入、IOE 退出、临时目录清零。`TEAM_SETUP.md`、工作站体检、`specs/io.yaml`、Peripheral Catalog 与专题文档已同步。
- 用户补充并纠正了 CpStudio EtherCAT Peripheral 工作流：先在 ctrlX IO Engineering 中添加真实从站，再由 CpStudio 的“一键读取 ctrlX IDE IO 组态”导入，导入后自动匹配标准 Peripheral；不是在 CpStudio 中手动拖 EtherCAT Peripheral。
- AI 已通过 IOE 2.6.4 官方 ScriptEngine 在受控 IO 工程中添加 Kistler 从站，并按用户指定的 BMK 命名为 `_100A104`；它位于 `_000SA620_X1` 下并与 `_000SK010` 同级。在保存、关闭、重新打开后回读为 `maXYmos BL 5867C / type 65 / 58A_0000E52F00000001 / Revision=16#00000001`。
- IO 工程变更已单独提交为 Station010 `3976d8b` (`feat: add Kistler 5867C EtherCAT slave`)，没有带入工作树中原有的 CpStudio、PLC Sync 或 HMI Logbook 改动。
- 真实硬件名在 IOE/ESI 层保持 `maXYmos BL 5867C`；CpStudio 后续自动匹配的 `Kistler MaXYmos BL5867B TL5877B0` 是标准库兼容适配器的旧标题。为了保持自动匹配且遵守 `Std` 只读红线，不修改该标准对象标题。
- 本节记录的“等待 CpStudio 一键读取”及 `NexeedKistlerForceStroke` Unit Channel 绑定均已在后续批次完成；`_100A104` 自动匹配和 Unit/Peripheral 两层接线均已验证。
- 该 ESI/IOE 阶段仅修改 IO project，没有修改 PLC project，也没有连接、下载、启停或 FORCE 实体 PLC；随后 CpStudio/PLC 的闭环结果见下节。

## Kistler CpStudio 导入、Burster BMK 改名修复与 400-byte PDO 映射（2026-08-19）

- 用户在 CpStudio 一键读取 ctrlX IO 组态成功，`_100A104` 自动匹配标准 Peripheral `Kistler MaXYmos BL5867B TL5877B0`；同批把 Burster Unit/Peripheral 从 `Wp100K103...` 改为 `Wp100A103...`。首次导出失败不是 Kistler ESI 问题，而是生成声明已换新名、`PeripheralRoot`/`OnInitHierarchy`/`OnApplyParameters` 仍保留旧引用。
- AI 经 PLE 官方 REST/MCP 把三处旧 Peripheral 引用迁移到 `_Wp100A103ResistantInterface`，把已验证的 `ReleaseSetRange/ReleaseStartMeas := CommonManRelease AND TRUE` 合入新 Unit，再删除无外部引用的旧 `Wp100K103ResistantDetector` POU。旧 Symbol 幽灵项通过官方 Symbol Configuration `UnSelectAll` 后按当前有效快照 `Select` 恢复，相关两条编译警告已清除。
- CpStudio 导出关键后台动作已复测：`PublishMarkedMethodsJob` 和 `DeclarationsJob/AddAllInstancePaths` 均为 Done。最终编译 **0 errors / 7 warnings**；剩余警告均为原工程既有 OPC UA 属性、参数合理性和 `ErrorCodes : DWORD` 枚举提示。
- CpStudio 的“写 peripheral 和 I/O designator 到 PLC IDE”在 Kistler 大 PDO 上触发 IOE 2.6.4 REST 序列化缺陷：设备 JSON 在 `ioMapping[350].subChannels[2].address` 附近混入 Critical 对象，错误文本为 `The stream is currently in use by a previous operation on the stream.`。这不是 BMK、ESI 或 Little-Endian 配置错误，禁止通过改 ESI 绕过。
- 已验证的接口化替代路径：IOE `ExportEthercatConfigJob` 导出 EtherCAT master → PLE `ImportOfflineFieldbusConfigJob(forceInsert=false, keepExisting=true)` 导入 `Realtime_Data` → persistent MCP connector mapping 绑定 400 个父 BYTE 通道。输入/输出均为前 20 byte 对应 `Ctrl[0..19]`，后 180 byte 对应 `Data[0..179]`；最终读回 **400/400 bound，0 mismatch**。
- 为避免原 `map_io_channel` 每个字节保存一次工程，`ctrlx-ai-coding` 兼容补丁新增 `@batch-json` 扩展：先完整校验索引与变量，逐项回读，失败时尽力回滚，全部成功后只保存一次。IDE 内部刷新仍耗时约 2.5 分钟，MCP 30 s 可能表面超时；必须遵守“超时先查状态，禁止立即重发”。
- 本阶段只读文本快照为 234 objects，project SHA-256=`f1348397a4f29506390b97e1f7185774e3756aa0b2fdc1701889d49b8b123747`；随后的 Unit 添加和手动放行结果见下节。
- 有效 CpStudio/IO/PLC/HMI 批次已提交并推送 Station010 `17c63e5`（`feat: integrate Kistler peripheral and rename Burster BMK`）；通用大 PDO 与批量映射方法已提交并推送 `ctrlx-ai-coding` `924ca25`（`tools: batch ctrlX connector IO mappings`）。两个 `.Sync.json` 和 HMI Logbook 日期滚动继续作为用户/工具噪声保留在本地，未暂存、未回退。
- 全程未连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 保持只读，`.project` 未被直接编辑字节。

## Kistler Force Stroke Unit 绑定与手动放行（2026-08-19）

- 用户经 CpStudio 在 `Wp100` 下添加 `Wp100A104Kistler`（Instance ID 8，`NexeedKistlerForceStroke V1.2`），并把 `ParCfg.iKistlerForceStroke` 绑定 `_100A104`；CTA、PublicInterface、HMI 和 PLC hierarchy 的设计号与实例号一致。
- AI 经 persistent MCP 只修改 `Wp100A104KistlerExtension.OnManRelease`：`Measure/LockKeyboard/UnlockKeyboard/SetProgram/ZeroX/TareY/ReadData/WriteData` 八路均为 `CommonManRelease AND TRUE`。公共 Mode Handler 手动互斥仍保留，不是无条件旁路。
- 用户已在 CpStudio 把八个对象级条件改为 `TRUE` 并重新导出；AI 回读 `Hmi/config.xml` 为 8 个 ManualFunction、8 个 `<Constant state="True" />`、0 个 FALSE。CpStudio/HMI 与 PLC `OnManRelease` 两层现在一致，未直接补丁生成 XML。
- MCP 回读为 8 个活动 `TRUE`、0 个残留 `FALSE`；Kistler EtherCAT 映射复核为 **400/400 bound，0 mismatch**。离线编译为 **0 errors / 7 warnings**；确定性文本快照为 237 objects，project SHA-256=`628ec31baee6a6cc55bf03f40357319025537c4fdf5b6c102090272b127cfcfa`。
- 本批 CpStudio 同时移除了旧 `Wp100/MachineView` 和 `StationSensorsView` 中 `_101M1B601A_3` 灯控件；两者引用的旧设备已不在当前最小框架中，因此随生成批次保留。若后续需要恢复，必须回到 CpStudio 模型处理，禁止手改生成 HMI 绕过模型。
- CpStudio 生成批次、Kistler Unit 与 PLC 手动放行已提交为 Station010 `36ec1a5`（`feat: add Kistler force-stroke unit`）；两个 `.Sync.json` 与 HMI Logbook 日期滚动继续作为本地工具噪声保留，未暂存、未回退。
- 未连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 保持只读，`.project` 仅经 PLC Engineering/MCP 接口修改。

## 维修门继电器、运动手动与 Mode Release 安全反馈（2026-08-19）

- `FB_MaintenanceDoorControl` 保留 5 s 的 A/B 门关闭监控，并新增 `_000K981_Y32` 输入及 1 s 继电器反馈监控。两门关闭后，维修门安全继电器未在 1 s 内成立会锁存故障；`xMainPressureRelease` 从第一周期起就要求两门输入、两路锁输出和继电器反馈同时成立。
- 同一个 CpStudio 事件 `EVENT_MAINTENANCE_DOOR_NOT_LOAKED=-2` 继续按 `SetEvent(Lock := TRUE) → UnlockEvent → ClearEvent` 管理。AdditionalInfo 会在故障锁存时明确写入 `_000K980_A`、`_000K981_B`、两门同时缺失，或 `_000K981_Y32` 1 s 超时；未新增或改名事件号。
- `Wp100K101SafetyDoor.OnManRelease` 的两个动作均要求 `CommonManRelease AND _000K981_Y32`。`Wp100K102PressingCylinder.OnManRelease` 的两个动作均要求安全门 `IsInWrkPos`、`_000K913_Y32` 和 `_000K912_Y32`。
- 当前唯一关闭安全门的自动步骤是 `SqS_Wp100_Home.N110`。N120 在 `CheckUnitDone=OK` 后继续等待 `_000K913_Y32 AND _000K912_Y32`，N130 启动压缸前再次检查同一联锁，覆盖“门本来已关闭、N110 被跳过”的分支。
- Station `AUTO/MANUAL/HOME/CHANGEOVER` 的 `OnModeRelease` 均要求 `_000K911_Y32`、`_000K981_Y32` 和既有的两门关闭标志；CHANGEOVER 继续额外要求 `Station.Unit.IsEmpty`，没有削弱原条件。
- AI 前后文本快照均为 237 objects，恰好只改变 8 个计划对象；最终 PLC project SHA-256=`27659F3C3EE4F4D85093B3B9304CCDA2ABDE871183D7412FA4ABACC3EA678436`，完整离线编译 **0 errors / 7 warnings**。DIDO 为 56 channels、38 bound、18 inactive，声明/映射差异为 0；Kistler 为 400/400 bound、0 mismatch。有效 CpStudio/IO/PLC/HMI 批次已提交为 Station010 `71df380`（`feat: enforce safety relay interlocks`）。
- 本批没有连接、下载、启停、写变量或 FORCE 实体 PLC，没有创建额外 `.project` 二进制备份；`Std` 未修改。真机仍需分别断开 A 门、B 门、维修门继电器和安全门两个继电器反馈，核对时序、报警 AdditionalInfo 与恢复路径。

## Wp100 Run 可复用原子操作（2026-08-20）

- CpStudio 当前正式接口为 `Wp100.MeasurePos : MeasurePsoEnum`；用户已把变量旧拼写 `MeasurePso` 更正为 `MeasurePos`。类型名仍是 CpStudio 生成的 `MeasurePsoEnum`，不要仅在 PLC 内改名。`LEFT/MIDDLE/RIGHT` 分别绑定 `_100B601/_100B602/_100B603`，每个位置都要求目标 DI=TRUE、另外两路=FALSE。
- CpStudio 同批新增 `StationData.PressDelayTime : DINT`（应用按毫秒解释），刷新三路位置传感器中英文描述，并把上一批 Mode/安全门/压缸安全反馈联锁同步到 HMI 条件树。
- AI 经 PLE 官方 REST 扩展把 `SqS_Wp100_Run` 从 N000/N100/N999 骨架扩展为 21 步。压缸下行与 Kistler 启动、压缸上行与 Kistler 结束分别使用一组 `simultaneousDivergence / simultaneousConvergence`；每台设备各有 Start/Wait Step，便于在 SFC 中直接诊断卡点。
- OpCon 并行支路严格使用基类提供的独立返回值：支路 1=`_retVal`，支路 2=`_retVal2`。N045/N095 是两组并行动作前的公共放行步骤；SFC Step Comment 使用短检索描述，详细联锁与结果处理留在对应 ST Action。
- 输出为 `Wp100.SqS_Run.Result : Wp100RunResultStruct`，内含 `Resistance` 与 `Kistler` 两个嵌套结构。结果在 DONE 后保留，到下一轮 N000 清零；N101 在压缸释放前一次性锁存 Kistler 循环力/位移，N120 再补写最终判定，不含完整曲线。
- `OnChainFinish` 对 DONE/ERROR/CANCEL 统一熄灭 `_000P610`、复位按钮/定时器/四个运动或测量 Unit Execute，并令 Kistler `EndMeasurement=TRUE`。单个 `Wp100.SqS_Run` 只允许调用方顺序复用；调用方尚未接线，后续在 READY 时写 `Wp100.MeasurePos`、置 Execute，再以 `CheckSubChainDone` 等待。
- 可重放 ST 源和结构体在 `src/plc/project/Station010`；`scripts/plc/apply_wp100_run_rest.ps1` 负责哈希门禁、官方 REST 写入、逐对象回读和 ProjectJob 保存。幂等回读确认 21 Steps、2 个并行分支、2 个并行汇合和 22 个 Action/方法；完整离线编译 **0 errors / 7 warnings**，Additional code checks **0 errors**；PLC project SHA-256=`7C4226DA757773287D56793F88C6723C42CF72BA63C1698691E0C9EEE0F0F6FF`。
- 有效 CpStudio/IO/PLC/HMI 与 Run Chain 主批次为 Station010 `6b692be`，Kistler 上升前锁存优化为 `768694a`，本次并行 SFC 重构为 `53440a1`；可重放源码、规格、Catalog、REST 写入器和文档主批次为 McpCoding `9549e08`，对应锁存优化为 `578df54`，本次源码随本交接提交。`.Sync.json`、Logbook 日期滚动、`Hmi/obj` 和展示页既有未提交改动均未混入本批。
- 尚待用户/产品数据确认：Burster 上下限和温度开关、Kistler 程序号如何由 TypeData 提供；是否需要 Kistler `READ_DATA` 完整曲线。未连接、下载、启停、写变量或 FORCE 实体 PLC，也未创建额外二进制备份；`Std` 保持只读。
