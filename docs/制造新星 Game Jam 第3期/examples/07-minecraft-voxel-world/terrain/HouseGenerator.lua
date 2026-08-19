-- ====================================================================
-- terrain/HouseGenerator.lua
-- 房屋生成器 - 在出生点附近生成一栋漂亮的小木屋
-- 参考图片：Minecraft风格的木质小屋，带石头地基、烟囱和花坛
-- ====================================================================

local Blocks = require("data.BlockRegistry")

-- ====================================================================
-- 房屋配置常量
-- ====================================================================
local HOUSE_CONFIG = {
    -- 房屋尺寸
    width = 12,           -- X方向宽度
    depth = 10,           -- Z方向深度
    wallHeight = 5,       -- 墙壁高度
    roofHeight = 5,       -- 屋顶高度
    
    -- 地面处理
    clearMargin = 8,      -- 清理地面时的额外边距
    flattenMargin = 4,    -- 平整地基时的额外边距
    clearHeight = 25,     -- 清理地面的高度范围
    
    -- 角柱高度
    cornerPillarHeight = 6,
    
    -- 门廊
    porchWidth = 3,       -- 门廊半宽
    porchDepth = 2,       -- 门廊深度
    porchPillarHeight = 3,-- 门廊支柱高度
}

---@class HouseGenerator
---@field config table
local HouseGenerator = {}
HouseGenerator.__index = HouseGenerator

---创建新的房屋生成器
---@param config table|nil 可选的自定义配置
---@return table HouseGenerator实例
function HouseGenerator.new(config)
    local self = setmetatable({}, HouseGenerator)
    -- 合并自定义配置（如果提供）
    self.config = config or HOUSE_CONFIG
    return self
end

-- ====================================================================
-- 辅助方法
-- ====================================================================

---在指定范围内清理地面（移除树木、草丛等）
---@param world table World实例
---@param cx number 中心X坐标
---@param cz number 中心Z坐标
---@param width number 宽度
---@param depth number 深度
---@param groundY number 地面Y坐标
function HouseGenerator:clearGround(world, cx, cz, width, depth, groundY)
    local cfg = self.config
    local halfW = math.floor(width / 2) + 2  -- 额外留2格边距
    local halfD = math.floor(depth / 2) + 2
    local clearHeight = cfg.clearHeight or 25
    
    -- 清理地上的所有非地面方块（树木、草丛等）
    for x = cx - halfW, cx + halfW do
        for z = cz - halfD, cz + halfD do
            -- 从地面以上开始清理，一直到顶部
            for y = groundY + 1, groundY + clearHeight do
                local block = world:getBlock(x, y, z)
                if block ~= Blocks.AIR then
                    world:setBlockRaw(x, y, z, Blocks.AIR)
                end
            end
            -- 确保地面是草地
            local groundBlock = world:getBlock(x, groundY, z)
            if groundBlock == Blocks.AIR or groundBlock == Blocks.WATER then
                world:setBlockRaw(x, groundY, z, Blocks.GRASS)
            end
        end
    end
    
    print(string.format("[HouseGenerator] Cleared ground at (%d, %d) size %dx%d", cx, cz, width, depth))
end

---找到合适的地面高度
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
---@return number 地面Y坐标
function HouseGenerator:findGroundLevel(world, x, z)
    return world:getGroundHeight(x, z) - 1
end

---找到区域内的平均地面高度
---@param world table World实例
---@param cx number 中心X坐标
---@param cz number 中心Z坐标
---@param width number 宽度
---@param depth number 深度
---@return number 平均地面Y坐标
function HouseGenerator:findAverageGroundLevel(world, cx, cz, width, depth)
    local totalY = 0
    local count = 0
    local halfW = math.floor(width / 2)
    local halfD = math.floor(depth / 2)
    
    for x = cx - halfW, cx + halfW, 2 do
        for z = cz - halfD, cz + halfD, 2 do
            local y = self:findGroundLevel(world, x, z)
            totalY = totalY + y
            count = count + 1
        end
    end
    
    return math.floor(totalY / count)
end

---平整地基
---@param world table World实例
---@param cx number 中心X坐标
---@param cz number 中心Z坐标
---@param width number 宽度
---@param depth number 深度
---@param targetY number 目标高度
function HouseGenerator:flattenGround(world, cx, cz, width, depth, targetY)
    local halfW = math.floor(width / 2)
    local halfD = math.floor(depth / 2)
    
    for x = cx - halfW, cx + halfW do
        for z = cz - halfD, cz + halfD do
            -- 填充或挖掘到目标高度
            local currentY = self:findGroundLevel(world, x, z)
            if currentY < targetY then
                -- 需要填充
                for y = currentY + 1, targetY do
                    world:setBlockRaw(x, y, z, Blocks.DIRT)
                end
                world:setBlockRaw(x, targetY, z, Blocks.GRASS)
            elseif currentY > targetY then
                -- 需要挖掘（清除上方）
                for y = targetY + 1, currentY do
                    world:setBlockRaw(x, y, z, Blocks.AIR)
                end
            end
        end
    end
end

-- ====================================================================
-- 房屋建造
-- ====================================================================

---在指定位置生成小木屋
---@param world table World实例
---@param centerX number 中心X坐标
---@param centerZ number 中心Z坐标
function HouseGenerator:generate(world, centerX, centerZ)
    local cfg = self.config
    
    -- 房屋尺寸（从配置读取）
    local houseWidth = cfg.width
    local houseDepth = cfg.depth
    local wallHeight = cfg.wallHeight
    local roofHeight = cfg.roofHeight
    
    -- 找到合适的地面高度
    local groundY = self:findAverageGroundLevel(world, centerX, centerZ, houseWidth + 6, houseDepth + 6)
    
    print(string.format("[HouseGenerator] Building house at (%d, %d, %d)", centerX, groundY, centerZ))
    
    -- 1. 清理地面
    self:clearGround(world, centerX, centerZ, houseWidth + cfg.clearMargin, houseDepth + cfg.clearMargin, groundY)
    
    -- 2. 平整地基
    self:flattenGround(world, centerX, centerZ, houseWidth + cfg.flattenMargin, houseDepth + cfg.flattenMargin, groundY)
    
    -- 房屋边界
    local x1 = centerX - math.floor(houseWidth / 2)
    local x2 = centerX + math.floor(houseWidth / 2)
    local z1 = centerZ - math.floor(houseDepth / 2)
    local z2 = centerZ + math.floor(houseDepth / 2)
    local floorY = groundY + 1
    
    -- 3. 建造石头地基
    self:buildFoundation(world, x1, z1, x2, z2, groundY)
    
    -- 4. 建造木质墙壁
    self:buildWalls(world, x1, z1, x2, z2, floorY, wallHeight)
    
    -- 5. 建造屋顶
    self:buildRoof(world, x1, z1, x2, z2, floorY + wallHeight, roofHeight)
    
    -- 6. 建造门窗
    self:buildDoorAndWindows(world, x1, z1, x2, z2, floorY)
    
    -- 7. 建造烟囱
    self:buildChimney(world, x2 - 1, z2 - 1, floorY + wallHeight + roofHeight)
    
    -- 8. 建造门廊
    self:buildPorch(world, x1, z1, x2, z2, floorY)
    
    -- 9. 建造花坛和装饰
    self:buildDecorations(world, x1, z1, x2, z2, floorY)
    
    -- 10. 放置灯光（火把）
    self:placeTorches(world, x1, z1, x2, z2, floorY, wallHeight)
    
    -- 11. 标记受影响的区块为脏，使用 World 的高层 API
    local chunkCount = world:markAreaDirtyAndRecalcHeight(x1 - 2, z1 - 4, x2 + 2, z2 + 4)
    
    print(string.format("[HouseGenerator] House built at (%d, %d, %d)! Updated %d chunks.", 
        centerX, groundY, centerZ, chunkCount))
end

---建造石头地基
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param groundY number 地面Y
function HouseGenerator:buildFoundation(world, x1, z1, x2, z2, groundY)
    local cfg = self.config
    local cornerPillarHeight = cfg.cornerPillarHeight or 6
    
    -- 石头地基（地面层）
    for x = x1, x2 do
        for z = z1, z2 do
            world:setBlockRaw(x, groundY, z, Blocks.STONE)
        end
    end
    
    -- 石头角柱 (比墙壁高1格)
    local corners = {
        {x1, z1}, {x1, z2}, {x2, z1}, {x2, z2}
    }
    for _, corner in ipairs(corners) do
        for y = groundY, groundY + cornerPillarHeight do
            world:setBlockRaw(corner[1], y, corner[2], Blocks.STONE)
        end
    end
end

---建造木质墙壁
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param floorY number 地板Y
---@param height number 墙壁高度
function HouseGenerator:buildWalls(world, x1, z1, x2, z2, floorY, height)
    -- 前墙 (Z = z1)
    for x = x1, x2 do
        for y = floorY, floorY + height - 1 do
            world:setBlockRaw(x, y, z1, Blocks.WOOD)
        end
    end
    
    -- 后墙 (Z = z2)
    for x = x1, x2 do
        for y = floorY, floorY + height - 1 do
            world:setBlockRaw(x, y, z2, Blocks.WOOD)
        end
    end
    
    -- 左墙 (X = x1)
    for z = z1, z2 do
        for y = floorY, floorY + height - 1 do
            world:setBlockRaw(x1, y, z, Blocks.WOOD)
        end
    end
    
    -- 右墙 (X = x2)
    for z = z1, z2 do
        for y = floorY, floorY + height - 1 do
            world:setBlockRaw(x2, y, z, Blocks.WOOD)
        end
    end
    
    -- 地板（木质）
    for x = x1 + 1, x2 - 1 do
        for z = z1 + 1, z2 - 1 do
            world:setBlockRaw(x, floorY, z, Blocks.WOOD)
        end
    end
    
    -- 石头边框装饰（墙壁底部和顶部）
    for x = x1, x2 do
        world:setBlockRaw(x, floorY, z1, Blocks.STONE)
        world:setBlockRaw(x, floorY, z2, Blocks.STONE)
        world:setBlockRaw(x, floorY + height - 1, z1, Blocks.STONE)
        world:setBlockRaw(x, floorY + height - 1, z2, Blocks.STONE)
    end
    for z = z1, z2 do
        world:setBlockRaw(x1, floorY, z, Blocks.STONE)
        world:setBlockRaw(x2, floorY, z, Blocks.STONE)
        world:setBlockRaw(x1, floorY + height - 1, z, Blocks.STONE)
        world:setBlockRaw(x2, floorY + height - 1, z, Blocks.STONE)
    end
end

---建造斜屋顶
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param roofStartY number 屋顶起始Y
---@param roofHeight number 屋顶高度
function HouseGenerator:buildRoof(world, x1, z1, x2, z2, roofStartY, roofHeight)
    local centerZ = math.floor((z1 + z2) / 2)
    local halfDepth = math.floor((z2 - z1) / 2)
    
    -- 从两侧向中间逐层升高
    for layer = 0, roofHeight do
        local y = roofStartY + layer
        local zOffset = layer
        
        if zOffset <= halfDepth then
            -- 前坡屋顶
            for x = x1 - 1, x2 + 1 do
                world:setBlockRaw(x, y, z1 - 1 + zOffset, Blocks.WOOD)
            end
            -- 后坡屋顶
            for x = x1 - 1, x2 + 1 do
                world:setBlockRaw(x, y, z2 + 1 - zOffset, Blocks.WOOD)
            end
        end
        
        -- 屋顶脊线（用石头装饰）
        if layer == roofHeight - 1 or layer == roofHeight then
            for x = x1 - 1, x2 + 1 do
                world:setBlockRaw(x, y, centerZ, Blocks.WOOD)
            end
        end
    end
    
    -- 山墙（三角形墙壁）
    for layer = 0, halfDepth do
        local y = roofStartY + layer
        -- 左山墙
        for z = z1 + layer, z2 - layer do
            world:setBlockRaw(x1, y, z, Blocks.WOOD)
        end
        -- 右山墙
        for z = z1 + layer, z2 - layer do
            world:setBlockRaw(x2, y, z, Blocks.WOOD)
        end
    end
    
    -- 屋檐装饰（石头边条）
    for x = x1 - 1, x2 + 1 do
        world:setBlockRaw(x, roofStartY, z1 - 1, Blocks.STONE)
        world:setBlockRaw(x, roofStartY, z2 + 1, Blocks.STONE)
    end
end

---建造门和窗户
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param floorY number 地板Y
function HouseGenerator:buildDoorAndWindows(world, x1, z1, x2, z2, floorY)
    local centerX = math.floor((x1 + x2) / 2)
    
    -- 前门 (在前墙中央)
    world:setBlockRaw(centerX, floorY + 1, z1, Blocks.AIR)
    world:setBlockRaw(centerX, floorY + 2, z1, Blocks.AIR)
    
    -- 前窗（门两侧）
    world:setBlockRaw(centerX - 3, floorY + 2, z1, Blocks.AIR)
    world:setBlockRaw(centerX - 3, floorY + 3, z1, Blocks.AIR)
    world:setBlockRaw(centerX + 3, floorY + 2, z1, Blocks.AIR)
    world:setBlockRaw(centerX + 3, floorY + 3, z1, Blocks.AIR)
    
    -- 侧面窗户（左墙）
    local midZ = math.floor((z1 + z2) / 2)
    world:setBlockRaw(x1, floorY + 2, midZ, Blocks.AIR)
    world:setBlockRaw(x1, floorY + 3, midZ, Blocks.AIR)
    world:setBlockRaw(x1, floorY + 2, midZ + 1, Blocks.AIR)
    world:setBlockRaw(x1, floorY + 3, midZ + 1, Blocks.AIR)
    
    -- 侧面窗户（右墙）
    world:setBlockRaw(x2, floorY + 2, midZ, Blocks.AIR)
    world:setBlockRaw(x2, floorY + 3, midZ, Blocks.AIR)
    world:setBlockRaw(x2, floorY + 2, midZ + 1, Blocks.AIR)
    world:setBlockRaw(x2, floorY + 3, midZ + 1, Blocks.AIR)
    
    -- 后窗
    world:setBlockRaw(centerX, floorY + 2, z2, Blocks.AIR)
    world:setBlockRaw(centerX, floorY + 3, z2, Blocks.AIR)
end

---建造烟囱
---@param world table
---@param x number 烟囱X坐标
---@param z number 烟囱Z坐标
---@param topY number 顶部Y坐标
function HouseGenerator:buildChimney(world, x, z, topY)
    -- 石头烟囱从屋顶到上方3格
    for y = topY - 3, topY + 3 do
        world:setBlockRaw(x, y, z, Blocks.STONE)
        world:setBlockRaw(x + 1, y, z, Blocks.STONE)
        world:setBlockRaw(x, y, z + 1, Blocks.STONE)
        world:setBlockRaw(x + 1, y, z + 1, Blocks.STONE)
    end
    
    -- 烟囱顶部装饰（略微突出）
    world:setBlockRaw(x - 1, topY + 2, z, Blocks.STONE)
    world:setBlockRaw(x + 2, topY + 2, z, Blocks.STONE)
    world:setBlockRaw(x, topY + 2, z - 1, Blocks.STONE)
    world:setBlockRaw(x, topY + 2, z + 2, Blocks.STONE)
end

---建造门廊
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param floorY number 地板Y
function HouseGenerator:buildPorch(world, x1, z1, x2, z2, floorY)
    local centerX = math.floor((x1 + x2) / 2)
    
    -- 门廊地板
    for x = centerX - 3, centerX + 3 do
        world:setBlockRaw(x, floorY, z1 - 1, Blocks.WOOD)
        world:setBlockRaw(x, floorY, z1 - 2, Blocks.WOOD)
    end
    
    -- 门廊支柱
    world:setBlockRaw(centerX - 3, floorY + 1, z1 - 2, Blocks.WOOD)
    world:setBlockRaw(centerX - 3, floorY + 2, z1 - 2, Blocks.WOOD)
    world:setBlockRaw(centerX - 3, floorY + 3, z1 - 2, Blocks.WOOD)
    
    world:setBlockRaw(centerX + 3, floorY + 1, z1 - 2, Blocks.WOOD)
    world:setBlockRaw(centerX + 3, floorY + 2, z1 - 2, Blocks.WOOD)
    world:setBlockRaw(centerX + 3, floorY + 3, z1 - 2, Blocks.WOOD)
    
    -- 门廊顶棚
    for x = centerX - 3, centerX + 3 do
        world:setBlockRaw(x, floorY + 4, z1 - 1, Blocks.WOOD)
        world:setBlockRaw(x, floorY + 4, z1 - 2, Blocks.WOOD)
    end
    
    -- 门廊栏杆（用石头）
    world:setBlockRaw(centerX - 3, floorY + 1, z1 - 1, Blocks.STONE)
    world:setBlockRaw(centerX + 3, floorY + 1, z1 - 1, Blocks.STONE)
    
    -- 台阶（通往门廊）
    world:setBlockRaw(centerX, floorY - 1, z1 - 3, Blocks.STONE)
    world:setBlockRaw(centerX - 1, floorY - 1, z1 - 3, Blocks.STONE)
    world:setBlockRaw(centerX + 1, floorY - 1, z1 - 3, Blocks.STONE)
end

---建造装饰物（花坛、灌木等）
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param floorY number 地板Y
function HouseGenerator:buildDecorations(world, x1, z1, x2, z2, floorY)
    -- 前窗下方的花坛
    local centerX = math.floor((x1 + x2) / 2)
    
    -- 左花坛
    world:setBlockRaw(centerX - 4, floorY, z1 - 1, Blocks.DIRT)
    world:setBlockRaw(centerX - 3, floorY, z1 - 1, Blocks.DIRT)
    world:setBlockRaw(centerX - 2, floorY, z1 - 1, Blocks.DIRT)
    world:setBlockRaw(centerX - 4, floorY + 1, z1 - 1, Blocks.ROSE)
    world:setBlockRaw(centerX - 3, floorY + 1, z1 - 1, Blocks.FLOWER_YELLOW)
    world:setBlockRaw(centerX - 2, floorY + 1, z1 - 1, Blocks.ROSE)
    
    -- 右花坛
    world:setBlockRaw(centerX + 2, floorY, z1 - 1, Blocks.DIRT)
    world:setBlockRaw(centerX + 3, floorY, z1 - 1, Blocks.DIRT)
    world:setBlockRaw(centerX + 4, floorY, z1 - 1, Blocks.DIRT)
    world:setBlockRaw(centerX + 2, floorY + 1, z1 - 1, Blocks.FLOWER_BLUE)
    world:setBlockRaw(centerX + 3, floorY + 1, z1 - 1, Blocks.FLOWER_YELLOW)
    world:setBlockRaw(centerX + 4, floorY + 1, z1 - 1, Blocks.FLOWER_BLUE)
    
    -- 房屋周围的灌木（用树叶代替）
    -- 左侧
    world:setBlockRaw(x1 - 1, floorY + 1, z1 + 2, Blocks.LEAVES)
    world:setBlockRaw(x1 - 1, floorY + 1, z2 - 2, Blocks.LEAVES)
    
    -- 右侧
    world:setBlockRaw(x2 + 1, floorY + 1, z1 + 2, Blocks.LEAVES)
    world:setBlockRaw(x2 + 1, floorY + 1, z2 - 2, Blocks.LEAVES)
    
    -- 后院花草
    for x = x1 + 2, x2 - 2, 2 do
        world:setBlockRaw(x, floorY + 1, z2 + 2, Blocks.TALL_GRASS)
    end
    
    -- 小路通往门口
    local pathZ = z1 - 4
    for z = pathZ, z1 - 3 do
        world:setBlockRaw(centerX - 1, floorY - 1, z, Blocks.STONE)
        world:setBlockRaw(centerX, floorY - 1, z, Blocks.STONE)
        world:setBlockRaw(centerX + 1, floorY - 1, z, Blocks.STONE)
    end
end

---放置灯柱/装饰
---@param world table
---@param x1 number 左边界
---@param z1 number 前边界
---@param x2 number 右边界
---@param z2 number 后边界
---@param floorY number 地板Y
---@param wallHeight number 墙壁高度
function HouseGenerator:placeTorches(world, x1, z1, x2, z2, floorY, wallHeight)
    -- 注意：TORCH 是手持物品(isItem=true)，不能直接放置在世界中
    -- 使用木头方块作为灯柱底座，实际的火把光源由 TorchDecorator 处理
    local centerX = math.floor((x1 + x2) / 2)
    
    -- 门廊两侧灯柱（使用石头作为灯座）
    world:setBlockRaw(centerX - 3, floorY + 4, z1 - 2, Blocks.STONE)
    world:setBlockRaw(centerX + 3, floorY + 4, z1 - 2, Blocks.STONE)
    
    -- 房屋四角的装饰石头
    world:setBlockRaw(x1 - 1, floorY + 2, z1 - 1, Blocks.STONE)
    world:setBlockRaw(x2 + 1, floorY + 2, z1 - 1, Blocks.STONE)
end

-- ====================================================================
-- 便捷方法：在出生点附近生成房屋
-- ====================================================================

---在出生点(0, 0)附近生成房屋
---@param world table World实例
---@param offsetX number X偏移（默认8，避开玩家出生点）
---@param offsetZ number Z偏移（默认8）
function HouseGenerator:generateAtSpawn(world, offsetX, offsetZ)
    offsetX = offsetX or 8
    offsetZ = offsetZ or 8
    self:generate(world, offsetX, offsetZ)
end

return HouseGenerator

