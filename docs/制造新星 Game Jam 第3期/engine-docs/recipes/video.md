# 视频播放开发指南

> **本指南是 UrhoX 视频播放功能的权威参考。**
> AI 助手在生成视频播放相关代码前，必须阅读本指南并遵循约束。

---

## 📌 快速开始

```lua
local UI = require("urhox-libs/UI")
local Video = require("urhox-libs/Video")

UI.Init({
    theme = "default-dark",
    scale = UI.Scale.DEFAULT,
})

local root = UI.Panel {
    width = "100%", height = "100%",

    Video.VideoPlayer {
        src = "videos/intro.mp4",
        width = "100%", height = "100%",
        autoPlay = true,
        objectFit = "contain",
        onEnded = function(self) print("Video ended") end,
    },
}

UI.SetRoot(root)
```

---

## 🔴 核心规则：必须使用 Video.VideoPlayer Widget

### 规则：禁止用 NanoVG 裸搓视频播放器

**视频播放必须使用 `Video.VideoPlayer` Widget**，不得手动创建 C++ `VideoPlayer` 实例 + 独立 NanoVG context 自行渲染。

```lua
-- ✅ 正确：使用 Video.VideoPlayer Widget
local Video = require("urhox-libs/Video")

Video.VideoPlayer {
    src = "videos/intro.mp4",
    width = "100%", height = "100%",
    autoPlay = true,
    onEnded = function(self) print("Done") end,
}

-- ❌ 错误：手动创建 C++ 实例 + 独立 NanoVG 渲染
local nvgCtx = nvgCreate(1)
local player = VideoPlayer:new()
player:Load("videos/intro.mp4", 1280, 720)
player:Play()
-- 然后在 HandleUpdate 里手动调 player:Update()
-- 在 NanoVGRender 里手动调 nvgCreateVideo + nvgImagePattern ...
```

### 为什么禁止 NanoVG 裸搓？

手动用 NanoVG 实现视频播放会引入以下严重问题：

#### 1. 双 NanoVG Context 导致渲染层级混乱

手动创建的 NanoVG context 与 UI 系统内置的 NanoVG context 是**两个独立的渲染通道**。视频在一个 context 里渲染，UI 覆盖层（加载封面、控制按钮、进度条等）在另一个 context 里渲染。两者之间的层级关系需要手动通过 `nvgSetRenderOrder` 协调，极易出错。

```
❌ 裸搓架构（两个独立渲染通道）：

  NanoVG Context A (renderOrder=0)     NanoVG Context B (renderOrder=999990)
  ┌──────────────────────┐             ┌──────────────────────┐
  │    视频帧渲染         │             │    UI 系统渲染        │
  │    (手动管理)         │             │    (自动管理)         │
  └──────────────────────┘             └──────────────────────┘
         ↑                                    ↑
    手动 nvgBeginFrame                   UI.Init() 自动创建
    手动 nvgEndFrame                     自动 BeginFrame/EndFrame
    手动管理生命周期                      自动管理生命周期

✅ Widget 架构（同一个渲染通道）：

  NanoVG Context (UI 系统内置)
  ┌──────────────────────────────────────┐
  │  VideoPlayer.Render()  → 视频帧      │
  │  Children.Render()     → 覆盖层 UI   │  同一个 context，自动管理层级
  └──────────────────────────────────────┘
```

#### 2. UI 状态同步断裂

裸搓方案中，视频覆盖层（加载封面、进度条等）属于 UI 系统，但视频状态（是否就绪、是否结束）属于手动管理的 C++ 实例。两者之间的同步必须通过外部传入的 `uiRoot` 引用来桥接。一旦 `uiRoot` 引用过期（例如切换画面后未更新），覆盖层就无法被正确控制。

**真实案例**：某互动影视项目中，视频加载成功且在底层正常播放，但全黑的"加载中..."封面因 `uiRoot` 引用过期而永远无法隐藏，用户看到的是永远卡在加载状态。

```
❌ 裸搓方案的状态同步链路（脆弱）：

  C++ VideoPlayer          外部 uiRoot 引用          UI 覆盖层
  ┌────────────┐    需要手动传递    ┌────────────┐
  │ IsReady()  │ ──────────────→ │ FindById() │ → 隐藏封面
  │ IsPlaying()│                 │            │ → 更新进度条
  │ GetState() │                 │            │ → 触发回调
  └────────────┘                 └────────────┘
       ↑                              ↑
  手动调 Update()              引用可能过期！

✅ Widget 方案的状态同步（内聚）：

  VideoPlayerWidget
  ┌─────────────────────────────────────┐
  │ Update()  → 检测状态 → 触发回调     │
  │ onReady   → self:FindById() → 隐藏  │  全在 Widget 内部，不依赖外部引用
  │ onEnded   → 直接回调                │
  │ Render()  → 渲染视频 + 子元素       │
  └─────────────────────────────────────┘
```

#### 3. 生命周期管理负担

裸搓方案需要手动管理：NanoVG context 创建/销毁、C++ VideoPlayer 创建/停止/释放、NanoVG video image handle 创建/释放、Update 事件订阅/取消、NanoVGRender 事件订阅/取消。任何一环遗漏都可能导致资源泄漏或崩溃。

Widget 方案下，这些全部由 Widget 框架自动管理。

---

## 🟢 Video.VideoPlayer Widget 完整用法

### Props 参考

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `src` | string | — | 视频源：虚拟路径（如 `"videos/intro.mp4"`）、UUID 引用（如 `"uuid://B_J0gVyL..."`）或 HTTPS URL。虚拟路径和 uuid:// 会被路由到实际地址；HTTPS URL 直接使用。别名 `source` |
| `autoPlay` | boolean | false | 是否自动播放 |
| `loop` | boolean | false | 是否循环 |
| `muted` | boolean | false | 是否静音 |
| `volume` | number | 1.0 | 音量 0-1 |
| `textureWidth` | number | 1920 | 纹理初始宽度 |
| `textureHeight` | number | 1080 | 纹理初始高度 |
| `objectFit` | string | "contain" | 缩放模式：`"contain"` / `"cover"` / `"fill"` |
| `playbackRate` | number | 1.0 | 播放速率（0.25 ~ 4.0），音频音调随速率变化 |
| `backgroundColor` | table | {0,0,0,255} | 背景色 |
| `width` / `height` | 同 Widget | — | 布局尺寸（支持百分比） |

### 回调

| 回调 | 参数 | 触发时机 |
|------|------|----------|
| `onReady` | (self) | 视频解码器就绪，首帧可用 |
| `onPlay` | (self) | 开始播放 |
| `onPause` | (self) | 暂停 |
| `onEnded` | (self) | 播放结束（非循环模式） |
| `onTimeUpdate` | (self, time, duration) | 播放进度更新（约 10 次/秒） |

### 控制方法

```lua
local player = Video.VideoPlayer { src = "videos/intro.mp4" }

player:Play()
player:Pause()
player:Stop()
player:Seek(30.0)          -- 跳到第 30 秒
player:SetVolume(0.5)
player:SetMuted(true)
player:SetPlaybackRate(2.0)  -- 2倍速播放（音调随速率变化）
player:IsPlaying()         -- boolean
player:IsReady()           -- boolean
player:GetCurrentTime()    -- number (秒)
player:GetDuration()       -- number (秒)
player:GetPlaybackRate()   -- number (当前播放速率)
```

### 子元素叠加

VideoPlayer Widget 支持子元素，子元素会自动渲染在视频画面之上。用于添加自定义的覆盖层 UI（加载封面、标题栏、进度条、控制按钮等）：

```lua
Video.VideoPlayer {
    src = "videos/intro.mp4",
    width = "100%", height = "100%",
    autoPlay = true,

    onReady = function(self)
        -- 在自身 Widget 树内查找，不依赖外部引用
        local cover = self:FindById("loadingCover")
        if cover then cover:SetVisible(false) end
    end,

    onTimeUpdate = function(self, time, duration)
        local bar = self:FindById("progressFill")
        if bar and duration > 0 then
            local pct = math.min(time / duration, 1.0)
            bar:SetStyle({ width = tostring(math.floor(pct * 100)) .. "%" })
        end
    end,

    -- 加载封面（onReady 时隐藏）
    UI.Panel {
        id = "loadingCover",
        position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 255 },
        justifyContent = "center", alignItems = "center",
        UI.Label { text = "加载中...", fontSize = 18, fontColor = { 200, 200, 200, 255 } },
    },

    -- 底部进度条
    UI.Panel {
        position = "absolute", bottom = 0, left = 0, right = 0, height = 4,
        backgroundColor = { 40, 40, 50, 255 },
        UI.Panel { id = "progressFill", width = "0%", height = "100%", backgroundColor = { 100, 180, 255, 255 } },
    },
}
```

### 点击行为

Widget 内置了点击切换播放/暂停的行为（`OnPointerUp`）。如果不需要，在 VideoPlayer 上方放一个全尺寸透明 Panel 拦截触摸事件即可。

---

## 🟡 需要自定义视频 UI？继承 Widget

如果 `Video.VideoPlayer` 的默认行为不满足需求（例如需要自定义手势控制、画中画、视频滤镜等），**应继承 Widget 基类**，在 `Render(nvg)` 中使用 UI 系统的 NanoVG context 渲染视频帧：

```lua
local Widget = require("urhox-libs/UI/Core/Widget")

local MyVideoPlayer = Widget:Extend("MyVideoPlayer")

function MyVideoPlayer:Init(props)
    -- 创建 C++ VideoPlayer
    self.player_ = VideoPlayer:new()
    self.nvgImageHandle_ = nil
    Widget.Init(self, props)
end

function MyVideoPlayer:Update(dt)
    if self.player_ then
        self.player_:Update()
    end
end

function MyVideoPlayer:Render(nvg)
    local l = self:GetAbsoluteLayout()

    -- 使用 UI 系统传入的 nvg context 渲染视频帧
    if self.player_ and self.player_:IsReady() then
        local texture = self.player_:GetTexture()
        if texture and not self.nvgImageHandle_ then
            self.nvgImageHandle_ = nvgCreateVideo(nvg, texture)
        end
        if self.nvgImageHandle_ and self.nvgImageHandle_ > 0 then
            local imgPaint = nvgImagePattern(nvg, l.x, l.y, l.w, l.h, 0, self.nvgImageHandle_, 1)
            nvgBeginPath(nvg)
            nvgRect(nvg, l.x, l.y, l.w, l.h)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
        end
    end
    -- 子元素由框架自动渲染在视频上方
end

function MyVideoPlayer:Destroy()
    if self.player_ then
        self.player_:Stop()
        self.player_ = nil
    end
    Widget.Destroy(self)
end
```

**关键点**：`Render(nvg)` 的 `nvg` 参数是 UI 系统的 NanoVG context，不要自己 `nvgCreate`。

---

## 📚 3D 视频屏幕

如果需要在 3D 场景中放置视频屏幕（IMAX 效果），使用 `VideoScreen3D`：

→ 详见 **[video-screen-3d.md](video-screen-3d.md)**

---

## 📎 相关资源

- **UI 开发指南**: [ui.md](ui.md)
- **3D 视频屏幕**: [video-screen-3d.md](video-screen-3d.md)
- **示例 - UI 视频播放器**: `examples/19-video-player-ui.lua`
- **示例 - NanoVG 视频播放器**（仅供理解底层原理）: `examples/20-video-player-nanovg.lua`
