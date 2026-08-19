-- ====================================================================
-- world/WorldGenerator.lua
-- 世界生成器 - 生成地形、树木等
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local BiomeGenerator = require("terrain.BiomeGenerator")
local TreeDecorator = require("terrain.TreeDecorator")
local HouseGenerator = require("terrain.HouseGenerator")

---@class WorldGenerator
---@field biome BiomeGenerator
---@field tree TreeDecorator
---@field house HouseGenerator
local WorldGenerator = {}
WorldGenerator.__index = WorldGenerator

---创建新的世界生成器
---@return table WorldGenerator实例
function WorldGenerator.new()
    local self = setmetatable({}, WorldGenerator)
    self.biome = BiomeGenerator.new()
    self.tree = TreeDecorator.new()
    self.house = HouseGenerator.new()  -- 预留：可在 generate() 末尾调用 self.house:generateAtSpawn(world, 8, 8)
    return self
end

---生成世界
---@param world table World实例
---@param centerX number|nil 中心X坐标（默认0）
---@param centerZ number|nil 中心Z坐标（默认0）
function WorldGenerator:generate(world, centerX, centerZ)
    centerX = centerX or 0
    centerZ = centerZ or 0

    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
    local WATER_LEVEL = Config.World.WATER_LEVEL
    local radius = CHUNK_SIZE * RENDER_DISTANCE

    print("Generating world...")

    -- 第一遍：生成地形
    for x = centerX - radius, centerX + radius do
        for z = centerZ - radius, centerZ + radius do
            -- 检查是否在圆形范围内
            local dx = x - centerX
            local dz = z - centerZ
            if dx*dx + dz*dz <= radius*radius then
                self:generateColumn(world, x, z)
            end
        end
    end

    -- 第二遍：添加树木（可选功能）
    if Config.Features and Config.Features.GENERATE_TREES then
        print("Adding trees...")
        local treeCount = 0
        local checkedCount = 0
        for x = centerX - radius + 3, centerX + radius - 3 do
            for z = centerZ - radius + 3, centerZ + radius - 3 do
                local dx = x - centerX
                local dz = z - centerZ
                if dx*dx + dz*dz <= (radius-3)*(radius-3) then
                    checkedCount = checkedCount + 1
                    if self:tryPlaceTree(world, x, z) then
                        treeCount = treeCount + 1
                    end
                end
            end
        end
        print(string.format("[Trees] Checked %d positions, placed %d trees", checkedCount, treeCount))
        self:printTreeStats()
        self.biome:printBiomeStats()
    else
        print("[Trees] Skipped (GENERATE_TREES = false)")
    end

    -- 第三遍：添加植被（草和花）（可选功能）
    if Config.Features and Config.Features.GENERATE_VEGETATION then
        print("Adding vegetation...")
        for x = centerX - radius, centerX + radius do
            for z = centerZ - radius, centerZ + radius do
                local dx = x - centerX
                local dz = z - centerZ
                if dx*dx + dz*dz <= radius*radius then
                    self:tryPlaceVegetation(world, x, z)
                end
            end
        end
    else
        print("[Vegetation] Skipped (GENERATE_VEGETATION = false)")
    end

    -- 计算所有区块的高度范围（用于 ChunkMeshBuilder 优化）
    world:computeAllChunkHeightRanges()

    -- L1: 天光垂直灌注（必须在 mesh 构建前完成，供 emitSolidFace 烘焙读取）
    world:propagateSkyLight()

    print("World generation complete!")
end

---生成单列方块
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
function WorldGenerator:generateColumn(world, x, z)
    local height = self.biome:getTerrainHeight(x, z)
    local biome = self.biome:getBiome(x, z)
    local WATER_LEVEL = Config.World.WATER_LEVEL
    
    -- 生成垂直方块列
    for y = 0, height do
        local blockType = Blocks.STONE
        
        if y == height then
            -- 顶层方块基于生物群系
            if height <= WATER_LEVEL then
                blockType = Blocks.SAND  -- 水下
            elseif height == WATER_LEVEL + 1 then
                blockType = Blocks.SAND  -- 海滩（仅水面上1格）
            elseif biome == BiomeGenerator.DESERT then
                blockType = Blocks.SAND  -- 沙漠
            else
                blockType = Blocks.GRASS  -- 普通草地
            end
        elseif y > height - 4 then
            -- 近表面
            if biome == BiomeGenerator.DESERT or height <= WATER_LEVEL + 1 then
                blockType = Blocks.SAND
            else
                blockType = Blocks.DIRT
            end
        else
            -- 深层地下 - 石头
            blockType = Blocks.STONE
        end
        
        world:setBlockRaw(x, y, z, blockType)
    end
    
    -- 添加水到水平面
    if height < WATER_LEVEL then
        for y = height + 1, WATER_LEVEL do
            world:setBlockRaw(x, y, z, Blocks.WATER)
        end
    end
end

-- 调试计数器（用于限制日志输出）
local debugLogCount = 0
local debugStats = { notGrass = 0, noTreeChance = 0, noSpace = 0, placed = 0 }

---尝试在位置放置树
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
---@return boolean 是否成功放置
function WorldGenerator:tryPlaceTree(world, x, z)
    -- ========================================================================
    -- TODO: 实现树木生成逻辑
    -- ========================================================================
    -- 
    -- 可用 API：
    --   self.biome:getTerrainHeight(x, z)        -- 获取地面高度
    --   self.biome:getBiome(x, z)                -- 获取生物群系类型
    --   self.biome:shouldPlaceTree(x, z, biome)  -- 基于噪声判断是否放树（控制密度）
    --   world:getBlock(x, y, z)                  -- 获取方块类型
    --   self.tree:canPlaceTree(world, x, y, z)   -- 检查周围是否有空间
    --   self.tree:generateTree(world, x, y, z)   -- 生成一棵树
    --
    -- 常用方块：Blocks.GRASS, Blocks.AIR, Blocks.WOOD, Blocks.LEAVES
    --
    -- 生成步骤：
    --   1. 获取地面高度和生物群系
    --   2. 检查地面是否是草地（只在草地种树）
    --   3. 用 shouldPlaceTree 控制密度（返回 true 才种）
    --   4. 用 canPlaceTree 检查空间（避免树木重叠）
    --   5. 调用 generateTree 生成树
    --
    -- 示例：
    --   local height = self.biome:getTerrainHeight(x, z)
    --   local biome = self.biome:getBiome(x, z)
    --   if world:getBlock(x, height, z) ~= Blocks.GRASS then return false end
    --   if not self.biome:shouldPlaceTree(x, z, biome) then return false end
    --   if not self.tree:canPlaceTree(world, x, height, z) then return false end
    --   self.tree:generateTree(world, x, height, z)
    --   return true
    -- ========================================================================
    
    return false  -- 默认不生成，等待 AI 实现
end

---打印树木生成统计
function WorldGenerator:printTreeStats()
    print(string.format("[Tree Stats] notGrass=%d, noTreeChance=%d, noSpace=%d, placed=%d",
        debugStats.notGrass, debugStats.noTreeChance, debugStats.noSpace, debugStats.placed))
end

---尝试在位置放置植被（草或花）
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
function WorldGenerator:tryPlaceVegetation(world, x, z)
    -- ========================================================================
    -- TODO: 实现植被生成逻辑（花草装饰）
    -- ========================================================================
    -- 
    -- 可用 API：
    --   self.biome:getTerrainHeight(x, z)       -- 获取地面高度
    --   world:getBlock(x, y, z)                 -- 获取方块类型
    --   world:setBlockRaw(x, y, z, blockType)   -- 放置方块
    --
    -- 植被方块：
    --   Blocks.TALL_GRASS    -- 装饰草（最常见）
    --   Blocks.ROSE          -- 玫瑰（红色）
    --   Blocks.FLOWER_YELLOW -- 黄花
    --   Blocks.FLOWER_BLUE   -- 蓝花（稀有）
    --
    -- 常用方块：Blocks.GRASS, Blocks.AIR
    --
    -- 生成步骤：
    --   1. 获取地面高度
    --   2. 检查地面是草地、上方是空气
    --   3. 用确定性随机控制概率：math.randomseed(x * 12345 + z * 67890)
    --   4. 放置植被方块（花比草稀有）
    --
    -- 示例：
    --   local height = self.biome:getTerrainHeight(x, z)
    --   if world:getBlock(x, height, z) ~= Blocks.GRASS then return end
    --   if world:getBlock(x, height + 1, z) ~= Blocks.AIR then return end
    --   math.randomseed(x * 12345 + z * 67890)
    --   if math.random() < 0.25 then
    --       world:setBlockRaw(x, height + 1, z, Blocks.TALL_GRASS)
    --   end
    -- ========================================================================
    
    -- 默认不生成，等待 AI 实现
end

-- ============================================================================
-- 协程化生成（异步分帧执行）
-- ============================================================================

---异步生成世界（协程版本）
---每帧执行一定量的工作后 yield，让主线程可以刷新 UI
---@param world table World实例
---@param centerX number|nil 中心X坐标（默认0）
---@param centerZ number|nil 中心Z坐标（默认0）
---@param onProgress function|nil 进度回调 function(phase, current, total)
---@return thread 协程对象
function WorldGenerator:generateAsync(world, centerX, centerZ, onProgress)
    return coroutine.create(function()
        centerX = centerX or 0
        centerZ = centerZ or 0

        local CHUNK_SIZE = Config.World.CHUNK_SIZE
        local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
        local radius = CHUNK_SIZE * RENDER_DISTANCE


        -- 计算总工作量（圆形区域内的列数）
        local totalColumns = 0
        for x = centerX - radius, centerX + radius do
            for z = centerZ - radius, centerZ + radius do
                local dx, dz = x - centerX, z - centerZ
                if dx*dx + dz*dz <= radius*radius then
                    totalColumns = totalColumns + 1
                end
            end
        end

        -- 配置参数
        local COLUMNS_PER_FRAME = 500   -- 地形生成每帧处理列数
        local TREES_PER_FRAME = 200     -- 树木检查每帧处理数
        local VEGETATION_PER_FRAME = 500 -- 植被每帧处理数

        print("Generating world (async)...")

        -- ========================================
        -- 第一阶段：生成地形 (60%)
        -- ========================================
        local currentColumn = 0

        for x = centerX - radius, centerX + radius do
            for z = centerZ - radius, centerZ + radius do
                local dx, dz = x - centerX, z - centerZ
                if dx*dx + dz*dz <= radius*radius then
                    self:generateColumn(world, x, z)
                    currentColumn = currentColumn + 1

                    if currentColumn % COLUMNS_PER_FRAME == 0 then
                        if onProgress then
                            onProgress("terrain", currentColumn, totalColumns)
                        end
                        coroutine.yield()
                    end
                end
            end
        end

        -- 确保地形阶段完成后报告
        if onProgress then
            onProgress("terrain", totalColumns, totalColumns)
        end
        coroutine.yield()

        -- ========================================
        -- 第二阶段：添加树木 (15%)（可选功能）
        -- ========================================
        if Config.Features and Config.Features.GENERATE_TREES then
            print("Adding trees (async)...")
            local treeCount = 0
            local checkedCount = 0
            local treeRadius = radius - 3

            -- 计算树木检查总数
            local totalTreeChecks = 0
            for x = centerX - treeRadius, centerX + treeRadius do
                for z = centerZ - treeRadius, centerZ + treeRadius do
                    local dx, dz = x - centerX, z - centerZ
                    if dx*dx + dz*dz <= treeRadius*treeRadius then
                        totalTreeChecks = totalTreeChecks + 1
                    end
                end
            end

            for x = centerX - treeRadius, centerX + treeRadius do
                for z = centerZ - treeRadius, centerZ + treeRadius do
                    local dx, dz = x - centerX, z - centerZ
                    if dx*dx + dz*dz <= treeRadius*treeRadius then
                        checkedCount = checkedCount + 1
                        if self:tryPlaceTree(world, x, z) then
                            treeCount = treeCount + 1
                        end

                        if checkedCount % TREES_PER_FRAME == 0 then
                            if onProgress then
                                onProgress("trees", checkedCount, totalTreeChecks)
                            end
                            coroutine.yield()
                        end
                    end
                end
            end

            print(string.format("[Trees] Checked %d positions, placed %d trees", checkedCount, treeCount))
            self:printTreeStats()
            self.biome:printBiomeStats()

            if onProgress then
                onProgress("trees", 1, 1)
            end
            coroutine.yield()
        else
            print("[Trees] Skipped (GENERATE_TREES = false)")
            if onProgress then
                onProgress("trees", 1, 1)
            end
            coroutine.yield()
        end

        -- ========================================
        -- 第三阶段：添加植被 (10%)（可选功能）
        -- ========================================
        if Config.Features and Config.Features.GENERATE_VEGETATION then
            print("Adding vegetation (async)...")
            local vegetationCount = 0

            for x = centerX - radius, centerX + radius do
                for z = centerZ - radius, centerZ + radius do
                    local dx, dz = x - centerX, z - centerZ
                    if dx*dx + dz*dz <= radius*radius then
                        self:tryPlaceVegetation(world, x, z)
                        vegetationCount = vegetationCount + 1

                        if vegetationCount % VEGETATION_PER_FRAME == 0 then
                            if onProgress then
                                onProgress("vegetation", vegetationCount, totalColumns)
                            end
                            coroutine.yield()
                        end
                    end
                end
            end

            if onProgress then
                onProgress("vegetation", 1, 1)
            end
            coroutine.yield()
        else
            print("[Vegetation] Skipped (GENERATE_VEGETATION = false)")
            if onProgress then
                onProgress("vegetation", 1, 1)
            end
            coroutine.yield()
        end

        -- ========================================
        -- 第四阶段：计算高度范围 (20%)
        -- ========================================
        local CHUNKS_PER_FRAME = 5  -- 每帧计算的 chunk 数

        -- 收集所有 chunk
        local chunkKeys = {}
        for numericKey, _ in pairs(world.chunkData) do
            table.insert(chunkKeys, numericKey)
        end
        local totalChunks = #chunkKeys

        -- 先 yield 一次让 UI 更新
        if onProgress then
            onProgress("heights", 0, totalChunks)
        end
        coroutine.yield()

        -- 分帧处理每个 chunk
        local processedInFrame = 0
        for i, numericKey in ipairs(chunkKeys) do
            local chunkData = world.chunkData[numericKey]
            if chunkData and chunkData.blocks then
                chunkData.minY, chunkData.maxY = world:computeHeightRange(chunkData)
                world:propagateSkyLightChunk(chunkData)  -- L1: 顺便灌天光（复用此处分帧）
            end
            processedInFrame = processedInFrame + 1

            -- 每处理 CHUNKS_PER_FRAME 个就 yield
            if processedInFrame >= CHUNKS_PER_FRAME then
                if onProgress then
                    onProgress("heights", i, totalChunks)
                end
                coroutine.yield()
                processedInFrame = 0
            end
        end

        -- 确保最后报告完成
        if onProgress then
            onProgress("heights", totalChunks, totalChunks)
        end
        coroutine.yield()

        -- ========================================
        -- 完成
        -- ========================================
        print("World generation complete (async)!")
        if onProgress then
            onProgress("complete", 1, 1)
        end
    end)
end

return WorldGenerator
