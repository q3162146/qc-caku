# R5 真机 DeviceDiag 启动日志（真我GT大师探索版 RMX3366 · Android 14）

- 抓取时间：2026-08-22 00:29:49（游戏冷启动）
- 方式：Wi-Fi 无线调试 adb logcat（本机 adb，无需 USB）
- 系统对比：wm size = 1080x2400，wm density = 480（font_scale 1.0，无强制密度）

```
08-22 00:29:49.797 I/Urho3D  ( 4621): [2026-08-22 00_29_49_797][120][Script] === 桃素洛无幽·素女篇 启动（S2 对话会话） ===
08-22 00:29:49.798 I/Urho3D  ( 4621): [2026-08-22 00_29_49_798][120][Script] [main] 单机模式校验通过 | source=IsNetworkMode() | networkMode=false
08-22 00:29:49.798 I/Urho3D  ( 4621): [2026-08-22 00_29_49_798][120][Script] [main] 竖屏由发布元数据锁定，跳过运行时 SetOrientations
08-22 00:29:49.799 I/Urho3D  ( 4621): [2026-08-22 00_29_49_799][120][Script] [DeviceDiag] 启动方向核对 | orientation=Portrait | physical=1080.0x2400.0 | DPR=3.0 | logical=360.0x800.0 | safeInsets=0.0,108.0,0.0,0.0 | scene= | paragraph=nil | dialogueOpen=false | touchEnabled=true | touchCount=0.0 | touchControlsReady=false
08-22 00:29:49.881 I/Urho3D  ( 4621): [2026-08-22 00_29_49_881][120][Script] [DeviceDiag] 启动完成 | orientation=Portrait | physical=1080.0x2400.0 | DPR=3.0 | logical=360.0x800.0 | safeInsets=0.0,108.0,0.0,0.0 | scene=chaoyang_gukou | paragraph=P02 | dialogueOpen=false | touchEnabled=true | touchCount=0.0 | touchControlsReady=true
```

## 关键结论
- physical=1080x2400 与设备规格一致 ✅
- DPR=3.0 ↔ 系统密度 480（非检查表示例的 2.75，以实际为准）✅
- logical=360x800 = 1080/3 x 2400/3 公式一致 ✅
- safeInsets=0,108,0,0（左/上/右/下；108 为顶部挖孔条区域，非底部手势条）
- orientation=Portrait ✅
