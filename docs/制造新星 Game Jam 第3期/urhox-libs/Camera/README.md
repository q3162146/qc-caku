# Camera Library

Camera systems for UrhoX.

## ThirdPersonCamera

第三人称相机库，支持多模式、平滑过渡、墙壁碰撞检测。

### 快速开始

```lua
require "urhox-libs.Camera.ThirdPersonCamera"

-- 创建
local tpCamera_ = ThirdPersonCamera.Create(scene_, {
    modes = {
        normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
    },
})
renderer:SetViewport(0, Viewport:new(scene_, tpCamera_:GetCamera()))

-- 更新（在 PostUpdate 中）
tpCamera_:Update(timeStep, characterNode, yaw, pitch)

-- 切换模式
tpCamera_:SetMode("armed")
```

### 完整文档

详见：**[engine-docs/recipes/camera.md](../../engine-docs/recipes/camera.md)**

### 参考脚手架

`templates/scaffold-3d-character.lua` - 第三人称角色游戏完整示例
