-- ====================================================================
-- network/Client.lua
-- 多人游戏客户端入口（连接服务器，接收同步数据）
-- ====================================================================
--
-- ⚠️ AI 注意：这是【多人模式客户端】文件！
--
-- 共享的游戏子系统（UI、特效、输入等）已提取到 core/GameSystems.lua
-- 本文件只包含网络客户端专用逻辑
--
-- ====================================================================

local Config = require("config.GameConfig")
local World = require("world.World")
local WorldGenerator = require("world.WorldGenerator")
local ChunkMeshBuilder = require("world.ChunkMeshBuilder")
local TextureAtlas = require("rendering.TextureAtlas")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")
local LoadingScreen = require("ui.LoadingScreen")
local Shared = require("network.Shared")
local BlockInteraction = require("player.BlockInteraction")
local GameSystems = require("core.GameSystems")

require "urhox-libs.UI.GameHUD"

local Client = {}

-- 全局状态
---@type Scene
local scene_ = nil
---@type World
local world_ = nil
---@type ChunkMeshBuilder
local chunkBuilder_ = nil
---@type Connection
local serverConnection_ = nil

-- 本地玩家
---@type integer|nil
local myPlayerId_ = nil
---@type Node
local myPlayerNode_ = nil
---@type Player
local myPlayer_ = nil
---@type Node
local cameraNode_ = nil
---@type Camera
local camera_ = nil

-- 输入状态
local yaw_ = 0
local pitch_ = 0
local selectedBlockType_ = 1

-- 光照
local lightGroup_ = nil
local zone_ = nil
local sunLight_ = nil

-- 方块交互
---@type BlockInteraction
local blockInteraction_ = nil

-- 加载状态
local loadingState_ = "init"
local loadingCoroutine_ = nil
local loadingProgress_ = { phase = "", current = 0, total = 1 }

-- 加载期间的事件队列
local pendingBlockChanges_ = {}

-- ============================================================================
-- 初始化
-- ============================================================================

function Client.Start()
    print("=== Minecraft Client Starting ===")

    -- 注册远程事件
    Shared.RegisterClientEvents()

    -- 获取服务器连接
    serverConnection_ = network:GetServerConnection()

    -- 创建场景
    Client.CreateScene()

    -- 关键：告诉网络层把复制的节点放到这个场景中
    serverConnection_.scene = scene_

    -- 创建本地世界（用于渲染）
    world_ = World.new()

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
    scene_:CreateComponent("Octree", LOCAL)

    -- 加载光照预设
    lightGroup_ = scene_:InstantiateXML("LightGroup/Daytime.xml", Vector3.ZERO, Quaternion.IDENTITY, LOCAL)

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

    print("[Client] Assigned player ID:", myPlayerId_, "seed:", worldSeed)

    -- 设置本地玩家 ID
    scene_:SetVar("LocalPlayerID", Variant(myPlayerId_))

    -- 初始化 UI 框架
    GameSystems:initUIFramework()

    -- 显示加载画面
    LoadingScreen.show()

    -- 创建纹理和区块构建器
    TexturePackManager:setCurrent("classic")
    local textureAtlas = TextureAtlas:new()
    local textures = textureAtlas:generate()

    chunkBuilder_ = ChunkMeshBuilder.new(world_, scene_)
    chunkBuilder_:setTextures(textures)

    -- 使用相同种子启动异步世界生成
    Config.Noise.SEED = worldSeed
    local worldGenerator = WorldGenerator.new()
    loadingCoroutine_ = worldGenerator:generateAsync(world_, 0, 0, function(phase, current, total)
        loadingProgress_ = { phase = phase, current = current, total = total }
    end)
    loadingState_ = "generating"

    print("[Client] World generation started (async)...")
end

function Client.StartChunkRendering()
    print("[Client] World generated, starting chunk rendering...")

    loadingCoroutine_ = chunkBuilder_:renderVisibleChunksAsync(Vector3(0, 0, 0), function(current, total)
        loadingProgress_ = { phase = "chunks", current = current, total = total }
    end)
    loadingState_ = "rendering"
end

function Client.OnWorldReady()
    print("[Client] Chunks rendered!")

    -- 应用加载期间缓存的方块变化
    if #pendingBlockChanges_ > 0 then
        print(string.format("[Client] Applying %d pending block changes...", #pendingBlockChanges_))
        for _, change in ipairs(pendingBlockChanges_) do
            world_:setBlock(change.x, change.y, change.z, change.block)
        end
        pendingBlockChanges_ = {}
    end

    loadingState_ = "ready"
    LoadingScreen.hide()

    -- 创建相机
    Client.CreateCamera()

    -- 初始化 GameSystems（共享子系统）
    GameSystems:init(scene_, cameraNode_, world_, {
        chunkBuilder = chunkBuilder_,
        lightGroup = lightGroup_,
        zone = zone_,
        sunLight = sunLight_,
    })

    -- 创建 UI
    GameSystems:createUI("Client", nil, function(blockType)
        selectedBlockType_ = blockType
    end)

    -- 创建移动端输入
    GameSystems:createMobileInput({
        on_look = function(deltaYaw, deltaPitch)
            yaw_ = yaw_ + deltaYaw
            pitch_ = pitch_ + deltaPitch
            pitch_ = math.max(-89, math.min(89, pitch_))
        end,
        on_tap = function()
            if blockInteraction_ then
                blockInteraction_:onLeftClick()
            end
        end,
        on_place = function()
            if blockInteraction_ then
                blockInteraction_:onRightClick()
            end
        end,
        autoMouseLocking = true,
    })

    print("[Client] Ready!")
end

function Client.CreateCamera()
    -- 加载景深（移动端不开启）
    local platform = GetPlatform()
    if platform ~= "Android" and platform ~= "iOS" then
        cameraNode_ = scene_:InstantiateXML("EngineRes/PostProcess/DOFPrefab.xml", Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
        cameraNode_.name = "Camera"
    else
        cameraNode_ = scene_:CreateChild("Camera", LOCAL)
    end
    camera_ = cameraNode_:CreateComponent("Camera", LOCAL)
    camera_.farClip = Config.Camera.FAR_CLIP
    camera_.fov = Config.Camera.FOV

    -- 设置初始相机位置
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local spawnY = world_:getGroundHeight(0, 0) + 1
    local eyeHeight = (Config.Player.HEIGHT - 0.2) * BLOCK_SIZE
    cameraNode_.position = Vector3(0, spawnY * BLOCK_SIZE + eyeHeight, 0)

    local viewport = Viewport:new(scene_, camera_)
    renderer:SetViewport(0, viewport)
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 加载中：处理协程
    if loadingState_ == "generating" then
        LoadingScreen.setProgress(loadingProgress_)
        if loadingCoroutine_ then
            local ok, err = coroutine.resume(loadingCoroutine_)
            if not ok then print("[Error] Coroutine error: " .. tostring(err)) end
            if coroutine.status(loadingCoroutine_) == "dead" then
                loadingCoroutine_ = nil
                Client.StartChunkRendering()
            end
        end
        return
    end

    if loadingState_ == "rendering" then
        LoadingScreen.setProgress(loadingProgress_)
        if loadingCoroutine_ then
            local ok, err = coroutine.resume(loadingCoroutine_)
            if not ok then print("[Error] Coroutine error: " .. tostring(err)) end
            if coroutine.status(loadingCoroutine_) == "dead" then
                loadingCoroutine_ = nil
                Client.OnWorldReady()
            end
        end
        return
    end

    -- 正常游戏状态
    Client.UpdateInput(timeStep)
    Client.UpdateCamera()
    
    -- 更新共享子系统
    GameSystems:update(timeStep)
end

function Client.UpdateInput(timeStep)
    if not serverConnection_ then return end

    -- PC 端鼠标视角
    local mobileInput = GameSystems:getMobileInput()
    if mobileInput and not mobileInput:isMobile() then
        local mouseMove = input.mouseMove
        local sensitivity = Config.Controls.MOUSE_SENSITIVITY
        yaw_ = yaw_ + mouseMove.x * sensitivity
        pitch_ = pitch_ + mouseMove.y * sensitivity
        pitch_ = math.max(-89, math.min(89, pitch_))
    end

    -- 同步到服务器
    serverConnection_.controls.yaw = yaw_
    serverConnection_.controls.pitch = pitch_

    -- 移动输入
    local buttons = 0
    if mobileInput then
        local moveX, moveZ = mobileInput:getMovement()
        if moveZ > 0.3 then buttons = buttons | 1 end
        if moveZ < -0.3 then buttons = buttons | 2 end
        if moveX < -0.3 then buttons = buttons | 4 end
        if moveX > 0.3 then buttons = buttons | 8 end
    else
        if input:GetKeyDown(KEY_W) then buttons = buttons | 1 end
        if input:GetKeyDown(KEY_S) then buttons = buttons | 2 end
        if input:GetKeyDown(KEY_A) then buttons = buttons | 4 end
        if input:GetKeyDown(KEY_D) then buttons = buttons | 8 end
    end

    if input:GetKeyDown(KEY_SPACE) then buttons = buttons | 16 end
    if input:GetKeyPress(KEY_F) then buttons = buttons | 32 end
    if input:GetKeyDown(KEY_SHIFT) then buttons = buttons | 64 end

    serverConnection_.controls.buttons = buttons
end

function Client.UpdateCamera()
    if not myPlayerId_ then return end

    -- 找到自己的玩家节点
    if not myPlayerNode_ then
        local children = scene_:GetChildren()
        for _, child in ipairs(children) do
            local idVar = child:GetVar(Shared.VARS.PLAYER_ID)
            if idVar and not idVar:IsEmpty() and idVar:GetInt() == myPlayerId_ then
                myPlayerNode_ = child
                print("[Client] Found player node:", child.name)
                break
            end
        end
        if not myPlayerNode_ then return end
    end

    -- 获取 Player 实例
    if not myPlayer_ and myPlayerNode_ then
        local scriptObject = myPlayerNode_:GetScriptObject()
        if scriptObject and scriptObject.GetPlayer then
            myPlayer_ = scriptObject:GetPlayer()
            if myPlayer_ then
                print("[Client] Got Player instance from PlayerScript")
                
                -- 更新 Hotbar 引用
                GameSystems:setHotbarPlayer(myPlayer_)

                -- 创建方块交互（联机模式）
                blockInteraction_ = BlockInteraction.new(myPlayer_, world_, {
                    isNetworkMode = true,
                    serverConnection = serverConnection_
                })
                blockInteraction_:setTorchDecorator(GameSystems:getTorchDecorator())
                print("[Client] BlockInteraction created (network mode)")
            end
        end
    end

    -- 更新相机
    if myPlayerNode_ and cameraNode_ then
        local playerPos = myPlayerNode_.position
        local BLOCK_SIZE = Config.World.BLOCK_SIZE
        local eyeHeight = (Config.Player.HEIGHT - 0.2) * BLOCK_SIZE

        cameraNode_.position = Vector3(playerPos.x, playerPos.y + eyeHeight, playerPos.z)
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0)

        if myPlayer_ then
            myPlayer_:setYaw(yaw_)
            myPlayer_:setPitch(pitch_)
            myPlayer_:updateCamera()
        end
    end
end

-- ============================================================================
-- 事件处理
-- ============================================================================

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    -- 先让 GameSystems 处理共享按键
    if GameSystems:handleKeyDown(key) then
        return
    end
    
    -- Client 专属按键可以在这里添加
end

function HandleMouseButtonDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    GameSystems:handleMouseButtonDown(button, blockInteraction_)
end

-- ============================================================================
-- 网络事件处理
-- ============================================================================

function HandleBlockChanged(eventType, eventData)
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local z = eventData["Z"]:GetInt()
    local newBlock = eventData["NewBlock"]:GetInt()

    if loadingState_ == "generating" or loadingState_ == "rendering" then
        table.insert(pendingBlockChanges_, { x = x, y = y, z = z, block = newBlock })
        return
    end

    world_:setBlock(x, y, z, newBlock)
end

function HandlePlayParticle(eventType, eventData)
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local z = eventData["Z"]:GetInt()
    local blockType = eventData["BlockType"]:GetInt()

    local particleSystem = GameSystems:getParticleSystem()
    if particleSystem then
        particleSystem:spawnBreakParticles(x, y, z, blockType)
    end
end

-- ============================================================================
-- 清理
-- ============================================================================

function Client.Stop()
    print("[Client] Shutting down...")
    GameSystems:destroy()
end

return Client
