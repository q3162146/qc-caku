# TTM 粘贴块：视频生命周期 Spike 浏览器/WASM 构建与验证（2026-08-22）

> **用法（这一节不要粘给 TTM）**
> - 本块 = 让 TTM 去【构建 + 浏览器 WASM 预览验证 Spike】的任务说明；整段复制发给 TTM 即可。
> - 前置背景：项目已实现 B｜视频生命周期 Spike，`scripts/experiments/VideoSpike.lua` + `scripts/main.lua` 的 F6 触发；引擎视频为 **WASM-only**，真机小游戏容器无视频能力、也无 F6 键盘，所以**必须在 PC 端 TapTap 开发者工具 / 浏览器（WASM 预览）验证**。
> - 素材：`assets/Videos/S1_test_low_3Mbps.mp4` / `_mid_6Mbps` / `_high_10Mbps` 三支测试视频已就绪；权威参考 `engine-docs/recipes/video.md`。
> - 若 TTM 看不到 `assets/Videos/` 或 `scripts/experiments/VideoSpike.lua`，请它先说明，勿自行脑补。

══════════════════════════════════════════════════════
以下为粘贴内容（整段复制）
══════════════════════════════════════════════════════

【任务｜视频生命周期 Spike 的构建与浏览器/WASM 验证】

背景：本项目《桃素洛无幽·素女篇》已实现一个独立实验模块 `scripts/experiments/VideoSpike.lua`（视频生命周期 Spike，为 S6 正式接入做前置技术验证），并在 `scripts/main.lua` 用 **F6** 触发 `VideoSpike.Toggle()`。引擎视频明确 **WASM-only**，真机小游戏容器无视频解码能力、也无 F6 键盘，因此必须用 **PC 端 TapTap 开发者工具 / 浏览器（WASM 预览）**验证。请按以下步骤执行并回填结果。

## 一、请你做的事

1. **官方构建**（确保包含新增文件，不裁掉资源）：
   - `scripts/experiments/VideoSpike.lua`（及同目录 `VideoSpike.lua.meta`）必须被 `asset_dirs` 收录；`main.lua` 已 `require "experiments.VideoSpike"`。
   - 构建成功后再进入预览，否则浏览器预览里没有 F6 / 没有 Spike 模块。

2. **用 TapTap 开发者工具 / 浏览器打开构建产物**，进入游戏（看到白模场景、虚拟摇杆 + 跳跃键）。

3. **触发 Spike = 按 F6**。
   ⚠️ **若浏览器预览无法按到 F6**（键盘事件未到达引擎 / 画布无焦点 / 被框架或 DevTools 吞掉 / 该预览不支持 F 键），**请做下述修改**并写进汇报：
   - 在 `scripts/main.lua`（或 `VideoSpike`）里追加一个**屏幕上的调试触发**：比如一个小角标按钮（`UI.Button`，onClick = `VideoSpike.Toggle()`）或读取入口/URL 参数（如 `?spike=1` 启动即运行 Spike）。核心目标：**在 WASM 预览里能可靠触发 Spike**。
   - 说明你新增的触发方式，触发后 Spike 自动跑 A→E 五场景约 30 秒并自动结束；再次触发可强制中断。

4. **抓 `[VideoSpike]` 日志**（Lua `print()` 会进 devtools console，筛选 `VideoSpike`）：
   - Spike 结束时会把汇报拼成**一段连续的 `[VideoSpike]` 块**一次 print（可整段选中复制）；并 `SendEvent("VideoSpikeReport", { report })`；也可在脚本里 `VideoSpike.GetReport()` 读取。
   - 需要的关键行：`A onReady/onPlay/onPause/onEnded`、`A seek确认 #1/#2（t=… diff=…）`、`B-low/B-high onReady`、`C 汇总｜ready=… error=… 存活实例=…`、`D 第N次建销｜存活实例=…`、`E …→PAUSED_AT_TARGET→REVEAL`、结尾 `结束存活实例数 → 0`。

5. **全程录屏 + 关键截图**（视频画面 / 顶部状态行 / 加载遮罩→REVEAL 过程）。

## 二、按此格式回填（附具体数值）

| 验证项 | 结果 |
|---|---|
| 三档码率（low/mid/high）是否全部被接受播放 | |
| onReady / onPlay / onPause / onEnded / onTimeUpdate 是否全部触发 | |
| Seek(3.5) 精度：确认时的当前时间、两次确认差值 | |
| 同屏 3 播放器行为（报错/排队/内存） | |
| 销毁后播放器实例数量是否归零 | |
| 切后台/回前台、通知栏返回时视频行为（自动暂停？恢复？） | |
| 视频内中文标题渲染是否正常（与 23 字符集字体预检关系） | |

**结论**：是否满足《22》§2 规格（H.264 High/yuv420p/1080×1920/30fps/AAC-LC 48kHz）；**S6 能否按此规格接入 13 段断点视频**（《21》§5）；遗留风险清单。

## 三、注意事项

- 播放器全程 `muted=true, volume=0`：**静音自动播放**多数浏览器允许；首次 F6 已补 `primeAutoplay()` 手势解锁（改屏幕按钮触发时，那个按钮的 onClick 也属于用户手势，同样能解锁）。
- **竖屏素材**需 `textureWidth/Height=1080×1920`（Spike 已设，勿改回指南默认横屏 1920×1080）。
- 播完必须 `Destroy()`；Spike 结束会销毁全部播放器并恢复 UI 根；`ClearChildren()` 不会释放视频资源。
- **≤2 播放器约束**：Spike 的 C 场景会**同屏建 3 个**观察实际行为（成功/排队/报错/内存），请如实记录。
- Spike 与 F6/屏幕触发都是调试/实验代码，**S9 发布前必须移除**。
- 若实测与 `engine-docs/recipes/video.md` 不符，记录差异并给出文档修订建议。

══════════════════════════════════════════════════════
粘贴内容到此结束
══════════════════════════════════════════════════════

---

## 给用户（不要粘给 TTM）备忘

- 本块重点 = 让 TTM **构建新构建 + 浏览器 WASM 预览 + 触发 Spike + 回填**，并**若按不到 F6 就补一个屏幕触发/入口参数**。
- TTM 回贴后，把「[VideoSpike] 日志块 + §二 表格 + 结论」粘回本会话，我据此更新《TTM-视频Spike结果汇报.md》与《21》的未确认清单/排期。
- ttm 构建时若把 `scripts/experiments/VideoSpike.lua` 或因 `.meta` 缺失而漏收，请它核对 `asset_dirs` 与资源打包。
