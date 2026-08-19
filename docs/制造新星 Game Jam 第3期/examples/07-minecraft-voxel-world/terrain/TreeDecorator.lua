-- ====================================================================
-- terrain/TreeDecorator.lua
-- 树木装饰器 - 生成多种美观的树木结构
-- ====================================================================

local Blocks = require("data.BlockRegistry")

---@class TreeDecorator
local TreeDecorator = {}
TreeDecorator.__index = TreeDecorator

-- 树木类型
TreeDecorator.OAK = 1       -- 橡树：圆形树冠
TreeDecorator.BIRCH = 2     -- 桦树：细长柱状
TreeDecorator.SPRUCE = 3    -- 云杉：锥形层叠
TreeDecorator.BIG_OAK = 4   -- 大橡树：更大的树冠

---创建新的树木装饰器
---@return table TreeDecorator实例
function TreeDecorator.new()
    local instance = setmetatable({}, TreeDecorator)
    return instance
end

---确定性随机数生成器（基于坐标）
---@param x number
---@param z number
---@param salt number 盐值，用于不同用途
---@return number 0-1之间的随机数
function TreeDecorator:hash(x, z, salt)
    salt = salt or 0
    local h = (x * 73856093) ~ (z * 19349663) ~ (salt * 83492791)
    h = h % 10000
    return h / 10000.0
end

---根据位置确定树的类型
---@param x number
---@param z number
---@return number 树类型
function TreeDecorator:getTreeType(x, z)
    local chance = self:hash(x, z, 12345)
    if chance < 0.5 then
        return TreeDecorator.OAK      -- 50% 橡树
    elseif chance < 0.7 then
        return TreeDecorator.BIRCH    -- 20% 桦树
    elseif chance < 0.9 then
        return TreeDecorator.SPRUCE   -- 20% 云杉
    else
        return TreeDecorator.BIG_OAK  -- 10% 大橡树
    end
end

---在指定位置生成一棵树
---@param world table World实例
---@param x number 树干底部X坐标
---@param groundY number 地面Y坐标
---@param z number 树干底部Z坐标
function TreeDecorator:generateTree(world, x, groundY, z)
    local treeType = self:getTreeType(x, z)
    
    if treeType == TreeDecorator.OAK then
        self:generateOak(world, x, groundY, z)
    elseif treeType == TreeDecorator.BIRCH then
        self:generateBirch(world, x, groundY, z)
    elseif treeType == TreeDecorator.SPRUCE then
        self:generateSpruce(world, x, groundY, z)
    elseif treeType == TreeDecorator.BIG_OAK then
        self:generateBigOak(world, x, groundY, z)
    end
end

-- ============================================
-- 橡树 (Oak) - 经典圆形树冠
-- ============================================
function TreeDecorator:generateOak(world, x, groundY, z)
    -- 树高 4-6
    local trunkHeight = 4 + math.floor(self:hash(x, z, 1) * 3)
    
    -- 树干
    for ty = 1, trunkHeight do
        world:setBlockRaw(x, groundY + ty, z, Blocks.WOOD)
    end
    
    local leafY = groundY + trunkHeight
    
    -- 圆形树冠（使用欧几里得距离）
    -- 从下到上：半径 2.5 -> 2 -> 1.5 -> 顶部
    local layers = {
        { y = -1, radius = 2.5, density = 0.85 },
        { y = 0,  radius = 2.5, density = 0.9 },
        { y = 1,  radius = 2.0, density = 0.85 },
        { y = 2,  radius = 1.0, density = 0.95 },
    }
    
    for _, layer in ipairs(layers) do
        local ly = leafY + layer.y
        local r = layer.radius
        local rSq = r * r
        
        for lx = -math.ceil(r), math.ceil(r) do
            for lz = -math.ceil(r), math.ceil(r) do
                local distSq = lx * lx + lz * lz
                if distSq <= rSq then
                    -- 边缘有随机缺口，让树冠看起来更自然
                    local edgeFactor = distSq / rSq
                    local keepChance = layer.density - edgeFactor * 0.3
                    
                    if self:hash(x + lx, z + lz, ly) < keepChance then
                        local bx, by, bz = x + lx, ly, z + lz
                        if world:getBlock(bx, by, bz) == Blocks.AIR then
                            world:setBlockRaw(bx, by, bz, Blocks.LEAVES)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================
-- 桦树 (Birch) - 细长柱状树冠
-- ============================================
function TreeDecorator:generateBirch(world, x, groundY, z)
    -- 树高 5-7（比橡树高）
    local trunkHeight = 5 + math.floor(self:hash(x, z, 2) * 3)
    
    -- 树干
    for ty = 1, trunkHeight do
        world:setBlockRaw(x, groundY + ty, z, Blocks.WOOD)
    end
    
    local leafY = groundY + trunkHeight
    
    -- 细长的椭圆形树冠
    local layers = {
        { y = -2, radius = 1.5, density = 0.7 },
        { y = -1, radius = 2.0, density = 0.85 },
        { y = 0,  radius = 2.0, density = 0.9 },
        { y = 1,  radius = 1.5, density = 0.85 },
        { y = 2,  radius = 1.0, density = 0.8 },
        { y = 3,  radius = 0.5, density = 1.0 },
    }
    
    for _, layer in ipairs(layers) do
        local ly = leafY + layer.y
        local r = layer.radius
        local rSq = r * r
        
        for lx = -math.ceil(r), math.ceil(r) do
            for lz = -math.ceil(r), math.ceil(r) do
                local distSq = lx * lx + lz * lz
                if distSq <= rSq then
                    local edgeFactor = distSq / rSq
                    local keepChance = layer.density - edgeFactor * 0.2
                    
                    if self:hash(x + lx, z + lz, ly + 100) < keepChance then
                        local bx, by, bz = x + lx, ly, z + lz
                        if world:getBlock(bx, by, bz) == Blocks.AIR then
                            world:setBlockRaw(bx, by, bz, Blocks.LEAVES)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================
-- 云杉 (Spruce) - 经典圣诞树形状
-- ============================================
function TreeDecorator:generateSpruce(world, x, groundY, z)
    -- 树高 6-8
    local trunkHeight = 6 + math.floor(self:hash(x, z, 3) * 3)
    
    -- 树干
    for ty = 1, trunkHeight do
        world:setBlockRaw(x, groundY + ty, z, Blocks.WOOD)
    end
    
    -- 树叶从树干 55% 高度开始，一直延伸到树干顶部以上
    local leafStart = groundY + math.floor(trunkHeight * 0.55)
    local leafTop = groundY + trunkHeight + 1
    local totalLeafHeight = leafTop - leafStart
    
    -- 从底到顶逐层生成树叶
    for ly = leafStart, leafTop do
        local layerIndex = ly - leafStart
        local progress = layerIndex / totalLeafHeight  -- 0 = 底部, 1 = 顶部
        
        -- 锥形半径：底部宽，顶部窄但不会太小
        -- 确保即使在顶部也有足够半径包住树干
        local radius
        if progress < 0.7 then
            -- 底部到中部：正常锥形
            radius = 2.5 * (1 - progress * 0.6)
        else
            -- 顶部：保持最小 1.0 半径，确保包住树干
            radius = 1.0 + (1 - progress) * 0.5
        end
        
        -- 层叠效果：每隔一层稍微突出
        if layerIndex % 2 == 0 and progress < 0.6 then
            radius = radius + 0.5
        end
        
        local rSq = radius * radius
        
        for lx = -math.ceil(radius), math.ceil(radius) do
            for lz = -math.ceil(radius), math.ceil(radius) do
                local distSq = lx * lx + lz * lz
                if distSq <= rSq then
                    -- 边缘随机缺口，但中心区域保证生成
                    local edgeFactor = distSq / rSq
                    local keepChance = 0.9 - edgeFactor * 0.25
                    
                    if self:hash(x + lx, z + lz, ly + 200) < keepChance then
                        local bx, by, bz = x + lx, ly, z + lz
                        local existing = world:getBlock(bx, by, bz)
                        if existing == Blocks.AIR then
                            world:setBlockRaw(bx, by, bz, Blocks.LEAVES)
                        end
                    end
                end
            end
        end
    end
    
    -- 顶部尖顶（1格）
    world:setBlockRaw(x, leafTop + 1, z, Blocks.LEAVES)
end

-- ============================================
-- 大橡树 (Big Oak) - 高大修长，带根基
-- ============================================
function TreeDecorator:generateBigOak(world, x, groundY, z)
    -- 树高 10-14 (显著增高，更修长)
    local trunkHeight = 10 + math.floor(self:hash(x, z, 4) * 5)
    
    -- 主树干 (1x1，去除笨重的 2x2)
    for ty = 1, trunkHeight do
        world:setBlockRaw(x, groundY + ty, z, Blocks.WOOD)
    end
    
    -- 底部根基 (十字形支撑，稳固但不臃肿)
    world:setBlockRaw(x + 1, groundY + 1, z, Blocks.WOOD)
    world:setBlockRaw(x - 1, groundY + 1, z, Blocks.WOOD)
    world:setBlockRaw(x, groundY + 1, z + 1, Blocks.WOOD)
    world:setBlockRaw(x, groundY + 1, z - 1, Blocks.WOOD)
    
    local leafY = groundY + trunkHeight
    
    -- 轻盈树冠 (小半径、低密度、高通透)
    local layers = {
        { y = -2, radius = 2.0, density = 0.5 },
        { y = -1, radius = 2.5, density = 0.65 },
        { y = 0,  radius = 2.5, density = 0.7 },
        { y = 1,  radius = 2.0, density = 0.6 },
        { y = 2,  radius = 1.0, density = 0.7 },
    }
    
    for _, layer in ipairs(layers) do
        local ly = leafY + layer.y
        local r = layer.radius
        local rSq = r * r
        
        for lx = -math.ceil(r), math.ceil(r) do
            for lz = -math.ceil(r), math.ceil(r) do
                local distSq = lx * lx + lz * lz
                if distSq <= rSq then
                    -- 高随机性，让树冠更稀疏不规则
                    local edgeFactor = distSq / rSq
                    local keepChance = layer.density - edgeFactor * 0.4
                    
                    if self:hash(x + lx, z + lz, ly + 300) < keepChance then
                        local bx, by, bz = x + lx, ly, z + lz
                        if world:getBlock(bx, by, bz) == Blocks.AIR then
                            world:setBlockRaw(bx, by, bz, Blocks.LEAVES)
                        end
                    end
                end
            end
        end
    end
    
    -- 添加分叉树枝 (从树干中上部伸出)
    local branchStart = groundY + math.floor(trunkHeight * 0.6)
    local branchDirs = {
        {dx = 2, dy = 1, dz = 0},
        {dx = -2, dy = 2, dz = 0},
        {dx = 0, dy = 1, dz = 2},
        {dx = 0, dy = 3, dz = -2},
    }
    
    for i, dir in ipairs(branchDirs) do
        if self:hash(x, z, 500 + i) < 0.7 then
            local bx = x + dir.dx
            local by = branchStart + dir.dy
            local bz = z + dir.dz
            
            -- 树枝木头
            world:setBlockRaw(bx, by, bz, Blocks.WOOD)
            -- 连接处
            world:setBlockRaw(x + math.floor(dir.dx/2), by - math.floor(dir.dy/2), z + math.floor(dir.dz/2), Blocks.WOOD)
            
            -- 树枝末端加一点叶子
            world:setBlockRaw(bx, by + 1, bz, Blocks.LEAVES)
            world:setBlockRaw(bx + 1, by, bz, Blocks.LEAVES)
            world:setBlockRaw(bx - 1, by, bz, Blocks.LEAVES)
            world:setBlockRaw(bx, by, bz + 1, Blocks.LEAVES)
            world:setBlockRaw(bx, by, bz - 1, Blocks.LEAVES)
        end
    end
end

---检查位置是否可以放置树（周围没有其他树）
---@param world table World实例
---@param x number X坐标
---@param y number Y坐标（地面）
---@param z number Z坐标
---@return boolean 是否可以放置
function TreeDecorator:canPlaceTree(world, x, y, z)
    -- 检查更大范围，避免树木重叠
    for cx = -3, 3 do
        for cz = -3, 3 do
            if world:getBlock(x + cx, y + 1, z + cz) == Blocks.WOOD then
                return false
            end
            if world:getBlock(x + cx, y + 2, z + cz) == Blocks.WOOD then
                return false
            end
        end
    end
    return true
end

-- 模块级单例
local defaultDecorator = nil

---获取默认装饰器实例
---@return table TreeDecorator实例
function TreeDecorator.getDefault()
    if not defaultDecorator then
        defaultDecorator = TreeDecorator.new()
    end
    return defaultDecorator
end

return TreeDecorator
