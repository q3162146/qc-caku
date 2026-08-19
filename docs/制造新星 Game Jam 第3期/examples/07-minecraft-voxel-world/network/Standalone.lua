-- ====================================================================
-- network/Standalone.lua
-- 单机模式入口（无网络，本地运行）
-- ====================================================================
--
-- ⚠️ AI 注意：这是【单机模式专用】文件！
--
-- 共享的游戏子系统（UI、特效、输入等）已提取到 core/GameSystems.lua
-- 本文件只包含单机模式专用逻辑（本地世界生成、玩家物理等）
--
-- ====================================================================

local Config = require("config.GameConfig")
local World = require("world.World")
local WorldGenerator = require("world.WorldGenerator")
local ChunkMeshBuilder = require("world.ChunkMeshBuilder")
local TextureAtlas = require("rendering.TextureAtlas")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")
local LoadingScreen = require("ui.LoadingScreen")
local Player = require("player.Player")
local PlayerController = require("player.PlayerController")
local BlockInteraction = require("player.BlockInteraction")
local Benchmark = require("devtools.Benchmark")
local GameSystems = require("core.GameSystems")

require "urhox-libs.UI.GameHUD"

local Standalone = {}

-- 全局状态
---@type Scene
local scene_ = nil
---@type World
local world_ = nil
---@type WorldGenerator
local worldGenerator_ = nil
---@type ChunkMeshBuilder
local chunkBuilder_ = nil
---@type Player|nil
local player_ = nil
---@type PlayerController
local playerController_ = nil
---@type BlockInteraction
local blockInteraction_ = nil
---@type Node
local cameraNode_ = nil
---@type Camera
local camera_ = nil

-- 输入状态
local selectedBlockType_ = 1

-- 光照
local lightGroup_ = nil
local zone_ = nil
local sunLight_ = nil

-- 性能测试
local benchmark_ = nil

-- 加载状态
local loadingState_ = "init"
local loadingCoroutine_ = nil
local loadingProgress_ = { phase = "", current = 0, total = 1 }

-- ============================================================================
-- 初始化
-- ============================================================================

function Standalone.Start()
    print("=== Minecraft Standalone Starting ===")

    -- 创建场景
    Standalone.CreateScene()

    -- 创建世界（空）
    world_ = World.new()
    worldGenerator_ = WorldGenerator.new()

    -- 创建纹理和区块构建器
    TexturePackManager:setCurrent("classic")
    local textureAtlas = TextureAtlas:new()
    local textures = textureAtlas:generate()

    chunkBuilder_ = ChunkMeshBuilder.new(world_, scene_)
    chunkBuilder_:setTextures(textures)

    -- 初始化 UI 框架
    GameSystems:initUIFramework()

    -- 显示加载画面
    LoadingScreen.show()

    -- 启动异步世界生成
    loadingCoroutine_ = worldGenerator_:generateAsync(world_, 0, 0, function(phase, current, total)
        loadingProgress_ = { phase = phase, current = current, total = total }
    end)
    loadingState_ = "generating"

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseButtonDown")

    print("[Standalone] World generation started (async)...")
end

function Standalone.CreateScene()
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

function Standalone.StartChunkRendering()
    print("[Standalone] World generated, starting chunk rendering...")

    local spawnX, spawnZ = 0, 0
    local spawnY = world_:getGroundHeight(spawnX, spawnZ) + 1
    local spawnPos = Vector3(
        spawnX * Config.World.BLOCK_SIZE,
        spawnY * Config.World.BLOCK_SIZE,
        spawnZ * Config.World.BLOCK_SIZE
    )

    loadingCoroutine_ = chunkBuilder_:renderVisibleChunksAsync(spawnPos, function(current, total)
        loadingProgress_ = { phase = "chunks", current = current, total = total }
    end)
    loadingState_ = "rendering"
end

function Standalone.OnWorldReady()
    print("[Standalone] World generated!")
    loadingState_ = "ready"
    LoadingScreen.hide()

    -- 计算出生点
    local spawnX, spawnZ = 0, 0
    local spawnY = world_:getGroundHeight(spawnX, spawnZ) + 1
    local spawnPos = Vector3(
        spawnX * Config.World.BLOCK_SIZE,
        spawnY * Config.World.BLOCK_SIZE,
        spawnZ * Config.World.BLOCK_SIZE
    )

    -- 创建本地玩家
    player_ = Player.new(scene_)
    player_:setPosition(spawnPos)

    -- 创建玩家控制器
    playerController_ = PlayerController.new(player_, world_)

    -- 使用玩家自带的相机
    cameraNode_ = player_:getCameraNode()
    camera_ = player_:getCamera()

    -- 设置视口
    local viewport = Viewport:new(scene_, camera_)
    renderer:SetViewport(0, viewport)

    -- 初始化 GameSystems（共享子系统）
    GameSystems:init(scene_, cameraNode_, world_, {
        chunkBuilder = chunkBuilder_,
        lightGroup = lightGroup_,
        zone = zone_,
        sunLight = sunLight_,
    })

    -- 创建方块交互（单机模式）
    blockInteraction_ = BlockInteraction.new(player_, world_, {
        isNetworkMode = false
    })
    blockInteraction_:setTorchDecorator(GameSystems:getTorchDecorator())
    blockInteraction_:setParticleSystem(GameSystems:getParticleSystem())

    -- 创建 UI
    GameSystems:createUI("Standalone", player_, function(blockType)
        selectedBlockType_ = blockType
    end)

    -- 创建移动端输入
    GameSystems:createMobileInput({
        on_look = function(deltaYaw, deltaPitch)
            playerController_:applyLookDelta(deltaYaw, deltaPitch)
        end,
        blockInteraction = blockInteraction_,
        playerController = playerController_,
        autoMouseLocking = true,
    })

    -- 设置摇杆
    local mobileInput = GameSystems:getMobileInput()
    if mobileInput then
        playerController_:setJoystick(mobileInput.joystick)
    end

    -- 创建性能测试工具
    benchmark_ = Benchmark.new(world_, blockInteraction_, chunkBuilder_, worldGenerator_)

    print("=== Minecraft Standalone Ready ===")
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
                Standalone.StartChunkRendering()
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
                Standalone.OnWorldReady()
            end
        end
        return
    end

    -- 正常游戏状态
    
    -- Standalone 专属：本地玩家更新
    if playerController_ then
        playerController_:updateMouseLook(timeStep)
        playerController_:updateMovement(timeStep)
    end
    if player_ then
        player_:update(timeStep)
    end

    -- 更新共享子系统
    GameSystems:update(timeStep)
end

-- ============================================================================
-- 事件处理
-- ============================================================================

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- Standalone 专属：性能测试按键
    if key == KEY_B and benchmark_ then
        benchmark_:runChunkRebuildTest()
        return
    end
    if key == KEY_P and benchmark_ then
        benchmark_:runAll(false)
        return
    end
    if key == KEY_O and benchmark_ then
        benchmark_:runAll(true)
        return
    end

    -- 共享按键处理
    if GameSystems:handleKeyDown(key) then
        return
    end
end

function HandleMouseButtonDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    GameSystems:handleMouseButtonDown(button, blockInteraction_)
end

-- ============================================================================
-- 清理
-- ============================================================================

function Standalone.Stop()
    print("[Standalone] Shutting down...")
    GameSystems:destroy()
end

return Standalone
