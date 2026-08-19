# Minecraft 联网版迁移方案

## 1. 现有架构分析

### 1.1 当前代码结构

```
scripts/
├── main.lua                    # 入口文件（单机）
├── config/
│   ├── GameConfig.lua          # 游戏配置 ✅ 无需修改
│   └── GameEvents.lua          # 本地事件定义 ✅ 无需修改
├── player/
│   ├── Player.lua              # 玩家状态
│   ├── PlayerController.lua    # 移动/碰撞 ✅ 无需修改（服务器复用）
│   ├── BlockInteraction.lua    # 方块交互 ✅ 无需修改
│   ├── CameraController.lua    # 相机控制 ⚠️ 需要 LOCAL 模式
│   ├── FirstPersonArm.lua      # 第一人称手臂 ⚠️ 需要 LOCAL 模式
│   └── PlayerBody.lua          # 第三人称身体 ⚠️ 特殊处理
├── world/
│   ├── World.lua               # 方块数据存储 ✅ 无需修改
│   ├── WorldGenerator.lua      # 世界生成 ✅ 无需修改
│   ├── ChunkMeshBuilder.lua    # 区块渲染 ⚠️ 需要 LOCAL 模式
│   └── DayNightCycle.lua       # 昼夜循环 ⚠️ 需要 LOCAL 模式
├── rendering/
│   ├── TextureAtlas.lua        # 纹理图集 ✅ 无需修改
│   └── ParticleSystem.lua      # 粒子系统 ⚠️ 需要 LOCAL 模式
├── terrain/
│   ├── BiomeGenerator.lua      # 生物群系 ✅ 无需修改
│   ├── NoiseGenerator.lua      # 噪声工具 ✅ 无需修改
│   ├── TreeDecorator.lua       # 树木生成 ✅ 无需修改
│   ├── HouseGenerator.lua      # 房屋生成 ✅ 无需修改
│   └── TorchDecorator.lua      # 火把装饰 ⚠️ 需要改造
├── devtools/
│   └── Benchmark.lua           # 性能测试 ✅ 无需修改
└── ui/
    ├── UIManager.lua           # UI管理 ✅ 无需修改
    ├── Hotbar.lua              # 物品栏 ✅ 无需修改
    └── DebugOverlay.lua        # 调试面板 ✅ 无需修改
```

**图例**: ✅ 无需修改 | ⚠️ 需要修改

### 1.2 关键模块依赖

```
main.lua
  ├── Player (状态)
  │     ├── PlayerController (输入 → 移动)
  │     ├── BlockInteraction (输入 → 方块操作)
  │     └── CameraController (相机)
  ├── World (数据)
  │     ├── WorldGenerator (生成)
  │     └── ChunkMeshBuilder (渲染)
  └── UI (界面)
```

---

## 2. 联网架构设计

### 2.1 职责划分

| 模块 | 服务器职责 | 客户端职责 |
|------|-----------|-----------|
| **Player** | 存储所有玩家状态，处理输入 | 发送输入，渲染玩家 |
| **World** | 权威数据源，验证方块操作 | 接收数据，渲染区块 |
| **Movement** | 计算移动，碰撞检测 | 发送输入方向 |
| **BlockInteraction** | 验证并执行放置/破坏 | 发送操作请求 |
| **WorldGenerator** | 生成世界 | 不需要 |
| **ChunkMeshBuilder** | 不需要 | 渲染区块网格 |
| **UI/Camera** | 不需要 | 本地处理 |

### 2.2 新增文件结构

```
scripts/
├── Main.lua                    # 新入口（判断模式）
├── network/
│   ├── Shared.lua              # 共享常量/事件/工具
│   ├── Server.lua              # 服务器逻辑
│   └── Client.lua              # 客户端逻辑
├── player/
│   └── PlayerScript.lua        # 网络玩家生命周期管理（ScriptObject）
└── (其他保持不变)
```

**变更说明**（最小修改原则）：
- `Player.lua` → **小改**，添加 `fromNode(node, isLocal)` 方法
- `PlayerController.lua` → **不变**，继续作为移动/碰撞逻辑
- `PlayerScript.lua` → **新增** ScriptObject，负责网络生命周期和角色判断

---

## 3. 统一架构设计（单机 + 联网共用代码）

### 3.1 运行模式 API

平台提供三个判断函数：

| 函数 | 单机 | 联网服务器 | 联网客户端 |
|------|------|-----------|-----------|
| `IsServerMode()` | false | **true** | false |
| `IsClientMode()` | true | false | **true** |
| `IsNetworkMode()` | **false** | **true** | **true** |

**关键点**：
- 单机模式下 `IsClientMode()` 也返回 `true`
- 需要用 `IsNetworkMode()` 区分单机和联网

### 3.2 功能判断逻辑

```lua
-- 是否需要渲染（CustomGeometry、材质、粒子等）
local needRendering = not IsServerMode()
-- 单机 ✅  服务器 ❌  客户端 ✅

-- 是否需要本地碰撞检测
local needLocalCollision = not IsNetworkMode() or IsServerMode()
-- 单机 ✅  服务器 ✅  客户端 ❌

-- 是否需要发送输入到服务器
local needSendInput = IsNetworkMode() and IsClientMode()
-- 单机 ❌  服务器 ❌  客户端 ✅

-- 是否需要同步世界变更
local needWorldSync = IsNetworkMode()
-- 单机 ❌  服务器 ✅  客户端 ✅
```

### 3.3 统一架构示意

```
┌─────────────────────────────────────────────────────────────┐
│  单机模式  (IsNetworkMode() = false)                         │
│                                                             │
│  → World 数据 ✅                                             │
│  → 渲染 ✅                                                   │
│  → 本地输入 ✅                                               │
│  → 本地碰撞 ✅                                               │
│  → 网络同步 ❌                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  联网服务器  (IsServerMode() = true)                         │
│                                                             │
│  → World 数据 ✅                                             │
│  → 渲染 ❌ (Headless)                                        │
│  → 从 connection.controls 读取输入 ✅                        │
│  → 碰撞检测 ✅                                               │
│  → 网络同步 ✅                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  联网客户端  (IsClientMode() = true, IsNetworkMode() = true) │
│                                                             │
│  → World 数据(副本) ✅                                       │
│  → 渲染 ✅                                                   │
│  → 发送输入到服务器 ✅                                       │
│  → 碰撞 ❌ (服务器处理)                                      │
│  → 网络同步 ✅                                               │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 ScriptObject 统一模式

将模块封装为 ScriptObject，在 `DelayedStart()` 中根据运行模式初始化：

```lua
---@class WorldScript : LuaScriptObject
WorldScript = ScriptObject()

function WorldScript:DelayedStart()
    local scene = self.node.scene

    -- 1. 初始化 World 数据（所有模式都需要）
    self.world = World:new()

    -- 2. 世界生成
    if not IsNetworkMode() then
        -- 单机：直接生成
        self:GenerateWorld()
    elseif IsServerMode() then
        -- 联网服务器：生成世界，准备同步给客户端
        self:GenerateWorld()
    else
        -- 联网客户端：等待服务器同步（种子+变更）
        -- 在 HandleWorldSync 事件中处理
    end

    -- 3. 初始化渲染（非服务器）
    if not IsServerMode() then
        self:InitRendering()
    end
end
```

```lua
---@class PlayerScript : LuaScriptObject
PlayerScript = ScriptObject()

function PlayerScript:DelayedStart()
    -- 服务器不需要渲染
    if IsServerMode() then
        return
    end

    -- 创建玩家身体（单机和客户端都需要）
    self.body = PlayerBody:new(self)

    -- 单机模式：创建相机和第一人称手臂
    if not IsNetworkMode() then
        self:CreateCamera()
        self:CreateFirstPersonArm()
    end
end

function PlayerScript:Update(timeStep)
    if not IsNetworkMode() then
        -- 单机：本地输入 + 本地碰撞
        self:HandleLocalInput(timeStep)
        self:ApplyMovement(timeStep)
    elseif IsServerMode() then
        -- 联网服务器：从 connection 读取输入 + 碰撞
        self:ReadNetworkInput()
        self:ApplyMovement(timeStep)
    else
        -- 联网客户端：发送输入，等待服务器同步位置
        self:SendInputToServer()
    end
end
```

### 3.5 ChunkMeshBuilder 改造

ChunkMeshBuilder 只在 `not IsServerMode()` 的情况下使用（单机或客户端），因此内部节点创建**直接使用 LOCAL 模式**，无需参数判断：

```lua
function ChunkMeshBuilder:buildChunk(chunkX, chunkZ)
    local chunkKey = chunkX .. "," .. chunkZ

    -- 直接使用 LOCAL 模式（单机和客户端都适用）
    local chunkNode = self.scene:CreateChild("Chunk_" .. chunkKey, LOCAL)
    local geometry = chunkNode:CreateComponent("CustomGeometry", LOCAL)
    -- ...
end
```

**原因**：
- 单机模式：无网络同步，LOCAL 无影响
- 联网客户端：必须 LOCAL，避免与服务器冲突
- 联网服务器：不会调用此模块（Headless）

---

## 4. 最小改动迁移策略

### 4.1 核心原则

1. **复用现有模块**：不重写，只在关键位置加模式判断
2. **单机/联网共用代码**：通过 `IsServerMode()` / `IsNetworkMode()` 分支
3. **ScriptObject 模式**：使用 `DelayedStart()` 处理初始化

### 3.2 改动清单

#### 阶段 1：基础框架（必须）

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `Main.lua` | 新增 | 联网入口，判断 Server/Client |
| `network/Shared.lua` | 新增 | 事件名、变量名常量 |
| `network/Server.lua` | 新增 | 服务器逻辑 |
| `network/Client.lua` | 新增 | 客户端逻辑 |
| `player/PlayerScript.lua` | 新增 | 网络玩家生命周期管理（ScriptObject） |

#### 阶段 2：模块适配（最小改动）

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `ChunkMeshBuilder.lua` | 小改 | 添加 `isLocal` 参数，客户端用 LOCAL 创建节点 |
| `World.lua` | 无需改动 | 数据结构通用 |
| `PlayerController.lua` | 无需改动 | 服务器直接复用碰撞逻辑 |

### 3.3 服务器/客户端模块需求

```
┌─────────────────────────────────────────────────────────────┐
│  服务器（Headless）需要：                                     │
│  ✅ World.lua              → 方块数据存储                     │
│  ✅ WorldGenerator.lua     → 生成初始世界                     │
│  ✅ BiomeGenerator.lua     → 地形生成                         │
│  ✅ TreeDecorator.lua      → 树木生成                         │
│  ✅ PlayerController.lua   → 碰撞检测逻辑（复用）              │
│  ✅ BlockRegistry.lua      → 方块定义                         │
│  ✅ GameConfig.lua         → 配置                             │
│                                                              │
│  服务器不需要：                                               │
│  ❌ ChunkMeshBuilder.lua   → 网格渲染                         │
│  ❌ TextureAtlas.lua       → 纹理图集                         │
│  ❌ ParticleSystem.lua     → 粒子效果                         │
│  ❌ DayNightCycle.lua      → 昼夜循环（可选）                  │
│  ❌ UI/*                   → 所有 UI                          │
│  ❌ FirstPersonArm.lua     → 第一人称手臂                     │
│  ❌ CameraController.lua   → 相机控制                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  客户端需要：                                                 │
│  ✅ World.lua              → 本地副本（用于渲染和射线检测）    │
│  ✅ WorldGenerator.lua     → 用种子生成本地世界               │
│  ✅ ChunkMeshBuilder.lua   → 区块渲染（LOCAL 模式）           │
│  ✅ 所有渲染/UI 模块       → 本地渲染                         │
│                                                              │
│  客户端不需要：                                               │
│  ❌ PlayerController.lua   → 移动由服务器计算                 │
│  ❌ BlockInteraction.lua   → 方块操作发送到服务器验证         │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. 详细实现方案

### 4.1 新入口 `Main.lua`

```lua
-- Main.lua（联网入口）
local Module = nil

function Start()
    if IsServerMode() then
        Module = require("network.Server")
    else
        Module = require("network.Client")
    end
    Module.Start()
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end
```

### 4.2 共享定义 `network/Shared.lua`

```lua
-- network/Shared.lua
local Shared = {}

-- 远程事件
Shared.EVENTS = {
    -- 客户端 → 服务器
    CLIENT_READY = "MC_ClientReady",
    BLOCK_ACTION = "MC_BlockAction",        -- 方块操作请求

    -- 服务器 → 客户端
    ASSIGN_PLAYER = "MC_AssignPlayer",      -- 分配玩家ID
    WORLD_SYNC = "MC_WorldSync",            -- 世界同步（种子 + 变更列表）
    BLOCK_CHANGED = "MC_BlockChanged",      -- 方块变化广播（运行时）
    PLAY_SOUND = "MC_PlaySound",            -- 音效播放
    PLAY_PARTICLE = "MC_PlayParticle",      -- 粒子效果
}

-- 节点变量名
Shared.VARS = {
    ENTITY_TYPE = "EntityType",     -- "player"
    PLAYER_ID = "PlayerId",
    PLAYER_NAME = "PlayerName",
    PLAYER_COLOR = "PlayerColor",
}

-- 方块操作类型
Shared.BLOCK_ACTION = {
    DESTROY = 1,
    PLACE = 2,
}

-- 服务器接收事件
Shared.SERVER_EVENTS = {
    Shared.EVENTS.CLIENT_READY,
    Shared.EVENTS.BLOCK_ACTION,
}

-- 客户端接收事件
Shared.CLIENT_EVENTS = {
    Shared.EVENTS.ASSIGN_PLAYER,
    Shared.EVENTS.WORLD_SYNC,
    Shared.EVENTS.BLOCK_CHANGED,
    Shared.EVENTS.PLAY_SOUND,
    Shared.EVENTS.PLAY_PARTICLE,
}

-- 注册函数
function Shared.RegisterServerEvents()
    for _, eventName in ipairs(Shared.SERVER_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

function Shared.RegisterClientEvents()
    for _, eventName in ipairs(Shared.CLIENT_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

-- 工具函数
function Shared.GetConnectionKey(connection)
    if connection then
        return tostring(connection:GetAddress()) .. ":" .. tostring(connection:GetPort())
    end
    return nil
end

return Shared
```

### 4.3 服务器 `network/Server.lua`

```lua
-- network/Server.lua
local Config = require("config.GameConfig")
local World = require("world.World")
local WorldGenerator = require("world.WorldGenerator")
local PlayerController = require("player.PlayerController")  -- 复用完整碰撞逻辑
local Shared = require("network.Shared")

local Server = {}

-- 全局状态
local scene_ = nil
local world_ = nil
local worldGenerator_ = nil
local players_ = {}  -- { [connKey] = { connection, playerId, node, ... } }
local nextPlayerId_ = 1

-- ============================================================================
-- 初始化
-- ============================================================================

function Server.Start()
    print("=== Minecraft Server Starting ===")

    -- 注册远程事件
    Shared.RegisterServerEvents()

    -- 创建场景
    Server.CreateScene()

    -- 创建世界
    world_ = World:new()
    worldGenerator_ = WorldGenerator:new()
    worldGenerator_:generate(world_)
    print("[Server] World generated!")

    -- 订阅事件
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent(Shared.EVENTS.CLIENT_READY, "HandleClientReady")
    SubscribeToEvent(Shared.EVENTS.BLOCK_ACTION, "HandleBlockAction")
    SubscribeToEvent("Update", "HandleUpdate")

    print("=== Minecraft Server Ready ===")
end

function Server.CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    -- 服务器不需要光照和渲染
end

-- ============================================================================
-- 连接管理
-- ============================================================================

function HandleClientConnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    connection.scene = scene_  -- 触发场景同步

    local connKey = Shared.GetConnectionKey(connection)
    print("[Server] Client connected:", connKey)
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Shared.GetConnectionKey(connection)

    local playerInfo = players_[connKey]
    if playerInfo then
        if playerInfo.node then
            playerInfo.node:Dispose()  -- 重要：用 Dispose 而非 Remove
        end
        players_[connKey] = nil
        print("[Server] Player disconnected:", connKey)
    end
end

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Shared.GetConnectionKey(connection)

    -- 分配玩家ID
    local playerId = nextPlayerId_
    nextPlayerId_ = nextPlayerId_ + 1

    -- 计算出生点
    local spawnX, spawnZ = 0, 0
    local spawnY = world_:getGroundHeight(spawnX, spawnZ) + 1
    local spawnPos = Vector3(
        spawnX * Config.World.BLOCK_SIZE,
        spawnY * Config.World.BLOCK_SIZE,
        spawnZ * Config.World.BLOCK_SIZE
    )

    -- 创建玩家节点（REPLICATED，会自动同步到客户端）
    local playerNode = scene_:CreateChild("Player_" .. playerId, REPLICATED)
    playerNode.position = spawnPos

    -- 设置节点变量（会同步到客户端）
    playerNode:SetVar(Shared.VARS.ENTITY_TYPE, Variant("player"))
    playerNode:SetVar(Shared.VARS.PLAYER_ID, Variant(playerId))

    -- 附加 ScriptObject（客户端用于创建渲染组件）
    playerNode:CreateScriptObject("scripts/player/PlayerScript.lua", "PlayerScript")

    -- 存储玩家信息
    players_[connKey] = {
        connection = connection,
        playerId = playerId,
        node = playerNode,
        velocity = Vector3(0, 0, 0),
        yaw = 0,
        pitch = 0,
        isOnGround = false,
    }

    -- 通知客户端
    local assignData = VariantMap()
    assignData["PlayerId"] = Variant(playerId)
    assignData["WorldSeed"] = Variant(Config.Noise.SEED)
    connection:SendRemoteEvent(Shared.EVENTS.ASSIGN_PLAYER, true, assignData)

    print("[Server] Player", playerId, "spawned at", spawnPos.x, spawnPos.y, spawnPos.z)
end

-- ============================================================================
-- 游戏逻辑
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    for connKey, playerInfo in pairs(players_) do
        Server.UpdatePlayer(playerInfo, timeStep)
    end
end

function Server.UpdatePlayer(playerInfo, timeStep)
    local conn = playerInfo.connection
    local node = playerInfo.node

    -- 读取客户端输入（通过 connection.controls）
    local yaw = conn.controls.yaw
    local pitch = conn.controls.pitch
    local buttons = conn.controls.buttons

    playerInfo.yaw = yaw
    playerInfo.pitch = pitch

    -- 解析按钮状态
    local moveForward = (buttons & 1) ~= 0
    local moveBack = (buttons & 2) ~= 0
    local moveLeft = (buttons & 4) ~= 0
    local moveRight = (buttons & 8) ~= 0
    local jump = (buttons & 16) ~= 0

    -- 计算移动方向
    local moveDir = Vector3(0, 0, 0)
    if moveForward then moveDir.z = moveDir.z + 1 end
    if moveBack then moveDir.z = moveDir.z - 1 end
    if moveLeft then moveDir.x = moveDir.x - 1 end
    if moveRight then moveDir.x = moveDir.x + 1 end

    if moveDir:Length() > 0 then
        moveDir = moveDir:Normalized()
        local yawRotation = Quaternion(yaw, Vector3(0, 1, 0))
        moveDir = yawRotation * moveDir
    end

    -- ============================================================
    -- 复用 PlayerController 的完整碰撞检测逻辑
    -- 注意：PlayerController 需要封装碰撞逻辑为可复用的方法
    -- ============================================================

    -- 为每个玩家创建独立的 PlayerController 实例
    if not playerInfo.controller then
        -- 创建 player 适配器对象（满足 PlayerController 接口）
        local playerAdapter = Server.CreatePlayerAdapter(playerInfo, node)
        playerInfo.controller = PlayerController:new(playerAdapter, world_)
    end

    -- 更新适配器状态
    playerInfo.controller.player.yaw = yaw
    playerInfo.controller.player.pitch = pitch

    -- 设置输入状态（模拟键盘输入）
    playerInfo.controller.moveForward = moveForward
    playerInfo.controller.moveBack = moveBack
    playerInfo.controller.moveLeft = moveLeft
    playerInfo.controller.moveRight = moveRight
    playerInfo.controller.jumpPressed = jump

    -- 调用 PlayerController 的移动更新（包含完整碰撞检测）
    playerInfo.controller:updateMovement(timeStep)
end

-- 创建 Player 适配器（满足 PlayerController 需要的接口）
function Server.CreatePlayerAdapter(playerInfo, node)
    return {
        node = node,
        velocity = playerInfo.velocity,
        isOnGround = playerInfo.isOnGround,
        yaw = playerInfo.yaw,
        pitch = playerInfo.pitch,
        getPosition = function(self) return node.position end,
        setPosition = function(self, pos) node.position = pos end,
        getVelocity = function(self) return playerInfo.velocity end,
        setVelocity = function(self, vel) playerInfo.velocity = vel end,
        getOnGround = function(self) return playerInfo.isOnGround end,
        setOnGround = function(self, val) playerInfo.isOnGround = val end,
        getYaw = function(self) return playerInfo.yaw end,
        getPitch = function(self) return playerInfo.pitch end,
    }
end

-- ============================================================================
-- 方块操作
-- ============================================================================

function HandleBlockAction(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Shared.GetConnectionKey(connection)
    local playerInfo = players_[connKey]

    if not playerInfo then return end

    local action = eventData["Action"]:GetInt()
    local bx = eventData["X"]:GetInt()
    local by = eventData["Y"]:GetInt()
    local bz = eventData["Z"]:GetInt()

    if action == Shared.BLOCK_ACTION.DESTROY then
        local oldBlock = world_:getBlock(bx, by, bz)
        if oldBlock ~= 0 then
            world_:setBlock(bx, by, bz, 0)  -- AIR
            Server.BroadcastBlockChange(bx, by, bz, 0, oldBlock)
        end
    elseif action == Shared.BLOCK_ACTION.PLACE then
        local blockType = eventData["BlockType"]:GetInt()
        local currentBlock = world_:getBlock(bx, by, bz)
        if currentBlock == 0 then
            world_:setBlock(bx, by, bz, blockType)
            Server.BroadcastBlockChange(bx, by, bz, blockType, 0)
        end
    end
end

function Server.BroadcastBlockChange(x, y, z, newBlock, oldBlock)
    local eventData = VariantMap()
    eventData["X"] = Variant(x)
    eventData["Y"] = Variant(y)
    eventData["Z"] = Variant(z)
    eventData["NewBlock"] = Variant(newBlock)
    eventData["OldBlock"] = Variant(oldBlock)

    network:BroadcastRemoteEvent(Shared.EVENTS.BLOCK_CHANGED, true, eventData)

    -- 广播粒子效果
    if oldBlock ~= 0 then
        local particleData = VariantMap()
        particleData["X"] = Variant(x)
        particleData["Y"] = Variant(y)
        particleData["Z"] = Variant(z)
        particleData["BlockType"] = Variant(oldBlock)
        network:BroadcastRemoteEvent(Shared.EVENTS.PLAY_PARTICLE, true, particleData)
    end
end

function Server.Stop()
    print("[Server] Shutting down...")
end

return Server
```

### 4.4 客户端 `network/Client.lua`

```lua
-- network/Client.lua
local Config = require("config.GameConfig")
local World = require("world.World")
local WorldGenerator = require("world.WorldGenerator")
local ChunkMeshBuilder = require("world.ChunkMeshBuilder")
local TextureAtlas = require("rendering.TextureAtlas")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")
local ParticleSystem = require("rendering.ParticleSystem")
local UIManager = require("ui.UIManager")
local Hotbar = require("ui.Hotbar")
local DebugOverlay = require("ui.DebugOverlay")
local DayNightCycle = require("world.DayNightCycle")
local Shared = require("network.Shared")

require "LuaScripts/Utilities/Sample"
require "urhox-libs.UI.GameHUD"

local Client = {}

-- 全局状态
local scene_ = nil
local world_ = nil
local chunkBuilder_ = nil
local particleSystem_ = nil
local serverConnection_ = nil

-- 本地玩家
local myPlayerId_ = nil
local myPlayerNode_ = nil
local cameraNode_ = nil
local camera_ = nil

-- 输入状态
local yaw_ = 0
local pitch_ = 0
local selectedBlockType_ = 1  -- GRASS

-- UI
local uiManager_ = nil
local hotbar_ = nil
local debugOverlay_ = nil

-- 光照
local lightGroup_ = nil
local zone_ = nil
local sunLight_ = nil
local dayNightCycle_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

function Client.Start()
    print("=== Minecraft Client Starting ===")

    SampleStart()

    -- 注册远程事件
    Shared.RegisterClientEvents()

    -- 获取服务器连接
    serverConnection_ = network:GetServerConnection()

    -- 创建场景
    Client.CreateScene()

    -- 创建本地世界（用于渲染）
    world_ = World:new()

    -- 订阅事件
    SubscribeToEvent(Shared.EVENTS.ASSIGN_PLAYER, "HandleAssignPlayer")
    SubscribeToEvent(Shared.EVENTS.BLOCK_CHANGED, "HandleBlockChanged")
    SubscribeToEvent(Shared.EVENTS.PLAY_PARTICLE, "HandlePlayParticle")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseButtonDown")

    -- 通知服务器客户端准备就绪
    serverConnection_:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)

    print("=== Minecraft Client Ready ===")
end

function Client.CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 加载光照预设
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    lightGroup_ = scene_:CreateChild("LightGroup", LOCAL)
    lightGroup_:LoadXML(lightGroupFile:GetRoot())

    zone_ = lightGroup_:GetComponent("Zone")
    local sunNode = lightGroup_:GetChild("Directional Light")
    if sunNode then
        sunLight_ = sunNode:GetComponent("Light")
    end

    if zone_ then
        zone_.fogStart = Config.Camera.FOG_START
        zone_.fogEnd = Config.Camera.FOG_END
    end
end

-- ============================================================================
-- 玩家初始化
-- ============================================================================

function HandleAssignPlayer(eventType, eventData)
    myPlayerId_ = eventData["PlayerId"]:GetInt()
    local worldSeed = eventData["WorldSeed"]:GetInt()

    print("[Client] Assigned player ID:", myPlayerId_)
    print("[Client] World seed:", worldSeed)

    -- 使用相同种子生成本地世界（用于渲染）
    Config.Noise.SEED = worldSeed
    local worldGenerator = WorldGenerator:new()
    worldGenerator:generate(world_)

    -- 创建纹理和区块构建器
    TexturePackManager:setCurrent("hd")
    local textureAtlas = TextureAtlas:new()
    local textures = textureAtlas:generate()

    chunkBuilder_ = ChunkMeshBuilder:new(world_, scene_)  -- 内部已用 LOCAL 模式
    chunkBuilder_:setTextures(textures)

    -- 创建粒子系统
    particleSystem_ = ParticleSystem:new(scene_, world_)

    -- 创建相机
    Client.CreateCamera()

    -- 创建 UI
    Client.CreateUI()

    -- 渲染区块
    chunkBuilder_:renderVisibleChunks(Vector3(0, 0, 0))

    -- 锁定鼠标
    input.mouseVisible = false
    input.mouseMode = MM_RELATIVE

    -- 初始化昼夜循环
    if Config.DayNight and Config.DayNight.ENABLED then
        dayNightCycle_ = DayNightCycle:new({
            scene = scene_,
            lightGroup = lightGroup_,
            zone = zone_,
            sunLight = sunLight_,
            startTime = Config.DayNight.START_TIME,
            dayDuration = Config.DayNight.DAY_DURATION,
        })
    end
end

function Client.CreateCamera()
    cameraNode_ = scene_:CreateChild("Camera", LOCAL)
    camera_ = cameraNode_:CreateComponent("Camera", LOCAL)
    camera_.farClip = Config.Camera.FAR_CLIP
    camera_.fov = Config.Camera.FOV

    local viewport = Viewport:new(scene_, camera_)
    renderer:SetViewport(0, viewport)
end

function Client.CreateUI()
    uiManager_ = UIManager:new()
    uiManager_:init({ designSize = 1080 })

    -- 创建简化版 hotbar（无 player 引用）
    hotbar_ = Hotbar:new(nil)
    hotbar_.onBlockSelected = function(blockType)
        selectedBlockType_ = blockType
    end

    uiManager_:setHotbar(hotbar_)
    uiManager_:build()
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 更新昼夜
    if dayNightCycle_ then
        dayNightCycle_:update(timeStep)
    end

    -- 更新输入
    Client.UpdateInput(timeStep)

    -- 更新相机跟随
    Client.UpdateCamera()

    -- 重建脏区块
    if chunkBuilder_ then
        chunkBuilder_:rebuildDirtyChunks()
    end

    -- 更新粒子
    if particleSystem_ then
        particleSystem_:update(timeStep)
    end

    -- 更新 UI
    if uiManager_ then
        uiManager_:update(timeStep)
    end
end

function Client.UpdateInput(timeStep)
    if not serverConnection_ then return end

    -- 鼠标视角
    local mouseMove = input.mouseMove
    local sensitivity = Config.Controls.MOUSE_SENSITIVITY
    yaw_ = yaw_ + mouseMove.x * sensitivity
    pitch_ = pitch_ + mouseMove.y * sensitivity
    pitch_ = math.max(-89, math.min(89, pitch_))

    -- 同步到服务器
    serverConnection_.controls.yaw = yaw_
    serverConnection_.controls.pitch = pitch_

    -- 按钮状态
    local buttons = 0
    if input:GetKeyDown(KEY_W) then buttons = buttons | 1 end
    if input:GetKeyDown(KEY_S) then buttons = buttons | 2 end
    if input:GetKeyDown(KEY_A) then buttons = buttons | 4 end
    if input:GetKeyDown(KEY_D) then buttons = buttons | 8 end
    if input:GetKeyDown(KEY_SPACE) then buttons = buttons | 16 end
    serverConnection_.controls.buttons = buttons
end

function Client.UpdateCamera()
    -- 找到自己的玩家节点
    if not myPlayerNode_ then
        local children = scene_:GetChildren()
        for i = 0, children:Size() - 1 do
            local child = children:At(i)
            local idVar = child:GetVar(Shared.VARS.PLAYER_ID)
            if idVar and not idVar:IsEmpty() and idVar:GetInt() == myPlayerId_ then
                myPlayerNode_ = child
                break
            end
        end
    end

    if myPlayerNode_ and cameraNode_ then
        local playerPos = myPlayerNode_.position
        local BLOCK_SIZE = Config.World.BLOCK_SIZE
        local eyeHeight = (Config.Player.HEIGHT - 0.2) * BLOCK_SIZE

        -- 相机跟随玩家（第一人称）
        cameraNode_.position = Vector3(playerPos.x, playerPos.y + eyeHeight, playerPos.z)
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0)
    end
end

-- ============================================================================
-- 方块操作
-- ============================================================================

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- Hotbar 选择
    local hotbarKeys = {
        [KEY_1] = 1, [KEY_2] = 2, [KEY_3] = 3, [KEY_4] = 4,
        [KEY_5] = 5, [KEY_6] = 6, [KEY_7] = 7, [KEY_8] = 8,
    }
    if hotbarKeys[key] and hotbar_ then
        hotbar_:selectSlot(hotbarKeys[key])
    end

    if key == KEY_ESCAPE then
        engine:Exit()
    end
end

function HandleMouseButtonDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()

    local bx, by, bz, prevBx, prevBy, prevBz = Client.RaycastBlock()
    if not bx then return end

    local actionData = VariantMap()

    if button == MOUSEB_LEFT then
        -- 破坏方块
        actionData["Action"] = Variant(Shared.BLOCK_ACTION.DESTROY)
        actionData["X"] = Variant(bx)
        actionData["Y"] = Variant(by)
        actionData["Z"] = Variant(bz)
    elseif button == MOUSEB_RIGHT then
        -- 放置方块
        actionData["Action"] = Variant(Shared.BLOCK_ACTION.PLACE)
        actionData["X"] = Variant(prevBx)
        actionData["Y"] = Variant(prevBy)
        actionData["Z"] = Variant(prevBz)
        actionData["BlockType"] = Variant(selectedBlockType_)
    end

    serverConnection_:SendRemoteEvent(Shared.EVENTS.BLOCK_ACTION, true, actionData)
end

-- 简化版射线检测（复用 BlockInteraction 的 DDA 算法）
function Client.RaycastBlock()
    if not cameraNode_ then return nil end

    local startPos = cameraNode_.worldPosition
    local dir = cameraNode_.worldDirection
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local REACH = Config.Player.REACH_DISTANCE

    local startX = startPos.x / BLOCK_SIZE
    local startY = startPos.y / BLOCK_SIZE
    local startZ = startPos.z / BLOCK_SIZE

    local x = math.floor(startX)
    local y = math.floor(startY)
    local z = math.floor(startZ)

    local stepX = dir.x > 0 and 1 or -1
    local stepY = dir.y > 0 and 1 or -1
    local stepZ = dir.z > 0 and 1 or -1

    local huge = math.huge
    local tDeltaX = math.abs(dir.x) > 1e-8 and math.abs(1 / dir.x) or huge
    local tDeltaY = math.abs(dir.y) > 1e-8 and math.abs(1 / dir.y) or huge
    local tDeltaZ = math.abs(dir.z) > 1e-8 and math.abs(1 / dir.z) or huge

    local tMaxX = stepX > 0 and tDeltaX * (x + 1 - startX) or tDeltaX * (startX - x)
    local tMaxY = stepY > 0 and tDeltaY * (y + 1 - startY) or tDeltaY * (startY - y)
    local tMaxZ = stepZ > 0 and tDeltaZ * (z + 1 - startZ) or tDeltaZ * (startZ - z)

    local prevX, prevY, prevZ = x, y, z
    local maxDist = REACH / BLOCK_SIZE
    local t = 0

    while t < maxDist do
        local block = world_:getBlock(x, y, z)
        if block ~= 0 then
            return x, y, z, prevX, prevY, prevZ
        end

        prevX, prevY, prevZ = x, y, z

        if tMaxX < tMaxY and tMaxX < tMaxZ then
            x = x + stepX
            t = tMaxX
            tMaxX = tMaxX + tDeltaX
        elseif tMaxY < tMaxZ then
            y = y + stepY
            t = tMaxY
            tMaxY = tMaxY + tDeltaY
        else
            z = z + stepZ
            t = tMaxZ
            tMaxZ = tMaxZ + tDeltaZ
        end
    end

    return nil
end

-- ============================================================================
-- 网络事件处理
-- ============================================================================

function HandleBlockChanged(eventType, eventData)
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local z = eventData["Z"]:GetInt()
    local newBlock = eventData["NewBlock"]:GetInt()

    -- 更新本地世界数据
    world_:setBlock(x, y, z, newBlock)
end

function HandlePlayParticle(eventType, eventData)
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local z = eventData["Z"]:GetInt()
    local blockType = eventData["BlockType"]:GetInt()

    if particleSystem_ then
        local BLOCK_SIZE = Config.World.BLOCK_SIZE
        local worldPos = Vector3(
            x * BLOCK_SIZE + BLOCK_SIZE * 0.5,
            y * BLOCK_SIZE + BLOCK_SIZE * 0.5,
            z * BLOCK_SIZE + BLOCK_SIZE * 0.5
        )
        particleSystem_:spawnBlockParticles(worldPos, blockType)
    end
end

function Client.Stop()
    print("[Client] Shutting down...")
end

return Client
```

### 4.5 ChunkMeshBuilder 改动

**问题**：当前 `CreateChild()` 默认是 REPLICATED，客户端创建会与服务器冲突。

**改动**：内部直接使用 LOCAL 模式（无需参数）

```lua
-- world/ChunkMeshBuilder.lua

function ChunkMeshBuilder:buildChunk(chunkX, chunkZ)
    local chunkKey = chunkX .. "," .. chunkZ

    -- 直接使用 LOCAL 模式
    local chunkNode = self.scene:CreateChild("Chunk_" .. chunkKey, LOCAL)
    local geometry = chunkNode:CreateComponent("CustomGeometry", LOCAL)
    -- ... 其余代码不变
end
```

**原因**：ChunkMeshBuilder 只在非服务器模式使用（单机或客户端），两种情况都适合 LOCAL：
- 单机：无网络，LOCAL 无影响
- 客户端：必须 LOCAL，避免与服务器冲突

### 4.6 玩家网络生命周期 `player/PlayerScript.lua`（ScriptObject）

**设计理念**：职责分明，最小修改。

- **Player.lua** = 玩家对象（节点 + 状态 + 组件）
- **PlayerController.lua** = 操作玩家（输入、移动、碰撞）
- **PlayerScript.lua** = 网络生命周期管理（ScriptObject）

```
┌─────────────────────────────────────────────────────────────┐
│  PlayerScript.lua (ScriptObject)                            │
│  职责：网络生命周期 + 角色判断                                │
├─────────────────────────────────────────────────────────────┤
│  DelayedStart()                                             │
│    ├── 判断角色（服务器/客户端本地/远程）                     │
│    ├── 创建 Player 实例（传入 node + isLocal）              │
│    └── 创建 PlayerController（如果需要控制）                 │
│                                                             │
│  FixedUpdate()                                              │
│    └── 调用 controller:update()                             │
└─────────────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
┌─────────────────┐      ┌─────────────────────┐
│   Player.lua    │      │ PlayerController.lua│
│   (数据/组件)    │◄─────│   (操作/逻辑)        │
└─────────────────┘      └─────────────────────┘
```

#### 4.6.1 角色判定逻辑

```
IsServerMode()?
    ├── true  → 联网服务器（Headless，无渲染，只有逻辑）
    │          isLocal = false
    │
    └── false → IsNetworkMode()?
                    ├── false → 单机模式（唯一玩家就是本地）
                    │          isLocal = true
                    │
                    └── true  → 联网客户端
                               isLocal = (PlayerID == LocalID)
```

#### 4.6.2 组件初始化策略

| 场景 | Camera | FirstPersonArm | PlayerBody | 碰撞检测 |
|------|--------|----------------|------------|----------|
| 单机 | ✅ 创建 | ✅ 创建 | ✅ 隐藏 | ✅ 本地 |
| 联网服务器 | ❌ | ❌ | ❌ | ✅ 服务器 |
| 联网客户端-本地 | ✅ 创建 | ✅ 创建 | ✅ 隐藏 | ❌ 服务器处理 |
| 联网客户端-远程 | ❌ | ❌ | ✅ 可见 | ❌ 服务器处理 |

#### 4.6.3 PlayerScript.lua 代码

```lua
-- player/PlayerScript.lua
-- 网络玩家生命周期管理（ScriptObject）

local Player = require("player.Player")
local PlayerController = require("player.PlayerController")
local Shared = require("network.Shared")

---@class PlayerScript : LuaScriptObject
PlayerScript = ScriptObject()

function PlayerScript:Start()
    self.player = nil
    self.controller = nil
    self.isLocal = false
end

function PlayerScript:DelayedStart()
    -- 判断角色
    self.isLocal = self:DetermineIsLocal()

    -- 服务器：只创建 Player（无渲染），需要 controller 处理移动
    -- 客户端本地：创建 Player（有渲染）+ controller
    -- 客户端远程：创建 Player（有渲染，body 可见），无 controller
    -- 单机：创建 Player（有渲染）+ controller

    -- 创建 Player 实例
    self.player = Player:fromNode(self.node, self.isLocal)

    -- 需要控制器的情况：服务器、单机、联网客户端本地玩家
    local needController = IsServerMode() or not IsNetworkMode() or self.isLocal
    if needController then
        -- 获取 world 引用（从场景变量）
        local world = self.node.scene:GetVar("World"):GetPtr()
        self.controller = PlayerController:new(self.player, world)
    end

    print("[PlayerScript] Created: isLocal=" .. tostring(self.isLocal))
end

function PlayerScript:DetermineIsLocal()
    if IsServerMode() then
        return false  -- 服务器没有"本地玩家"
    elseif not IsNetworkMode() then
        return true   -- 单机：唯一玩家就是本地
    else
        -- 联网客户端：比较 PlayerID
        local playerID = self.node:GetVar(Shared.VARS.PLAYER_ID):GetInt()
        local localID = self.node.scene:GetVar("LocalPlayerID"):GetInt()
        return playerID == localID
    end
end

function PlayerScript:Update(timeStep)
    if self.player then
        self.player:update(timeStep)
    end
end

function PlayerScript:FixedUpdate(timeStep)
    if self.controller then
        self.controller:update(timeStep)
    end
end
```

#### 4.6.4 Player.lua 改动（最小修改）

只需添加 `fromNode` 方法：

```lua
-- player/Player.lua 添加以下方法

---从已有节点创建玩家（联机/单机通用）
---@param node Node 玩家节点
---@param isLocal boolean 是否为本地玩家
---@return table Player实例
function Player:fromNode(node, isLocal)
    local self = setmetatable({}, Player)

    self.node = node
    self.scene = node.scene
    self.isLocal = isLocal

    -- 状态初始化
    self.velocity = Vector3(0, 0, 0)
    self.yaw = 0
    self.pitch = 0
    self.isOnGround = false
    self.selectedBlockType = Blocks.GRASS
    self.selectedBlockIndex = 1

    -- 服务器：不创建任何渲染组件
    if IsServerMode() then
        self.cameraNode = nil
        self.camera = nil
        self.firstPersonArm = nil
        self.body = nil
        return self
    end

    -- 本地玩家：创建相机和手臂
    if isLocal then
        self:createCamera()
        self.firstPersonArm = FirstPersonArm:new(self, self.scene)
        self.body = PlayerBody:new(self)
        self.body:setVisible(false)
    else
        -- 远程玩家：只创建可见的身体
        self.cameraNode = nil
        self.camera = nil
        self.firstPersonArm = nil
        self.body = PlayerBody:new(self)
        self.body:setVisible(true)
    end

    return self
end

---创建相机（从 new 方法提取）
function Player:createCamera()
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local PLAYER_HEIGHT = Config.Player.HEIGHT

    self.cameraNode = self.node:CreateChild("Camera", LOCAL)
    self.cameraNode.position = Vector3(0, (PLAYER_HEIGHT - 0.2) * BLOCK_SIZE, 0)

    -- 加载景深（移动端跳过）
    local platform = GetPlatform()
    if platform ~= "Android" and platform ~= "iOS" then
        local xmlFile = cache:GetResource("XMLFile", "EngineRes/PostProcess/DOFPrefab.xml")
        if xmlFile then
            self.cameraNode:LoadXML(xmlFile:GetRoot())
        end
    end

    self.camera = self.cameraNode:CreateComponent("Camera")
    self.camera.farClip = Config.Camera.FAR_CLIP
    self.camera.fov = Config.Camera.FOV
end
```

**注意**：原有的 `Player:new(scene)` 方法保留不变，单机模式可继续使用原有方式。

#### 4.6.5 使用方式

**服务端创建玩家**（Server.lua）:

```lua
function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")

    -- 创建玩家节点（REPLICATED）
    local playerNode = scene_:CreateChild("Player_" .. playerId, REPLICATED)
    playerNode.position = spawnPos

    -- 设置 Vars（同步给客户端）
    playerNode:SetVar(Shared.VARS.ENTITY_TYPE, Variant("player"))
    playerNode:SetVar(Shared.VARS.PLAYER_ID, Variant(playerId))
    playerNode:SetVar("Connection", Variant(connection))  -- 服务端用

    -- 创建 PlayerScript（自动同步给客户端）
    playerNode:CreateScriptObject("scripts/player/PlayerScript.lua", "PlayerScript")

    -- ... 其余逻辑
end
```

**客户端连接**（Client.lua）:

```lua
function HandleAssignPlayer(eventType, eventData)
    myPlayerId_ = eventData["PlayerId"]:GetInt()

    -- 设置本地玩家 ID（供 PlayerScript 判断）
    scene_:SetVar("LocalPlayerID", Variant(myPlayerId_))

    -- 不需要手动创建任何东西
    -- 服务端的 PlayerScript 会自动同步过来
    -- DelayedStart 会自动判断是否为本地玩家

    -- ... 世界生成、渲染初始化等
end
```

**单机模式**（保持原有 main.lua 不变即可）:

```lua
-- 单机模式可以：
-- 1. 继续使用原有的 Player:new(scene) 方式（无需改动）
-- 2. 或统一使用 PlayerScript（可选）
```

---

## 5. 数据同步策略

### 5.1 世界数据同步

**方案：种子 + 变更列表** ✅

由于地形可破坏，单纯种子同步不够，需要同步运行时的方块变更。

```
新玩家加入流程：
┌─────────────────────────────────────────────────────────────┐
│  1. 服务器发送：种子 + 变更列表                                │
│     { seed: 12345, changes: {"10,20,30":0, "11,21,31":3} }  │
│                                                             │
│  2. 客户端：                                                 │
│     a) 用种子生成原始世界                                     │
│     b) 遍历变更列表，覆盖对应方块                              │
│     c) 渲染区块                                              │
└─────────────────────────────────────────────────────────────┘
```

**服务器维护变更列表**：

```lua
-- Server.lua
local modifiedBlocks_ = {}  -- { ["x,y,z"] = blockType }

-- 方块变更时记录
function Server.RecordBlockChange(x, y, z, newBlock)
    local key = x .. "," .. y .. "," .. z
    local originalBlock = Server.GetOriginalBlock(x, y, z)  -- 用种子计算

    if newBlock == originalBlock then
        modifiedBlocks_[key] = nil  -- 恢复原状，删除记录
    else
        modifiedBlocks_[key] = newBlock
    end
end

-- 新玩家加入时发送
function Server.SendWorldSync(connection)
    local eventData = VariantMap()
    eventData["Seed"] = Variant(Config.Noise.SEED)

    -- 序列化变更列表
    local changesStr = ""
    for key, blockType in pairs(modifiedBlocks_) do
        changesStr = changesStr .. key .. ":" .. blockType .. ";"
    end
    eventData["Changes"] = Variant(changesStr)

    connection:SendRemoteEvent(Shared.EVENTS.WORLD_SYNC, true, eventData)
end
```

**数据量估算**：

| 场景 | 变更数 | 数据大小 |
|------|--------|----------|
| 短局（10分钟） | ~200 | ~4KB |
| 中局（30分钟） | ~1000 | ~20KB |
| 长局（2小时） | ~5000 | ~100KB |

### 5.2 玩家位置同步

```
客户端                              服务器
   │                                  │
   │  controls.yaw/pitch/buttons      │
   │  ────────────────────────────→   │
   │                                  │
   │                                  │  处理输入，计算位置
   │                                  │  更新 REPLICATED 节点
   │                                  │
   │    ←── SmoothedTransform ────    │  自动位置同步
   │                                  │
```

### 5.3 方块操作同步

```
客户端                              服务器
   │                                  │
   │  BLOCK_ACTION (x,y,z,type)       │
   │  ────────────────────────────→   │
   │                                  │
   │                                  │  验证操作合法性
   │                                  │  更新 World 数据
   │                                  │
   │    ←── BLOCK_CHANGED ────────    │  广播给所有客户端
   │    ←── PLAY_PARTICLE ────────    │  粒子效果
   │                                  │
```

### 5.4 装饰器同步策略

世界生成包含多种装饰器，需要确保联网时数据一致。

#### 5.4.1 装饰器分析

| 装饰器 | 随机方式 | 数据存储 | 需要改造？ |
|--------|---------|---------|----------|
| BiomeGenerator | 确定性（Perlin 噪声） | 无（实时计算） | ❌ |
| TreeDecorator | 确定性（哈希函数） | `world:setBlockRaw` → WOOD/LEAVES | ❌ |
| WorldGenerator（植被） | 确定性（坐标种子） | `world:setBlockRaw` → TALL_GRASS/ROSE/FLOWER | ❌ |
| **TorchDecorator** | 确定性（坐标种子） | **直接创建场景节点** | ✅ **需要改造** |

#### 5.4.2 确定性随机说明

```lua
-- TreeDecorator 使用纯哈希函数（完全确定性）
function TreeDecorator:hash(x, z, salt)
    local h = (x * 73856093) ~ (z * 19349663) ~ (salt * 83492791)
    return (h % 10000) / 10000.0
end

-- WorldGenerator/TorchDecorator 使用坐标作为种子（确定性）
math.randomseed(x * 12345 + z * 67890)
```

**结论**：给定相同世界种子，树木、植被、火把位置完全一致。

#### 5.4.3 TorchDecorator 改造方案

**问题**：当前火把不存入 World 数据，直接创建场景节点（Light + CustomGeometry + 粒子），无法被"种子+变更列表"同步。

**改造**：分离数据层和渲染层

```lua
-- terrain/TorchDecorator.lua 改造

function TorchDecorator:tryPlaceTorch(world, x, z)
    local height = world:getGroundHeight(x, z) - 1
    local topBlock = world:getBlock(x, height, z)
    local aboveBlock = world:getBlock(x, height + 1, z)

    if topBlock ~= Blocks.GRASS or aboveBlock ~= Blocks.AIR then
        return false
    end

    -- 确定性随机
    math.randomseed(x * 54321 + z * 98765)
    if math.random() > TORCH_CONFIG.density then
        return false
    end

    if not self:checkMinDistance(x, z) then
        return false
    end

    -- ========== 改造点 ==========
    -- 1. 存入 World 数据（服务器+客户端都执行）
    world:setBlockRaw(x, height + 1, z, Blocks.TORCH)

    -- 2. 创建渲染（仅非服务器模式）
    if not IsServerMode() then
        self:createTorchVisuals(x, height + 1, z)
    end
    -- ============================

    table.insert(self.torchPositions, { x = x, z = z })
    return true
end

-- 重命名：createTorch → createTorchVisuals（仅渲染）
function TorchDecorator:createTorchVisuals(x, y, z)
    -- 原 createTorch 的渲染逻辑（Light + CustomGeometry + 粒子）
    -- ...
end
```

**运行时火把操作**：

```lua
-- 玩家放置火把
function TorchDecorator:addTorch(world, x, y, z)
    world:setBlock(x, y, z, Blocks.TORCH)  -- 存入数据（会触发网络同步）
    if not IsServerMode() then
        self:createTorchVisuals(x, y, z)
    end
end

-- 玩家破坏火把
function TorchDecorator:removeTorch(world, x, y, z)
    world:setBlock(x, y, z, Blocks.AIR)  -- 存入数据（会触发网络同步）
    if not IsServerMode() then
        self:removeTorchVisuals(x, y, z)
    end
end
```

**同步流程**：

```
┌─────────────────────────────────────────────────────────────┐
│  火把同步流程（与普通方块一致）                                │
│                                                             │
│  世界生成：                                                  │
│    服务器/客户端用相同种子 → 火把位置一致 → World 数据一致     │
│                                                             │
│  运行时变更：                                                │
│    玩家放置/破坏火把 → world:setBlock → 变更列表记录         │
│    → 新玩家加入时通过"种子+变更列表"同步                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 改动汇总

### 6.1 新增文件（5个）

| 文件 | 行数估计 | 说明 |
|------|---------|------|
| `Main.lua` | ~20 | 联网入口 |
| `network/Shared.lua` | ~80 | 共享定义 |
| `network/Server.lua` | ~300 | 服务器逻辑（含变更列表管理） |
| `network/Client.lua` | ~400 | 客户端逻辑（含世界同步处理） |
| `player/PlayerScript.lua` | ~60 | 网络玩家生命周期管理（ScriptObject） |

### 6.2 需要小改的文件（7个）

| 文件 | 改动 | 说明 |
|------|------|------|
| `player/Player.lua` | 添加 `fromNode(node, isLocal)` 方法 | 支持从已有节点创建玩家 |
| `world/ChunkMeshBuilder.lua` | 内部 `CreateChild/CreateComponent` 直接传 `LOCAL` | 区块网格渲染，服务器不调用 |
| `rendering/ParticleSystem.lua` | 内部 `CreateChild` 直接传 `LOCAL` | 方块破坏粒子，服务器不调用 |
| `player/FirstPersonArm.lua` | 内部 `CreateChild/CreateComponent` 直接传 `LOCAL` | 第一人称手臂，服务器不调用 |
| `player/CameraController.lua` | 内部 `CreateChild/CreateComponent` 直接传 `LOCAL` | 第三人称相机，服务器不调用 |
| `world/DayNightCycle.lua` | 内部 `CreateChild` 直接传 `LOCAL` | 光照系统，服务器不调用 |
| `terrain/TorchDecorator.lua` | **特殊**：分离数据层和渲染层 | 火把位置存入 World 数据，渲染部分用 LOCAL |

**示例**：
```lua
-- 改动前
local chunkNode = self.scene:CreateChild("Chunk_" .. chunkKey)

-- 改动后（直接传 LOCAL，无需判断）
local chunkNode = self.scene:CreateChild("Chunk_" .. chunkKey, LOCAL)
```

### 6.2.1 PlayerBody.lua 特殊处理

`player/PlayerBody.lua` 需要区分场景处理：

| 场景 | 处理方式 |
|------|---------|
| 单机模式 | 正常创建（无网络同步） |
| 联网本地玩家 | 用 LOCAL 模式创建（避免与服务器冲突） |
| 联网远程玩家 | 由 `Player:fromNode()` 创建（body 可见） |

```lua
-- PlayerBody.lua 改造示例
function PlayerBody:createBody()
    -- 判断是否需要 LOCAL 模式
    local mode = IsNetworkMode() and LOCAL or REPLICATED

    self.bodyNode = self.playerNode:CreateChild("PlayerBody", mode)
    -- ... 其余部件同样使用 mode
end
```

### 6.3 无需修改的文件

**配置和数据模块**（纯数据，无场景节点）：
- `config/GameConfig.lua` - 配置通用
- `config/GameEvents.lua` - 本地事件定义
- `data/BlockRegistry.lua` - 方块定义通用

**世界数据模块**（数据存储，无渲染）：
- `world/World.lua` - 数据结构通用（服务器/客户端都用）
- `world/WorldGenerator.lua` - 生成逻辑通用（确定性随机，数据存入 World）

**地形生成模块**（确定性算法，数据存入 World）：
- `terrain/BiomeGenerator.lua` - 确定性 Perlin 噪声
- `terrain/NoiseGenerator.lua` - 噪声工具函数
- `terrain/TreeDecorator.lua` - 确定性哈希，数据存入 World（WOOD/LEAVES 方块）
- `terrain/HouseGenerator.lua` - 使用 `setBlockRaw`，数据存入 World

**渲染资源模块**（纯资源管理，无场景节点创建）：
- `rendering/TextureAtlas.lua` - 纹理图集代理
- `rendering/texturepacks/TexturePackManager.lua` - 材质包管理
- `rendering/texturepacks/ClassicPack.lua` - 经典材质包
- `rendering/texturepacks/HDPack.lua` - HD 材质包

**UI 模块**（使用独立 UI 系统，与场景节点无关）：
- `ui/UIManager.lua` - UI 管理器
- `ui/Hotbar.lua` - 物品栏
- `ui/DebugOverlay.lua` - 调试面板

**玩家逻辑模块**（纯逻辑，可被服务器复用）：
- `player/PlayerController.lua` - 移动/碰撞逻辑
- `player/BlockInteraction.lua` - 方块交互逻辑（射线检测）

**开发工具**：
- `devtools/Benchmark.lua` - 性能测试工具

### 6.4 保留原单机入口

`main.lua` 保持不变，用于单机模式开发和测试。

---

## 7. 测试计划

### 7.1 阶段性测试

1. **基础连接**
   - [ ] 客户端能连接服务器
   - [ ] `ASSIGN_PLAYER` 事件正常发送/接收

2. **玩家同步**
   - [ ] 玩家节点在客户端可见
   - [ ] 位置同步正常（SmoothedTransform）
   - [ ] 多玩家互相可见

3. **输入同步**
   - [ ] WASD 移动正常
   - [ ] 鼠标视角正常
   - [ ] 跳跃正常

4. **方块操作**
   - [ ] 破坏方块同步
   - [ ] 放置方块同步
   - [ ] 粒子效果播放

5. **世界渲染**
   - [ ] 区块正常生成
   - [ ] 昼夜循环正常

---

## 8. 后续优化

### 8.1 短期优化
- [ ] 添加玩家名显示（头顶标签）
- [ ] 添加玩家皮肤/颜色区分

### 8.2 中期优化
- [ ] 客户端预测（减少延迟感）
- [ ] 区块按需加载（大世界支持）
- [ ] 断线重连

### 8.3 长期优化
- [ ] 存档/读档
- [ ] 权限系统
- [ ] 聊天系统

---

## 9. 关键设计决策总结

| 问题 | 决策 | 原因 |
|------|------|------|
| 世界同步方式 | 种子 + 变更列表 | 数据量小，实现简单 |
| 碰撞检测位置 | 服务器 | 防作弊，权威服务器 |
| 区块渲染节点 | 统一 LOCAL 模式 | 单机无影响，客户端避免冲突，服务器不调用 |
| 客户端渲染模块 | 统一 LOCAL 模式 | ParticleSystem、FirstPersonArm、CameraController、DayNightCycle 等仅客户端使用 |
| World 数据 | 服务器/客户端都有 | 服务器碰撞，客户端渲染 |
| 玩家输入 | connection.controls | 引擎原生支持 |
| 玩家位置同步 | REPLICATED 节点 | SmoothedTransform 自动插值 |
| 本地玩家身体 | LOCAL 模式 | 避免与服务器节点冲突，远程玩家由 PlayerScript 处理 |
| 玩家架构 | Player + PlayerController + PlayerScript | 职责分明：数据/操作/生命周期 |

---

*文档版本: 1.6*
*创建日期: 2026-01-27*
*更新历史:*
- *v1.3: 添加装饰器同步策略（5.4 节），TorchDecorator 改造方案*
- *v1.4: 完整代码审查，补充需要 LOCAL 模式的文件，添加 PlayerBody 特殊处理说明*
- *v1.5: Server.lua 必须复用 PlayerController 完整碰撞逻辑；从后续优化中移除碰撞检测和火把同步（均为第一版必须功能）*
- *v1.6: 重构玩家架构，职责分明（最小修改原则）：Player（数据/组件）+ PlayerController（操作/逻辑）+ PlayerScript（ScriptObject，网络生命周期）*
