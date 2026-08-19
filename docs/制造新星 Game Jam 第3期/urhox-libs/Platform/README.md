# platform/ - 跨平台处理模块

处理不同平台（Windows, Linux, Mac, Android, iOS, Web）的差异和兼容性。

## 📦 模块清单

| 模块 | 功能 |
|------|------|
| **PlatformUtils.lua** | 平台检测工具 |
| **InputManager.lua** | 统一输入初始化 |
| **MouseLockManager.lua** | 鼠标模式管理 |

---

## PlatformUtils.lua

### 功能
- 平台检测和识别
- 提供统一的平台判断接口
- 缓存结果提高性能

### API

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

-- 获取平台名称
local platform = PlatformUtils.GetPlatform()  -- "Windows", "Linux", "Mac", "Android", "iOS", "Web"

-- 平台判断
if PlatformUtils.IsMobilePlatform() then
    print("Running on mobile")
end

if PlatformUtils.IsDesktopPlatform() then
    print("Running on desktop")
end

if PlatformUtils.IsWebPlatform() then
    print("Running in browser")
end

-- 具体平台判断
if PlatformUtils.IsAndroid() then end
if PlatformUtils.IsIOS() then end
if PlatformUtils.IsWindows() then end
if PlatformUtils.IsLinux() then end
if PlatformUtils.IsMac() then end

-- 功能判断
if PlatformUtils.IsTouchSupported() then
    print("Touch input is available")
end

if PlatformUtils.NeedsVirtualJoystick() then
    print("Should show virtual joystick")
end
```

---

## InputManager.lua

### 功能
- 自动检测平台并初始化合适的输入方式
- 管理虚拟摇杆（移动平台）
- 支持触摸模拟和动态触摸检测

### API

```lua
local InputManager = require "urhox-libs.Platform.InputManager"

function Start()
    -- 基本初始化（自动检测平台）
    InputManager.Initialize()
    
    -- 高级初始化（自定义配置）
    InputManager.Initialize({
        touchSensitivity = 2,
        joystickLayout = "UI/MyJoystick.xml",
        joystickStyle = "UI/DefaultStyle.xml",
        patchString = "<patch>...</patch>"  -- XML patch
    })
    
    -- 手动控制
    InputManager.EnableTouchInput()   -- 启用触摸
    InputManager.DisableTouchInput()  -- 禁用触摸
    InputManager.ToggleTouchInput()   -- 切换
    
    -- 查询状态
    if InputManager.IsTouchEnabled() then
        print("Touch enabled")
    end
    
    -- 获取摇杆索引
    local joystickIdx = InputManager.GetJoystickIndex()
    
    -- 添加设置摇杆（暂停菜单等）
    InputManager.AddSettingsJoystick()
    InputManager.ShowSettingsJoystick(true)  -- 显示
    InputManager.ShowSettingsJoystick(false) -- 隐藏
end
```

### 配置选项

```lua
-- 默认配置
InputManager.config = {
    touchSensitivity = 2,
    defaultJoystickLayout = "UI/ScreenJoystick_Samples.xml",
    defaultJoystickStyle = "UI/DefaultStyle.xml"
}
```

---

## MouseLockManager.lua

### 功能
- 统一管理鼠标模式
- Web 平台特殊处理（需要用户交互）
- 控制台兼容性
- ESC 键跨平台行为

### API

```lua
local MouseLockManager = require "urhox-libs.Platform.MouseLockManager"

function Start()
    -- 初始化（设置期望的鼠标模式）
    MouseLockManager.Initialize(MM_RELATIVE)  -- 相对模式（FPS）
    -- 鼠标模式：MM_ABSOLUTE, MM_RELATIVE, MM_WRAP, MM_FREE
    
    -- 设置鼠标模式
    MouseLockManager.SetMouseMode(MM_RELATIVE)
    
    -- 获取当前模式
    local mode = MouseLockManager.GetMouseMode()
    
    -- 释放/锁定鼠标
    MouseLockManager.ReleaseMouse()  -- 释放锁定
    MouseLockManager.LockMouse()     -- 重新锁定
    
    -- 处理控制台
    MouseLockManager.HandleConsoleVisibility(console.visible)
    
    -- ESC 键处理（推荐）
    SubscribeToEvent("KeyUp", "HandleKeyUp")
end

function HandleKeyUp(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    if key == KEY_ESCAPE then
        if console:IsVisible() then
            console:SetVisible(false)
        else
            -- Web 平台：释放鼠标
            -- 桌面平台：退出
            if MouseLockManager.HandleEscapeKey() then
                -- Web 平台已处理
            else
                engine:Exit()  -- 桌面平台退出
            end
        end
    end
end
```

### 鼠标模式说明

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **MM_ABSOLUTE** | 绝对坐标 | 菜单、UI |
| **MM_RELATIVE** | 相对移动（隐藏光标） | FPS、3D 相机 |
| **MM_WRAP** | 边界环绕 | 策略游戏 |
| **MM_FREE** | 自由模式 | 窗口模式 |

---

## 💡 使用场景

### 场景 1：2D 移动游戏

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local InputManager = require "urhox-libs.Platform.InputManager"

function Start()
    -- 移动平台显示虚拟摇杆
    if PlatformUtils.IsMobilePlatform() then
        InputManager.Initialize({
            joystickLayout = "UI/MyGameJoystick.xml"
        })
    end
end
```

### 场景 2：3D FPS 游戏

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local MouseLockManager = require "urhox-libs.Platform.MouseLockManager"
local InputManager = require "urhox-libs.Platform.InputManager"

function Start()
    -- 桌面/Web：锁定鼠标
    if not PlatformUtils.IsMobilePlatform() then
        MouseLockManager.Initialize(MM_RELATIVE)
    else
        -- 移动：虚拟摇杆
        InputManager.Initialize()
    end
end
```

### 场景 3：跨平台自适应

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local InputManager = require "urhox-libs.Platform.InputManager"
local MouseLockManager = require "urhox-libs.Platform.MouseLockManager"

function Start()
    print("Platform: " .. PlatformUtils.GetPlatformDisplayName())
    
    -- 自动适配
    InputManager.Initialize()  -- 自动处理移动/桌面
    
    if not PlatformUtils.IsMobilePlatform() then
        MouseLockManager.Initialize(MM_RELATIVE)
    end
end
```

---

## 🔧 平台特性对比

| 功能 | Windows/Linux/Mac | Android/iOS | Web |
|------|------------------|------------|-----|
| 鼠标锁定 | ✅ 直接支持 | ❌ 不适用 | ⚠️ 需用户点击 |
| 虚拟摇杆 | ⚠️ 可选 | ✅ 必需 | ⚠️ 可选 |
| 触摸检测 | ⚠️ 动态检测 | ✅ 默认启用 | ⚠️ 看浏览器 |
| ESC 退出 | ✅ 直接退出 | ❌ 不适用 | ❌ 释放鼠标 |

---

## 📚 相关文档

- [Urho3D Input Subsystem](https://urho3d.io/documentation/HEAD/_input.html)
- [Web Platform Limitations](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_Lock_API)

---

**最后更新**: 2025-11-19

