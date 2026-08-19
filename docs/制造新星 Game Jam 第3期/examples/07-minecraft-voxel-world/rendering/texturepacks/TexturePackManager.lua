-- ====================================================================
-- rendering/texturepacks/TexturePackManager.lua
-- 材质包管理器 - 管理材质包的注册、切换和通知
-- ====================================================================

---@class TexturePackManager
local TexturePackManager = {
    packs = {},                    -- [name] = pack
    currentPackName = "classic",   -- 当前材质包名称
    onPackChanged = nil,           -- 切换回调函数
}

---注册材质包
---@param pack table 材质包实例
function TexturePackManager:register(pack)
    if not pack or not pack.name then
        print("[TexturePack] Warning: invalid pack registration")
        return
    end
    self.packs[pack.name] = pack
    print("[TexturePack] Registered: " .. pack.name .. " (" .. pack.displayName .. ")")
end

---设置当前材质包
---@param name string 材质包名称
---@return boolean 是否成功
function TexturePackManager:setCurrent(name)
    if self.currentPackName == name then
        return true
    end
    if not self.packs[name] then
        print("[TexturePack] Warning: pack not found: " .. name .. ", keeping current")
        return false
    end
    self.currentPackName = name
    print("[TexturePack] Switched to: " .. name)
    -- 通知订阅者
    if self.onPackChanged then
        self.onPackChanged(self:getCurrent())
    end
    return true
end

---获取当前材质包
---@return table 当前材质包实例
function TexturePackManager:getCurrent()
    local pack = self.packs[self.currentPackName]
    if not pack then
        -- fallback 到第一个可用的包
        for name, p in pairs(self.packs) do
            self.currentPackName = name
            print("[TexturePack] Fallback to: " .. name)
            return p
        end
    end
    return pack
end

---获取指定材质包
---@param name string 材质包名称
---@return table|nil 材质包实例
function TexturePackManager:getPack(name)
    return self.packs[name]
end

---获取所有可用材质包列表
---@return table 材质包信息列表
function TexturePackManager:getAvailablePacks()
    local list = {}
    for name, pack in pairs(self.packs) do
        table.insert(list, {
            name = name,
            displayName = pack.displayName,
            tileSize = pack.tileSize,
            atlasSize = pack.atlasSize
        })
    end
    return list
end

---设置材质包切换回调
---@param callback function 回调函数，参数为新的材质包
function TexturePackManager:setOnPackChanged(callback)
    self.onPackChanged = callback
end

-- ============================================
-- 自动注册内置材质包
-- ============================================
local ClassicPack = require("rendering.texturepacks.ClassicPack")
local HDPack = require("rendering.texturepacks.HDPack")
TexturePackManager:register(ClassicPack)
TexturePackManager:register(HDPack)

return TexturePackManager
