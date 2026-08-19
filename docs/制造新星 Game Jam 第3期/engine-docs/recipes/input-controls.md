# 输入与虚拟控制指南

> **跨平台输入处理完整指南 - PC 键盘/鼠标 + 移动端触摸**

---

## 快速选择

| 游戏类型 | 推荐方案 |
|---------|---------|
| 3D 第一人称 (Minecraft) | GameHUD 摇杆 + 触摸视角 |
| 3D 第三人称角色 | GameHUD 摇杆 + 跳跃 + 触摸视角 |
| TPS 射击游戏 | GameHUD 完整配置（摇杆+跳跃+射击系统） |
| 2D 平台跳跃 | GameHUD 摇杆 + 跳跃 |
| 2D 射击/飞行 | VirtualControls 全屏触控摇杆 |

---

## GameHUD 库（推荐）

### 快速开始

```lua
require "urhox-libs.UI.GameHUD"

function Start()
    GameHUD.Initialize()
    
    local hud = GameHUD.Create({
        enableJump = true,  -- 跳跃按钮
    })
    
    -- 保存引用供 Update 使用
    joystick_ = hud.joystick
    jumpButton_ = hud.jumpButton
    
    -- 移动端触摸视角（第一人称）
    GameHUD.EnableTouchLook({
        camera = cameraNode_,
        onLook = function(deltaYaw, deltaPitch)
            playerYaw_ = playerYaw_ + deltaYaw
            playerPitch_ = playerPitch_ + deltaPitch
        end
    })
end
```

---

## ⚠️ 重要：摇杆输入的正确用法

### 规则：只使用一种输入方式！

GameHUD 摇杆会**自动**将键盘 WASD 转换为摇杆方向：
- **PC端**：`keyBinding="WASD"` 自动生效
- **移动端**：触摸虚拟摇杆

```lua
-- ❌ 错误：同时使用键盘检测 + 摇杆值（会冲突！）
if input:GetKeyDown(KEY_W) then
    moveDir.z = 1  -- 键盘输入
end
if joystick_.y < -0.1 then  -- 摇杆也会响应 W 键
    moveDir.z = moveDir.z + 1  -- 双重输入！
end

-- ✅ 正确：只使用摇杆值
if joystick_ then
    moveDir.x = joystick_.x
    moveDir.z = -joystick_.y  -- 注意 Y 轴取反
end
```

### Y 轴方向约定

摇杆使用**屏幕坐标系**：

| 操作 | joystick.x | joystick.y |
|------|------------|------------|
| 向左推 / A键 | -1 | 0 |
| 向右推 / D键 | +1 | 0 |
| 向上推 / W键 | 0 | **-1** |
| 向下推 / S键 | 0 | **+1** |

### 推荐：使用 `getMovement()` 方法

摇杆提供便捷方法自动处理死区和 Y 轴反转：

```lua
-- 3D 游戏（默认反转Y轴，向上推=正值）
local x, z = joystick_:getMovement()
moveDir.x = x
moveDir.z = z  -- 无需手动取反！

-- 2D 游戏（数学坐标系，Y+ 向上）
local x, y = joystick_:getMovement()  -- 默认即可

-- 2D 游戏（屏幕坐标系，Y+ 向下）
local x, y = joystick_:getMovement(false)  -- 显式不反转
```

| invertY | 向上推返回 | 适用场景 |
|---------|-----------|---------|
| `true` (默认) | **+1** | 3D游戏、2D数学坐标系（Y+向上）|
| `false` | **-1** | 2D屏幕坐标系（Y+向下）|

### 手动处理（旧方式）

如果需要手动处理，Y 轴需要根据游戏类型取反：

```lua
-- 3D 第一人称/第三人称移动
moveDir.x = joystick_.x       -- 左/右 直接映射
moveDir.z = -joystick_.y      -- 向上推(-1) → 向前(+1)
```

---

## 完整示例：3D 第一人称移动

```lua
require "urhox-libs.UI.GameHUD"

local joystick_ = nil
local jumpButton_ = nil
local playerYaw_ = 0
local playerPitch_ = 0

function Start()
    GameHUD.Initialize()
    
    local hud = GameHUD.Create({ enableJump = true })
    joystick_ = hud.joystick
    jumpButton_ = hud.jumpButton
    
    GameHUD.EnableTouchLook({
        camera = cameraNode_,
        onLook = function(deltaYaw, deltaPitch)
            playerYaw_ = playerYaw_ + deltaYaw
            playerPitch_ = Clamp(playerPitch_ + deltaPitch, -89, 89)
        end
    })
end

function UpdatePlayerMovement(timeStep)
    local moveDir = Vector3(0, 0, 0)
    
    -- 使用 getMovement() 方法（自动处理死区和Y轴反转）
    if joystick_ then
        local x, z = joystick_:getMovement()  -- 默认反转Y轴
        moveDir.x = x
        moveDir.z = z
    end
    
    -- 应用玩家视角旋转
    if moveDir:Length() > 0 then
        moveDir = moveDir:Normalized()
        local yawRotation = Quaternion(playerYaw_, Vector3(0, 1, 0))
        moveDir = yawRotation * moveDir
    end
    
    -- 跳跃
    local jumpPressed = jumpButton_ and jumpButton_.isPressed
    if jumpPressed and isOnGround_ then
        playerVelocity_.y = JUMP_SPEED
    end
    
    -- 应用移动...
end
```

---

## GameHUD 配置选项

### GameHUD.Create(config)

```lua
GameHUD.Create({
    enableJump = true,      -- 跳跃按钮
    enableRun = true,       -- 奔跑按钮
    enableShooter = true,   -- 射击系统（装备/射击/换弹按钮）
    
    -- 回调函数
    onJump = function() end,
    onRunChange = function(isRunning) end,
    onArm = function(isArmed) end,
    onShoot = function() end,
    onReload = function() end,
    onAimChange = function(isAiming) end,
})
```

### GameHUD.EnableTouchLook(config)

```lua
GameHUD.EnableTouchLook({
    camera = cameraNode_,       -- 必须：相机节点（用于 FOV 计算灵敏度）
    sensitivity = 2.0,          -- 触摸灵敏度
    invertY = false,            -- 反转 Y 轴
    onLook = function(deltaYaw, deltaPitch)
        -- 自定义视角处理
    end,
    onTap = function()          -- 可选：短点击回调（如攻击/交互）
        Attack()
    end,
    regionPreset = "full_screen",  -- "full_screen" | "right_half" | "left_half"
})
```

> 内部使用 `VirtualControls.CreateTouchLookArea`，自动处理 Tap/Drag 判定和触摸优先级。

---

## 常见游戏类型配置

### Minecraft 风格（第一人称建造）

```lua
local hud = GameHUD.Create({ enableJump = true })
GameHUD.EnableTouchLook({
    camera = cameraNode_,
    onLook = function(deltaYaw, deltaPitch)
        playerYaw_ = playerYaw_ + deltaYaw
        playerPitch_ = Clamp(playerPitch_ + deltaPitch, -89, 89)
    end,
    onTap = function()  -- 短点击 = 攻击/挖矿
        blockInteraction_:onLeftClick()
    end
})
```

### 第三人称动作游戏

```lua
local hud = GameHUD.Create({
    enableJump = true,
    enableRun = true,
})
GameHUD.EnableTouchLook({ camera = tpCamera_:GetNode() })
```

### TPS 射击游戏

```lua
local hud = GameHUD.Create({
    enableJump = true,
    enableRun = true,
    enableShooter = true,
    onArm = function(isArmed) tpCamera_:SetMode(isArmed and "armed" or "normal") end,
    onShoot = function() FireWeapon() end,
    onReload = function() ReloadWeapon() end,
})
```

---

## 鼠标输入（PC端）

### 鼠标锁定模式

```lua
-- 锁定鼠标（FPS 游戏）
input.mouseVisible = false
input.mouseMode = MM_RELATIVE

-- 解锁鼠标（UI 交互）
input.mouseVisible = true
input.mouseMode = MM_ABSOLUTE
```

### 鼠标视角控制

```lua
function UpdateMouseLook(timeStep)
    if input.mouseMode == MM_RELATIVE then
        local mouseMove = input.mouseMove
        playerYaw_ = playerYaw_ + mouseMove.x * MOUSE_SENSITIVITY
        playerPitch_ = playerPitch_ + mouseMove.y * MOUSE_SENSITIVITY
        playerPitch_ = Clamp(playerPitch_, -89, 89)
    end
end
```

### 鼠标按钮检测

```lua
-- 在 Update 中检测
if input:GetMouseButtonPress(MOUSEB_LEFT) then
    -- 左键点击
end
if input:GetMouseButtonDown(MOUSEB_RIGHT) then
    -- 右键按住
end

-- 或订阅事件
SubscribeToEvent("MouseButtonDown", function(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        -- 左键
    elseif button == MOUSEB_RIGHT then
        -- 右键
    end
end)
```

### 鼠标滚轮

> ⚠️ **常见陷阱**: `input.mouseMove` 返回 `IntVector2`（只有 x, y），**没有 `.z` 属性**！
> 不要用 `input.mouseMove.z` 获取滚轮值，这会导致 `nil` 错误。

```lua
-- ✅ 正确：使用 mouseMoveWheel 属性
local wheel = input.mouseMoveWheel
if wheel ~= 0 then
    -- wheel > 0: 向上滚动, wheel < 0: 向下滚动
    cameraDistance = cameraDistance - wheel * 2
end

-- ✅ 也可以使用方法调用
local wheel = input:GetMouseMoveWheel()

```

**常见使用场景**:

```lua
-- 场景1: 相机缩放
if input.mouseMoveWheel ~= 0 then
    local distance = cameraNode.position:Length()
    distance = distance - input.mouseMoveWheel * 2
    distance = Clamp(distance, 5, 30)
    cameraNode.position = cameraNode.position:Normalized() * distance
end

-- 场景2: 列表/内容滚动
if input.mouseMoveWheel ~= 0 then
    scrollOffset = scrollOffset - input.mouseMoveWheel * 20
    scrollOffset = math.max(0, scrollOffset)
end
```

---

## 输入架构模式

### 三种主要模式

| 模式 | 适用场景 | 示例文件 |
|------|---------|---------|
| **模式1: SetControls** | CharacterComponent 角色 | `scaffold-3d-character.lua` |
| **模式2: getMovement()** | 自定义物理/移动 | `Minecraft`, `PhysicsCollision3D.lua` |
| **模式3: 直接摇杆值** | 2D 横版游戏 | `SuperMario.lua` |

### 模式1: SetControls（推荐用于 CharacterComponent）

```lua
-- 初始化时绑定角色控制
GameHUD.Initialize()
GameHUD.SetControls(character_.controls)
GameHUD.Create({ enableJump = true, enableRun = true })

-- Update 中无需处理移动，CharacterComponent 自动读取 controls
function HandleUpdate(timeStep)
    -- 只处理视角
    character_.controls.yaw = character_.controls.yaw + input.mouseMoveX * 0.1
end
```

### 模式2: getMovement()（推荐用于自定义移动）

```lua
-- 初始化
local hud = GameHUD.Create({ enableJump = true })
joystick_ = hud.joystick

-- Update 中获取移动方向
function HandleUpdate(timeStep)
    local moveDir = Vector3(0, 0, 0)
    
    if joystick_ then
        local moveX, moveY = joystick_:getMovement()  -- 自动处理死区和Y轴反转
        moveDir.x = moveX  -- 左右
        moveDir.z = moveY  -- 前后
    end
    
    -- 应用移动...
end
```

### 模式3: 直接摇杆值（用于特殊需求）

```lua
-- 2D 横版只用 X 轴
if joystick_ then
    local moveX, _ = joystick_:getMovement()
    if moveX < -0.1 then
        velocity.x = -SPEED
    elseif moveX > 0.1 then
        velocity.x = SPEED
    end
end
```

### ⚠️ 常见错误

**不要同时使用键盘检测和摇杆值！**

```lua
-- ❌ 错误：双重输入导致冲突
if input:GetKeyDown(KEY_W) then moveDir.z = 1 end      -- 键盘设置 +1
if joystick_.y < -0.1 then moveDir.z = moveDir.z - 1 end  -- 摇杆抵消为 0

-- ✅ 正确：只用摇杆（已内置键盘绑定）
local x, z = joystick_:getMovement()
moveDir.x = x
moveDir.z = z
```

---

## 常见问题

### Q: 为什么 WASD 没反应？

检查是否同时使用了键盘检测和摇杆值：

```lua
-- ❌ 这会导致输入冲突
if input:GetKeyDown(KEY_W) then moveDir.z = 1 end
if joystick_.y < -0.1 then moveDir.z = moveDir.z + (-1) end  -- 抵消了！

-- ✅ 只用摇杆
moveDir.z = -joystick_.y
```

### Q: 为什么前后移动方向反了？

使用 `getMovement()` 方法可以自动处理：

```lua
-- ✅ 推荐：使用 getMovement(true)
local x, z = joystick_:getMovement(true)  -- 自动处理Y轴反转
moveDir.x = x
moveDir.z = z

-- ❌ 手动处理时忘记取反
moveDir.z = joystick_.y  -- 向上推会向后走

-- ✅ 手动处理时记得取反
moveDir.z = -joystick_.y  -- 向上推向前走
```

### Q: 移动端摇杆不显示？

确保 GameHUD 已初始化：

```lua
GameHUD.Initialize()  -- 必须先调用
local hud = GameHUD.Create(...)
```

---

## 加速度计输入（移动端体感控制）

Android/iOS 倾斜手机控制摇杆方向。**仅移动端生效**，桌面端自动旁路。

### 在摇杆上启用

```lua
require "urhox-libs.UI.VirtualControls"

VirtualControls.CreateJoystick({
    keyBinding = "WASD",
    accelerometerMode        = "both",  -- "none" | "only" | "both"
    accelerometerDeadZone    = 0.1,
    accelerometerSensitivity = 1.5,
    accelerometerInvertX     = false,
    accelerometerInvertY     = false,
})
```

### 三种模式

| mode | 行为 | 适用场景 |
|------|------|---------|
| `"none"` (默认) | 禁用，只保留触摸/键盘 | 默认行为，向后兼容 |
| `"only"` | 替换触摸/键盘，自动隐藏摇杆 UI | 纯体感游戏（赛车、平衡球） |
| `"both"` | 与触摸/键盘逐轴组合（同向取大、反向相加） | 提供体感作为辅助 |

### 配置说明

| 字段 | 默认 | 说明 |
|------|------|------|
| `accelerometerMode` | `"none"` | 启用模式 |
| `accelerometerDeadZone` | `0.1` | 死区阈值，绝对值小于此值视为 0 |
| `accelerometerSensitivity` | `1.5` | 灵敏度倍率，结果会被 Clamp 到 [-1, 1] |
| `accelerometerInvertX` / `InvertY` | `false` | 反转对应轴方向 |

### 直接读取原始加速度计（无摇杆 UI）

```lua
local TouchController = require("urhox-libs.Input.TouchController")

-- 用到加速度计：先显式开启（懒加载，幂等；桌面/Web 为空操作）
TouchController.EnableAccelerometer()

function HandleUpdate(_, _)
    -- 检测设备是否支持（反映已 Enable 且设备已注册；Enable 后首帧可能尚未就绪）
    if TouchController.IsAccelerometerAvailable() then
        local sx, sz = TouchController.ReadAccelerometer()  -- 各轴 -1..+1，原始值（无死区/无灵敏度）
        -- 调用方必须自行过滤死区，否则平放时的重力噪声会持续输入
        local DEAD_ZONE = 0.1
        if math.abs(sx) < DEAD_ZONE then sx = 0 end
        if math.abs(sz) < DEAD_ZONE then sz = 0 end
        -- 自行处理 sx / sz...
    end
end
```

> **必须先 `TouchController.EnableAccelerometer()`**：加速度计默认不注册（避免占用 joystick index / 影响真实手柄），用到时才懒加载开启；`VirtualControls` 的 `accelerometerMode` 会自动开启。`ReadAccelerometer` **只读原始值**——死区 / 灵敏度 / 反转全部由调用方处理（理由见 `urhox-libs/Input/README.md`：不同消费者阈值不同）。轴向跨平台不一致：Android 已按屏幕旋转归一化、iOS 为 SDL 原始设备轴向，符号可能不同 `(sx, sz)`。

---

## TouchLookArea（触摸视角区域）

右半屏拖动控制视角，短点击触发攻击：

```lua
VirtualControls.CreateTouchLookArea({
    regionPreset = "right_half",  -- "right_half" | "left_half" | "full_screen"
    sensitivity = 0.15,
    on_look = function(deltaYaw, deltaPitch)
        playerYaw_ = playerYaw_ + deltaYaw
        playerPitch_ = playerPitch_ + deltaPitch
    end,
    on_tap = function()
        Attack()  -- 短点击（<10px 且 <300ms）
    end,
})
```

> **推荐使用 `GameHUD.EnableTouchLook()`**，它内部调用此函数并自动处理 FOV 灵敏度缩放。
> 仅移动端生效，PC 端由鼠标控制。参考 `Minecraft/scripts/ui/MobileInputManager.lua`。

---

## 相关资源

- **GameHUD 源码**: `urhox-libs/UI/GameHUD.lua`
- **VirtualControls 源码**: `urhox-libs/UI/VirtualControls.lua`
- **加速度计模块**: `urhox-libs/Input/TouchController.lua`
- **脚手架**: `templates/scaffold-3d-character.lua`
- **示例**: `LuaScripts/Hand-picked/Minecraft.lua`

---

*最后更新: 2026-05-21*

