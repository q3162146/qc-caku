# 发 TTM：S6 视频版构建 + 真机二维码 + 代码回推

> 用法：整段复制发给 TTM。让 TTM 用带 `MediaPlayer.lua` 的 S6 代码官方构建、生成真机测试二维码，并把 S6 代码 push 到 qc-caku（仓库规范）。

══════════════════════════════════════════════════════
【S6 视频媒体接入——请构建 + 出真机码 + 回推代码】

背景：S6 视频媒体模块（`scripts/media/MediaPlayer.lua` + `FlowController`/`main.lua` 接入）你已实现并验证（LSP 0 error / 构建成功 / 本地运行错误路径 OK）。现在请：
1. **用带 MediaPlayer 的 S6 代码官方构建**（入口 `scripts/main.lua`，LSP 0 error）。
2. **生成 TapTap 真机测试二维码**（`test_qrcode`）——本次验证的是 **MediaPlayer 链路**（能播→断点→读档→后台→P02），不是真实剧情内容；素材仍占位 `S1_test_mid_6Mbps.mp4`（画面为「素女篇·视频链路测试」+ 时间码属正常）。
3. **按仓库规范，把 S6 代码 push 到权威仓库 `https://github.com/q3162146/qc-caku`**（`MediaPlayer.lua` + `FlowController`/`main.lua` 改动 + 工具准则/ docs/memory-index/versions 更新），分支 `main`；这样本地与你这边一致，避免分叉。

## 请一并确认
- 构建产物里 `MediaPlayer.lua`、`FlowController` 的 `video` 分支（`MediaPlayer.Play(p, data_)`）、`main.lua` 的 `MediaPlayer.Update(dt)`/`Stop(true)` 均已包含。
- `VIDEO_SOURCES` 目前为占位（S1~S13 → `S1_test_mid_6Mbps.mp4`）。

## 无需你做的
- 真机回归由用户侧执行（扫码 → P01 视频 → P02；断点/读档/后台/连续段/内存回落）。你只需给二维码 + 确认构建即可。
- 若你那边有 PC WASM 预览通道，可顺带把「P01 视频播放→P02」自己跑一遍，结果一并回传（没有就无需，别伪报）。

## 回传
二维码（或码链接）+ 构建确认（含 MediaPlayer）+ push 是否成功（提交号）。
══════════════════════════════════════════════════════
