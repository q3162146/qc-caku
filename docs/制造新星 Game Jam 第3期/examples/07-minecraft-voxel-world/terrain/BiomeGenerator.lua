-- ====================================================================
-- terrain/BiomeGenerator.lua
-- 生物群系生成器
-- ====================================================================

local Config = require("config.GameConfig")
local Noise = require("terrain.NoiseGenerator")

---@class BiomeGenerator
---@field noise NoiseGenerator
local BiomeGenerator = {}
BiomeGenerator.__index = BiomeGenerator

-- 生物群系类型常量
BiomeGenerator.OCEAN = 0
BiomeGenerator.BEACH = 1
BiomeGenerator.PLAINS = 2
BiomeGenerator.FOREST = 3
BiomeGenerator.DESERT = 4
BiomeGenerator.MOUNTAINS = 5

---创建新的生物群系生成器
---@return table BiomeGenerator实例
function BiomeGenerator.new()
    local self = setmetatable({}, BiomeGenerator)
    self.noise = Noise.new()
    return self
end

---获取地形高度
---@param x number 世界坐标X
---@param z number 世界坐标Z
---@return number 高度
function BiomeGenerator:getTerrainHeight(x, z)
    local noise = self.noise
    local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
    local WATER_LEVEL = Config.World.WATER_LEVEL
    
    -- 大陆形状（超大尺度）
    local continentNoise = noise:fbm(x * 0.002, z * 0.002, 2, 2.0, 0.5)
    
    -- 山脉/平原选择器
    local mountainNoise = noise:fbm(x * 0.008 + 100, z * 0.008 + 100, 2, 2.0, 0.5)
    mountainNoise = (mountainNoise + 1) * 0.5  -- 归一化到 0-1
    
    -- 细节地形
    local detailNoise = noise:fbm(x * 0.03, z * 0.03, 4, 2.0, 0.5)
    
    -- 基础高度：水平面上方 1-2 格，让更多区域成为海洋
    local baseHeight = WATER_LEVEL + 1
    
    -- 地形变化范围：根据世界高度动态调整
    local heightScale = WORLD_HEIGHT / 64.0  -- 以 64 为基准
    
    -- 应用大陆形状
    local height = baseHeight + continentNoise * (10 * heightScale)
    
    -- 应用山脉（阈值降低到 0.45，增加山脉覆盖面积）
    if mountainNoise > 0.45 then
        local mountainFactor = (mountainNoise - 0.45) / 0.55  -- 0 到 1
        height = height + detailNoise * (22 * heightScale) * mountainFactor
    else
        -- 平原带有缓和的起伏
        height = height + detailNoise * (5 * heightScale)
    end
    
    -- 添加小细节
    local smallDetail = noise:fbm(x * 0.1, z * 0.1, 2, 2.0, 0.5)
    height = height + smallDetail * (2 * heightScale)
    
    -- 限制在有效范围内
    height = math.max(1, math.min(WORLD_HEIGHT - 10, height))
    
    return math.floor(height)
end

---获取生物群系类型
---@param x number 世界坐标X
---@param z number 世界坐标Z
---@return number 生物群系类型
function BiomeGenerator:getBiome(x, z)
    local noise = self.noise
    
    local temp = noise:fbm(x * 0.005 + 500, z * 0.005 + 500, 2, 2.0, 0.5)
    local moisture = noise:fbm(x * 0.005 + 1000, z * 0.005 + 1000, 2, 2.0, 0.5)
    
    if temp < -0.3 then
        return BiomeGenerator.DESERT  -- 沙漠
    elseif moisture > 0.2 then
        return BiomeGenerator.FOREST  -- 森林
    else
        return BiomeGenerator.PLAINS  -- 平原
    end
end

-- 调试统计
local biomeStats = { forest = 0, plains = 0, desert = 0, other = 0 }
local treePassCount = 0

---判断该位置是否应该生成树
---@param x number 世界坐标X
---@param z number 世界坐标Z
---@param biome number 生物群系类型
---@return boolean 是否生成树
function BiomeGenerator:shouldPlaceTree(x, z, biome)
    -- 统计生物群系
    if biome == BiomeGenerator.FOREST then
        biomeStats.forest = biomeStats.forest + 1
    elseif biome == BiomeGenerator.PLAINS then
        biomeStats.plains = biomeStats.plains + 1
    elseif biome == BiomeGenerator.DESERT then
        biomeStats.desert = biomeStats.desert + 1
    else
        biomeStats.other = biomeStats.other + 1
    end
    
    -- 树木密度基于生物群系
    local treeDensity = 0.0
    if biome == BiomeGenerator.FOREST then
        treeDensity = 0.15  -- 森林：15% 概率
    elseif biome == BiomeGenerator.PLAINS then
        treeDensity = 0.06  -- 平原：6% 概率
    end
    
    if treeDensity <= 0 then
        return false
    end
    
    -- 使用高频噪声产生自然聚集效果
    -- 频率设为 5.0，在小地图上也能有足够变化
    local noise = self.noise
    local treeNoise = noise:fbm(x * 5.0 + 1000.5, z * 5.0 + 2000.5, 2, 2.0, 0.5)
    
    -- 实际噪声范围约 -0.67 到 0.67，重新归一化到 0-1
    -- 使用更宽的归一化范围来确保覆盖 0-1
    treeNoise = (treeNoise + 0.7) / 1.4  -- 假设范围 [-0.7, 0.7]
    treeNoise = math.max(0, math.min(1, treeNoise))  -- 钳制到 0-1
    
    local pass = treeNoise < treeDensity
    if pass then
        treePassCount = treePassCount + 1
        if treePassCount <= 5 then
            print(string.format("[Tree] (%d,%d) biome=%d noise=%.4f < density=%.2f PASS", 
                x, z, biome, treeNoise, treeDensity))
        end
    end
    
    return pass
end

---打印生物群系统计
function BiomeGenerator:printBiomeStats()
    print(string.format("[Biome Stats] forest=%d, plains=%d, desert=%d, other=%d",
        biomeStats.forest, biomeStats.plains, biomeStats.desert, biomeStats.other))
    print(string.format("[Tree Chance] %d positions passed density check", treePassCount))
end

-- 模块级单例
local defaultGenerator = nil

---获取默认生成器实例
---@return table BiomeGenerator实例
function BiomeGenerator.getDefault()
    if not defaultGenerator then
        defaultGenerator = BiomeGenerator.new()
    end
    return defaultGenerator
end

return BiomeGenerator
