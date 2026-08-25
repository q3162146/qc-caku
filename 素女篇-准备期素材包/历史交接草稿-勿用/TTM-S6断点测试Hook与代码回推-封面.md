# 发 TTM：S6 断点测试 Hook + S6 代码文件回推

> 用法：整段复制发给 TTM。① 让 TTM 加一个「断点测试 Hook」验证断点/交互/读档/后台/内存机制；② 让 TTM 把 S6 代码文件发你，你本地 push 到 qc-caku。

══════════════════════════════════════════════════════
【S6 —— ①加断点测试 Hook + ②回推 S6 代码文件】

背景：S6 MediaPlayer 真机 P01（auto，播完推进）已通过。但**断点/交互/读档/后台**因 S5/S6-1 段落还没接进 Chapters（当前只有 P01 是 video 段），用现有流程测不到。为高效验证**断点机制**，请加一个**断点测试 Hook**；同时把 S6 代码文件发我（我带凭据的机器本地 push 到 qc-caku）。

## ① 加「断点测试 Hook」（调试入口，类似 Spike，S9 前移除）
加一个调试触发（建议复用目前 Spike 的触发方式：Spike 按钮旁再加一个「断点」按钮；或 F7 键），**直接播放一段带 `at` 断点 + 交互的视频**，验证下列机制：

- **测试参数**：复用占位视频（如 `S1_test_mid`），定义含 `breakpoints = { {at=4.0, act="choice", options={...三选...}}, ... }` 的测试段；不依赖正式 S5/S6-1 段落。
- **验证点（依次）**：
  1. **断点暂停 + 写 `mediaPos`**：到 `at` → `Pause()` + `mediaPos = {node=测试段, video=S1, breakpoint=序号, timeSec=当前秒}`（`breakpoint` 应为 ≥1，不再是 0）。
  2. **交互三选锁定**：显示三选（复用现有 choice UI），选中后**立即锁定**（防连点双加 belief），选完记录信念增量 → `Play()` 继续。
  3. **读档恢复**：在断点处暂停时记 `mediaPos` → 切后台/重启 → 读档恢复走**Seek 双确认**（不闪首帧、断点**不重复触发**）。
  4. **后台冻结自愈**：视频播放中切后台/回前台 → **冻结自愈**续播（不依赖 AppDidEnterBackground）。
  5. **退出内存回落**：Hook 结束/退出 → `Destroy 剧情播放器 | 存活实例=0`。
- **要求**：同屏剧情播放器=1；断点时间以「暂停那一刻」为准，`at` 前 0.5s 不设；有 `[MediaPlayer]` 日志（断点命中/写 mediaPos/交互选择/自愈/销毁）。
- 出码：加好 Hook 后**构建 + 出真机二维码**给我。

## ② 把 S6 代码文件发我（我来本地 push）
你那边无 GitHub 凭据 push 失败。请把 S6 代码文件发我（带凭据机器本地 `git add`+`git push github main` 到权威仓库 `https://github.com/q3162146/qc-caku`）：
- `scripts/media/MediaPlayer.lua`（新建，含**断点测试 Hook**）
- `scripts/flow/FlowController.lua`（video 分支 + SetCompleteHandler 改动）
- `scripts/main.lua`（MediaPlayer.Update/Stop + 断点 Hook 接入）
- 若有其他改动（工具准则/docs/versions）列出文件或给 diff。
- 形式不限：文件全文 / 打包 / `git format-patch` / `git diff` 都行；**别混入录屏/截图/Spike 文档**。
- 若只改这 3 个，直接发 3 个文件全文即可。

## 回传
① 断点 Hook 加好后：真机二维码 + 构建确认；② S6 代码文件。我本地 push（分支 `main`）+ 回填文档。
══════════════════════════════════════════════════════
