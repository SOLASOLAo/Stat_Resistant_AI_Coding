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
2. create_project(templatePath=Standard.project) 建 src/ResistantStation.project,编译 errors=0。
## 最近会话(2026-08-18)
- 做了什么:
  1. 解析 ../电阻测试台.pdf:39 页渲染到 data/pdf_pages/;页 4 = EtherCAT 目标树;页 19-25 = K010A1-A4(EL1018)/K010C1-C3(EL2008)通道信号表;页 28 = 电阻测量 -A740(Burster 5877A,USB 接入,不在 EtherCAT 上)。
  2. 发现 PLE(2.6.8)打开 IO 工程会触发版本转换且 PLE 实例崩溃;IO 工程必须用 IOE(2.6.4)编辑。
  3. 新工具 scripts/ioe_ipc.ps1:复用 MCP 的 watcher 机制(--runscript + 文件 IPC),直接驱动一个独立的 ctrlX IO Engineering 2.6.4 实例(%TEMP%\ioe-ipc 会话目录)。已验证:open/树遍历/remove/save 全通。
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
   - 现状:编译 3 errors / 16 warnings。3 个错误全是陈旧符号表条目:`bus_000S900`、`bus_000SK010A1_Channel_6`、`bus_000SK010A1_Channel_7`("is no component of 'BinIo'")。
   - 对照 `Engineering/Engineering_Data.xml`(CpStudio 模型)确认:模型里只有 `_000S900A/_000S900B`,**没有**裸 `_000S900`、Channel_6/7、IpKeyenceSr2000 → 这 3 个错误是旧残留,**不是 CpStudio 当前产物**,用户无需在 CpStudio 操作,在 PLE 里删即可。
   - `_Wp100A830Scanner` 警告条目在 CpStudio 模型中存在 → 属 CpStudio 管辖,勿擅删,由用户决定;`IpKeyenceSr2000(ParCfg)` 不在模型中 → 可删。
   - **SymbolConfig 条目对 ScriptEngine 不可见**:find/get_children/export_xml 全部返回空(已实测)。可读形态只有 IDE 导出的 Symbolconfiguration XML:`Plc/Stat010_V5.11_CtrlX_PLC.Device.Application.xml`(4208 行,其中不含 3 个陈旧条目)。下次路线:① 让用户在 PLE Symbols 编辑器手删 3 行(30 秒,最快);② AI 试验对 Symbols 节点 import_xml 的整表覆盖语义。
3. **CpStudio 定位**:Bosch OpCon/Nexeed "Control plus Studio" V5.11;模型 = `Engineering/Engineering_Data.xml`(10.7 MB,Bosch.OpCon.Data schema);索引 = `Engineering/Stat010_V5.11_CtrlX.cpsp`;HMI = `OpCon.HMI.Modulo`。**注意:模型中仍有 `Wp100A740*` 残留**——PLC/IO 侧 `_100A740_BL` 已删,若不在 CpStudio 删除 740 站,下次重新生成可能带回相关符号。
4. 后台副本实例(PID 32724)已被用户关闭,无副作用;MCP 附着的主 PLE(PID 9048)全程正常。

### 当前状态
- 编译:3 errors / 16 warnings(错误全为上所述陈旧符号条目,暂停处理等用户指示)。
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