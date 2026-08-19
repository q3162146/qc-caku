-- ====================================================================
-- rendering/texturepacks/TexturePackBase.lua
-- 材质包基类/接口 - 定义材质包的通用接口
-- ====================================================================

---@class TexturePackBase
local TexturePackBase = {
    name = "base",           -- 内部名称
    displayName = "Base",    -- 显示名称
    tileSize = 16,           -- 单个纹理像素尺寸
    atlasSize = 256,         -- 图集像素尺寸
    tilesPerRow = 16,        -- 每行 tile 数（= atlasSize / tileSize）
    isPBR = false,           -- 是否为 PBR 材质包
    _cachedTextures = nil,   -- 纹理缓存（避免重复生成）
}
TexturePackBase.__index = TexturePackBase

---创建材质包实例
---@return table TexturePackBase实例
function TexturePackBase.new(config)
    config = config or {}
    local instance = setmetatable({}, TexturePackBase)
    instance.name = config.name or TexturePackBase.name
    instance.displayName = config.displayName or TexturePackBase.displayName
    instance.tileSize = config.tileSize or TexturePackBase.tileSize
    instance.atlasSize = config.atlasSize or TexturePackBase.atlasSize
    instance.tilesPerRow = config.tilesPerRow or (instance.atlasSize / instance.tileSize)
    return instance
end

---子类必须重写此方法，返回 Image 对象
---@return Image 生成的图像
function TexturePackBase:createImage()
    error("TexturePackBase:createImage() must be overridden by subclass")
end

---创建纹理的辅助方法（支持指定 SRGB）
---@param image Image 图像对象
---@param srgb boolean|nil 是否使用 sRGB（默认 true，法线/数据贴图应传 false）
---@return Texture2D 纹理对象
function TexturePackBase:createTexture(image, srgb)
    if srgb == nil then srgb = true end  -- 默认 true（漫反射贴图）
    local texture = Texture2D:new()
    texture:SetSRGB(srgb)
    -- 禁用 mipmap（设置为 1 级），防止远处采样到相邻 tile
    -- Texture Atlas 不能用 mipmap，否则低级别 mipmap 会混合相邻 tile
    texture:SetNumLevels(1)
    texture:SetFilterMode(self:getFilterMode())
    texture:SetData(image, false)
    return texture
end

---生成纹理（统一返回 table 格式）
---使用缓存避免重复生成
---@return table { diffuse: Texture2D, normal: Texture2D|nil, specular: Texture2D|nil }
function TexturePackBase:generate()
    -- 检查缓存，避免重复生成纹理图集
    if self._cachedTextures then
        return self._cachedTextures
    end
    
    local image = self:createImage()  -- 调用子类实现
    self._cachedTextures = {
        diffuse = self:createTexture(image, true),  -- 漫反射用 sRGB
        normal = nil,      -- 非 PBR，不生成
        specular = nil,    -- 非 PBR，不生成
    }
    return self._cachedTextures
end

---清除纹理缓存（切换材质包时调用）
function TexturePackBase:clearCache()
    self._cachedTextures = nil
end

---获取滤波模式（子类可重写）
---@return number 滤波模式常量
function TexturePackBase:getFilterMode()
    return FILTER_NEAREST
end

---获取 tile 的 UV 坐标（封装 UV 计算，避免硬编码）
---添加 padding 防止采样到相邻 tile（解决接缝问题）
---@param row number 行索引
---@param col number 列索引
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function TexturePackBase:getTileUV(row, col)
    local tileUVSize = 1.0 / self.tilesPerRow
    -- 使用半像素偏移，确保采样中心在像素内部
    -- 对于 512 的 atlas 和 32 的 tile，padding = 0.5/512 ≈ 0.001
    local halfPixel = 0.5 / self.atlasSize
    
    local u0 = col * tileUVSize + halfPixel
    local v0 = row * tileUVSize + halfPixel
    local u1 = (col + 1) * tileUVSize - halfPixel
    local v1 = (row + 1) * tileUVSize - halfPixel
    return u0, v0, u1, v1
end

-- ============================================
-- 辅助函数（供子类复用）
-- ============================================

---平滑噪声（非周期性，保留兼容）
---@param x number X坐标
---@param y number Y坐标
---@param seed number 随机种子
---@return number 噪声值 (-0.5 ~ 0.5)
function TexturePackBase:smoothNoise(x, y, seed)
    math.randomseed(seed + x * 1000 + y)
    return math.random() - 0.5
end

---周期性噪声（四方连续）
---将 2D 坐标映射到环面上，确保边缘自然连续
---@param x number X坐标
---@param y number Y坐标
---@param period number 周期（通常等于 tileSize）
---@param seed number 随机种子
---@return number 噪声值 (-0.5 ~ 0.5)
function TexturePackBase:periodicNoise(x, y, period, seed)
    -- 将坐标映射到环面（使用 sin/cos 确保周期性）
    local angle_x = (x / period) * 2 * math.pi
    local angle_y = (y / period) * 2 * math.pi
    
    -- 4D 坐标（在环面上的点）
    local cx = math.cos(angle_x)
    local sx = math.sin(angle_x)
    local cy = math.cos(angle_y)
    local sy = math.sin(angle_y)
    
    -- 使用 4D 坐标生成确定性噪声
    -- 将浮点数转换为整数种子
    local hash = seed + math.floor((cx + 1) * 500) + math.floor((sx + 1) * 50000)
                      + math.floor((cy + 1) * 5000) + math.floor((sy + 1) * 500000)
    math.randomseed(hash)
    return math.random() - 0.5
end

---周期性平滑噪声（带插值，更平滑）
---@param x number X坐标
---@param y number Y坐标
---@param period number 周期
---@param seed number 随机种子
---@return number 噪声值 (-0.5 ~ 0.5)
function TexturePackBase:periodicSmoothNoise(x, y, period, seed)
    local x0 = math.floor(x)
    local y0 = math.floor(y)
    local fx = x - x0
    local fy = y - y0
    
    -- 采样四个角（周期性）
    local n00 = self:periodicNoise(x0 % period, y0 % period, period, seed)
    local n10 = self:periodicNoise((x0 + 1) % period, y0 % period, period, seed)
    local n01 = self:periodicNoise(x0 % period, (y0 + 1) % period, period, seed)
    local n11 = self:periodicNoise((x0 + 1) % period, (y0 + 1) % period, period, seed)
    
    -- 双线性插值
    local nx0 = self:lerp(n00, n10, fx)
    local nx1 = self:lerp(n01, n11, fx)
    return self:lerp(nx0, nx1, fy)
end

---线性插值
---@param a number 起始值
---@param b number 结束值
---@param t number 插值因子 (0~1)
---@return number 插值结果
function TexturePackBase:lerp(a, b, t)
    return a + (b - a) * t
end

---从高度图计算法线（周期性边界，支持四方连续）
---@param heightMap table 二维高度图 heightMap[y][x]
---@param x number X坐标
---@param y number Y坐标
---@param size number 贴图尺寸
---@param strength number 法线强度
---@return number nx (0-1 范围)
---@return number ny (0-1 范围)
---@return number nz (0-1 范围)
function TexturePackBase:computeNormalFromHeight(heightMap, x, y, size, strength)
    -- 周期性边界：边缘采样到对边
    local left  = heightMap[y][(x - 1 + size) % size]
    local right = heightMap[y][(x + 1) % size]
    local up    = heightMap[(y - 1 + size) % size][x]
    local down  = heightMap[(y + 1) % size][x]
    
    local dx = (left - right) * strength
    local dy = (up - down) * strength
    local dz = 1.0
    
    -- 归一化
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    dx, dy, dz = dx/len, dy/len, dz/len
    
    -- 映射到 0-1 范围
    return dx * 0.5 + 0.5, dy * 0.5 + 0.5, dz * 0.5 + 0.5
end

return TexturePackBase
