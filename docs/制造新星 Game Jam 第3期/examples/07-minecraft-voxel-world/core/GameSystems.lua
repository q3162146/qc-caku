-- ====================================================================
-- core/GameSystems.lua
-- 游戏子系统管理器 - 集中管理 Client 和 Standalone 共享的子系统
-- ====================================================================
--
-- 职责：
--   - 初始化和管理共享的游戏子系统（UI、特效、输入等）
--   - 统一 update 调用
--   - 统一按键处理
--   - 统一销毁逻辑
--
-- 使用方式：
--   local GameSystems = require("core.GameSystems")
--   GameSystems:init(scene, cameraNode, world, options)
--   GameSystems:update(timeStep)
--   GameSystems:destroy()
--
-- ====================================================================

local Config = require("config.GameConfig")
local SuffocationBox = require("ui.SuffocationBox")
local UnderwaterOverlay = require("ui.UnderwaterOverlay")
local DayNightCycle = require("world.DayNightCycle")
local ParticleSystem = require("rendering.ParticleSystem")
local TorchDecorator = require("terrain.TorchDecorator")
local UIManager = require("ui.UIManager")
local Hotbar = require("ui.Hotbar")
local MobileInputManager = require("ui.MobileInputManager")

---@class GameSystems
---@field scene Scene
---@field cameraNode Node
---@field world World
---@field suffocationBox SuffocationBox|nil
---@field underwaterOverlay UnderwaterOverlay|nil
---@field dayNightCycle DayNightCycle|nil
---@field particleSystem ParticleSystem|nil
---@field torchDecorator TorchDecorator|nil
---@field uiManager UIManager|nil
---@field hotbar Hotbar|nil
---@field mobileInput MobileInputManager|nil
---@field chunkBuilder ChunkMeshBuilder|nil
local GameSystems = {}
GameSystems.__index = GameSystems

-- ============================================================================
-- 初始化
-- ============================================================================

---初始化 UI 框架（在其他 UI 组件之前调用）
function GameSystems:initUIFramework()
    local UI = require("urhox-libs/UI/init")
    UI.Init({
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
        -- 推荐! DPR 缩放 + 小屏密度自适应（见 ui.md §10）
        -- 1 基准像素 ≈ 1 CSS 像素，尺寸遵循 CSS/Web 常识
        scale = UI.Scale.DEFAULT,
        autoEvents = true,
    })
end

---初始化游戏子系统
---@param scene Scene 场景
---@param cameraNode Node 相机节点
---@param world World 世界实例
---@param options table 配置选项
---@return GameSystems
function GameSystems:init(scene, cameraNode, world, options)
    options = options or {}
    
    self.scene = scene
    self.cameraNode = cameraNode
    self.world = world
    self.chunkBuilder = options.chunkBuilder
    
    -- 保存光照组件引用（用于昼夜循环）
    self.lightGroup = options.lightGroup
    self.zone = options.zone
    self.sunLight = options.sunLight
    
    -- 创建粒子系统
    self.particleSystem = ParticleSystem.new(scene, world)
    
    -- 创建火把装饰器
    self.torchDecorator = TorchDecorator.new(scene)
    
    -- 创建窒息盒子（相机穿墙时显示方块内部）
    if Config.Effects and Config.Effects.SUFFOCATION_BOX_ENABLED ~= false then
        self.suffocationBox = SuffocationBox.new(cameraNode, scene)
    end
    
    -- 创建水下效果覆盖层
    self.underwaterOverlay = UnderwaterOverlay.new(cameraNode, scene)
    
    -- 初始化昼夜循环
    if Config.DayNight and Config.DayNight.ENABLED then
        self.dayNightCycle = DayNightCycle.new({
            scene = scene,
            lightGroup = self.lightGroup,
            zone = self.zone,
            sunLight = self.sunLight,
            startTime = Config.DayNight.START_TIME,
            dayDuration = Config.DayNight.DAY_DURATION,
        })
    end
    
    return self
end

---创建 UI 系统
---@param gameMode string "Client" 或 "Standalone"
---@param player Player|nil 玩家实例（Standalone 模式需要）
---@param onBlockSelected function|nil 方块选择回调
function GameSystems:createUI(gameMode, player, onBlockSelected)
    self.uiManager = UIManager.new()
    self.uiManager:init()
    self.uiManager:setGameMode(gameMode)
    
    -- 创建 Hotbar
    self.hotbar = Hotbar.new(player)
    if onBlockSelected then
        self.hotbar.onBlockSelected = onBlockSelected
    end
    
    self.uiManager:setHotbar(self.hotbar)
    self.uiManager:build()
end

---创建移动端输入管理器
---@param options table 配置选项
function GameSystems:createMobileInput(options)
    self.mobileInput = MobileInputManager:new(options)
    self.mobileInput:init()
end

---更新 Hotbar 的玩家引用（用于 Client 延迟获取玩家）
---@param player Player
function GameSystems:setHotbarPlayer(player)
    if self.hotbar then
        self.hotbar.player = player
    end
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

---更新所有子系统
---@param timeStep number 时间步长
function GameSystems:update(timeStep)
    -- 更新昼夜循环
    if self.dayNightCycle then
        self.dayNightCycle:update(timeStep)
    end
    
    -- 更新火把效果（闪烁、粒子）
    if self.torchDecorator then
        self.torchDecorator:update(timeStep)
    end
    
    -- 重建脏区块
    if self.chunkBuilder then
        self.chunkBuilder:rebuildDirtyChunks()
    end
    
    -- 更新粒子
    if self.particleSystem then
        self.particleSystem:update(timeStep)
    end
    
    -- 更新 UI
    if self.uiManager then
        self.uiManager:update(timeStep)
    end
    
    -- 更新窒息盒子
    if self.suffocationBox and self.world then
        self.suffocationBox:update(self.world)
    end
    
    -- 更新水下效果
    if self.underwaterOverlay and self.world then
        self.underwaterOverlay:update(self.world)
    end
end

-- ============================================================================
-- 按键处理
-- ============================================================================

---处理共享的按键事件
---@param key number 按键码
---@return boolean 是否已处理（返回 true 则调用方不再处理）
function GameSystems:handleKeyDown(key)
    -- 快速切换到白天 (Y = daY)
    if key == KEY_Y and self.dayNightCycle then
        self.dayNightCycle:setTime(12)  -- 正午
        print("[DayNight] Time set to noon (12:00)")
        return true
    end
    
    -- 快速切换到夜晚 (N = Night)
    if key == KEY_N and self.dayNightCycle then
        self.dayNightCycle:setTime(0)  -- 午夜
        print("[DayNight] Time set to midnight (00:00)")
        return true
    end
    
    -- 切换快速时间流逝 (L = Lapse)
    if key == KEY_L and self.dayNightCycle then
        local currentScale = self.dayNightCycle:getTimeScale()
        if currentScale > 1 then
            self.dayNightCycle:setTimeScale(1.0)
            print("[DayNight] Time speed: NORMAL (1x)")
        else
            self.dayNightCycle:setTimeScale(60.0)
            print("[DayNight] Time speed: FAST (60x)")
        end
        return true
    end
    
    -- Hotbar 选择 (1-0, -)
    local hotbarKeys = {
        [KEY_1] = 1, [KEY_2] = 2, [KEY_3] = 3, [KEY_4] = 4,
        [KEY_5] = 5, [KEY_6] = 6, [KEY_7] = 7, [KEY_8] = 8,
        [KEY_9] = 9, [KEY_0] = 10, [KEY_MINUS] = 11,
    }
    if hotbarKeys[key] and self.hotbar then
        self.hotbar:selectSlot(hotbarKeys[key])
        return true
    end
    
    -- ESC 退出
    if key == KEY_ESCAPE then
        engine:Exit()
        return true
    end
    
    return false  -- 未处理，交给调用方
end

---处理共享的鼠标按键事件
---@param button number 鼠标按键
---@param blockInteraction BlockInteraction|nil 方块交互实例
---@return boolean 是否已处理
function GameSystems:handleMouseButtonDown(button, blockInteraction)
    -- 移动端由 VirtualControls 处理点击，跳过鼠标事件
    if VirtualControls.IsMobile() then
        return true
    end
    
    if not blockInteraction then
        return false
    end
    
    if button == MOUSEB_LEFT then
        blockInteraction:onLeftClick()
        return true
    elseif button == MOUSEB_RIGHT then
        blockInteraction:onRightClick()
        return true
    end
    
    return false
end

-- ============================================================================
-- 获取器
-- ============================================================================

---获取粒子系统
---@return ParticleSystem|nil
function GameSystems:getParticleSystem()
    return self.particleSystem
end

---获取火把装饰器
---@return TorchDecorator|nil
function GameSystems:getTorchDecorator()
    return self.torchDecorator
end

---获取移动输入管理器
---@return MobileInputManager|nil
function GameSystems:getMobileInput()
    return self.mobileInput
end

---获取 Hotbar
---@return Hotbar|nil
function GameSystems:getHotbar()
    return self.hotbar
end

---获取 UIManager
---@return UIManager|nil
function GameSystems:getUIManager()
    return self.uiManager
end

-- ============================================================================
-- 销毁
-- ============================================================================

---销毁所有子系统
function GameSystems:destroy()
    if self.mobileInput then
        self.mobileInput:destroy()
        self.mobileInput = nil
    end
    
    if self.suffocationBox then
        self.suffocationBox:destroy()
        self.suffocationBox = nil
    end
    
    if self.underwaterOverlay then
        self.underwaterOverlay:destroy()
        self.underwaterOverlay = nil
    end
    
    -- 清空其他引用
    self.particleSystem = nil
    self.torchDecorator = nil
    self.dayNightCycle = nil
    self.uiManager = nil
    self.hotbar = nil
    self.chunkBuilder = nil
    self.scene = nil
    self.cameraNode = nil
    self.world = nil
end

-- ============================================================================
-- 模块导出（简单单例）
-- ============================================================================

-- 直接返回 GameSystems 表，init 时会设置字段
return GameSystems

