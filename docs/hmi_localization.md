# 电阻与力曲线 HMI 中英文接入

2026-09-11，HMI-ZH-EN-20260911。本地配置已保存并导出；IPC 运行时语言切换尚未验收。

## 晚间菜单补齐

在 CpStudio 原生语言字段新增“手动功能、测试功能、操作引导、工位指示灯”及操作引导页标题；
保存用户已输入的“换型”，保留“主界面/自动/手动/回原位”。本次 HMI 单独 Export 为 **0 errors / 原 2 warnings**。
模型仅变更 5 个 HMI 文本和 1 个模式文本的 zh_CN，没有添加/删除模型行；中文导出共更新 10 项，英文不变。
VWN 除 DateLastModified 外完整相同，PLC 工程/Symbol 和两张业务 SFC 未改。
0.1.0.2 候选上的 48 项资源、36 项动态提示及英文宽度检查通过；未调用运行时语言管理器冒充现场验收。
证据 `data/reports/hmi/force-trace-startup-20260911/menu-model-diff.json`、`menu-export-diff.json`、`localization/`。
IPC 只读核对仍为旧语言文件；这些新文字需随下一次已授权的 HMI 部署生效。

CpStudio 的 en-US / zh-CN 均启用了运行时 State。新增 6 个 Station 原生 Text：`ResistanceLeft/Middle/Right` 及各自的 `Pending` 文本。UserDefined 的数值标题与未完成提示通过原厂 LocalizedText/TextGroup 引用这些资源，菜单为“测量结果 / Measurement results”。OK/NOK 使用既有 `NexeedStateAddon.Nok/Ok`；`mΩ` 和中性占位 `—` 保持不随语言变化。

ForceTrace 沿用原有 18 个 Station 原生 Text，位置、按钮、坐标轴及动态提示均复用现有绑定。本次没有改变扩展 DLL 或注册文件，也未增加第二套翻译机制。

## 保存与范围核对

- 6 个 Text 经 CpStudio 原生导入、Save 后回读；页面菜单通过属性编辑器保存。
- UserDefined 在关闭设计页后精确替换文本引用，并经原厂 SFCLoader 及 CpStudio 打开、保存、关闭、HMI Export、重开验证。
- 原 5 个控件、9 个电阻显示控件的数值/Valid/Ok 绑定、Visible/颜色门控、坐标、字体、944×572 画布和图片资源保持。新 SFC SHA-256：`7AB00C02F4150E1DF30DC8A06617B04C1669107692B1C88B706662D583E789BC`。
- 模型新增 6 行 HmiLogic/HmiTextData/MultiLanguageString/VarBaseData 和 12 行语言数据；旧数据只变更 UserDefined 菜单的 en_US/zh_CN 及原生 `PlcExportId`。没有删除旧行。
- HMI Export 为 **0 errors / 2 条原有 Burster 平台 warnings**。VWN 只增加 6 个文本索引及修改时间；两个 `.lng` 只增加对应文本、更新菜单。变量、连接、报警、配方、用户等其他分支保持。
- HMI 导出前后 PLC 工程与 Symbol 哈希完全一致。之后的 Changeover 离线修复另行改变 PLC 工程；Symbol 仍未变。

最初导入片段因 PowerShell 7 生成的 .NET 10 `System.Guid` schema 被 CpStudio 拒绝，模型未增加文本。改用 Windows PowerShell/.NET Framework 后原生导入成功；不要再次导入已存在的 6 个资源。

## 验证证据与边界

`tests/hmi/Test-HmiLocalization.ps1` 用 Windows PowerShell 5 运行，加载实际安装的原厂控件/ForceTrace DLL、本站 SFC 与实际导出的语言文件，不建立 PLC Item 连接：

- 48 项导出文本检查通过：6 个电阻资源、18 个曲线资源，各核对两种语言。
- zh→en→zh 的 36 项动态提示检查通过，覆盖 12 个曲线状态；原生 TextChange 处理更新按钮、坐标轴和状态。
- 电阻未完成/结果、曲线完成/断线等离线渲染已目视检查，最长英文名称和提示宽度适合现有布局。

这些检查把导出翻译注入内存中的原生文本对象，并模拟显示状态。独立运行时 LanguageManager 检查未能初始化，**不能据此宣称实际 HMI 语言切换通过**。所有实验进程均已结束。下一步在另行授权部署后，通过原生语言入口实际切换 zh→en→zh，核对电阻结果、曲线运行/结束/取消/断线及保存提示。

本地证据：`data/reports/hmi/hmi-zh-en-changeover-20260911/` 下的 `localization-scope.audit.json`、`resistance-candidate.audit.json`、`resistance-loader.audit.json`、`previews/localization-check.json` 与 PNG。完整配置备份留在忽略目录，包含敏感配置，不应直接暂存或输出。

本批未下载 PLC、未部署 IPC、未提交或推送 GitHub。
