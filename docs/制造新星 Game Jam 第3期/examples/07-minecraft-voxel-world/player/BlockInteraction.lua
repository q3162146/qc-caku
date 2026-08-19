-- ====================================================================
-- player/BlockInteraction.lua
-- 方块交互 - 放置/破坏方块（统一单机/联机处理）
-- 使用 DDA 射线算法，无临时 Vector3 对象，减少 GC 开销
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local Events = require("config.GameEvents")

-- 常量本地化（热路径优化）
local BLOCK_SIZE = Config.World.BLOCK_SIZE
local REACH_DISTANCE = Config.Player.REACH_DISTANCE
local AIR = Blocks.AIR

-- 数学函数本地化
local floor = math.floor
local abs = math.abs

---@class BlockInteraction
---@field player Player
---@field world World
local BlockInteraction = {}
BlockInteraction.__index = BlockInteraction

---创建新的方块交互实例
---@param player table Player实例
---@param world table World实例
---@param options table|nil 配置选项 { isNetworkMode, serverConnection, particleSystem }
---@return table BlockInteraction实例
function BlockInteraction.new(player, world, options)
    local self = setmetatable({}, BlockInteraction)
    
    self.player = player
    self.world = world
    self.torchDecorator = nil  -- 火把装饰器引用（由外部设置）
    self.particleSystem = nil  -- 粒子系统引用（由外部设置）
    
    -- 网络模式配置
    options = options or {}
    self.isNetworkMode = options.isNetworkMode or false
    self.serverConnection = options.serverConnection or nil
    
    -- 网络常量（延迟加载，避免单机模式依赖 Shared）
    self.networkEvents = nil
    self.blockActions = nil
    
    return self
end

---设置火把装饰器引用
---@param torchDecorator table TorchDecorator实例
function BlockInteraction:setTorchDecorator(torchDecorator)
    self.torchDecorator = torchDecorator
end

---设置粒子系统引用
---@param particleSystem table ParticleSystem实例
function BlockInteraction:setParticleSystem(particleSystem)
    self.particleSystem = particleSystem
end

---设置服务器连接（联机模式）
---@param connection Connection 服务器连接
function BlockInteraction:setServerConnection(connection)
    self.serverConnection = connection
    self.isNetworkMode = (connection ~= nil)
end

---延迟加载网络常量（避免单机模式报错）
function BlockInteraction:loadNetworkConstants()
    if self.networkEvents then return end
    
    local Shared = require("network.Shared")
    self.networkEvents = Shared.EVENTS
    self.blockActions = Shared.BLOCK_ACTION
end

-- ============================================================================
-- 统一入口：左键/右键点击处理
-- ============================================================================

---处理左键点击（破坏方块）
---@return boolean 是否有操作执行
function BlockInteraction:onLeftClick()
    -- ① 立即播放挥臂动画（任何模式都执行）
    if self.player and self.player.swingArm then
        self.player:swingArm()
    end
    
    -- ② 尝试破坏火把（火把是独立节点，优先处理）
    if self:tryDestroyTorch() then
        return true
    end
    
    -- ③ 获取目标方块
    local bx, by, bz = self:getTargetBlock()
    if not bx then
        return false
    end
    
    -- ④ 根据模式执行破坏逻辑
    if self.isNetworkMode then
        return self:destroyBlockNetwork(bx, by, bz)
    else
        return self:destroyBlockLocal(bx, by, bz)
    end
end

---处理右键点击（放置方块）
---@return boolean 是否有操作执行
function BlockInteraction:onRightClick()
    -- ① 立即播放挥臂动画（任何模式都执行）
    if self.player and self.player.swingArm then
        self.player:swingArm()
    end
    
    -- ② 获取目标方块和放置位置
    local bx, by, bz, prevBx, prevBy, prevBz = self:getTargetBlock()
    if not bx or not prevBx then
        return false
    end
    
    -- ③ 获取要放置的方块类型
    local blockType = self.player:getSelectedBlockType()
    
    -- ④ 根据模式执行放置逻辑
    if self.isNetworkMode then
        return self:placeBlockNetwork(prevBx, prevBy, prevBz, blockType)
    else
        return self:placeBlockLocal(prevBx, prevBy, prevBz, blockType)
    end
end

-- ============================================================================
-- 单机模式：直接操作本地 world
-- ============================================================================

---本地破坏方块
---@param bx number 方块X坐标
---@param by number 方块Y坐标
---@param bz number 方块Z坐标
---@return boolean 是否成功
function BlockInteraction:destroyBlockLocal(bx, by, bz)
    local blockType = self.world:getBlock(bx, by, bz)
    if blockType == AIR then
        return false
    end
    
    -- 移除方块
    self.world:setBlock(bx, by, bz, AIR)
    
    -- 播放破坏粒子
    if self.particleSystem then
        self.particleSystem:spawnBreakParticles(bx, by, bz, blockType)
    end
    
    -- 发送本地事件
    local eventData = VariantMap()
    eventData["X"] = Variant(bx)
    eventData["Y"] = Variant(by)
    eventData["Z"] = Variant(bz)
    eventData["BlockType"] = Variant(blockType)
    SendEvent(Events.BLOCK_DESTROYED, eventData)
    
    return true
end

---本地放置方块
---@param bx number 放置位置X坐标
---@param by number 放置位置Y坐标
---@param bz number 放置位置Z坐标
---@param blockType number 方块类型
---@return boolean 是否成功
function BlockInteraction:placeBlockLocal(bx, by, bz, blockType)
    local currentBlock = self.world:getBlock(bx, by, bz)
    if currentBlock ~= AIR then
        return false
    end
    
    local block = Blocks:get(blockType)
    
    -- 火把特殊处理
    if block and block.isItem and blockType == Blocks.TORCH then
        if self.torchDecorator then
            self.torchDecorator:addTorch(bx, by, bz)
        end
    else
        -- 普通方块放置
        self.world:setBlock(bx, by, bz, blockType)
    end
    
    -- 发送本地事件
    local eventData = VariantMap()
    eventData["X"] = Variant(bx)
    eventData["Y"] = Variant(by)
    eventData["Z"] = Variant(bz)
    eventData["BlockType"] = Variant(blockType)
    SendEvent(Events.BLOCK_PLACED, eventData)
    
    return true
end

-- ============================================================================
-- 联机模式：发送网络请求到服务器
-- ============================================================================

---网络模式破坏方块（发送请求到服务器）
---@param bx number 方块X坐标
---@param by number 方块Y坐标
---@param bz number 方块Z坐标
---@return boolean 是否发送成功
function BlockInteraction:destroyBlockNetwork(bx, by, bz)
    if not self.serverConnection then
        print("[BlockInteraction] Error: No server connection")
        return false
    end
    
    self:loadNetworkConstants()
    
    local actionData = VariantMap()
    actionData["Action"] = Variant(self.blockActions.DESTROY)
    actionData["X"] = Variant(bx)
    actionData["Y"] = Variant(by)
    actionData["Z"] = Variant(bz)
    self.serverConnection:SendRemoteEvent(self.networkEvents.BLOCK_ACTION, true, actionData)
    
    return true
end

---网络模式放置方块（发送请求到服务器）
---@param bx number 放置位置X坐标
---@param by number 放置位置Y坐标
---@param bz number 放置位置Z坐标
---@param blockType number 方块类型
---@return boolean 是否发送成功
function BlockInteraction:placeBlockNetwork(bx, by, bz, blockType)
    if not self.serverConnection then
        print("[BlockInteraction] Error: No server connection")
        return false
    end
    
    local block = Blocks:get(blockType)
    
    -- 火把特殊处理：客户端本地创建（带光源效果）
    if block and block.isItem and blockType == Blocks.TORCH then
        if self.torchDecorator then
            self.torchDecorator:addTorch(bx, by, bz)
        end
        return true
    end
    
    -- 其他方块：发送到服务器
    self:loadNetworkConstants()
    
    local actionData = VariantMap()
    actionData["Action"] = Variant(self.blockActions.PLACE)
    actionData["X"] = Variant(bx)
    actionData["Y"] = Variant(by)
    actionData["Z"] = Variant(bz)
    actionData["BlockType"] = Variant(blockType)
    self.serverConnection:SendRemoteEvent(self.networkEvents.BLOCK_ACTION, true, actionData)
    
    return true
end

-- ============================================================================
-- 射线检测（DDA 算法）
-- ============================================================================

---DDA 射线检测（无临时 Vector3 对象，减少 GC 开销）
---@return number|nil, number|nil, number|nil, number|nil, number|nil, number|nil 方块坐标和前一个位置坐标
function BlockInteraction:raycastDDA()
    local world = self.world
    local startPos = self.player:getEyePosition()
    local dir = self.player:getLookDirection()
    
    -- 转换为方块坐标系
    local startX = startPos.x / BLOCK_SIZE
    local startY = startPos.y / BLOCK_SIZE
    local startZ = startPos.z / BLOCK_SIZE
    
    local x = floor(startX)
    local y = floor(startY)
    local z = floor(startZ)
    
    -- 方向分量
    local dirX, dirY, dirZ = dir.x, dir.y, dir.z
    
    -- 步进方向
    local stepX = dirX > 0 and 1 or -1
    local stepY = dirY > 0 and 1 or -1
    local stepZ = dirZ > 0 and 1 or -1
    
    -- 边界处理：避免除零（使用 math.huge 语义更清晰）
    local huge = math.huge
    local tDeltaX = abs(dirX) > 1e-8 and abs(1 / dirX) or huge
    local tDeltaY = abs(dirY) > 1e-8 and abs(1 / dirY) or huge
    local tDeltaZ = abs(dirZ) > 1e-8 and abs(1 / dirZ) or huge
    
    -- 计算到第一个边界的距离
    local tMaxX, tMaxY, tMaxZ
    if stepX > 0 then
        tMaxX = tDeltaX * (x + 1 - startX)
    else
        tMaxX = tDeltaX * (startX - x)
    end
    if stepY > 0 then
        tMaxY = tDeltaY * (y + 1 - startY)
    else
        tMaxY = tDeltaY * (startY - y)
    end
    if stepZ > 0 then
        tMaxZ = tDeltaZ * (z + 1 - startZ)
    else
        tMaxZ = tDeltaZ * (startZ - z)
    end
    
    -- 记录前一个位置（用于 placeBlock）
    local prevX, prevY, prevZ = x, y, z
    
    -- 最大距离（方块单位）
    local maxDist = REACH_DISTANCE / BLOCK_SIZE
    local t = 0
    
    -- DDA 主循环
    while t < maxDist do
        -- 检查当前方块
        local block = world:getBlock(x, y, z)
        if block ~= AIR then
            return x, y, z, prevX, prevY, prevZ
        end
        
        -- 保存前一个位置
        prevX, prevY, prevZ = x, y, z
        
        -- 步进到下一个方块
        if tMaxX < tMaxY and tMaxX < tMaxZ then
            x = x + stepX
            t = tMaxX
            tMaxX = tMaxX + tDeltaX
        elseif tMaxY < tMaxZ then
            y = y + stepY
            t = tMaxY
            tMaxY = tMaxY + tDeltaY
        else
            z = z + stepZ
            t = tMaxZ
            tMaxZ = tMaxZ + tDeltaZ
        end
    end
    
    return nil, nil, nil, nil, nil, nil
end

---获取目标方块（使用 DDA 射线检测）
---@return number|nil, number|nil, number|nil, number|nil, number|nil, number|nil 方块坐标和前一个位置坐标
function BlockInteraction:getTargetBlock()
    return self:raycastDDA()
end

-- ============================================================================
-- 火把处理
-- ============================================================================

---尝试破坏火把
---@return boolean 是否成功破坏火把
function BlockInteraction:tryDestroyTorch()
    if not self.torchDecorator then
        return false
    end
    
    local startPos = self.player:getEyePosition()
    local dir = self.player:getLookDirection()
    
    -- 遍历所有火把检查碰撞
    local closestDist = REACH_DISTANCE
    local closestTorch = nil
    
    for i, torch in ipairs(self.torchDecorator.torches) do
        local torchPos = Vector3(
            torch.blockX * BLOCK_SIZE + BLOCK_SIZE * 0.5,
            torch.blockY * BLOCK_SIZE + BLOCK_SIZE * 0.4,  -- 火把中心
            torch.blockZ * BLOCK_SIZE + BLOCK_SIZE * 0.5
        )
        
        -- 简单的球体碰撞检测
        local toTorch = torchPos - startPos
        local t = toTorch:DotProduct(dir)
        
        if t > 0 and t < closestDist then
            local closestPoint = startPos + dir * t
            local dist = (closestPoint - torchPos).length
            
            -- 火把碰撞半径
            if dist < BLOCK_SIZE * 0.3 then
                closestDist = t
                closestTorch = torch
            end
        end
    end
    
    if closestTorch then
        self.torchDecorator:removeTorch(
            closestTorch.blockX,
            closestTorch.blockY,
            closestTorch.blockZ
        )
        return true
    end
    
    return false
end

-- ============================================================================
-- 兼容旧接口（向后兼容）
-- ============================================================================

---破坏方块（兼容旧接口）
---@return boolean 是否成功破坏
function BlockInteraction:destroyBlock()
    return self:onLeftClick()
end

---放置方块（兼容旧接口）
---@return boolean 是否成功放置
function BlockInteraction:placeBlock()
    return self:onRightClick()
end

return BlockInteraction
