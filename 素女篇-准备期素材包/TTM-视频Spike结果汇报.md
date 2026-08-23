# TTM · 视频生命周期 Spike 结果汇报（2026-08-22）

> 任务：见《TTM-视频Spike粘贴块.md》【B】。权威参考：`engine-docs/recipes/video.md`、`examples/19-video-player-ui.lua`。
> 约束：一次会话只做本任务；不修改 Chapters / FlowController / 正式剧情流程；Spike 为独立实验模块。

## 一、交付物

| 文件 | 说明 |
|---|---|
| `scripts/experiments/VideoSpike.lua` | 独立实验模块：5 场景串行 + 后台/前台事件订阅 + 汇报汇总 |
| `scripts/experiments/VideoSpike.lua.meta` | 资源 UUID 元数据（构建导入所需） |
| `scripts/main.lua` | 仅接入 3 处：`require`、`F6` 触发 `VideoSpike.Toggle()`、激活时每帧 `VideoSpike.Update(dt)`；未改动正式剧情/流程 |

**触发方式**：在 **PC 端 TapTap 开发者工具 / 浏览器（WASM 预览）**中进入游戏后按 **F6** 开始整条 Spike 序列（再按 F6 强制结束）；约 30 秒自动跑完并结束。真机小游戏容器通常无视频解码能力且无键盘，不能按 F6，**Spike 应在 WASM 环境验证**（引擎 video 明确 WASM-only）。序列为：
`A 生命周期(mid) → B 三档码率(low/high) → C 同屏3播放器 → D 建销×3计数 → E 三步恢复状态机 → 汇总 → 恢复 UI 根节点`。

## 二、实现要点（对照视频指南）

- **必须用 Widget**：全部经 `Video.VideoPlayer{...}` 创建，`objectFit="contain"`；未裸搓 C++ + NanoVG。
- **纹理尺寸**：素材为**竖屏** 1080×1920，故显式设 `textureWidth=1080 / textureHeight=1920`（指南默认横屏 1920×1080，示例 `19` 也是横屏，本项目必须覆盖）。
- **回调**：`onReady / onPlay / onPause / onEnded / onTimeUpdate(self, time, dur) / onLoadError` 全部挂钩并打 `[VideoSpike]` 日志。
- **Seek 两次确认**：`Seek(3.5)` 后，在 `onTimeUpdate` 里累计 `|t−3.5| ≤ 0.15` 连续两次才判「到达目标」，命中后 `Pause` 并记录 `GetCurrentTime()/GetDuration()`。
- **三步恢复状态机**（存档契约第 9 条）：`CREATING → WAIT_READY → REQUEST_SEEK → WAIT_SEEK_CONFIRM → PAUSED_AT_TARGET → REVEAL`；用「等待 3s → seek 到 2.0s → 连续确认 → 移除遮罩」模拟一次读档恢复。
- **播放器计数**：`widgets_` 追踪存活实例；`Destroy()` 显式释放（含 `nvgDeleteVideo` + `player_:Dispose`），结束时日志确认归零。
- **后台/前台**：订阅 `AppDidEnterBackground / AppDidEnterForebackground`，后台若在播则记录并 `Pause`（演示 mediaPos 断点写入），前台记录号。
- **浏览器适配**：① 首次按 F6 是真实用户手势，`Toggle()` 内 `primeAutoplay()` 立即对媒体元素触发一次 `play()` 以解锁浏览器自动播放（Spike 全程 `muted`，多数浏览器本就允许静音自动播放，此为从严 iframe/预览兜底）；② 结尾把汇报整合为一段可整段复制的 `[VideoSpike]` 汇总块一次 `print`，并以自定义事件 `SendEvent("VideoSpikeReport", { report })` 发出，`VideoSpike.GetReport()` 可程序化读取结果——便于 devtools 控制台一键复制/脚本抓取。

## 三、验证结果（WASM 预览实测 ✅，2026-08-23 真播放）

> 修正版 `VideoSpike.lua`（A 防重入 + onTimeUpdate 接通 + 先清后报）由 TTM 整份替换到平台侧并官方构建，在 **PC 端 TapTap maker 预览（WASM）** 实际播放验证，结果如下。

| 验证项 | 结果 |
|---|---|
| 三档码率（low/mid/high）是否全部被接受播放 | ✅ mid(A)+low/high(B) 全部 onReady/onPlay 通过，`Async load succeeded ×4` |
| onReady / onPlay / onPause / onEnded / onTimeUpdate 是否全部触发 | ✅ 全部触发；**onTimeUpdate 触发 66 次（>0，回调已接通）** |
| Seek(3.5) 精度：确认时的当前时间、两次确认差值 | ✅ A 双确认通过（发起 Seek(3.5) 仅 1 次）；E 恢复 seek(2.0)`#1 t=2.000 diff=0.000 / #2 t=2.107 diff=0.107（≤0.15）` |
| 同屏 3 播放器行为（报错/排队/内存） | ✅ ready=3 error=0 存活实例=3 → 销毁后 0（无报错/无需排队） |
| 销毁后播放器实例数量是否归零 | ✅ 建销×3 全部 release、最终存活实例=0；`结束存活实例数 → 0`；UI 根已恢复 |
| 切后台/回前台、通知栏返回时视频行为 | ⏳ 已订阅事件并在后台自动 Pause/记录断点；**本次 WASM 未实测**，建议真机补测 |
| 视频内中文标题渲染是否正常 | ✅ 视频内「素女篇·视频链路测试」+ 时间码 `T:` 正常渲染（中文烧录在帧内，与引擎字体/23 字符集无关） |

**A 场景修正确认**：修正后 `onPlay` 为个位数（初始 + resume 各 1），`发起 Seek(3.5)` 仅 1 行，确认完成 = 2（双确认），**无死循环**。

**本会话静态校验**：`emmylua_check`（LSP）对 `scripts/` 工作区校验——新增/修改文件 **0 error**（全工作区仅 `game/SceneManager.lua` 既有 3 个 `Redefined local variable scene_`，与本次无关）。`VideoSpike.lua` 的 warning 多为对引擎 userdata 类型推断的噪声（`urhox-libs/UI`、`urhox-libs/Video` 点号 require 解析为 init.lua 的 CLI 限制），以及 `mask` 作为闭包捕获 upvalue 的误报，均非真 bug。

## 四、代码阅读发现（不依赖运行，可靠）

1. **`Video.isSupported` 仅对 WASM 平台为 true**（`VideoPlayer ~= nil`）。本项目是 TapTap 小游戏（sce，`collection_type: "sce"`），运行时为 WASM，故部署环境应支持；若小游戏宿主未加载 `video_bridge.js` 则为 false。模块已做守卫：不支持时打日志并放弃执行。
2. **`onTimeUpdate` 节流**：仅当 `|当前时间 − lastUpdate| > 0.1` 时触发（约 10 次/秒）。因此「两次连续确认 ≤0.15」可行但偏临界（相邻更新约相差 0.1s）；**若真机确认精度不足，需放宽 `TOL` 或改为单次确认 + 阈值策略**。
3. **`Seek` 强制刷新**：`VideoPlayer.lua` 在 `Seek()` 后置 `lastTimeUpdate_ = -1`，使 seek 后即便时间差 <0.1s 也会触发一次 `onTimeUpdate` —— 这正是「seek 后确认」能生效的关键，已利用。
4. **`ClearChildren()` 不释放资源**（仅摘除子树，不调 `Destroy`）；必须对每个 VideoPlayer 显式 `Destroy()`。模块已显式 `Destroy` + 逆序清理。
5. **or-orphan 检测**：VideoPlayer 从 UI 树摘除超 5s 未 `Destroy()` 会告警（视频纹理大，GC 时机不可控）。模块每场景结束都显式销毁。
6. **根节点自动 `pointerEvents="box-none"`**：`UI.SetRoot` 对根容器自动设置，不拦截游戏输入（对 Spike 全屏遮罩无碍）。
7. **后台行为**：WASM 的 HTML5 `<video>` 在页面隐藏时浏览器通常自动暂停；引擎层面的正确恢复依赖事件订阅 + 断点记录，本 Spike 已演示回调链路，正式接入需按 mediaPos 恢复。

## 五、结论

- **规格 §2（MP4/H.264 High/yuv420p/1080×1920/30fps/AAC-LC 48kHz 立体声）**：**WASM 预览实测通过**——三档码率均被引擎接受并真实播放（`Async load succeeded`、onReady/onPlay/onEnded 齐全），规格成立。
- **S6 能否按此接入 13 段断点视频（《21》§5）**：**可行**。Seek 精度满足断点恢复契约（`diff≤0.15`，E 实测 0.000/0.107）；三步恢复状态机完整；销毁归零；「同屏 ≤2 实例」策略可行（3 实例虽可用但**正式建议按 ≤2**，见遗留 ③）。
- **文档修订建议**：`video.md` 示例默认横屏 1920×1080，本项目素材为**竖屏 1080×1920**，建议在指南中补充「竖屏须显式设 textureWidth/Height」的提示；另「同屏 ≤2 播放器」在指南中未明确，建议补一句约束。

## 六、遗留风险清单

1. **真机切后台/回前台（已实测，真机差异）**：真机（RMX3366/Android14）Spike 视频播放中切走，**视频自动冻结**（HTML5 `<video>` 页面隐藏暂停，正常）；但**切回游戏后 Spike 卡住、不恢复**（定格，无后续/无 REVEAL/汇报）。且**虚拟手势（长按底部→最近任务/切走，无实体 Home 键）下没有触发 `AppDidEnterBackground / AppDidEnterForeground` 事件** → Spike 的「自动 Pause + mediaPos 断点」逻辑用不上。⚠️ **正式（S6）断点恢复必须「视频冻结可自愈」**（用 `onTimeUpdate` 空窗判定冻结 + 续播），不能依赖 `AppDidEnterBackground`。
2. **A 场景 Seek 双确认真机失败**：真机 `Seek(3.5)` 后视频未回退到 3.5（`A seek确认 #1 t=3.593` 后播放到 `t=4.893`，confirm#2 不成立），A 记录不了「Seek(3.5) 两次确认」精度，仅靠 onEnded 走完。与真机「Seek 不回退」一致；TTM 已给 **E** 加「Seek 重试」兜底（E 真机走通），**建议 A 也加同样兜底**。
3. **Seek 容差 0.15 偏临界**：E 实测 diff=0.107 在容差内，但接近阈值；若真机 `onTimeUpdate` 频率/首次抖动不同，需放宽 `TOL` 或改单次确认+阈值策略。
4. **正式「同屏 ≤2 播放器」**：WASM 下同屏 3 可用（ready=3），但资源/内存偏好下**正式接入建议按 ≤2**（剧情播放器 1 + 循环背景 ≤1）。
5. **`experiments/VideoSpike.lua` 是实验模块**：`F6` 触发 + Spike 按钮 + Spike 文件均为调试代码，**S9 发布前必须移除**（或保留作参考，但不得进正式流程）。
6. **素材路径/名称**：Spike 引用的三档视频实际在 `assets/video/短视频生命周期 spike（推荐）/`（全角括号），正式接入需固定资源根路径，避免与 `assets/Videos/` 等旧路径混淆。
7. **两工作区同步**：本地（`Videos/` 路径、`Update(dt)` 为主）与平台侧（`video/短视频…（推荐）/` 路径、`Process(dt)`）已统一为修正版，但本地镜像仍需 `git fetch origin && git rebase origin/main` 合并；`docs/memory-index.md` 两边已各自更新，需一次性对齐避免分叉。

## 七、下一步建议

1. 真机/WASM 预览跑 Spike（F6），抓 `[VideoSpike]` 日志 + 录屏，回填第三节表格。
2. TTM 复盘 `VideoSpike.lua` 代码并列待办（本会话已完成，未顺手做正式视频接入）。
3. 在媒体正式接入前，按《22》做转码测试样本复核、按《23》做字符集字体预检。
