-- ====================================================================
-- network/Server.lua
-- 多人游戏服务器入口（管理所有玩家，同步世界状态）
-- ====================================================================
--
-- ⚠️ AI 注意：这是【多人模式服务端】文件！
--
-- 如果用户正在开发多人模式：
--   - 服务端专用逻辑 → 放在本文件 (Server.lua)
--   - 客户端专用逻辑 → Client.lua
--   - 网络事件定义   → Shared.lua
--   - 通用功能       → player/, world/, ui/ 等独立模块
--
-- ====================================================================

local Config = require("config.GameConfig")
local World = require("world.World")
local WorldGenerator = require("world.WorldGenerator")
local PlayerController = require("player.PlayerController")
local Shared = require("network.Shared")

local Server = {}

-- 全局状态
---@type Scene
local scene_ = nil
---@type World
local world_ = nil
---@type WorldGenerator
local worldGenerator_ = nil
local players_ = {}  -- { [connection] = { connection, playerId, node, ... } }
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
    world_ = World.new()
    worldGenerator_ = WorldGenerator.new()
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
    scene_:CreateComponent("Octree", LOCAL)
    -- 服务器不需要光照和渲染
end

-- ============================================================================
-- 连接管理
-- ============================================================================

function HandleClientConnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    -- 注意：不要在这里设置 connection.scene，等客户端准备好再设置
    -- 否则会出现 "Can not handle LoadScene message without an assigned scene" 错误

    print("[Server] Client connected:", Shared.GetConnectionLabel(connection))
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")

    local playerInfo = players_[connection]
    if playerInfo then
        if playerInfo.node then
            playerInfo.node:Dispose()  -- 重要：用 Dispose 而非 Remove
        end
        players_[connection] = nil
        print("[Server] Player disconnected:", Shared.GetConnectionLabel(connection))
    end
end

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")

    -- 现在客户端已准备好，可以开始场景同步
    connection.scene = scene_
    print("[Server] Scene assigned to connection:", Shared.GetConnectionLabel(connection))

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
    playerNode:CreateScriptObject("player/PlayerScript.lua", "PlayerScript")

    -- 存储玩家信息
    players_[connection] = {
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
    local controls = conn.controls
    local yaw = controls.yaw
    local pitch = controls.pitch
    local buttons = controls.buttons

    playerInfo.yaw = yaw
    playerInfo.pitch = pitch

    -- 解析按钮状态
    local moveForward = (buttons & 1) ~= 0
    local moveBack = (buttons & 2) ~= 0
    local moveLeft = (buttons & 4) ~= 0
    local moveRight = (buttons & 8) ~= 0
    local jump = (buttons & 16) ~= 0
    local toggleFly = (buttons & 32) ~= 0  -- 飞行模式切换
    local flyDown = (buttons & 64) ~= 0  -- 飞行时下降（Shift）

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

    -- 为每个玩家创建独立的 PlayerController 实例
    if not playerInfo.controller then
        local playerAdapter = Server.CreatePlayerAdapter(playerInfo, node)
        playerInfo.controller = PlayerController.new(playerAdapter, world_)

        -- 创建虚拟 joystick 适配器（读取 playerInfo 中的输入状态）
        local virtualJoystick = {
            playerInfo = playerInfo,
            getMovement = function(self)
                local moveX, moveZ = 0, 0
                if self.playerInfo.moveForward then moveZ = moveZ + 1 end
                if self.playerInfo.moveBack then moveZ = moveZ - 1 end
                if self.playerInfo.moveLeft then moveX = moveX - 1 end
                if self.playerInfo.moveRight then moveX = moveX + 1 end
                return moveX, moveZ
            end
        }
        playerInfo.controller:setJoystick(virtualJoystick)

        -- 创建输入适配器（读取 playerInfo 中的按键状态）
        local inputAdapter = {
            playerInfo = playerInfo,
            getKeyDown = function(self, key)
                if key == KEY_SPACE then return self.playerInfo.jump or false end
                if key == KEY_SHIFT then return self.playerInfo.flyDown or false end
                if key == KEY_F then return self.playerInfo.toggleFly or false end
                return false
            end,
            getKeyPress = function(self, key)
                -- KeyPress 需要检测边沿（本帧按下，上帧未按下）
                if key == KEY_SPACE then
                    local current = self.playerInfo.jump or false
                    local last = self.playerInfo.lastJump or false
                    return current and not last
                end
                if key == KEY_F then
                    local current = self.playerInfo.toggleFly or false
                    local last = self.playerInfo.lastToggleFly or false
                    return current and not last
                end
                return false
            end
        }
        playerInfo.controller:setInputAdapter(inputAdapter)
    end

    -- 更新适配器状态
    playerInfo.controller.player.yaw = yaw
    playerInfo.controller.player.pitch = pitch

    -- 设置输入状态（供虚拟 joystick 和输入适配器读取）
    playerInfo.moveForward = moveForward
    playerInfo.moveBack = moveBack
    playerInfo.moveLeft = moveLeft
    playerInfo.moveRight = moveRight
    playerInfo.jump = jump
    playerInfo.flyDown = flyDown
    playerInfo.toggleFly = toggleFly

    -- 调用 PlayerController 的移动更新（包含完整碰撞检测、飞行模式）
    playerInfo.controller:updateMovement(timeStep)

    -- 更新上帧状态（用于边沿检测）
    playerInfo.lastJump = jump
    playerInfo.lastToggleFly = toggleFly
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
    local playerInfo = players_[connection]

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
