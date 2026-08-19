# UrhoX 联网游戏开发指南

## 概述

本文档介绍如何使用 UrhoX 引擎开发联网多人游戏，涵盖服务器-客户端架构、场景复制、节点同步、远程事件等核心概念。

---

## 1. 架构概述

### 1.1 服务器-客户端模型

UrhoX 联网游戏采用**权威服务器**架构：

```
┌─────────────────────────────────────────────────────────────────┐
│                     服务器 (Headless)                            │
│  - 运行完整游戏逻辑（移动、碰撞、AI、得分等）                      │
│  - 无渲染，纯计算                                                │
│  - 游戏对象使用 REPLICATED 模式创建                              │
│  - 从 connection.controls 读取玩家输入                           │
└─────────────────────────────────────────────────────────────────┘
                          ↕ Scene Replication（自动同步）
┌─────────────────────────────────────────────────────────────────┐
│                          客户端                                  │
│  - 负责渲染和用户输入                                            │
│  - 通过 connection.controls 发送输入到服务器                      │
│  - 通过 ScriptObject 的 DelayedStart 为同步的节点创建本地渲染组件   │
│  - 本地播放音效和粒子特效                                        │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 场景复制机制（Scene Replication）

引擎内置场景复制功能，自动同步：
- **REPLICATED 节点**的位置、旋转、缩放
- **节点变量**（通过 SetVar 设置的数据）
- **节点创建和删除**事件

### 1.3 推荐代码结构

```
scripts/
├── Main.lua                 # 入口文件（判断运行模式）
├── Network/
│   ├── Shared.lua           # 共享代码（配置、事件名、工具函数）
│   ├── Server.lua           # 服务器逻辑
│   └── Client.lua           # 客户端逻辑
└── Modules/                 # 可复用模块
```

### 1.4 运行模式判断

框架提供两个全局函数判断当前运行模式：

| 函数 | 返回值 | 说明 |
|------|--------|------|
| `IsServerMode()` | boolean | 当前是否为服务器模式 |
| `IsClientMode()` | boolean | 当前是否为客户端模式 |

**入口文件示例**：

```lua
-- Main.lua
local Module = nil

function Start()
    -- IsServerMode() 和 IsClientMode() 是框架提供的全局函数
    if IsServerMode() then
        Module = require("Network.Server")
    else
        Module = require("Network.Client")
    end

    Module.Start()
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end
```

**注意**：这两个函数由框架层面提供，在脚本加载时即可使用，无需额外初始化。

### 1.5 服务器全局变量

服务器端 Lua 脚本启动时，框架会自动注入以下全局变量，可直接访问：

| 变量 | 类型 | 说明 |
|------|------|------|
| `SERVER_MAX_PLAYERS` | int | 最大玩家数（来自 settings.json） |
| `SERVER_TICK_RATE` | int | 服务器 Tick 频率（帧率） |
| `SERVER_MODE` | string | 多人模式（如 `"server_authoritative"`） |
| `SERVER_REGISTERED_PLAYERS` | int | 本局游戏实际玩家数量（见下方说明） |

**使用示例**：

```lua
-- Server.lua
function Start()
    print("[Server] Starting...")
    print("  Max players: " .. SERVER_MAX_PLAYERS)
    print("  Actual players: " .. SERVER_REGISTERED_PLAYERS)
    print("  Tick rate: " .. SERVER_TICK_RATE .. " FPS")
end
```

**注意**：
- 这些变量**仅在服务器端可用**，客户端脚本中不存在
- 变量值在脚本加载时确定，运行期间不会变化

**`SERVER_REGISTERED_PLAYERS` 详解**：

这个变量表示**本局游戏实际参与的玩家数量**，与 `SERVER_MAX_PLAYERS`（最大玩家数）的区别：

| 场景 | `SERVER_MAX_PLAYERS` | `SERVER_REGISTERED_PLAYERS` |
|------|---------------------|----------------------------|
| 快速匹配（8人局，匹配到6人+2个AI） | 8 | 6（实际玩家数） |
| 开房间（最大8人，实际进入5人） | 8 | 5（房间实际人数） |
| 满员开局 | 8 | 8 |

**典型用法**：
```lua
-- 根据实际玩家数初始化（而不是最大玩家数）
for i = 1, SERVER_REGISTERED_PLAYERS do
    -- 为每个真实玩家预分配资源...
end

-- 判断是否需要填充 AI
local aiCount = SERVER_MAX_PLAYERS - SERVER_REGISTERED_PLAYERS
if aiCount > 0 then
    -- 创建 AI 玩家...
end
```

**注意**：`SERVER_REGISTERED_PLAYERS` 是游戏开始时的玩家数量，不是当前在线玩家数。当前在线玩家数需要通过 `network:GetClientConnections()` 获取。

---

## 2. 节点创建模式

### 2.1 模式说明

| 模式 | 常量 | 说明 |
|------|------|------|
| REPLICATED | `REPLICATED` | 节点会同步到所有客户端（**默认值**） |
| LOCAL | `LOCAL` | 节点只存在于当前端，不同步 |

**重要**：`CreateChild()` 和 `CreateComponent()` 的**默认模式是 REPLICATED**！

```lua
-- 这两行是等价的
local node = scene:CreateChild("Node")
local node = scene:CreateChild("Node", REPLICATED)  -- 默认就是 REPLICATED
```

**客户端必须显式指定 LOCAL**，否则会创建 REPLICATED 节点，与服务器冲突！

### 2.2 使用原则

```lua
-- ============================================================================
-- 服务器端创建游戏实体
-- ============================================================================

-- 需要同步的游戏实体：使用 REPLICATED
local entityNode = scene:CreateChild("Player", REPLICATED)
entityNode.position = Vector3(x, y, z)

-- 设置节点变量（会自动同步到客户端）
entityNode:SetVar("EntityType", Variant("player"))
entityNode:SetVar("EntityId", Variant(playerId))
entityNode:SetVar("Color", Variant(Vector3(r, g, b)))

-- 渲染组件：使用 LOCAL（服务器是 Headless，不需要渲染）
-- 注意：服务器端通常不创建 StaticModel，由客户端自行创建
```

```lua
-- ============================================================================
-- 客户端创建本地内容
-- ============================================================================

-- 环境元素：使用 LOCAL（各端独立创建，不需要同步）
local floorNode = scene:CreateChild("Floor", LOCAL)
local model = floorNode:CreateComponent("StaticModel", LOCAL)

-- 光照：使用 LOCAL
local lightNode = scene:CreateChild("Light", LOCAL)
local light = lightNode:CreateComponent("Light", LOCAL)

-- 相机：使用 LOCAL
local cameraNode = scene:CreateChild("Camera", LOCAL)
local camera = cameraNode:CreateComponent("Camera", LOCAL)
```

### 2.3 完整对照表

| 内容类型 | 服务器 | 客户端 | 说明 |
|---------|--------|--------|------|
| 游戏实体节点 | REPLICATED | (自动同步) | 位置自动同步 |
| StaticModel 组件 | 不创建 | LOCAL | 客户端根据节点变量创建 |
| 材质 | 不创建 | LOCAL | 避免材质同步问题 |
| 地面/墙壁 | LOCAL | LOCAL | 环境由各端独立创建 |
| 光照 | 不创建 | LOCAL | 服务器无渲染 |
| 相机 | 不创建 | LOCAL | 只有客户端需要 |
| 音效/粒子 | 不创建 | LOCAL | 通过远程事件通知客户端播放 |

---

## 3. 节点变量同步（Node Vars）

### 3.1 基本用法

节点变量是附加在节点上的键值对数据，会随 REPLICATED 节点自动同步。

```lua
-- ============================================================================
-- 服务器端：设置节点变量
-- ============================================================================

local node = scene:CreateChild("Entity", REPLICATED)

-- 设置各种类型的变量
node:SetVar("EntityType", Variant("enemy"))           -- 字符串
node:SetVar("EntityId", Variant(123))                 -- 整数
node:SetVar("Health", Variant(100.0))                 -- 浮点数
node:SetVar("IsActive", Variant(true))                -- 布尔值
node:SetVar("Color", Variant(Vector3(1.0, 0.5, 0.0))) -- Vector3

-- 更新变量（会自动同步到客户端）
node:SetVar("Health", Variant(80.0))
```

```lua
-- ============================================================================
-- 客户端：读取节点变量
-- ============================================================================

-- 读取变量（需要检查是否为空）
local typeVar = node:GetVar("EntityType")
if typeVar and not typeVar:IsEmpty() then
    local entityType = typeVar:GetString()
end

-- 读取不同类型
local id = node:GetVar("EntityId"):GetInt()
local health = node:GetVar("Health"):GetFloat()
local isActive = node:GetVar("IsActive"):GetBool()
local color = node:GetVar("Color"):GetVector3()
```

### 3.2 推荐：定义变量名常量

在 Shared.lua 中统一定义变量名，避免拼写错误：

```lua
-- Shared.lua
local Shared = {}

Shared.VARS = {
    -- 实体相关
    ENTITY_TYPE = "EntityType",
    ENTITY_ID = "EntityId",

    -- 玩家相关
    PLAYER_ID = "PlayerId",
    PLAYER_NAME = "PlayerName",
    PLAYER_SCORE = "PlayerScore",
    PLAYER_COLOR = "PlayerColor",

    -- 状态相关
    IS_ACTIVE = "IsActive",
    HEALTH = "Health",
}

return Shared
```

```lua
-- 使用示例
local Shared = require("Network.Shared")

-- 服务器
node:SetVar(Shared.VARS.PLAYER_ID, Variant(playerId))

-- 客户端
local playerId = node:GetVar(Shared.VARS.PLAYER_ID):GetInt()
```

### 3.3 支持的 Variant 类型

| Lua 类型 | Variant 构造 | 读取方法 |
|---------|-------------|---------|
| 整数 | `Variant(123)` | `GetInt()` |
| 浮点数 | `Variant(1.5)` | `GetFloat()` |
| 布尔值 | `Variant(true)` | `GetBool()` |
| 字符串 | `Variant("text")` | `GetString()` |
| Vector2 | `Variant(Vector2(x, y))` | `GetVector2()` |
| Vector3 | `Variant(Vector3(x, y, z))` | `GetVector3()` |
| Quaternion | `Variant(Quaternion(...))` | `GetQuaternion()` |
| Color | `Variant(Color(r, g, b, a))` | `GetColor()` |

---

## 4. 远程事件（Remote Events）

### 4.1 事件定义

在 Shared.lua 中统一定义事件名：

```lua
-- Shared.lua
Shared.EVENTS = {
    -- 连接事件
    CLIENT_READY = "ClientReady",           -- 客户端准备就绪
    ASSIGN_PLAYER = "AssignPlayer",         -- 服务器分配玩家

    -- 游戏事件
    PLAYER_DIED = "PlayerDied",             -- 玩家死亡
    PLAYER_SCORED = "PlayerScored",         -- 玩家得分
    GAME_OVER = "GameOver",                 -- 游戏结束

    -- 特效事件（服务器通知客户端播放）
    PLAY_SOUND = "PlaySound",               -- 播放音效
    PLAY_PARTICLE = "PlayParticle",         -- 播放粒子
}
```

### 4.2 事件注册（重要！）

**远程事件必须先注册，才能被对端接收。** 这是一个安全机制，防止未授权的事件被处理。

```lua
-- ============================================================================
-- 注册远程事件（接收方必须调用）
-- ============================================================================

-- 服务器要接收客户端事件，需要在服务器端注册
-- 客户端要接收服务器事件，需要在客户端注册

function Start()
    -- 注册本端需要接收的远程事件
    network:RegisterRemoteEvent(Shared.EVENTS.CLIENT_READY)    -- 服务器接收
    network:RegisterRemoteEvent(Shared.EVENTS.ASSIGN_PLAYER)   -- 客户端接收
    network:RegisterRemoteEvent(Shared.EVENTS.PLAYER_DIED)     -- 客户端接收
    network:RegisterRemoteEvent(Shared.EVENTS.PLAY_SOUND)      -- 客户端接收
    network:RegisterRemoteEvent(Shared.EVENTS.PLAY_PARTICLE)   -- 客户端接收

    -- 然后再订阅事件
    SubscribeToEvent(Shared.EVENTS.ASSIGN_PLAYER, "HandleAssignPlayer")
end
```

**推荐做法**：在 Shared.lua 中提供统一的注册函数：

```lua
-- Shared.lua

-- 服务器需要接收的事件（客户端发送）
Shared.SERVER_EVENTS = {
    Shared.EVENTS.CLIENT_READY,
}

-- 客户端需要接收的事件（服务器发送）
Shared.CLIENT_EVENTS = {
    Shared.EVENTS.ASSIGN_PLAYER,
    Shared.EVENTS.PLAYER_DIED,
    Shared.EVENTS.PLAYER_SCORED,
    Shared.EVENTS.GAME_OVER,
    Shared.EVENTS.PLAY_SOUND,
    Shared.EVENTS.PLAY_PARTICLE,
}

-- 注册服务器端事件
function Shared.RegisterServerEvents()
    for _, eventName in ipairs(Shared.SERVER_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

-- 注册客户端事件
function Shared.RegisterClientEvents()
    for _, eventName in ipairs(Shared.CLIENT_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end
```

```lua
-- Server.lua
function Start()
    Shared.RegisterServerEvents()  -- 注册服务器需要接收的事件
    -- ...
end

-- Client.lua
function Start()
    Shared.RegisterClientEvents()  -- 注册客户端需要接收的事件
    -- ...
end
```

### 4.3 客户端 → 服务器

```lua
-- ============================================================================
-- 客户端发送事件到服务器
-- ============================================================================

local Shared = require("Network.Shared")

-- 获取服务器连接
local serverConnection = network:GetServerConnection()

-- 发送无数据事件
serverConnection:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)

-- 发送带数据事件
local eventData = VariantMap()
eventData["PlayerName"] = Variant("Player1")
eventData["PositionX"] = Variant(100.0)
eventData["PositionZ"] = Variant(200.0)
serverConnection:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true, eventData)
```

### 4.4 服务器 → 单个客户端

```lua
-- ============================================================================
-- 服务器发送事件到特定客户端
-- ============================================================================

-- connection 是该客户端的连接对象
local eventData = VariantMap()
eventData["PlayerId"] = Variant(playerId)
eventData["SpawnX"] = Variant(spawnPos.x)
eventData["SpawnZ"] = Variant(spawnPos.z)

connection:SendRemoteEvent(Shared.EVENTS.ASSIGN_PLAYER, true, eventData)
```

### 4.5 服务器 → 所有客户端（广播）

```lua
-- ============================================================================
-- 服务器广播事件到所有客户端
-- ============================================================================

local eventData = VariantMap()
eventData["Message"] = Variant("Game Started!")

network:BroadcastRemoteEvent(Shared.EVENTS.GAME_START, true, eventData)
```

### 4.6 订阅远程事件

```lua
-- ============================================================================
-- 订阅远程事件
-- ============================================================================

function Start()
    -- 客户端订阅来自服务器的事件
    SubscribeToEvent(Shared.EVENTS.ASSIGN_PLAYER, "HandleAssignPlayer")
    SubscribeToEvent(Shared.EVENTS.PLAYER_DIED, "HandlePlayerDied")
    SubscribeToEvent(Shared.EVENTS.PLAY_SOUND, "HandlePlaySound")
end

function HandleAssignPlayer(eventType, eventData)
    local playerId = eventData["PlayerId"]:GetInt()
    local spawnX = eventData["SpawnX"]:GetFloat()
    local spawnZ = eventData["SpawnZ"]:GetFloat()

    -- 处理玩家分配...
end

function HandlePlaySound(eventType, eventData)
    local soundName = eventData["SoundName"]:GetString()
    -- 播放本地音效...
end
```

---

## 5. 玩家输入同步

### 5.1 Controls 结构

UrhoX 使用 `connection.controls` 在客户端和服务器之间同步玩家输入。

| 字段 | 类型 | 说明 |
|------|------|------|
| `yaw` | float | 水平旋转角度（常用于移动方向） |
| `pitch` | float | 垂直旋转角度 |
| `buttons` | uint | 按钮状态位标志 |

### 5.2 客户端发送输入

```lua
-- ============================================================================
-- 客户端：在 Update 中发送输入
-- ============================================================================

local serverConnection_ = nil
local targetYaw_ = 0.0

function Start()
    serverConnection_ = network:GetServerConnection()
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    if not serverConnection_ then return end

    -- 处理输入，计算目标方向
    if input:GetKeyDown(KEY_A) then
        targetYaw_ = targetYaw_ + 3.0
    end
    if input:GetKeyDown(KEY_D) then
        targetYaw_ = targetYaw_ - 3.0
    end

    -- 发送到服务器
    serverConnection_.controls.yaw = targetYaw_

    -- 如果需要发送按钮状态
    local buttons = 0
    if input:GetKeyDown(KEY_SPACE) then
        buttons = buttons | 1  -- bit 0: 跳跃
    end
    if input:GetKeyDown(KEY_SHIFT) then
        buttons = buttons | 2  -- bit 1: 加速
    end
    serverConnection_.controls.buttons = buttons
end
```

### 5.3 服务器读取输入

```lua
-- ============================================================================
-- 服务器：在 Update 中读取玩家输入
-- ============================================================================

-- 存储所有玩家连接
local playerConnections_ = {}  -- { [connKey] = { connection, playerData, ... } }

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    for connKey, playerInfo in pairs(playerConnections_) do
        local conn = playerInfo.connection
        local playerData = playerInfo.playerData

        -- 读取玩家输入
        local yaw = conn.controls.yaw
        local buttons = conn.controls.buttons

        -- 应用移动
        playerData.targetAngle = math.rad(yaw)

        -- 检查按钮状态
        local isJumping = (buttons & 1) ~= 0
        local isBoosting = (buttons & 2) ~= 0

        -- 更新玩家状态...
    end
end
```

### 5.4 脉冲按键可靠传输（PulseButtonMask）

`controls.buttons` 通过 unreliable 通道发送（UDP/KCP），存在丢包风险。对于**持续状态**按键（如加速），丢一帧没关系，下一帧会补上；但对于**脉冲按键**（如跳跃、技能释放），按下只持续一帧，丢包后服务器永远看不到这次输入。

此外，当服务器帧率较低时，多个客户端帧的输入在同一个服务器 tick 内到达，最后一个覆盖前面的，也会导致脉冲按键丢失。

**解决方案**：使用 `SetPulseButtonMask` 指定哪些 bit 是脉冲按键，引擎会自动通过 reliable 通道传输这些位，并通过排队机制保证每次状态变化至少被服务器游戏逻辑看到一个 tick。

```lua
-- ============================================================================
-- 服务器：在客户端连入后配置脉冲按键掩码
-- ============================================================================

local CTRL = {
    JUMP  = 1,  -- bit 0: 脉冲按键（按一下触发）
    BOOST = 2,  -- bit 1: 持续按键（按住生效）
}

function HandleClientIdentity(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    -- JUMP 走 reliable 保证不丢，BOOST 走 unreliable 零延迟
    connection:SetPulseButtonMask(CTRL.JUMP)
end
```

**工作原理**：

| 按键类型 | 传输通道 | 延迟 | 可靠性 |
|---------|---------|------|--------|
| pulse 位（如 JUMP） | MSG_BUTTON_STATE (reliable+ordered) | 同 tick 多个状态时 +1 tick | 保证送达 |
| 非 pulse 位（如 BOOST） | MSG_CONTROLS (unreliable) | 零额外延迟 | 可能丢包 |

**注意事项**：

- `SetPulseButtonMask` 只需在服务端调用一次，引擎会自动同步给客户端
- 只把**脉冲按键**（按一下触发、持续一帧）放入 mask，不要把持续按键放进去
- WASM 平台使用 WebSocket (TCP)，不存在丢包问题，引擎会自动跳过 pulse 机制

---

## 6. 客户端渲染组件创建

### 6.1 问题：NodeAdded 时 Vars 尚未同步

**这是一个关键的时序问题**：当 `NodeAdded` 事件触发时，节点的 Vars（通过 `SetVar` 设置的变量）**还没有被同步过来**！

```
时序：
1. 服务器创建节点，设置 Vars
2. 客户端收到 NodeAdded 事件    ← 此时 Vars 还未同步！
3. 客户端收到 Vars 同步数据     ← Vars 才可用
```

```lua
-- ❌ 错误：NodeAdded 时直接读取 Vars
function HandleNodeAdded(eventType, eventData)
    local node = eventData["Node"]:GetPtr("Node")
    local typeVar = node:GetVar("EntityType")  -- 返回空！Vars 还没同步
end
```

### 6.2 推荐方案：ScriptObject + DelayedStart

使用 **ScriptObject** 的 `DelayedStart()` 回调，在节点完全初始化（包括 Vars 同步）后自动触发，无需手动维护队列。

**核心原理**：

| 回调 | 触发时机 | Vars 状态 |
|------|---------|----------|
| `Start()` | 组件创建时 | 可能未同步 |
| `DelayedStart()` | 节点完全初始化后 | **已同步** ✅ |

**服务器端**：创建节点时附加 ScriptObject

```lua
-- ============================================================================
-- Server.lua：创建带渲染器的网络实体
-- ============================================================================

function CreatePlayerEntity(playerId, color, spawnPos)
    local node = scene:CreateChild("Player", REPLICATED)
    node.position = spawnPos

    -- 设置 Vars（会同步到客户端）
    node:SetVar("EntityType", Variant("player"))
    node:SetVar("PlayerId", Variant(playerId))
    node:SetVar("Color", Variant(color))

    -- 附加 ScriptObject（会被复制到客户端）
    node:CreateScriptObject("Scripts/EntityRenderer.lua", "EntityRenderer")

    return node
end

function CreateItemEntity(itemType, tier, spawnPos)
    local node = scene:CreateChild("Item", REPLICATED)
    node.position = spawnPos

    node:SetVar("EntityType", Variant("item"))
    node:SetVar("ItemType", Variant(itemType))
    node:SetVar("ItemTier", Variant(tier))

    node:CreateScriptObject("Scripts/EntityRenderer.lua", "EntityRenderer")

    return node
end
```

**EntityRenderer.lua**：客户端自动创建渲染组件

```lua
-- ============================================================================
-- Scripts/EntityRenderer.lua
-- 网络实体的客户端渲染组件
-- ScriptObject 会被复制到客户端，DelayedStart 在 Vars 同步后触发
-- ============================================================================

---@class EntityRenderer : LuaScriptObject
EntityRenderer = ScriptObject()

function EntityRenderer:DelayedStart()
    -- 服务器是 Headless，跳过渲染
    if IsServerMode() then
        return
    end

    -- 此时 Vars 已经同步完成，可以安全读取！
    local node = self.node
    local typeVar = node:GetVar("EntityType")

    if not typeVar or typeVar:IsEmpty() then
        return
    end

    local entityType = typeVar:GetString()

    -- 根据类型创建不同的渲染组件
    if entityType == "player" then
        self:CreatePlayerVisuals()
    elseif entityType == "enemy" then
        self:CreateEnemyVisuals()
    elseif entityType == "item" then
        self:CreateItemVisuals()
    end
end

function EntityRenderer:CreatePlayerVisuals()
    local node = self.node

    -- 读取颜色（Vars 已同步）
    local colorVar = node:GetVar("Color")
    local color = colorVar and not colorVar:IsEmpty()
        and colorVar:GetVector3()
        or Vector3(1, 1, 1)

    -- 创建渲染组件（LOCAL 模式，不同步回服务器）
    local model = node:CreateComponent("StaticModel", LOCAL)
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

    -- 创建材质
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(color.x, color.y, color.z, 1.0)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(color.x * 0.3, color.y * 0.3, color.z * 0.3)))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    mat:SetShaderParameter("Metallic", Variant(0.1))
    model:SetMaterial(mat)
    model.castShadows = true
end

function EntityRenderer:CreateEnemyVisuals()
    local node = self.node

    local model = node:CreateComponent("StaticModel", LOCAL)
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.2, 0.2, 1.0)))
    model:SetMaterial(mat)
    model.castShadows = true
end

function EntityRenderer:CreateItemVisuals()
    local node = self.node

    -- 读取等级决定颜色
    local tierVar = node:GetVar("ItemTier")
    local tier = tierVar and not tierVar:IsEmpty() and tierVar:GetInt() or 1

    local colors = {
        Color(1.0, 0.8, 0.2, 1.0),  -- 等级 1: 金色
        Color(0.2, 0.8, 1.0, 1.0),  -- 等级 2: 蓝色
        Color(1.0, 0.2, 0.8, 1.0),  -- 等级 3: 紫色
    }
    local color = colors[tier] or colors[1]

    local model = node:CreateComponent("StaticModel", LOCAL)
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    node.scale = Vector3(0.5, 0.5, 0.5)  -- 物品小一点

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    model:SetMaterial(mat)
end

-- ⚠️ 注意：如果不需要每帧更新，不要定义 Update 函数！
-- 下面是一个需要动画效果时的示例（按需添加）：
--
-- function EntityRenderer:Update(timeStep)
--     -- 物品旋转动画
--     if self.node:GetVar("EntityType"):GetString() == "item" then
--         self.node:Rotate(Quaternion(0, timeStep * 90, 0))
--     end
-- end
```

### 6.3 机制总结

```
┌─────────────────────────────────────────────────────────────────┐
│  服务器创建节点                                                   │
│  ↓                                                              │
│  设置 Vars + 附加 ScriptObject                                   │
│  ↓                                                              │
│  网络同步到客户端（节点 + Vars + ScriptObject）                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  客户端收到节点数据                                               │
│  ↓                                                              │
│  创建节点 → 同步 Vars → 加载 ScriptObject                        │
│  ↓                                                              │
│  ScriptObject:DelayedStart() 触发（Vars 已就绪）                 │
│  ↓                                                              │
│  创建本地渲染组件（StaticModel 等）                               │
└─────────────────────────────────────────────────────────────────┘
```

**优点**：

| 特性 | ScriptObject 方案 | 队列方案 |
|------|------------------|---------|
| 需要维护队列 | ❌ 不需要 | ✅ 需要 |
| 每帧遍历开销 | ❌ 无 | ✅ 有 |
| 代码复杂度 | 低 | 较高 |
| 时序可靠性 | 引擎保证 | 手动重试 |
| 渲染逻辑位置 | 与实体绑定 | 集中处理 |

### 6.4 ScriptObject 常用回调

```lua
---@class MyScript : LuaScriptObject
MyScript = ScriptObject()

function MyScript:Start()
    -- 组件创建时调用（Vars 可能未同步）
end

function MyScript:DelayedStart()
    -- 节点完全初始化后调用（Vars 已同步）✅ 推荐用于创建渲染组件
end

function MyScript:Update(timeStep)
    -- 每帧调用
end

function MyScript:FixedUpdate(timeStep)
    -- 固定时间步调用（物理更新）
end

function MyScript:Stop()
    -- 组件销毁时调用
end
```

**⚠️ 性能注意**：**不要定义不需要的回调函数！**

引擎会检查 ScriptObject 是否定义了 `Update`、`FixedUpdate` 等回调，如果定义了就会每帧调用。即使函数体为空，也会有调用开销。

```lua
-- ❌ 错误：定义了空的 Update，每帧都会被调用
EntityRenderer = ScriptObject()

function EntityRenderer:DelayedStart()
    self:CreateVisuals()
end

function EntityRenderer:Update(timeStep)
    -- 什么都不做，但仍有调用开销！
end

-- ✅ 正确：只定义需要的回调
EntityRenderer = ScriptObject()

function EntityRenderer:DelayedStart()
    self:CreateVisuals()
end

-- 不需要 Update，就不要定义
```

**原则**：只定义实际需要的回调函数，保持 ScriptObject 精简。

---

## 7. 网络节点生命周期

### 7.1 创建节点

```lua
-- 服务器创建 REPLICATED 节点
local node = scene:CreateChild("Entity", REPLICATED)
node.position = spawnPosition
node:SetVar("EntityId", Variant(entityId))
```

### 7.2 移除节点（重要！）

**必须使用 `Dispose()` 而不是 `Remove()`**：

```lua
-- ============================================================================
-- 正确的节点移除方式
-- ============================================================================

-- ❌ 错误：直接调用 Remove()
-- node:Remove()  -- 客户端可能长时间看不到节点消失

-- ✅ 正确：使用 Dispose()
node:Dispose()

-- ✅ 或封装为工具函数
function RemoveNetworkNode(node)
    if node then
        node:Dispose()
    end
end
```

**原因详解**：

引擎使用引用计数管理节点生命周期。问题在于 Lua 绑定会持有对节点的引用：

```
调用 Remove() 后的时序：
1. Remove() 被调用，节点标记为待删除
2. 但 Lua 变量仍持有对节点的引用 → 引用计数 > 0
3. 节点不会真正删除，客户端不会收到通知
4. 等待 Lua GC 回收该变量...（时机不确定）
5. GC 回收后引用计数归零，节点才真正删除
6. 此时才向客户端发送 Remove 协议
```

**问题**：从调用 `Remove()` 到客户端收到通知，可能延迟数秒甚至更久（取决于 GC 时机）。

**Dispose() 的作用**：

```
调用 Dispose() 后的时序：
1. Dispose() 立即断开 Lua userdata 与 C++ 对象的关联
2. 引用计数立即归零
3. 节点立即从场景中删除
4. 立即向客户端发送 Remove 协议
```

**总结**：
- `Remove()` 依赖 GC，删除时机不可控
- `Dispose()` 立即生效，确保客户端同步

### 7.3 客户端处理节点移除

客户端可以监听 `NodeRemoved` 事件进行清理：

```lua
function Start()
    SubscribeToEvent(scene_, "NodeRemoved", "HandleNodeRemoved")
end

function HandleNodeRemoved(eventType, eventData)
    local node = eventData["Node"]:GetPtr("Node")

    -- 清理本地缓存
    local entityId = node:GetVar(Shared.VARS.ENTITY_ID)
    if entityId and not entityId:IsEmpty() then
        localEntityCache_[entityId:GetInt()] = nil
    end
end
```

---

## 8. SmoothedTransform（位置插值）

### 8.1 工作原理

引擎为所有 REPLICATED 节点自动创建 `SmoothedTransform` 组件，在网络数据包之间平滑插值位置，避免卡顿感。

### 8.2 相机跟随注意事项

**不要在相机跟随代码中添加额外的 lerp 平滑**，否则会导致相机抖动：

**抖动原因详解**：

```
SmoothedTransform 和相机 lerp 的计算方式不同：

帧 1: 物体位置 = 10.0（SmoothedTransform 插值）
      相机位置 = 9.5（lerp 插值）
      相对距离 = 0.5

帧 2: 物体位置 = 10.3（SmoothedTransform 插值）
      相机位置 = 9.8（lerp 插值）
      相对距离 = 0.5

帧 3: 物体位置 = 10.5（SmoothedTransform 插值）
      相机位置 = 10.1（lerp 插值）
      相对距离 = 0.4  ← 相对距离变化了！

问题：两种插值算法的速度/参数不同，导致每帧相机与物体的相对位置都在变化。
表现：相机相对于物体在抖动。
```

```lua
-- ============================================================================
-- 相机跟随实现
-- ============================================================================

local cameraNode_ = nil
local followTarget_ = nil  -- 跟随的目标节点

function HandleUpdate(eventType, eventData)
    if not followTarget_ then return end

    local targetPos = followTarget_.position
    local currentPos = cameraNode_.position

    -- ❌ 错误：额外的 lerp 会导致相机与物体的相对位置每帧都在变化
    -- local smoothSpeed = 5.0
    -- local dt = eventData["TimeStep"]:GetFloat()
    -- local newX = currentPos.x + (targetPos.x - currentPos.x) * smoothSpeed * dt
    -- local newZ = currentPos.z + (targetPos.z - currentPos.z) * smoothSpeed * dt
    -- cameraNode_.position = Vector3(newX, currentPos.y, newZ)

    -- ✅ 正确：直接跟随目标位置，保持相对位置恒定
    cameraNode_.position = Vector3(targetPos.x, currentPos.y, targetPos.z)
end
```

**关键点**：相机直接使用物体的插值后位置，这样相机与物体的相对位置始终恒定，不会抖动。

### 8.3 如果确实需要平滑

如果游戏设计需要额外的相机平滑（如死亡回放），可以临时禁用或调整：

```lua
-- 获取 SmoothedTransform 组件
local smoothed = node:GetComponent("SmoothedTransform")
if smoothed then
    -- 调整平滑参数
    smoothed.smoothingMask = SMOOTH_NONE  -- 禁用平滑
    -- 或
    smoothed.smoothingMask = SMOOTH_POSITION  -- 只平滑位置
end
```

---

## 9. 兴趣管理（Interest Management）

### 9.1 NetworkPriority 组件

`NetworkPriority` 组件用于控制节点的网络更新频率，根据客户端与节点的距离动态调整，减少带宽消耗。

```lua
-- ============================================================================
-- 服务器端：为实体添加优先级组件
-- ============================================================================

local entityNode = scene:CreateChild("Entity", REPLICATED)
entityNode.position = spawnPosition

-- 添加 NetworkPriority 组件
local priority = entityNode:CreateComponent("NetworkPriority", REPLICATED)
priority.basePriority = 100.0       -- 基础优先级（越高越优先更新）
priority.distanceFactor = 0.5       -- 距离因子（距离越远，优先级衰减越多）
priority.minPriority = 0.0          -- 最小优先级（低于此值不更新）
priority.alwaysUpdateOwner = true   -- 始终向拥有者更新（玩家自己的实体）
```

**参数说明**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `basePriority` | float | 基础优先级，默认 100.0 |
| `distanceFactor` | float | 距离衰减因子，优先级 = basePriority - distance * distanceFactor |
| `minPriority` | float | 最小优先级阈值，低于此值不发送更新 |
| `alwaysUpdateOwner` | bool | 是否始终向节点拥有者发送更新 |

**使用场景**：

```lua
-- 玩家实体：高优先级，始终更新给自己
local playerPriority = playerNode:CreateComponent("NetworkPriority", REPLICATED)
playerPriority.basePriority = 200.0
playerPriority.distanceFactor = 0.1
playerPriority.alwaysUpdateOwner = true

-- 远处的 NPC：低优先级，距离远时减少更新
local npcPriority = npcNode:CreateComponent("NetworkPriority", REPLICATED)
npcPriority.basePriority = 50.0
npcPriority.distanceFactor = 1.0
npcPriority.minPriority = 10.0

-- 环境物体：最低优先级
local propPriority = propNode:CreateComponent("NetworkPriority", REPLICATED)
propPriority.basePriority = 20.0
propPriority.distanceFactor = 2.0
propPriority.minPriority = 5.0
```

### 9.2 Observer Position（观察者位置）

客户端可以向服务器报告观察者位置，用于兴趣管理计算。服务器会根据此位置计算与各节点的距离，决定更新优先级。

```lua
-- ============================================================================
-- 客户端：设置观察者位置
-- ============================================================================

local serverConnection_ = nil
local cameraNode_ = nil

function Start()
    serverConnection_ = network:GetServerConnection()
    -- ...
end

function HandleUpdate(eventType, eventData)
    if not serverConnection_ then return end

    -- 上报相机位置作为观察者位置
    serverConnection_.position = cameraNode_.worldPosition

    -- 可选：上报观察者朝向（用于更精细的兴趣管理）
    serverConnection_.rotation = cameraNode_.worldRotation
end
```

**工作原理**：

```
客户端                                服务器
  │                                    │
  │  上报 connection.position          │
  │  ─────────────────────────────→    │
  │                                    │
  │                                    │  计算各节点与观察者的距离
  │                                    │  ↓
  │                                    │  根据 NetworkPriority 决定更新频率
  │                                    │  ↓
  │    ←── 近处节点：高频更新 ───────   │
  │    ←── 远处节点：低频更新 ───────   │
  │                                    │
```

---

## 10. 网络统计与调试

### 10.1 连接统计 API

可以获取连接的网络统计信息，用于显示延迟、监控网络状态等。

```lua
-- ============================================================================
-- 获取连接统计信息
-- ============================================================================

-- 服务器端：获取某个客户端的统计
function GetClientStats(connection)
    return {
        rtt = connection.roundTripTime,      -- 往返时间 (毫秒)
        bytesIn = connection.bytesInPerSec,  -- 入站流量 (字节/秒)
        bytesOut = connection.bytesOutPerSec, -- 出站流量 (字节/秒)
    }
end

-- 客户端：获取到服务器的统计
function GetServerStats()
    local conn = network:GetServerConnection()
    if conn then
        return {
            rtt = conn.roundTripTime,
            bytesIn = conn.bytesInPerSec,
            bytesOut = conn.bytesOutPerSec,
        }
    end
    return nil
end
```

**可用属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `connection.roundTripTime` | float | 往返时间（RTT），单位毫秒 |
| `connection.bytesInPerSec` | float | 入站流量，字节/秒 |
| `connection.bytesOutPerSec` | float | 出站流量，字节/秒 |

**示例：显示玩家延迟**

```lua
-- 服务器端：广播所有玩家的延迟
function BroadcastPlayerPings()
    local pingData = VariantMap()
    local index = 0

    for connKey, playerInfo in pairs(playerConnections_) do
        local conn = playerInfo.connection
        local ping = math.floor(conn.roundTripTime)
        pingData["Player" .. index .. "Id"] = Variant(playerInfo.playerId)
        pingData["Player" .. index .. "Ping"] = Variant(ping)
        index = index + 1
    end
    pingData["PlayerCount"] = Variant(index)

    network:BroadcastRemoteEvent("PlayerPings", true, pingData)
end
```

### 10.2 Ban 机制

服务器可以封禁恶意客户端的 IP 地址。

```lua
-- ============================================================================
-- 封禁客户端
-- ============================================================================

-- 封禁特定连接的 IP
function BanPlayer(connection)
    if connection then
        connection:Ban()
        print("[Server] Banned: " .. connection:GetAddress())
    end
end

-- 在检测到作弊时封禁
function HandleCheatDetected(connection, reason)
    print("[Server] Cheat detected: " .. reason)
    BanPlayer(connection)
end
```

**注意**：
- `Ban()` 会封禁该连接的 IP 地址
- 封禁列表在服务器重启后会清空
- 封禁后该 IP 的后续连接请求会被拒绝

---

## 11. 连接管理

### 11.1 场景关联的时序问题（重要！）

**核心问题**：服务器设置 `connection.scene` 会立即触发场景同步，但如果此时客户端还没准备好（没有设置 `serverConnection.scene`），客户端会报错：

```
ERROR: Can not handle LoadScene message without an assigned scene
```

**错误的做法**：

```
服务器                                     客户端
  │                                          │
  │  ←───── ClientConnected 事件 ─────────   │
  │                                          │
  │  connection.scene = scene_  ❌ 太早了！   │
  │                                          │
  │  ─────── LoadScene 消息 ──────────────→  │  ❌ 客户端 scene 还是空的！
  │                                          │  💥 报错：Can not handle LoadScene...
```

**正确的时序**：

```
服务器                                     客户端
  │                                          │
  │  ←───── ClientConnected 事件 ─────────   │
  │                                          │
  │  （不设置 scene，等待客户端准备好）        │  serverConnection.scene = scene_  ✅
  │                                          │
  │  ←───── ClientReady 远程事件 ─────────   │  发送 ClientReady 事件
  │                                          │
  │  connection.scene = scene_  ✅ 现在安全了 │
  │                                          │
  │  ─────── LoadScene 消息 ──────────────→  │  ✅ 客户端已准备好接收
```

**规则**：
1. **客户端**先设置 `serverConnection.scene = scene_`
2. **客户端**发送 `ClientReady` 事件通知服务器
3. **服务器**收到 `ClientReady` 后才设置 `connection.scene = scene_`

### 11.2 Scene 是网络同步的必要媒介（重要！）

**即使是不需要 3D 场景的游戏（如纯 2D 游戏、卡牌游戏等），也必须创建一个 Scene 对象**。

UrhoX 的网络同步机制基于 Scene，`connection.scene` 必须设置一个有效的 Scene 对象，否则：
- 无法同步 REPLICATED 节点
- 无法接收/发送场景相关的网络消息
- 会报错 `Can not handle LoadScene message without an assigned scene`

**解决方案**：创建一个空的 Scene 作为同步媒介：

```lua
-- ============================================================================
-- 即使不需要渲染场景，也要创建 Scene 用于网络同步
-- ============================================================================

local scene_ = nil

function Start()
    -- 创建空场景（仅用于网络同步）
    scene_ = Scene()

    -- 如果需要网络功能，必须注册 Network 子系统
    scene_:CreateComponent("Octree")  -- 可选，如果有任何渲染需求

    -- 后续设置 connection.scene = scene_ ...
end
```

**常见场景**：

| 游戏类型 | 是否需要 Scene | 说明 |
|---------|---------------|------|
| 3D 游戏 | ✅ 需要 | 场景用于渲染和网络同步 |
| 2D 游戏（Sprite2D） | ✅ 需要 | 场景用于渲染 2D 精灵和网络同步 |
| 纯 NanoVG 2D 游戏 | ✅ 需要 | **虽然不渲染场景，但网络同步仍需要 Scene** |
| 卡牌/棋盘游戏 | ✅ 需要 | 同上 |

**记住**：Scene 是网络同步的基础设施，不是可选的！

### 11.3 服务器端连接处理

```lua
-- ============================================================================
-- 服务器：处理客户端连接
-- ============================================================================

local playerConnections_ = {}

function Start()
    Shared.RegisterServerEvents()  -- 注册 ClientReady 等事件

    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent(Shared.EVENTS.CLIENT_READY, "HandleClientReady")  -- ⚠️ 关键！
end

function HandleClientConnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = GetConnectionKey(connection)

    -- ⚠️ 不要在这里设置 connection.scene！
    -- 只做基本的连接记录，等待客户端准备好
    playerConnections_[connKey] = {
        connection = connection,
        playerId = GeneratePlayerId(),
        playerData = nil,  -- 稍后创建
    }

    print("[Server] Client connected: " .. connKey)
end

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = GetConnectionKey(connection)

    local playerInfo = playerConnections_[connKey]
    if not playerInfo then return end

    -- ✅ 客户端已准备好，现在才设置场景（触发全量同步）
    connection.scene = scene_

    print("[Server] Client ready, scene assigned: " .. connKey)

    -- 现在可以安全地创建玩家实体、发送初始数据等...
    -- CreatePlayerForConnection(connection, playerInfo)
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = GetConnectionKey(connection)

    local playerInfo = playerConnections_[connKey]
    if playerInfo then
        -- 清理玩家数据
        if playerInfo.playerNode then
            playerInfo.playerNode:Dispose()
        end
        playerConnections_[connKey] = nil
    end

    print("[Server] Client disconnected: " .. connKey)
end

-- 生成连接唯一键
function GetConnectionKey(connection)
    if connection then
        return tostring(connection:GetAddress()) .. ":" .. tostring(connection:GetPort())
    end
    return nil
end
```

**`connection.scene = scene_` 的作用**：

这行代码将场景关联到客户端连接，触发以下行为：

```
1. 关联场景
   connection.scene = scene_
   ↓
2. 全量同步（首次）
   服务器刷新该连接的状态同步缓存，将当前场景中所有 REPLICATED 节点
   的完整状态（位置、旋转、缩放、Vars 等）一次性发送给该客户端
   ↓
3. 差异同步（后续）
   之后只同步发生变化的部分（增量更新），节省带宽
```

**注意**：
- 如果不设置 `connection.scene`，客户端将收不到任何场景数据
- **必须等待客户端准备好后再设置**，否则客户端会报错
- 设置后立即触发全量同步

### 11.4 客户端连接处理

**重要**：客户端必须先设置 `serverConnection.scene`，然后发送 `ClientReady` 事件！

#### 正常模式（默认）

框架层面保证：**客户端脚本加载时，服务器连接一定已经建立**。

```lua
-- ============================================================================
-- 正常模式：脚本加载时已连接
-- ============================================================================

local serverConnection_ = nil

function Start()
    Shared.RegisterClientEvents()  -- 注册客户端需要接收的事件

    -- 框架保证此时已连接，直接获取即可
    serverConnection_ = network:GetServerConnection()

    -- ⚠️ 关键步骤 1：先设置场景（告诉引擎把收到的数据应用到哪个场景）
    serverConnection_.scene = scene_

    -- ⚠️ 关键步骤 2：通知服务器"我准备好了"
    serverConnection_:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)

    -- 订阅其他事件
    SubscribeToEvent(Shared.EVENTS.ASSIGN_PLAYER, "HandleAssignPlayer")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
end

function HandleServerDisconnected(eventType, eventData)
    serverConnection_ = nil
    -- 显示断线提示
end
```

**客户端初始化顺序**（必须按此顺序）：
1. `Shared.RegisterClientEvents()` - 注册需要接收的远程事件
2. `serverConnection_.scene = scene_` - 设置场景，准备接收同步数据
3. `SendRemoteEvent(CLIENT_READY)` - 通知服务器可以开始同步了
4. 订阅其他事件处理函数

#### 后台匹配模式（Background Match）

如果在 TapCode 上配置了**后台匹配机制**，情况不同：

- 客户端脚本加载时，服务器连接**可能还不存在**
- 需要订阅 `ServerReady` 事件等待服务器就绪
- 收到该事件表示：服务器已连接 + 服务器脚本已加载完成

**ServerReady 事件说明**：

| 事件名 | 触发时机 | 说明 |
|--------|---------|------|
| `ServerReady` | 后台匹配模式下服务器就绪 | 仅在后台匹配模式下触发，正常模式不会触发 |

**注意**：`ServerReady` 事件目前没有携带任何数据字段，仅作为信号使用。

```lua
-- ============================================================================
-- 后台匹配模式：需要等待 ServerReady 事件
-- ============================================================================

local serverConnection_ = nil
local isBackgroundMatch_ = true  -- 根据配置判断

function Start()
    Shared.RegisterClientEvents()  -- 注册客户端需要接收的事件

    if isBackgroundMatch_ then
        -- 后台匹配模式：脚本加载时服务器可能未就绪
        -- 此时 network:GetServerConnection() 可能返回 nil！
        SubscribeToEvent("ServerReady", "HandleServerReady")
    else
        -- 正常模式：直接获取
        serverConnection_ = network:GetServerConnection()
        OnServerReady()
    end

    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
end

function HandleServerReady(eventType, eventData)
    -- 服务器已连接且脚本已加载，现在可以安全获取连接
    serverConnection_ = network:GetServerConnection()
    OnServerReady()
end

function OnServerReady()
    -- ⚠️ 关键步骤 1：先设置场景
    serverConnection_.scene = scene_

    -- ⚠️ 关键步骤 2：通知服务器"我准备好了"
    serverConnection_:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)
end

function HandleServerDisconnected(eventType, eventData)
    serverConnection_ = nil
    -- 显示断线提示
end
```

**两种模式对比**：

| 模式 | 脚本加载时连接状态 | 获取连接方式 |
|------|-------------------|-------------|
| 正常模式 | 一定已连接 | `Start()` 中直接获取 |
| 后台匹配模式 | 可能未连接 | 等待 `ServerReady` 事件后获取 |

**两种模式的共同点**：都需要先设置 `serverConnection_.scene`，再发送 `ClientReady` 事件！

#### 常驻服模式（Persistent World）

如果在 TapCode 上配置了**常驻服**（`persistent_world`），服务器实例会持续运行，玩家可以**随时加入、随时离开**，不影响游戏继续运行。

**典型适用场景**：

| 场景 | 说明 |
|------|------|
| 沙盒创造（Minecraft 风格） | 玩家随时加入世界建造，离开后世界继续存在 |
| 大厅社交 | 公共聊天室、展厅，玩家自由进出 |
| 休闲对战（IO 游戏风格） | 随时加入、随时离开，不影响其他人 |
| 持久世界 MMO-Lite | 小型常驻世界，玩家可随时连入 |

**与普通匹配模式的核心区别**：

| | 普通匹配模式 | 常驻服 |
|---|---|---|
| **开局方式** | 凑齐 N 人后统一开局 | 服务器先启动，玩家随时加入 |
| **中途加入** | ❌ 不支持 | ✅ 支持 |
| **玩家离开** | 游戏可能因人数不足结束 | 游戏继续运行 |
| **服务器生命周期** | 一局结束即销毁 | 持续运行，直到所有人离开后空闲超时 |
| **房间发现** | 匹配系统自动分配 | 自动查找可加入的房间 |

**客户端连接流程**（Lobby 自动处理，游戏脚本无需关心）：

```
客户端启动
  ↓
Lobby 加载 → 发现 persistent_world 已启用
  ↓
查询可加入的房间
  ├─ 找到房间 → 加入该房间
  └─ 未找到   → 创建新房间
  ↓
等待 Lobby 服务器分配游戏服务器
  ↓
收到 NotifyGameStart → 连接游戏服务器
  ↓
等待 ServerReady → 切换到游戏脚本
```

无论是第一个进入（创建新房间）还是后续加入（加入已有房间），游戏脚本看到的初始化流程完全一致。

**服务器全局变量**：

| 变量 | 类型 | 说明 |
|------|------|------|
| `PERSISTENT_WORLD_KEY` | string | 当前常驻服的房间标识（非空表示本局为常驻服） |

**与普通匹配模式的关键编码差异**：

| 要点 | 普通匹配 | 常驻服 |
|------|---------|--------|
| 玩家加入时 | 只在开局时处理 | 任何时刻都可能有新玩家加入 |
| 获取在线人数 | `SERVER_REGISTERED_PLAYERS` | `network:GetClientConnections()` 实时查询 |
| 客户端代码 | — | 与普通匹配完全一致，无需特殊处理 |

**服务器生命周期**：

```
服务器启动
  ↓
游戏世界初始化 → 等待玩家加入
  ↓
玩家随时加入/离开，游戏持续运行
  ↓
最后一个玩家离开 → 开始空闲计时器
  ├─ 新玩家在超时前加入 → 重置计时器，继续运行
  └─ 超时无人加入 → 服务器自动关闭
```

空闲超时由引擎自动管理，游戏脚本无需关心。

**注意事项**：

- **不能与后台匹配同时使用**：`persistent_world` 和 `background_match` 互斥，同时启用时 `persistent_world` 优先
- **初始化不能依赖玩家数量**：`Start()` 时可能没有任何玩家连接
- **不要使用 `SERVER_REGISTERED_PLAYERS`**：该值是脚本启动时的快照，中途加入的玩家不会更新它。使用 `network:GetClientConnections()` 获取实时在线人数
- **玩家数据持久化需自行处理**：玩家离开后再加入，属于新连接，服务器不会自动恢复之前的状态。如需保留玩家进度，使用云变量（serverCloud）存储


### 11.5 断线重连

断线重连涉及两侧职责：客户端读取连接 identity 上的 `is_reconnect` 标记；服务端按认证后的 `user_id` 恢复断线前的玩家数据。重连状态不要在 `ClientConnected` 中判断；`user_id` 需等 `ClientIdentity` 后才可用，场景恢复需等 `ClientReady`。

#### 11.5.1 客户端重连标记（is_reconnect）

客户端脚本的 `Start()` 在**首次进入**和**断线重连恢复**时都会被调用。Lobby 在连接成功后把本次连接是否为重连写入服务器连接的 identity，项目脚本可直接读取：

| 变量 | 首次进入 | 断线重连 |
|---|---|---|
| `serverConnection:GetIdentity():GetBool("is_reconnect")` | `false` | `true` |

```lua
local function IsReconnect()
    local network = GetNetwork()
    local serverConnection = network and network:GetServerConnection()
    if not serverConnection then
        return false
    end

    return serverConnection:GetIdentity():GetBool("is_reconnect")
end

function Start()
    if IsReconnect() then
        -- 断线重连：恢复上次状态，跳过开场动画
        RestorePlayerState()
    else
        -- 首次进入：走完整初始化流程
        InitFreshGame()
    end
end
```

**触发条件**：客户端非主动返回大厅地断开连接，Lobby 查询到可重连会话并成功重新连接游戏服后，该值为 `true`。主动返回大厅、无可重连会话、或游戏局已结束时，该值为 `false`。

**注意**：`is_reconnect` 是客户端连接 identity 上的标记，服务端脚本不要依赖客户端全局函数。

#### 11.5.2 服务端状态恢复模式

Lobby 自动重连成功后，服务端需要识别"这个新连接属于之前的哪个玩家"。不要用 `connKey`（地址:端口）做身份匹配：重连时端口可能变化，应使用认证后的 `user_id` 建立映射。

推荐结构是三张表加两阶段恢复。先定义状态表，再在连接事件中使用它们：

```lua
-- connKey -> userId：在 ClientIdentity 时记录，供断线时反查
local connKeyToUserId_     = {}  -- connKey → userId（趁 ClientIdentity 时预存）

-- userId -> playerInfo：旧连接断开后暂存，不立即销毁玩家节点
local disconnectedPlayers_ = {}  -- userId  → playerInfo（断线时暂存，不销毁节点）

-- connKey -> userId：新连接已识别为重连，等待 ClientReady 后恢复
local pendingReconnect_    = {}  -- connKey → userId（标记新连接需要恢复）
```

**推荐时序**：

```
ClientIdentity（identity 可用）
  ├─ 记录 connKeyToUserId_[connKey] = userId
  └─ 如果 disconnectedPlayers_[userId] 存在
      → 标记 pendingReconnect_[connKey] = userId

ClientDisconnected（旧连接断开）
  └─ 用 connKeyToUserId_[connKey] 取 userId（不依赖此时可能已失效的 identity）
  └─ 暂存 disconnectedPlayers_[userId] = playerInfo（不 Dispose 玩家节点）

ClientReady（客户端已完成本地 scene 绑定）
  └─ 检查 pendingReconnect_[connKey]
      → 恢复玩家（重新绑定 connection，设置 connection.scene）
```

恢复逻辑以 `userId` 为唯一身份键；`connKey` 只用于当前连接的事件反查，不作为玩家身份。

恢复动作放在 `ClientReady` 阶段，是为了与上文的 scene 绑定时序保持一致：客户端先设置 `serverConnection.scene` 并发送 `ClientReady`，服务端再设置 `connection.scene`。

---

### 11.6 获取玩家昵称

使用全局函数 `GetUserNickname` 批量查询玩家昵称。该接口**服务端和客户端通用**，内部自动切换实现：

> **⚠️ 服务端时序要求**：`user_id` 在 `ClientIdentity` 事件中才可用（客户端发送认证消息之后）。在 `ClientConnected` 事件中 identity 尚未建立，**不能**获取 `user_id`。

#### 基本用法

```lua
GetUserNickname({
    userIds = { 12345, 67890 },  -- 支持 number 或 string
    onSuccess = function(nicknames)
        for _, info in ipairs(nicknames) do
            print(string.format("用户 %s 的昵称: %s", tostring(info.userId), info.nickname))
        end
    end,
    onError = function(errorCode)
        print("查询失败, errorCode=" .. tostring(errorCode))
    end
})
```

#### 参数说明

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `userIds` | `table` | 是 | 用户 ID 列表，支持 number 或 string |
| `onSuccess` | `function(nicknames)` | 否 | 成功回调，`nicknames` 为数组，每个元素包含 `userId`(number) 和 `nickname`(string) |
| `onError` | `function(errorCode)` | 否 | 失败回调，errorCode: -1=内部错误, -2=超时 |

#### 服务端示例

服务端必须在 `ClientIdentity` 事件中获取 `user_id`，此时客户端已发送认证消息：

```lua
-- 订阅事件
SubscribeToEvent("ClientIdentity", "OnClientIdentity")

-- ClientIdentity 事件：客户端认证完成，user_id 可用
function OnClientIdentity(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local identity = connection.identity  -- 从 Connection 对象获取，不是从 eventData
    local userId = identity["user_id"]:GetInt64()

    -- 查询昵称（服务端从 SERVER_PLAYER_AUTH_INFOS 同步读取，无需网络请求）
    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            local nick = nicknames[1].nickname
            print(string.format("[服务器] 玩家 %d 昵称: %s", userId, nick))
        end
    })
end
```

>
> **⚠️ 不要在 `ClientConnected` 中获取 `user_id`**：此时客户端刚建立 TCP 连接，尚未发送认证消息，identity 为空。
>
> **时序**：`ClientConnected` → `ClientIdentity`（user_id 可用）→ `ClientReady`（自定义远程事件）

#### 客户端示例

```lua
-- 在客户端脚本中查询排行榜玩家昵称
local leaderboardUserIds = { 10001, 10002, 10003 }
GetUserNickname({
    userIds = leaderboardUserIds,
    onSuccess = function(nicknames)
        for _, info in ipairs(nicknames) do
            -- 更新 UI 显示
            print(info.userId .. ": " .. info.nickname)
        end
    end,
    onError = function(errorCode)
        print("昵称查询失败: " .. tostring(errorCode))
    end
})
```







#### 实现差异

| | 服务端 | 客户端 |
|---|---|---|
| **数据来源** | `SERVER_PLAYER_AUTH_INFOS` 全局表 | Lobby 服务器批量查询 |
| **同步/异步** | 同步（回调立即执行） | 异步（通过网络请求） |
| **适用范围** | 仅配置中注册的玩家 | 任意用户 |

> **注意**：昵称由 TapTap 账号系统管理。排行榜数据本身不包含昵称，需要通过此接口单独查询。

---

## 12. 常见问题与解决方案

### 12.1 `Can not handle LoadScene message without an assigned scene`

**错误信息**：
```
ERROR: Can not handle LoadScene message without an assigned scene
```

**原因**：服务器发送场景数据时，客户端还没有设置 `serverConnection.scene`。

**解决方案**：确保正确的初始化时序：

1. **客户端**先设置场景：
   ```lua
   serverConnection_.scene = scene_
   ```

2. **客户端**发送准备就绪事件：
   ```lua
   serverConnection_:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)
   ```

3. **服务器**在收到 `ClientReady` 事件后才设置场景：
   ```lua
   function HandleClientReady(eventType, eventData)
       local connection = eventData["Connection"]:GetPtr("Connection")
       connection.scene = scene_  -- 现在才设置！
   end
   ```

**关键**：服务器不要在 `ClientConnected` 事件中立即设置 `connection.scene`！

详见：[11.1 场景关联的时序问题](#111-场景关联的时序问题重要)

---

### 12.2 客户端看不到服务器创建的实体

**检查清单**：

1. 是否遵循了正确的初始化时序？（见 12.1）

2. 服务器是否在 `HandleClientReady` 中设置了 `connection.scene`？
   ```lua
   -- 服务器端，在 HandleClientReady 事件中（不是 ClientConnected！）
   connection.scene = scene_
   ```

2. 服务器创建节点时是否附加了 ScriptObject？
   ```lua
   node:CreateScriptObject("Scripts/EntityRenderer.lua", "EntityRenderer")
   ```

3. 节点是否设置了用于识别的变量？
   ```lua
   node:SetVar("EntityType", Variant("player"))
   ```

4. 客户端是否错误地使用了默认模式创建节点？
   ```lua
   -- ❌ 客户端错误：默认是 REPLICATED，会与服务器冲突！
   local node = scene:CreateChild("MyNode")

   -- ✅ 客户端正确：必须显式指定 LOCAL
   local node = scene:CreateChild("MyNode", LOCAL)
   ```

### 12.3 客户端创建的节点与服务器冲突

**重要**：`CreateChild()` 的默认模式是 `REPLICATED`，不是 `LOCAL`！

**问题**：客户端如果不指定模式创建节点，会创建 REPLICATED 节点，导致与服务器的节点 ID 冲突或数据混乱。

```lua
-- ============================================================================
-- 客户端创建节点必须显式指定 LOCAL
-- ============================================================================

-- ❌ 错误：默认是 REPLICATED，客户端不应创建 REPLICATED 节点
local cameraNode = scene:CreateChild("Camera")
local floorNode = scene:CreateChild("Floor")

-- ✅ 正确：客户端创建的所有节点都应该是 LOCAL
local cameraNode = scene:CreateChild("Camera", LOCAL)
local floorNode = scene:CreateChild("Floor", LOCAL)

-- ✅ 正确：组件也应该是 LOCAL
local model = node:CreateComponent("StaticModel", LOCAL)
local light = node:CreateComponent("Light", LOCAL)
```

**规则**：
- **服务器**：游戏实体用 `REPLICATED`（或默认），环境用 `LOCAL`
- **客户端**：**所有节点和组件都必须用 `LOCAL`**

### 12.4 实体移动时抖动

**原因**：相机跟随代码中有额外的 lerp 平滑，与引擎的 SmoothedTransform 冲突。

**解决方案**：移除相机跟随中的额外平滑，直接跟随目标位置。

```lua
-- ❌ 抖动代码
local newX = currentPos.x + (targetPos.x - currentPos.x) * smoothSpeed * dt

-- ✅ 正确代码
cameraNode_.position = Vector3(targetPos.x, currentPos.y, targetPos.z)
```

### 12.5 节点删除后客户端还能看到

**原因**：使用了 `Remove()` 而不是 `Dispose()`。

**解决方案**：

```lua
-- ❌ 错误
node:Remove()

-- ✅ 正确
node:Dispose()
```

### 12.6 音效没有播放

**原因**：服务器是 Headless 模式，无法播放音效。

**解决方案**：服务器发送远程事件，客户端本地播放。

```lua
-- 服务器
local eventData = VariantMap()
eventData["SoundName"] = Variant("explosion.wav")
eventData["Position"] = Variant(position)
connection:SendRemoteEvent("PlaySound", true, eventData)

-- 客户端
function HandlePlaySound(eventType, eventData)
    local soundName = eventData["SoundName"]:GetString()
    local position = eventData["Position"]:GetVector3()

    -- 播放 3D 音效
    local soundNode = scene_:CreateChild("Sound", LOCAL)
    soundNode.position = position
    local soundSource = soundNode:CreateComponent("SoundSource3D", LOCAL)
    soundSource:Play(cache:GetResource("Sound", "Sounds/" .. soundName))
    soundSource.autoRemoveMode = REMOVE_NODE
end
```

### 12.7 粒子特效不显示

**解决方案**：与音效相同，服务器发送事件，客户端本地创建。

```lua
-- 服务器
local eventData = VariantMap()
eventData["EffectName"] = Variant("Explosion.xml")
eventData["Position"] = Variant(position)
network:BroadcastRemoteEvent("PlayParticle", true, eventData)

-- 客户端
function HandlePlayParticle(eventType, eventData)
    local effectName = eventData["EffectName"]:GetString()
    local position = eventData["Position"]:GetVector3()

    local effectNode = scene_:CreateChild("Effect", LOCAL)
    effectNode.position = position
    local emitter = effectNode:CreateComponent("ParticleEmitter", LOCAL)
    emitter.effect = cache:GetResource("ParticleEffect", "Particle/" .. effectName)
    emitter.autoRemoveMode = REMOVE_NODE
end
```

### 12.8 远程事件数据为空

**检查**：确保使用 `Variant()` 包装数据。

```lua
-- ❌ 错误
eventData["Value"] = 123

-- ✅ 正确
eventData["Value"] = Variant(123)
```

### 12.9 GetVar 返回空值

**检查**：使用前先检查是否为空。

```lua
local var = node:GetVar("SomeVar")
if var and not var:IsEmpty() then
    local value = var:GetInt()
end
```

### 12.10 远程事件收不到

**原因**：接收方没有调用 `RegisterRemoteEvent` 注册事件。

**解决方案**：

```lua
-- 接收方必须先注册事件
function Start()
    -- 1. 注册事件（必须！）
    network:RegisterRemoteEvent("MyEvent")

    -- 2. 然后订阅
    SubscribeToEvent("MyEvent", "HandleMyEvent")
end
```

**检查清单**：
1. 服务器接收客户端事件 → 服务器端调用 `RegisterRemoteEvent`
2. 客户端接收服务器事件 → 客户端调用 `RegisterRemoteEvent`
3. 事件名拼写是否一致

### 12.11 NodeAdded 中 GetVar 返回空值

**原因**：`NodeAdded` 事件触发时，节点的 Vars **尚未同步**，此时调用 `GetVar` 会返回空值。

**解决方案**：使用 ScriptObject 的 `DelayedStart()` 回调（详见第 6 节）。

```lua
-- ❌ 错误：NodeAdded 中直接读取 Vars
function HandleNodeAdded(eventType, eventData)
    local node = eventData["Node"]:GetPtr("Node")
    local type = node:GetVar("EntityType"):GetString()  -- 返回空！
end

-- ✅ 正确：使用 ScriptObject，在 DelayedStart 中处理
-- 服务器端创建节点时附加 ScriptObject
node:CreateScriptObject("Scripts/EntityRenderer.lua", "EntityRenderer")

-- EntityRenderer.lua
EntityRenderer = ScriptObject()

function EntityRenderer:DelayedStart()
    -- 此时 Vars 已同步，可以安全读取
    local entityType = self.node:GetVar("EntityType"):GetString()
    -- 创建渲染组件...
end
```

---

## 附录 A：完整示例代码结构

### Shared.lua

```lua
local Shared = {}

-- 网络配置
Shared.CONFIG = {
    SERVER_PORT = 2345,
    SERVER_NAME = "Game Server",
}

-- 事件名
Shared.EVENTS = {
    CLIENT_READY = "ClientReady",
    ASSIGN_PLAYER = "AssignPlayer",
    PLAYER_DIED = "PlayerDied",
    PLAY_SOUND = "PlaySound",
    PLAY_PARTICLE = "PlayParticle",
}

-- 服务器需要接收的事件（客户端发送）
Shared.SERVER_EVENTS = {
    Shared.EVENTS.CLIENT_READY,
}

-- 客户端需要接收的事件（服务器发送）
Shared.CLIENT_EVENTS = {
    Shared.EVENTS.ASSIGN_PLAYER,
    Shared.EVENTS.PLAYER_DIED,
    Shared.EVENTS.PLAY_SOUND,
    Shared.EVENTS.PLAY_PARTICLE,
}

-- 节点变量名
Shared.VARS = {
    ENTITY_TYPE = "EntityType",
    ENTITY_ID = "EntityId",
    PLAYER_ID = "PlayerId",
    PLAYER_NAME = "PlayerName",
    PLAYER_COLOR = "PlayerColor",
}

-- 注册服务器端事件（服务器调用）
function Shared.RegisterServerEvents()
    for _, eventName in ipairs(Shared.SERVER_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

-- 注册客户端事件（客户端调用）
function Shared.RegisterClientEvents()
    for _, eventName in ipairs(Shared.CLIENT_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

-- 工具函数：获取连接唯一键
function Shared.GetConnectionKey(connection)
    if connection then
        return tostring(connection:GetAddress()) .. ":" .. tostring(connection:GetPort())
    end
    return nil
end

-- 工具函数：安全移除网络节点
function Shared.RemoveNetworkNode(node)
    if node then
        node:Dispose()
    end
end

return Shared
```

---

## 13. 返回大厅（ReturnToLobby）

### 13.1 概述

当玩家需要从游戏中退出回到大厅（例如死亡后选择退出、观战模式退出、胜利结算后退出），客户端脚本通过发送 **本地事件** `ReturnToLobby` 通知引擎大厅处理。

**关键**：`ReturnToLobby` 是 **本地事件**（`SendEvent`），不是远程事件（`SendRemoteEvent`）。引擎大厅会自动监听并处理后续所有流程。

### 13.2 使用方式

```lua
-- 在任何需要返回大厅的地方调用（死亡退出、观战退出、胜利结算等）
SendEvent("ReturnToLobby", VariantMap())
```

**典型触发场景**：

| 场景 | 说明 |
|------|------|
| 死亡选择界面 | 玩家死亡后点击"退出"按钮 |
| 观战模式 | 观战界面点击"返回大厅"按钮 |
| 胜利/结算界面 | 游戏结束后点击"返回"按钮 |

### 13.3 引擎大厅自动处理的事项

游戏脚本只需发送一个事件，以下流程由引擎大厅自动完成：

1. **通知服务器**：自动向服务器发送离开事件
2. **断开连接**：自动断开与游戏服务器的网络连接（不会触发意外重连）
3. **卸载游戏脚本**：当前游戏脚本被卸载
4. **恢复大厅界面**：重新显示大厅 UI（普通模式）或自动开始下一局匹配（后台匹配模式）

### 13.4 两种模式的行为差异

| | 普通模式 | 后台匹配模式 |
|---|---|---|
| **用户体验** | 返回大厅界面，手动重新匹配 | 无缝重开，直接进入下一局 |
| **玩家看到的提示** | "正在返回大厅..." | "正在重新开始..." |

### 13.5 注意事项

- **不需要手动断开连接**：引擎大厅会处理网络断开和脚本切换，游戏脚本只需发送事件
- **不需要注册远程事件**：`ReturnToLobby` 是本地事件（`SendEvent`），不走网络
- **不会触发意外重连**：引擎大厅会区分主动返回和意外断线，`ReturnToLobby` 触发的断线不会导致自动重连
- **过渡状态**：建议设置一个标志位（如 `returningToLobby_`）显示过渡提示，避免玩家在等待期间重复点击

---

*最后更新: 2026-06-17*
