# 3D 视频屏幕（IMAX 效果）

> 在 3D 世界中创建视频屏幕的完整指南

---

## 📌 快速开始

```lua
local VideoScreen3D = require("urhox-libs/Video/VideoScreen3D")

-- 创建视频屏幕
local screen = VideoScreen3D.Create(scene, {
    videoUrl = "https://example.com/video.mp4",
    videoWidth = 1280,   -- 初始纹理宽度（预估即可）
    videoHeight = 720,   -- 初始纹理高度（预估即可）
    autoPlay = true,
    autoResizeToVideo = true,  -- 自动调整屏幕比例匹配视频
})

-- 每帧更新（必须调用！）
function HandleUpdate(eventType, eventData)
    screen:Update()
end
```

### ⚠️ 注意：纹理尺寸不能为 0

```lua
-- ❌ 错误：尺寸为 0 会导致纹理初始化失败
local screen = VideoScreen3D.Create(scene, {
    videoUrl = "video.mp4",
    videoWidth = 0,   -- ERROR!
    videoHeight = 0,  -- ERROR!
})

-- ✅ 正确：指定预估的视频分辨率（不必精确匹配，引擎会自动检测实际尺寸）
local screen = VideoScreen3D.Create(scene, {
    videoUrl = "video.mp4",
    videoWidth = 1280,
    videoHeight = 720,
    autoResizeToVideo = true,  -- 自动调整屏幕比例匹配实际视频
})
```

---

## 🔴 常见问题及解决方案

### 问题 1: 屏幕不可见

**现象**: 创建的屏幕看不到

**原因**:
- 距离太远（超过迷雾范围）
- 高度太高/太低，超出相机视野
- 屏幕背面朝向玩家

**解决方案**:
```lua
-- 控制距离和高度
local screen = VideoScreen3D.Create(scene, {
    position = Vector3(0, 5, 20),  -- 前方 20 米，高度 5 米
})

-- 或使用默认配置（自动面向原点）
local screen = VideoScreen3D.Create(scene, {
    defaultDistance = 20,  -- 前方距离
    defaultHeight = 5,     -- 屏幕中心高度
})

-- 让屏幕面向指定位置
screen:LookAt(cameraNode.position)
```

### 问题 2: 视频画面偏黑

**现象**: 视频能播放但颜色很暗

**原因**: 材质的 `MatDiffColor` 不是白色，视频颜色被乘以深色

**解决方案**:
```lua
-- VideoScreen3D 已自动处理，手动创建时需要：
local material = Material:new()
material:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
-- 关键：设置为纯白色！
material:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
material:SetTexture(TU_DIFFUSE, videoPlayer:GetTexture())
```

### 问题 3: 视频无法全屏

**现象**: 视频只占据屏幕一小部分

**原因**: 初始纹理尺寸过小，且未启用 `autoResizeToVideo`

**解决方案**:
```lua
-- 方案 1（推荐）：启用 autoResizeToVideo，屏幕自动匹配视频比例
local screen = VideoScreen3D.Create(scene, {
    videoUrl = url,
    videoWidth = 1280,     -- 初始纹理尺寸（预估即可）
    videoHeight = 720,
    autoResizeToVideo = true,
})

-- 方案 2：手动指定与视频匹配的尺寸
local screen = VideoScreen3D.Create(scene, {
    videoUrl = url,
    videoWidth = 1920,
    videoHeight = 1080,
})
```

### 问题 4: Box/Plane 模型 UV 映射混乱

**现象**: 使用 `Models/Box.mdl` 或 `Models/Plane.mdl` 时，视频位置和方向错误

**原因**: 内置模型的 UV 映射不适合视频纹理

**解决方案**: 使用 `CustomGeometry` 手动创建平面

```lua
-- VideoScreen3D 内部实现（自动处理）
local geometry = node:CreateComponent("CustomGeometry")
geometry:SetNumGeometries(1)
geometry:BeginGeometry(0, TRIANGLE_LIST)

local halfW = width / 2
local halfH = height / 2
local normal = Vector3(0, 0, -1)

-- 三角形 1
geometry:DefineVertex(Vector3(-halfW, -halfH, 0))
geometry:DefineNormal(normal)
geometry:DefineTexCoord(Vector2(1, 1))  -- UV 翻转后的坐标

geometry:DefineVertex(Vector3(halfW, -halfH, 0))
geometry:DefineNormal(normal)
geometry:DefineTexCoord(Vector2(0, 1))

geometry:DefineVertex(Vector3(halfW, halfH, 0))
geometry:DefineNormal(normal)
geometry:DefineTexCoord(Vector2(0, 0))

-- 三角形 2
geometry:DefineVertex(Vector3(-halfW, -halfH, 0))
geometry:DefineNormal(normal)
geometry:DefineTexCoord(Vector2(1, 1))

geometry:DefineVertex(Vector3(halfW, halfH, 0))
geometry:DefineNormal(normal)
geometry:DefineTexCoord(Vector2(0, 0))

geometry:DefineVertex(Vector3(-halfW, halfH, 0))
geometry:DefineNormal(normal)
geometry:DefineTexCoord(Vector2(1, 0))

geometry:Commit()
```

### 问题 5: 画面上下颠倒

**现象**: 视频内容上下翻转

**原因**: UV 坐标 Y 轴方向与视频纹理相反

**解决方案**: 翻转 UV 的 Y 坐标
```lua
-- 原始 UV（左下角）
Vector2(0, 0)  -- 错误：对应纹理左上角

-- 修正后 UV（左下角）
Vector2(0, 1)  -- 正确：对应纹理左下角
```

### 问题 6: 画面左右镜像

**现象**: 视频内容左右翻转

**原因**: 屏幕旋转 180° 面向玩家后，UV X 轴也需要翻转

**解决方案**: 同时翻转 UV 的 X 和 Y 坐标
```lua
-- 最终 UV 坐标（屏幕面向 -Z 方向）
-- 左下角顶点: Vector2(1, 1)
-- 右下角顶点: Vector2(0, 1)
-- 右上角顶点: Vector2(0, 0)
-- 左上角顶点: Vector2(1, 0)
```

---

## 📐 UV 映射原理图解

视频纹理与普通纹理的坐标系不同，这是需要翻转 UV 的根本原因：

| 特性 | 普通纹理 (OpenGL) | 视频纹理 |
|------|------------------|---------|
| **原点位置** | 左下角 (0,0) | 左上角 (0,0) |
| **Y 轴方向** | 向上 | 向下 |
| **需要翻转** | 否 | 是（Y 轴） |

```
视频纹理坐标系:          屏幕顶点坐标系（面向 -Z）:
(0,0)-------(1,0)        左上(-W,+H)----右上(+W,+H)
  |           |               |              |
  |   视频    |               |    屏幕      |
  |           |               |              |
(0,1)-------(1,1)        左下(-W,-H)----右下(+W,-H)

屏幕旋转 180° 面向玩家后，需要翻转 UV：
  顶点位置    →    UV 坐标
  左下(-W,-H)  →   (1, 1)
  右下(+W,-H)  →   (0, 1)
  右上(+W,+H)  →   (0, 0)
  左上(-W,+H)  →   (1, 0)
```

**为什么需要双向翻转？**
1. **Y 轴翻转**：视频纹理原点在左上角（与普通纹理相反）
2. **X 轴翻转**：屏幕旋转 180° 面向观察者

> 使用 `VideoScreen3D` 组件时上述翻转自动处理；仅在用 CustomGeometry 手搓视频网格时才需要手动按上表设置 UV。

---

## 🎛️ VideoScreen3D API

### 创建

```lua
local screen = VideoScreen3D.Create(scene, {
    -- 视频源
    -- 视频源：虚拟路径 / uuid://{uuid} / https:// URL
    videoUrl = "url",

    -- ⚠️ 视频分辨率（必须指定！不支持自动检测）
    -- 常见分辨率: 720p=1280×720, 1080p=1920×1080, 4K=3840×2160
    videoWidth = 1280,          -- ⚠️ 必须 > 0
    videoHeight = 720,          -- ⚠️ 必须 > 0

    -- 屏幕尺寸（米）
    width = 16,
    height = 9,

    -- 自动调整屏幕大小以匹配视频宽高比
    autoResizeToVideo = false,  -- 设为 true 自动调整

    -- 位置（可选）
    position = Vector3(0, 5, 20),
    -- 或使用默认计算
    defaultDistance = 20,
    defaultHeight = 5,

    -- 播放设置
    autoPlay = false,
    loop = false,
    volume = 1.0,
    muted = false,

    -- 边框
    showFrame = true,
    frameWidth = 0.3,
    frameColor = Color(0.1, 0.1, 0.1, 1.0),

    -- 调试（打印尺寸检测信息、警告等）
    debug = false,
})
```

> **videoUrl 支持三种格式**：虚拟路径（如 `"videos/intro.mp4"`）、UUID 引用（如 `"uuid://B_J0gVyL..."`）、HTTPS URL（如 `"https://example.com/video.mp4"`）。虚拟路径和 uuid:// 会被路由到实际地址（本地或远端）；HTTPS URL 直接使用，不经过路由。其他格式尚不支持。

### 控制方法

```lua
-- 播放控制
screen:Play()
screen:Pause()
screen:Stop()
screen:Seek(10.5)          -- 跳转到 10.5 秒

-- 音量控制
screen:SetVolume(0.8)      -- 0.0 - 1.0
screen:SetMuted(true)
screen:SetLoop(true)

-- 状态查询
screen:IsPlaying()         -- boolean
screen:IsReady()           -- boolean
screen:GetCurrentTime()    -- float（秒）
screen:GetDuration()       -- float（秒）
screen:GetVideoWidth()     -- int
screen:GetVideoHeight()    -- int

-- 位置控制
screen:SetPosition(Vector3(0, 10, 30))
screen:SetRotation(Quaternion(0, 45, 0))
screen:LookAt(targetPosition)  -- 面向目标

-- 调整大小
screen:SetSize(20, 11.25)  -- 宽度, 高度（米）

-- 每帧更新（必须调用！）
screen:Update()

-- 销毁
screen:Destroy()
```

### 工具方法

```lua
-- 根据视频宽高比计算屏幕尺寸
local w, h = VideoScreen3D.CalculateScreenSize(16, 1280, 720)
-- 结果: 16, 9（16:9 比例）

local w, h = VideoScreen3D.CalculateScreenSizeByHeight(9, 1280, 720)
-- 结果: 16, 9（根据高度计算宽度）
```

### 材质工厂方法

```lua
-- 创建视频材质（自动配置好所有参数）
local material = VideoScreen3D.CreateVideoMaterial(videoTexture)
-- 自动设置：
--   Technique = DiffUnlit
--   MatDiffColor = (1,1,1,1)

-- 创建无光照纯色材质
local material = VideoScreen3D.CreateUnlitMaterial(Color(0.1, 0.1, 0.1, 1.0))
```

### 手动创建视频材质（不使用 VideoScreen3D）

```lua
-- 如果你需要自己处理视频渲染：
local material = Material:new()
material:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
material:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))  -- 必须白色！
material:SetTexture(TU_DIFFUSE, videoPlayer:GetTexture())
```

---

## 💡 最佳实践

### 1. 获取视频实际分辨率

如果不知道视频分辨率，可以先用默认值加载，然后查询：

```lua
-- 先用估计值加载
videoPlayer:Load(url, 1920, 1080)

-- 等待 metadata 加载后获取实际尺寸
SubscribeToEvent("Update", function()
    if videoPlayer:IsReady() then
        local actualWidth = videoPlayer:GetVideoWidth()
        local actualHeight = videoPlayer:GetVideoHeight()
        print("Actual size: " .. actualWidth .. "x" .. actualHeight)
    end
end)
```

### 2. 根据地形高度放置屏幕

```lua
-- 获取地形高度
local terrain = scene:GetComponent("Terrain")
local groundHeight = terrain:GetHeight(Vector3(0, 0, 20))

-- 屏幕底部距地面 1 米
local screenHeight = 9
local screenY = groundHeight + 1 + screenHeight / 2

local screen = VideoScreen3D.Create(scene, {
    position = Vector3(0, screenY, 20),
    -- ...
})
```

### 3. 多个屏幕

```lua
local screens = {}

-- 创建多个屏幕
for i = 1, 3 do
    local screen = VideoScreen3D.Create(scene, {
        videoUrl = "video" .. i .. ".mp4",
        position = Vector3((i - 2) * 20, 5, 30),
        videoWidth = 1280,
        videoHeight = 720,
    })
    table.insert(screens, screen)
end

-- 更新所有屏幕
function HandleUpdate()
    for _, screen in ipairs(screens) do
        screen:Update()
    end
end
```

---

## 🔧 调试技巧

```lua
-- 启用调试模式
local screen = VideoScreen3D.Create(scene, {
    debug = true,  -- 打印详细信息
})

-- 手动检查材质
local mat = screen.material_
print("MatDiffColor: " .. tostring(mat:GetShaderParameter("MatDiffColor"):GetColor()))

-- 检查纹理
local tex = screen.player_:GetTexture()
print("Texture size: " .. tex:GetWidth() .. "x" .. tex:GetHeight())

-- 检查视频实际尺寸
print("Video size: " .. screen:GetVideoWidth() .. "x" .. screen:GetVideoHeight())
```

---

## ⚠️ 注意事项

1. **视频播放支持 WASM 和原生平台**
2. **纹理尺寸不必精确匹配视频分辨率** - 引擎会自动检测实际视频尺寸并调整纹理；`videoWidth`/`videoHeight` 用于初始纹理分配，建议设为预估值（如 1280×720）
3. **必须每帧调用 `Update()`** - 否则视频画面不会更新
4. **使用无光照材质** - 避免视频颜色受光照影响变暗
5. **注意雾效范围** - 屏幕距离不要超过 `zone.fogEnd`

---

## 📁 相关文件

- `urhox-libs/Video/VideoScreen3D.lua` - 视频屏幕组件
- `urhox-libs/Video/VideoPlayer.lua` - 视频播放器 UI Widget

### 示例

| # | 文件 | 说明 |
|---|------|------|
| 19 | `examples/19-video-player-ui.lua` | UI Widget 方式播放视频，支持 UI 叠加 |
| 20 | `examples/20-video-player-nanovg.lua` | NanoVG 裸搓视频渲染，不依赖 UI 库 |
| 21 | `examples/21-video-screen-3d.lua` | 3D 场景 IMAX 视频屏幕 |


