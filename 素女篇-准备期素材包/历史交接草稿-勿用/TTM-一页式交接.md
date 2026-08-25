# TTM 一页式交接（2026-08-23）

> 用法：整段发给 TTM。作为「后续开发/媒体接入」的前置上下文与铁律。

══════════════════════════════════════════════════════

【交接｜《桃素洛无幽·素女篇》当前状态 + 后续约定】

## 一、当前已完成（可放心立足）
1. **S1 真机复盘——R1~R12 全部 ✅**：竖屏 portrait 双层配置、三场景 9:16 纵深白模、R12 镜头修复（球体缩小至占屏 1/6~1/10、相机 6.8/2.3/52、三场景后墙外移 32/29）、22-00.mp4 真机复测确认（球体暖白像素减 4 倍）。
2. **B｜视频生命周期 Spike——WASM 验证全通过 ✅**：`Video.VideoPlayer` 生命周期 / Seek(3.5)=3.500 精度 / onTimeUpdate 66 次 / 同屏 3 播放器就绪 / 建销×3 归零 / E 三步状态机（→REVEAL）/ 中文标题渲染。结论：《22》§2 规格成立，**S6 可按此接入《21》§5 的 13 段断点视频**。
3. **已推送到 GitHub**：`q3162146/qc-caku`（`main`=`8077363`）已含 scripts/、docs/、素材包、assets/、复盘表、真机录屏。

## 二、⚠️ 仓库 / 同步铁律（最重要，避免重蹈分叉）
- **唯一权威仓库 = GitHub `https://github.com/q3162146/qc-caku`（分支 `main`）**。所有改动统一落到这个仓库并 `git push github main`。
- **不要**另建 `/workspace`、第三方镜像，**不要**把权威内容推到 TapTap Maker 仓库（`maker.taptap.cn/git/094d3e2f-…`）——避免“无共同祖先/两份历史”再分叉。
- **推送前先巡查**：`git fetch github && git status`，确认不把 `.tmp/`、`.scratch/`、`.adb-tools/`、`logs/s1_test/` 等垃圾带进去；`CLAUDE.md` 按 `.gitignore` 意愿不入库。
- 更新/拉取：`git pull --rebase github main`（或 `git fetch github && git rebase github/main`）；推送：`git push github main`。
- 拿不准就**先问**，不要自作主张换仓库/分支。

## 三、后续待办
1. **真机补测视频后台/前台**（Spike WASM 未实测）：播放中切后台/回前台，记录自动 Pause、`mediaPos.timeSec` 断点、通知栏下拉返回、多播放器内存、音画同步 → 回填《素女篇-准备期素材包/TTM-视频Spike结果汇报.md》§六 ①。
2. **S9 发布前必须移除调试代码**：Spike 的 F6/Spike 按钮 + 三指切场景手势；并入正式 media 模块时按《21》§5 断点表 + **同屏 ≤2** + `PlayerData.mediaPos { node, video, breakpoint, timeSec }` 断点恢复。
3. **媒体接入前确认**：《22》§2 转码测试样本 +《23》接口字符集（1441 字符）字体预检（Spike 已确认视频可播放、中文标题为帧内像素；字符集预检用于引擎 UI 字体）。
4. **后续开发**：P02 真实老人交互、媒体断点存档、ch2/ch3/ch4；顶部 HUD 若加入需重评 SafeAreaView `nativeMenuInset=true`。
5. **素材路径**：测试视频在 `assets/video/短视频生命周期 spike（推荐）/`（**全角括号**）；正式接入须固定资源根路径，避免与旧 `assets/Videos/` 混淆。

## 四、关键参考
- 视频权威指南：`engine-docs/recipes/video.md`（必须用 `Video.VideoPlayer` Widget；竖屏素材须显式设 `textureWidth/Height=1080×1920`）。
- 已完成文档：`素女篇-准备期素材包/TTM-视频Spike结果汇报.md`、`24-S1真机复盘检查表.md`、`TTM-R12镜头修复交付.md`、`TTM-视频Spike缺陷修复粘贴块.md`、`TTM-视频Spike浏览器验证粘贴块.md`。
- 项目记忆：`CLAUDE.md`、`docs/memory-index.md`（含仓库/同步规范）。

══════════════════════════════════════════════════════
粘贴到此结束
══════════════════════════════════════════════════════

---

## 给用户备忘（不要粘给 TTM）
- 重点 = ① 现状已定（S1 收官 + Spike 通过 + 已推 GitHub）；② **仓库铁律**（只认 qc-caku，别再造第二份）；③ 剩下 5 项待办（真机补测 / S9 移除 / 字符集预检 / ch2~ch4 / HUD）。
- 之后 TTM 每次动工，先看这份即可对齐，不用重复交代背景。
