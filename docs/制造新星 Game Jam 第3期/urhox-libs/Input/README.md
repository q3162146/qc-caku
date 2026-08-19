# input/ - 输入处理模块

处理触摸手势、设备传感器、触摸相机等高级输入功能。

## 📦 模块清单

| 模块 | 功能 |
|------|------|
| **TouchController.lua** | 双指缩放、相机距离、加速度计（体感）读取 |
| **TouchCamera.lua** | 触摸相机控制（3D） |

---

## TouchController.lua

### 功能

- 双指缩放手势检测 + 相机距离管理
- 加速度计（体感）控制：陀螺仪开关量化为方向键，或直接读原始模拟量
- 加速度计读取内置 JoystickState 缓存 + 设备热插拔失效（`JoystickConnected/Disconnected`）

### 底层机制（加速度计）

加速度计**默认不注册**（`SDL_HINT_ACCELEROMETER_AS_JOYSTICK=0`，见 `Input.cpp`）。
调用 `EnableAccelerometer()` 时才在运行时把它注册成名为 `"Android Accelerometer"` /
`"iOS Accelerometer"` 的虚拟 joystick（复用手柄热插拔路径，见 `Input::EnableAccelerometer`），
3 个 axis 对应重力分量。本模块按 name 查询（避免与真实手柄抢占 index 0）。
懒加载的好处：不用加速度计的游戏，joystick 列表不被占用、手柄 index 不受影响。

### API

```lua
local TouchController = require "urhox-libs.Input.TouchController"

function Start()
    -- 初始化（全部可选）
    TouchController.Initialize({
        gyroscopeThreshold = 0.1,
        cameraMinDist = 1.0,
        cameraMaxDist = 20.0,
        touchSensitivity = 1.0,
        useGyroscope = true,
        cameraDistance = 5.0
    })
end

function HandleUpdate(eventType, eventData)
    -- 更新触摸输入：双指缩放 + 陀螺仪（controls 可选，仅陀螺仪用）
    local result = TouchController.Update(controls)
    if result.zoom then
        print("Zooming! Distance: " .. result.cameraDistance)
    end
end

-- 相机距离
TouchController.SetCameraDistance(10.0)
TouchController.ResetCameraDistance()  -- 重置到 5.0
local distance = TouchController.GetCameraDistance()
local isZooming = TouchController.IsZooming()

-- 陀螺仪开关（量化为 CTRL_LEFT/RIGHT/FORWARD/BACK，由 Update 写入 controls）
TouchController.SetGyroscopeEnabled(true)
```

### 直接读加速度计原始模拟量

`Update` 的陀螺仪路径把倾斜量化成离散方向键。需要力度的场景（视角微调、
摇晃检测、虚拟摇杆混合）请直接读原始值。

> ⚠️ **使用前必须先 `EnableAccelerometer()`**。加速度计默认不注册（避免占用
> joystick index / 影响真实手柄），用到时显式开启即可懒加载。开启后设备需一帧
> 才注册成 joystick，故首帧读取可能仍是 (0, 0)。`VirtualControls` 的
> `accelerometerMode` 会自动 Enable，无需手动调用。

```lua
-- 开启一次（如 Start 里）。幂等；桌面/Web 无传感器时为安全空操作。
TouchController.EnableAccelerometer()

-- 轴向跨平台不一致：Android 已按屏幕旋转归一化、iOS 为 SDL 原始设备轴向，符号可能不同。
-- 默认水平向上时 (0, 0)；无设备 / 无传感器 / 未授权 / 未 Enable 时返回 (0, 0)。
local ax, ay = TouchController.ReadAccelerometer()

-- 设置菜单灰显"加速度计控制"选项用（反映已 Enable 且设备已注册）
if TouchController.IsAccelerometerAvailable() then ... end

-- 不再需要时可关闭（省电 / iOS 停 CMMotionManager）
TouchController.DisableAccelerometer()
```

`ReadAccelerometer` 不做死区/灵敏度，由调用方按场景处理（不同消费者合理阈值差异极大）：

```lua
local ax, ay = TouchController.ReadAccelerometer()
local DEAD_ZONE = 0.1
local SENSITIVITY = 1.5
ax = (math.abs(ax) < DEAD_ZONE) and 0 or ax * SENSITIVITY
ay = (math.abs(ay) < DEAD_ZONE) and 0 or ay * SENSITIVITY
```

### 配置选项

```lua
TouchController.config = {
    gyroscopeThreshold = 0.1,    -- 陀螺仪量化阈值
    cameraMinDist = 1.0,         -- 相机最小距离
    cameraMaxDist = 20.0,        -- 相机最大距离
    touchSensitivity = 1.0       -- 触摸缩放灵敏度
}
```

### 与 VirtualControls 集成

`VirtualControls` 已经内置对 `TouchController.ReadAccelerometer` 的调用。给虚拟摇杆加
`accelerometerMode` 配置即可启用加速度计混合，无需手动调本模块：

```lua
VirtualControls.CreateJoystick({
    keyBinding = "WASD",
    accelerometerMode = "both",       -- "none" | "only" | "both"
    accelerometerDeadZone = 0.1,
    accelerometerSensitivity = 1.0,
})
```

详见 `urhox-libs/UI/VirtualControls.lua`。

---

## TouchCamera.lua

### 功能
- 触摸拖动旋转 3D 相机
- 偏航角（Yaw）和俯仰角（Pitch）控制
- 自动跳过 UI 元素上的触摸
- 光标同步

### API

```lua
local TouchCamera = require "urhox-libs.Input.TouchCamera"
local InputManager = require "urhox-libs.PlatformInputManager"

function Start()
    -- 创建相机
    local cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(0, 0, -10)
    local camera = cameraNode:CreateComponent("Camera")

    -- 初始化触摸相机
    TouchCamera.Initialize(cameraNode, {
        touchSensitivity = 2,
        initialYaw = 0,
        initialPitch = 0,
        useNodeRotation = false  -- 是否使用节点当前旋转作为初始值
    })

    -- 订阅场景更新
    SubscribeToEvent("SceneUpdate", "HandleSceneUpdate")
end

function HandleSceneUpdate(eventType, eventData)
    -- 更新触摸相机
    local touchEnabled = InputManager.IsTouchEnabled()
    TouchCamera.Update(touchEnabled)
end

-- 控制相机角度
TouchCamera.SetYaw(45)       -- 设置偏航角
TouchCamera.SetPitch(30)     -- 设置俯仰角

-- 获取当前角度
local yaw = TouchCamera.GetYaw()
local pitch = TouchCamera.GetPitch()

-- 重置
TouchCamera.Reset(0, 0)  -- 重置到初始角度

-- 启用/禁用
TouchCamera.SetEnabled(false)
TouchCamera.SetEnabled(true)

-- 更换相机节点
TouchCamera.SetCameraNode(newCameraNode)
```

### 角度限制

- **Yaw（偏航角）**: 无限制（-∞ 到 +∞）
- **Pitch（俯仰角）**: 限制在 -89° 到 +89°（避免万向节死锁）
- **Roll（翻滚角）**: 固定为 0

---

## 💡 使用场景

### 场景 1：第三人称相机 + 加速度计微调视角

```lua
local TouchCamera     = require "urhox-libs.Input.TouchCamera"
local TouchController = require "urhox-libs.Input.TouchController"
local InputManager    = require "urhox-libs.PlatformInputManager"

function Start()
    InputManager.Initialize()
    cameraNode = scene_:CreateChild("Camera")
    TouchCamera.Initialize(cameraNode, { touchSensitivity = 1.5, initialPitch = 15 })
    TouchController.EnableAccelerometer()  -- 用到加速度计，先开启
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
end

function HandlePostUpdate(_, _)
    TouchCamera.Update(InputManager.IsTouchEnabled())

    -- 倾斜手机微调视角
    local ax, _ = TouchController.ReadAccelerometer()
    if math.abs(ax) > 0.1 then
        TouchCamera.SetYaw(TouchCamera.GetYaw() + ax * 2.0)
    end
end
```

### 场景 2：摇晃手机触发技能

```lua
local TouchController = require "urhox-libs.Input.TouchController"

function Start()
    TouchController.EnableAccelerometer()  -- 用到加速度计，先开启
    SubscribeToEvent("Update", "HandleUpdate")
end

local lastAx, lastAy = 0, 0
function HandleUpdate(_, _)
    local ax, ay = TouchController.ReadAccelerometer()
    local dx, dy = ax - lastAx, ay - lastAy
    if dx*dx + dy*dy > 0.5*0.5 then OnShake() end
    lastAx, lastAy = ax, ay
end
```

### 场景 3：双指缩放 + 俯视相机

```lua
local TouchController = require "urhox-libs.Input.TouchController"

function Start()
    TouchController.Initialize({ cameraMinDist = 10.0, cameraMaxDist = 50.0, cameraDistance = 25.0 })
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(_, _)
    local result = TouchController.Update()
    if result.zoom then
        cameraNode.position = Vector3(0, result.cameraDistance, 0)
    end
end
```

---

## 🎮 触摸事件优先级

触摸事件处理顺序：

1. **UI 元素** - 最高优先级（按钮、滑块等）
2. **游戏逻辑** - 拾取对象、选择单位等
3. **VirtualControls** - 虚拟摇杆、按钮、视角触摸区
4. **TouchCamera** - 空白区域拖动旋转相机
5. **TouchController** - 双指缩放

`TouchCamera` / `TouchController` 都会自动跳过 UI 元素上的触摸（检查 `state.touchedElement`）。

---

## 📚 相关文档

- [Urho3D Touch Input](https://urho3d.io/documentation/HEAD/_input.html)
- [Mobile Input Best Practices](../docs/recipes/mobile-input.md)
- [VirtualControls 加速度计配置](../UI/VirtualControls.lua)

---

**最后更新**: 2026-05-21
