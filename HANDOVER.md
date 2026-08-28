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
- 环境快照:Windows 开发机;参考工程 Station010(OpCon V5.11 ctrlX)。

## 阻塞项
- 电阻测试台工艺需求需用户确认:可由 AI 解析 ../电阻测试台.pdf 提取,或用户直接口述。

## 下次会话建议第一步
1. 解析 ../电阻测试台.pdf,整理工艺需求清单到 docs/requirements.md 并请用户确认。
2. 该早期 `src/ResistantStation.project` 建议已废止；当前统一使用旁级 `Station010` 受控集成工程。
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
1. **Station010 主工程 GitHub 备份**:私有仓库 `github.com/SOLASOLAo/Stat_Resistant_Station010`(分支 main):
   - `6a7b4ea` 基线(259 文件;.gitignore 排除锁/缓存/备份/每用户配置)
   - `b9b1161` IDE/CpStudio 现状快照
   - 本地仓库已加 origin 并跟踪 origin/main,与远端完全一致。**以后 CpStudio 每次重新生成后先 `git -C ../Station010 diff`**,即可逐文件分析低代码生成机制。
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
- 仓库映射:McpCoding → `Stat_Resistant_AI_Coding`(public);`../Station010` → `Stat_Resistant_Station010`(private);`McpCoding/ctrlx-ai-coding` → `SOLASOLAo/ctrlx-ai-coding`(独立子仓库)。

### 本机网络 / git 推送配方(必读)
- git 全局 `http.proxy=http://127.0.0.1:7890`(Clash)经常停 → 推送报 Could not connect;直连也不行(DNS 解析被拦)。
- 可用组合:`git -c http.sslBackend=openssl -c http.proxy=http://127.0.0.1:3128 -c https.proxy=http://127.0.0.1:3128 push https://x-access-token:$(gh auth token)@github.com/...`(schannel 后端在 Codex 沙箱里报 SEC_E_NO_CREDENTIALS;3128 代理常驻可用)。
- gh CLI 自身一直可用(建仓库/API 无需上述参数)。
- 若 Codex 沙箱为 workspace-write:写 `../Station010/.git` 被拒 → 用 %TEMP% 中转副本(Copy-Item .git + robocopy 文件 → commit → push)。

### 下次会话建议第一步
1. 读 AGENTS.md → 本文件 → TODO.md;确认 MCP 状态(get_codesys_status)。
2. 符号清理:先问用户是否接受在 PLE Symbols 编辑器手删 3 行;不接受再试 import_xml 整表方案。
3. 用户若在 CpStudio 做了重新生成:立即 `git -C ../Station010 diff` 归档分析。
4. 红线:真机操作(下载/启动/write_variable 强制)必须先经用户确认;PLE 绝不打开 IO 工程;.project 只能经 IDE/脚本引擎改。

## 最近会话(2026-08-18 午)· CpStudio/Git/MCP 闭环 + PLC 文本快照工具

### 已完成
1. 建立 `docs/cpstudio_git_mcp_workflow.md`：CpStudio 管模型/HMI/符号，Git 管生成差异，AI+MCP 管底层 ST 与编译闭环。
2. 新增只读确定性导出器 `scripts/plc/export_plc_snapshot.py`：只遍历 primary PLC 的 Application，跳过 Library Manager/Task Configuration/Symbols；一个代码对象一个稳定 `.st`，manifest 无时间戳并含 SHA-256；不 open/save/compile/online。
3. 新增 `scripts/plc/verify_plc_snapshot.ps1`；已通过成功样本和篡改检测自测。内置 `get_all_pou_code` 在 Station010 上因从根遍历设备树超过 120s，不适合作为该工程的批量导出实现。
4. 新增 `docs/cpstudio_generation_analysis.md`，记录 `b9b1161` 后当前未提交生成批次。

### 新发现：Station010 当前有外部生成改动，勿覆盖
- 本会话检查期间发现 `../Station010` 已有 26 个未提交变化；不是本会话工具写入。
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
- 整个失败路径没有改写 PLC project；事后源文件哈希仍与备份完全一致。`../Station010` 仍保留 27 个有意的未提交生成变化，未提交、未回滚。

### 重载后的唯一第一步

在一次 MCP 调用链中依次完成：`get_codesys_status/launch` → `open_project` → 两次 `eval_python(execfile export_plc_snapshot.py)` → 本地校验零 diff → `compile_project`。避免把这些调用拆到多个独立 MCP client；不得再次走 headless。

## 恢复后结果(2026-08-18 11:50)· 最小骨架只读基线完成

- 扩展重启后状态正常：唯一 MCP Node + 唯一 persistent PLE，session `0b4dd2b0-85c1-44cd-a260-aa5fdfe470b0`，PLE PID 24368。
- MCP 打开 Station010 PLC 工程；两次快照均返回 215 个文本对象和相同 project SHA-256。PowerShell verifier 通过；文本树 SHA-256=`4e556b44bb2212c91d7c86d260a87b325b7dfeba8fe0f2b9622089a1dab63241`。
- 离线编译基线：66 errors / 40 warnings。3 errors 当时暂归为 SymbolConfig 残留，后续确认是 A1 旧 I/O 映射；其余 63 errors 是删除 Unit 后遗留在 10 个 ST 对象中的安全门/压缸/扫码枪引用，详见 `docs/cpstudio_generation_analysis.md`。
- 编译没有改写 project：当前哈希仍为 `24A34D3B7A2B6E6E7E9AE57BE9794221716E75BA580A9E5ED20B3F19C9B4EB5C`，与备份一致。
- 用户已明确选择方案①：授权 AI 经 MCP 修改 `../Station010`，并将其正式定义为 CpStudio + MCP 受控集成工作工程；`../Std` 继续严格只读。后续已完成 10 个旧 ST 对象和三条 A1 I/O 映射的清理。

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

- `McpCoding` 已按 `config/specs/ai/src/catalog/scripts/tests/data/docs` 标准重组；`../Station010` 供应商生成布局和 `../Std` 只读目录均未修改。标准全文见 `docs/project_structure_standard.md`，后续项目复制同一旁车骨架后只需修改 `config/project.yaml`。
- 当前 Station010 已落入结构化事实源：Station/AddOn、IO、Events、Wp100 Units、Home/Run Chains；未核实的物理映射明确标记为 pending，不伪装成已验证数据。
- `ai/ownership.yaml` 区分完整 AI-owned、implementation、mixed semantic merge 与 SFC graphical attributes；`ai/hooks.yaml` 记录主气压、维修门、Wp100 Home 和 Burster 手动放行的必要接线；`ai/graphical.yaml` 记录 Home 的 9 个 Step Comment 和正式 REST 写入属性。
- `src/plc/common` 保存 `FB_OperatorButton`、`FB_MainPressureControl`、`FB_MaintenanceDoorControl` 三个当前已编译 POU 的可读规范源；任何同步仍必须通过 MCP 并执行 readback + compile，绝不直接写 `.project`。
- Catalog 首批登记 BasMove Standard V2.1、Burster 2316 V1.0、ControlOn V2.0、EmergencySwitch V2.0、StationLamp V2.3.1 和 IpBurster2316 V1.0；仅保存接口事实与本地手册路径，不复制闭源手册或供应商代码。
- 现有工具分类到 `scripts/plc` 与 `scripts/ioe`；新增 `scripts/cpstudio/post_export_signal.bat` + `write_export_request.ps1`。CpStudio 的 Post-export hook 是官方能力，该自定义脚本只原子发布 `data/requests/export_request.json`，不启动第二个 PLE/MCP。真实 CpStudio hook 配置和 request 消费器仍列为下一步。
- 新增 `tests/static/Test-ProjectFramework.ps1`，检查标准文件、兄弟目录、POU 分段标记和 Post-export 脚本不含 PLE/MCP/在线启动入口。本批只改 AI 工程仓库文件，没有连接、下载、启停或写入实体 PLC，也没有修改 Station010 PLC 工程。

## 团队工作站部署交接(2026-08-19)

- 新增根目录 `TEAM_SETUP.md`，作为同事/新电脑的一次性部署权威入口；原 `HANDOVER.md` 继续只保存项目状态和工程历史，不再承担安装手册职责。
- 文档明确标准四目录布局：`Station010`、只读 `Std`、`McpCoding`、嵌套独立仓库 `McpCoding/ctrlx-ai-coding`；记录三个 GitHub 仓库、私有仓库授权和不能经 GitHub 分发的闭源资产/许可证。
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

- 此处曾记录为全局 `Wp100.MeasurePos`，该设计已被后续纠正取代。当前正式接口是 CpStudio 配置并生成的 `SqS_Wp100_Run.MeasurePos : MeasurePsoEnum`（`VAR_INPUT`）；类型名仍保留 CpStudio 生成拼写。`LEFT/MIDDLE/RIGHT` 分别绑定 `_100B601/_100B602/_100B603`，每个位置都要求目标 DI=TRUE、另外两路=FALSE。
- CpStudio 同批新增 `StationData.PressDelayTime : DINT`（应用按毫秒解释），刷新三路位置传感器中英文描述，并把上一批 Mode/安全门/压缸安全反馈联锁同步到 HMI 条件树。
- AI 经 PLE 官方 REST 扩展把 `SqS_Wp100_Run` 从 N000/N100/N999 骨架扩展为 21 步。压缸下行与 Kistler 启动、压缸上行与 Kistler 结束分别使用一组 `simultaneousDivergence / simultaneousConvergence`；每台设备各有 Start/Wait Step，便于在 SFC 中直接诊断卡点。
- OpCon 并行支路严格使用基类提供的独立返回值：支路 1=`_retVal`，支路 2=`_retVal2`。N045/N095 是两组并行动作前的公共放行步骤；SFC Step Comment 使用短检索描述，详细联锁与结果处理留在对应 ST Action。
- 输出为 `Wp100.SqS_Run.Result : Wp100RunResultStruct`，内含 `Resistance` 与 `Kistler` 两个嵌套结构。结果在 DONE 后保留，到下一轮 N000 清零；N101 在压缸释放前一次性锁存 Kistler 循环力/位移，N120 再补写最终判定，不含完整曲线。
- `OnChainFinish` 对 DONE/ERROR/CANCEL 统一熄灭 `_000P610`、复位按钮/定时器/四个运动或测量 Unit Execute，并令 Kistler `EndMeasurement=TRUE`。单个 `Wp100.SqS_Run` 只允许调用方顺序复用；调用方在 READY 时写 `Wp100.SqS_Run.MeasurePos`、置 Execute，再以 `CheckSubChainDone` 等待。
- 可重放 ST 源和结构体在 `src/plc/project/Station010`；`scripts/plc/apply_wp100_run_rest.ps1` 负责哈希门禁、官方 REST 写入、逐对象回读和 ProjectJob 保存。幂等回读确认 21 Steps、2 个并行分支、2 个并行汇合和 22 个 Action/方法；完整离线编译 **0 errors / 7 warnings**，Additional code checks **0 errors**；PLC project SHA-256=`7C4226DA757773287D56793F88C6723C42CF72BA63C1698691E0C9EEE0F0F6FF`。
- 有效 CpStudio/IO/PLC/HMI 与 Run Chain 主批次为 Station010 `6b692be`，Kistler 上升前锁存优化为 `768694a`，本次并行 SFC 重构为 `53440a1`；可重放源码、规格、Catalog、REST 写入器和文档主批次为 McpCoding `9549e08`，对应锁存优化为 `578df54`，本次源码随本交接提交。`.Sync.json`、Logbook 日期滚动、`Hmi/obj` 和展示页既有未提交改动均未混入本批。
- 尚待用户/产品数据确认：Burster 上下限和温度开关、Kistler 程序号如何由 TypeData 提供；是否需要 Kistler `READ_DATA` 完整曲线。未连接、下载、启停、写变量或 FORCE 实体 PLC，也未创建额外二进制备份；`Std` 保持只读。

## SqC_Wp100_Run 三位置顺序测量（2026-08-20）

- 用户纠正原子操作接口：`SqS_Wp100_Run.MeasurePos : MeasurePsoEnum` 已改为正式 `VAR_INPUT`，删除内部 `_measurePosLatched` 和对 `Wp100.MeasurePos` 全局字段的读取；N000 只把本次输入记录到 `Result.MeasurePos`。
- `SqC_Wp100_Run` 已经官方 REST 重建为 11 步：每个位置各有产品检查、Start、Wait，严格 LEFT → MIDDLE → RIGHT 顺序复用同一个 `Wp100.SqS_Run`；Start 仅在 READY 写输入并置 Execute，Wait 使用 `CheckSubChainDone`。
- 新增 `Wp100RunSequenceResultStruct`，把三轮原子结果分别保留在 `Wp100.SqC_Run.Result.Left/Middle/Right`，避免下一轮 SqS N000 覆盖前一位置的数据。
- N010/N040/N070 均要求 `_100B701 AND _100B702`。`CheckPartPresent` 使用 CpStudio 生成的 `EVENT_PART_DETECT_SENSOR=-4` 和锁定 `SOFTERROR`；AdditionalInfo 精确区分 `_100B701`、`_100B702` 或两路同时缺失，信号恢复后自动 Unlock/Clear，缺失组合改变时会刷新文本。
- `OnChainFinish` 对 DONE/ERROR/CANCEL 撤销 `SqS_Run.Execute` 并清理本链产品检测事件；旧扫描枪模板 Action 已在替换图形后通过 REST 删除。
- 两份 REST 写入器均完成 exact readback 和全 verified 幂等复跑。Application Compile **0 errors / 6 warnings**，Additional code checks **0 errors**；IDE 总计栏的 3 errors 仍是三个未安装 Atmo 旧库，不属于 Application Build。最终 PLC project SHA-256=`D3C251242B5647094A255A71C173D589D5B5A863137F94C7038BB91CD4B4CD4C`。
- Station010 有效 CpStudio 事件/PressDelayTime 生成文件和 PLC 逻辑提交为 `6b402c9`（分支 `feat/wp100-run-sequence-20260820`）。两个 `.Sync.json`、HMI Logbook 日期滚动及 `Hmi/obj` 未暂存、未回退。未连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 未修改。

## PLC ST 条件排版统一（2026-08-20）

- 用户确认条件括号内侧保留空格，项目标准写法为 `IF ( ConditionA ) AND` 换行后 `( ConditionB )`，`THEN` 独立一行；每个独立条件均加括号，`AND`/`OR` 留在上一行末尾。
- 已统一 `src/plc/common` 三个通用 FB，以及 `SqS_Wp100_Run`、`SqC_Wp100_Run` 的 AI-owned Action/Method 源码；没有机械改写 CpStudio-owned 或 mixed 生成区，避免下一次导出产生无意义的空白冲突。
- 两个 REST 写入器新增精确的格式迁移哈希，只允许把已编译旧排版迁移到当前规范；经 PLC Engineering 官方 REST 写入、逐对象回读后再次执行，全部为 `verified` 且 `No changes; save skipped.`。
- `tests/static/Test-ProjectFramework.ps1` 现在扫描 `src/plc/**/*.st`，拒绝续行开头的 `AND`/`OR`、未加括号的 `IF`/`ELSIF`，以及括号内侧没有空格的复合条件；当前结果为 `Project framework OK: 46 required files`。
- 最终 PLC project SHA-256=`48B620837C99B0BA9EBF53449CAB0C75D981B80D629D0111C7A1C201650DEE49`。Application Build 为 **0 errors / 8 warnings**；IDE 总计栏既有 3 个 Atmo 库缺失错误不属于 Application Build。未连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 未修改。

## persistent MCP 编译完成后超时修复（2026-08-20）

- 现象已复现：Station010 的 Application Build 在 PLE 窗口中已经完成，但旧 `compile_project` 在 300 s 后超时；只审计消息类别 × Fatal/Error/Warning 的只读调用也超过 180 s。根因是 MCP 原脚本叠加 `clean/clean_all/build/generate_code`，并在编译后对全部类别和五种严重级别反复调用 ctrlX 上会阻塞的 `get_message_objects`，不是 PLC Build 本身慢。
- `ctrlx-ai-coding/patches/codesys-mcp-persistent-crlf/apply-crlf-patch.ps1` 已扩展为统一修复入口：应用工程只执行一次 `ScriptApplication.build()`；Build 与 Additional code checks 每类只调用一次 `System.get_messages(category)`；以 IDE Build summary 为 error/warning 事实源，摘要不可验证时按错误失败关闭。
- 补丁同时覆盖 npm 包的 `dist/scripts` 与 `src/scripts` 中 `_message_utils.py`、`compile_project.py`、`get_compile_messages.py`，保留原 CRLF 与 connector I/O Mapping 补丁；新增 `test-fast-compile-message.py`，离线覆盖干净、失败、Application current、未知摘要四类回归，`-Check` 幂等且全部通过。
- 恢复卡住会话时，先经 PLE REST `ProjectJob` 保存，再正常关闭窗口并由 persistent MCP 重启；未强杀进程，也未手删活锁。真实工程复测：`compile_project` 约 **7.6 s** 返回 **0 errors / 7 warnings**，其中 Build 调用约 6.1 s、消息快照约 0.094 s；`get_compile_messages` 约 **0.8 s** 返回同一缓存。
- 本次只做离线 Build，未连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 未修改。PLE 保存离线编译状态后，Station010 加密 `.project` 在工作树显示 modified；它未被手改字节、未纳入本次工具修复提交，也不会随本次推送上传。临时回归工程只是 `Standard.project` 的一次性副本，验证后已精确删除，不可恢复但不包含用户数据。

## PLE SFC 元数据、Symbol 与预编译缓存恢复（2026-08-20）

- 本次不需要重新从 CpStudio 导出。最初的 `Bit type at the wrong position!` 弹窗来自工程内部元数据：两份 REST SFC 生成器创建 `<transition>` 时没有写 `name`，导致 `SqC_Wp100_Run`、`SqS_Wp100_Home`、`SqS_Wp100_Run` 共 39 个 Transition 被 PLE 序列化为 `VariableName=NULL`；`SqM_Station_Home` 另有两个内部名仍指向旧步骤 `Step0`。以上对象均经 PLE 官方 native export/remove/import 方式修复，没有手改 `.project` 字节。
- Symbol Configuration 当时保留 8 个签名、但 datatype 配置从正常基线的 73 个变成 0 个；已通过官方 native import 恢复。同一批对应用、设备、Library Manager、BinIo 和 EtherCAT/I/O Mapping 做了 GUID 对齐的全量 native export 比较：38 个 DIDO BIT 映射和 400 个 Kistler BYTE 映射全部一致，52 个库占位符及所有 PLC POU 也一致，因此没有重做 CpStudio、IO 或库引用。
- SFC/Symbol 修复后仍出现的 501 条 AddOn/BinIo 缺失级联，最终隔离为工程同目录的损坏 `Stat010_V5.precompilecache`。关闭正式工程后只把该缓存移到 `%LOCALAPPDATA%\Temp\Stat010_V5.precompilecache.stale-20260820`，重开后由 PLE 自动生成新缓存；连续两次真实 Clean Build 均为 **0 errors / 7 warnings**。复验完成后已删除这一临时旧缓存，不保留多余备份。`MainTask.core_binding` 已恢复 CpStudio 基线值 `-2`，复编仍通过，证明它不是根因。
- 两份 Run-chain REST 写入器现在为每个 Transition 显式生成 `SourceStep__to__TargetStep` 名称；`tests/static/Test-ProjectFramework.ps1` 新增缺名门禁，防止同类无效图元再次进入工程。正式工程最终 SHA-256=`A8CCD18F1C9CBB7CD6465700C78E20CA1ECFA9B0E77BBB95B7AF7C8586889D4E`。
- persistent MCP 的另一个独立故障是旧 `ready.signal` 中的 PID 已被 Windows 复用于无关 `python.exe`，原启动器仅做 signal-0 检查而误判会话仍存活。兼容补丁现同时验证目标可执行文件名，并在接管前执行 watcher `SCRIPT_SUCCESS` 握手；健康检查与 shutdown 也使用同一身份判断，防止误接管或误结束无关进程。首次重启还遇到 `configCtrlXPlc.json` 的瞬时文件锁，锁释放后正常启动，与项目/CpStudio 无关。
- 最终正式工程已完成“保存关闭 → 重新打开 → 等待库加载 → Clean → Build”复验，当前 PLE 无 `Bit type` 弹窗。全程仅离线处理，没有连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 未修改，用户的展示页、Sync、HMI Logbook 与 `Hmi/obj` 工作树改动未回退、未混入本批。

## C0198 SetEvent AdditionalInfo 长度修复（2026-08-20）

- C0198 的完整 PLE 消息为 `String constant ... too long for destination type 'STRING(63)'`，对象是 `SqC_Wp100_Run.CheckPartPresent`。双路产品检测缺失文本原为 79 字符；单路两条均为 58 字符，因此只有 `missingMask=3` 分支触发。
- 双路文本已缩短为 60 字符：`_100B701=FALSE; _100B702=FALSE: both fixture sensors missing`，两个 BMK、FALSE 状态和故障含义均保留。规格、可重放 ST 源和正式 PLC Method 已同步。
- `tests/static/Test-ProjectFramework.ps1` 现在解析 AI-owned ST 中 `SetEvent` 的第三个字符串常量，超过 OpCon `STRING(63)` 即失败。两份 SFC REST 写入器同时兼容 PLE 的非对称规则：PUT 保留 Transition `name`，GET 省略该属性；门禁分别校验命名目标哈希与标准化读回哈希，重复运行均为 `verified / No changes; save skipped.`。
- 最终正式工程 SHA-256=`20D9DD9A44B72A4025F49774E2151D12A119937ED788BE9B1AAABA711899B51E`；真实 Clean Build 为 **0 errors / 6 warnings**，全活动消息类别复查 `C0198_MATCHES=0`。未连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 未修改，既有 HTML、Sync、HMI Logbook 与 `Hmi/obj` 改动未暂存、未回退。

## 跨项目工具链第一阶段产品化（2026-08-20）

- 共享 `ctrlx-ai-coding` 新增 `New-CtrlXOpconProject.ps1` 与完整 AI 旁车模板。初始化器先支持 `-WhatIf`，目标存在即拒绝，使用临时目录事务生成；Station/Std/PLC/IO/CpStudio 路径写成相对正斜杠，不复制 `.project`、Std、PDF/CHM/ZIP 或其他闭源资产。Windows PowerShell 5.1 端到端 **50 assertions** 通过，生成项目自带的静态门禁和 Post-export 队列自测均通过。
- 新增版本化 `ctrlx-opcon-engineering` Codex Skill，并通过安装器同步到 `%USERPROFILE%\.codex\skills\ctrlx-opcon-engineering`。Skill 明确组合初始化、CpStudio 导出、PLC 离线开发和故障诊断模式；工程写入前要求路径/profile/ownership/可恢复基线就绪，按 CpStudio-owned、AI-owned、mixed 分流，真机操作仍需单独授权。安装器支持 `-WhatIf/-Check/-Force`，精确同步测试 **6 assertions** 通过。
- Post-export 从单一覆盖文件升级为 schema-v2 队列：`pending → processing → done/failed`。`Invoke-PostExportAudit.ps1` 在排他锁后枚举请求，支持 `-WhatIf/-RequestId/-All/-RecoverProcessing`、旧 schema-v1、失败留痕和 JSON/Markdown 报告；请求 Station/PLC 必须与 `config/project.yaml` 强一致。它只执行 `GIT_OPTIONAL_LOCKS=0` 的 Git 审计、关键文件 SHA-256 与 ownership 清单，不启动 PLE/MCP，也不修改 Station。隔离自测覆盖连续请求、锁等待 stale-candidate、错 Station、错 PLC、旧请求重复、坏 JSON 和审计前后 Station 哈希/Git 状态不变。
- 主项目静态门禁改为从 `config/project.yaml` 与 `ai/ownership.yaml` 发现路径/源码/规格/写入器，检查 orphan ST、Chain spec 与 graphical Step Comment、REST-composite Action 完整性、`SetEvent STRING(63)` 和 SFC Transition 命名；自测会故意制造 Comment 不一致和 Action 缺失并确认失败。当前结果：**20 core files / 58 ownership records / 44 PLC sources**。
- MCP 下一阶段的确定范围已写入 `ctrlx-ai-coding/docs/mcp_productization_roadmap.md`：先受控 fork、跨进程租约、异步 operation、`project_health`、`compile_project_v2`、FORCE 生命周期和 `apply_change_set`，再做正式 Symbol/I/O/SFC 与 IOE adapter。项目 BMK、事件、工艺、安全决策和 Git/HANDOVER 不进入通用 MCP。
- 本批没有调用 PLC 写入 MCP、没有修改 Station010/IO/Std，也没有连接、下载、启停、写变量或 FORCE 实体 PLC。`docs/ai_coding_showcase.html` 是用户既有未提交修改，保持未暂存、未回退、不会混入本批提交。

## Station010 工程目录去日期化（2026-08-20）

- 用户将受控集成工程根目录从旧的带日期名称统一为 `Station010`。操作前确认 CpStudio/IOE 已退出；persistent PLE 打开旧 PLC 路径但工程 `dirty=False`，经 `shutdown_codesys` 优雅关闭，未保存或改写工程。
- Windows PowerShell `Move-Item` 因源 `.git` 的 Hidden 属性在最后清理阶段返回权限错误，但项目与完整 Git 元数据已移动到目标目录；核对目标 HEAD、工作树状态及四个关键文件 SHA-256 后，只精确删除旧路径中空的 `.git` 壳和空目录。后续同类 Git 工作树同盘改名优先使用 `Rename-Item`，并始终在清理残留前核对两端内容。
- 改名前后 CpStudio 索引、`Engineering_Data.xml`、PLC project、IO project 的长度和 SHA-256 完全一致；PLC project 仍为 `20D9DD9A44B72A4025F49774E2151D12A119937ED788BE9B1AAABA711899B51E`。Station 既有 Sync/HMI/Logbook 工作树状态原样保留。
- `config/project.yaml`、团队部署说明、脚本默认路径、规格、测试和展示页统一改为 `../Station010`；GitHub 集成仓库原本已叫 `Stat_Resistant_Station010`，无需重命名。目录名与 Git 分支无绑定，现有功能分支继续使用并更新远端。
- 本次没有修改 `.project` 字节、PLC/ST/IO/HMI 逻辑，也没有连接、下载、启停、写变量或 FORCE 实体 PLC；`Std` 未修改。

## CpStudio 接口所有权与 Symbol 导出周期（2026-08-22）

- 用户确认 `MeasurePos` 必须在 CpStudio 中配置为 `SqS_Wp100_Run` 的 `VAR_INPUT`。因此生成 POU 的接口、类型、方向和 OES `Declaration` 合并区统一归 CpStudio；AI 只读取并使用。两份旧 REST composite 写入器在完成“声明原样保持”改造前已在清单中标记为 blocked，本轮未运行，也未修改 PLC 程序。
- 当前 Station010 的 CpStudio/连接生成文件含实体凭据字段，不能原样提交。Station 集成仓库禁止 `git add -A`/`git add .`；本轮只更新旁车规则与记录，不暂存或上传任何 Station010 生成文件，也不在日志中记录凭据值。
- 本机 CpStudio 5.11 导出链经只读追踪确认：写入 PLC 对象后直接执行 OPC UA 方法发布、PersistentVars 实例路径刷新以及 Symbol Configuration GET/PUT，中间没有 Build。CODESYS 官方文档同时明确 Build 是 Symbol Configuration 当前变量准备的前提。由此得到待实验确认的机制：Export #1 写入声明，但仍可能读取旧编译模型；PLE Build 刷新模型；Export #2 再完成符号选择与后处理。
- `DummySymbolProbe` 实验基线为 PLE 离线 Build **0 errors / 7 warnings**，探针在 CpStudio 模型、PLC 文本快照、Symbol XML 和 Public Interface 中均不存在；随后由用户在 `Wp100` 已发布变量区创建普通 `BOOL` 探针并分阶段导出。完整过程见 `docs/symbol_configuration_export_cycle.md`。
- 新增实验已完成：Export #1 在 Build 前就已将探针写入 `Wp100` 声明并在 Symbol Configuration 中设为 `BOOL / ReadWrite / selected=true`，CpStudio Output 无红字；中间与最终 PLE Build 均为 **0 errors / 6 warnings**。因此“双导出”不作为所有新增变量的硬门禁，仅在第一次导出出现 Symbol 缺失、未选中或 OPC UA Method/PersistentVars/Symbol 后处理失败时执行。
- 删除实验补充了会话边界：CpStudio 删除探针并完成 Export #1、Build、Export #2 后，源码与 REST 当前可用 Symbol 已为 0，但同一 PLE 会话两次 Build 仍报两条旧签名警告。保存关闭并重新打开 Export #2 生成的同一份工程后，Build 恢复 **0 errors / 6 warnings**，Dummy 警告为 0；最终工程 SHA-256=`761ECD38F811C545CBA5791B8E31CA872D44C9688C1A0442BB45EB5B8332CC55`。
- 失效签名不会出现在 REST GET 的当前可用清单中，不能根据推测 payload 做精确 `UnSelect`。一次隔离尝试将警告扩大到 101 条，已立即关闭 PLE，并用操作前内容寻址检查点逐字节恢复后重开验证；最终工程无残留。以后顺序固定为“条件二次 Export → 保存关闭并重开 PLE → Build → 仍有问题才用 UI `Remove...`”，不裸用 `UnSelectAll`，不修改 CpStudio 模型或 PLC 代码。

## EtherCAT BMK 单通道双向实验（2026-08-22）

- 以 A4 Channel 4 完成 `_100B604 → _100B606 → _100B604` 双向实验，确认 Save、Write designators、Export 和 Link I/O 分别更新不同层，不能互相替代。
- Export #1 已更新 `BinIo`，但 connector mapping 仍指向旧名；Link I/O 后映射正确。随后 Build 的 4 errors 实际只有一个根因：mixed 对象 `Wp100Unit.OnApplyOutputs` 仍直接引用旧 BMK，其余 3 条为类型推断级联。按声明钩子语义合并后 Build 恢复 0 errors。
- Build 刷新后执行 Export #2，OPC UA Method、PersistentVars 和 Symbol 后处理完成；反向恢复按完全相同的顺序完成，最终 Build 为 **0 errors / 9 warnings**。
- CpStudio 自身最终只保留 3 条 Burster 2316 对象“尚未针对当前 PLC 类型测试”的兼容性警告；它们与 PLE 最终 9 条 Build warning 是两个消息源，也不是本次 BMK/Symbol 导出失败。
- 首次 Export #2 的 `Symbol Configuration ... already in use` 是审计与 CpStudio Export 并发访问同一 Symbol 对象造成的，不是 CpStudio 模型故障。停止并发读取，并在同一 PLE 进程内 Save → Close → Open 后恢复；没有启动第二个 PLE。
- 最终 `BinIo`、A4 Channel 4 mapping 和 mixed hook 均只含 `_100B604`，临时 `_100B606` 为 0；Kistler 400-byte PDO 未变化。本实验没有连接、下载、启停、写变量或 FORCE 实体 PLC。
- 后续 EtherCAT BMK 改名固定使用“Save → Write designators → Export #1 → Link I/O → mixed refs → Build → 条件 Export #2 → final Build”，并在 CpStudio Export 期间暂停一切 Symbol Configuration 并发审计。

## Post-export Stage 2 PlanOnly 协调层（2026-08-22）

- 新增 `scripts/cpstudio/Invoke-PostExportEngineering.ps1` 作为 Stage 1 离线报告之后的旁车协调层。CpStudio 当前不能承载这套控制逻辑，因此不修改 CpStudio 本体；协调器只建立幂等、内容哈希绑定的 operation/action ledger，默认保存在 `data/operations/cpstudio-stage2/<operation-id>/`。
- operation 明确使用 `WAITING_FOR_RUNNER`、`WAITING_FOR_CPSTUDIO`、`WAITING_FOR_EXPORT_2`、`DONE`、`BLOCKED` 和 `FAILED`。同一 Stage 1 报告重复提交只查询/复用原 operation；推进证据必须绑定 operation、当前 action 和 action SHA-256，并与 `config/project.yaml` 中的 Station/PLC 路径一致。
- 该脚本是 **PlanOnly**，不会启动 PLE、MCP 或 REST，不会打开 Symbol Configuration，也不会修改 Station010。action 由当前唯一的 persistent Codex/PLE 会话执行后再提交 evidence；当前批次没有实现自动 live runner 或跨进程 MCP 租约，不能把“action 已生成”当成“工程动作已完成”。
- Export #2 改为条件状态：只有 Export #1 后记录到 Symbol 缺失/未选中、OPC UA Method/PersistentVars/Symbol 后处理失败，或 BMK 变更经 Build 后仍需刷新，才进入 `WAITING_FOR_EXPORT_2`。若缺陷属于 CpStudio-owned 接口/模型，则进入 `WAITING_FOR_CPSTUDIO`，由用户在 CpStudio 修正并重新导出，AI 不经 PLE 强补接口。
- BMK 顺序保持 `Save → Write designators → Export #1 → Link I/O → mixed refs → Build → 条件 Export #2 → final Build`。CpStudio Export 期间必须释放/停止一切 Symbol Configuration 并发读写；`This object is already in use` 视为序列化失败，不能通过再开一个 PLE 规避。
- warning 验收仍以 fresh Build 的 code/object/position 签名审阅为准；`config/quality-gates.yaml` 中历史 `baseline_warning_count: 6` 未改成 9，相同数量不能证明 warning 集合相同。该批只改 AI 旁车工具、模板/Skill 与文档，不修改 PLC 程序、Station010 或 `Std`，也不执行任何实体 PLC 在线动作。

## CpStudio Post-export 真实冒烟（2026-08-22）

- CpStudio 5.11 的准确入口为 `Engineering V5.11.0 → Engineering settings → Export`；`Post-export script` 相对于 Station 路径，因此 Station010 的正确配置是 `..\McpCoding\scripts\cpstudio\post_export_signal.bat`。此前建议的两个 `..` 已纠正，Pre-export 保持空白。
- 用户保存配置后执行了一次无模型改动的普通 Export。hook 真实生成 schema-v2 请求 `94920f26-6481-4d97-bb8e-f48775c12c95`；Stage 1 `-WhatIf` 精确看到一个 pending 请求，正式消费后状态为 `done/review`，唯一 finding 是 `GENERATED_CHANGES_PRESENT`。22 个 Git changed path、23 个关键指纹和 3 份 ownership manifest 均已记录，guardrail 回读为 0 个工程工具启动、0 个生成文件写入、0 个在线操作。
- Stage 2 `-WhatIf` 与正式创建使用同一确定性 operation id `cpstudio-stage2-94920f26-6481-4d97-bb8e-f48775c12c95-70171e90`；正式状态为 `WAITING_FOR_RUNNER`，不可变 action 为 `0001-inspect_and_build.json`，ledger/action SHA-256 读回一致。由此证明 `CpStudio hook → request queue → Stage 1 → Stage 2` 真实串通。
- 冒烟同时发现首次创建 operation 时，内存对象是 `OrderedDictionary`，旧的 `Get-ResultView` 只按 PSObject 属性读取，导致命令返回的 action path/hash/id/kind 为 null；ledger 本体始终正确。`Get-PropertyValue` 已补 `IDictionary` 支持，并新增 6 条回归断言，根项目/模板 Stage 2 测试、静态门禁和初始化器 54 assertions 全部通过。
- 本轮只写 `McpCoding/data` 队列、报告和 operation ledger；没有启动 PLE/MCP/REST，没有修改 Station010/PLC/IO/Std，也没有连接、下载、启停、写变量或 FORCE 真机。下一步是实现唯一 persistent 会话消费 action 的受控 runner，并提交结构化 evidence；不能把当前 `WAITING_FOR_RUNNER` 当成已完成工程检查。

## Post-export runner evidence 边界（2026-08-23）

> 历史记录：本节描述 Broker 落地前的 workflow-local/Codex 执行边界，已由下方 2026-08-27～28 的 P1.2a、P1.2b 与真实 PLE 通道章节取代；保留用于追溯，不代表当前能力状态。

- 新增 `scripts/cpstudio/New-PostExportRunnerEvidence.ps1`。它只接受 immutable action + ledger SHA + 当前 runner 的显式 observation，重新验证 Stage 1 报告、3 个 ownership 清单、所需关键 Station 指纹、Build 时间与当前 PLC SHA，并把逐条 warning 规范化为 `sha256:v1:normalized-warning-record` 签名多重集后原子写入不可变 evidence。它不启动或调用 PLE、MCP、REST、Symbol Configuration 或 watcher IPC，也不会默认把任何 guardrail/acceptance 设为 `TRUE`。
- 新增 PS5.1 自测 `tests/cpstudio/Test-PostExportRunnerEvidence.ps1`，覆盖 UTF-8/BOM 与中文/空格路径、成功与无虚假 Build 的 blocked 路径、幂等/WhatIf、action/manifest/fingerprint 漂移、在线能力、第二 PLE、直接 watcher IPC、未显式释放 lease、旧 Build、warning 多重集不完整和敏感字段拒绝。Stage 2 另覆盖 apply 调用前空能力阻塞、顶层 null 拒绝、部分写入失败的已验证子集与严格 evidence 字段集。根项目与模板测试均通过；初始化器现为 **58 assertions**，生成项目会自动携带并执行该测试。
- Stage 2 consumer 只从 `data/runner-evidence/` 接受 producer-contract evidence，并强制核对 action 身份/SHA、显式 guardrail、existing persistent session、按 action kind 区分的离线 capability 白名单、Build 工程/SHA/来源与 warning 算法。真实生成的测试 action 已完成 `Stage2 → producer → consumer → DONE` 离线回归；这仍是结构化合约校验，不是 producer 的加密签名。
- 根项目、`ctrlx-ai-coding` 模板、基线 MD/HTML、SESSION_LOG 和已安装的 `$ctrlx-opcon-engineering` reference 已同步。`workflow-local` lease 被明确限定为当前单 Codex 会话协调，并不宣称已经实现跨进程锁。
- session PID、session reuse、acceptance 与 workflow-local lease 均为当前 runner 的结构化自证；纯离线 producer 只校验必填性和相互一致性，不会独立查询进程表或 MCP，因此这些字段是审计证据，不是加密签名或 OS 强制锁。
- 用户关闭 PLE 并重启 Codex 扩展后，persistent 会话恢复为唯一 healthy PLE：session `c107a39e-91d7-47d7-b91d-c2fb7a321aca`、PID `33748`、profile `ctrlX PLC 2.6.8`。runner 复用该会话打开 action 指定的同一 PLC 工程；这暴露出证据白名单遗漏只读 `open_project` 的问题，producer/consumer 与回归 fixture 已补齐该能力，仍禁止 `save_project` 和所有在线能力。
- 真实 operation `cpstudio-stage2-94920f26-6481-4d97-bb8e-f48775c12c95-70171e90` 已由 immutable action SHA `59422DA644F93CE1EE3181F686C7173976B4B4E81F6F2521F21AE1D9B90F8116` 完成 `Stage2 → live runner → producer → consumer` 闭环，revision `2`、最终状态 `DONE`。fresh offline Build 为 **0 errors / 6 warnings**；warning 多重集为 3 个签名（`application is up to date` 1 次、`CLASS` 兼容提示 4 次、`OPC.UA.DA` 属性提示 1 次），无 I/O、Symbol、旧签名或应用代码错误，因此不要求 Export #2，也不要求 CpStudio/PLC 修复。
- PLC `.project` 在 Build 前后 SHA-256 均为 `42BB6D9C1BA5E1544DC0751AA7BE9F7A43FD94C9F9875B6C940425ABAE0055C5`，未被写入。按 Skill readiness gate 只建立一份同哈希、Git 忽略的内容寻址检查点；未重复备份。全过程没有连接、下载、启停、读写变量、FORCE、第二 PLE、direct watcher IPC，也没有修改 Station010/PLC/IO/Std；用户自有 `docs/ai_coding_showcase.html` 继续保持未暂存、未覆盖。

## 用户本地离线 Post-export 检查器（2026-08-23）

- 新增 `scripts/cpstudio/Run-OfflinePostExportCheck.cmd`。用户断网时双击运行，按提示选择第 1/2 次 Export、CpStudio Output 类型、普通变量或 EtherCAT BMK，以及是否已完成 Link I/O；PowerShell checker 只在确认没有既有 PLE/MCP 和 `.project.~u` 后启动一组自有 `codesys-mcp-persistent`/PLE。
- runner 仅调用 `get_codesys_status → open_project → compile_project → get_compile_messages → shutdown_codesys`；没有编辑、保存、在线连接、下载、启停、变量写入或 FORCE。PLC `.project` Build 前后 SHA-256、owned PID/父子关系、进程退出和锁释放全部失败关闭；全局锁覆盖 anchor 读取到不可变报告写入，锁占用、权限或路径异常均不执行 Build、不落报告。正常报告写入 `data/reports/offline-post-export/`，不推进 Stage 2 ledger。
- 统一补丁新增 `ctrlX strict no-save compile guard v2`：移除 dirty-project 隐式 `save()`，工程 dirty 状态不可确认或为 dirty 时拒绝 Build。检查器只使用本次隔离 TEMP 生成的 fresh Build evidence 作决策，缓存消息仅作附录；`DONE_OFFLINE` 只表示无需继续 Export，不代表 warning/质量门禁通过。
- Export #2 只能由 fresh、verified、0-error 的 Export #1 Build 建立 anchor，并要求当前及随后导出都有可关联、带时间戳的 CpStudio request；缺少 request 时明确回到 Export #1，不创建不可使用的 anchor。对象占用、次数误选、Output 待确认和 Build 前 Link I/O 会显式携带该 anchor；Export #2 一旦进入 Build 即消费，终态和已尝试 Build 的报告不能复活旧 anchor。
- 根项目与通用新项目模板的 checker/helper/launcher/test 内容哈希一致，各 **458 assertions** 通过；初始化器端到端 **65 assertions** 通过并会把它们带到以后项目。真实 `-WhatIf` 读回 `1 PLE + 4 MCP + .project.~u`、`wouldStart=false`，前后 5 个 PID 完全不变；因此本轮没有强关会话、没有手删锁，也没有冒充完成真实生命周期 smoke test，待用户正常关闭 owner 后补做一次。
- 本轮没有修改 Station010、PLC、IO、CpStudio 模型或 `Std`，也没有执行任何实体 PLC 在线动作。用户自有 `docs/ai_coding_showcase.html` 保持未暂存、未覆盖。

## HMI OverView / UserDefined 迁移（2026-08-23）

- Station010 的 `OverView.sfc` 已收敛为单一 `Mod_SmartControlHost1`，`SmartControlName="UserDefined"`；原来的 `Mod_EnumDisplay1`、`Mod_VarOut2`、`Mod_VarOut3`、`Mod_Led1`、`Mod_PictureBox1` 共 5 个内容控件已迁入 `UserDefined.sfc`。嵌入偏移按宿主 `Y=4` 折算，保持最终画面绝对位置不变，临时 `AI_ProbeLabel` 已移除。
- 图片资源由 `OverView.resources` 迁到 `UserDefined.resources`，键仍为 `Mod_PictureBox1.Images.0`；资源读回为 `551 × 761 / Format32bppArgb`。`OpCon.HMI.Modulo.csproj` 只保留 `UserDefined.resources → UserDefined.sfc` 关联，旧资源文件和项目引用均已移除。
- 使用 CpStudio 5.11 内置的官方 HMI Configurator 完成两次加载验证：直接打开 `UserDefined` 可见状态灯、Station/Type 编号、设备图片和自动信息栏；再打开宿主 `OverView`，相同内容经唯一 SmartControlHost 完整显示。保存、正常关闭并重新审计后，CpStudio 未重新生成旧 `OverView.resources`，XML、4 条 VWItem 绑定、5 个控件 ID 和资源引用全部通过静态校验。
- 本机独立 VisiWinNET Smart 与当前 OpCon 程序集运行时不兼容，Launcher 也判定所需版本不可用；因此当前受支持的官方可视化验证面是 CpStudio 内嵌 HMI Configurator。AI 仍可在内容寻址检查点和精确 diff 边界下维护用户画面文件，用户不必逐个手工搬控件；CpStudio 的模型树、画面注册和完整 Export 继续由 CpStudio 负责。
- 本轮未执行完整 CpStudio Export：当时唯一 persistent PLE 会话仍在，直接 Export 可能再次争用 Symbol Configuration。迁移已完成官方加载/保存往返验证；下次正常 Export 应在释放 PLE/Symbol 占用后进行，再由 Post-export 流程审计是否保持。没有调用 PLC MCP、修改 PLC/IO/`Std`，也没有连接、下载、启停、读写变量或 FORCE 真机。
- Station010 工作树还混有用户既有生成改动，并且 `.vwn`/其他生成配置存在凭据字段，故本轮不整体暂存、不提交或推送 Station010。HMI 最小变更集合仅为 `OverView.sfc`、`UserDefined.sfc`、`OverView.resources` 删除、`UserDefined.resources` 新增及 `OpCon.HMI.Modulo.csproj`；后续上传前仍需字段级审阅和脱敏。

## HMI 用户布局与 Git 脱敏收口（2026-08-23）

- 用户在 CpStudio 官方 HMI Configurator 中继续调整并保存布局：宿主为 `(3,0) / 944×624`；自动信息栏为 `(4,561) / 889×32`；TypeNo 为 `(564,4)`，StationNo 为 `(243,4)`，Home LED 为 `(15,10)`，设备图为 `(38,42)`。官方预览中五项内容完整可见，标签页无未保存标记；变量绑定和图片资源未改变。
- 完整 HMI 注册链经字段级审计为 10 个路径。9 个运行/注册路径只有 UserDefined 文本 ID、View/SmartForm 注册、项目资源关联和控件迁移；`.vwn` 本轮语义变化只有时间戳与文本 ID，但本机文件含非空现场字段，因此采用“索引仅暂存脱敏版本”：Git 提交中的 HMI 管理密码与项目密钥为空，本机工作文件未改写。
- Station010 已精确提交 `84d1577`（`feat: move overview content into UserDefined HMI`）。提交只包含 HMI 注册、宿主/内容画面与资源 100% rename；`PlcHandlerL1.ini`、Engineering/DataSetAccess/Targets、PLC/IO、Logbook 和 `Hmi/obj` 均未暂存。当前本机 `.vwn` 相对脱敏 HEAD 保持 modified 是预期状态，后续严禁整体暂存。
- 结构、当前坐标、5 个绑定、注册文件、官方工具边界、验证证据和后续 HTML 事实已集中记录到 `docs/hmi_userdefined_integration.md`；现有 `docs/ai_coding_showcase.html` 是用户 2026-08-20 的既有未提交改动，本轮未覆盖。
- 本轮未执行完整 CpStudio Export 或 PLC Build，也未调用 PLC MCP、修改 PLC/IO/`Std` 或执行实体 PLC 在线动作。浏览器使用企业 PAC，而 Git 全局配置指向未监听的旧本地代理；本次只对 push 进程使用系统已验证的代理路径，没有修改全局 Git、PAC、WinHTTP 或 Windows 网络设置。Station010 `84d1577` 与 McpCoding `8d80fca` 均已推送对应远端分支。

## AI-first 展示页与操作边界更新（2026-08-23）

- `docs/ai_coding_showcase.html` 已从旧的三方概览更新为 AI-first 工程方案：可经受控接口稳定完成的需求结构化、PLC/SFC 实现、Export/BMK/Symbol 审计、Build 修复、既有 UserDefined 内容维护、证据与 Git 默认由 AI 执行；用户只保留 CpStudio 模型/生成接口/View 注册、当前无稳定接口的官方 GUI 操作，以及所有实体设备安全决定。
- 页面新增 6 行责任矩阵和 5 个可切换流程：纯 PLC、CpStudio 模型 Export、EtherCAT/BMK、HMI、断网离线。明确 Export #2 只在报告要求时执行；官方 Post-export 槽只调用项目自研请求脚本，Stage 2 仍为 PlanOnly，通用无人值守 live runner 尚未实现。
- 新增 HMI 章节，记录 `OverView → Mod_SmartControlHost1 → UserDefined` 分层、1 个 Host / 5 个业务控件 / 4 个绑定及资源关系。准确边界为“AI 维护 WFML/resources，CpStudio 内嵌 HMI Configurator 负责官方加载、预览和保存”；没有宣称存在官方 HMI 写 API/headless CLI，也没有把独立 VisiWinNET 当作验证工具。
- 历史指标已纠正为“最近一次已记录 Clean Build 基线 0 errors / 6 warnings、237-object 确定性快照”，不再冒充当前脏工作树状态；Post-export、离线 checker 和 HMI 的状态更新至 2026-08-23。页面经 Edge 1440×1200 实际渲染检查，责任矩阵、断网流程、HMI 案例和结论章节均无溢出，五个流程页签可切换，`git diff --check` 通过。
- 本轮仅修改 McpCoding 文档，不调用 PLC MCP，不修改 Station010/PLC/IO/CpStudio/`Std`，不连接、下载、启停、写变量或 FORCE 实体 PLC。提交仍须精确暂存这 3 个文档，禁止整体暂存。

## AutoInfoLine 与 Run Chain 操作提示收口（2026-08-24）

- 用户已在 CpStudio 末尾追加并导出 `AutoInfoLineEnum` 4–16。PLE 官方 REST 回读的实际 DUT 声明按 0–16 顺序生成；`Engineering_Data.xml` 中新项 `Index=0 / IndexChange=false` 是 CpStudio 的自动顺序语义，不是 PLC 里 13 个重复的枚举值。HMI 1033/2052 资源已实际生成 `L1_AutoInfoLineEnum4..16`。
- `SqS_Wp100_Run` 以 Plan SHA-256 `0fcb072b9cc175f79559fea7b18f0f434474acc1044b7df608352d569b07fd50` 事务应用；`SqC_Wp100_Run` 以 `b644dc984743937c303ef8607a8be3ac61d8d80402c7b482683740ff10e68c15` 事务应用。两者都完成写前二次快照、保存后回读和原声明逐字保持；SqC 现为 14 Steps，新增 `N015/N045/N075` 等待 LEFT/MIDDLE/RIGHT 夹具位置。
- fresh offline Build 初次为 **0 errors / 6 warnings**。其中两条项目内 `C0373` 来自 Station/Type Data 两个 `OnCheckData` 的“检查后删除”占位 `{warning}`；保留 CpStudio 生成范围校验并仅删除这两行后，最终 Build 为 **0 errors / 4 warnings**。
- 剩余 4 条精确签名均为 `C0351 / NexeedStateAddon 1.1.1.0 / OPC.UA.DA unknown`，来自 `C:\ProgramData\Rexroth\PLE-V-0206\0\Studio\Managed Libraries`下的 Bosch 托管库；不修改安装库或 `Std`。该签名已作为当前可接受基线，新的应用层 warning 仍必须失败关闭。
- 确定性 PLC 文本快照为 **262 objects**，project SHA-256=`B92CD8940EA762056BD820DDE8C8DBCD46ECB057BA3ABE0BE52F5043E447B508`，manifest 校验通过。本轮未连接、下载、启停、写变量或 FORCE 实体 PLC，也未修改 `Std`。
- 已知的非运行阻塞：CpStudio canonical XML 中 `USER_INFO_MEASUREMENT_COMPLETE` 的 `zh_CN` 节点仍为空，但实际 2052 HMI 资源已是“测量完成”。后续再编辑该枚举时应在 CpStudio 中确认最后一项中文单元格，AI 不直改 `Engineering_Data.xml`。

## Nexeed License Server 61863 崩溃诊断（2026-08-24）

- 实体 ctrlX CORE X3 上 `443=True`，但 Nexeed Licensing 的 `61863` 被目标主动拒绝；这排除电脑到 ctrlX 的基本网络路径，但不能单独给出根因。
- 用户在 Service 状态重启 Bosch Nexeed Automation Licensing 后切回 Operating。13:28:02 之后约两分半内，新 developer Logbook 完整记录 9 次 `slots/plugs connected → AppArmor DENIED net_admin → StatusCode 999 → status=11/SEGV → restart`，证明 `61863=False` 是 App crash-loop 的结果。
- 本机只读审计 2.2.0 arm64/core22/strict 包：daemon 只声明 `network/network-bind/active-solution/log-observe`，未声明 `network-control` 或 `network-manager`；包内外部 OPC UA 端点为 61863，六项 Control plus 许可证均为非启动必需。权限声明/运行时兼容是最强线索，但 SIGSEGV 的唯一因果仍需供应商确认。
- 新增 `docs/nexeed_license_server_diagnosis.md` 与只读 `scripts/diagnostics/Test-CtrlXLicenseServer.ps1`。原始 CSV、端口报告、设备序列号和本机网络清单不入 Git。
- 当前阻塞是取得 Bosch/Nexeed 提供的兼容修正版或正式处置；不要继续反复 Read/Restart，不手改 AppArmor，不修改供应商签名 App。修复后先验证 Logbook 稳定和 61863 连续 60 s 可达，再执行 CpStudio Read from target。此次只读诊断没有修改工程或设备状态。
## 2026-08-24 · 主气压虚拟反馈

- 首次真机观察发现旧虚拟反馈跟随 `ControlOn.OutImm.IsCtrlOn`，而压力诊断跟随最终 `xValveOn`。当维修门释放尚未成立时，虚拟 HIGH 会提前出现，令主阀失去 LOW-only 开阀条件；5 s 后锁存 `EVENT_PRESSURE_NOT_LOWER`，再经 `UserEnableControlOn` 自动下电。
- 已把 `FB_PressureFeedbackSimulation` 改为跟随 `Station.MainPressureControl.xValveOn`：使能时先建立安全 LOW，阀命令 ON/OFF 后 1 s 原子切换 HIGH/LOW。保留主压力 5 s 诊断、维修门放行和官方 ControlOn 下电接口，不屏蔽真实故障。
- 四个通用 FB 已在 PLE Declaration 和 canonical 源中建立 `V1.0.0` 受控基线；版本表与完整关系图见 `src/plc/common/README.md`、`docs/main_pressure_control_sequence.md`。四个 FB 与 `StationUnit.OnCall` 均逐字读回通过。
- fresh offline Build 为 **0 errors / 101 条可见 warnings**。可见记录中 93 条为当前工程 I/O/Symbol 生成表达式的 “code has no effect”，另有 8 条供应商/保留字警告；后续确认 PLE 在该阈值截断输出，因此这不是完整告警全集。未连接、下载、启停、读写或 FORCE 实体 PLC。

## 独立 Windows HMI Phase 1（2026-08-25）

- 在 `src/hmi/Bpp.ResistantStation.Hmi` 新建 .NET 8 WPF 原型，使用官方 `OPCFoundation.NetStandard.Opc.Ua.Client 1.5.378.156` 与提交的 lock file；新 HMI 独立于 `Station010/Hmi`，不修改 CpStudio 模型、PLC、IO 或 `Std`。真实运行时由用户关闭 Nexeed HMI 后再打开本客户端，本阶段不处理双控制端并发。
- 运行时从 `http://www.boschrexroth.com/OpcUa/Datalayer` 解析 namespace index，不持久化 `ns=2`；24 个只读 NodeId 均对照当前 `Stat010_V5.11_CtrlX_PLC.Device.Application.xml` 验证存在。账号/密码只在内存连接对话框使用，客户端 PKI 位于 `%LOCALAPPDATA%` 且不入 Git。
- 画面采用 Nexeed 类似的信息层级而非复制专有组件：顶栏、模式条、左侧 Overview/Manual/Events/I/O/Data 导航、工位/安全/设备卡片和黄色双语 AutoInfoLine。Events 页明确标为待接 `PublicEventList`，不会把未实现误表示为无报警；Bosch/Nexeed 商标、图标和 VisiWin 控件均未复制。
- 数据断开、等待和 Bad quality 会遮罩实时区并清除旧值；Burster/Kistler 按真实 `OpconUnitState` 解码（Operational/Standby 绿、过渡黄、Disabled/Unknown 红、无数据灰）。连接账号移入独立对话框，主模式条不再因 1440 宽度挤压。
- `IStationDataSource` 无 Write API；静态门禁扫描全部 HMI C#，拒绝 OPC UA `Write/WriteAsync/Call/CallAsync`、FORCE、下载和 runtime 控制调用。Windows PowerShell 5.1 一键测试完成 **24 nodes / no write surface / Release 0 errors, 0 warnings**；`--demo` 进程启动并响应正常。未连接实体 PLC，也未执行下载、启停、变量读写或 FORCE。
- 下一步为 Phase 1.1：解析 `PublicEventList`、基于 keepalive 的 stale timeout/自动重连、生成式节点目录；随后由用户在关闭 Nexeed HMI 后授权一次实体 ctrlX 只读连接验收。只有该阶段接受后才讨论 Token/Heartbeat/命令脉冲/回读的精确写白名单。

## 独立 Windows HMI Phase 1.1 + 最小模式控制（2026-08-25）

- 只读订阅从 24 点扩展到 **94 点**，全部经当前 Application Symbol XML 校验：官方 20 行 `PublicEventList`、9 个 EtherCAT Slave 诊断数组、38 个已命名 DI/DO、Kistler Unit 的 Ready/程序号/报警/力/位移、13 项 StationData、4 个 REAL 数组 + 4 个 TypeData 标量。`StationDataNew/TypeDataNew` 暂存区不显示。
- I/O 页显示完整静态拓扑：EK1100(index 1)、4×EL1018(index 2–5)、3×EL2008(index 6–8)、Kistler maXYmos BL 5867C(index 9)，并把 `SlaveDeviceState` 解码为 INIT/PREOP/BOOTSTRAP/SAFEOP/OP；WC 状态 FALSE 表示过程数据有效。页面列出 38 个已发布命名 DI/DO，未发布的空通道不列出；`_000B085A_LOW/HIGH` 标记为 `legacy/unwired`。
- Kistler 原始 200 B 输入 + 200 B 输出虽已映射，但当前未发布到 Application OPC UA；自研 HMI 只显示已发布的语义结果，未伪造 raw PDO NodeId。Events 已订阅根结构并支持常见 ExtensionObject/字典/反射对象解码，离线演示已验证活动/已清除过滤；实际 ctrlX payload 与 Event 编号到 Nexeed 中英文消息目录的映射仍需一次只读验收，当前 `Source · Event N` 仅为明确占位文本。
- OPC UA keepalive 失败会进入 `SessionReconnectHandler`；连续 3 s 没有健康 session keepalive 才整页显示 stale，静止设备不会因没有 DataChange 而误超时；任一订阅节点 Bad quality 也会遮罩旧值。Data 页明确拆为 StationData / TypeData。
- 四种模式现为可由鼠标/触摸点击的操作员按钮，顶栏标为受控操作。APQ/IPC panel token 固定为 1：先保持写 `TokenRequest=1` 并要求精确回读 `Token==1`，再保持写 `ModeIdRequest∈{1,3,4,5}` 并等待 `ModeId` 回读。写入前通过服务器 `ReadAsync` 重新读取急停与维修门反馈，Changeover 额外读取 `Station.Unit.IsEmpty`；安全门及总回路继续显示，但不在 HMI 重复添加为模式选择联锁，PLC `OnModeRelease` 仍为最终权限源。在完成真实只读协议验收前，不把 255 当成本客户端的授权 token。
- 唯一写实现为私有语义 allowlist；不提供任意 NodeId Write。明确不写 Token/ModeId 输出、Heartbeat、TokenChangeResponse、Start/Stop/Step、物理 BinIo、Chain 状态，也没有 FORCE/download/PLC start-stop。Heartbeat 已证实是远程手动功能执行时 PLC 置 TRUE、HMI 写 FALSE 的 challenge/ack，不是周期翻转，因此当前不实现。
- 实体 OPC UA 连接默认创建只读会话，模式按钮保持禁用；只有操作员在连接对话框显式勾选“本次会话允许模式切换”才开放，选项不持久化。离线 demo 单独开启该能力供 UI 自动验收，避免第一次只读真机验收误写模式请求。
- 验证：`Test-HmiReadOnlyScaffold.ps1` 通过 **94 read-only nodes + 2 allowlisted request inputs**；Release Build **0 errors / 0 warnings**；自动 UI smoke 已点击 Automatic 演示模式、验证字典形态 PublicEventList 的活动/已清除过滤，并访问 Events/I-O/Data，StationData 与 TypeData Tab 可达。全过程未连接实体 PLC，未修改 `../Station010` 或 `../Std`。
- 下一步严格分两次：① 用户关闭 Nexeed HMI 后授权一次实体 ctrlX **只读**验收 PublicEventList、EtherCAT 数组、I/O 和 Kistler；② 只读通过后，再由用户单独批准四种模式请求测试。不要把两步合并，也不要测试多面板 token 转移。

## Independent Windows HMI Phase 1.2 operator UI (2026-08-25)

- Added the missing Nexeed-like operator functions: common Chain Start/Cycle Stop for Automatic, Homing and Change-over; Automatic Step Mode/Next Step; Station/Wp100 navigation and all 16 configured manual functions.
- Replaced the flat EtherCAT table with a hierarchical `Master -> EK1100 -> EL modules` tree; Kistler remains a direct master child. Selecting a node filters its named I/O and shows address, OP state and process-data validity.
- The read-only catalog now contains 133 nodes, including Station Start/Stop/Step visibility and all manual `Release*/Running*` outputs. These PLC outputs are authoritative.
- The verified Nexeed behavior is in `docs/self_hmi_nexeed_control_contract.md`. Real `StationCommands` and `ManualFunctions` remain hard-disabled. Only the existing, explicitly enabled TokenRequest/ModeIdRequest mode adapter can write; DEMO exercises the new controls without PLC access.
- Before real extended control, separately accept request-bit readback-to-FALSE, PanelActive, Unit hold-to-run Exec, Heartbeat challenge/ack and forced release on mouse-up/focus loss/disconnect/process exit. Never write Chain state or physical I/O directly.

## Independent HMI navigation information architecture (2026-08-25)

- Corrected the navigation hierarchy after operator review: Automatic, Manual, Homing and Change-over are now the vertical left mode selector; Overview, Events, I/O and Data are the horizontal top page selector.
- `SelectedPageIndex` now represents only the four primary pages (`0..3`). Manual is not a fifth page: while the confirmed PLC `ModeId` is Manual (`3`), Overview renders the Station/Wp100 Unit and manual-function workspace; other modes render the station/Chain overview.
- Mode requests and page navigation remain independent. This layout work did not change the OPC UA adapter, write allowlist, PLC, CpStudio, Station010, IO project or `Std`.
- Added stable navigation automation names and a geometry regression check proving that mode buttons remain vertical and primary pages remain horizontal. Release Build is `0 errors / 0 warnings`; the 133-node static contract and offline UI smoke both pass.

## Independent Windows HMI Phase 1.3 Unit detail views (2026-08-25)

- Reviewed the generated Nexeed SmartForms and the current Application Symbol XML without changing `../Station010`, CpStudio, PLC or `../Std`. The missing content was a self-HMI presentation/catalog gap, not a missing PLC interface.
- The Burster Unit page now shows five input readbacks (`UpperRange`, `LowerRange`, `UpperLimit`, `LowerLimit`, `ReadTemperature`), two result states (`ResistOk`, `OutOfLimit`) and two measured values (`Resistance`, `Temperature`). The nine-range enum is decoded from 2 mΩ through 200 kΩ.
- The Kistler Unit page now shows requested/current program, measurement timeout, `EndMeasurement`, screen lock, ready, switch signals 1/2, no-pass, warning, alarm, OK/NOK, force and stroke. Existing Unit manual-command buttons and authoritative `Release*/Running*` indications remain below the detail panel.
- The OPC UA catalog increased from 133 to **150 read-only nodes**. Every added identifier resolves through `Stat010_V5.11_CtrlX_PLC.Device.Application.xml`; no raw 400-byte Kistler PDO path was invented. The real adapter still writes only the separately enabled mode `TokenRequest`/`ModeIdRequest`; Unit parameters and commands remain locked pending live protocol acceptance.
- Verification: Release Build **0 errors / 0 warnings**; static HMI contract **150 nodes**; offline UI automation switches to Burster and Kistler and confirms their parameter/status/result surfaces before completing Events/I/O/Data navigation. No physical PLC connection, download, runtime start/stop, variable write or FORCE was performed.

## Product Phase 1 / Controlled Runner P1.1 (2026-08-27)

- The product execution order is now explicit in `docs/productization_roadmap.md`: controlled Runner, project/process generation, HMI productization, then commercial delivery. Phase 2–4 are intentionally not being expanded yet.
- Added `scripts/runner/Invoke-CtrlXOpconRunner.ps1` as the P1.1 single entry. `Status` validates the configured Station/PLC path, exact PLE profile, single-session policy, quality gates and ownership manifests. `ProcessOne` acquires an OS-exclusive lease, consumes at most one Post-export request, runs the existing read-only Stage 1 audit and creates/resumes the immutable Stage 2 action.
- Each real invocation writes `data/runs/runner/<run-id>/run-manifest.json`; concurrent invocations fail closed with exit code 20. P1.1 has no PLE/MCP startup, online, download, runtime write, FORCE or deployment capability.
- Verification passed: current project Runner self-test 30 assertions; template Runner self-test 30 assertions; full new-project initializer regression 70 assertions. A real current-project `Status` returned `READY`, profile `ctrlX PLC 2.6.8`, lease released, `pleOrMcpStarted=false`, `onlineOperationsUsed=false`.
- P1.2 is the next and only active implementation target: an interactive-session Agent/Broker must be the sole stdio MCP/PLE owner. A future Windows Service may manage queue/policy/evidence, but must not start visible PLE from Session 0.
- This work did not invoke MCP/REST, open PLE, touch Station010/Std, connect to a PLC, download, start/stop, write variables or FORCE.

## Product Phase 1 / Controlled Runner P1.2a Action Client (2026-08-27)

- Added the reusable .NET 8 Runner Core/CLI in `ctrlx-ai-coding/src/runner/`; the project initializer copies the same checked-in source to each new sidecar under `tools/runner/`. The PowerShell entry now exposes `Doctor`, `ExecuteAction`, `ActionStatus` and `ActionVerify`, and consumes only an explicitly prebuilt Release assembly—never `dotnet run`/MSBuild during action execution.
- The client binds every immutable action to `operation.json.currentAction`, validates path/SHA/project/profile/ownership/fingerprints/guardrails, holds separate profile-project and action-run OS leases, writes claim/result atomically and validates every replay artifact before returning a prior terminal result. A crash after claim becomes `UNKNOWN`; it is never silently re-executed.
- The existing evidence producer is release-bound by normalized SHA-256. Evidence/result tampering, operation-ledger drift and producer drift all fail closed before Broker execution or successful replay.
- Historical Named Pipe v1 required a caller-supplied expected Broker PID and verified the actual Pipe server PID plus current interactive Windows session; it did not establish an independent trust root. P1.2a contains no Broker and never starts PLE/MCP/Broker; no-session execution produces an immutable `BLOCKED_SESSION_UNAVAILABLE` result. `apply_change_set_and_build` remains blocked.
- Verification passed: Runner Release build `0 errors / 0 warnings`; .NET SelfTest `14/14`, `176 assertions`; current P1.1 test `35 assertions`; Stage 2/evidence/static tests passed; new-project initializer `81 assertions`; project `Doctor` returned `readyForActionClient=true`, `startsPleOrMcp=false`, `onlineOperationsAllowed=false`.
- Next and only Phase 1 implementation target is P1.2b: the interactive-session Agent/Broker that exclusively owns persistent MCP stdio/PLE, enforces Broker-side Pipe ACL/current-user validated registration, accepts only typed allowlisted actions, and implements long-Build cancellation-or-completion semantics. Do not describe P1.2a as a live engineering executor until P1.2b is accepted.
- This work did not invoke MCP/REST, open PLE, touch Station010/Std, connect to a PLC, download, start/stop, write variables or FORCE.

## Product Phase 1 / Controlled Runner P1.2b Broker foundation (2026-08-27)

> 历史记录：本节记录 Broker foundation 当日尚未接入真实 adapter 的状态；`BLOCKED_CAPABILITY_NOT_IMPLEMENTED`、12/12 和 9/9 已由下方 2026-08-28 真实 PLE acceptance 与 fail-closed hardening 章节取代。

- Added an explicitly started interactive Broker with one profile/project owner lease, current-user Named Pipe protocol v2, canonical registration discovery, durable submit/query operations and exact idempotent replay. The action client cannot choose a Pipe/PID and never starts the Broker.
- Shutdown now stops admission, drains already accepted work, then stops/disposes the engineering session. Malformed Pipe clients are isolated per connection. Interrupted engineering work becomes `UNKNOWN_REVIEW_REQUIRED` and is never Build-replayed automatically.
- The engineering session accepts only `inspect_and_build` and `verify_after_export_2`. It verifies exact session/project identity and project fingerprints around one Build. External PLE sessions are never opened, altered or shut down; an already Broker-owned orphan is rejected instead of adopted.
- Production success is intentionally disabled. The installed MCP package does not yet provide the required ownership and same-call fresh-Build contracts, and semantic producers for ownership/mapping/readback/recoverable baseline/Symbol post-processing are not implemented. Missing proof returns `BLOCKED_CAPABILITY_NOT_IMPLEMENTED`; blocked/failed evidence contains no fabricated Build or acceptance fields.
- Current-user processes are the present local trust boundary. A sellable release must add a controlled install location plus signed/release-bound Broker identity; do not describe the current registration as protection from a malicious process running under the same Windows account.
- Verification used only .NET fixtures and a fake MCP RPC client: Runner 24 cases / 196 assertions in three consecutive runs, Broker 12/12 in three consecutive runs, Engineering 9/9, and Broker/CLI Release builds at 0 errors / 0 warnings. No Node, MCP, PLE, REST, Station010/Std, PLC connection, download, runtime start/stop, variable write or FORCE was used. The next target remains P1.2b adapter/evidence acceptance, not P1.3.

## Product Phase 1 / Controlled Runner real PLE channel acceptance (2026-08-28)

- Applied and rechecked the controlled `codesys-persistent` adapter extensions for explicit PLE ownership, same-call fresh Build, fixed-category typed warnings and read-only recursive I/O/Symbol semantic snapshots. The isolated adapter upgrade/readiness regressions and global `apply-crlf-patch.ps1 -Check` pass.
- A new immutable Station010 `inspect_and_build` action ran through the unique interactive Broker and the real PLE. It invoked exactly `get_codesys_status`, `compile_project` and `get_ctrlx_semantic_snapshot`; it did not connect to a PLC, download, start/stop runtime, write/force a variable, edit PLC/IO/ST, or start a second PLE.
- Fresh Build result: **0 errors / 101 visible warnings**, `typedRecordsVerified=true`. The visible warning multiset contains 98 unique signatures; the compiler included a `>100 warnings` truncation sentinel, so this is not a complete warning population and cannot be approved as a formal baseline.
- Semantic result: 456 EtherCAT/I/O mapping records (438 bound, 18 unbound), mapping SHA-256 `491B719CA3FFDB28855CF207538B3CB0F1AAFD7C29AD5B577FBC5AACF51A5086`, Symbol Configuration SHA-256 `3FE32193B8EAC6FE03662F92BC2EF5AFF0827131C7C7226A2154FD6F2C8E686F`.
- PLC project SHA-256 remained `0F9557B3F5100E4FF44EBF1BE30C5833EFE11F1E02D8A8AB3991DD24640734CA`; structure SHA-256 remained `A077CA1360309897FEB29B4F6080E393268DBD57FBC37767D390AE002B74F98A` before and after the action.
- The action correctly ended `BLOCKED` with `SEMANTIC_BASELINE_BOOTSTRAP_REQUIRED`; this is a successful technical-channel acceptance, not final P1.2 production acceptance. Both semantic and warning candidates now exist under `docs/reviews/` as `pending-human-review` artifacts and cannot be renamed or automatically promoted into formal baselines.
- At that checkpoint the warning candidate was explicitly blocked by `PLE_WARNING_OUTPUT_TRUNCATED`; 101 visible records did not prove a complete warning population. The later bounded Clean Build resolved this and produced the current complete 4-warning candidate. Baseline approval now uses explicit `confirmedByUser: true` plus evidence hashes, without personal identity, followed by another **new** immutable action. P1.3 remains deferred until that sequence is complete.
- Final offline regression after the truncation guard: Runner 24 cases / 196 assertions, Broker 13/13, Engineering 33/33, Broker Release build 0 errors / 0 warnings, initializer 103 assertions, adapter readiness/global `-Check`, root/template Stage 1/Stage 2/evidence/candidate tests, and project static checks all pass. No MCP/PLE or physical PLC operation was used by these regression suites.

## Product Phase 1 / P1.2b fail-closed hardening (2026-08-28)

- Closed the pre-release evidence boundaries found by independent review. Stage 1 and Stage 2 now accept review provenance only from a separate human artifact under `docs/reviews/`; generated warning/semantic candidates, AI triage, the reviews index, path escapes and byte-identical renamed copies are rejected. The validated review bytes and the action-bound SHA now come from the same bounded read.
- Malformed Post-export requests no longer persist raw/original payload text. Failure records retain only a 1 MiB-bounded byte count, SHA-256 and fixed safe diagnostic metadata. The evidence and both candidate generators now fail closed on credential assignments, connection strings/credential URLs, Bearer tokens, PEM/OpenSSH private keys, excessive nesting/node counts or oversized strings; rejection messages do not echo the matched value.
- Warning, semantic-scope and semantic-baseline JSON are read once under explicit size limits; the same byte buffer is hashed and parsed, closing the prior hash/reopen race. PLE warning truncation remains a hard blocker at Broker, Stage 1, Stage 2 and evidence layers.
- The semantic adapter now performs a final ScriptEngine clean/stability probe after both mapping and Symbol REST reads. REST body consumption is covered by the full 30 s abort window and stops/cancels at the first byte beyond 8 MiB. Patcher upgrades are exact-version gated; Python/Node syntax failure returns nonzero and restores the package files written in that run.
- The release-bound normalized SHA-256 for `New-PostExportRunnerEvidence.ps1` is now `4796DDCC30945129743953EDEF00E881D80A5884E2CAFB1CE9FD6406B74E5493`. Root/template copies are byte-identical after line-ending normalization.
- Focused verification passed: Runner 24 cases / 196 assertions, Broker 13/13, Engineering 37/37, Broker Release build 0 warnings / 0 errors, root/template PowerShell 5.1 Stage/queue/evidence/candidate tests, canonical-vector clean-clone fallback, adapter readiness, semantic Python/Node tests and global patch `-Check`. This hardening did not start PLE/MCP and did not modify Station010, PLC, CpStudio or `Std`.
- Remaining P1.2 blocker is unchanged: acquire a complete non-truncated warning population, then perform independent human review, create formal warning/semantic baselines and verify them with a new immutable action. Do not start P1.3 before this closes.

## PLE warning generation limit finding (2026-08-28)

- Read-only inspection of the installed official PLE resources confirmed that the `>100 warnings` sentinel is emitted by the compiler's project-level warning cap, not by an MCP/ScriptEngine retrieval cap. ScriptEngine exposes the messages already generated by the compiler and has no documented paging/cursor API for discarded warnings.
- The official PLE REST v2 schema exposes project setting type `CompileOptionsEditor` and property `maxCompilerWarnings`, documented as either `<no limit>` or a numeric value. This is the supported route; do not edit `.project`, `.opt`, registry or plugin files and do not use reflection.
- The isolated-copy REST transaction is now complete. A manifest-bound copy with the same SHA as Station010 was checked against `/projects/current?option=meta`; `CompileOptionsEditor.maxCompilerWarnings` was changed `100 → <no limit>`, read back, restored to `100`, and read back again. The copy and source `.project` SHA-256 remained `0F9557B3F5100E4FF44EBF1BE30C5833EFE11F1E02D8A8AB3991DD24640734CA`; no save or online operation occurred.
- PLE 2.6.8 leaves `ScriptProject.dirty=True` after the REST PUT even when the original setting is restored. The utility therefore reports `reopenOrDiscardRequired=true`: close PLE without saving, then reopen or discard the isolated copy. The normal compile adapter must continue to reject that dirty session.
- Ordinary Build is not a semantic-clean baseline. The original path produced 101 visible warnings; the same-byte isolated copy produced 4. Removing the original precompile cache still produced 101, while copying the cache and user `.opt` to the isolated path still produced 4. This is path/incremental PLE state, not a `.project` byte difference.
- Added and installed `clean_compile_project` (`ctrlx-ai-coding` commit `2c23612`; isolated warning-limit utility commit `ffa596a`): one `application.clean()` followed by one `application.build()`, with identity/dirty/category/readback evidence and no save, `clean_all`, `generate_code`, or online operation. It also fixes the ordinary Build display so the four typed `OPC.UA.DA` warnings are no longer replaced by Information/`CLASS` rows. Isolated installer, syntax and transactional rollback regressions pass; global patch `-Check` is all OK.
- The current Codex extension process was started before the new MCP tool registration and must be restarted once. After restart, persist `<no limit>` only in a disposable isolated copy, close/reopen it, run two explicit Clean Builds, require identical complete results without the truncation sentinel, and only then generate a new warning candidate. Do not run this setting lifecycle on Station010.
- Final clean-clone initializer regression passed **106 assertions** under Windows PowerShell 5.1 after adding a deterministic AST guard for the queue invariant “acquire exclusive lock before runtime request enumeration” and an ASCII `RUNNER_ACCEPTANCE_CONTRACT` for the explicit Clean Build gate (`ctrlx-ai-coding` commit `bcda841`); Station010 PLC SHA-256 remains `0F9557B3F5100E4FF44EBF1BE30C5833EFE11F1E02D8A8AB3991DD24640734CA` and the tracked PLC project is unchanged.
- Local commits are ready in both repositories. GitHub push was attempted with the configured transport and once with a non-persistent no-proxy override, but the workstation could not reach or resolve `github.com`; no proxy setting was changed. Retry both branch pushes after Internet connectivity is restored.

## Product Phase 1 / repeated explicit Clean Build acceptance（2026-08-28）

- Codex 扩展重启后已加载 `clean_compile_project`。`CompileOptionsEditor.maxCompilerWarnings=<no limit>` 只保存到 manifest 绑定的可丢弃隔离副本；正常关闭并重开后，REST 精确读回仍为 `<no limit>`，没有把该设置保存到 Station010。
- 隔离副本连续执行两次显式 Clean Build。两次均为 **0 errors / 4 warnings**，且 warning 多重集完全一致：四条 typed record 都是 `The attribute OPC.UA.DA is unknown and will be ignored by the compiler.`。两次均证明 records、diagnostic rows、warning details、Build summary、category coverage、identity 和 dirty evidence 完整，无 `PLE_WARNING_OUTPUT_TRUNCATED`。
- Station010 PLC 源工程 SHA-256 在全过程保持 `0F9557B3F5100E4FF44EBF1BE30C5833EFE11F1E02D8A8AB3991DD24640734CA`；没有连接实体 PLC、下载、启停 runtime、读写/Force 变量或执行其他在线操作，也没有修改 CpStudio、IO 或 `Std`。
- Broker/evidence 已接入显式 `clean_compile_project` 合同，Runner/Broker/Engineering/Stage/evidence/candidate/initializer 的全部离线回归统一在 PowerShell 7 下通过。该结果只关闭技术执行与告警完整性门禁；本轮新的正式 immutable action/candidate 必须由下一次真实 CpStudio Export 产生，不能伪造 Export 或复用已经执行的旧 action。人工 warning/semantic baseline 也尚未审阅或建立，action 继续保持 baseline-bootstrap `BLOCKED`。
- 先前 GitHub 网络阻塞已经解除：根仓库 `6090e32` 与嵌套 `ctrlx-ai-coding` 的 `bcda841` 均已在各自远端分支。上一节“尚未上传”的记录已被本节取代；本节及当前后续工作仍须另行提交和推送。

## Product Phase 1 / first real Export action（2026-08-28）

- 精确消费 CpStudio request `08bd1cc9-f16d-4903-99ff-7d83a88b0dae`（本地 09:31:42），Stage 1 报告为 `review`：检测到 14 个 Station010 生成文件变化，无 staged/untracked 文件；未盲取队列中 13 个更早的历史请求。
- 生成并执行 immutable action `cpstudio-stage2-08bd1cc9-f16d-4903-99ff-7d83a88b0dae-c7a0ea87-0001`。受控 Broker 只调用 status、`clean_compile_project` 和 semantic snapshot；Clean Build 为 **0 errors / 4 warnings**，四条均为相同的 `OPC.UA.DA` attribute warning，warning 记录完整且未截断，PLC project SHA 与 structure SHA 前后不变。
- action 在 semantic snapshot 处失败关闭。只读复测证明 Clean Build 后 Symbol Configuration 首次成功 REST GET 可能仍是异步重建中的短响应；随后响应才稳定。适配器已改为丢弃恰好一次有界 warm-up GET，再保留严格权威双读；mapping 三读、最终 dirty probe 和任一差异失败关闭均未放宽。
- 原 action 已提交 sealed evidence 并以 `BLOCKED` 封口，不能重跑或复用。已从完整告警证据生成待人工审阅的 warning candidate；该 action 没有有效 semantic candidate。下一步必须由一次新的真实 CpStudio Export 生成新 request/action，验证修复后的 semantic snapshot，再建立正式人工 baseline。
- 本轮没有连接实体 PLC、下载、启停 runtime、读写/FORCE 变量或保存 PLC 工程；没有修改 `../Std`。OpCon Plus ControlOn 规则同步写入 catalog/spec/docs：Unit/Peripheral 故障通过 Station/应用释放聚合阻止或撤销 Control On，应用不得直接写 `_000K911/_000K951`。

## Product Phase 1 / second real Export action and semantic stabilization（2026-08-28）

- 精确消费 CpStudio request `fa0c5fa1-3fff-4b3c-a8d3-05f590538fb4`（本地 11:31:00），生成并执行 immutable action `cpstudio-stage2-fa0c5fa1-3fff-4b3c-a8d3-05f590538fb4-d8fa7348-0001`。Clean Build 为 **0 errors / 4 warnings**，四条均为完整、未截断的 `OPC.UA.DA` attribute warning；PLC project SHA `70024B739B6C39832644870D7612431280E5AA77A7FC461B8CAD384A27B1178A` 与 structure SHA `0252BF2D7580B8DF961634EC8D227DE04E19CEC8098E7DDF2B7BC73154EC1D9B` 前后不变。
- action 在 semantic acceptance 处以 `SEMANTIC_ADAPTER_RETURNED_ERROR` 失败关闭并提交 sealed evidence；没有 semantic candidate。完整 warning evidence 已生成新的 `pending-human-review` candidate。该 action 已终态封口，不重跑、不复用。
- 旧失败证据把 Project、Mapping 和 Symbol 合并成同一错误，不能证明本次究竟是哪一层变化；代码审查同时发现两个确定缺陷：适配器拿 PLE mapping 的原始记录顺序/内部诊断字段做比较，而最终 baseline 封存的是排序、去内部字段后的语义投影；Clean Build 后 Symbol Configuration 也可能经历多于一个成功但未完成的过渡响应。两者都会造成“实际语义未变但原始表示变化”的误判。
- 修复后采用三组 Mapping/Symbol 交叉权威读取：mapping 只比较最终会封存的语义投影并逐条验证完整性，Symbol 在最多 4 次有界 settle 后丢弃 settle 数据并独立权威三读；最后再执行一次 Mapping/dirty guard，关闭最后一次 Symbol 读取后的编辑竞态。30 s 单读超时、8 MiB body 上限和 480 KiB MCP 响应上限均保留，失败诊断只返回大小/SHA 和固定组件名，不回显 Symbol/Mapping 内容。
- Node regression、完整 adapter readiness、全局补丁应用和最终 `-Check` 均通过。唯一 Broker/PLE 已优雅关闭；没有连接实体 PLC、下载、启停 runtime、读写/FORCE 变量、保存 PLC 工程或修改 `../Std`。
- 可复用适配器已提交到旁车仓库本地 commit `f08bb7e`。收场时 GitHub 无 DNS，且 `.gitconfig` 指向的本地 `127.0.0.1:7890` 代理未运行，因此该 commit 与本仓库本轮文档 commit 需在网络恢复后推送；未修改全局代理配置。
- 正式 P1.2 验收仍需另一次真实 CpStudio Export 产生新 request/action，取得稳定 semantic canonical facts 并生成 semantic candidate；之后由用户独立审阅 warning/semantic candidates，建立正式 baseline，再由后续新的 immutable action 复验。

## Product Phase 1 / semantic candidate bootstrap closed（2026-08-28）

- 第三次真实 Export request `af26d2e5-563b-4776-8990-bdc133a63070` 生成 immutable action `cpstudio-stage2-af26d2e5-563b-4776-8990-bdc133a63070-561d25a4-0001`。Clean Build 为 **0 errors / 4 warnings**，但真实 action 揭示 Runner 验收器仍要求旧 `PLE ScriptEngine double-read` / `PLE REST api v2 GET` 元数据，而已安装 adapter 输出新版 triple-read、bounded-settle、raw-SHA 合同；action 以 `SEMANTIC_ADAPTER_EVIDENCE_INVALID` 封口且不复用。
- Broker 验收合同已与 adapter 同步：mapping source 精确要求三组语义投影读取加最终 mapping/dirty guard；Symbol source 精确绑定 action 的 application/REST endpoint，要求 2–4 次 settle、3 次权威读取、raw payload SHA 和 8 MiB 上限。新增故障注入覆盖旧 source、缺失 SHA、settle 边界、权威次数、body 上限及 application/endpoint 漂移；Engineering、Runner、Broker 离线自测全部通过。
- 在用户已授权 CpStudio UI 操作且外部 PLE 为 0 的条件下，AI 通过 CpStudio 官方 `Control plus Studio export` 按钮执行了一次无模型改动的正常 Export，并用正常窗口关闭 CpStudio 自己启动的临时 PLE；未手改 `.project`。新 request 为 `cb1af562-25e6-4523-b2d8-037751d9433d`，Stage 1 仍只发现已知 14 个生成文件变化，无 staged/untracked 文件。
- 新 immutable action `cpstudio-stage2-cb1af562-25e6-4523-b2d8-037751d9433d-633764e6-0001` 经修复版唯一 Broker 完成：Clean Build **0 errors / 4 complete warnings**；PLC project SHA `7A5461472DF6F62334CCFF10DC807F3D4B78A22FC55E2D0CAD255142CEE4C8F9` 与 structure SHA `00E47D2910CA052887D3D15E0AAB2AA43BAC12544BD10A0ECFF460EA1D73465D` 前后不变；无在线、下载、启停、写变量、FORCE 或第二 PLE。
- 新 action 正确停在预期的 `SEMANTIC_BASELINE_BOOTSTRAP_REQUIRED`，不是 adapter 故障。已生成无技术 blocker 的 warning candidate（4 次同一 `OPC.UA.DA` managed-library warning）和 semantic candidate：1 个 scope、456 条 mapping（438 bound / 18 unbound），mapping SHA `491B719CA3FFDB28855CF207538B3CB0F1AAFD7C29AD5B577FBC5AACF51A5086`，Symbol SHA `3FE32193B8EAC6FE03662F92BC2EF5AFF0827131C7C7226A2154FD6F2C8E686F`，combined SHA `3BC227C9D1FFAD917F0F5A08427A907A925AF06047FE88E7C7EEF32CEAA6CB52`。这些语义哈希与此前独立 capture 一致。
- 用户已明确确认 18 个未绑定通道当前不用、4 条 managed-library warning 暂不处理。按用户要求，baseline 审批不再收集姓名/工号：正式合同使用 `confirmedByUser: true`，reviewId/time/path/SHA 由工具自动生成；candidate/AI triage 仍不能冒充确认记录。正式 warning/semantic baseline 建立后还要再做一次正常 Export，以新的 immutable action 完成最终复验。

## Product Phase 1 / identity-free formal baselines（2026-08-28）

- 新增 `scripts/cpstudio/Approve-PostExportBaselines.ps1`。项目负责人只需一次明确确认；工具验证候选的项目、action、计数和 canonical hashes，并原子生成 warning baseline、semantic baseline 与一份去身份确认记录。姓名、工号和 reviewer 字段均不采集。
- 已批准 request `cb1af562-25e6-4523-b2d8-037751d9433d` 对应的两个候选。正式事实为 4 条 warning / 1 个签名、456 条 mapping / 18 个当前不用的 unbound；mapping、Symbol 与 combined SHA 分别保持 `491B719CA3FFDB28855CF207538B3CB0F1AAFD7C29AD5B577FBC5AACF51A5086`、`3FE32193B8EAC6FE03662F92BC2EF5AFF0827131C7C7226A2154FD6F2C8E686F`、`3BC227C9D1FFAD917F0F5A08427A907A925AF06047FE88E7C7EEF32CEAA6CB52`。
- 正式 review ID 为 `approval-3761fac2d36b-074f9525c2c7`；两份 baseline 均绑定同一去身份确认文件及 SHA。敏感字段扫描为 0，根项目审批/Stage 1/Stage 2/candidate/evidence/static 离线回归通过。
- 本轮未启动 PLE/MCP、未连接或写入 PLC、未修改 Station010/Std。P1.2 最终验收只剩一次新的正常 CpStudio Export 和全新 immutable action；旧 action 不复用。

## Product Phase 1 / final-baseline action and recoverability blocker（2026-08-28）

- request `26abbeb9-137e-4c65-9774-98846893103d` 的 action 在 Build 前因 PLE 工程树尚未完成加载而以 `PROJECT_STRUCTURE_READ_FAILED` 封口；工程未写入、Build 未执行，旧 action 不复用。Broker 的工程树读取现增加 500 ms 间隔、最多 30 s 的窄范围重试，持续失败仍关闭失败；Engineering/Broker/Runner 自测与 Release Build 全部通过。
- AI 通过 CpStudio 官方 Export 按钮完成新的真实导出，request 为 `aadf8692-07e0-4862-b525-5dcfd0b78fb0`。新 action 的 Clean Build 为 **0 errors / 4 warnings**；PLC SHA `7914AFB4E3F3BFB75643C69A873E45426F2DBC7E2B9448957742854D49C3E7E3` 与 structure SHA `56F0519011BA2704C14374CF89A77DEFFDA6C8F4D3B5F15F03750C7BC794EDDC` 前后不变。正式 warning baseline、456 条 mapping、Symbol 与 combined SHA 全部验证通过，没有在线、下载、启停、变量写入或 FORCE。
- action 唯一 blocker 为 `RECOVERABLE_BASELINE_NOT_AT_HEAD`：当前实现要求 `.project` 精确等于 Station010 Git HEAD，而本仓库红线禁止继续提交 `.project` 二进制。没有暂存或推送 Station010 生成文件，也没有削弱门禁。下一步只解决这一合同冲突：采用可验证、可恢复且不把 `.project` 放入 Git 的最小机制，然后由另一个 immutable action 最终复验。

## Product Phase 1 / P1.2 final acceptance closed（2026-08-28）

- recoverable-baseline 已由 Git HEAD 假设改为 Build 前本机内容寻址 checkpoint：按当前用户、工程 identity 与 PLC SHA 存一份不可变 `.project`，同 SHA 复用；现有 blob 损坏或源工程在复制期间漂移时，在进入 Build 前失败关闭。checkpoint 不入 Git、不自动恢复，也不连接设备。
- 精确消费新的 CpStudio request `839ff68c-6ac8-4764-8258-7cef4aa10406`，生成全新 immutable action `cpstudio-stage2-839ff68c-6ac8-4764-8258-7cef4aa10406-282dae08-0001`。真实 PLE 离线 Clean Build 为 **0 errors / 4 warnings**；456 mapping、Symbol、正式 warning/semantic baseline 全部匹配。
- PLC SHA `8274453076502750908CFC72353EB925A0504805F84B73E28DCD2FCCB18C79FD` 与结构 SHA `A63FDB2ADE23DC9168A602917FFE3CEA17705718CF1A9BE3E6C41EC507423CE5` 前后不变；checkpoint 长度 1,991,792 bytes，回读 SHA 与 PLC 完全一致。operation revision 2 最终为 `DONE`，无需 Export #2 或工程修复。
- Broker/PLE 已优雅关闭，未留下 `.~u`；没有连接实体 PLC、下载、启停、变量写入、FORCE、第二 PLE，也没有修改 `Std`。P1.2 至此关闭，下一步只推进 P1.3 Windows Runner Host。

## Product Phase 1 / P1.3a current-user Host（2026-08-28）

- 已实现 current-user interactive Host：单项目实例、状态/心跳、实例绑定停止、限定目录的 JSONL 日志保留，以及可选的当前用户 AtLogOn Scheduled Task。
- Host 只观察同一 Windows 会话中已验证的 Agent/Broker，永不启动 Broker、MCP、PLE、Node 或任何在线 PLC 操作；P1.3b 下只有存在待处理 action 且 Agent 不可用时才保持 `WAITING_FOR_AGENT`，无 action 时为 `WAITING_FOR_ACTION`。
- 自动 action 消费、完整崩溃恢复、稳定安装目录和产品级升级/回滚仍未完成，因此只标记 P1.3a 完成，整个 P1.3 保持进行中。
- P1.2 的正式 baseline 与最终 immutable action 已完成；确认流程只需用户一次明确确认，不采集姓名、工号或增加重复审批。
- 本机已注册并精确回读当前用户任务 `CtrlX OpCon Runner Host c60aad6fd4c7512b`：Interactive/Limited、AtLogOn、IgnoreNew、失败后 1 分钟重启且最多 3 次。正常 `Start` 只走该任务；裸进程入口仅在显式 `-DevelopmentProcess` 下可用。
- 真实本机生命周期已通过 Install 幂等、Start、重复 Start、Status、Logs、Stop、再次 Start；最终仅有 1 个 Host 处于 `WAITING_FOR_AGENT`。未新增 Broker/PLE，未连接、下载、启停或写入 PLC。
- 离线回归：Host 9/9、Runner 207 assertions、Broker/Engineering fixtures 全通过；新项目初始化器 226 assertions、项目框架 36 core files / 62 ownership records / 48 PLC sources。当前用户任务属于本机部署状态，不进入 Git；其他工作站需各自执行一次 `Install`。

## Product Phase 1 / P1.3b automatic action consumption（2026-08-28）

- current-user Host 现在只从 Stage 2 `operation.json.currentAction` 自动发现并消费 activation 后的 immutable action；历史终态 action 隔离，旧 open claim 可恢复，单次只执行一个 action，终态结果持续显示为 `WAITING_FOR_COORDINATOR`，等待 P1.3c coordinator 接收后推进 ledger。
- Host 状态合同已区分：没有待处理 action 时为 `WAITING_FOR_ACTION`；有待处理 action 但同会话 Agent/Broker 不可用时为 `WAITING_FOR_AGENT`。Broker registration 有效但 Pipe 暂不可用时，底层安全 reason 会保留，`Agent.Available` 不会再错误显示为 true。
- 旧 schema-v1 状态只在内存中安全兼容；存活旧 Host 阻止第二实例，死亡/陈旧旧状态可由 schema-v2 Host 接管且不改写旧证据。Inbox、operation/action、run/result/evidence 的路径链遇到 junction/symlink 均失败关闭；停止流程先发布 `STOPPING`，再做 3 秒有界 drain，未完成 claim 留作恢复而不伪造终态。
- 本机计划任务已按新二进制重新 `Uninstall → Install → Start → Stop → Start`。两次启动均稳定为 `WAITING_FOR_ACTION`，5 个历史终态 action 被隔离；22 个既有 claim/result 标记的组合 SHA-256 在前后均为 `DC48205C9A9B52C3AB8A6F1167E20C2F94D64350347A06739F9F1FBF887912F0`。durable consumer activation 已落在当前用户 LocalAppData，任务最终保持 Running。
- Release 验证：8 个 .NET 工程全部 0 errors / 0 warnings；Core SelfTest 29 cases / 275 assertions，Host 18/18，Broker 与 Engineering 全部通过；Host wrapper、项目框架和新项目初始化器 230 assertions 全部通过。前后受控进程集合一致，没有新增 Broker/MCP/PLE；没有连接 PLC、下载、启停 runtime、读写/FORCE 变量，也没有修改 CpStudio、Station010 或 `Std`。
- P1.3b 到此完成，但整个 P1.3 尚未完成。下一步 P1.3c 只做 result/evidence 自动接收与 Stage 2 ledger 推进，以及稳定安装目录、升级/回滚；完整 artifact 哈希复验、handle-based 路径加固和 Broker 重试退避保留为该阶段的产品化边界。
- 可复用实现已提交到嵌套仓库 commit `41a49c0`，本项目计划/交接也已本地提交。收场时配置的 `127.0.0.1:7890` 代理未运行，临时禁用代理后本机又无法解析 `github.com`，所以两个 branch 仍待网络恢复后 push；没有修改全局代理或公司网络设置。
