# HANDOVER.md — 会话交接

> 目的:让下一个 AI 会话(或人)3 分钟接手。**每次会话结束前更新本文件**。

> **2026-09-10 本轮发布范围**：用户在一轮自动完成后明确要求“先上传GitHub”，因此本轮将当前AI可读源码、规格/归属清单、应用脚本、离线测试及现场记录提交至现有`feat/self-hmi-poc-20260824`分支，不标记正式稳定版。发布前Kistler/Burster源码契约、SFC事务、工程框架检查及18项离线协议测试通过；工程计划发现过期，使用现有Project Pack Build刷新后Check通过。仅本地生成清单变化，无新PLC编译/下载/动作。旁级Station010集成仓库的21项模型/配置/加密工程改动不在这次源码发布范围，保留本地，未把凭据候选配置或`.project`混入此仓库。是否已推送以Git远端核验为准。

> **2026-09-10 16:59 最新：一轮左/中/右自动流程完成**。用户明确要求“直接跑自动过程”，AI确认当前MP001/Ready正常/无红色报警后，选择自动并于16:57:18.420只点击一次HMI Start。16:57:28提示等待左侧实体启动按钮；fixture移动和实体按钮由现场操作，AI未模拟/强制输入。16:58:27观察安全门打开提示，16:58:51进入右侧测量，16:59:12显示“测量完成”、Station in home position绿色、Start恢复可用/Stop禁用。抽样观察未见红色报警，仅余既有PartCounter服务read timeout。结合父链完成入口，确认本轮完整流程结束；未逐项读取Left/Middle/Right数值及OK/NOK，也没有连续力趋势、第二轮或重启稳定性验证，不等于产品质量及长期稳定性验收。本轮无PLC代码修改/下载、无消警强行续跑、未额外启动第二轮、未推送GitHub。保留用户仅勾选MP000 Active后的0/1勾选及生产TypeData程序1。下方“完整自动仍未测试”是历史状态，已被本条取代；下一步只核对三位置结果及后续稳定性。

> **2026-09-10 16:54 最新：仅勾选 MP000 Active 后手动选程恢复**。用户明确未配置/复制/修改0号程序内容，只把MP000也勾选Active（现0/1均勾选），报告HMI Set program=0和1均正常。AI于16:54:06只读复核IPC：实际Program number=1、目标1、Ready绿、Alarm灭、力12.91N，Manual，End measure禁用；仅余PartCounter警告。用户对两次切程的报告与AI此刻状态读取需区分，AI本轮未重复命令。这是当前组合下Active设置影响选程的有效对比结果，先保留0/1勾选，不再要求配置或复制MP0，TypeData及生产测量程序仍1。准确内部AUTO/MP时序未抓取，不能推广为全部maXYmos必须双激活。该项不需要新增PLC修改、Export、编译或下载；未推送。下一步是MP001手动Start/End及完整左中右/第二轮验收，目前只确认手动选程恢复，不能称全部自动已通过。下方“MP000未激活/需要本体恢复”的旧状态已被本条取代。

> **2026-09-10 16:39 最新现场确证：正常 MP1 经标准手动 Set program=1 后变回 MP0**。用户恢复本体 PROCESS MP001 后，AI 实读 HMI 实际1/Ready绿/Alarm灭/力值更新；随后 Manual 已选，按用户说明点击右下操作放行，16:39:05.493 仅一次 Set program=1，未测量/去皮/气缸/自动。16:39:19.785 PLE 驱动首错 `-5 / SetProg`，HMI随后实际0/Ready=false/Alarm=true。稍后展开 Unit 证实 SetProgram.ProgNo=1、Measure.ProgNo=1，实际OutImm.ProgNo=0；未发现应用Extension自定义参数复制（只有OnManRelease）。这次确有1→0操作前后对比，区别于16:16那次初始已0的-1测试；但不是扫描周期级AUTO/MP波形，不能声称闭源内部顺序已被证实。未新增PLC修改/编译/下载/推送。下一项：本体再恢复MP001后，单独受控验证MEASURE/End（不动缸），判断既有“相同程序跳过SET_PROGRAM”能否维持采力；当前未通过自动验收。用户授权的修复/下载/测试仍有效。另：用户要求延长锁屏时间，本机当前用户安全屏保通过Windows配置API由900秒改为1800秒，API与保存回读均1800，启用/恢复登录均仍1；未改Policies、睡眠或关闭安全锁定，若公司后续回写不得对抗。

> **2026-09-10 最新授权与阻点（取代下方旧的一次命令限制）**：用户已明确授权本轮修复后直接下载测试，并说明右下锁是正常手动操作放行。无需再次询问同一下载/手动测试授权；先刷新安全状态，测试先限程序选择。当前尚无经证据支持的新代码修复：公开 OOD/OSD 未找到 BL/TL 模式参数，BL 手册 AUTO=byte1.bit4、MP=byte2.bit0..3 与现场 C 照片一致，不支持直接认定报文布局错。REST 确认仍为正确 Station010 / ctrlX PLC 2.6.8；现有生成参数没有新增 Kistler 兼容项。窗口刷新后 RDP 激活连续两次失败 `failed to activate captured window`，已停止 UI 输入并请用户恢复 PLE/RDP。该轮未 Logout、改 PLC、编译、下载、发送设备命令或推送。下一项有效验证：用户安全退出自动，在仪表本体蓝色 PROCESS 页选择现有 MP001（不是打开 Setup 参数页），然后读取实际 ProgNo/Ready/Alarm；C 手册此入口要求 I-AUTO=0，但未保证本固件报警下能否成功，不宣称已修好。保持 TypeData=1，不强写 Ready/PDO，不猜测性启用/复制 MP0。详见 Kistler review 最新节。

> **MP Manager Active 语义更正**：用户追问0/1是否都应激活后，厂家5867C_012-118e-05.25手册§4.13.3/p76将Active明确描述为显示/隐藏MP。不能仅凭MP0未勾选就称它是空程序/配置无效；之前该推断撤回。仪表照片里的Inactive MP selected仍是已观察报警，但其固件行为与此勾选的关系尚未验证。不要要求0/1都勾上或改程序内容来代替根因排查。本次单次测试首错-1/SetProg有效，TypeData仍1，没有后续设备命令或配置修改。详见Kistler review最上方。

> **2026-09-10 16:16:45 单次测试已执行，首错为 -1/SetProg**：用户纠正右下锁是HMI操作放行；刷新时已放行、Manual、目标1/实际0/Alarm红。AI只点击一次Set program=1，没有再点锁/登录、没有测量或动作。16:16:59现有PLE读取 Peripheral._lastError.Number=-1、AddText=SetProg、NativeErrCode=0；不是旧-5 AUTO超时。事后SendData.Auto=false/MeasProgNo=0/Start=false，采样距命令约13s，不冒称完整时序或从未发送AUTO。只读从站状态DeviceState=8、LinkState=0、PdStatus=0、LastPdStatusError=0，力值持续更新；标准库公开文档不暴露-1的精确内部门禁。用户问0/1是否都需激活：之前照片0未激活、1已激活，无依据认定必须两者均激活，不启用空0。未改PLC/仪表配置、未编译/下载/推送。本次一次命令授权已消耗，不再重复触发。

> **2026-09-10 单次 SET_PROGRAM 测试获准但尚未触发**：用户回复“可以”，授权范围仅安全手动执行一次 Set program=1，不测量、不动气缸、不跑自动。现有 RDP 的 Kistler 页面仍显示目标1/实际0/Alarm红，Manual已选，但 Set program 灰色带锁，顶部显示登录入口；未点击灰色按钮，未绕过 HMI 放行或代操作认证。请用户完成正常登录/操作放行，让按钮可用，先不要点击。Watch3已就绪显示标准 Peripheral._lastError、_sendData.Auto及MeasProgNo；基线 Number=0、Auto=false、MeasProgNo=0、Start=false，仅为空闲基线。下一轮刷新放行和目标值后再消耗这一次命令授权，不重复索取同一授权、不重复触发。未PLC写入/编译/下载/推送。

> **2026-09-10 16:07 最新只读复核：Kistler 实际仍为 MP0，不能认定手动选程序成功**。当前在线 Station010 已包含上一轮候选修正，PLE 显示 Program unchanged；SetProgram.ProgNo=1、Measure.ProgNo=1，但 OutImm.ProgNo=0 / Ready=false / Alarm=true / ScreenLocked=false / MeasRunning=false，PlcLockActive=false。撤回“手动 HMI 消警等于成功切 MP1”的推断。稍后读取 Peripheral._lastError 已为0/附加文本空，RDP 显示 Manual、Home position No，仅 PartCounter 警告；不是故障瞬间记录或安全确认，不沿用旧 -5 当作新首错。本轮未改 PLC、编译、下载或推送。下一步须确认现场安全并获准后，仅执行一次标准 Set program=1，观察请求 MP/AUTO/实际反馈，不跑整套自动、不启用空 MP0、不强写 PDO。见 Kistler review 顶部。

> **2026-09-10 15:49 当前：Kistler 候选修正已离线编译，现场根因未闭环**。用户再次确认实际 MP000 未启用；在线读取 ProgNo=0 / Ready=false / Alarm=true / ScreenLocked=false / MeasRunning=false，Peripheral 首错 -5、AddText=SetProg；SetProgram.ProgNo=1、Measure.ProgNo=0、PlcLockActive=false。不要据默认 DeviceUnlock=true 认定持续解锁冲突；也不要把 OOD 2.0.7.0 与 PLC 库 2.0.1.0 当错版，供应包的 Library.osd 本来就要求 2.0.1.0。本次只改 CheckKistlerProgram：N045 提前把两个命令程序号都从同一 TypeData 赋值；已匹配/就绪/无报警且 Unit 空闲时不再重复 SET_PROGRAM，其他情况仍走标准命令及错误反馈，所有下压/力联锁保留。1 PUT/Save/回读通过，父声明和 SFC 未改；本次新 F11 **0 errors / 原 5 warnings**（4×C0351、1×C0373 line2378），四组相关静态/模型检查通过。副本/证据 `data/reports/plc/kistler-program-guard-20260910-154618/`；未做工程哈希、下载、运行写入或推送。用户新图 `IMG_20260910_154614.jpg` 是仪表 Fieldbus info：AUTO=byte1.bit4；MP bits=byte2.bit0..3；拍照时全0，只能证明空闲状态，不能证明故障时序。需要在安全取消自动后受控手动验证 Set program=1 及其请求/反馈，不能宣称 MP0 故障已经修好，不能启用空 MP0 或强改 PDO。详见 `docs/reviews/station010-kistler-program-20260910.md` 顶部。

> **2026-09-10 最新离线修复：Burster E1106 零错误响应误判已修，待用户现场复测**。先前只读确认 HMI `B2316 E=1106 CMD=SYST:ERR?`，仪表实际回复 `0,"NO ERROR"`，MeasurementStarts=0；旧判断仅接受不带引号格式。用户“改啊”后，经现有 PLE Logout 并确认离线，仅修改共享 SelectProgram 的完整字符串判断：保留原两种格式，补充带引号、逗号后可有一个空格的两种格式；严格只接受这四种完整零错误响应，非0/残缺/未知格式仍阻断，不做宽松数值转换。1 个实现 PUT、Save/回读通过，18 项协议/源码测试与 Burster 静态检查通过；**本次新 F11：0 errors / 原 5 warnings**（4×C0351 OPC.UA.DA、1×C0373 SymbolConfig ErrorCodes/DWord）。生成声明、socket/程序号/量程、力和运动联锁未改。只保留一份普通工程副本，未做哈希；证据 `data/reports/plc/burster-error-response-20260910-151220/`，说明 `docs/reviews/station010-burster-error-response-20260910.md`。未下载/运行写入/设备命令/提交/推送；本次无需 CpStudio Export。用户安全结束旧自动后再下载复测。Kistler 初始 Device not ready 仍需手动选 MP001 的现场限制另案保留，不能当作自动恢复已通过。

> **2026-09-10 最新离线修复：Kistler 在检查 measuring Ready 之前先选择 TypeData 程序**。新照片 `IMG20260910143803.jpg` 明确 MP000 Active 未勾选、MP001 已勾选；保留 TypeData.KistlerProgramNo=1，不启用空 MP0。此前 N045 的 `Ready=FALSE / Alarm=TRUE / ProgNo=0` 与仪表 `Inactive MP selected` 相符，原流程却把目标程序赋值放在 N051，形成程序选择前的 Ready 等待。新增 AI-owned `CheckKistlerProgram`，N045 先执行标准 SET_PROGRAM，再经 CheckUnitDone 完成握手，最后确认实际程序号、Ready、无 Alarm/MeasRunning，才进入 Burster 选程序和两条启动分支；N050/N051 另保留无 Alarm/程序号匹配门禁。N000/OnChainFinish 清理该方法状态。正确 Station010 的官方 REST 确认离线后，6 个对象已保存/回读，原 SFC 图和生成声明原样保留；本轮 AI 新 F11 **0 errors / 5 warnings**（4×C0351 OPC.UA.DA、1×C0373 SymbolConfig ErrorCodes/DWord）。只做一份工程副本和目标文本回读；未下载、未运行写入、未推送 GitHub。详见 `docs/reviews/station010-kistler-program-20260910.md`，备份/回读目录 `data/reports/plc/kistler-program-20260910-145115/`。

> **下一步仍是用户受控现场验收**：先安全结束旧自动循环，再下载本轮离线程序；验证 SET_PROGRAM 将 MP0 切到已启用的 MP1，Ready/Alarm 恢复后才启动采力/下压，再完成左中右及第二轮。标准命令能否在当前硬件 inactive-MP 锁存报警下完成切换尚未实测，不自动消警、不绕过反馈；若拒绝，保留标准事件并在安全退出自动后处理仪表。不要在仍等待的自动中手动切程序/清报警，Ready 恢复可能继续下压。本次没有 CpStudio 生成接口变化，无需常规追加 Export。

> **2026-09-10 上一批离线结果**：单连接 Burster 已接入，用户 Export #2 已完成并复核；本批新 F11 **0 errors / 5 原 warnings**，CpStudio PLC Export 输出为空，21 个驱动/绑定目标及 40 个 Run 目标零差异，56/56 I/O 匹配。尚无单连接完整现场验收；AI 未下载/动作，现场稳定后才提交/推送。不要再要求常规 Export #3、关闭已删除 Peripheral 的 AutoRange，或回退到双连接方案。独立 REST/UI 检查不等于正式 Runner 完成；详情见文末最新节。

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
- Host 后台入口已改为 Windows GUI subsystem apphost，计划任务启动时不再创建空白 Windows Terminal；`Status/Stop/Logs` 则固定通过 `dotnet + vcrunner-host.dll` 保留控制台 JSON。升级按 `Stop → Uninstall → Build → Install → Start` 完成，本机 Host 最终为 `WAITING_FOR_ACTION`，无子进程且未新增 `WindowsTerminal/OpenConsole/conhost`，22 个既有 claim/result 标记保持不变。
- P1.3b 到此完成，但整个 P1.3 尚未完成。下一步 P1.3c 只做 result/evidence 自动接收与 Stage 2 ledger 推进，以及稳定安装目录、升级/回滚；完整 artifact 哈希复验、handle-based 路径加固和 Broker 重试退避保留为该阶段的产品化边界。
- 可复用实现已提交到嵌套仓库 commit `41a49c0`，本项目计划/交接也已本地提交。收场时配置的 `127.0.0.1:7890` 代理未运行，临时禁用代理后本机又无法解析 `github.com`，所以两个 branch 仍待网络恢复后 push；没有修改全局代理或公司网络设置。

## Product Phase 1 / P1.3c technical and local acceptance closed（2026-08-28）

- Host 已完整校验 result/evidence SHA、immutable action 与 operation ledger，再调用 Stage 2 coordinator 推进 ledger。合法 `UNKNOWN`/`FAILED` 且无 evidence 时保持 `WAITING_FOR_COORDINATOR` 交给人工复核；coordinator busy 使用有界退避，畸形 ledger 失败关闭。production ingestor 默认 Host 装配已通过 6 项 fixture E2E，另以真实 ledger lock 验证 busy 路径。
- 稳定部署使用当前用户 `LocalAppData` 下包含 5 个文件的内容寻址不可变 release，并以 durable pending journal/reconcile 覆盖中断窗口。恢复验收覆盖源任务禁用、源任务已删除、`STATE_COMMITTED`，以及 wrapper 被强杀后由默认 `Start` 的窄门禁完成恢复。
- 生命周期验收覆盖新 release 升级、同版本 no-op、回滚、损坏候选拒绝，以及 deployment 状态丢失时从精确任务反推 immutable release 的安全 `Uninstall`。主 Host active release 为 `faa27c1d79415996ddcd524833160c57ea23ac63888f17b853487a81b46ab0f1`，previous release 为 `ac89b28f9a93a61c10b5bd7731c3b5b83288169a105c62eb4218a30c119f4b51`，状态为 `WAITING_FOR_ACTION`。
- AtLogOn Scheduled Task 的 action 精确指向 release exe，description 记录 release/manifest。`Install`、`Start`、`Stop`、`Rollback`、`Uninstall` 等显式生命周期路径会验证 5 个 release 文件并执行 apphost self-check；登录任务自身直接启动 exe，不做 prelaunch manifest 校验。
- P1.3c 技术实现与本机验收到此完成；Host 未启动 Broker、MCP、PLE、Node 或任何在线 PLC 操作，也未连接、下载、启停或写入 PLC。团队工作站安装、签名、受控安装包、登录前 manifest bootstrap、兼容矩阵与新电脑验收属于 P1.4，仍未完成。

## Product Phase 1 / P1.4a lean team package（2026-08-29）

- 嵌套方法论仓库新增 `scripts/runner/New-CtrlXOpconRunnerHostPackage.ps1` 和对应离线回归。发行包固定包含 `Install.ps1`、canonical wrapper/module、`package-manifest.json` 与 Host 五文件 payload；manifest 绑定八个内容文件的 path/length/SHA-256 和整体 `contentId`，安装入口在任何 lifecycle 命令前验证。
- 接收工位要求 PowerShell 7、.NET 8 runtime 与显式 AI 工程根目录，不依赖 Git、源码、SDK 或本机 build。fresh `Install` 默认只注册 release、不启动 Host；升级复用同一 Install 并保留原 running/stopped 状态；另支持精确 `Rollback`、安全 `Uninstall` 和只读 `Status`。
- 中文/空格路径、全新/空目标、非空拒绝、manifest/contentId、篡改阻断、五命令路由及两层 `WhatIf` 均通过；真实 Release 打包后的 `Status` 回读当前 Host 为 `WAITING_FOR_ACTION`。本轮未注册真实任务、未修改现有 Host、PLE/CpStudio/PLC/Station010/Std。
- P1.4a 不增加自定义 ACL，数字签名延期到商业发行或公司 IT 明确要求。独立 AtLogOn 五文件 prelaunch Bootstrap、兼容矩阵和全新团队工作站验收仍未完成，P1.4 整体不得标完成。

## Product Phase 1 / P1.4b deferred during development（2026-08-29）

- 用户明确决定当前开发阶段跳过独立 AtLogOn 五文件 prelaunch Bootstrap；不实现、不注册新的
  Bootstrap 或任务迁移，现有 Host/任务保持不变。
- 开发期继续通过 canonical wrapper 显式启动 Host；P1.4a 团队离线包仍可正常使用，fresh
  `Install` 仍默认停止。
- Bootstrap 仅在进入商业化或明确要求无人值守登录自启时恢复；兼容矩阵和新电脑验收在有团队
  工位时执行。两项均不再阻塞 Phase 2 项目目录与流程生成。

# 2026-08-29 Phase 2/3 精简交付

- Phase 2：新增 Project Pack/process schema、PowerShell 7 `Build/Check`、initializer 与 Runner
  门禁。Station010 计划为 2 processes / 35 steps / 14 prompts / 13 requirements / 9 tests；
  generated POU interfaces 全部登记为 CpStudio ownership。新 action 固定 Pack contentId、Pack/plan
  hash，并在 Host/ExecuteAction 共用校验器中逐项回读 plan sources；任一事实源漂移都会在 Broker 前阻断。
- Phase 3：HMI 升级为 schema v2 配置驱动壳；Station010 与独立 ExampleCell 均使用相同二进制，
  品牌/Overview/Manual/Mode/EtherCAT device data 不再写死在页面中。Station010 保留夹具、产品检测
  和安全回路原始诊断卡；ExampleCell 实际启动 DEMO、切到 Manual 并显示其自有夹具 Unit。未知 JSON
  字段失败关闭，真实模式控制默认关闭，模式请求超时被限定为 250–60000 ms。
- 最终离线验收：HMI Release build 0 errors / 0 warnings；两套配置加载、Station010 完整 UI、
  Project Pack、45 条 wrapper 断言、280 条 Runner 断言、Stage2 E2E 和 251 条 initializer 断言通过。
- 安全边界未改变：没有启动 PLE/MCP、没有连接 PLC、没有下载/启停/变量写入/FORCE；HMI 真机
  写白名单仍只有默认关闭的 `TokenRequest`/`ModeIdRequest`。现场 A/B 需另行即时批准。

## 2026-08-29 开发辅助 Skill 边界

- 已将 Ponytail 的唯一权威边界写入 `AGENTS.md` 第 5 节：仅作开发期减法审查，不进入产品或客户环境，也不得覆盖 ctrlX/OpCon 安全门禁。本轮未修改产品代码、PLE、PLC、`Station010` 或 `Std`。
# 2026-08-31 Station010 ePLAN DIDO description automation verified

- `scripts/ioe/New-CpStudioEplanIoAsc.ps1` now enforces the verified CpStudio
  contract: UTF-16LE BOM, CRLF, 15 TAB columns, one contiguous block per module
  and channel addresses starting at 1 without gaps. CpStudio maps by row order,
  not by the `Address` value, so this ordering guard prevents shifted I/O.
- The official importer treats every non-empty `IoDesignator` as active. An
  empty value sets `Active=false`, clears the stored name and removes its PLC
  variable reference. The first full import exposed 15 generated
  `_..._Channel_N` placeholders as unsafe because they activated unused points;
  the corrected complete ASC left all 18 unused points empty.
- The reviewed Station010 source is `specs/station010-eplan-io.csv`: seven
  modules, 56 channels, 32 DI, 24 DO, 38 active and 18 inactive. A1 channel 1/2
  Chinese descriptions are `控制上电按钮` / `控制下电按钮`. Other stations must start
  from their own complete ASC export rather than copying these signal facts.
- Official round trip completed successfully: Import → Save → Write peripheral
  and I/O designators → Export #1 → Link I/O → Build (0 errors / 5 warnings) →
  Export #2 (0 errors / 3 warnings) → final PLE Build **0 errors / 0 warnings**.
  The two Chinese descriptions propagated into HMI labels, EventRecorder and
  generated message text; 38 active / 18 inactive remained unchanged.
- `tests/ioe/Test-CpStudioEplanIoAutomation.ps1` now covers unsafe order gaps,
  the full 56-row source, 38/18 state counts, E/X content, byte contract and the
  EtherCAT master-name chain. No online PLC connection, download, runtime
  start/stop, variable write or FORCE was used; `Std` was not modified.

# 2026-08-31 ePLAN DIDO automation integrated into Project Pack

- `project-pack.json` now references the reviewed complete Station010 DIDO CSV.
  Project Pack `Build` atomically produces `generated/cpstudio-io-designators.asc`;
  `Check` regenerates it in TEMP and fails on CSV, generator or ASC drift. The
  verified artifact is 6,570 bytes with SHA-256
  `25f85082e85013b02ea933ac094697ac1ede5869152387468b4fb6f9a88d29a1`.
- The engineering plan records the source/generator/checker/artifact hashes and the
  reviewed 56 / 32 DI / 24 DO / 38 active / 18 inactive counts. The optional
  schema keeps projects without an I/O designator source backward compatible.
- Post-export Stage 1 now fingerprints the configured BusConfig and compares all
  expected channels, designators and English/Chinese descriptions with the CSV.
  A semantic mismatch yields `IO_DESIGNATOR_EXPORT_MISMATCH`; an unreadable
  export fails the request. Both stop before Stage 2. Stage 2 binds the matching CSV/BusConfig hashes into its
  immutable operation/action and rejects later drift. The real Station010
  BusConfig matched all 56 channels.
- The official human boundary remains deliberately small: Import ASC, review,
  Save, Write designators, Export and Link I/O stay in CpStudio/PLE. No Runner,
  Broker or online PLC capability was added; no `.project`, Station010 or `Std`
  file was modified by this integration.

# 2026-08-31 Station010 complete bilingual DIDO acceptance

- The reviewed CSV keeps the verified hardware facts unchanged: 56 channels,
  32 DI, 24 DO, 38 active and 18 inactive. Every active row now has a non-empty
  English description and a Chinese description; inactive rows remain blank.
- Project Pack content ID is
  `ebe1824f7dc01e697f9c5fef001af71f5e05e1360dd79841a54f6a297ce20e37`.
  The generated ASC is 6,570 bytes with SHA-256
  `25f85082e85013b02ea933ac094697ac1ede5869152387468b4fb6f9a88d29a1`.
- Post-export audits `09f0b407-639e-48e1-a83b-61c96b367b89` and
  `cbbbdddd-05dd-44c2-befe-e3e63164b444` both matched all 56 channels with zero
  mismatches and preserved 38 active / 18 inactive. Both audits were read-only
  and reported no engineering-tool launch or online operation.
- The user completed Import, Save, Write designators, Export #1, Link I/O,
  intermediate Build (0 errors / 5 warnings), Export #2 and final PLE Build.
  The final Build result was user-reported as **0 errors / 0 warnings**.
- No PLC connect, download, runtime start/stop, variable write or FORCE was
  performed. `Std` was not modified.

# 2026-08-31 Wp100 TypeData production parameters integrated

- CpStudio Export request `363c3534-47fc-49c3-bb8e-5f92bcb6b87b` added the
  CpStudio-owned `Wp100BursterRangeEnum` (INT, values 0..8) and six Wp100
  TypeData fields: upper/lower Burster range, upper/lower limit, temperature
  switch and Kistler program number. The generated POU interfaces were only
  read and consumed; no declaration was added or rewritten through PLE.
- `SqS_Wp100_Run` is now 23 Steps. N046/N047 execute and wait for Burster
  `SET_RANGE` before the press/Kistler parallel start. N051 copies the active
  Kistler program before `MEASURE`; N080 copies the active limits and
  temperature switch before `SINGLE_MEAS`.
- `TypeDataSetManagerAddon.OnCheckData` was semantically merged only inside its
  application-specific region. CpStudio's generated 0..8 checks remain; the
  application adds `LowerRange <= UpperRange` and `LowerLimit <= UpperLimit`.
- A failed enum-call attempt was corrected before acceptance to a checked
  `TO_INT` conversion between the two INT-based enums. Final PLE Build is
  **0 errors / 5 warnings**, Additional code checks **0 errors**. The warnings
  are the existing four `OPC.UA.DA` C0351 messages plus one generated
  SymbolConfig C0373 message; no new application warning signature was added.
- Feature Plan SHA is
  `92577f72164ac56e5cbae61ee788bd1663f1222d33216b17f766da0a0ff8f23d`;
  final conversion-fix Plan SHA is
  `35d70b6c2f1b8fea8aab9ef32300bc3b197566610108e447d02d56db3fef0ec7`.
  Final PlanOnly readback SHA
  `8285734b5fc0350cbb2d2899cc2b1333fef8a117dedf5dcdc1f40df3b04a6f7f`
  contains zero operations. Project Pack is now 2 processes / 37 steps /
  14 requirements / 9 tests.
- A local content-addressed `.project` checkpoint was created under ignored
  `data/checkpoints/plc/` before mutation. No PLC connect, download, runtime
  start/stop, variable write or FORCE was performed; `Std` was not modified.

# 2026-08-31 Export #2 and Nexeed dataset storage boundary

- CpStudio Export #2 request `ae821c21-bb32-4310-9a41-7606716eec51` was
  consumed by the read-only post-export audit. All 56 EtherCAT designators
  matched (38 active / 18 inactive, zero mismatches).
- Final PLE Build after Export #2 is **0 errors / 5 warnings** and Additional
  code checks are **0 errors**. PlanOnly readback remains SHA-256
  `8285734b5fc0350cbb2d2899cc2b1333fef8a117dedf5dcdc1f40df3b04a6f7f`
  with zero operations, so Export #2 did not overwrite the 23-step Run Chain
  or its TypeData integration.
- Runtime StationData and TypeData are `.dat` datasets owned by Nexeed
  DataSetAccess on the HMI IPC. Their configured folders are
  `\\%DataSetAccessHost%\OpconData$\StationData` and
  `\\%DataSetAccessHost%\OpconData$\TypeData`; the default names are
  `StationData` and `1111111111` respectively.
- The exported `Hmi/*DataSetManagerL1.dat` files define dataset fields and
  defaults; they are not the selected runtime datasets on the IPC. PLC logic
  consumes the applied `Station.StationData` / `Station.TypeData` structures
  and must not read the share or `.dat` files directly.
- No PLC connect, download, runtime start/stop, variable write or FORCE was
  performed. `Std` was not modified.

# 2026-08-31 resumable Runner and ASC-only electrical intake

- `scripts/runner/Invoke-CtrlXOpconRunner.ps1 -Command Run` is now the normal
  local entry. It reuses the existing Stage 1 audit and Stage 2 coordinator;
  the latest earlier `Run` manifest identifies the one operation that may be
  resumed. Untracked legacy ledgers are not adopted and no new state machine
  or pointer file was introduced.
- A tracked `WAITING_FOR_RUNNER` action is reported before any new request is
  consumed. `WAITING_FOR_CPSTUDIO` remains the manual model boundary. The next
  audit is bound automatically only when that tracked operation is
  `WAITING_FOR_EXPORT_2`; with no tracked operation or request the result is
  `IDLE` with `reasonCode=NO_PENDING`.
- External electrical I/O exchange is now ASC-only. The new strict intake
  converts UTF-16LE-BOM / CRLF / 15-column `E`/`X` ASC into the internal
  reviewable UTF-8 CSV; AML/XML/OHD are intentionally unsupported. Project
  Pack continues to own CSV→ASC generation and BusConfig comparison.
- Real `../AscBackup.asc` acceptance produced 56 rows, 32 DI, 24 DO, 38 active
  and 18 inactive. Fifteen exact, description-free CpStudio
  `_..._Channel_N` placeholders were normalized to inactive; 15 active rows
  were reported as lacking actual Chinese text. Wrong-channel or described
  placeholders fail closed.
- Replacing an existing canonical CSV requires the same complete
  module/address/type key set. Partial-module input or topology drift is
  rejected before the previous CSV is touched. A deliberate hardware topology
  change must first use a new CSV path and receive separate review.
- Offline acceptance passed: root/template Runner 61 assertions each,
  root/template ASC intake, existing Station010 I/O automation, root static
  framework, Project Pack Check and initializer 255 assertions. The new
  Runner/ASC implementation scripts and their paired tests are byte-identical
  between root and template. No PLE, MCP, Broker, CpStudio, IOE or
  online PLC operation was started; `Station010` and `Std` were not modified.

# 2026-09-01 CpStudio export Stage 2 closed

- Request `9cc8d375-f4ba-4368-832a-d7331d13ef6c` completed operation
  `cpstudio-stage2-9cc8d375-f4ba-4368-832a-d7331d13ef6c-d7b50493` at revision 2
  with final status `DONE`; Export #2 was not required.
- The offline Clean Build completed with **0 errors / 4 reviewed `OPC.UA.DA`
  warnings**. All 456 mapping records and the Symbol Configuration matched the
  reviewed semantic baseline; project and structure hashes were unchanged.
- The optional `get_ctrlx_semantic_snapshot_retry` audit capability is now
  accepted consistently by the Runner, evidence producer and Stage 2
  coordinator while the original three success capabilities remain required.
  This prevents a durable Broker success from remaining falsely pending after
  a read-only Symbol snapshot retry.
- No PLC connection, download, runtime start/stop, variable write or FORCE was
  performed. The engineering session was closed after evidence ingestion.

# 2026-09-01 engineering automation roadmap aligned

- Product `Phase 1–4` and CpStudio + ctrlX engineering automation `P0–P4` are
  now explicitly separate in `TODO.md`, `docs/productization_roadmap.md` and
  `docs/cpstudio_git_mcp_workflow.md`; future status reports must not mix them.
- Engineering automation **P0 Runner** and **P1 ASC-only electrical intake** are
  complete. The current implementation target is **P2 IOE topology**:
  `manifest → Plan → checkpoint → Apply → reopen/readback`.
- P3 Link I/O remains manual unless a stable supported PLE interface is proven.
  P4 waits for a copied real runtime StationData/TypeData DAT sample from the
  HMI IPC; exported HMI definition files are not accepted as substitutes.
- This update changed documentation only. It did not open or modify CpStudio,
  PLE, IOE, Station010, `Std`, or any physical controller.

# 2026-09-01 Engineering Console v0.1

- Added an independent .NET 8 WPF Engineering Console as a thin facade over
  the existing controlled Runner, Host and Project Pack entry points. It has
  Workbench, Plan/Review and Evidence pages and shows project engineering
  phases, current state, next action, the complete IOE/CpStudio/Runner/AI/PLE
  sequence, human checkpoints and the latest immutable manifest.
- The command surface is a fixed six-command PowerShell 7 allowlist: Runner
  Status/Run, Host Status/Start/Stop and Project Pack Check. There is no shell
  input, embedded AI service, second PLE/MCP/IOE owner, direct `.project`
  editing, or PLC connect/download/runtime/write/FORCE capability.
- P2 IOE Apply is visible but disabled until the formal
  `Plan -> checkpoint -> Apply -> reopen/readback` backend passes regression.
  P3 Link I/O remains a displayed manual PLE step and P4 remains blocked on a
  real runtime DAT sample.
- Added PowerShell 7 and double-click CMD launchers to the project and generic
  template. `New-CtrlXOpconProject.ps1` now copies the text-only Workbench
  source to `tools/workbench`; `bin`/`obj` and binary assets are excluded.
- Acceptance passed: Release Build 0 errors / 0 warnings; Workbench self-test
  84 assertions; initializer regression 278 assertions; current Station010
  smoke reports 5 phases/current P2, P2 Apply false and online operations
  false; generic template smoke reports 3 phases/current P0. A real window
  opened with the expected title and closed cleanly. During the read-only
  status probe Runner was READY and Host was STOPPED.
- No CpStudio, PLE, IOE, MCP, Station010, `Std` or physical controller state
  was modified. No online operation was performed.

# 2026-09-01 Engineering Console v0.2 compact UI

- Simplified only the generic WPF surface: one state, one next action and one
  primary Run next button; secondary tools share one row and the workflow is
  reduced from seven verbose rows to four grouped steps.
- Moved P2 detail to the Plan page as four explicit cards: Plan, checkpoint,
  Apply and readback. Apply remains disabled until the backend contract is
  implemented and accepted.
- Release Build passed with 0 errors / 0 warnings; Workbench self-test passed
  84 assertions; Station010 smoke remained Ready with current P2,
  `p2ApplyEnabled=false` and `onlineOperationsAllowed=false`. Workbench and
  Plan pages were inspected from real rendered windows.
- No command, dependency, Runner/Host behavior, CpStudio/PLE/IOE project or
  online operation changed.

# 2026-09-04 Burster 2316 TypeData program selection

- CpStudio remains the owner of `Station.TypeData.Wp100.Burster.ProgramNo` and
  every generated Chain/TypeData declaration. No generated interface was
  changed. The standard Nexeed Burster libraries expose no public program
  selection command, so the implementation is isolated in the AI-owned
  `FB_Wp100BursterProgramSelect` plus the `AiWp100` GVL.
- N045 now requires the Burster Unit to be READY, closes its normal connection,
  sends the documented RESISTOMAT 2316 `*RCL Pn` request for program 0..15 over
  one short TCP 5555 session, waits for ACK, sends EOT and closes. Only then are
  both SFC start branches released; NAK, timeout or an unexpected response is
  returned as `HAS_ERROR`. `OnChainFinish` resets the selector and performs a
  best-effort EOT/close cleanup.
- The official PLE REST writer was extended with immutable Plan/checkpoint/
  Apply/readback support for the new FB and GVL. Its mocked PlanOnly, drift,
  exact request, post-save readback and rollback tests pass, including deletion
  of newly created support objects after an injected persistence-time failure.
- Real Station010 Apply used Plan SHA-256
  `81bca2e9f146f1341f61e6ad3b1fa132222f80225d0d65a6585422fae1418935`:
  two POSTs (FB/GVL) and two PUTs (N045/OnChainFinish). All declarations were
  preserved exactly. Final PlanOnly SHA-256
  `48693ceb2da0d9aedb59f43581a3f3a3e94cbe5c9c4d40f401e621274a6229ca`
  has zero operations.
- A real PLE Clean Build passed with **0 errors / 4 existing `OPC.UA.DA`
  warnings**, build token `62658432b17448b4bc720cb09fd223dc`.
  Final project SHA-256 is
  `F00DC266E58C59496E1F1553017C0591EE3909EC837DD63B9AA90EAF3B17640A`;
  its hash-identical local checkpoint is under ignored `data/checkpoints/plc/`.
- After offline acceptance, one MCP login used the project's existing target
  configuration for a read-only preflight. The target reported Application
  `STOP`; `Station.TypeData.Wp100.Burster.ProgramNo` and the new `AiWp100`
  diagnostics all had online quality `unknown`, so no runtime conclusion was
  claimed. The session was disconnected and PLE closed. No download, runtime
  start/stop, variable write, FORCE or Burster protocol command was performed.
  The remaining step is one separately approved, bounded field test using a
  known-safe Burster program.

# 2026-09-04 Burster manual field check and range cleanup

- The user removed the invalid CpStudio `Wp100BursterRangeEnum.NONE` item and
  exported again. Readback showed exactly the nine real instrument ranges at
  indices 0..8; the CpStudio-generated TypeData range checks returned to
  `UpperRange > 8` / `LowerRange > 8`. The guarded PLC PlanOnly result contained
  zero operations, so no AI repair was required after this export.
- The user performed the physical download/runtime operation and reported that
  Burster manual testing from the Nexeed HMI works normally. This confirms the
  standard manual Unit path for the tested operation; it does not yet close the
  separate automatic `*RCL Pn` program-selection acceptance item.
- The sanitized Station010 export snapshot is commit `42c373a`. It contains the
  CpStudio model, TypeData/HMI definitions, Symbol XML and both structure JSON
  snapshots. Local credentials, License workflow state, runtime connection
  files and the encrypted `.project` working copy were deliberately excluded;
  the replayable AI-owned PLC sources remain in this repository.
- The AI did not download, start/stop the runtime, write/FORCE a PLC variable or
  issue a Burster command during this check. `Std` was not modified.

# 2026-09-07 Development-PC OneDrive migration preparation

- Added one minimal setup script, `scripts/setup/New-DevelopmentPcMigrationBundle.ps1`.
  It refuses to run while CpStudio/PLE/IOE is open, records the three Git refs,
  archives the current encrypted PLC project, optionally packages `Std` and
  `Technical Docs`, validates each 7z archive, and verifies the local OneDrive
  copy by SHA-256.
- Plaintext DataSetAccess/HMI/Target credentials, License workflow, IDE locks,
  caches, Git metadata, personal Codex/Git configuration and runtime data are
  deliberately excluded. The new PC must re-enter its machine-local settings.
- `TEAM_SETUP.md` now defines OneDrive as transfer-only, not an active engineering
  workspace. Warning acceptance uses the formal signature baseline instead of
  contradictory historical counts. The new-PC restore and offline acceptance
  remain pending; no IDE or physical PLC operation is part of bundle creation.

# 2026-09-07 HMI IPC service connection diagnosis

- 用户现场反馈：打开 CpStudio/PLE 准备修改 StationData/TypeData 时，HMI IPC
  持续提示 `not connected to service`；完成 `Export #1 → PLE Build →
  Export #2 → final Build → 用户下载 PLC` 后恢复正常。本次未复现故障；
  不能仅凭这次恢复顺序确定哪一步消除了故障。
- 本机记录（Asia/Shanghai）：恢复阶段 Post-export request 分别为
  `41db3731-bf93-47e0-a9a2-8e437c9742c0`（13:03:11）和
  `f306b4ae-9c7c-4eef-b43e-f4bd1b03a056`（13:03:52）；Symbol XML 于
  13:04:12 更新，编译/boot/同步文件于 13:04:24–26 更新。两份 request
  在检查时仍为 pending，没有被本次诊断消费；文件时间不代替 Build
  错误数、下载成功或运行时验收证据。
- 恢复后的只读检查结果：

  | 对象 | 已观察事实 | 证明范围 |
  |---|---|---|
  | HMI IPC `192.168.0.50` | Ping 成功；3389/445 可建立 TCP 连接；已有 RDP 连接 | 开发机到 IPC 的可达性；不证明 DataSetAccess 服务健康 |
  | PLC `192.168.0.51` | Ping 成功；443/4840/11740/61863 可建立 TCP 连接 | 开发机到各监听端口的可达性；不证明 IPC→PLC 会话、授权状态或无 crash-loop |
  | 本机 HMI 配置 | `Hmi/PlcHandlerL1.ini` 指向 `192.168.0.51` | 仅本机导出配置，尚未比较 IPC 已部署文件 |
  | 当前 PLE Symbol Configuration | 官方 REST GET 200，`supportOPCUA=true`；StationData、StationDataNew、TypeData、TypeDataNew 均 selected | 工程端选择状态；返回 `accessRights=Void`、`maximalAccess=ReadWrite`，不能当作运行时读写已验证 |

- 结论修正：接口/Symbol 与已下载应用未同步是候选原因；下载引起的应用
  重新初始化或服务重连也可能解释恢复。未获得故障时 IPC 的 HMI/DataSetAccess
  日志，也没有修改前后的运行时 Symbol 对比，根因保持未确认。相对
  Station010 `42c373a`，本次可读模型差异只显示 Export ID 与连接凭据字段，
  两份 Struct.json 只显示 ObjectGuid 变化，没有证据证明此次新增/删除了
  StationData/TypeData 成员；`.project` 内未导出的差异仍未检查。
- 操作约定保持精简：只在 HMI 修改现有 DAT 参数值时，沿用现有加载/应用
  流程，不因改值而强制 Export/Build/下载；CpStudio 接口或 PLC 代码变化
  则按工程流程同步。Export #2 仍由首次导出的 Symbol/OPC UA/PersistentVars
  后处理错误或缺失目标决定，不把本次现象升级为“所有修改固定导出两次”。
- 未完成项：RDP 窗口最小化且恢复失败，未读到实际 HMI 画面；开发机当前
  身份未能访问 IPC 的 `OpconData$`，原因未判定，不能据此认定共享或 DAT
  不存在。下一次可读取 IPC 时，优先核对服务/报警日志及已部署配置与 PLC
  会话；若再发作，先取故障时证据再恢复，不为取证主动制造生产故障。
- AI 仅执行网络探测、配置读取和现有 PLE 官方 REST GET；MCP 无 owner，
  未启动另一套 PLE/MCP，也未 Build、保存工程、下载、启停、写变量、FORCE
  或重启服务。本次 Git 提交限交接与待办记录；Station010 本地生成/运行
  配置和加密 PLC 工程保留原样，未上传凭据、License、运行缓存或 `.project`。

## 2026-09-07 · Wp100 压紧力联锁初始需求（历史记录，实施结果见下）

- 用户明确的新工艺：左、中、右三个位置均在压缸下压到位后，要求实时力
  **严格大于 2500 N 且连续保持 2 s**，随后启动一次 Burster 测量；正常测量
  完成才允许上升。等待达标超过最大诊断时间，或电阻测量期间力
  `<=2500 N`，均报警并阻止流程继续。
- 当前可读源码仍是旧逻辑：N050/N051 并行下压与 Kistler MEASURE；N070
  只等待 `Station.StationData.PressDelayTime`；N080/N090 没有测量期间掉力
  联锁。SqC_Run 已按 LEFT → MIDDLE → RIGHT 顺序复用同一 SqS_Run，
  不应复制三套逻辑。本次没有读取在线代码或证明现场已部署源码一致。
- CpStudio 待新增接口（不能由 AI 在 PLE 强补生成声明）：

  | 位置 | 名称 | 配置 |
  |---|---|---|
  | Station 的 StationDataStruct，与 PressDelayTime 同级 | PressForceTimeout | DINT，单位 ms；中文“压紧力达标最大等待时间”；英文“Maximum wait for stable pressing force (ms)” |
  | Wp100 → Events | EVENT_PRESS_FORCE_INVALID | 本次已保存模型的 Wp100 本地编号 5 空闲，可用于新事件；以重新导出的常量为准，不复用 Station 的压力事件 |

  事件中文：`压紧力异常：等待达标超时或电阻测量期间压紧力不足`。
  事件英文：`Press force fault: stabilization timeout or insufficient force during resistance measurement`。
  最大等待时间必须大于 2000 ms；实际工艺值待用户确定，不能把 0 当作禁用。
- 最小实现计划：保留单个原子 Chain，先确认 Kistler 进入有效测量状态再
  下压（避免当前压电 OPERATE/START 耦合下带载归零）；用现有实时值
  `Wp100A104Kistler.Unit.OutImm.ForceAct` 判定。2 s 稳定计时在条件不成立时
  清零；独立总等待计时从下压到位起算，不随力的波动重置。新判定替代
  原来的单纯压后延时，不能把旧 PressDelayTime 的到时当成力达标。
- 测量启动前再确认有效力；从 Burster 启动请求到完成判定均检测掉力，
  同一扫描周期掉力与完成同时出现时按失败处理，不接受该次结果。通信
  无效或 Kistler 意外结束也不能使用旧的力值放行。故障锁存后不因力恢复
  自动清除/重测/上升/进入下一位置。
- 报警计划沿用链内锁定 SOFTERROR + AdditionalInfo（位置、阶段、力值和
  原因）来阻止步骤放行，不直接用 ERROR 假装“保持原步骤”。**压缸在
  故障后的实际处置与复位/重测方式仍待用户确认**；现有安全回路、
  ControlOn 和标准 Unit 故障处理始终优先，不保证气动保持、不屏蔽下电。
  Kistler 整次测量超时还需覆盖启动/下压、力达标等待、Burster 测量和结束
  握手，不能与新增的力达标诊断时间混为同一个计时器或简单禁用超时。
- 验收应覆盖：三个位置、2500 N 等号边界、2 s 中途跌落重新计时、等待
  反复波动仍会超时、Burster 测量中掉力/数据失效、故障不自恢复、正常
  结果后才上升。本次仅记录需求与待办；原 process.json/PLC 源码保留
  当前实现状态，新增接口 Export 后再同步修改流程事实源和 ST、回读、
  Build。没有修改 CpStudio/PLE、连接或操作真机，亦未提交推送 Git。

## 2026-09-07 · Wp100 压紧力联锁已写入 PLE（离线通过，未下载）

- 用户确认故障时压缸保持下压、等待人工处理；不是自动上升或自动重测。
  已从本次 CpStudio 导出和当前 PLE 读取到
  `Station.StationData.PressForceTimeout : DINT`（ms）以及
  `Wp100.EVENT_PRESS_FORCE_INVALID : DINT := -5`。生成声明没有改动。
- 仅在 `SqS_Wp100_Run` 增加 AI-owned `CheckPressForce` 方法，左/中/右
  继续复用原来的 23 步 SFC。使用方法的原生 `VAR_INST` 保存诊断 TON 和
  故障锁存，复用链中原有 `_pressDelay` 做连续 2 s 判断；没有新增框架/FB。
  原理参考：[CODESYS VAR_INST](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_vartypes_var_inst.html)。
- 实际改动：N000/OnChainFinish 清理计时和锁定事件；N050 等 Kistler
  MeasRunning 且 ExecState 非 ERROR 后才下压；N051 校验诊断时间并启动
  Kistler；N060 从压缸到位开始总等待；N070 要求有效力严格 `>2500 N`
  连续 2 s；N080 启动前复查且单次触发；N090 在接收 Burster DONE 前
  检查掉力。原 PressDelayTime 字段保留兼容，但不再用它代替力达标。
- 力跌到 `<=2500 N` 会重置达标的 2 s TON，但不会重启总诊断时间。
  电阻测量开始后不再去抖；掉力、Kistler 结束/ERROR/Alarm、非有限数或
  压缸工作位丢失均锁存首次故障。SOFTERROR 附加信息保留位置/原因/力值；
  测量结果无效，结束/取消仪表请求，**不发送压缸上升命令**。
  力恢复或只确认报警不会自动继续；人工取消当前链、处理后重新启动。
  安全回路、ControlOn 和标准 Unit 故障处理仍可中止过程，软件不保证物理保压。
- 自动 Kistler 测量 watchdog 至少为 `PressForceTimeout + 30 s`，已有更大值
  保留；30 s 是下压/Burster/结束握手的工程余量，现场需确认覆盖实际时长。
  HMI 手动测量的现有输入值/超时机制没有改成无限等待。
- 写入过程：现有唯一 PLE（profile `ctrlX PLC 2.6.8`）官方 REST，先 Plan
  再按 SHA Apply、逐对象回读、Save。首次新增方法后父对象校验不一致，事务
  自动回退并验证恢复；调整为先改现有图再新增方法，未放宽哈希门禁。
  编译修正了本库不存在的 ErrorSet 成员，使用实际的 ExecState.ERROR。
- 最终 PLE F11 Build：**0 errors / 5 warnings**，与改前同为四条 C0351
  OPC.UA.DA 和一条 C0373 SymbolConfig。REST 没有应用 Build 接口，本轮仅
  Build 使用 UI；没有通过 UI 编辑代码，也没有启动第二套 PLE/MCP。
  全目标最终 PlanOnly 为 0 个操作，生成父声明 SHA 未变。
- 本轮通过框架静态检查、REST PlanOnly/事务回退测试、力时序模型测试及
  Station010 Project Pack 检查。时序模型不是 PLC 仿真，编译不是现场验收。
  检查记录：`data/reports/plc/wp100-force-interlock-20260907.json`（仅本地）。
  Stage 2 建立了 PlanOnly action，但没有以 UI 截图冒充结构化 Runner evidence，
  所以不宣称该 ledger DONE。原审计和本次新审计均保留。
- 用户下一步：在 IPC 实际 StationData 中设置 `PressForceTimeout >2000 ms`
  并加载为 active dataset；0/未设置会报警，不会静默禁用诊断。导出接口不等于
  运行时 DAT 已有值。部署前同步新事件文本/数据定义；下载由用户操作或再次批准。
  现场还需验收三个位置、2500 N 等号、2 s 中断、总等待超时、测量中掉力、
  锁存不自恢复和取消后重新开始。本轮没有连接真机、下载、启停或写变量/FORCE。

## 2026-09-07 · Fixture 提示改用实时原位输入（已保存，待用户 Build）

- 用户确认截图条件要判断实时传感器，接受原位输出关闭时仍按输入显示位置。
  本轮仅将 `SqC_Wp100_Run` 的 N015/N045/N075 内安全门和压缸共六处
  `IsInBasPos` 改成 `IsInBasPosIn`。保留产品检测、位置 one-hot、
  `CheckSubChainDone`、SqS_Run 动作联锁和全部标准 Unit 配置。
  这不保证子链在输出不满足时继续放行动作；没有把输入反馈当作安全功能。
- 现有唯一用户 PLE，profile `ctrlX PLC 2.6.8`，官方 REST Plan →
  精确三项 Action PUT → Save → 全对象回读；父声明和 SFC 图未变，
  最终 PlanOnly 为 0 项写入。起点 SHA `5cc808e6...0f792` 的本地
  `.project` checkpoint 已回验；不改加密文件字节、不启动第二个 IDE。
- 复用既有 REST writer，补入三个已核对旧 Action 的哈希；回归检查要求
  完整的 `IsInBasPosIn` 条件并拒绝恢复旧综合状态判断。operator guidance、
  REST PlanOnly/事务回退、框架静态检查及 Project Pack Build 均通过。
  流程规格与生成计划已同步，无新框架/服务。
- 当前 PLE 不是 MCP 所有，会话状态 stopped；本轮没有为编译另开 PLE，
  也没有通过界面点击。**尚未运行本次 PLE Build**，用户按 F11 后核对。
  此前 0 errors / 5 warnings 只作对比，不作为本次结果；没有下载、连接、
  启停或 FORCE。证据：`data/reports/plc/fixture-input-feedback-20260907.json`。

## 2026-09-08 · Fixture 左右 BMK 与 StationData 同步（已保存，待用户 Build）

- 用户新导出的 BusConfig 与 PLE BinIo 一致：`_100B603` 左、`_100B602` 中、
  `_100B601` 右。变量名/通道未互换，本次只修正方向语义，不再次交换 I/O 映射。
- 经现有用户 PLE（`ctrlX PLC 2.6.8`）REST，精确修改 SqS_Run N010 与
  SqC_Run N015/N075 三个 Action；Save 成功，完整回读后两个 writer 均为
  0 项待写。父声明、SFC 图、BinIo 与 StationData 声明保留；不另开 PLE。
- StationData 已由用户删除 `PressDelayTime`；现行程序无该字段引用，继续
  消费 `PressForceTimeout`。不恢复旧字段，不改变 >2500 N 连续 2 s、掉力锁存、
  IsInBasPosIn 提示条件或测量顺序。IPC 实际 DAT 值仍需用户加载确认。
- ASC 源清单、流程规格及生成计划已同步。新 Export 请求
  `31bfc591-c9fe-4227-a1d6-ab60599b6762` 的 Stage 1 已审计：56/56 点一致，
  38 active / 18 inactive，0 mismatch；Stage 2 仅 WhatIf，没有执行 Runner action。
- 一份起点 `.project` checkpoint（SHA `ce417fe0...376c4`）已本地回验。
  三位置各八种输入组合（SqC/SqS 共 48 组）、力时序模型、REST PlanOnly/事务回退、
  框架及 Project Pack 检查通过。这些不代替 PLC Build/现场验证。
- **本次 PLE Build 未运行**：MCP 未持有当前用户 PLE，REST 无已验证的应用
  Build 接口；请用户 F11 编译并自行下载。未连接真机、启停、下载或写变量/FORCE。
  本地证据：`data/reports/plc/fixture-bmk-swap-20260908.json`。

## 2026-09-08 · 全应用位置反馈修正（已保存，待用户 Build）

- 用户指出 SqS_Run N010 在传感器已到位时仍被综合状态阻塞；此前仅修改 SqC
  三个提示动作，覆盖不足。本轮按确认的规则检查全部应用，不再只修截图。
  标准对象 OOD 的 `PosEvalWithOutputs` 说明验证了不带 In 的状态会结合输出。
- 当前用户 PLE 官方 REST 扫描 Application 307 个对象（不进入标准库），
  发现 20 个位置相关对象，其中 17 个对象共 27 处仍使用综合位置状态。
  已精确修正为 `IsInBasPosIn` / `IsInWrkPosIn`：
  - SqS_Run：N010/N030/N040/N045/N050/N051/N060/N080/N095/N100/N130
    以及 CheckPressForce，共 12 对象 / 18 处。
  - SqS_Home：N110/N130/N150，共 3 对象 / 5 处；补齐可读实现源与归属记录。
  - Wp100Unit.OnApplyOutputs 的 IsInHomePosition：2 处；IsEmpty 原样保留。
  - 压缸 Extension.OnManRelease 的两个动作放行：2 处；CommonManRelease
    与 `_000K913_Y32/_000K912_Y32` 原样保留。
- 所有 CheckUnitDone、ExecState、StepPulse、Execute/Command、PreStartCheck、
  OutputPulsing、安全继电器、>2500 N/2 s/PressForceTimeout 与故障锁存均保留。
  Home 只额外采用仓库既定括号排版；未改生成声明、SFC 图、I/O 映射、Std。
- 使用共享 REST 事务保护做单次离线迁移，Plan SHA `420481ce...78266`；
  起点 checkpoint `e7377541...d076e` 已回验，17 项 PUT 后仅 Save 一次。
  完整回读成功，再扫描 307 对象：旧引用 0，输入反馈引用 33（含此前正确的 6）。
  两个现有 Run writer 与本地迁移 PlanOnly 均为 0 写入。
- AGENTS/规格/hooks/catalog/Project Pack 同步；全源码禁止旧综合状态的检查、
  SqS N010 双原位输入断言、力检测输入断言、框架、REST 事务、力时序模型及
  Project Pack Build/Check 通过。未以静态模型冒充 PLC 仿真或现场验证。
- 用户拔掉网线；AI 没有重新连接、下载、启停、写变量或 FORCE。MCP 未持有
  当前 PLE，**本次 PLE Build 未运行**，请用户 F11 后再自行部署和现场核对。
  本地证据：`data/reports/plc/basmove-input-feedback-20260908.json`；
  修改前对象快照为同目录 `basmove-input-feedback-20260908-before.json`。

## 2026-09-08 · 启动按钮灯使用标准 Toggle

- 只读扫描确认 `Station.FlashBits : OpconUnitRootDataFlashBits` 只有声明、没有周期赋值；Run N020 和 Home N010 均引用其中的 `Pulse500ms`。本机 NxBase 官方框架手册还确认 Pulse 仅维持一个 PLC 扫描周期，Toggle 才按指定间隔翻转。
- 两处调用已改为 `Root.RootNode.FlashBits.Toggle500ms`；MAIN 本来就周期调用 RootNode，无需增加定时器或复制全局变量。`FB_OperatorButton` 只更正注释示例，接口、算法、按键完成与取消熄灯不变。Home N010 补齐可读源；Run/Home 规格、ownership 与回归断言同步。
- 用户当前 PLE `isOnline=false`，工程/profile 精确核对；复用 checkpoint `cea2d22a...b798`。两处 Action 与一处注释经官方 REST 写入、仅保存一次，完整回读与根对象/SFC 图不变检查通过。保存后工程 SHA `81dda38c...5ba0`；证据：`data/reports/plc/operator-lamp-toggle-20260908.json`，同目录 `-before.json` 保存对象快照。
- MCP 未持有该用户打开的 PLE，本次没有启动第二实例，**没有执行 PLE Build**；错误数与 warning 对比待本次新 Build，不引用截图旧结果。用户 F11 后自行下载并核对自动/回原位等待闪灯及按下/取消熄灯；不需 CpStudio Export。无连接、下载、启停、写变量或 FORCE。

## 2026-09-08 · Kistler END 连带报警修复；Burster/原位显示仍有待办

- 用户报告：自动关安全门后压缸未下，Burster 显示 `invalid range when starting command`，Kistler 同时报 `Ending measurement only possible while measurement is running`。用户确认当前 TypeData 上下量程均为 **2 mΩ**；之前手动仅测试 `Start Single Measure` 并得到数值，没有执行过 `Set Measurement/SET_RANGE` 成功验证。
- 当前自动实际顺序为 N045 程序选择 → N046 SET_RANGE → N047 CheckUnitDone → N050/N051 压缸/Kistler 分支。量程失败发生在运动分支之前；OnChainFinish 又无条件设置 Kistler END，能解释第二条连带报警。标准对象 EN/DE 手册、OSD 与导出 Symbol 均确认 2 mΩ 的枚举为 **0**；当前转换无 +1 偏移。仅凭用户的 0/0 不能确定标准库拒绝的内部条件，不得谎称“0 是无效量程”或“等量程一定是根因”。
- 标准库本机版本 NexeedBursterResis2316 1.0.1.0；德国技术手册（2024-04-16）说明 SET_RANGE 设置 AutoRange 上下边界，SINGLE_MEAS 默认先进入 AutoRange，除非 CpStudio 外围 AutoRange=false。当前生成 `PeripheralRoot.OnApplyParameters` 中 `UseAutoRange := True`。**本轮未修改 Burster 范围、程序选择、TypeData、外围配置或标准库，也未跳过 SET_RANGE**。待用户确认是否采用“量程跟随仪表程序”的路径；若采用，必须一起处理 CpStudio 的 AutoRange 配置，不能只删一行 SET_RANGE 后宣称仍遵循完整程序配置。
- 已修正 4 个 AI 实现：OnChainFinish 将 END 清 FALSE，Execute 清 FALSE（NxBase 2025-02-24 官方手册 Execute/OpconExecUnit 明确下降沿触发 Cancel）；N101 和 CheckPressForce 的 END 门控为本链已启动 + MeasRunning + ExecState RUNNING，每次执行重新求值；N120 在停止/非 RUNNING 时清 END。正常完成仍用 CheckUnitDone 收取结果，故障锁存不自动恢复、不请求压缸 BASPOS。无需新增 FB、接口、配置或周期钩子。
- 采用现有受控 Run writer，只执行四项实施体 PUT，声明/SFC 图均未改。Plan SHA `c050c83adcb2c58229c310567c71626ef76330fe7ca6198d17efa2bab27b5e55`；checkpoint `81dda38c99fab44b5a9da2c1293e65af5da50ecb4705f949fea0ce61ce8d5ba0`；一次保存后 `.project` SHA `bbf386ee61b9e2f5d94dd64c4476aecbb8cc190c262cf04b350dca579c8d8a31`。完整回读成功，保存后 Run PlanOnly 为 0 操作。证据 `data/reports/plc/kistler-end-20260908.json` 及同目录 `-before.json`（本地，不提交二进制）。
- 框架/位置规范、operator guidance、force 时序及 END 门控/单步/前置失败检查、REST PlanOnly/事务回归、Project Pack Build/Check 通过；这是离线源代码/模型验证，不是标准库运行仿真。当前 PLE 不归 MCP 所有，未启动第二实例，**本轮未 Build、未连接、未下载、未启停、未写变量/FORCE**。F11 新 Build 与真机取消时仪表停止行为仍需用户复核。
- 当时原位显示仍不一致：PLE `Wp100Unit.OnApplyOutputs` 已使用两路 IsInBasPosIn，Station 使用 Wp100.Unit.IsInHomePosition；但 `Station010/Hmi/config.xml` 的 Station/Wp100 条件各仍含两路不带 In 的绑定（总计 4 处）。**09-09 更正处理方式**：这是解析树未同步，应在 PLE 保存后执行 CpStudio **Parse PLC code**，再保存/导出并更新 IPC HMI；不手动重建操作数，也不直接修改 Engineering_Data.xml 或生成 config.xml。见文末完成核对记录。

## 2026-09-08 / 09-09 · Burster 自动量程由仪表程序决定（PLC 已保存，配置/Build 待办）

- 用户确认自动运行量程完全跟随仪表程序。保留 N045 的 TypeData `ProgramNo` → `*RCL Pn` → ACK/EOT/关闭临时连接；N046 不再下发 `SET_RANGE` 或复制 TypeData `UpperRange/LowerRange`，改为检查 `Peripherals._Wp100A103ResistantInterface.ParCfg.UseAutoRange=false`。N047 只等标准 Unit READY 且 Execute=false，不调用未发送命令的 `CheckUnitDone`。保留步骤编号和所有分支，仅更正两个步骤注释；没有新增 FB/服务/配置层。
- N080 继续从 active TypeData 取得 `UpperLimit/LowerLimit/ReadTemperature` 并执行标准 SINGLE_MEAS。OnCheckData 仅移除 AI 语义区内无用途的上下量程大小关系校验，保留上下限/程序号检查以及全部 CpStudio 生成的接口、枚举校验和用户生成内容。力阈值/2 s、诊断超时、故障保持、位置输入和 Kistler END 修复均未改。
- **必须由用户在 CpStudio 配套修改**：Peripherals → Wp100A103ResistantInterface → Parameters → Measure → **Auto Range=False**，保存并 Export。本机 OOD 的显示名为 `Auto Range`，内部参数名 `AutRange`；生成目标为 `ParCfg.UseAutoRange`。09-08 修改后最后回读仍是 True，AI 未改标准外围参数或模型 XML。False 仅阻止标准驱动强制切入自动量程，实际量程由所选仪表程序保存的设置决定；不是在 PLC 内指定 2 mΩ。未改好时 N046 保持等待，压缸/Kistler 启动分支不放行。TypeData 两个旧量程字段保留兼容，标准手动 SET_RANGE 未改。
- 使用原有 REST 事务 writer，在精确工程/profile 且离线时只写 OnCheckData 语义区、SqS_Run 两条步骤注释和 N046/N047，保存一次、完整回读，最终 PlanOnly 0 操作。Plan SHA `a471cc242744ba9c58cb8142f53e9f559c9fffe4b27412997790cb4c6ee9e8fd`；内容寻址 checkpoint `bbf386ee61b9e2f5d94dd64c4476aecbb8cc190c262cf04b350dca579c8d8a31`；保存后 `.project` SHA `c5cc88c07045ed0f90ec4e0b99b64dc20e4910ac3af8726fbb508b25165ab1d3`。生成 Peripheral 参数及 CpStudio 模型 SHA 未变。本地证据：`data/reports/plc/burster-program-range-20260908.json` 与同目录 `-before.json`。
- 09-09 续做时磁盘 SHA 仍与该保存报告一致；本地 PLE REST 已拒绝连接，没有重开 PLE 或重复 Apply。Burster 源码合同、框架/位置规范、operator guidance、力联锁、REST PlanOnly/事务与 Project Pack 检查通过；这些不代表 PLC 编译或仪表现场验证。**本批尚未取得 PLE Build 结果，无连接、下载、启停、写变量/FORCE**。用户完成 Auto Range 配置/Export 后做 F11，新编译通过后再受控部署，核对真实程序/量程、测量与判定。
- 当时 CpStudio 原位显示仍待同步；**09-09 更正**：PLC 实现已经正确，用户需执行 **Parse PLC code** 刷新解析树，不是在 CpStudio 手改表达式。AI 不直接补丁生成 HMI。代码、配置同步与现场验收分别记录。

## 2026-09-09 · Auto Range=False 新 Export 核对（无 PLC 写入）

- 用户确认已完成 Auto Range=False、保存/Export/F11。新请求 `04500e24-28c7-4157-a8cd-9fbfa80af5b0`（10:50:22 本地）经指定 request 的 WhatIf → Stage 1 审计；56/56 designator 一致，38 active / 18 inactive，0 mismatch。20 个 Station010 脏生成文件保留，未暂存/上传工程配置或二进制。Stage 1 的 `done` 仅指该审计队列已处理，不是工程或现场验收 DONE。
- 现有用户 PLE 官方 REST：精确 Station010 路径/profile `ctrlX PLC 2.6.8`、Application offline；生成 `Peripherals._Wp100A103ResistantInterface.ParCfg.UseAutoRange := False`。Run 与 SqC 两个 writer 的 PlanOnly 均为 0 操作，程序号握手、无 SET_RANGE、量程模式/READY 检查、上下限判定、力联锁及 Kistler END 修复均保留，不必重复 Apply。
- 补查 Wp100Unit.OnApplyOutputs、压缸 OnManRelease、Home N010/N110/N130/N150：位置判断仍用 In，Home 灯仍用 Root Toggle500ms。该批 HMI XML 的 Station/Wp100 `IsInHomePosition` 条件各有两条旧 IsInBasPos 叶绑定，随后确认需在 CpStudio **Parse PLC code** 同步，而非手改条件定义；未修改生成 HMI。源代码/力时序模型/框架/Project Pack 检查通过。
- 本轮 PLE 工程 SHA 前后同为 `3c5909da508533c743f83848f0d327142d7ccb098532513017b752d22c4bbd73`；没有工程 PUT/Save/Build、物理连接、下载、启停、变量写入/FORCE。MCP stopped/无 owner，未另开 PLE。用户报告 F11 完成，但具体 errors/warnings 尚待确认；不以缓存代替新 Build。Stage 2 仅 WhatIf，未执行/提交 immutable action 的 DONE evidence。
- 本地机器可读核对记录：`data/reports/plc/burster-program-range-export-20260909.json`；Stage 1：`data/reports/cpstudio/04500e24-28c7-4157-a8cd-9fbfa80af5b0.json`。下一步确认编译数量，完成 CpStudio 原位条件及受控现场测试；不再要求重复设置 Auto Range。

### 2026-09-09 · 用户截图补齐本批 Build 数量

- 用户提供 PLE Build 截图：`Build complete -- 0 errors, 5 warnings : Ready for download`，同时显示 94 条 messages。本批编译通过；该证据来自用户截图，不是 AI 执行的新 Build，也不能替代 Stage 2 所需的结构化 immutable action evidence。
- 截图未展开五条 warning，签名/内容尚未核对；不因数量与旧记录相同就认定全是旧警告。TODO 已完成编译数量项，保留警告明细、CpStudio 原位显示条件和真机验收待办。本轮只更新记录，没有改 PLC/IO/HMI、下载或操作真机。
- 单独保存补充记录 `data/reports/plc/burster-build-user-confirmation-20260909.json`，不覆盖原始导出审计。先前本地提交 `b8bd098` 的 GitHub 推送因 3128 代理不可达而未完成；推送成功前不得当作远端备份。

## 2026-09-09 · Parse 后导出核对与昨日离线修改收尾

- 用户确认 Parse 操作完成并继续现场测试。按最新请求 `2a246abf-94bb-4ecd-9f87-d2d77ad55d30`（11:08:00 本地）完成 WhatIf → Stage 1 审计：56/56 designator 匹配、38 active / 18 inactive、0 mismatch。审计唯一 finding 是 20 个受保留的 Station010 生成文件变更；未暂存这些配置、凭据或工程二进制。队列 `done` 不等于 Stage 2/真机验收 DONE。
- 新 HMI config 的 Station/Wp100 原位条件树均为 AND，4 个叶绑定全部为 `OutImm.IsInBasPosIn`，旧位置叶绑定为 0。现有 PLE REST 复核 Station 委托、Wp100 两路输入 AND 及压缸手动放行安全继电器均保留。**正确闭环是 PLE 条件代码 → Parse PLC code → HMI 导出/部署**；已更正 TODO 和工作流中的旧建议，不增加解析器或手工补丁。
- 精确工程 `Station010/Plc/Stat010_V5.11_CtrlX_PLC.project` / profile `ctrlX PLC 2.6.8`，单个用户 PLE PID 3112、Application offline；MCP stopped/无 owner。Run PlanOnly SHA `ec8c839d01d0b31872ed854a5e46d72e540e4d3dddcaabfeb1edd217ee5aecac`、SqC PlanOnly SHA `0a73597aa5cf58774735ee1fd0af0538af38083ee54fe7a69bf1799b8d11157f`，均为 0 操作；Home N010/N110/N130/N150 与可读源一致。生成 `UseAutoRange := False` 确认保留，无需重复 Apply。
- 六组回归通过：Burster 程序量程、force 联锁/时序模型、框架/位置规范、operator guidance、REST PlanOnly、REST 事务；Project Pack Check 为 VALID，contentId `81af8d7326c9314118474bcc5b39008e11ab2fc7f628b1aaea4ba138ba688dc2`。这些检查不冒充 PLE 编译、标准库仿真或现场测试。
- 工程核对前后 SHA 同为 `aac3e08e7e61afb08e7fbb25fd9f90811c172eee9d4f4678aef7254ba0d6d849`；HMI SHA `0336153f012c08cd76ee8529d10c9a1a48932012b48fb5a7614edce56500814a`。本轮没有 PLC PUT/Save/Build、第二 PLE、连接、下载、启停或变量写入/FORCE。此前用户的 0 errors / 5 warnings 截图早于这次 Parse/Export；本次新 Build 和 5 条 warning 明细尚未取得，不能移用为当前工程的 fresh Build evidence。
- 现场测试仍由用户操作：先核对原位显示与启动/回原位等待闪灯，再跑左 603 → 中 602 → 右 601 的正常完整流程，确认压下后力 >2500 N 连续 2 s 才启动 Burster、结果完成再回升。诊断超时/测量中掉力/无效数据/取消的受控故障测试单列，确认故障保持下压且不自动重试；不要求在运行中拔传感器或强制物理 I/O。
- 本地汇总证据 `data/reports/plc/engineering-closeout-20260909.json`，最新 Stage 1 报告 `data/reports/cpstudio/2a246abf-94bb-4ecd-9f87-d2d77ad55d30.json`。本轮只完成离线核对与文档收尾，不把未执行的现场项目勾选为完成。

## 2026-09-09 · 回原位空步骤与并行分支完成保持

- 用户截图定位 `SqM_Station_Home.N110` 无 Action 而等待 `_retVal = OK`。全量检查 12 条应用 SFC 后，删除该空步，保留 N100 的 `ExecuteSubChain` 真实完成握手并直达 N999。不要误删其他链中有 `CheckSubChainDone` 的 N110。
- 按用户约定，Run 两组并行分支新增末尾 N065/N066、N115/N125；只赋本分支 `_retVal := OK;` / `_retVal2 := OK;`，到达前仍须实际完成。仅修改两张图和新建四个 Action，既有 ST、全部声明、运动/力/安全和仪表协议不变。规范进入 AGENTS/框架目录/链规格，Project Pack 同步。
- 单个原有 PLE PID 3112/profile `ctrlX PLC 2.6.8`，REST 确认 offline；按 checkpoint → Plan → Apply → Save → readback 执行。Home 一次因 native localId 重编号导致严格回读失败，自动回滚核验后，使用连续 ID 重新执行成功；新增回归防止重现。MCP 未另开工程，无物理连接/下载/启停/FORCE。
- 最终扫描 367 个可读 Application 对象、12 条 Chain；所有既有 33 个 Home/Run 目标的差异仅两张图。Home 3 步、Run 27 步，汇合输入 N065/N066 与 N115/N125；三个 writer PlanOnly 均为 0 操作。保存工程 SHA `c5d5ec1c67b9a1bedf78a0228edc2c71fa28ca024062ffc207d2716c26306356`，写前 checkpoint `aac3e08e7e61afb08e7fbb25fd9f90811c172eee9d4f4678aef7254ba0d6d849`。
- **本批新编译已由用户 F11 确认：0 errors / 5 warnings**，不是旧截图或 MCP 缓存。警告明细仍未提供；现场回原位结束、LEFT/MIDDLE/RIGHT 两组分支汇合待用户受控下载验证。
- **仍需用户选择**：`SqC_Wp100_DeleteWpcData` 的 N110/N120/N130/N140 只有注释中的模板代码，没有清数据实现。已询问是否不用或需要清哪些数据，未擅自改成无动作成功；其余 11 条 Chain 未发现残留同类空步/未引用子 Action。详细检查表、执行 SHA 与验证范围见 `docs/reviews/station010-sfc-completion-20260909.md`，本地证据为 `data/reports/plc/sfc-completion-*-20260909.json`。

## 2026-09-09 · 自动 N000 被旧力报警复位卡住（当前交接）

- 修改前在线只读证据：SqS_Run.N000 长时间 RUNNING；CheckPressForce 保留 `_fault=TRUE`、`_eventIndex=2`、`INVALID_TIMEOUT_MS` 和旧 `_timeoutMs=2000`，但 active StationData 已为 10000。Phase 0 的事件 cleanup FALSE 提前返回，阻止释放旧状态及读取新参数；未单独捕获是哪一个 cleanup 返回 FALSE。HMI 无红字不代表内部句柄已复位。
- 用户说“直接改”并确认已退出在线后，REST 再验 offline；仅修改 CheckPressForce Phase 0：对自己的非零句柄依次 Unlock/Clear 后释放，不把 BOOL 当链完成握手。依据本机 NxBase 官方 ClearEvent/UnlockEvent 手册，保留当前两参数接口。显式链边界复位、2500 N/2 s、掉力/无效数据、故障保持及全部运动逻辑不变，无新 FB/接口。
- 现有 writer：Plan `b8899e08...74b03`，一个 implementation PUT/一次 Save/39 目标回读；checkpoint `c5d5ec1c...6356`，保存后 SHA `3b43f791...100e2`。新 F11 后 SHA 不变，最终 PlanOnly 0 操作；未另起 MCP/PLE。七组回归与 Project Pack Build/Check 通过，不冒充库仿真。
- **AI 已在当前 PLE 完成本轮新 F11：0 errors / 5 warnings**，观察到 Build started 和完成结果。五条明细为 4 × C0351 OPC.UA.DA、1 × C0373 SymbolConfig ErrorCodes/DWord；附加代码检查 0 errors。记录当前 UI 编译证据，不擅自修改正式 warning baseline，也不替代现场 Symbol 验收。
- **未下载、未启停、未写变量/FORCE**。用户下一步安全下载，核对 active PressForceTimeout=10000，重新发起自动，验证 N000 → N010；本次方法实现修改无需 CpStudio Export。左中右及故障恢复现场测试仍未完成。详细证据、库说明及测试边界见 `docs/reviews/station010-force-reset-20260909.md`；本地报告 `data/reports/plc/force-reset-20260909-{plan,apply,verification}.json`。

## 2026-09-09 · N045 Burster 程序选择 NAK 修复（当前交接）

- 用户报告安全门已下、压缸未下而黄色提示“正在测量”。现有 PLE 只读定位 N045：位置 In / 继电器 / 标准 Unit READY 条件满足，active ProgramNo=0，选择器 ErrorCode=6/state=200。实际发出 `*RCL P0`（完整帧 18 字节），接收 `[21,13]` 即 NAK+CR，错误清理后 socket 已关闭。N000 旧力复位已通过，当前 `_fault=FALSE`、`_eventIndex=0`、active/内部 timeout=10000；不能把这次 N045 故障当成原 N000 问题。
- 官方 2316 手册 §8.15.11/P113 明确 P1 为 0..15 数值占位符。用户说“改吧”后，按最小修改将共享 FB 报文前缀改为 `*RCL `，程序 0 完整帧变为 17 字节；N045 失败时清掉误导测量提示，仍用 HAS_ERROR 阻止两分支。没改 ProgramNo、接口、SFC 图、连接交接、ACK/EOT、测量命令、位置/力/运动联锁或 CpStudio 生成内容。
- 当前模型没有专用“Burster 程序选择失败”事件，**HMI 专用红字报警尚未实现**；保留 ErrorCode，不复用压紧力/缺料事件。若用户需要，由用户在 CpStudio 新建事件并 Export 后再接入。未为此增设 FB、服务、运行依赖或直接改生成声明。
- 写前 REST 确认精确 Station010/profile `ctrlX PLC 2.6.8` 且 offline；checkpoint `3b43f791...100e2` 校验一致。复用事务 writer，新增只接受已审阅 FB 实现 SHA 的升级入口；未知声明/实现、hash 漂移、保存后损坏仍拒绝或回滚。实际 Plan `e5003063...02f72`，两个 implementation PUT/一次 Save/全目标回读；最终 PlanOnly **0 操作**，SHA `c7746be7...4f648`。保存工程 SHA `36081bfc...1d83c3`。
- **本批 AI 新 F11：0 errors / 5 warnings**。观察到 Build started 和完成；逐条读取 4 × C0351 OPC.UA.DA、1 × C0373 SymbolConfig ErrorCodes/DWord，附加检查 0 errors；不把同数量旧 Build 当本次结果，也未扩大正式 warning baseline。七组回归通过（含全部 0..15 报文字节、NAK 不放行、已存在 FB 升级/回滚/幂等）；Project Pack Build/Check VALID，内容 ID `4f0eaab9...2ace` 未变。
- **未下载、未启停、未写变量/FORCE、未发送修正报文给仪表**。本次无需 CpStudio Export；用户确认现场安全后自行下载并重新发起自动，验证 ProgramNo=0 ACK → N045 放行 → 压缸/Kistler → 到位后力稳定 → 电阻测量 → 回升，再完成中/右及故障验收。未宣称现场已通过。
- 详细说明 `docs/reviews/station010-burster-rcl-20260909.md`；本地证据 `data/reports/plc/burster-rcl-numeric-20260909-{before,plan,apply,verification}.json`。Station010 原生成脏改保留，未暂存二进制、配置或凭据。

## 2026-09-10 · Burster 异步清理与取消续跑（当前交接）

- **先纠正待办：Auto Range 早已关闭并 Export。** 用户本次指出重复提醒，本轮现有 PLE REST 再次确认 `UseAutoRange := False`，保持不动，不再要求配置或导出。用户授权继续离线修改，不包含设备下载/启停/试测。
- 昨天最后现场记录已是正确 `*RCL 0`（17 字节），但 N045 仍因 ErrorCode=3/Open 超时退出；当时两个连接均 CLOSED，旧收发计数不是本次响应。初始 TCP 超时原因仍未证实，不能断言被标准驱动/厂家软件占用。此次修复的是可确认的异步生命周期缺陷。
- 只改 `FB_Wp100BursterProgramSelect` 实现与 StationUnit.OnCall 的取消清理片段：以方法返回值完成 Open/Write/Read/EOT/Close；放弃 pending 调用后持续 Reset，即使 IsOpen 已 FALSE；保留首次错误，新显式请求清旧计数；OnChainFinish 单次取消后由 OnCall 在 Execute=false/Busy=true 时继续清理。不启动程序选择、测量或运动，不自动重试。声明、SFC/Action、TypeData/StationData、BMK、量程、力和运动联锁不变。
- 唯一用户 PLE PID 19976、profile `ctrlX PLC 2.6.8`，REST 确认 offline。先保存用户当前工程并验证 checkpoint `1fdd8c7b...8b4f`；Plan `4e75350a...9f551`，两个 implementation PUT/一次 Save/40 目标回读成功。保存工程 SHA `6a1c0637...7a75d`，编译后不变；最终 PlanOnly 0 操作，SHA `4a1481ef...34ff`。MCP 未接管，不另起 PLE。
- **本批新 F11：0 errors / 5 warnings / 158 messages**，实际看见启动/完成和五条明细（4 × C0351 OPC.UA.DA，1 × C0373 SymbolConfig ErrorCodes/DWord）。打开工程时显示的 336 条 Symbol 旧警告不是本次编译结果；未清 Symbol 或改正式 warning baseline。七组离线回归、Project Pack Build/Check 通过，内容 ID `821ac91c...3270`；均不是运行库仿真/现场验收。
- **未下载、未连接实体 PLC、未发送仪表命令、未启停/FORCE。** 本次无需 CpStudio Export；用户确认现场安全后自行下载，验程序 0 ACK/标准驱动测量、取消恢复和完整左中右流程。如再失败，读取并保留首次 ErrorCode/LastSocketError/Busy/state。专用程序选择失败 HMI 事件仍需 CpStudio 建模，未借用压紧力事件。
- 详细可追溯记录：`docs/reviews/station010-burster-async-cleanup-20260910.md`。源码、语义合并 hook、writer、离线回归和计划同步；未暂存 Station010 二进制、标准库或连接凭据。

## 2026-09-10 · 自动压下后 N090 / Kistler 超时（最新，离线修复已完成）

- 用户本次自动已完成安全门/压缸下降。只读现有正确 Station010 PLE：程序选择 ProgramNo=0、Done TRUE、Error FALSE；N090 `_bursterStarted=TRUE`、结果未有效。锁存首个力诊断 `LEFT FORCE_DATA_INVALID F=2637.033 N`，不是 2500 N 阈值不足。Kistler 测量结束超时与状态失效相关；Burster 故障后标准 socket CLOSED 是取消后的快照，不能直接当成初始故障证据。PartCounter 服务超时另外保留。
- 确认源码交接缺口：selector 为选程序关闭标准连接，却在临时 Close 后直接 Done；N047 仅 Unit READY，没有显式标准 Open。已修复并写入：临时 Close → 标准公共 Open 完成才 Done，35 s 前置 watchdog，ErrorCode 11；取消/失败先标准 Reset → Close，异步未完成仍 Busy，保留首错。接口通过当前 PLE Library Manager 核对，没有改标准库、生成声明、量程、力/运动条件或增加自动重试。
- 用户确认 Logout 后先保存并校验 checkpoint `fefa4e5e...c170f`；Esc 暂停后，用户明确“继续”，再验 exact Station010/profile `ctrlX PLC 2.6.8`、offline、checkpoint 和 Plan。Plan `31d33db1...c6ed3`，**1 个 selector 实现 PUT/一次 Save，40 目标回读通过**；Run 27 步与声明不变。保存工程 SHA `ea870727...a5919`，编译后不变；最终 PlanOnly 0 操作，SHA `d8280461...625d`。未另起 PLE/MCP。
- **本批 AI 新 F11：0 errors / 5 warnings**，观察 Build started/complete，并实际读到 4 × C0351 OPC.UA.DA、1 × C0373 SymbolConfig ErrorCodes/DWord，与上一批一致，没有新增或变更正式 warning baseline。七组离线检查和 Project Pack VALID，contentId `945a1a26...90257e`。源码、事务和编译证据不等于运行库/仪表仿真或现场验收。
- 下一步由用户安全下载，验证标准 Open、SINGLE_MEAS 完成及左中右；若仍卡 N090，抓 Kistler 超时前的 Burster 接受/通信/完成状态。完整原因仍需新现场结果确认。无需再关 AutoRange 或 CpStudio Export。PartCounter 服务问题未处理，不冒充已解决。
- 记录：`docs/reviews/station010-burster-measuring-handoff-20260910.md`。本轮未执行任何 PLC/仪表命令、变量写入、FORCE、下载或动作；仅增加两个表达式监视项。

## 2026-09-10 · LEFT 成功后 MIDDLE 重连失败（最新，离线修复/编译已完成）

- 用户报告 LEFT 正常；MIDDLE 安全门关闭、压缸未下，HMI 11:26:42 报 `Socket handle invalid or closed / OpconTcpClientIpV4Stream.Close`。当前正确 PLE 只读确认 selector 首错 **ErrorCode=11**，LastSocketError -1/NativeErrCode 32766/AddText Close；临时报文 17/17 字节，EOT 1 字节、读取 2 字节。故障在标准 Open/handoff 阶段；后来取消已回 state=0，不能用此时库内部全 0 推断初始故障行。
- 已完成共享 FB 最小修复：每次临时 EOT/Close 完成后，标准 Reset -> ClearError -> Open 各成功才 Done；Reset/ClearError 3 s、原 Open 35 s。取消使用标准 Reset 完成后直接清临时 socket，删除上批的 Reset 后多余 Close。公开文档说明 Reset 已关闭流；此清理缺陷成立，但不等于证明第一次 Open-stage Close 错误的全部内因。
- 用户已确认 Logout；复核 exact Station010/profile、offline 后先保存并校验 checkpoint `42545d1d...89d`，再按 Plan `badd5cd7...19e` 执行 **1 个实现 PUT/一次 Save，40 目标回读通过**。声明、标准库、生成接口、量程、2500 N/2 s、27 步 SFC 和全部运动联锁均未改；未另起 PLE/MCP。
- **本批新 F11：0 errors / 5 warnings**，已观察 Build started/complete 并实际核对 4 × C0351 OPC.UA.DA、1 × C0373 SymbolConfig ErrorCodes/DWord，和上一批一致，没有调整正式 warning 基线。七组源码/时序/事务回归通过，Project Pack VALID（contentId `7e3cef46...bc558`）；不把源码合同或编译当运行库仿真/现场验收。
- 最终 Build 后 PlanOnly **0 操作 / 40 目标**（SHA `4d8fded0...6195e`）；工程 SHA `11c428eb...42bf` 与保存后相同，selector 实现 SHA `cae05d7f...373e2`。完整证据见 `docs/reviews/station010-burster-repeat-lifecycle-20260910.md` 和本地 `data/reports/plc/burster-repeat-lifecycle-20260910-verification.json`。
- **未下载、未执行在线变量写入/FORCE、复位或仪表命令。** 用户安全下载后验证左中右及下一完整件；本批无需 CpStudio Export。LEFT 是用户对上一批的报告，MIDDLE/RIGHT 和重复循环尚未验收。

## 2026-09-10 · MIDDLE 再次报错（解锁前中间记录，后续见下一节）

- 用户新截图 `codex-clipboard-6585f5d2-883b-40e9-855a-316c44117a69.png` 仍显示中间位置 `ETHERNET_TABLE General : Socket handle invalid or closed`。上一批 88f0980 的离线编译仍有效，但现场未通过；不能声称 Reset/ClearError/Open 顺序已经解决问题。
- 正确 PLE 项目/profile 与源码均确认；selector 实现 SHA `cae05d7f...373e2`，工程 SHA `11c428eb...42bf` 未变。GUI 激活失败并按恢复流程刷新后仍失败，未继续发输入；本轮没有读到新的 selector 首错，不复用旧 ErrorCode=11。
- 用户明确允许 AI 自行 Logout。使用安装目录官方 OpenAPI 定义的 ApplicationJob/Logout，job `9e9be36a1136bcab` 完成，Application.isOnline=false；无 Stop、Login、下载、运行变量写入/FORCE或仪表命令。
- 已只读复查全部 selector 调用点和标准对象/版本/公共 Reset/ClearError 文档；现有 Burster 技术手册未公开驱动内部连接实现，不能据此确认初始失败行。本轮未修改 PLC 源码或工程，未新 Build。请求用户保持开发桌面解锁，后续先取得新首错阶段再修复。细节见 `docs/reviews/station010-burster-repeat-followup-20260910.md`。
- **用户最新 GitHub 规则已写入 AGENTS**：现场版本稳定后再统一提交推送；调试期间只保留本地备份、源码和记录。本轮未提交/推送。

## 2026-09-10 · 新首错 13：移除正常交接的多余 ClearError（最新，离线完成）

- 用户解锁并允许只读 Login；实际未发送 Login POST，现有正确 PLE 已在线。只读 Watch 3 得到保留首错 **ErrorCode=13 / Number=-1 / NativeErrCode=32766 / AddText=OpconTcpClientIpV4Stream.Close**；该版本只在 state66 标准 ClearError 失败时设置 13，前序 Reset 已返回 OK。不是上一轮的 Open=11；供应商内部具体失败行未公开，不声称完成库内根因证明。
- 按用户授权自行 Logout，job `2ec66403b1e39302` Done，确认 offline 后修改。只删除共享 selector 的 state66 和相应取消入口，标准 Reset65 OK → Open70 OK 才 Done；不缓存位置间 Ready，不吞掉 Reset/Open 失败，临时 socket 的独立初始 ClearError 不变。保留声明、27 步 SFC、生成配置、量程、2500 N/2 s 和全部运动/安全联锁。
- 原 PLE/profile `ctrlX PLC 2.6.8` / compiler `3.5.19.70`。先 Save 用户当前状态，再校验唯一 checkpoint `f1e10d49ec955c6454f85a39b6ce97251858dda6ebed0b764e2d48be5b3ab630`。Plan `0b72cb2c...7f739`，**1 实现 PUT/一次 Save，40 目标回读，另 39 目标指纹不变**；未另起 PLE/MCP。
- 新增回归先对旧实现失败，修后七组源码/事务检查全通过；Project Pack VALID，contentId `95a44cc9...dd0ba`。用户恢复最小化窗口后，本批 AI 新 F11 实际启动/完成：**0 errors / 5 warnings / 155 Build messages**，4 × C0351 OPC.UA.DA、1 × C0373 ErrorCodes/DWord，与上一批同签名，未更改正式 warning 基线。不是 Clean Build/库仿真/现场验收。
- 编译后再次确认 offline，最终 PlanOnly **0 操作 / 40 目标**，SHA `d73ca73e...e0e3a5`；工程 SHA `80ccdf667c50c13960387506172cc2bc9799dd231098899cec4c4befc0112b14` 与 Save 后一致；selector 实现 SHA `4e10703b...ec38c8e`。完整记录在 `docs/reviews/station010-burster-repeat-followup-20260910.md`，机器可读证据 `data/reports/plc/burster-clearerror-20260910-*.json`。
- **未下载、未 Stop/Start、未写变量/FORCE或发送仪表命令；未提交/推送 GitHub**。无需 CpStudio Export。用户安全下载后复测左中右和下一完整件；本修复移除了已观察的新增 ClearError 失败点，但此前 Open=11 尚需现场重复验证，不能把离线通过标成全部现场问题解决。

## 2026-09-10 · 12:45:42 再复现（最新：诊断完成，通讯方案待确认）

- 用户 MIDDLE 新报警仍为 `OpconTcpClientIpV4Stream.Close` 无效句柄。现有在线 PLE 只读 Watch 新首错 **ErrorCode=11**（标准 Open），Number=-1，AddText Close；标准 socket 在取消后 ConnState=ERROR。Program loaded/unchanged、当前实现 SHA `4e10703b...ec38c8e` 与删除 ClearError 候选一致，工程 SHA `80ccdf66...112b14` 未变。不能归因于旧代码没下载，也不能把取消后状态当初始故障行。
- 按用户此前明确授权自行 Logout，job `9549bc2bf0ad72b5` Done，REST offline。未 Login、Stop/Start、写运行变量/FORCE、探测仪表、下载或动作；本次没有新的 PLC 实现修改或 Build，前批 0/5 仍只是历史离线结果。
- 完整复查共享选择器及所有调用点，并在当前 Library Manager 重验公开 API：NexeedIpBurster2316 1.0.1.0 只有测量/量程/生命周期方法，没有程序号或原始报文接口。当前双连接交接方案仍在标准 Open 边界失败；供应商内部原因尚未证明。OOD 的 CXA NotTested 只是支持状态，不作为库有 Bug 的证明。
- 下一步需确定通讯层方向：获取 Nexeed 支持的程序选择/连接接口；否则由用户批准单连接通讯适配（程序选择和测量同一 owner），保留 CpStudio/HMI、运动/力判定，涉及 CpStudio 绑定需按生成接口归属处理。未绕过程序确认、未永久缓存 Ready、未改私有句柄/标准库，未实现未经确认的替代驱动。详细新证据继续记入 `docs/reviews/station010-burster-repeat-followup-20260910.md`。**版本尚未现场稳定，不提交/推送 GitHub。**

## 2026-09-10 · 单连接驱动离线暂存（最新：待 CpStudio 解绑，不可下载）

- 用户“改吧”批准单连接方向。新增 `Application/Fbs/FB_Wp100BursterSingleOwner`，一个 OpconTcpClientIpV4 承担 RCL/readback/单次测量/取值/清理；实现公开 IBursterResis2316 与 LastError。标准库、生成接口/绑定、旧 selector、SFC/力/运动联锁均未修改。无实例，FB body 惰性，当前运行逻辑仍是旧方案。
- 使用现有唯一离线 PLE REST，checkpoint/冻结 Plan SHA/前置哈希/回滚/Save 后15对象回读。PLE 自动生成接口方法，首次创建冲突已成功回滚，之后分 shell + methods 两步写入；修正 reserved `r`、属性返回结构取成员和索引警告。最终 PlanOnly 0 操作，project SHA `ed7f11a5e71af70977d150b5e225e80e9b69145f652a93218cbfa426784a6e94`。
- AI 本轮 fresh F11 **0 errors / 5 warnings**（4×C0351、1×C0373 ErrorCodes/DWord），没有新签名；15 项协议参考模型/源码测试、七组现有回归及 Project Pack VALID，contentId `2374350e...2e5f7658`。这些不证明实际 TCP/EOC/仪表行为；未下载/测试设备/动作/提交/推送。最后 REST offline、旧 selector implementation SHA `4e10703b...ec38c8e`。
- 下一步用户在 CpStudio：Model/Station/Wp100/Wp100A103ResistantDetector → Parameters → Burster 2316 Channel 清空旧绑定；仅移除 Peripherals 下 `Wp100A103ResistantInterface`，保留 Model 的 Detector Unit 与 HMI。只读 UI 已确认旧通道 Active 灰色，右键仅 Remove，无 Disable。AI 没改 CpStudio；已复制其磁盘 Engineering 五文件至 `data/checkpoints/cpstudio/20260910-single-owner-before-unbind` 并校验源/副本 SHA，排除锁文件。
- Export 后必须由 AI 添加实例和非生成绑定 hook，将 selector 改为同 owner 委托并更新 N046 的已移除 Peripheral 引用；手动 Start 也要先按 active TypeData 程序选择（当前候选仅有显式 SelectProgram 方法，未接入手动前置）。SET_RANGE 明确不支持，不得假成功。接入后重新 Build/读回/检查 Symbol，再另行现场下载与完整重复循环验收。
- 详情、回滚证据、当前限制和接入步骤：`docs/reviews/station010-burster-single-owner-20260910.md`。**这是已编译的暂存通讯层，不是已接入或现场修好的版本。**

## 2026-09-10 · CpStudio 解绑后单连接接入（最新，待 Export #2 同步）

- 用户“已导出”，新 request `47c44845-dae8-4d94-a25c-006feee0d90e`。Stage 1 review 仅生成变更待审，56/56 I/O 完全匹配；REST 确认旧 Peripheral 实例、注册/任务/参数调用和 Unit 生成绑定全部移除，新驱动 15 对象原样保留。导出后新 F11 确认 **50 errors / 5 warnings**，错误来自旧 selector/N046 的已删除 Peripheral 引用。
- 按已批准单连接方向：新增 `AiWp100.Burster` 唯一实例；Wp100Unit.OnApplyParameters 在 OES 外 STARTUP/CONFIGURATION/ONLINE_CHANGE 绑定标准 Detector Unit，192.168.0.103:5555、30 s 测量上限；OnCall 仅复制 active TypeData.ProgramNo，不调用网络/测量。CpStudio 的可选通道必须保持未分配，不能再次绑定旧 Peripheral。
- selector 改为无 socket 的同 owner Open/SelectProgram 委托；取消未完成 Open/Select 走同 owner Reset 并由现有 Station OnCall 续跑，Done 后落 Execute 不会重置后续 Unit 测量。N046 改查 Connected/SelectionVerified/ProgramNo/idle/ErrorCode，不假置 OK。N045/N047、全部运动/位置/力判定和标准 Unit SINGLE_MEAS/结果上下限保留。
- 手动 SINGLE_MEAS 同样由 owner 按 active TypeData 程序准备；必要时 Open/RCL，同一程序的已验证选择不重复 RCL，但每次 INIT 前重新 RCL? 核验。命令中 TypeData 程序变化拒绝；错误不自动重试。手动 SET_RANGE 明确禁用而非假成功，量程/补偿随仪表程序；温度读取仍按 CmdSetting.ReadTemperature。
- 原 PLE/profile `ctrlX PLC 2.6.8` 全程 offline；写前 checkpoint `3f4736fd9f99924e7a956ba24d81476e2d8bd2d895ff01ddb4621cc81afb2e95`；9 个对象 PUT/Save 后 21 目标回读一致，工程 SHA `fbd91124bea48c8e3aefa3dad14429f9e8b90a19dd702d65a5a94f56c109e328`。writer `apply_burster_single_owner_rest.ps1 -Integrate`：Plan SHA `325df1dc...d2928fb`；Build 后 final PlanOnly SHA `e2a59a12...5bf1615`、0 修改；Run writer 40 目标也 0 修改，SHA `68e943a7...d48003f`。
- **本轮 fresh F11：0 errors / 5 warnings / 189 Build messages**（Messages 总 190）。界面完整显示 4×C0351 OPC.UA.DA、1×C0373 SymbolConfig ErrorCodes/DWord（line2378），原签名，无新告警。17 项协议参考模型/源码检查、七组现有静态/时序/事务回归与 Project Pack Build/Check 通过；不是运行库仿真/仪表验收。
- **必须再 Export #2**：只读打开 CpStudio Output/PLC Export，仍显示 `Error getting the symbol configuration! ... Build has error(s). You need error free build to proceed`。它对应新驱动接入前的失败导出；新 Build 并不会补做该 Symbol 步骤。已请用户再导出、先不下载，之后重新 Stage 1/钩子与绑定回读/新 Build。未自改 Symbol 或 formal warning/semantic baseline。
- Stage 2 ledger `cpstudio-stage2-47c44845-dae8-4d94-a25c-006feee0d90e-00d3cfed` 仍 WAITING_FOR_RUNNER；当前 MCP 未持有这个 PLE，不能把 REST/UI 独立证据冒充 Runner typed-evidence/DONE，且接入修改后其原 manifests 已旧。不要启动第二个 MCP PLE，不要重用旧 immutable action；后续新 Export 创建新动作。
- **无 Login/下载/PLC启停/变量写入/FORCE/仪表连接，无 Git 提交推送。** 后续现场至少验手动、左中右及下一整轮、程序变化、取消/故障恢复、无重复 INIT/旧结果，以及原压紧力联锁。EOC/FETC 清零、设备格式和库真实生命周期仍需现场验证，不宣称重复位置故障已被现场解决。

## 2026-09-10 · Export #2 复核完成（最新，交用户现场测试）

- 用户新导出 request `c5beb205-8e88-4657-a986-a3faa2342de3`（05:58:18 UTC）。Stage 1 预演后仅消费此请求；21 个历史生成变更待审，I/O 56/56 匹配、38 active / 18 inactive、0 mismatch。没有改动任何 PLC/CpStudio 源码或工程。
- 当前唯一 PLE REST 确认正确 Station010 / ctrlX PLC 2.6.8 / compiler 3.5.19.70，检查前后 `isOnline=false`。单连接 writer `-PlanOnly -Integrate` 21 目标、0 修改，SHA `e2a59a12...5bf1615`；Run writer 40 目标、0 修改，SHA `68e943a7...d48003f`。旧 Peripheral 仍移除，新实例、非 OES 绑定和手动/自动入口完整保留。
- 实际 CpStudio Output / PLC Export 为空，无上次 Symbol 报错。随后 AI 在同一离线 PLE 新按 F11，看到 Build started → Build complete：**0 errors / 5 warnings / 189 Build messages**（总 190），4×C0351 OPC.UA.DA、1×C0373 ErrorCodes/DWord，原签名。不能用旧 Build 代替本轮结果。
- 本轮 Symbol XML 于 06:03:42.5637583 UTC 重新生成，SHA `0455ce88...590ef8c`；StationData、TypeData、Burster.ProgramNo 及 Detector Extension 的 HMI 命令/状态读写字段存在，旧 Peripheral 名称 0 次。REST symbol-config HTTP 200，但 payload 的 JSON 解析仍失败；未改 Symbol/未打印原文，以实际干净 Export + 新 Build + XML 做本轮局部核对，不声称完整 Runner semantic baseline 通过。
- 导出后/Build 后工程 SHA 相同：`077eebed69481d90e6f07ff5a4eccc2ec4eeaab3712d7ed704e2cfb2caf2c886`。17 项协议/源码测试及程序量程、力联锁、SFC 完成契约三组回归重新通过；不是 PLC 运行时或仪表实测。
- Stage 2 新 ledger `cpstudio-stage2-c5beb205-8e88-4657-a986-a3faa2342de3-7064637d` 仍 `WAITING_FOR_RUNNER`，独立证据见 `data/reports/plc/burster-single-owner-export2-verification.json`。没有启动第二个 MCP/PLE，没有伪造 typed evidence/DONE。
- **无需再常规 Export。** 下一步用户安全下载，并按本次工程同步 IPC HMI/DataSetAccess（尚未核验部署），先手动 SINGLE_MEAS，再 LEFT → MIDDLE → RIGHT，至少重复下一整轮。取消/故障恢复、程序切换和原力联锁另行安全验收；出现首错保留诊断，不反复自动重试。AI 无在线写入/仪表请求/动作，无 Git 提交推送。
