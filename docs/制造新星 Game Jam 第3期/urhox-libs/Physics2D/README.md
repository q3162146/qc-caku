# physics-2d/ - 2D 物理工具模块

2D 物理系统（Box2D）的辅助工具和组件。

## 📦 模块清单

| 模块 | 功能 |
|------|------|
| **TilemapPhysics.lua** | TMX 瓦片地图碰撞生成 |
| **PathFollower.lua** | 路径跟随组件 |

---

## TilemapPhysics.lua

### 功能
- 从 Tiled Map Editor (TMX) 对象层自动生成 Box2D 碰撞形状
- 支持矩形、圆形、多边形、链条（折线）
- 支持正交和等距地图
- 支持自定义物理属性

### API

```lua
local TilemapPhysics = require "urhox-libs.Physics2D.TilemapPhysics"

function Start()
    -- 创建瓦片地图
    local tileMapNode = scene_:CreateChild("TileMap")
    local tileMap = tileMapNode:CreateComponent("TileMap2D")
    tileMap.tmxFile = cache:GetResource("TmxFile2D", "Urho2D/MyLevel.tmx")
    
    -- 方式 1：自动从 "Physics" 层创建碰撞
    TilemapPhysics.AutoCreateFromLayer(tileMapNode, "Physics", {
        defaultFriction = 0.8,
        bodyType = BT_STATIC
    })
    
    -- 方式 2：手动指定层
    local physicsLayer = tileMap:GetLayer("Collision")
    if physicsLayer then
        TilemapPhysics.CreateCollisionShapes(
            tileMapNode,
            physicsLayer,
            tileMap.info,  -- 地图信息
            {
                defaultFriction = 0.5,
                bodyType = BT_STATIC
            }
        )
    end
end
```

### 支持的对象类型

| TMX 对象类型 | Box2D 形状 |
|------------|-----------|
| **Rectangle** | CollisionBox2D |
| **Ellipse** | CollisionCircle2D |
| **Polygon** | CollisionPolygon2D |
| **Polyline** | CollisionChain2D |

### 自定义属性

在 Tiled 中为对象添加自定义属性：

| 属性名 | 类型 | 说明 |
|-------|------|------|
| **Friction** | float | 摩擦力（0-1） |
| **Restitution** | float | 弹性（0-1） |
| **Density** | float | 密度 |
| **IsTrigger** | bool/string | 是否为触发器 |

```xml
<!-- Tiled 中的对象属性示例 -->
<object id="1" type="Platform" x="0" y="64" width="128" height="16">
  <properties>
    <property name="Friction" type="float" value="0.9"/>
    <property name="Restitution" type="float" value="0.1"/>
  </properties>
</object>
```

### 从对象创建路径

```lua
-- 从 Polyline 对象创建路径（用于 PathFollower）
local movingLayer = tileMap:GetLayer("Moving")
for i = 0, movingLayer:GetNumObjects() - 1 do
    local object = movingLayer:GetObject(i)
    if object.objectType == OT_POLYLINE then
        local path = TilemapPhysics.CreatePathFromObject(object, Vector2(0, 0))
        -- 使用 path...
    end
end
```

---

## PathFollower.lua

### 功能
- 沿路径移动节点
- 支持循环、往返、单程模式
- 速度控制（正向/反向）
- 暂停/恢复
- 回调通知

### API

```lua
-- 作为 ScriptObject 使用
local node = scene_:CreateChild("MovingPlatform")
node.position2D = Vector2(0, 0)

-- 创建 PathFollower 组件
local follower = node:CreateScriptObject("PathFollower")

-- 设置路径
follower:SetPath({
    Vector2(0, 0),
    Vector2(10, 0),
    Vector2(10, 10),
    Vector2(0, 10)
})

-- 配置
follower:SetSpeed(2.0)      -- 速度
follower:SetLoop(true)      -- 循环模式
follower:SetReverse(false)  -- 不往返（循环时忽略）

-- 回调
follower.onReachWaypoint = function(index)
    print("Reached waypoint: " .. index)
end

follower.onPathComplete = function()
    print("Path completed!")
end

follower.onDirectionChange = function(direction)
    -- direction 是 Vector2
    print("Moving direction: " .. direction.x .. ", " .. direction.y)
end

-- 控制
follower:SetPaused(true)   -- 暂停
follower:SetPaused(false)  -- 恢复
follower:Reset()           -- 重置到起点

-- 查询
local speed = follower:GetSpeed()
local paused = follower:IsPaused()
local waypoint = follower:GetCurrentWaypoint()
local direction = follower:GetDirection()
```

### 模式说明

| 模式 | loop | reverse | 行为 |
|------|------|---------|------|
| **循环** | true | - | A→B→C→D→A（无限循环） |
| **往返** | false | true | A→B→C→D→C→B→A（往返） |
| **单程** | false | false | A→B→C→D（停止） |

### 使用 require 方式（而非文件路径）

```lua
-- ✅ 推荐：使用 require
local PathFollower = require "urhox-libs.Physics2D.PathFollower"
local follower = node:CreateScriptObject(PathFollower)

-- ❌ 旧方式（兼容但不推荐）
local follower = node:CreateScriptObject("LuaScripts/Utilities/2D/Mover.lua", "Mover")
```

---

## 💡 使用场景

### 场景 1：平台跳跃游戏

```lua
local TilemapPhysics = require "urhox-libs.Physics2D.TilemapPhysics"

function CreateScene()
    -- 加载瓦片地图
    local tileMapNode = scene_:CreateChild("TileMap")
    local tileMap = tileMapNode:CreateComponent("TileMap2D")
    tileMap.tmxFile = cache:GetResource("TmxFile2D", "Urho2D/Level1.tmx")
    
    -- 自动创建碰撞（从 "Physics" 层）
    TilemapPhysics.AutoCreateFromLayer(tileMapNode)
    
    -- 创建移动平台（从 "Moving" 层）
    local movingLayer = tileMap:GetLayer("Moving")
    if movingLayer then
        for i = 0, movingLayer:GetNumObjects() - 1 do
            local object = movingLayer:GetObject(i)
            if object.objectType == OT_POLYLINE and object.type == "Platform" then
                CreateMovingPlatform(object)
            end
        end
    end
end

function CreateMovingPlatform(pathObject)
    local node = scene_:CreateChild("Platform")
    node.position2D = pathObject:GetPoint(0)
    
    -- 添加精灵
    local sprite = node:CreateComponent("StaticSprite2D")
    sprite.sprite = cache:GetResource("Sprite2D", "Urho2D/Platform.png")
    
    -- 添加物理
    local body = node:CreateComponent("RigidBody2D")
    body.bodyType = BT_KINEMATIC  -- 运动学刚体
    local shape = node:CreateComponent("CollisionBox2D")
    shape.size = Vector2(2, 0.5)
    
    -- 添加路径跟随
    local follower = node:CreateScriptObject("PathFollower")
    follower:SetPath(TilemapPhysics.CreatePathFromObject(pathObject))
    follower:SetSpeed(tonumber(pathObject:GetProperty("Speed") or "1.5"))
    follower:SetLoop(true)
end
```

### 场景 2：敌人巡逻

```lua
function CreatePatrolEnemy(startPos, path)
    local node = scene_:CreateChild("Enemy")
    node.position2D = startPos
    
    -- 精灵
    local sprite = node:CreateComponent("AnimatedSprite2D")
    sprite.animationSet = cache:GetResource("AnimationSet2D", "Urho2D/Enemy.scml")
    sprite.animation = "walk"
    
    -- 物理
    local body = node:CreateComponent("RigidBody2D")
    body.bodyType = BT_KINEMATIC
    local shape = node:CreateComponent("CollisionCircle2D")
    shape.radius = 0.5
    
    -- 路径跟随
    local follower = node:CreateScriptObject("PathFollower")
    follower:SetPath(path)
    follower:SetSpeed(1.0)
    follower:SetReverse(true)  -- 往返巡逻
    
    -- 根据移动方向翻转精灵
    follower.onDirectionChange = function(direction)
        sprite.flipX = direction.x < 0
    end
    
    return node
end
```

### 场景 3：引导轨道

```lua
-- 引导玩家的轨道（仅用于 AI 路径，不是物理）
function CreateGuidePath()
    local guidePath = {
        Vector2(0, 0),
        Vector2(5, 2),
        Vector2(10, 2),
        Vector2(15, 5)
    }
    
    local guide = scene_:CreateChild("Guide")
    guide.position2D = guidePath[1]
    
    local follower = guide:CreateScriptObject("PathFollower")
    follower:SetPath(guidePath)
    follower:SetSpeed(3.0)
    follower:SetLoop(false)
    follower:SetReverse(false)
    
    follower.onPathComplete = function()
        print("Guide reached destination")
        guide:Remove()
    end
end
```

---

## 🔧 与 Tiled Map Editor 集成

### 1. 创建物理层

在 Tiled 中：
1. 创建对象层（Object Layer），命名为 `Physics`
2. 添加矩形、圆形、多边形对象
3. 设置自定义属性（Friction, Restitution 等）

### 2. 创建移动路径层

1. 创建对象层，命名为 `Moving`
2. 使用 Polyline 工具绘制路径
3. 设置对象类型（type）为 `Platform`, `Enemy` 等
4. 添加 `Speed` 属性

### 3. 导出为 TMX

保存为 `.tmx` 文件，放到 `Data/Urho2D/` 目录。

---

## 📚 相关文档

- [Urho2D Physics](https://urho3d.io/documentation/HEAD/_urho2_d.html)
- [Box2D Manual](https://box2d.org/documentation/)
- [Tiled Map Editor](https://www.mapeditor.org/)

---

**最后更新**: 2025-11-19

