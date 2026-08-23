<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时先读取 CLAUDE.md、本文件和 docs/persona.md。 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：桃素洛无幽·素女篇
当前版本：v0.1.5-S1-R12
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
- 2026-08-23 **媒体接入前预检完成**：① 转码样本三支符合《22》§2（H.264 High/yuv420p/1080×1920/30fps/AAC-LC/48kHz/立体声/10s）；② 字符集字体（UI 默认字体 = Noto Sans SC）用 fontTools 比对《23》：1318 汉字+全部标点覆盖，缺 `▸ U+25B8 / ► U+25BA / ✅ U+2705 / ️ U+FE0F`，其中 `▸`（`DialogueUI.lua:104`「继续 ▸」按钮）已改 `›`(U+203A)；`►`/`✅` 仅在文档、未来 UI 用需后备 symbol 字库或图标。
- 2026-08-23 **视频 Spike 真机后台/前台实测（RMX3366/Android14）**：真机**支持视频解码**、Spike 可播、右上角 Spike 触屏按钮有效；TTM 给 **E** 加「Seek 重试」后 E 真机走通、StringHash 后台崩溃消失。**但真机差异**：① 视频切后台**自动冻结**（HTML5 正常）→ 切回后 **Spike 卡住不恢复**；② **虚拟手势（长按底部→最近任务/切走，无实体 Home 键）下 `AppDidEnterBackground/AppDidEnterForeground` 不触发** → Spike 断点恢复用不上；③ **A 场景 Seek 双确认失败**（`Seek(3.5)` 视频未回退，`A seek确认#1 t=3.593` 后播到 `t=4.893`，confirm#2 不成立，仅靠 onEnded 走完）。⚠️ **S6 正式媒体断点恢复须「视频冻结可自愈」**（onTimeUpdate 空窗判冻结 + 续播），不依赖 `AppDidEnterBackground`。已回填《TTM-视频Spike结果汇报.md》§六。
- 2026-08-23 **B｜视频生命周期 Spike WASM 验证全通过 ✅**：修正版 `VideoSpike.lua`（A 防重入 `resumeScheduled` + onTimeUpdate 接通（66 次）+ `finish` 先清后报=0 + 素材路径 `video/短视频生命周期 spike（推荐）/`（全角括号）+ `Process(dt)` 别名）由 TTM 整份替换平台侧并官方构建，PC 端 TapTap maker 预览（WASM）真播放验证通过——三档码率全 onReady/onPlay、A Seek(3.5) 双确认无死循环、同屏3就绪（ready=3 error=0）、建销×3 归零、E 三步状态机（seek 2.0 diff 0.000/0.107）、结束存活=0、中文标题「素女篇·视频链路测试」✅。**《22》§2 规格通过；S6 可按此接入《21》§5 13 段断点视频**。已回填《TTM-视频Spike结果汇报.md》。⚠️ 遗留：切后台/回前台未在 WASM 实测（建议真机补测）；Spike 的 F6/按钮/三指 S9 前必须移除；正式接入建议同屏 ≤2。⚠️ 两工作区素材路径/驱动名需随镜像对齐。
- 2026-08-22 **B｜视频生命周期 Spike（代码完成，运行期待真机/WASM 验证）**：新建 `scripts/experiments/VideoSpike.lua` 独立实验模块（A 生命周期 mid / B 三档码率 / C 同屏3播放器 / D 建销×3 / E 三步恢复状态机 + 后台/前台事件订阅 + 汇报汇总），`main.lua` 仅接入 3 处（require + F6 触发 + 激活时每帧 Update），未改正式剧情/流程；竖屏素材显式设 `textureWidth/Height=1080×1920`。静态校验 emmylua_check：新增/修改文件 0 error（仅 SceneManager 既有 3 个报错）；已交付《素女篇-准备期素材包/TTM-视频Spike结果汇报.md》。⚠️ 真机/TapTap 预览需按 F6 跑 Spike 抓 `[VideoSpike]` 日志 + 录屏回填汇报表（本机沙箱缺 AVX2 跑不了 UrhoXRuntime；视频需 WASM+图形环境）；后续还需 TTM 复盘 `VideoSpike.lua`。
- 2026-08-22 **S1 真机复盘彻底收官：R1~R12 全部 ✅**（用户侧实测 + TTM 复核）：R1~R11 用无线 adb logcat + 录屏像素分析（RMX3366/Android 14/密度 480），R8/R9 TTM 判定 ✅、R9 跳跃离地 01:30 体感确认 ✅；R12 真机复测通过（玩家球体占屏 9.6%，锚定 TTM 平台侧 9.6%，不遮挡无涕桃/路线）。R12 修复 6 处，**根因 = 边界墙离出生点太近致相机被墙压回 3.05m**（单调相机参数无效，须后墙外移）→ 视觉球体 (0.45,0.6,0.45)@y0.65、相机 distance 6.8/offset.y 2.3/fov 52、TaoA→(7,0,15)、GhostStone→x3.5、water 桃花随移、三场景后墙外移（朝阳 25.5→32/桃林洛水 22.5→29），决策 D-011/D-012 入档本索引 v0.1.5-S1-R12。实测要点：DPR=3.0（非 2.75）、safeInsets 上 108=顶部挖孔条、通知栏下拉=完整前后台事件（minimized=true）、旋转锁屏无 OrientationChanged/ScreenMode=锁屏生效。材料：`素女篇-准备期素材包/真机录屏-2026-08-22/`、`25-R5真机DeviceDiag日志.md`、`TTM-2026-08-22真机验证回填粘贴块.md`、`TTM-R12镜头修复交付.md`。
- 2026-08-22 本会话开头核对的 B｜视频 Spike 粘贴块与素材：`assets/Videos/` 三支测试视频（low_3M/mid_6M/high_10M）已就绪，`engine-docs/recipes/video.md` 为权威参考。
- 2026-08-21 22-54.mp4（386.5s，gst 逐秒解码）：59~313s 活跃游戏 → 314~369s 退出蓝色桌面 → 370~386s 返回正常 = R6 切后台/回前台 ✅（全程可见）；⚠️ ffmpegthumbnailer 对该文件 seek 不可靠，曾误判"96s 冻结 290s"，时间线以 gst 解码为准。
- 2026-08-21 DSH harness 修复（用户侧）：停用 `dsh-personal` 视觉路由（`~/.dsh/profiles/web/cordis.patch.yml` 打 `disabled: true`），消除含图会话 `NO_ADAPTER` 整轮中断；根因与恢复方法见 CLAUDE.md 避雷清单。
- 2026-08-21 真机录屏验证 22-04.mp4（182s 竖屏）：1.0.4 运行正常 —— 启动进游戏、三场景多轮循环、触摸可用、无崩溃/错误页；与 20-43 一致。
- v0.1.1-S1：完成 portrait 元数据、运行时方向请求、三个白模的 9:16 纵深重排、相机镜头调整；LSP Error 为空，官方构建通过，Lua runtime error 为 0，生成 540×960 截图。
- v0.1.0：创建单机白模骨架，完成三场景、PlayerData、Chapters、Flow、移动相机与基础碰撞。

## 下一步
1. **B｜视频生命周期 Spike —— WASM 验证通过 ✅ + 真机差异已解决**：PC WASM 真播放全过，《22》§2 成立；真机（RMX3366）后台/前台实测发现「视频切后台冻结、回前台 Spike 卡住、虚拟手势下 AppDidEnterBackground 不触发、A 双确认失败」；**TTM 已解决**：A 加 Seek(3.5) 重试兜底（≤3 次）+ **S6「冻结自愈」方案定案**（onTimeUpdate/GetCurrentTime 空窗 >1.5s 判冻结 → 记 mediaPos.timeSec → Pause/Play 自愈 ≤3 次，不依赖 AppDidEnterBackground）。官方构建成功、Lua 0 error、90 帧运行正常（字体/shader 缺失为沙箱固定告警）。后续：S6 正式媒体断点恢复按此「冻结自愈」接入；Spike F6/Spike 按钮 + 三指手势 **S9 前移除**；正式接入建议同屏 ≤2（按 §2 + mediaPos 断点恢复）。
2. 在媒体接入前确认 22 的转码测试样本与 23 字符集字体预检（Spike 已确认视频可播放、中文标题为帧内像素；字符集预检用于引擎 UI 字体）。
3. 后续再做 P02 真实老人交互、媒体断点存档和 ch2/ch3/ch4。
4. ⚠️ 三指切场景调试手势与 Spike 的 F6 触发，S9 发布前必须移除；未来顶部 HUD 需重评 SafeAreaView `nativeMenuInset=true`。
5. 同步本地镜像：`git fetch origin && git rebase origin/main`（注意当前 shell 需另装 git，本地无 `/usr/bin/git`）。
