-- ====================================================================
-- rendering/TextureAtlas.lua
-- 纹理图集代理 - 委托给材质包系统
-- ====================================================================

local TexturePackManager = require("rendering.texturepacks.TexturePackManager")

---@class TextureAtlas
local TextureAtlas = {}
TextureAtlas.__index = TextureAtlas

---创建纹理图集实例
---@return table TextureAtlas实例
function TextureAtlas.new()
    local self = setmetatable({}, TextureAtlas)
    self.textures = nil
    self.currentPack = nil
    return self
end

---生成纹理图集（代理到材质包管理器）
---@return table { diffuse: Texture2D, normal: Texture2D|nil, specular: Texture2D|nil }
function TextureAtlas:generate()
    local pack = TexturePackManager:getCurrent()
    self.currentPack = pack
    self.textures = pack:generate()
    print("TextureAtlas: Using texture pack '" .. pack.displayName .. "'")
    return self.textures
end

---获取所有贴图
---@return table { diffuse: Texture2D, normal: Texture2D|nil, specular: Texture2D|nil }
function TextureAtlas:getTextures()
    if not self.textures then
        return self:generate()
    end
    return self.textures
end

---获取 tile 的 UV 坐标（代理到当前材质包）
---@param row number 行索引
---@param col number 列索引
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function TextureAtlas:getTileUV(row, col)
    if not self.currentPack then
        self.currentPack = TexturePackManager:getCurrent()
    end
    return self.currentPack:getTileUV(row, col)
end

-- ============================================
-- 模块级单例（保持兼容性）
-- ============================================
local defaultAtlas = nil

---获取默认纹理图集实例
---@return table TextureAtlas实例
function TextureAtlas.getDefault()
    if not defaultAtlas then
        defaultAtlas = TextureAtlas.new()
    end
    return defaultAtlas
end

return TextureAtlas
