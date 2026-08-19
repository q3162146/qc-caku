# UrhoX Lua 库 (urhox-libs)

UrhoX 游戏开发的通用 Lua 库集合。

## 📚 库清单

### 🎮 UI/GameHUD - 虚拟摇杆与游戏 HUD（跨平台必备）

移动端和跨平台游戏的核心控制库，基于 NanoVG 渲染。

| 模块 | 功能 |
|------|------|
| **GameHUD.lua** | 高层 API：一键创建基础 HUD / 射击 HUD |
| **VirtualControls.lua** | 底层库：虚拟摇杆、虚拟按钮、技能轮盘、DPI 自适应 |

```lua
require "urhox-libs/UI/GameHUD"

function Start()
    GameHUD.Initialize()
    GameHUD.SetControls(character.controls)
    
    -- 基础 HUD（平台/冒险游戏）
    GameHUD.CreateBasicHUD()
    
    -- 射击 HUD（TPS/FPS 游戏）
    GameHUD.CreateShooterHUD({
        onShoot = function() stateMachine:SetTrigger("shoot") end,
        onReload = function() stateMachine:SetTrigger("reload") end,
    })
end
```

### 🎨 UI/ - UI 组件库

基于 Yoga 布局引擎和 NanoVG 渲染的完整 UI 解决方案。

| 子目录 | 功能 |
|--------|------|
| **Core/** | 基础框架：Widget、Theme、Style、Input、Gesture 等 |
| **Widgets/** | 40+ 预制组件：Button、Modal、ScrollView、Tabs、Table 等 |
| **Components/** | 游戏专用组件：SkillTree、ItemSlot、ChatWindow、VirtualList 等 |
| **Examples/** | 使用示例 |

详细文档见 [UI/README.md](UI/README.md)

### 🎥 Camera/ - 相机控制

| 模块 | 功能 |
|------|------|
| **ThirdPersonCamera.lua** | 第三人称相机控制（支持碰撞检测） |

### 🌐 Platform/ - 跨平台处理

| 模块 | 功能 |
|------|------|
| **PlatformUtils.lua** | 平台检测和通用工具 |
| **InputManager.lua** | 统一输入初始化（自动平台检测） |
| **MouseLockManager.lua** | 鼠标模式管理（Web 兼容） |

### 🎮 Input/ - 输入处理

| 模块 | 功能 |
|------|------|
| **TouchController.lua** | 双指缩放、相机距离、加速度计（体感）读取 |
| **TouchCamera.lua** | 触摸相机控制（3D） |

### 🎭 Animation/ - 动画资源

| 子目录 | 功能 |
|--------|------|
| **FSM/** | 预制状态机和混合空间配置文件 |

### ⚛️ Physics2D/ - 2D 物理工具

| 模块 | 功能 |
|------|------|
| **TilemapPhysics.lua** | TMX 瓦片地图碰撞生成 |
| **PathFollower.lua** | 路径跟随组件 |

### ✨ Effects/ - 特效工具

| 模块 | 功能 |
|------|------|
| **Effects.lua** | 粒子特效和音效辅助 |

### 🔷 Geometry/ - 几何体生成

| 模块 | 功能 |
|------|------|
| **Primitives.lua** | 半球、弧形、圆锥等自定义几何体 |

### 🌐 Network/ - 网络工具

| 模块 | 功能 |
|------|------|
| **CommandLineParser.lua** | 命令行参数解析 |

---

## 🚀 快速开始

### 引用规则

```lua
-- ✅ 正确：使用斜杠路径
require "urhox-libs/UI/GameHUD"
require "urhox-libs/Platform/PlatformUtils"
require "urhox-libs/UI/init"

-- ❌ 错误：不要使用点号
require "urhox-libs.UI.GameHUD"  -- 错误！
```

---

## 🎯 设计原则

1. **模块化** - 每个模块独立可用，最小化依赖
2. **零侵入** - 不污染全局命名空间，使用 require 返回
3. **跨平台** - 自动检测和适配平台

---

## ✅ 测试

使用 `urhox-libs/Testing/luaunit.lua` 测试框架编写单元测试。

详见 [Tests/README.md](Tests/README.md)

---

**版本**: v2.0  
**最后更新**: 2026-01-18
