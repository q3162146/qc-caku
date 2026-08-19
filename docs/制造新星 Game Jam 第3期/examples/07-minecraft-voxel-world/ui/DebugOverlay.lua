-- ====================================================================
-- ui/DebugOverlay.lua
-- 调试信息覆盖层 - 使用 urhox-libs/UI 系统重构
-- 美化版本：使用多行 Label 分别显示各项信息
-- ====================================================================

---@class Engine
---@field fps number 当前帧率

local UI = require("urhox-libs/UI/init")
local Config = require("config.GameConfig")

---@class DebugOverlay
---@field labels table<string, any>
---@field fps number
---@field player Player
---@field world World
local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

-- 调试信息项配置
local DEBUG_ITEMS = {
    { id = "fps",        label = "FPS" },
    { id = "position",   label = "Pos" },
    { id = "block",      label = "Block" },
    { id = "rotation",   label = "Rot" },
    { id = "ground",     label = "Ground" },
    { id = "velocity",   label = "Vel Y" },
    { id = "chunks",     label = "Chunks" },
    { id = "particles",  label = "Particles" },
    { id = "time",       label = "Time" },
    { id = "phase",      label = "Phase" },
}

---创建调试覆盖层
---@param player table Player实例
---@param world table World实例
---@return table DebugOverlay实例
function DebugOverlay.new(player, world)
    local self = setmetatable({}, DebugOverlay)
    self.player = player
    self.world = world
    self.root = nil
    self.labels = {}
    self.visible = false
    self.particleSystem = nil
    self.dayNightCycle = nil
    return self
end

---设置粒子系统引用
---@param particleSystem table ParticleSystem实例
function DebugOverlay:setParticleSystem(particleSystem)
    self.particleSystem = particleSystem
end

---设置昼夜循环系统引用
---@param dayNightCycle table DayNightCycle实例
function DebugOverlay:setDayNightCycle(dayNightCycle)
    self.dayNightCycle = dayNightCycle
end

---创建单行调试信息
---@param item table 配置项 { id, label }
---@return Widget
function DebugOverlay:createRow(item)
    return UI.Row {
        id = "row_" .. item.id,
        height = 16,
        alignItems = "center",
        gap = 6,
        
        -- 标签名称（固定宽度）
        UI.Label {
            text = item.label,
            width = 50,
            fontSize = 11,
            fontColor = {180, 180, 180, 255},
            textAlign = "left",
        },
        
        -- 值显示
        UI.Label {
            id = "value_" .. item.id,
            text = "--",
            fontSize = 11,
            fontColor = {255, 255, 255, 240},
            textAlign = "left",
        },
    }
end

---构建调试覆盖层 UI 树
---@return Widget 根 Widget
function DebugOverlay:build()
    -- 创建所有行
    local rows = {}
    for _, item in ipairs(DEBUG_ITEMS) do
        table.insert(rows, self:createRow(item))
    end
    
    self.root = UI.Panel {
        id = "debug_overlay",
        position = "absolute",
        top = 12,
        left = 12,
        minWidth = 180,
        backgroundColor = {20, 20, 20, 200},
        borderRadius = 6,
        padding = 10,
        flexDirection = "column",
        gap = 2,
        visible = self.visible,
        
        -- 标题行
        UI.Row {
            height = 20,
            alignItems = "center",
            marginBottom = 6,
            
            UI.Label {
                text = "Debug",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = {255, 220, 100, 255},
            },
            
            UI.Label {
                text = "  (F1)",
                fontSize = 10,
                fontColor = {150, 150, 150, 255},
            },
        },
        
        -- 分隔线
        UI.Panel {
            width = "100%",
            height = 1,
            backgroundColor = {255, 255, 255, 30},
            marginBottom = 6,
        },
        
        -- 调试信息行
        table.unpack(rows)
    }
    
    -- 存储标签引用
    for _, item in ipairs(DEBUG_ITEMS) do
        self.labels[item.id] = self.root:FindById("value_" .. item.id)
    end
    
    -- 根据初始可见状态设置
    if not self.visible then
        self.root:SetVisible(false)
    end
    
    return self.root
end

---获取根 Widget
---@return Widget|nil
function DebugOverlay:getRoot()
    return self.root
end

---切换可见性
function DebugOverlay:toggle()
    self.visible = not self.visible
    if self.root then
        self.root:SetVisible(self.visible)
    end
end

---设置可见性
---@param visible boolean
function DebugOverlay:setVisible(visible)
    self.visible = visible
    if self.root then
        self.root:SetVisible(visible)
    end
end

---更新调试信息
function DebugOverlay:update()
    if not self.visible then
        return
    end
    
    local pos = self.player:getPosition()
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local bx = math.floor(pos.x / BLOCK_SIZE)
    local by = math.floor(pos.y / BLOCK_SIZE)
    local bz = math.floor(pos.z / BLOCK_SIZE)
    
    local fps = engine.fps or 0
    local particleCount = 0
    if self.particleSystem then
        particleCount = self.particleSystem:getParticleCount()
    end
    
    -- 更新各个值
    if self.labels.fps then
        self.labels.fps:SetText(tostring(fps))
        -- FPS 颜色指示
        local fpsColor
        if fps >= 60 then
            fpsColor = {100, 255, 100, 255}  -- 绿色
        elseif fps >= 30 then
            fpsColor = {255, 255, 100, 255}  -- 黄色
        else
            fpsColor = {255, 100, 100, 255}  -- 红色
        end
        self.labels.fps:SetFontColor(fpsColor)
    end
    
    if self.labels.position then
        self.labels.position:SetText(string.format("%.1f, %.1f, %.1f", pos.x, pos.y, pos.z))
    end
    
    if self.labels.block then
        self.labels.block:SetText(string.format("%d, %d, %d", bx, by, bz))
    end
    
    if self.labels.rotation then
        self.labels.rotation:SetText(string.format("%.1f / %.1f", self.player:getYaw(), self.player:getPitch()))
    end
    
    if self.labels.ground then
        local onGround = self.player:getOnGround()
        self.labels.ground:SetText(onGround and "Yes" or "No")
        self.labels.ground:SetFontColor(onGround and {100, 255, 100, 255} or {255, 180, 100, 255})
    end
    
    if self.labels.velocity then
        self.labels.velocity:SetText(string.format("%.2f", self.player:getVelocity().y))
    end
    
    if self.labels.chunks then
        self.labels.chunks:SetText(string.format("%d / %d dirty", 
            self.world:getChunkCount(), 
            self.world:getDirtyChunkCount()))
    end
    
    if self.labels.particles then
        self.labels.particles:SetText(tostring(particleCount))
    end
    
    -- 昼夜循环信息
    if self.labels.time and self.dayNightCycle then
        local timeStr = self.dayNightCycle:getTimeString()
        -- 如果时间倍速不是 1x，显示倍速
        local scale = self.dayNightCycle:getTimeScale()
        if scale > 1 then
            timeStr = timeStr .. string.format(" (x%.0f)", scale)
        end
        self.labels.time:SetText(timeStr)
        -- 根据时间段设置颜色（快速模式时使用闪烁效果）
        local phase = self.dayNightCycle:getPhase()
        local timeColor
        if scale > 1 then
            timeColor = {255, 100, 100, 255}  -- 红色（快速模式）
        elseif phase == "day" then
            timeColor = {255, 220, 100, 255}  -- 金黄色（白天）
        elseif phase == "dawn" then
            timeColor = {255, 180, 120, 255}  -- 橙色（黎明）
        elseif phase == "dusk" then
            timeColor = {255, 140, 100, 255}  -- 深橙色（黄昏）
        else
            timeColor = {100, 150, 255, 255}  -- 蓝色（夜晚）
        end
        self.labels.time:SetFontColor(timeColor)
    elseif self.labels.time then
        self.labels.time:SetText("--")
    end
    
    if self.labels.phase and self.dayNightCycle then
        local phaseName = self.dayNightCycle:getPhaseDisplayName()
        self.labels.phase:SetText(phaseName)
    elseif self.labels.phase then
        self.labels.phase:SetText("--")
    end
end

return DebugOverlay
