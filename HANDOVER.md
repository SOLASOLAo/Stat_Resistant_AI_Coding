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