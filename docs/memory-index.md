<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时先读取 CLAUDE.md、本文件和 docs/persona.md。 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：桃素洛无幽·素女篇
当前版本：v0.1.6-S2（P02 老人交互）
简述：TapTap 制造 × Seedance 主题赛单机叙事游戏；已完成单机 3D 白模骨架、S1 竖屏 9:16 布局调整，S1 真机复盘 R1~R12 全部 ✅；B｜视频生命周期 Spike 代码完成（运行期待真机/WASM 验证）。
最后巩固：2026-08-22

## 项目概况
- UrhoX Lua 单机项目，唯一入口 `scripts/main.lua`。
- 三地点白模：朝阳谷口、谷内桃林、洛水阴山。
- 玩家移动/跳跃/第三人称相机/基础碰撞已接入；S1 真机复盘（R1~R12 全部 ✅）后镜头/球体/边界墙已按 R12 修复。
- 章节数据驱动，当前骨架段落为 `P01→P02→P03→P04~P07→P11→P12→P99`。
- S1 已将发布配置设为 portrait，并在运行时调用 `graphics:SetOrientations("Portrait")`；真机锁屏验证 ✅。
- B｜视频生命周期 Spike：新建 `scripts/experiments/VideoSpike.lua` 独立实验模块（F6 触发），验证 Video.VideoPlayer 生命周期 / Seek 双确认 / ≤2 播放器 / 建销归零 / 三步恢复状态机。

## 仓库 / 同步规范（重要，避免分叉）
- **唯一权威仓库 = GitHub `https://github.com/q3162146/qc-caku`（分支 `main`）**。所有资料/代码/文档同步都去/来自它；**不要**另建 `/workspace`、第三方镜像或把权威推到 TapTap Maker 仓库，避免“无共同祖先/两份历史”再次分叉。
- **本机 remote**（`/media/pc/机械/nong/制造新星 Game Jam 第3期`）：`origin`=旧 TapTap Maker（`maker.taptap.cn/git/094d3e2f-…git`，勿用 GitHub 凭据推）；`github`=`https://github.com/q3162146/qc-caku.git`（同步/备份/推送都走它，`git push github main`）。
- **同步规则**：更新 = `git fetch github && git rebase github/main`；推送前先 `git status` 不把 `.tmp/.scratch/.adb-tools/logs/s1_test` 等垃圾带进去；`CLAUDE.md` 按 `.gitignore` 意愿不入库。
- **给 TTM 的约定**：TTM 改完统一落本仓库 `git push github main`，不再另维护“平台侧”副本，以免两边漂移。
- **TTM 直推认证（2026-08-25 定案）**：TTM 无独立 GitHub 账号（加协作者走不通）、无法建 SSH（环境无 `~/.ssh`），但**可持久化 git 凭据**（`credential.helper=store` 实测 ✅）→ 采用 **repo 级 fine-grained PAT**（仅 `qc-caku`，`Contents: Read and write`）。PAT 值只经 TTM 环境自己的凭据配置交给 TTM，**绝不进对话**；TTM 侧写入 `~/.git-credentials` + `credential.helper store` 后 `git push github main`。用户侧 `git fetch github && git rebase github/main` 拉取。若日后 PAT 失效/环境受限，降级为「git format-patch 零凭据交接」（`素女篇-准备期素材包/TTM-零凭据patch交接.md`），仍同一条 main 不产生第二副本。**现行接入说明**：`素女篇-准备期素材包/TTM-共用仓库直推接入说明-方案B凭据.md`；**历史/已废弃交接草稿**统一在 `素女篇-准备期素材包/历史交接草稿-勿用/`（勿当现行规范）。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 单机校验、竖屏方向请求、生命周期诊断、调试键（含 F6 触发 VideoSpike）与唯一入口 |
| `scripts/game/InputManager.lua` | 输入抽象层 |
| `scripts/game/PlayerController.lua` | 移动、相机、角色碰撞；竖屏镜头（distance 6.8/offset.y 2.3/fov 52）与视觉球体 (0.45,0.6,0.45)@y0.65 |
| `scripts/game/SceneManager.lua` | 三场景 9:16 纵深白模 + 后墙外移（朝阳 32/桃林洛水 29）与 SceneRoot 生命周期 |
| `scripts/game/WhiteBox.lua` | 白模几何、材质、可配置宽深边界墙、碰撞 |
| `scripts/experiments/VideoSpike.lua` | 视频生命周期 Spike 独立实验模块（5 场景串行 + 后台/前台订阅）；S9 前应移除 |
| `scripts/config/PlayerData.lua` | 固定字段和类型兜底；含 mediaPos（节点/视频/断点/秒数契约） |
| `scripts/config/Chapters.lua` | 段落表 |
| `scripts/flow/FlowController.lua` | 统一结果消费与段落推进 |
| `screenshots/s1/chaoyang_portrait.png` | 540×960 竖屏比例白模截图 |

## 有效决策
- D-001：本轮不接视频、完整存档 IO、正式资产和后续章节。
- D-002：常规 UI 采用 `urhox-libs/UI`，本轮无 raw NanoVG。
- D-003：白模挂在 `SceneRoot`，切换整组销毁；玩家出生高度固定为 0.6 米。
- D-004：portrait 元数据和运行时 `SetOrientations("Portrait")` 双层请求已完成；真机锁屏已确认（R1/R10/R5 ✅）。
- D-005：三场景采用窄 X、深 Z 的 9:16 纵深构图，不维护横竖双布局。
- D-006：地名定案：朝阳谷所在之山为「夷山」（《山海经·南山经·南次二经》）；「洛水阴山」与代码键 luoshui_yinshan 不变；文案统一"夷山下有一谷，名唤朝阳"。任何时候不要把"夷山下"改回"阴山下"。
- D-011：边界墙限制第三人称相机距离——若相机被墙压回，需外移边界墙，而非只调 distance（R12 根因）。
- D-012：白模球体色（0.95,0.88,0.78）与雾色相近，诊断需用独立检测法（逐像素差异/颜色通道），不能只靠视觉。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| 单机配置 | `scripts/main.lua` | 已完成，配置异常退出 |
| 屏幕方向 | `.project/project.json` + `scripts/main.lua` | portrait + Portrait 请求；真机锁屏 ✅（R5/R10） |
| 玩家状态字段 | `scripts/config/PlayerData.lua` | 骨架完成，含 mediaPos 媒体恢复契约 |
| P02 老人交互 | `scripts/config/Chapters.lua` + `scripts/flow/FlowController.lua` | 走近 `Int_oldman` 触发初见台词；LSP 0 error；真机回归待跑 |
| 统一完成结果 | `scripts/flow/FlowController.lua` | `done=false` 不推进 |
| 三地点白模 | `scripts/game/SceneManager.lua` | 9:16 纵深布局 + R12 后墙外移/近景靠边；真机取景 ✅（R4/R11/R12） |
| 视频恢复/释放 | 后续 media 模块 | Spike 已验证生命周期/Seek/恢复状态机代码路径；正式媒体接入未开始 |
| 视频生命周期 Spike | `scripts/experiments/VideoSpike.lua` | 代码完成 + LSP 0 error；运行期待真机/WASM 验证 |

## 避雷清单
- 一次会话只做一个 S 任务；结束时让 TTM 复盘代码并列待办。
- 22 的视频/音频规格是首轮兼容性测试起点；23 字符集共 1441 字符，正文不用书法体。
- 剧情播放器 1 个，带循环背景最多 2 个；播完 Destroy/Dispose。
- 分享卡先预生成三张，真机确认后再做运行时分享。
- 首次真机必须测后台/前台/通知栏返回、多播放器内存、音画同步。
- `cache:Exists` 不等于运行时普通文件存在；settings 使用 `fileSystem:FileExists` 与 `File`。
- `SetOrientations("Portrait")` 已被真机确认锁屏生效（合法值实测为 Portrait）。
- 场景内容必须挂到 `SceneRoot`，否则切换后旧碰撞体残留。
- InputManager 封装所有业务输入访问。
- 验证环境可能缺 shader/audio/默认字体；先看 Lua 错误、场景统计和截图。
- 视频用 `Video.VideoPlayer` Widget（urhox-libs/Video），禁止裸搓 C++ + NanoVG；竖屏素材须显式设 `textureWidth/Height=1080×1920`（指南默认横屏）。
- `ClearChildren()` 不释放视频资源，必须对每个 VideoPlayer 显式 `Destroy()`（配合 orphan 检测）。
- Spike 的 `F6` 触发与 `scripts/experiments/VideoSpike.lua` 是调试/实验代码，**S9 发布前必须移除**。
- DSH harness 环境：`dsh-personal` 预设的视觉路由（含图会话→dashscope/qwen3-vl-plus）必须与 `settings.yaml` 的 `llm-pi-ai.providers.dashscope` 同步；删 provider 配置/key 必须同时停用该路由，否则含图轮次 `NO_ADAPTER` 整轮失败。2026-08-21 已通过 `~/.dsh/profiles/web/cordis.patch.yml` 给 personal 打 `disabled: true` 停用（read_image 不可用，视频/截图分析改用 gst 解码 + PIL 帧统计）。

## 最近变更
- 2026-08-26 **S2·P02 走近守桃老人真实交互（本会话）**：把 P02 从"收集 1 个标记点"白模占位改为走近 `Int_oldman` 触发初见台词（`explore` 段新增 `interaction` 字段 = `{trigger, lines}`，FlowController 拦截触发 → 播完完成段落）。初见台词（"远来的客人……"）移至 P02（`DialogueData.oldman_greeting`）；P03 精简为开场之问（`open_choice` 只剩"你相信哪个版本？"，三选仍不计信念）。附带：带 `interaction` 的探索段会忽略沿途桃花等其它拾取，防误完成。LSP（emmylua_check）0 新增 error/warning（`FlowController.lua` 21 条为既有 `state_/data_ may be nil` 风格告警，新行 98-115/178-183 无诊断；`DialogueData/Chapters` 无诊断）。⏳ 真机回归仍需 TTM/用户按 P01→P02→P03 走一遍确认走近触发台词 + 三选正常。
- 2026-08-25 **S6 断点 Hook 真机全链路通过 ✅（TTM 修复生效）**：`DEBUG_BREAKPOINT_TEST`（at=4.0 三选）真机（21:53）完整闭环——断点命中+mediaPos(`breakpoint=1`)、三选 UI 显示+选中**锁定**（`断点交互选择已锁定 key=release belief=1`）、继续播放、**断点不重复**（`breakpoint=1` 续写至 9.776）、**强制 ENDED**（`达到视频结尾 current=9.962 强制 ENDED`，结尾死循环已修）、`Destroy 存活=0`、同屏=1。✅（修复：① 结尾死循环→强制 ENDED；② 断点无三选 UI→显示三选+onChoose 锁定/记信念/继续。）⏳ 剩余：冻结自愈(后台)、S6 连续 5 段(S6-1..5 未接线)、完整读档恢复(部分测过 02:17 模拟读档)。⚠️ 代码回推：TTM 无凭据，`S6-breakpoint-hook-code.zip` 在 `/workspace/`，需 TTM 交给用户→本地 push 到 qc-caku（勿泄凭据）。
- 2026-08-25 **S6 断点 Hook 真机复测再确认 ✅（break2.log / 22:21）**：logcat `break2.log`（`/home/pc/桌面/TAPTAP测试图片/`，08-25 22:21，游戏进程 17820）完整闭环：断点命中 `到达断点 #1 | at=4.018`、三选 UI `显示三选` + 选中**锁定**（`断点交互选择已锁定 key=reunion belief=1`，本次选**重逢**，与 21:53 那次 key=release/放手 不同）、继续播放、**断点不重复**（`breakpoint=1` 续写 4.018→9.893）、**强制 ENDED**（`ENDED | 段落 DEBUG_BREAKPOINT_TEST 播放完成`，无结尾死循环）、`Destroy 存活=0`、同屏=1。期间还实测到**后台/前台切换 + 冻结自愈续播**（`AppDidEnterBackground`→`AppDidEnterForebackground | 由冻结自愈负责续播`→`onPlay current=1.138`）。游戏进程 17820 无 Lua error/崩溃。✅ 协作方 ①断点三选UI+锁定、继续播放、断点不重复 三项全部满足；②新真机二维码、③S6 代码 zip 已解决：TTM 提供 `S6-breakpoint-hook-code.zip`（SHA-256 `076bc594b80a0feb86bbbe58976e0d56860be57625e8fb8c07660e7e7ed3efa2`，仅含 3 个 .lua，未混录屏/截图/Spike 文档），本地已合入 2 文件 diff（FlowController/main 改动 + 新增 media/MediaPlayer.lua）并 push 到 qc-caku，提交 `5d0c95b`；冻结自愈（FREEZE_GAP=1.5/MAX_FREEZE_RECOVERIES=3）+ 断点 Hook（at=4.0/F7/断点按钮/三选锁定/信念增量/断点不重复/强制 ENDED/Destroy=0）均已确认在文件内。
- 2026-08-24 **真机 S6 P01 媒体链路回归通过（核心）**：P01 视频真实播放（`T:04.833 F:145` 测试视频渲染 + `CREATING→READY(dur=10.000)`、`同屏=1`、`写入 mediaPos node=P01 video=S1 breakpoint=0 timeSec=0.186→9.845`、无 Lua error）→ 播完自动进 P02（录屏 t=40/62 = P02 探索场景）。✅ P01 链路过。⏳ 剩余未测：断点+交互(S5/S6-1)、读档恢复、后台冻结自愈、S6 连续 5 段、退出内存回落（已让 TTM 出 S5/S6-1 断点二维码补测）。⚠️ TTM 无 GitHub 凭据 push 失败 → 让 TTM 发 S6 代码文件，本地 push 到 qc-caku（最安全）。
- 2026-08-23 **S6 正式视频媒体接入（TTM 实现，代码完成 + 修 bug；视频真实回归待做）**：新建 `scripts/media/MediaPlayer.lua`（状态机 CREATING→READY→SEEK_READ→PLAY；断点/mediaPos；读档 Seek 双确认；真机 Seek 重试≤3 降级；冻结>1.5s 自愈≤3；同屏播放器=1；显式释放），接入 FlowController(video) + main.lua。修复 `CompletedParagraph nil` 回调（改 SetCompleteHandler）。LSP 0 error / 构建成功 / 本地运行 0 error（无解码器 env 走 ERROR_NO_DECODER 错误路径）。⚠️ 视频真实回归未做（TTM 无 PC WASM/真机通道，不伪报）；S1~S13 素材占位（`S1_test_mid`）；代码在 TTM 环境需 push 到 qc-caku + 本地同步。提交 10afcd8(feat)+b69051a(fix)。
- 2026-08-23 **媒体接入前预检完成**：① 转码样本三支符合《22》§2（H.264 High/yuv420p/1080×1920/30fps/AAC-LC/48kHz/立体声/10s）；② 字符集字体（UI 默认字体 = Noto Sans SC）用 fontTools 比对《23》：1318 汉字+全部标点覆盖，缺 `▸ U+25B8 / ► U+25BA / ✅ U+2705 / ️ U+FE0F`，其中 `▸`（`DialogueUI.lua:104`「继续 ▸」按钮）已改 `›`(U+203A)；`►`/`✅` 仅在文档、未来 UI 用需后备 symbol 字库或图标。
- 2026-08-23 **视频 Spike 真机后台/前台实测（RMX3366/Android14）**：真机**支持视频解码**、Spike 可播、右上角 Spike 触屏按钮有效；TTM 给 **E** 加「Seek 重试」后 E 真机走通、StringHash 后台崩溃消失。**但真机差异**：① 视频切后台**自动冻结**（HTML5 正常）→ 切回后 **Spike 卡住不恢复**；② **虚拟手势（长按底部→最近任务/切走，无实体 Home 键）下 `AppDidEnterBackground/AppDidEnterForeground` 不触发** → Spike 断点恢复用不上；③ **A 场景 Seek 双确认失败**（`Seek(3.5)` 视频未回退，`A seek确认#1 t=3.593` 后播到 `t=4.893`，confirm#2 不成立，仅靠 onEnded 走完）。⚠️ **S6 正式媒体断点恢复须「视频冻结可自愈」**（onTimeUpdate 空窗判冻结 + 续播），不依赖 `AppDidEnterBackground`。已回填《TTM-视频Spike结果汇报.md》§六。
- 2026-08-23 **B｜视频生命周期 Spike WASM 验证全通过 ✅**：修正版 `VideoSpike.lua`（A 防重入 `resumeScheduled` + onTimeUpdate 接通（66 次）+ `finish` 先清后报=0 + 素材路径 `video/短视频生命周期 spike（推荐）/`（全角括号）+ `Process(dt)` 别名）由 TTM 整份替换平台侧并官方构建，PC 端 TapTap maker 预览（WASM）真播放验证通过——三档码率全 onReady/onPlay、A Seek(3.5) 双确认无死循环、同屏3就绪（ready=3 error=0）、建销×3 归零、E 三步状态机（seek 2.0 diff 0.000/0.107）、结束存活=0、中文标题「素女篇·视频链路测试」✅。**《22》§2 规格通过；S6 可按此接入《21》§5 13 段断点视频**。已回填《TTM-视频Spike结果汇报.md》。⚠️ 遗留：切后台/回前台未在 WASM 实测（建议真机补测）；Spike 的 F6/按钮/三指 S9 前必须移除；正式接入建议同屏 ≤2。⚠️ 两工作区素材路径/驱动名需随镜像对齐。
- 2026-08-22 **B｜视频生命周期 Spike（代码完成，运行期待真机/WASM 验证）**：新建 `scripts/experiments/VideoSpike.lua` 独立实验模块（A 生命周期 mid / B 三档码率 / C 同屏3播放器 / D 建销×3 / E 三步恢复状态机 + 后台/前台事件订阅 + 汇报汇总），`main.lua` 仅接入 3 处（require + F6 触发 + 激活时每帧 Update），未改正式剧情/流程；竖屏素材显式设 `textureWidth/Height=1080×1920`。静态校验 emmylua_check：新增/修改文件 0 error（仅 SceneManager 既有 3 个报错）；已交付《素女篇-准备期素材包/TTM-视频Spike结果汇报.md》。⚠️ 真机/TapTap 预览需按 F6 跑 Spike 抓 `[VideoSpike]` 日志 + 录屏回填汇报表（本机沙箱缺 AVX2 跑不了 UrhoXRuntime；视频需 WASM+图形环境）；后续还需 TTM 复盘 `VideoSpike.lua`。
- 2026-08-22 **S1 真机复盘彻底收官：R1~R12 全部 ✅**（用户侧实测 + TTM 复核）：R1~R11 用无线 adb logcat + 录屏像素分析（RMX3366/Android 14/密度 480），R8/R9 TTM 判定 ✅、R9 跳跃离地 01:30 体感确认 ✅；R12 真机复测通过（玩家球体占屏 9.6%，锚定 TTM 平台侧 9.6%，不遮挡无涕桃/路线）。R12 修复 6 处，**根因 = 边界墙离出生点太近致相机被墙压回 3.05m**（单调相机参数无效，须后墙外移）→ 视觉球体 (0.45,0.6,0.45)@y0.65、相机 distance 6.8/offset.y 2.3/fov 52、TaoA→(7,0,15)、GhostStone→x3.5、water 桃花随移、三场景后墙外移（朝阳 25.5→32/桃林洛水 22.5→29），决策 D-011/D-012 入档本索引 v0.1.5-S1-R12。实测要点：DPR=3.0（非 2.75）、safeInsets 上 108=顶部挖孔条、通知栏下拉=完整前后台事件（minimized=true）、旋转锁屏无 OrientationChanged/ScreenMode=锁屏生效。材料：`素女篇-准备期素材包/真机录屏-2026-08-22/`、`25-R5真机DeviceDiag日志.md`、`素女篇-准备期素材包/历史交接草稿-勿用/TTM-2026-08-22真机验证回填粘贴块.md`、`素女篇-准备期素材包/历史交接草稿-勿用/TTM-R12镜头修复交付.md`。
- 2026-08-22 本会话开头核对的 B｜视频 Spike 粘贴块与素材：`assets/Videos/` 三支测试视频（low_3M/mid_6M/high_10M）已就绪，`engine-docs/recipes/video.md` 为权威参考。
- 2026-08-21 22-54.mp4（386.5s，gst 逐秒解码）：59~313s 活跃游戏 → 314~369s 退出蓝色桌面 → 370~386s 返回正常 = R6 切后台/回前台 ✅（全程可见）；⚠️ ffmpegthumbnailer 对该文件 seek 不可靠，曾误判"96s 冻结 290s"，时间线以 gst 解码为准。
- 2026-08-21 DSH harness 修复（用户侧）：停用 `dsh-personal` 视觉路由（`~/.dsh/profiles/web/cordis.patch.yml` 打 `disabled: true`），消除含图会话 `NO_ADAPTER` 整轮中断；根因与恢复方法见 CLAUDE.md 避雷清单。
- 2026-08-21 真机录屏验证 22-04.mp4（182s 竖屏）：1.0.4 运行正常 —— 启动进游戏、三场景多轮循环、触摸可用、无崩溃/错误页；与 20-43 一致。
- v0.1.1-S1：完成 portrait 元数据、运行时方向请求、三个白模的 9:16 纵深重排、相机镜头调整；LSP Error 为空，官方构建通过，Lua runtime error 为 0，生成 540×960 截图。
- v0.1.0：创建单机白模骨架，完成三场景、PlayerData、Chapters、Flow、移动相机与基础碰撞。

## 下一步
0. **同步管道已就绪（2026-08-25）**：S6 代码已合入并推权威仓（提交 `5d0c95b`）+ 文档整理（`ccb62c7`）。TTM 无 GitHub 账号/无 SSH，已用 **repo 级 fine-grained PAT + `credential.helper store`** 打通直推：此后 TTM `git push github main`，本机 `git fetch github && git rebase github/main` 即同步（不再打 zip/手动合并）；降级用 `git format-patch`。PAT 值只在 TTM 环境，**不进对话**。现行接入说明=素材包/`TTM-共用仓库直推接入说明-方案B凭据.md`；降级=素材包/`TTM-零凭据patch交接.md`；历史接头草稿归档在素材包/`历史交接草稿-勿用/`。
1. **S6 媒体模块（主要闭环已完成）**：MediaPlayer 状态机 + 断点 Hook（DEBUG_BREAKPOINT_TEST @4.0 三选）+ 冻结自愈 + mediaPos 断点续写/断点不重复/强制 ENDED/显式释放，真机两轮（21:53、22:21 break2.log）全链路 ✅。**剩余验证**：S6 连续 5 段（S6-1..5 未接线，暂不可测）、完整读档恢复（部分测过 02:17 模拟读档）、后台冻结自愈（已在 22:21 复测随切后台/回前台顺带验证到恢复续播）。
2. **正式素材**：S1~S13 仍为测试占位（`S1_test_mid`），正式素材到位后仅替换 `scripts/media/MediaPlayer.lua` 的 `VIDEO_SOURCES` 映射。
3. **S9 前移除**：断点/Spike 的 F6/F7/右上角按钮 + 三指手势；正式接入建议同屏 ≤2（按 §2 + mediaPos 断点恢复）；未来顶部 HUD 需重评 SafeAreaView `nativeMenuInset=true`。
4. **后续主线（下一阶段）**：~~P02 真实老人交互~~（**已完成，见 v0.1.6-S2**）、媒体断点存档、ch2/ch3/ch4（章节系统已预留，`config/Chapters.lua` + `mediaPos` 断点恢复）、P11 五朵桃花收集 vs `Int_*` 交互的接线核对。
5. 同步规则：`git fetch github && git rebase github/main`；推送走 `git push github main`（**勿用** Maker 仓 origin 的 GitHub 凭据；推送前 `git status` 不带 `.tmp/.scratch/.adb-tools/logs/s1_test` 等垃圾）。git 已可用（`/usr/bin/git`）。
