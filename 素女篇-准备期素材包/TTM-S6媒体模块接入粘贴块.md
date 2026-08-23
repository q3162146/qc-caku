# TTM 粘贴块：S6 视频媒体模块接入（实现）

> 用法：整段复制发给 TTM。依据《21》§5/§6（断点表 + 恢复策略 + 三步状态机）与视频 Spike 真机结论。

══════════════════════════════════════════════════════

【S6 视频媒体模块接入｜实现】

目标：实现正式剧情视频播放 / 断点 / 读档恢复，接入 Chapters 的 `video` 段落（P01=S1 等），播完推进 flow。

## 一、新建 `scripts/media/MediaPlayer.lua`

对外接口（供 FlowController / main 调用）：
- `MediaPlayer.Play(paragraph, data)` —— 播放段落指定视频；`data` = 清洗后的 PlayerData（读写 `mediaPos`）。
- `MediaPlayer.Update(dt)` —— 每帧驱动（定时器 / 冻结空窗检测）。
- `MediaPlayer.IsPlaying()` —— 是否播放中。
- `MediaPlayer.Stop(boolRelease)` —— 显式停止 + 释放（离开场景 / 段落切换 / 退出用）。

内部状态机（对照《21》§6.2 三步）：
```
CREATING → (onReady) READY
          → 若 data.mediaPos.node==p.id 且 timeSec>0 → SEEK_READ
          → 否则 PLAY
SEEK_READ → Seek(mediaPos.timeSec) → onTimeUpdate 双确认(≤0.15, 超时重试≤3) → PLAY
PLAY      → Play()；onTimeUpdate 按 p.breakpoints 检测到断点 at → 写 mediaPos + Pause + 触发交互(act)
PAUSED_AT_BREAKPOINT → 交互完成(三选锁定) → Play() 继续
ENDED(onEnded) → 释放(Destroy/Dispose) → CompleteParagraph({done=true}) 推进 flow
```

## 二、关键约束（必须遵守，来自《21》+ Spike 真机结论）

1. **断点**：按 `p.breakpoints`（如 P01 `{at=-1, act="auto"}`；`at=-1`=播完自动）。断点时间以「暂停那一刻」为准，`at` 前 0.5s 不设（防闪帧）。
2. **mediaPos 写**：仅剧情视频播放/暂停/断点时写 `{node=p.id, video=<videoId>, breakpoint=序号, timeSec=当前秒}`；循环背景不写（§8）。
3. **读档恢复**：seek 后**必须确认到达**再显示（三步：就绪→seek确认→移除遮罩），禁止「就绪=到位」。
4. **🔴 真机 Seek 不回退**：真机 `VideoPlayer.Seek()` 可能不把时间拉回（PC 正常）。对策：断点/恢复 seek 加**重试 ≤3** + 若反复失败则**降级**为「自然播放到目标」或从当前位置继续（记录差异）。
5. **🔴 真机无 `AppDidEnterBackground`**（虚拟手势下不触发）。后台/前台不依赖该事件；改用**冻结自愈**：`GetCurrentTime()` 空窗 >1.5s 无推进 → 记录 `mediaPos.timeSec` → `Pause(); Play()` 自愈 ≤3 次 → 时间恢复后续播。生命周期事件仅作辅助日志。
6. **同屏 ≤2**：剧情视频 1 + 循环背景 ≤1；超限先释放旧循环背景（《21》§6.3）。播放结束即释放（尤其 S6 系列 5 段连播段间必须回收，防无声/旧场景串台）。
7. **资产映射**：`videoId("S1")` → 实际文件路径。目前 `assets/` 只有测试视频 `video/短视频生命周期 spike（推荐）/S1_test_*.mp4`，**无正式 S1.mp4**——请先确认正式剧情视频资源路径（或先用测试视频占位映射，注明来源差异）。
8. **释放**：播放结束 / 离开带视频场景 / 段落切换 → 显式 `Destroy()` + 清除残留；目标设备记录播放器数量与内存峰值（§7-6）。

## 三、接入点

- `scripts/flow/FlowController.lua` `EnterParagraph` 的 `p.type=="video"` 分支（现 76-79 行自动跳过）：改为 `MediaPlayer.Play(p, data_)`（替换自动完成）。
- `scripts/main.lua` `HandleUpdate`：加 `if MediaPlayer.IsPlaying() then MediaPlayer.Update(timeStep) end`（与 Spike 同理）；场景切换/退出时 `MediaPlayer.Stop(true)`。
- `scripts/config/PlayerData.lua` `mediaPos` 已就绪（node/video/breakpoint/timeSec + Sanitize），无需改。

## 四、验收（对照《21》§7）

1. P01(S1) 能进视频 → 播放 → 播完进 P02。2. 断点（有 at 的）在断点处暂停 + 写 mediaPos + 交互。3. S6 系列 5 段连播无无声/无重复/无上段回调串台。4. 读档（mediaPos）恢复：不闪现第 0 帧、断点不重复触发。5. 前后台/通知栏返回从正确位置续播（冻结自愈）。6. 退出带视频玩法后播放器归零、内存回落。7. 系统在真机 + PC WASM 各回归。

══════════════════════════════════════════════════════
粘贴到此结束
══════════════════════════════════════════════════════

---

## 给用户备忘（不要粘给 TTM）

- 本块 = S6 正式媒体接入的实现规格（新建 MediaPlayer.lua + 改 FlowController/main + 按《21》§5/§6 + Spike 真机结论）。
- 🔴 两个真机坑要 TTM 特别注意：① Seek 真机不回退（加重试+降级）；② 无 AppDidEnterBackground（用冻结自愈）。
- ⚠️ 正式剧情视频素材（S1.mp4 等 13 段）目前还没有，需 TTM 先确认资源路径或用测试视频占位。
- TTM 实现+构建后，回传结果我核对并回填《TTM-视频Spike结果汇报.md》/《21》未确认清单。
