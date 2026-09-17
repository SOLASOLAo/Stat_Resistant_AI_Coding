# Kistler 5867C 集成包 — 0.1.0-rc.2

保留Nexeed标准EtherCAT Peripheral和Unit。本包管理自研应用接入逻辑、设备设置
基线及测试，不替换标准驱动，也不分发它的库/ESI/手册。

相对 rc.1，本站 N050/OnChainFinish 等参考包含新增只读 ForceTrace 钩子；本版锁定实际未提交源码摘要，旧包不覆盖。记录器及 14 DWORD v1 发布协议由配套 `bpp-forcetrace 0.1.0-rc.2` 提供，按该包接入后才可编译这些参考；也可在新工位明确不选记录功能，仅审阅移除 `AI_HMI_FORCE_TRACE_BEGIN/END` 片段，不能删掉过程门禁来消除依赖。

## 本版选程合同

1. 从当前TypeData捕获目标程序，同时赋值`SetProgram.ProgNo`和`Measure.ProgNo`。
2. 实际程序已匹配、Ready、无Alarm、Unit空闲且不在测量时，跳过重复SET_PROGRAM。
3. 其他情况使用标准SET_PROGRAM和CheckUnitDone；确认目标/实际程序、Ready、
   无Alarm、无测量并且Unit回到READY后才放行。Done要锁存，不反复消费导致重发。
4. N050/N051保留安全反馈及程序匹配检查；先收到MeasRunning才请求压缸下降。
5. 新执行/取消复位本方法状态；不改Ready/PDO、不主动消警。只有本链测量实际运行
   才能请求END；取消仍由标准Unit Execute下降沿完成。

`station-reference`文件含Station010实例、SFC、按键、力监控与气缸引用，**不是
可独立导入的新驱动**。新工位必须按其模型重绑定；不能删掉依赖检查后直接使用。
包内N000/OnChainFinish只是接入位置参考，不授权替换另一个项目的整个方法。

## 设备配置基线与经验

- 当前硬件为5867C001；实际固件版本尚未登记，不能用ESI包版本代替固件。
- 程序MP001用于生产，目标值和实际反馈分别检查，HMI输入框的1不等于实际已选1。
- 用户仅勾选MP000 Active，未配置/复制其内容；现在MP000/MP001均Active，手动
  Set program=0/1用户报告正常，随后一轮自动完成。该组合保留为**本站实测经验**，
  不宣称所有maXYmos都必须双激活，不自动激活新设备的未知程序。
- 用户报告已设力—时间Y(t)、Start/Stop均Dig-Input；新设备应核对现场总线映射，
  不能只按菜单名称推断握手正确。
- 力来自`OutImm.ForceAct`；本工艺没有位移传感器，不能用Stroke显示值作为位移证据。
- 力复位必须核对实际传感器/放大器方式及OPERATE/START关联；Zero X不是力复位。
  本包不新增Tare/RESET命令，也未单独验收每轮力复位。
- MeasuringTimeout是测量总超时，不是力达标诊断时间；Start之后必须由正常流程
  发End，不能靠把超时改为0掩盖遗漏的结束命令。

## 版本特别注意

2026-09-10记录的实际库：NexeedEcKistlerMaxymosBl **2.0.1.0**、
AtmoKistlerForceStroke **1.2.2.0**、**AtmoKistlerForceStrokeBase 1.2.1.0**；2026-09-11 对当前离线 PLE 再次只读核对了完整名称和版本。
CpStudio对象包 **2.0.7.0** 与实际PLC库版本不同，是不同层次的编号，不因此自动升级。
本次只读使用已有 CpStudio PLE REST，不连接实体 PLC，不改变任何库引用。

## 检查与下一步

在包根目录执行：

```powershell
pwsh -NoProfile -File tests/static/Test-Wp100KistlerProgram.ps1
```

这是源码合同和独立状态模型，不执行PLC代码。已有一轮完成不代表连续采力、质量
判定、再次启动/断电恢复或另一固件兼容通过。仪表内部完整曲线读取不在本包实现范围；ForceTrace 提供 PLC 实时力 y(t) 的 HMI 观察记录。

版本升级必须同时审阅代码、依赖和仪表配置；不能只回退ST、保留不匹配的配置。
同一版本包不覆盖，先在隔离工程编译和受控现场测试。详见[公共版本规则](../README.md)。
