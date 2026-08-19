-- ====================================================================
-- debug/Benchmark.lua
-- 性能基准测试模块 - 测量和记录关键性能指标
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")

---@class Benchmark
---@field world World
---@field blockInteraction BlockInteraction
---@field chunkBuilder ChunkMeshBuilder
---@field worldGenerator WorldGenerator|nil
---@field maxFrameSamples integer
local Benchmark = {}
Benchmark.__index = Benchmark

---创建新的基准测试实例
---@param world table World实例
---@param blockInteraction table BlockInteraction实例
---@param chunkBuilder table ChunkMeshBuilder实例
---@param worldGenerator table|nil WorldGenerator实例（可选）
---@return table Benchmark实例
function Benchmark.new(world, blockInteraction, chunkBuilder, worldGenerator)
    local self = setmetatable({}, Benchmark)
    self.world = world
    self.blockInteraction = blockInteraction
    self.chunkBuilder = chunkBuilder
    self.worldGenerator = worldGenerator
    
    -- 帧时间收集
    self.frameTimeSamples = {}
    self.isCollectingFrames = false
    self.maxFrameSamples = 300  -- 5秒 @ 60fps
    
    return self
end

---开始帧时间收集
function Benchmark:startFrameCollection()
    self.frameTimeSamples = {}
    self.isCollectingFrames = true
    print("[Benchmark] Started frame time collection...")
end

---记录帧时间
---@param deltaTime number 帧时间（秒）
function Benchmark:recordFrame(deltaTime)
    if not self.isCollectingFrames then return end
    
    table.insert(self.frameTimeSamples, deltaTime)
    
    if #self.frameTimeSamples >= self.maxFrameSamples then
        self.isCollectingFrames = false
    end
end

---是否正在收集帧数据
---@return boolean
function Benchmark:isCollecting()
    return self.isCollectingFrames
end

---打印帧时间汇总
function Benchmark:printSummary()
    if #self.frameTimeSamples == 0 then
        print("[Benchmark] No frame samples collected")
        return
    end
    
    local sum = 0
    local minTime = math.huge
    local maxTime = 0
    
    for _, dt in ipairs(self.frameTimeSamples) do
        sum = sum + dt
        minTime = math.min(minTime, dt)
        maxTime = math.max(maxTime, dt)
    end
    
    local avgTime = sum / #self.frameTimeSamples
    local avgFps = 1 / avgTime
    
    print("=== Frame Time Summary ===")
    print(string.format("  Samples: %d", #self.frameTimeSamples))
    print(string.format("  Average: %.2f ms (%.1f FPS)", avgTime * 1000, avgFps))
    print(string.format("  Min: %.2f ms", minTime * 1000))
    print(string.format("  Max: %.2f ms", maxTime * 1000))
end

---测试 getBlock 性能
---@param iterations number 迭代次数
---@return number 每次调用耗时（微秒）
function Benchmark:testGetBlock(iterations)
    iterations = iterations or 10000
    local world = self.world
    local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
    
    -- 预生成随机坐标（避免测量 math.random 开销）
    local coords = {}
    for i = 1, iterations do
        coords[i] = {
            x = math.random(-32, 32),
            y = math.random(0, WORLD_HEIGHT - 1),
            z = math.random(-32, 32)
        }
    end
    
    collectgarbage("collect")
    local start = os.clock()
    
    for i = 1, iterations do
        local c = coords[i]
        world:getBlock(c.x, c.y, c.z)
    end
    
    local elapsed = os.clock() - start
    local usPerCall = (elapsed * 1000000) / iterations
    
    print(string.format("[Benchmark] getBlock x%d: %.2f ms (%.2f us/call)", 
        iterations, elapsed * 1000, usPerCall))
    
    return usPerCall
end

---测试 setBlock 性能
---@param iterations number 迭代次数
---@return number 每次调用耗时（微秒）
function Benchmark:testSetBlock(iterations)
    iterations = iterations or 10000
    local world = self.world
    local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
    local AIR = Blocks.AIR
    local STONE = Blocks.STONE
    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local floor = math.floor
    
    -- 预生成随机坐标（在测试区域，不影响实际世界）
    local TEST_OFFSET = 1000
    local coords = {}
    local testChunkKeys = {}  -- 记录创建的测试区块
    
    for i = 1, iterations do
        local x = TEST_OFFSET + math.random(0, 63)
        local z = TEST_OFFSET + math.random(0, 63)
        coords[i] = {
            x = x,
            y = math.random(0, WORLD_HEIGHT - 1),
            z = z
        }
        -- 记录测试区块键
        local chunkX = floor(x / CHUNK_SIZE)
        local chunkZ = floor(z / CHUNK_SIZE)
        testChunkKeys[chunkX * 65536 + chunkZ] = true
    end
    
    collectgarbage("collect")
    local start = os.clock()
    
    for i = 1, iterations do
        local c = coords[i]
        -- 交替设置石头和空气
        local blockType = (i % 2 == 0) and STONE or AIR
        world:setBlockRaw(c.x, c.y, c.z, blockType)
    end
    
    local elapsed = os.clock() - start
    local usPerCall = (elapsed * 1000000) / iterations
    
    print(string.format("[Benchmark] setBlock x%d: %.2f ms (%.2f us/call)", 
        iterations, elapsed * 1000, usPerCall))
    
    -- 清理测试区块（避免影响高度范围准确性测试）
    for key in pairs(testChunkKeys) do
        world.chunkData[key] = nil
    end
    
    return usPerCall
end

---测试高度范围准确性
---验证 minY/maxY 是否正确反映区块内容
---注意：只检查有实际方块内容的区块（跳过空区块）
---@return boolean 是否通过测试
function Benchmark:testHeightRangeAccuracy()
    local world = self.world
    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
    local AIR = Blocks.AIR
    
    local passed = 0
    local failed = 0
    local skipped = 0
    local failedDetails = {}
    
    for numericKey, chunkData in pairs(world.chunkData) do
        if chunkData.blocks then
            -- 实际计算高度范围
            local actualMinY = WORLD_HEIGHT
            local actualMaxY = 0
            local hasBlocks = false
            
            for y = 0, WORLD_HEIGHT - 1 do
                for lz = 0, CHUNK_SIZE - 1 do
                    for lx = 0, CHUNK_SIZE - 1 do
                        local idx = y * 256 + lz * 16 + lx
                        local block = chunkData.blocks[idx]
                        if block and block ~= AIR then
                            hasBlocks = true
                            if y < actualMinY then actualMinY = y end
                            if y > actualMaxY then actualMaxY = y end
                        end
                    end
                end
            end
            
            -- 跳过空区块（它们的高度范围是默认值）
            if not hasBlocks then
                skipped = skipped + 1
            else
                local storedMinY = chunkData.minY or WORLD_HEIGHT
                local storedMaxY = chunkData.maxY or 0
                
                -- 存储的范围应该包含实际范围（允许更宽松，因为删除方块不收缩）
                if storedMinY <= actualMinY and storedMaxY >= actualMaxY then
                    passed = passed + 1
                else
                    failed = failed + 1
                    -- 记录前几个失败的详情
                    if #failedDetails < 3 then
                        table.insert(failedDetails, string.format(
                            "  key=%d: stored[%d,%d] vs actual[%d,%d]",
                            numericKey, storedMinY, storedMaxY, actualMinY, actualMaxY
                        ))
                    end
                end
            end
        end
    end
    
    local success = failed == 0
    print(string.format("[Benchmark] Height range accuracy: %d passed, %d failed, %d skipped (%s)", 
        passed, failed, skipped, success and "OK" or "FAIL"))
    
    -- 打印失败详情
    for _, detail in ipairs(failedDetails) do
        print(detail)
    end
    
    return success
end

---测试内存使用
---@return number 当前内存使用（KB）
function Benchmark:testMemoryUsage()
    collectgarbage("collect")
    local memKB = collectgarbage("count")
    
    print(string.format("[Benchmark] Memory usage: %.2f KB (%.2f MB)", 
        memKB, memKB / 1024))
    
    return memKB
end

---测试射线检测 GC 开销
---@param iterations number 迭代次数
---@return number 每次调用 GC 开销（KB）
function Benchmark:testRaycastGC(iterations)
    iterations = iterations or 100
    local blockInteraction = self.blockInteraction
    
    collectgarbage("collect")
    local beforeGC = collectgarbage("count")
    
    for i = 1, iterations do
        blockInteraction:getTargetBlock()
    end
    
    local afterGC = collectgarbage("count")
    local gcPerCall = (afterGC - beforeGC) / iterations
    
    print(string.format("[Benchmark] Raycast GC x%d: %.2f KB (%.2f KB/call)", 
        iterations, afterGC - beforeGC, gcPerCall))
    
    return gcPerCall
end

---测试单区块重建时间
---@return number 重建耗时（毫秒）
function Benchmark:testChunkRebuild()
    local chunkBuilder = self.chunkBuilder
    
    collectgarbage("collect")
    local start = os.clock()
    
    -- 重建原点区块
    chunkBuilder:buildChunk(0, 0)
    
    local elapsed = (os.clock() - start) * 1000
    
    print(string.format("[Benchmark] Chunk rebuild (0,0): %.2f ms", elapsed))
    
    return elapsed
end

---测试多区块重建时间（模拟敲方块后的重建）
---@param count number 重建区块数
---@return number 总耗时（毫秒）
function Benchmark:testMultiChunkRebuild(count)
    count = count or 3
    local chunkBuilder = self.chunkBuilder
    local world = self.world
    
    -- 获取有数据的区块
    local chunks = {}
    for numericKey, _ in pairs(world.chunkData) do
        local chunkX = math.floor(numericKey / 65536)
        local chunkZ = numericKey % 65536
        if chunkZ > 32767 then chunkZ = chunkZ - 65536 end  -- 处理负数
        table.insert(chunks, { x = chunkX, z = chunkZ })
        if #chunks >= count then break end
    end
    
    collectgarbage("collect")
    local start = os.clock()
    
    for _, chunk in ipairs(chunks) do
        chunkBuilder:buildChunk(chunk.x, chunk.z)
    end
    
    local elapsed = (os.clock() - start) * 1000
    
    print(string.format("[Benchmark] Multi-chunk rebuild (%d chunks): %.2f ms (%.2f ms/chunk)", 
        #chunks, elapsed, elapsed / #chunks))
    
    return elapsed
end

---测试边界区块标记行为
---统计在边界位置敲方块时会标记多少个脏区块
---@return table { interior, edgeX, edgeZ, corner } 各位置标记的区块数
function Benchmark:testBoundaryChunkMarking()
    local world = self.world
    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local AIR = Blocks.AIR
    local STONE = Blocks.STONE
    
    -- 测试位置
    local testCases = {
        { name = "interior", localX = 8, localZ = 8 },   -- 区块内部
        { name = "edgeX",    localX = 0, localZ = 8 },   -- X边界
        { name = "edgeZ",    localX = 8, localZ = 0 },   -- Z边界
        { name = "corner",   localX = 0, localZ = 0 },   -- 角落
    }
    
    local results = {}
    local TEST_CHUNK_X = 100  -- 使用远离玩家的测试区块
    local TEST_CHUNK_Z = 100
    
    for _, tc in ipairs(testCases) do
        -- 确保测试区块存在
        local testX = TEST_CHUNK_X * CHUNK_SIZE + tc.localX
        local testZ = TEST_CHUNK_Z * CHUNK_SIZE + tc.localZ
        local testY = 40  -- 中间高度
        
        -- 先放置一个方块
        world:setBlockRaw(testX, testY, testZ, STONE)
        
        -- 清空脏区块列表
        for key in pairs(world.dirtyChunks) do
            world.dirtyChunks[key] = nil
        end
        
        -- 执行 setBlock（会触发 markChunkDirty）
        world:setBlock(testX, testY, testZ, AIR)
        
        -- 统计标记的脏区块数
        local dirtyCount = 0
        for _ in pairs(world.dirtyChunks) do
            dirtyCount = dirtyCount + 1
        end
        
        results[tc.name] = dirtyCount
        
        -- 清理
        for key in pairs(world.dirtyChunks) do
            world.dirtyChunks[key] = nil
        end
    end
    
    print("[Benchmark] Boundary chunk marking:")
    print(string.format("  Interior (8,8): %d chunks marked", results.interior))
    print(string.format("  Edge X   (0,8): %d chunks marked", results.edgeX))
    print(string.format("  Edge Z   (8,0): %d chunks marked", results.edgeZ))
    print(string.format("  Corner   (0,0): %d chunks marked", results.corner))
    
    return results
end

---测试敲方块端到端耗时
---模拟完整的敲方块流程：setBlock → markDirty → rebuildDirtyChunks
---@param count number 测试次数
---@return table { setBlock, rebuild, total } 各阶段耗时（毫秒）
function Benchmark:testBlockDestroyE2E(count)
    count = count or 10
    local world = self.world
    local chunkBuilder = self.chunkBuilder
    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local AIR = Blocks.AIR
    local STONE = Blocks.STONE
    local DIRT = Blocks.DIRT
    local GRASS = Blocks.GRASS
    
    -- 在测试区块放置方块
    local TEST_CHUNK_X = 50
    local TEST_CHUNK_Z = 50
    local testBlocks = {}
    
    -- 创建一个真实的测试区块（模拟真实地形）
    -- 填充 y=0~60 的地形，使重建时间接近真实情况
    local startX = TEST_CHUNK_X * CHUNK_SIZE
    local startZ = TEST_CHUNK_Z * CHUNK_SIZE
    for x = startX, startX + CHUNK_SIZE - 1 do
        for z = startZ, startZ + CHUNK_SIZE - 1 do
            -- 石头层 (0-50)
            for y = 0, 50 do
                world:setBlockRaw(x, y, z, STONE)
            end
            -- 泥土层 (51-59)
            for y = 51, 59 do
                world:setBlockRaw(x, y, z, DIRT)
            end
            -- 草地层 (60)
            world:setBlockRaw(x, 60, z, GRASS)
        end
    end
    
    -- 更新高度范围
    local numericKey = TEST_CHUNK_X * 65536 + TEST_CHUNK_Z
    local chunkData = world.chunkData[numericKey]
    if chunkData then
        chunkData.minY = 0
        chunkData.maxY = 60
    end
    
    -- 记录要测试的方块（地表草地）
    for i = 1, count do
        local x = startX + math.random(1, CHUNK_SIZE - 2)
        local z = startZ + math.random(1, CHUNK_SIZE - 2)
        table.insert(testBlocks, { x = x, y = 60, z = z })
    end
    
    -- 构建初始区块
    chunkBuilder:buildChunk(TEST_CHUNK_X, TEST_CHUNK_Z)
    
    -- 测量各阶段耗时
    local setBlockTimes = {}
    local rebuildTimes = {}
    
    collectgarbage("collect")
    
    for i, block in ipairs(testBlocks) do
        -- 阶段1：setBlock（含 markChunkDirty）
        local start1 = os.clock()
        world:setBlock(block.x, block.y, block.z, AIR)
        local setBlockTime = (os.clock() - start1) * 1000
        table.insert(setBlockTimes, setBlockTime)
        
        -- 阶段2：rebuildDirtyChunks（异步版本需要循环调用直到完成）
        local start2 = os.clock()
        local frameCount = 0
        repeat
            chunkBuilder:rebuildDirtyChunks()
            frameCount = frameCount + 1
        until not chunkBuilder:isAsyncRebuildActive() or frameCount > 100  -- 防止无限循环
        local rebuildTime = (os.clock() - start2) * 1000
        table.insert(rebuildTimes, rebuildTime)
        
        -- 记录分帧信息（调试用）
        if frameCount > 1 and i == 1 then
            print(string.format("  [Async] Rebuild completed in %d frames", frameCount))
        end
    end
    
    -- 计算平均值
    local avgSetBlock = 0
    local avgRebuild = 0
    for i = 1, #setBlockTimes do
        avgSetBlock = avgSetBlock + setBlockTimes[i]
        avgRebuild = avgRebuild + rebuildTimes[i]
    end
    avgSetBlock = avgSetBlock / #setBlockTimes
    avgRebuild = avgRebuild / #rebuildTimes
    
    local results = {
        setBlock = avgSetBlock,
        rebuild = avgRebuild,
        total = avgSetBlock + avgRebuild
    }
    
    print(string.format("[Benchmark] Block destroy E2E (avg of %d):", count))
    print(string.format("  setBlock + markDirty: %.2f ms", results.setBlock))
    print(string.format("  rebuildDirtyChunks:   %.2f ms", results.rebuild))
    print(string.format("  Total:                %.2f ms", results.total))
    
    -- 清理测试区块（复用之前定义的 numericKey）
    world.chunkData[numericKey] = nil
    world:removeChunk(TEST_CHUNK_X .. "," .. TEST_CHUNK_Z)
    
    return results
end

---测试世界生成时间（可选，需要 WorldGenerator）
---@return number|nil 生成耗时（毫秒）
function Benchmark:testWorldGeneration()
    if not self.worldGenerator then
        print("[Benchmark] WorldGenerator not available, skipping world gen test")
        return nil
    end
    
    -- 创建临时世界
    local World = require("world.World")
    local tempWorld = World.new()
    
    collectgarbage("collect")
    local start = os.clock()
    
    -- 生成小范围世界 (RENDER_DISTANCE=2)
    local originalDistance = Config.World.RENDER_DISTANCE
    Config.World.RENDER_DISTANCE = 2
    
    self.worldGenerator:generate(tempWorld, 100, 100)  -- 偏移位置避免覆盖
    
    Config.World.RENDER_DISTANCE = originalDistance
    
    local elapsed = (os.clock() - start) * 1000
    
    print(string.format("[Benchmark] World generation (5x5 chunks): %.2f ms", elapsed))
    
    return elapsed
end

---运行所有基准测试
---@param skipWorldGen boolean|nil 是否跳过世界生成测试
function Benchmark:runAll(skipWorldGen)
    print("=== Performance Benchmark ===")
    print("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("")
    
    -- 1. 内存使用
    self:testMemoryUsage()
    
    -- 2. getBlock 性能
    self:testGetBlock(10000)
    
    -- 3. setBlock 性能
    self:testSetBlock(10000)
    
    -- 4. 射线检测 GC
    self:testRaycastGC(100)
    
    -- 5. 区块重建
    self:testChunkRebuild()
    
    -- 6. 高度范围准确性
    self:testHeightRangeAccuracy()
    
    -- 7. 世界生成（可选）
    if not skipWorldGen then
        self:testWorldGeneration()
    end
    
    -- 8. 开始帧时间收集
    self:startFrameCollection()
    
    print("")
    print("[Benchmark] Collecting frame times for 5 seconds...")
    print("[Benchmark] Results will be printed when complete.")
end

---运行区块重建专项测试
---专门测试敲方块相关的性能指标
function Benchmark:runChunkRebuildTest()
    print("=== Chunk Rebuild Benchmark ===")
    print("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("")
    
    -- 1. 单区块重建
    self:testChunkRebuild()
    
    -- 2. 多区块重建（模拟边界情况）
    self:testMultiChunkRebuild(3)
    
    -- 3. 边界区块标记行为
    self:testBoundaryChunkMarking()
    
    -- 4. 敲方块端到端耗时
    self:testBlockDestroyE2E(10)
    
    print("")
    print("=== Chunk Rebuild Benchmark Complete ===")
end

return Benchmark

