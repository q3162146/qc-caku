-- ====================================================================
-- ui/MobileInputManager.lua
-- 输入管理器 - 统一管理虚拟摇杆、视角控制、攻击等
-- VirtualControls 内部自动处理 PC/移动端差异
-- ====================================================================

local Config = require("config.GameConfig")
require "urhox-libs.UI.VirtualControls"

---@class MobileInputManager
---@field config table 配置对象
---@field joystick VirtualJoystick|nil 虚拟摇杆
---@field touchLookArea TouchLookArea|nil 触摸视角区域
---@field jumpButton VirtualButton|nil 跳跃按钮
---@field placeButton VirtualButton|nil 放置按钮
---@field initialized boolean 是否已初始化
local MobileInputManager = {}
MobileInputManager.__index = MobileInputManager

---创建输入管理器
---@param config table 配置对象
---  - on_look: function(deltaYaw, deltaPitch) 视角回调（必需）
---  - on_tap: function() 点击回调（可选，若传入 blockInteraction 则自动生成）
---  - on_place: function() 放置回调（可选，若传入 blockInteraction 则自动生成）
---  - blockInteraction: BlockInteraction 方块交互对象（可选，自动生成 on_tap 和 on_place）
---  - playerController: PlayerController 玩家控制器（可选，用于 setMouseLocked）
---  - autoMouseLocking: boolean 是否自动处理鼠标锁定（默认 true）
---@return MobileInputManager
function MobileInputManager:new(config)
    local self = setmetatable({}, MobileInputManager)

    self.config = config or {}
    self.joystick = nil
    self.touchLookArea = nil
    self.jumpButton = nil
    self.initialized = false

    -- 如果提供了 blockInteraction 但没有 on_tap/on_place，自动生成
    if self.config.blockInteraction then
        if not self.config.on_tap then
            self.config.on_tap = function()
                self.config.blockInteraction:onLeftClick()
            end
        end
        if not self.config.on_place then
            self.config.on_place = function()
                self.config.blockInteraction:onRightClick()
            end
        end
    end

    -- autoMouseLocking 默认为 true
    if self.config.autoMouseLocking == nil then
        self.config.autoMouseLocking = true
    end

    return self
end

---初始化虚拟控件
---VirtualControls 自动处理平台差异，无需手动判断
function MobileInputManager:init()
    VirtualControls.Initialize()
    
    -- 左侧摇杆（PC/移动端通用，始终显示）
    self.joystick = VirtualControls.CreateJoystick({
        position = Vector2(260, -260),
        alignment = {HA_LEFT, VA_BOTTOM},
        baseRadius = 150,         -- 底盘半径（与 GameHUD 一致）
        knobRadius = 60,          -- 摇杆头半径
        moveRadius = 110,         -- 移动范围
        pressRegionRadius = 250,  -- 可点击区域半径
        keyBinding = "WASD",      -- PC 端同时支持键盘
        alwaysShow = true,        -- 所有平台都显示摇杆
    })
    
    -- 右侧触摸视角区域（仅移动端生效，PC 端由鼠标处理）
    self.touchLookArea = VirtualControls.CreateTouchLookArea({
        regionPreset = "right_half",
        sensitivity = Config.Controls.TOUCH_LOOK_SENSITIVITY or 0.15,
        tapMaxDistance = Config.Controls.TOUCH_TAP_MAX_DISTANCE or 10,
        tapMaxDuration = Config.Controls.TOUCH_TAP_MAX_DURATION or 300,
        
        on_look = function(deltaYaw, deltaPitch)
            if self.config.on_look then
                self.config.on_look(deltaYaw, deltaPitch)
            end
        end,
        
        on_tap = function()
            if self.config.on_tap then
                self.config.on_tap()
            end
        end,
    })
    
    -- 跳跃按钮（PC/移动端通用，始终显示）
    self.jumpButton = VirtualControls.CreateButton({
        position = Vector2(-150, -150),   -- 与 GameHUD 标准一致
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 60,              -- 与 GameHUD 标准按钮一致
        label = "Jump",
        keyBinding = "SPACE",
        alwaysShow = true,        -- 所有平台都显示按钮
    })
    
    -- 放置按钮（放置方块，仅移动端显示，PC 端用鼠标右键）
    -- 注：移动端点击屏幕已经是破坏方块，所以这里提供放置功能
    self.placeButton = VirtualControls.CreateButton({
        position = Vector2(-150, -300),   -- 跳跃按钮上方（间距 150）
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 60,              -- 与跳跃按钮一致
        label = "Place",
        -- PC 端由 Standalone/Client 的 HandleMouseButtonDown 处理鼠标右键
        alwaysShow = false,       -- 仅移动端显示
        color = {100, 200, 100},          -- 绿色表示放置/建造
        pressedColor = {150, 230, 150},
        on_press = function()
            -- 优先使用 on_place 回调（支持延迟检查模式，用于 Client.lua）
            if self.config.on_place then
                self.config.on_place()
            elseif self.config.blockInteraction then
                self.config.blockInteraction:onRightClick()
            end
        end,
    })
    
    -- 自动处理鼠标锁定
    if self.config.autoMouseLocking then
        if self:isMobile() then
            -- 如果提供了 playerController，禁用其鼠标控制
            if self.config.playerController then
                self.config.playerController:setMouseLocked(false)
            end
        else
            input.mouseMode = MM_RELATIVE
        end
    end
    
    self.initialized = true
    print("[MobileInputManager] Initialized (mobile=" .. tostring(VirtualControls.IsMobile()) .. ")")
end

---获取摇杆移动输入（PC/移动端通用）
---@return number, number x, z 移动值 (-1 到 1)
function MobileInputManager:getMovement()
    if self.joystick then
        return self.joystick:getMovement()
    end
    return 0, 0
end

---检查是否为移动端
---@return boolean
function MobileInputManager:isMobile()
    return VirtualControls.IsMobile()
end

---销毁
function MobileInputManager:destroy()
    VirtualControls.Clear()
    self.initialized = false
end

return MobileInputManager
