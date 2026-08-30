# 开发封存（不进发布包）

本目录只做封存，**不在 `assets/` / `scripts/` 构建引用范围内**，不参与打包。
素女篇正式入口仍是 `scripts/main.lua` 的全局 `Start()`。

## 目录

| 路径 | 内容 |
|------|------|
| `_dev/lifeplate_src/` | 命盘实验 Lua |
| `_dev/lifeplate_assets/` | 命盘印面 / 音效 |
| `_dev/video_spike/` | 视频生命周期 Spike 实验模块（原 `scripts/experiments/VideoSpike.lua`） |
| `_dev/spike_videos/` | Spike 三档测试片（原 `assets/video/短视频生命周期 spike（推荐）/`） |
| `_dev/cgt_intermediates/` | Seedance 生成中间产物（cgt-*.mp4 + 尾帧，与正式 `assets/video/剧情/` 重复） |
| `_dev/chapter_card_sources/` | 章节卡生成源图（正式卡在 `assets/image/章节卡/`） |
| `_dev/story_last_frames/` | 剧情视频尾帧静帧（正式视频已在 `assets/video/剧情/`） |

## 命盘解封

素女篇上线后若要续做命盘实验：把 `_dev/lifeplate_src/` 移回 `scripts/lifeplate/`、`_dev/lifeplate_assets/` 移回 `assets/`，并在 `main.lua` 顶部恢复 `DEBUG_LIFEPLATE=true` 段。

```bash
mkdir -p scripts/lifeplate assets/textures assets/audio
mv _dev/lifeplate_src/* scripts/lifeplate/
mv _dev/lifeplate_assets/textures/lifeplate assets/textures/lifeplate
mv _dev/lifeplate_assets/audio/lifeplate assets/audio/lifeplate
```

然后在 `scripts/main.lua` 最顶部恢复：

```lua
-- 【实验】发布素女篇前必须改为 false 或删除本段
local DEBUG_LIFEPLATE = true
if DEBUG_LIFEPLATE then
    return require("lifeplate.lp_main").run()
end
```

注意：`require` 路径是 `lifeplate.lp_main`（相对 `scripts/`），不是 `scripts.lifeplate.lp_main`。

## Spike 解封（一般不需要）

把 `_dev/video_spike/VideoSpike.lua` 移回 `scripts/experiments/`，把 `_dev/spike_videos/` 移回 `assets/video/`，并在 `main.lua` 恢复 `require "experiments.VideoSpike"` 与 F6 入口。
