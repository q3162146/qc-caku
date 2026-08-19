-- ====================================================================
-- terrain/NoiseGenerator.lua
-- 噪声生成器 - 柏林噪声和分形布朗运动算法（优化版）
-- 内联关键函数 + 梯度查表优化
-- ====================================================================

local Config = require("config.GameConfig")

-- 数学函数本地化（热路径优化）
local floor = math.floor
local abs = math.abs

-- 跨平台安全的位与运算（使用取模代替，避免 WASM/PC 差异）
-- band(x, 2^n - 1) == x % 2^n（仅对 2^n-1 形式的掩码有效）
local function safeBand255(x)
    return floor(abs(x)) % 256
end

local function safeBand3(x)
    return floor(abs(x)) % 4
end

local function safeBand7fffffff(x)
    return floor(abs(x)) % 0x80000000
end

---@class NoiseGenerator
---@field seed number
---@field perm table
local NoiseGenerator = {}
NoiseGenerator.__index = NoiseGenerator

-- 梯度查表（内联优化）
-- grad(hash, x, y) 的结果等价于：
-- h=0: x+y, h=1: -x+y, h=2: x-y, h=3: -x-y
local GRAD_X = { [0] = 1, [1] = -1, [2] = 1, [3] = -1 }
local GRAD_Y = { [0] = 1, [1] = 1, [2] = -1, [3] = -1 }

---创建新的噪声生成器实例
---@param seed number|nil 随机种子（可选）
---@return table NoiseGenerator实例
function NoiseGenerator.new(seed)
    local self = setmetatable({}, NoiseGenerator)
    self.seed = seed or Config.Noise.SEED
    self.perm = {}  -- 实例级排列表（修复不同种子共享问题）
    self:init()
    return self
end

---初始化排列表
function NoiseGenerator:init()
    local perm = self.perm
    
    -- 初始化排列表
    for i = 0, 255 do
        perm[i] = i
    end
    
    -- Fisher-Yates 洗牌算法（跨平台安全版本）
    local rng = self.seed
    for i = 255, 1, -1 do
        rng = safeBand7fffffff(rng * 1103515245 + 12345)
        local j = rng % (i + 1)
        perm[i], perm[j] = perm[j], perm[i]
    end
    
    -- 复制以处理溢出
    for i = 0, 255 do
        perm[i + 256] = perm[i]
    end
end

---2D 柏林噪声 (-1 到 1)（内联优化版）
---@param x number
---@param y number
---@return number
function NoiseGenerator:perlin2D(x, y)
    local perm = self.perm
    
    -- 找到单位方格（跨平台安全版本）
    local floorX = floor(x)
    local floorY = floor(y)
    local xi = safeBand255(floorX)
    local yi = safeBand255(floorY)
    
    -- 方格内相对位置
    local xf = x - floorX
    local yf = y - floorY
    
    -- 内联 fade: t * t * t * (t * (t * 6 - 15) + 10)
    local u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    local v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
    
    -- 方格角落的哈希值
    local permXi = perm[xi]
    local permXi1 = perm[xi + 1]
    local aa = perm[permXi + yi]
    local ab = perm[permXi + yi + 1]
    local ba = perm[permXi1 + yi]
    local bb = perm[permXi1 + yi + 1]
    
    -- 内联 grad: 使用查表（跨平台安全版本）
    local hAA = safeBand3(aa)
    local hAB = safeBand3(ab)
    local hBA = safeBand3(ba)
    local hBB = safeBand3(bb)
    
    local gradAA = GRAD_X[hAA] * xf + GRAD_Y[hAA] * yf
    local gradBA = GRAD_X[hBA] * (xf - 1) + GRAD_Y[hBA] * yf
    local gradAB = GRAD_X[hAB] * xf + GRAD_Y[hAB] * (yf - 1)
    local gradBB = GRAD_X[hBB] * (xf - 1) + GRAD_Y[hBB] * (yf - 1)
    
    -- 内联 lerp: a + t * (b - a)
    local x1 = gradAA + u * (gradBA - gradAA)
    local x2 = gradAB + u * (gradBB - gradAB)
    
    return x1 + v * (x2 - x1)
end

---分形布朗运动 (fBm) - 多层叠加噪声
---@param x number
---@param y number
---@param octaves number 叠加层数
---@param lacunarity number 频率倍增系数
---@param persistence number 振幅衰减系数
---@return number
function NoiseGenerator:fbm(x, y, octaves, lacunarity, persistence)
    local total = 0
    local amplitude = 1
    local frequency = 1
    local maxValue = 0
    
    for i = 1, octaves do
        total = total + self:perlin2D(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end
    
    return total / maxValue
end

-- 保留原始函数用于兼容性（可选删除）
---平滑插值函数 (6t^5 - 15t^4 + 10t^3)
---@param t number
---@return number
function NoiseGenerator.fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

---线性插值
---@param a number
---@param b number
---@param t number
---@return number
function NoiseGenerator.lerp(a, b, t)
    return a + t * (b - a)
end

---梯度函数（跨平台安全版本）
---@param hash number
---@param x number
---@param y number
---@return number
function NoiseGenerator.grad(hash, x, y)
    local h = safeBand3(hash)
    return GRAD_X[h] * x + GRAD_Y[h] * y
end

-- 模块级单例（方便直接调用）
local defaultGenerator = nil

---获取默认生成器实例
---@return table NoiseGenerator实例
function NoiseGenerator.getDefault()
    if not defaultGenerator then
        defaultGenerator = NoiseGenerator.new()
    end
    return defaultGenerator
end

---快捷方法：2D柏林噪声
---@param x number
---@param y number
---@return number
function NoiseGenerator.noise2D(x, y)
    return NoiseGenerator.getDefault():perlin2D(x, y)
end

---快捷方法：分形噪声
---@param x number
---@param y number
---@param octaves number|nil
---@param lacunarity number|nil
---@param persistence number|nil
---@return number
function NoiseGenerator.fbmNoise(x, y, octaves, lacunarity, persistence)
    octaves = octaves or 4
    lacunarity = lacunarity or 2.0
    persistence = persistence or 0.5
    return NoiseGenerator.getDefault():fbm(x, y, octaves, lacunarity, persistence)
end

return NoiseGenerator
