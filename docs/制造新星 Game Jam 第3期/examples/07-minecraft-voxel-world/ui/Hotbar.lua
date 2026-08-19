-- ====================================================================
-- ui/Hotbar.lua
-- 物品栏 UI - 使用 urhox-libs/UI 系统重构
-- 美化版本：简化层次，保留底框，更现代的设计
-- ====================================================================

local UI = require("urhox-libs/UI/init")
local Blocks = require("data.BlockRegistry")

---@class Hotbar
---@field hotbarBlocks table
---@field player Player|nil
---@field onBlockSelected function|nil
---@field selectedIndex integer
---@field root Panel|nil
local Hotbar = {}
Hotbar.__index = Hotbar

-- 方块颜色映射 (用于显示方块类型)
local BLOCK_COLORS = {
    [Blocks.GRASS]      = {76, 153, 0, 255},    -- 草地绿
    [Blocks.DIRT]       = {139, 90, 43, 255},   -- 泥土棕
    [Blocks.STONE]      = {128, 128, 128, 255}, -- 石头灰
    [Blocks.WOOD]       = {139, 69, 19, 255},   -- 木头棕
    [Blocks.LEAVES]     = {34, 139, 34, 255},   -- 树叶绿
    [Blocks.SAND]       = {238, 214, 175, 255}, -- 沙子黄
    [Blocks.TALL_GRASS] = {102, 178, 76, 255},  -- 装饰草浅绿
    [Blocks.TORCH]      = {255, 180, 80, 255},  -- 火把橙黄色
    [Blocks.ROSE]          = {204, 51, 51, 255},   -- 玫瑰红
    [Blocks.FLOWER_YELLOW] = {230, 230, 50, 255},  -- 黄花
    [Blocks.FLOWER_BLUE]   = {50, 50, 230, 255},   -- 蓝花
}

-- 槽位尺寸配置
local SLOT_SIZE = 48
local SLOT_GAP = 6

---创建物品栏 UI
---@param player Player|nil Player实例（可选）
---@return Hotbar
function Hotbar.new(player)
    local self = setmetatable({}, Hotbar)
    self.player = player
    -- 默认只提供基础方块，装饰性方块需要开启相关功能后才有意义
    self.hotbarBlocks = { 
        Blocks.GRASS, Blocks.DIRT, Blocks.STONE, Blocks.WOOD, 
        Blocks.LEAVES, Blocks.SAND
    }
    self.root = nil
    self.slots = {}
    self.selectedIndex = 1
    return self
end

---创建单个物品槽
---@param index number 槽位索引 (1-6)
---@param blockType number 方块类型
---@return Widget 槽位 Widget
function Hotbar:createSlot(index, blockType)
    local isSelected = (index == self.selectedIndex)
    local color = BLOCK_COLORS[blockType] or {100, 100, 100, 255}
    
    local slot = UI.Panel {
        id = "slot_" .. index,
        width = SLOT_SIZE,
        height = SLOT_SIZE,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = color,
        borderRadius = 4,
        -- 选中时白色边框，未选中时深色边框（与底框区分）
        borderWidth = isSelected and 3 or 1,
        borderColor = isSelected and {255, 255, 255, 255} or {0, 0, 0, 60},
        
        -- 槽位编号（右下角小数字）
        UI.Label {
            text = tostring(index),
            position = "absolute",
            bottom = 2,
            right = 4,
            fontSize = 10,
            fontColor = isSelected and {255, 255, 255, 255} or {255, 255, 255, 150},
            textAlign = "right",
        },
    }
    
    return slot
end

---构建物品栏 UI 树
---@return Widget 物品栏根 Widget
function Hotbar:build()
    -- 获取选中的槽位名称
    local selectedBlock = self.hotbarBlocks[self.selectedIndex]
    local selectedName = Blocks:getDisplayName(selectedBlock)
    
    -- 创建物品栏容器
    self.root = UI.Panel {
        id = "hotbar_container",
        position = "absolute",
        bottom = 20,
        left = 0,
        right = 0,
        height = 110,
        flexDirection = "column",
        alignItems = "center",
        gap = 10,
        
        -- 选中方块名称（上方浮动显示）- 直接使用 Label + padding
        UI.Label {
            id = "selected_block_name",
            text = selectedName,
            fontSize = 14,
            fontColor = {255, 255, 255, 240},
            textAlign = "center",
            backgroundColor = {30, 30, 30, 200},
            borderRadius = 8,
            paddingHorizontal = 16,
            paddingVertical = 6,
        },
        
        -- 物品槽容器（添加半透明底框）
        UI.Row {
            id = "slots_row",
            gap = SLOT_GAP,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = {0, 0, 0, 150},
            borderRadius = 10,
            padding = 8,
            
            -- 动态创建物品槽
            table.unpack(self:createSlots())
        },
    }
    
    return self.root
end

---创建所有物品槽
---@return table Widget数组
function Hotbar:createSlots()
    local slots = {}
    self.slots = {}
    
    for i, blockType in ipairs(self.hotbarBlocks) do
        local slot = self:createSlot(i, blockType)
        slots[i] = slot
        self.slots[i] = slot
    end
    
    return slots
end

---获取物品栏根 Widget
---@return Widget|nil
function Hotbar:getRoot()
    return self.root
end

---更新物品栏显示
function Hotbar:update()
    if not self.root then return end
    
    -- 更新选中方块名称
    ---@type Label|nil
    local nameLabel = self.root:FindById("selected_block_name")
    if nameLabel then
        local selectedBlock = self.hotbarBlocks[self.selectedIndex]
        local selectedName = Blocks:getDisplayName(selectedBlock)
        nameLabel:SetText(selectedName)
    end
    
    -- 更新槽位样式
    for i, slot in ipairs(self.slots) do
        local isSelected = (i == self.selectedIndex)
        
        slot:SetStyle({
            borderWidth = isSelected and 3 or 1,
            borderColor = isSelected and {255, 255, 255, 255} or {0, 0, 0, 60},
        })
    end
end

---处理槽位选择
---@param index number 槽位索引（1-N）
function Hotbar:selectSlot(index)
    if index >= 1 and index <= #self.hotbarBlocks then
        self.selectedIndex = index
        -- 通知 player（如果存在）
        if self.player then
            self.player:selectSlot(index)
        end
        -- 触发回调（网络模式使用）
        if self.onBlockSelected then
            self.onBlockSelected(self.hotbarBlocks[index])
        end
        self:update()
    end
end

---获取选中的方块类型
---@return number 方块类型
function Hotbar:getSelectedBlock()
    return self.hotbarBlocks[self.selectedIndex]
end

return Hotbar
