# 相机系统指南

> **3D 游戏相机配置完整指南**

---

## 相机类型选择

| 游戏类型 | 推荐方案 |
|---------|---------|
| 3D 场景漫游（无角色） | 自由相机（见 `scaffold-3d-scene.lua`） |
| 第三人称角色游戏 | **ThirdPersonCamera 库** ⭐ |
| 第一人称游戏 | 相机作为角色子节点 |

---

## ThirdPersonCamera 库

### 快速开始

```lua
require "urhox-libs.Camera.ThirdPersonCamera"

-- 创建第三人称相机
local tpCamera_ = ThirdPersonCamera.Create(scene_, {
    modes = {
        normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
        armed = { distance = 4.0, offset = Vector3(0.6, 1.6, 0), fov = 45.0 },
        aiming = { distance = 2.0, offset = Vector3(0.4, 1.5, 0), fov = 32.0 },
    },
})

-- 设置视口
renderer:SetViewport(0, Viewport:new(scene_, tpCamera_:GetCamera()))

-- 在 PostUpdate 中更新
function HandlePostUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    tpCamera_:Update(timeStep, characterNode, playerYaw_, playerPitch_)
end

-- 切换模式
tpCamera_:SetMode("armed")   -- 战斗模式
tpCamera_:SetMode("aiming")  -- 瞄准模式
tpCamera_:SetMode("normal")  -- 普通模式
```

### 配置选项

```lua
ThirdPersonCamera.Create(scene_, {
    modes = { ... },                      -- 相机模式配置
    transitionSpeed = 8.0,                -- 模式切换平滑速度
    collisionMask = CollisionMaskCamera,  -- 墙壁碰撞检测层
    minDistance = 0.5,                    -- 最小距离（防止过近）
    farClip = 300.0,                      -- 远裁剪面
    nearClip = 0.1,                       -- 近裁剪面
    initialMode = "normal",               -- 初始模式
})
```

### 模式预设

```lua
-- 探索模式（标准第三人称）
normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 }

-- 战斗模式（越肩视角）
armed = { distance = 4.0, offset = Vector3(0.6, 1.6, 0), fov = 45.0 }

-- 瞄准模式（拉近）
aiming = { distance = 2.0, offset = Vector3(0.4, 1.5, 0), fov = 32.0 }

-- 狙击模式
sniper = { distance = 1.5, offset = Vector3(0.3, 1.4, 0), fov = 20.0 }

-- 载具跟随
vehicle = { distance = 10.0, offset = Vector3(0, 3.0, 0), fov = 60.0 }
```

### API 参考

| 方法 | 说明 |
|------|------|
| `Create(scene, config)` | 创建相机实例 |
| `Update(dt, node, yaw, pitch)` | 每帧更新（在 PostUpdate 调用） |
| `SetMode(name)` | 切换相机模式 |
| `GetMode()` | 获取当前模式名 |
| `GetCamera()` | 获取 Camera 组件 |
| `GetNode()` | 获取相机节点 |
| `SetModeConfig(name, config)` | 动态添加/修改模式 |
| `SetTransitionSpeed(speed)` | 设置过渡速度 |

### 墙壁碰撞

库内置墙壁碰撞检测，自动防止相机穿墙：

```lua
ThirdPersonCamera.Create(scene_, {
    collisionMask = CollisionLayerStatic,  -- 只检测静态物体
    minDistance = 0.5,                     -- 最小距离
})
```

### 与 GameHUD 集成

```lua
require "urhox-libs.UI.GameHUD"
require "urhox-libs.Camera.ThirdPersonCamera"

GameHUD.CreateShooterHUD({
    onArm = function(isArmed)
        tpCamera_:SetMode(isArmed and "armed" or "normal")
    end,
    onAimChange = function(isAiming)
        tpCamera_:SetMode(isAiming and "aiming" or (isArmed_ and "armed" or "normal"))
    end,
})
```

---

## 从第一人称改为第三人称

**必须使用 `ThirdPersonCamera` 库**：

```lua
require "urhox-libs.Camera.ThirdPersonCamera"

local tpCamera_ = ThirdPersonCamera.Create(scene_, {
    modes = {
        normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
    },
})

tpCamera_:Update(timeStep, characterNode, playerYaw_, playerPitch_)
```

**关键规则**：
1. **不要手动计算相机位置**
2. **不要修改 yaw 更新符号**
3. **参考脚手架**：`templates/scaffold-3d-character.lua`

---

## ⚠️ 常见陷阱

> 详见 [gotchas/camera.md](../gotchas/camera.md)

| 陷阱 | 要点 |
|------|------|
| `orthoSize` 是**全高度** | 手动计算时需 `* 0.5`，引擎内部使用半高度 |
| `GetScreenRay` 无缓存 | 修改参数后立即调用即可，无需等待下帧 |

---

## 相关资源

- **库源码**: `urhox-libs/Camera/ThirdPersonCamera.lua`
- **脚手架**: `templates/scaffold-3d-character.lua`
- **示例**: `examples/12-fruit-ninja-3d-game.lua`

---

*最后更新: 2026-02-05*

