# UrhoX Lua 5.4 开发指南 - 补充文档

参考: [Lua 5.4 手册](https://www.lua.org/manual/5.4/)
---

## 📖 本文档内容

| 章节 | 说明 |
|------|------|
| eventData 访问详解 | tolua++ 绑定的详细示例 |
| NanoVG API 映射 | C API 与 Lua API 对照 |
| Box2D 脚底传感器 | 2D 平台跳跃常见问题 |
| 命名规范 | 代码风格指南 |
| 脚本组件模板 | 标准组件结构 |
| OOP 类字段误报 | 字段藏在构造器导致 undefined-field |
| 常见错误信息 | 错误速查表 |
| Unicode 转义语法 | AI 生成代码高频错误 |

---

## ✅ eventData 访问方式详解

> AGENTS.md 规则 #3 的补充说明

**正确格式**：`eventData["字段名"]:Get类型()`

```lua
-- 各类型的访问示例
function HandleMouseMove(eventType, eventData)
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local dx = eventData["DX"]:GetFloat()
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    local scancode = eventData["Scancode"]:GetInt()
end

function HandleCollision(eventType, eventData)
    local nodeA = eventData["NodeA"]:GetPtr("Node")
    local nodeB = eventData["NodeB"]:GetPtr("Node")
end
```

**另一种合法写法**（UrhoX 便捷绑定，少一次中间对象，更高效）：

```lua
local dt = eventData:GetFloat("TimeStep")   -- 等价于 eventData["TimeStep"]:GetFloat()
local x  = eventData:GetInt("X")
```

**⚠️ 常见错误**：
- ❌ `eventData.X` - 不能用点语法（tolua++ 对象不支持点访问字段）

**原理**：`eventData` 是 VariantMap（C++ 对象），通过 tolua++ 绑定到 Lua。经典写法 `eventData["字段名"]:Get类型()` 先索引得到 Variant 对象再转类型；便捷写法 `eventData:Get类型("字段名")` 由引擎直接绑定，二者等价。

---

## ✨ NanoVG API 映射规则

> NanoVG Lua API **完全对齐** C API（函数名和参数一致）
>
> ⚠️ 唯一区别：C 中 `vg` 是 `NVGcontext*` 指针，Lua 中是 Object（`nvgCreate(1)` 返回值），**不是 integer**。

```lua
local vg = nvgCreate(1)  -- 返回 NVGContextWrapper (Object)

-- C API: nvgBeginPath(vg)
nvgBeginPath(vg)

-- C API: nvgRect(vg, x, y, w, h)
nvgRect(vg, 100, 100, 200, 150)

-- C API: nvgFillColor(vg, nvgRGBA(255, 0, 0, 255))
nvgFillColor(vg, nvgRGBA(255, 0, 0, 255))
nvgFill(vg)
```

**详细文档**：[NanoVG C API](https://github.com/memononen/nanovg)（函数签名完全相同）

### UrhoX 扩展（上游 C API 没有，别去 github 找）

**`nvgImagePatternTinted`** — 给图片叠色。上游 `nvgImagePattern` 第 8 参是 `alpha`（数字），只能控透明度、无法染色；UrhoX 版把第 8 参换成 `NVGcolor`，对图片做乘法叠色（texture × color）。

```lua
-- 签名：nvgImagePatternTinted(ctx, ox,oy, ex,ey, angle, image, color)
--       前 7 参与 nvgImagePattern 相同，第 8 参 alpha → NVGcolor
local img = nvgCreateImage(vg, "Images/icon.png", 0)   -- img 是 integer 句柄，Start() 里建一次复用
nvgBeginPath(vg)
nvgRect(vg, x, y, w, h)
nvgFillPaint(vg, nvgImagePatternTinted(vg, x, y, w, h, 0, img, nvgRGBA(255, 60, 60, 255)))
nvgFill(vg)
```

`nvgRGBA(255,255,255,255)`（白）= 不染色；色值越低越压暗；color 的 alpha 分量控整体透明度。

> ⚠️ 这是**乘法叠色**（压暗/染色），**不是去饱和**：乘灰色只会变暗、不会变黑白。"置灰禁用"若要的是真·灰度（黑白），tint 做不到，需灰度 shader 或预烘一张灰度图。

---

## ❌ Box2D 脚底传感器不触发碰撞事件

**场景**: 2D 平台跳跃游戏
**症状**: 按空格无法跳跃，地面检测失败，`onGround` 始终为 `false`

**✅ 正确方案：使用 `center` 属性偏移碰撞形状**

```lua
function CreatePlayer()
    playerNode_ = scene_:CreateChild("Player")
    playerNode_:SetPosition2D(0, 2)
    
    -- 创建刚体
    playerBody_ = playerNode_:CreateComponent("RigidBody2D")
    playerBody_.bodyType = BT_DYNAMIC
    playerBody_.fixedRotation = true
    
    -- 碰撞形状 #1: 玩家身体（位于中心）
    local bodyShape = playerNode_:CreateComponent("CollisionCircle2D")
    bodyShape.radius = 0.5
    bodyShape.friction = 0.0
    bodyShape.categoryBits = 2
    
    -- 碰撞形状 #2: 脚底传感器（使用 center 偏移）
    local footSensorShape = playerNode_:CreateComponent("CollisionCircle2D")
    footSensorShape.radius = 0.35
    footSensorShape.center = Vector2(0, -0.45)  -- ✅ 关键：用 center 偏移
    footSensorShape.trigger = true
    footSensorShape.categoryBits = 4
    footSensorShape.maskBits = 1
end
```

**关键要点**:
- ✅ 一个刚体可以有**多个碰撞形状**
- ✅ 使用 `center` 属性调整相对位置（不是子节点！）
- ✅ 碰撞分组 `categoryBits` 和 `maskBits` 用于过滤

**诊断方法**:
1. 在碰撞回调中添加 `print()` 检查事件是否触发
2. 按 Z 键启用物理调试显示
3. 确认传感器使用了 `center` 偏移

**完整示例**: `examples/04-box2d-platformer.lua`

---

## 📋 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 脚本文件 | `PascalCase.lua` | `PlayerController.lua` |
| 函数名 | `PascalCase` | `GetComponent`, `CreateChild` |
| 变量名 | `camelCase` | `playerHealth`, `maxSpeed` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_PLAYERS` |

---

## 📄 脚本组件模板

```lua
-- PlayerController.lua
-- 标准的 Urho3D Lua 脚本组件结构

function Start()
    -- 初始化
    self.speed = 5.0
    self.health = 100

    -- 缓存组件（避免每帧 GetComponent）
    self.body = self.node:GetComponent("RigidBody2D")
    self.sprite = self.node:GetComponent("AnimatedSprite2D")

    -- 订阅事件
    self:SubscribeToEvent("Update", "HandleUpdate")
end

function Stop()
    -- 清理
    self:UnsubscribeFromAllEvents()
end

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    -- 游戏逻辑...
end
```

---

## ⚠️ OOP 类字段误报 undefined-field

用 `local M = {}` + `setmetatable` + `return M` 定义的类，导出后 `M` 成为闭合类型，`undefined-field` 生效。此时**只在 `.new`/`.create` 静态工厂的 `local self = setmetatable({}, M)` 上赋值**的字段，在成员方法中读取会误报 `undefined-field`——静态工厂里对 `local self` 的赋值不会并入导出类型。

**最佳实践**：把字段初始化放进一个**冒号方法**（如 `:init`），由静态工厂调用。冒号方法里 `self` 类型即 `M`，赋值会并入类型 → 消除误报；且字段是 per-instance 初始化，可变默认值（table）各实例独立，不会共享，也无需任何标注。

```lua
-- ❌ 字段只在静态工厂里赋值 → 方法内读报 undefined-field
local Player = {}
Player.__index = Player
function Player.New()
    local self = setmetatable({}, Player)
    self.w, self.h = 14, 14            -- 字段只藏在 .New 里
    return self
end
function Player:CheckCollision()
    return self.w * 0.4, self.h * 0.4  -- 方法内读 → undefined-field: w / h
end
return Player

-- ✅ 同样的字段，改在冒号方法里初始化，静态工厂调用它
local Player = {}
Player.__index = Player
function Player.New()
    local self = setmetatable({}, Player)
    self:init()
    return self
end
function Player:init()                 -- 冒号方法：self 即 Player，赋值并入类型
    self.w, self.h = 14, 14
end
function Player:CheckCollision()
    return self.w * 0.4, self.h * 0.4  -- OK；字段名写错仍会报 undefined-field
end
return Player
```

> 其次：也可用 `---@class`/`---@field` 标注声明字段类型来消除误报。

---

## 🔍 常见错误信息速查

| 错误信息 | 可能原因 | 解决方案 |
|---------|---------|---------|
| `Null pointer access` | 对象是 nil | 添加 nil 检查 |
| `Stack index X out of range` | 参数数量/类型错误 | 检查函数签名 |
| `attempt to index a nil value` | 对象未初始化 | 检查对象创建代码 |
| `Component not found` | 组件不存在 | 检查组件类型名称 |
| `Resource not found` | 资源路径错误 | 检查 asset_dirs 配置 |
| `missing '{' near '"\u...'` | Unicode 转义语法错误 | `\uXXXX` → `\u{XXXX}`，见下方说明 |

---

## ⚠️ 对象生命周期陷阱：局部 Scene

`Scene` 构造后必须由 **Lua 变量明确持有**，否则函数返回后 GC 会回收它，引发随机闪退。

**规则**：自己 `new` 出来的 `Scene`，必须存到**模块级 local 变量**或 **`self.xxx`**，生命周期要覆盖你期望它存活的整段时间。

---

**错误模式 1：只保子产物，顶层对象无人持有**

```lua
-- ❌ audioScene 是 local，函数返回后无人持有
local function setupAudio()
    local audioScene = Scene()
    sfx.node = audioScene:CreateChild("SFX")
end

-- ✅ 把 Scene 自身也存起来
local _audioScene  -- 模块级

local function setupAudio()
    _audioScene = Scene()
    sfx.node = _audioScene:CreateChild("SFX")
end
```

---

**错误模式 2：把 Scene 赋给引擎对象的属性，误以为"交给引擎管了"**

引擎某些属性（如 `connection.scene`、`viewport.scene`）内部是**弱引用**，赋值不增加 Lua 的引用计数，不能阻止 GC 回收。

```lua
-- ❌ local scene 函数返回后失效，connection.scene 是弱引用不保活
local function connect()
    local scene = Scene()
    scene:CreateComponent("Octree")
    serverConn.scene = scene   -- 赋给了弱引用属性，场景仍会被 GC
end

-- ✅ 用模块级变量持有，生命周期与连接一致
local _connScene

local function connect()
    if not _connScene then
        _connScene = Scene()
        _connScene:CreateComponent("Octree")
    end
    serverConn.scene = _connScene
end
```

---

崩溃不在出错的那一帧，而在几秒到几分钟后引擎内部的某次帧更新，位置随机，难以定位。

子节点/子组件由父对象强引用，不需要单独持有。

---

## ⚠️ Unicode 转义语法（AI 生成代码高频错误）

**错误信息**：`missing '{' near '"\u2'`

**原因**：Lua 5.4 的 Unicode 转义语法是 `\u{XXXX}`（花括号），**不是** JavaScript/JSON 风格的 `\uXXXX`。AI（LLM）生成代码时经常混淆这两种语法。

```lua
-- ❌ 错误：JavaScript/JSON 风格（Lua 不支持）
local star = "\u2605"
local heart = "\u2764"

-- ✅ 正确：Lua 5.4 花括号语法
local star = "\u{2605}"
local heart = "\u{2764}"

-- ✅ 也可以直接写 UTF-8 字符（文件须为 UTF-8 编码）
local star = "★"
local heart = "❤"
```

**建议**：遇到 Unicode 字符，优先直接写字符本身（如 `"★"`），避免转义语法问题。

---

## 📖 参考资料

1. **Urho3D Lua API**: https://urho3d.github.io/documentation/HEAD/_lua_scripting.html
2. **NanoVG C API**: https://github.com/memononen/nanovg
3. **Lua 5.4 手册**: https://www.lua.org/manual/5.4/

---

*最后更新: 2026-02-09*
