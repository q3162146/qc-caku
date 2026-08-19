-- ====================================================================
-- data/BlockRegistry.lua
-- 方块注册表 - 数据驱动的方块系统
-- ====================================================================

local BlockRegistry = {
    blocks = {},       -- [id] = blockData
    byName = {},       -- [name] = blockData
}

-- ============================================
-- 方块 ID 常量 (保持向后兼容)
-- ============================================
BlockRegistry.AIR = 0
BlockRegistry.GRASS = 1
BlockRegistry.DIRT = 2
BlockRegistry.STONE = 3
BlockRegistry.WOOD = 4
BlockRegistry.LEAVES = 5
BlockRegistry.SAND = 6
BlockRegistry.WATER = 7
BlockRegistry.TALL_GRASS = 8  -- 装饰草
BlockRegistry.TORCH = 9       -- 火把（手持物品，有光源）
BlockRegistry.ROSE = 10
BlockRegistry.FLOWER_YELLOW = 11
BlockRegistry.FLOWER_BLUE = 12

-- ============================================
-- 方块注册方法
-- ============================================

---@param id number 方块 ID
---@param name string 方块内部名称
---@param config table 方块配置
---@return table block 注册的方块数据
function BlockRegistry:register(id, name, config)
    local block = {
        id = id,
        name = name,
        displayName = config.displayName or name,
        color = config.color or Color(0.5, 0.5, 0.5),
        textures = config.textures or { top = {0,2}, side = {0,2}, bottom = {0,2} },
        solid = config.solid ~= false,        -- 默认 true
        transparent = config.transparent or false,
        liquid = config.liquid or false,
        crossMesh = config.crossMesh or false,  -- 使用交叉网格渲染（X形插片）
        isItem = config.isItem or false,        -- 是否为手持物品（不是方块）
        hasLight = config.hasLight or false,    -- 是否有光源
        lightColor = config.lightColor,         -- 光源颜色
        lightRadius = config.lightRadius or 5,  -- 光源范围
    }
    
    self.blocks[id] = block
    self.byName[name] = block
    return block
end

---@param id number 方块 ID
---@return table|nil block 方块数据
function BlockRegistry:get(id)
    return self.blocks[id]
end

---@param name string 方块名称
---@return table|nil block 方块数据
function BlockRegistry:getByName(name)
    return self.byName[name]
end

---@param id number 方块 ID
---@return boolean 是否为实心方块
function BlockRegistry:isSolid(id)
    local block = self.blocks[id]
    return block and block.solid
end

---@param id number 方块 ID
---@return boolean 是否为透明方块
function BlockRegistry:isTransparent(id)
    local block = self.blocks[id]
    return not block or block.transparent
end

---@param id number 方块 ID
---@return boolean 是否为液体
function BlockRegistry:isLiquid(id)
    local block = self.blocks[id]
    return block and block.liquid
end

---@param id number 方块 ID
---@return boolean 是否使用交叉网格渲染
function BlockRegistry:isCrossMesh(id)
    local block = self.blocks[id]
    return block and block.crossMesh
end

---@param id number 方块 ID
---@return boolean 是否为手持物品
function BlockRegistry:isItem(id)
    local block = self.blocks[id]
    return block and block.isItem
end

---@param id number 方块 ID
---@return boolean 是否有光源
function BlockRegistry:hasLight(id)
    local block = self.blocks[id]
    return block and block.hasLight
end

---@param id number 方块 ID
---@return Color 方块颜色
function BlockRegistry:getColor(id)
    local block = self.blocks[id]
    return block and block.color or Color(0.5, 0.5, 0.5)
end

---@param id number 方块 ID
---@return string 方块显示名称
function BlockRegistry:getDisplayName(id)
    local block = self.blocks[id]
    return block and block.displayName or "Unknown"
end

---@return table 所有可放置的方块类型列表
function BlockRegistry:getPlaceableBlocks()
    local list = {}
    for id, block in pairs(self.blocks) do
        if id ~= BlockRegistry.AIR and id ~= BlockRegistry.WATER then
            table.insert(list, id)
        end
    end
    table.sort(list)
    return list
end

-- ============================================
-- 注册内置方块
-- ============================================

BlockRegistry:register(0, "air", {
    displayName = "Air",
    solid = false,
    transparent = true
})

BlockRegistry:register(1, "grass", {
    displayName = "Grass",
    color = Color(0.3, 0.8, 0.3),
    textures = { top = {0,0}, side = {0,1}, bottom = {0,2} }
})

BlockRegistry:register(2, "dirt", {
    displayName = "Dirt",
    color = Color(0.6, 0.4, 0.2),
    textures = { top = {0,2}, side = {0,2}, bottom = {0,2} }
})

BlockRegistry:register(3, "stone", {
    displayName = "Stone",
    color = Color(0.5, 0.5, 0.5),
    textures = { top = {0,3}, side = {0,3}, bottom = {0,3} }
})

BlockRegistry:register(4, "wood", {
    displayName = "Wood",
    color = Color(0.5, 0.3, 0.1),
    textures = { top = {1,0}, side = {1,1}, bottom = {1,0} }
})

BlockRegistry:register(5, "leaves", {
    displayName = "Leaves",
    color = Color(0.2, 0.6, 0.2),
    textures = { top = {1,2}, side = {1,2}, bottom = {1,2} },
    transparent = true  -- 树叶半透明
})

BlockRegistry:register(6, "sand", {
    displayName = "Sand",
    color = Color(0.9, 0.85, 0.6),
    textures = { top = {1,3}, side = {1,3}, bottom = {1,3} }
})

BlockRegistry:register(7, "water", {
    displayName = "Water",
    color = Color(0.2, 0.65, 1.0),
    textures = { top = {2,0}, side = {2,0}, bottom = {2,0} },
    solid = false,
    transparent = true,
    liquid = true
})

BlockRegistry:register(8, "tall_grass", {
    displayName = "Tall Grass",
    color = Color(0.4, 0.8, 0.3),
    textures = { top = {2,1}, side = {2,1}, bottom = {2,1} },  -- 纹理位置 Row2, Col1
    solid = false,
    transparent = true,
    crossMesh = true  -- 使用交叉网格渲染（X形）
})

BlockRegistry:register(9, "torch", {
    displayName = "Torch",
    color = Color(0.9, 0.7, 0.3),  -- 火把木棍颜色
    textures = { top = {2,2}, side = {2,2}, bottom = {2,2} },  -- 纹理位置 Row2, Col2 (Note: This might overlap if I use 2,2 for flower, wait. I should check if Torch uses 2,2 in HDPack. It seems HDPack fills it with gray. I will use 2,3 for flower to be safe, or check if Torch is actually rendered using that texture. The TorchDecorator probably uses a model or particle, but let's see. The registry says textures={2,2}. I'll use 2,3, 2,4, 2,5 for flowers to avoid conflict just in case.)
    solid = false,
    transparent = true,
    isItem = true,                 -- 这是一个手持物品，不是方块
    hasLight = true,               -- 有光源效果
    lightColor = Color(1.0, 0.8, 0.4),  -- 暖黄色火光
    lightRadius = 8,               -- 光照范围
})

BlockRegistry.ROSE = 10
BlockRegistry:register(10, "rose", {
    displayName = "Rose",
    color = Color(0.8, 0.2, 0.2),
    textures = { top = {2,3}, side = {2,3}, bottom = {2,3} },
    solid = false,
    transparent = true,
    crossMesh = true
})

BlockRegistry.FLOWER_YELLOW = 11
BlockRegistry:register(11, "flower_yellow", {
    displayName = "Yellow Flower",
    color = Color(0.9, 0.9, 0.2),
    textures = { top = {2,4}, side = {2,4}, bottom = {2,4} },
    solid = false,
    transparent = true,
    crossMesh = true
})

BlockRegistry.FLOWER_BLUE = 12
BlockRegistry:register(12, "flower_blue", {
    displayName = "Blue Flower",
    color = Color(0.2, 0.2, 0.9),
    textures = { top = {2,5}, side = {2,5}, bottom = {2,5} },
    solid = false,
    transparent = true,
    crossMesh = true
})

-- ============================================
-- 新增方块示例（只需一行注册！）
-- ============================================
-- BlockRegistry:register(8, "diamond_ore", {
--     displayName = "Diamond Ore",
--     color = Color(0.2, 0.8, 0.9),
--     textures = { top = {3,0}, side = {3,0}, bottom = {3,0} }
-- })

return BlockRegistry
