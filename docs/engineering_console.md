# 工程控制台（Engineering Console）

工程控制台把现有 Runner、Host、Project Pack 和 CpStudio/PLE 人工步骤集中到一个
Windows 界面中。它解决的是“脚本入口太多、当前步骤不清楚”，不会再造一套 Runner，
也不会用鼠标自动化代替 CpStudio。

## 启动

在本仓库根目录用 PowerShell 7 执行：

```powershell
pwsh -NoProfile -File .\scripts\workbench\Start-CtrlXOpconWorkbench.ps1
```

仅做无界面自检：

```powershell
pwsh -NoProfile -File .\scripts\workbench\Start-CtrlXOpconWorkbench.ps1 -SmokeTest
```

## 使用原则

- 日常先点“刷新全部状态”，再点“推进下一安全步骤”。
- Runner 能自动完成的步骤由原 Runner 执行，证据仍写入原 JSON/manifest。
- 界面提示 CpStudio Import/Save/Write designators/Export 时，由用户在 CpStudio
  完成；界面不会模拟鼠标键盘。
- PLE `Link I/O with variables` 当前仍是一次人工操作。
- P2 的 IOE Apply、P3 Link I/O 自动化和 P4 DAT 部署在正式后端门禁完成前保持
  禁用，不能因为界面上有进度卡就视为已实现。
- 本工具没有连接 PLC、下载、启停 runtime、写变量或 FORCE 功能。

通用模板和实现说明记录在 `ctrlx-ai-coding` 方法论仓库的
`docs/engineering_workbench.md`；本项目 GitHub 只记录自己的启动和使用边界。
