-- ====================================================================
-- terrain/TorchDecorator.lua
-- 火把装饰器 - 在世界中放置装饰性火把
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local TempPool = require("utils.TempPool")

-- 函数本地化（热路径优化）
local tempVec3 = TempPool.tempVec3
local tempQuat = TempPool.tempQuat
local tempColor = TempPool.tempColor

---@class TorchDecorator
---@field torchByPos table<string, table>
---@field sparkMaterial Material
---@field scene Scene
local TorchDecorator = {}
TorchDecorator.__index = TorchDecorator

-- 火把配置
local TORCH_CONFIG = {
    density = 0.003,           -- 放置概率（每个草方块）
    minDistance = 8,           -- 火把之间最小距离
    lightBrightness = 4.0,     -- 光源亮度
    lightRange = 10,           -- 光照范围（格）
    lightColor = Color(1.0, 0.8, 0.4),  -- 暖黄色
    flickerEnabled = true,     -- 是否启用闪烁
    
    -- 火花粒子配置
    particleEnabled = true,    -- 是否启用粒子
    particleSpawnRate = 12.0,  -- 每秒生成粒子数（更密集）
    particleLifetime = 0.6,    -- 粒子生命周期（更短）
    particleSize = 0.06,       -- 粒子大小（方块比例）
    particleSpeed = 0.4,       -- 粒子速度（更慢）
    particleGravity = -0.2,    -- 粒子重力（更轻微上飘）
}

---创建火把装饰器
---@param scene table Scene 实例
---@return table TorchDecorator 实例
function TorchDecorator.new(scene)
    local self = setmetatable({}, TorchDecorator)
    self.scene = scene
    self.torches = {}          -- 存储所有火把节点
    self.torchPositions = {}   -- 存储火把位置用于距离检查
    self.torchByPos = {}       -- [key] = torchData，用于快速查找
    self.flickerTime = 0
    
    -- 粒子系统
    self.particles = {}        -- 活动粒子列表
    self.particleSpawnTimers = {}  -- 每个火把的粒子生成计时器
    
    -- 预创建自发光材质（所有火花粒子共享）
    self.sparkMaterial = self:createSparkMaterial()
    
    return self
end

---获取位置键
---@param x number 方块 X
---@param y number 方块 Y
---@param z number 方块 Z
---@return string 位置键
function TorchDecorator:getPosKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

---创建火花粒子材质（超高亮度自发光）
---@return Material 材质
function TorchDecorator:createSparkMaterial()
    local material = Material:new()
    -- 使用 Unlit 自发光材质，不受光照影响
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    -- 超高亮度橙色，产生强烈 bloom
    material:SetShaderParameter("MatDiffColor", Variant(Color(8.0, 4.0, 1.0, 1.0)))
    return material
end

---在世界中放置火把
---@param world table World 实例
---@param centerX number 中心 X
---@param centerZ number 中心 Z
function TorchDecorator:decorate(world, centerX, centerZ)
    centerX = centerX or 0
    centerZ = centerZ or 0
    
    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
    local radius = CHUNK_SIZE * RENDER_DISTANCE
    
    print("[TorchDecorator] Placing torches...")
    
    local torchCount = 0
    
    for x = centerX - radius, centerX + radius do
        for z = centerZ - radius, centerZ + radius do
            local dx = x - centerX
            local dz = z - centerZ
            if dx*dx + dz*dz <= radius*radius then
                if self:tryPlaceTorch(world, x, z) then
                    torchCount = torchCount + 1
                end
            end
        end
    end
    
    print(string.format("[TorchDecorator] Placed %d torches", torchCount))
end

---检查位置是否与现有火把距离足够
---@param x number X 坐标
---@param z number Z 坐标
---@return boolean 是否可以放置
function TorchDecorator:checkMinDistance(x, z)
    local minDist = TORCH_CONFIG.minDistance
    local minDistSq = minDist * minDist
    
    for _, pos in ipairs(self.torchPositions) do
        local dx = x - pos.x
        local dz = z - pos.z
        if dx*dx + dz*dz < minDistSq then
            return false
        end
    end
    return true
end

---尝试在位置放置火把
---@param world table World 实例
---@param x number X 坐标
---@param z number Z 坐标
---@return boolean 是否成功放置
function TorchDecorator:tryPlaceTorch(world, x, z)
    -- 获取地面高度
    local height = world:getGroundHeight(x, z) - 1
    local topBlock = world:getBlock(x, height, z)
    local aboveBlock = world:getBlock(x, height + 1, z)
    
    -- 只在草地上且上方为空气时放置
    if topBlock ~= Blocks.GRASS or aboveBlock ~= Blocks.AIR then
        return false
    end
    
    -- 使用确定性随机
    math.randomseed(x * 54321 + z * 98765)
    local chance = math.random()
    
    if chance > TORCH_CONFIG.density then
        return false
    end
    
    -- 检查距离
    if not self:checkMinDistance(x, z) then
        return false
    end
    
    -- 放置火把
    self:createTorch(x, height + 1, z)
    table.insert(self.torchPositions, { x = x, z = z })
    
    return true
end

---创建火把节点（3D 模型 + 光源）
---@param x number 方块 X
---@param y number 方块 Y
---@param z number 方块 Z
function TorchDecorator:createTorch(x, y, z)
    local BLOCK_SIZE = Config.World.BLOCK_SIZE

    -- 创建火把根节点（使用 LOCAL 模式）
    local torchNode = self.scene:CreateChild("Torch_" .. x .. "_" .. z, LOCAL)
    torchNode.position = tempVec3(
        x * BLOCK_SIZE + BLOCK_SIZE * 0.5,
        y * BLOCK_SIZE,
        z * BLOCK_SIZE + BLOCK_SIZE * 0.5
    )

    -- 创建火把几何体
    local geomNode = torchNode:CreateChild("TorchGeometry", LOCAL)
    local geom = geomNode:CreateComponent("CustomGeometry", LOCAL)
    geom:SetNumGeometries(1)

    self:buildTorchGeometry(geom, BLOCK_SIZE)

    -- 创建光源
    local lightNode = torchNode:CreateChild("TorchLight", LOCAL)
    -- 光源位置在火焰顶部
    lightNode.position = tempVec3(0, BLOCK_SIZE * 0.8, 0)

    local light = lightNode:CreateComponent("Light", LOCAL)
    light.lightType = LIGHT_POINT
    light.color = TORCH_CONFIG.lightColor
    light.range = TORCH_CONFIG.lightRange * BLOCK_SIZE
    light.brightness = TORCH_CONFIG.lightBrightness
    light.castShadows = false  -- 装饰火把不投射阴影（性能考虑）
    
    -- 火焰顶部位置（粒子生成点）
    local flameTopY = BLOCK_SIZE * 0.88  -- 火焰顶部
    
    -- 存储火把信息
    local torchData = {
        node = torchNode,
        light = light,
        basePosition = Vector3(x, y, z),
        blockX = x,
        blockY = y,
        blockZ = z,
        -- 粒子生成位置（火焰顶部）
        particleSpawnPos = Vector3(
            x * BLOCK_SIZE + BLOCK_SIZE * 0.5,
            y * BLOCK_SIZE + flameTopY,
            z * BLOCK_SIZE + BLOCK_SIZE * 0.5
        ),
        spawnTimer = math.random() * 0.5,  -- 随机初始延迟，避免同步
    }
    table.insert(self.torches, torchData)
    
    -- 添加到位置索引
    local posKey = self:getPosKey(x, y, z)
    self.torchByPos[posKey] = torchData
end

---构建火把几何体
---@param geom CustomGeometry 几何体组件
---@param BLOCK_SIZE number 方块大小
function TorchDecorator:buildTorchGeometry(geom, BLOCK_SIZE)
    -- 火把参数
    local stickWidth = 0.06 * BLOCK_SIZE
    local stickHeight = 0.7 * BLOCK_SIZE
    local flameWidth = 0.12 * BLOCK_SIZE
    local flameHeight = 0.18 * BLOCK_SIZE
    
    geom:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 木棍颜色
    local stickColor = Color(0.5, 0.3, 0.1)
    -- 火焰颜色（超高亮度）
    local flameColorBottom = Color(5.0, 3.0, 0.8)
    local flameColorTop = Color(6.0, 5.0, 2.0)
    
    local hw = stickWidth * 0.5
    local hh = stickHeight * 0.5
    
    -- ============================================
    -- 绘制木棍（4个面）
    -- ============================================
    local stickFaces = {
        { normal = {1,0,0}, verts = {
            {hw, 0, -hw}, {hw, stickHeight, -hw}, {hw, stickHeight, hw},
            {hw, 0, -hw}, {hw, stickHeight, hw}, {hw, 0, hw},
        }},
        { normal = {-1,0,0}, verts = {
            {-hw, 0, hw}, {-hw, stickHeight, hw}, {-hw, stickHeight, -hw},
            {-hw, 0, hw}, {-hw, stickHeight, -hw}, {-hw, 0, -hw},
        }},
        { normal = {0,0,1}, verts = {
            {-hw, 0, hw}, {hw, 0, hw}, {hw, stickHeight, hw},
            {-hw, 0, hw}, {hw, stickHeight, hw}, {-hw, stickHeight, hw},
        }},
        { normal = {0,0,-1}, verts = {
            {hw, 0, -hw}, {-hw, 0, -hw}, {-hw, stickHeight, -hw},
            {hw, 0, -hw}, {-hw, stickHeight, -hw}, {hw, stickHeight, -hw},
        }},
    }
    
    for _, face in ipairs(stickFaces) do
        local normal = Vector3(face.normal[1], face.normal[2], face.normal[3])
        for _, vert in ipairs(face.verts) do
            geom:DefineVertex(Vector3(vert[1], vert[2], vert[3]))
            geom:DefineNormal(normal)
            geom:DefineColor(stickColor)
        end
    end
    
    -- ============================================
    -- 绘制火焰（交叉的两个面）
    -- ============================================
    local flameBaseY = stickHeight
    local flameTopY = stickHeight + flameHeight
    local fhw = flameWidth * 0.5
    
    local flameFace1 = {
        {-fhw, flameBaseY, 0, flameColorBottom},
        {fhw, flameBaseY, 0, flameColorBottom},
        {fhw * 0.3, flameTopY, 0, flameColorTop},
        {-fhw, flameBaseY, 0, flameColorBottom},
        {fhw * 0.3, flameTopY, 0, flameColorTop},
        {-fhw * 0.3, flameTopY, 0, flameColorTop},
    }
    
    local flameFace2 = {
        {0, flameBaseY, -fhw, flameColorBottom},
        {0, flameBaseY, fhw, flameColorBottom},
        {0, flameTopY, fhw * 0.3, flameColorTop},
        {0, flameBaseY, -fhw, flameColorBottom},
        {0, flameTopY, fhw * 0.3, flameColorTop},
        {0, flameTopY, -fhw * 0.3, flameColorTop},
    }
    
    -- 绘制火焰面（双面）
    for _, face in ipairs({flameFace1, flameFace2}) do
        for _, vert in ipairs(face) do
            geom:DefineVertex(Vector3(vert[1], vert[2], vert[3]))
            geom:DefineNormal(Vector3(0, 1, 0))
            geom:DefineColor(vert[4])
        end
        for i = #face, 1, -1 do
            local vert = face[i]
            geom:DefineVertex(Vector3(vert[1], vert[2], vert[3]))
            geom:DefineNormal(Vector3(0, -1, 0))
            geom:DefineColor(vert[4])
        end
    end
    
    geom:Commit()
    
    -- 使用 Unlit 自发光材质
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlitVCol.xml"))
    geom:SetMaterial(0, material)
end

---更新火把闪烁效果（每帧调用）
---@param timeStep number 时间步长
function TorchDecorator:update(timeStep)
    self.flickerTime = self.flickerTime + timeStep

    -- 更新光源闪烁
    if TORCH_CONFIG.flickerEnabled then
        for i, torch in ipairs(self.torches) do
            if torch.light then
                local phase = i * 0.7
                local flicker = 1.0 
                    + math.sin(self.flickerTime * 8 + phase) * 0.15
                    + math.sin(self.flickerTime * 13 + phase * 1.3) * 0.08
                    + math.sin(self.flickerTime * 21 + phase * 0.5) * 0.05
                
                torch.light.brightness = TORCH_CONFIG.lightBrightness * flicker
                
                local colorShift = math.sin(self.flickerTime * 5 + phase) * 0.05
                torch.light.color = tempColor(1.0, 0.8 + colorShift, 0.4 - colorShift * 0.5)
            end
        end
    end
    
    -- 更新粒子系统
    if TORCH_CONFIG.particleEnabled then
        self:updateParticleSpawning(timeStep)
        self:updateParticles(timeStep)
    end
end

---更新粒子生成
---@param timeStep number 时间步长
function TorchDecorator:updateParticleSpawning(timeStep)
    local spawnInterval = 1.0 / TORCH_CONFIG.particleSpawnRate
    
    for i, torch in ipairs(self.torches) do
        torch.spawnTimer = torch.spawnTimer + timeStep
        
        -- 检查是否应该生成粒子
        while torch.spawnTimer >= spawnInterval do
            torch.spawnTimer = torch.spawnTimer - spawnInterval
            self:spawnSparkParticle(torch.particleSpawnPos)
        end
    end
end

---生成火花粒子
---@param spawnPos Vector3 生成位置
function TorchDecorator:spawnSparkParticle(spawnPos)
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local size = TORCH_CONFIG.particleSize * BLOCK_SIZE
    
    -- 随机偏移（在火焰范围内）
    local offsetX = (math.random() - 0.5) * 0.1 * BLOCK_SIZE
    local offsetZ = (math.random() - 0.5) * 0.1 * BLOCK_SIZE

    -- 创建粒子节点（小方块，使用 LOCAL 模式）
    local particleNode = self.scene:CreateChild("TorchSpark", LOCAL)
    particleNode.position = tempVec3(spawnPos.x + offsetX, spawnPos.y, spawnPos.z + offsetZ)

    -- 随机大小变化
    local sizeVariation = size * (0.5 + math.random() * 0.5)
    particleNode.scale = tempVec3(sizeVariation, sizeVariation, sizeVariation)

    -- 随机初始旋转
    particleNode.rotation = tempQuat(math.random() * 360, math.random() * 360, math.random() * 360)

    local particleModel = particleNode:CreateComponent("StaticModel", LOCAL)
    particleModel.model = cache:GetResource("Model", "Models/Box.mdl")
    particleModel.material = self.sparkMaterial
    
    -- 随机速度（轻微向上，略微四散）
    local speed = TORCH_CONFIG.particleSpeed * BLOCK_SIZE
    local velX = (math.random() - 0.5) * speed * 1.2  -- 更多水平散开
    local velY = speed * (0.3 + math.random() * 0.5)  -- 更低的上升速度
    local velZ = (math.random() - 0.5) * speed * 1.2
    
    -- 存储粒子数据
    local particle = {
        node = particleNode,
        velocity = Vector3(velX, velY, velZ),
        lifetime = TORCH_CONFIG.particleLifetime * (0.7 + math.random() * 0.6),
        age = 0,
        initialScale = sizeVariation,
        rotationSpeed = Vector3(
            (math.random() - 0.5) * 540,
            (math.random() - 0.5) * 540,
            (math.random() - 0.5) * 540
        ),
        -- 随机颜色变化（橙色到黄色范围）
        colorPhase = math.random() * math.pi * 2,
    }
    
    table.insert(self.particles, particle)
end

---更新所有粒子
---@param timeStep number 时间步长
function TorchDecorator:updateParticles(timeStep)
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local gravity = TORCH_CONFIG.particleGravity * BLOCK_SIZE

    local i = 1
    while i <= #self.particles do
        local p = self.particles[i]
        p.age = p.age + timeStep
        
        -- 移除过期粒子
        if p.age >= p.lifetime then
            p.node:Remove()
            table.remove(self.particles, i)
        else
            -- 更新速度（应用负重力使粒子上升）
            p.velocity.y = p.velocity.y - gravity * timeStep
            
            -- 添加一些随机摆动
            local wobble = math.sin(p.age * 10 + p.colorPhase) * 0.3 * BLOCK_SIZE
            p.velocity.x = p.velocity.x + wobble * timeStep
            p.velocity.z = p.velocity.z + wobble * 0.7 * timeStep
            
            -- 更新位置（避免 Vector3 运算产生临时对象）
            local pos = p.node.position
            local vel = p.velocity
            p.node.position = tempVec3(
                pos.x + vel.x * timeStep,
                pos.y + vel.y * timeStep,
                pos.z + vel.z * timeStep
            )

            -- 更新旋转
            local rot = p.node.rotation
            local euler = rot:EulerAngles()
            local rotSpeed = p.rotationSpeed
            p.node.rotation = tempQuat(
                euler.x + rotSpeed.x * timeStep,
                euler.y + rotSpeed.y * timeStep,
                euler.z + rotSpeed.z * timeStep
            )

            -- 淡出和缩小
            local lifeRatio = p.age / p.lifetime
            -- 前半生保持大小，后半生快速缩小
            local scale
            if lifeRatio < 0.5 then
                scale = p.initialScale
            else
                local fadeRatio = (lifeRatio - 0.5) * 2  -- 0 to 1
                scale = p.initialScale * (1.0 - fadeRatio * 0.8)
            end
            p.node.scale = tempVec3(scale, scale, scale)

            i = i + 1
        end
    end
end

---销毁所有火把
function TorchDecorator:destroy()
    -- 清理粒子
    for _, particle in ipairs(self.particles) do
        if particle.node then
            particle.node:Remove()
        end
    end
    self.particles = {}
    
    -- 清理火把
    for _, torch in ipairs(self.torches) do
        if torch.node then
            torch.node:Remove()
        end
    end
    self.torches = {}
    self.torchPositions = {}
    print("[TorchDecorator] All torches and particles destroyed")
end

---获取火把数量
---@return number 火把数量
function TorchDecorator:getTorchCount()
    return #self.torches
end

---获取活动粒子数量
---@return number 粒子数量
function TorchDecorator:getParticleCount()
    return #self.particles
end

-- ============================================
-- 公开 API：添加/移除/检测火把
-- ============================================

---在指定位置添加火把（玩家放置时调用）
---@param x number 方块 X
---@param y number 方块 Y
---@param z number 方块 Z
---@return boolean 是否成功添加
function TorchDecorator:addTorch(x, y, z)
    local posKey = self:getPosKey(x, y, z)
    
    -- 检查是否已存在
    if self.torchByPos[posKey] then
        return false
    end
    
    -- 创建火把
    self:createTorch(x, y, z)
    table.insert(self.torchPositions, { x = x, z = z })
    
    print(string.format("[TorchDecorator] Added torch at (%d, %d, %d)", x, y, z))
    return true
end

---移除指定位置的火把（玩家破坏时调用）
---@param x number 方块 X
---@param y number 方块 Y
---@param z number 方块 Z
---@return boolean 是否成功移除
function TorchDecorator:removeTorch(x, y, z)
    local posKey = self:getPosKey(x, y, z)
    local torchData = self.torchByPos[posKey]
    
    if not torchData then
        return false
    end
    
    -- 移除节点
    if torchData.node then
        torchData.node:Remove()
    end
    
    -- 从 torchByPos 移除
    self.torchByPos[posKey] = nil
    
    -- 从 torches 列表移除
    for i, torch in ipairs(self.torches) do
        if torch == torchData then
            table.remove(self.torches, i)
            break
        end
    end
    
    -- 从 torchPositions 移除
    for i, pos in ipairs(self.torchPositions) do
        if pos.x == x and pos.z == z then
            table.remove(self.torchPositions, i)
            break
        end
    end
    
    print(string.format("[TorchDecorator] Removed torch at (%d, %d, %d)", x, y, z))
    return true
end

---检查指定位置是否有火把
---@param x number 方块 X
---@param y number 方块 Y
---@param z number 方块 Z
---@return boolean 是否有火把
function TorchDecorator:hasTorch(x, y, z)
    local posKey = self:getPosKey(x, y, z)
    return self.torchByPos[posKey] ~= nil
end

---获取指定位置的火把数据
---@param x number 方块 X
---@param y number 方块 Y
---@param z number 方块 Z
---@return table|nil 火把数据
function TorchDecorator:getTorch(x, y, z)
    local posKey = self:getPosKey(x, y, z)
    return self.torchByPos[posKey]
end

---清理指定区块内的火把（区块卸载时调用）
---@param chunkX number 区块 X
---@param chunkZ number 区块 Z
---@return number 清理的火把数量
function TorchDecorator:cleanupChunk(chunkX, chunkZ)
    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local minX = chunkX * CHUNK_SIZE
    local maxX = minX + CHUNK_SIZE - 1
    local minZ = chunkZ * CHUNK_SIZE
    local maxZ = minZ + CHUNK_SIZE - 1
    
    local cleanedCount = 0
    
    -- 倒序遍历避免删除时索引问题
    for i = #self.torches, 1, -1 do
        local torch = self.torches[i]
        if torch.blockX >= minX and torch.blockX <= maxX 
           and torch.blockZ >= minZ and torch.blockZ <= maxZ then
            self:removeTorch(torch.blockX, torch.blockY, torch.blockZ)
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 0 then
        print(string.format("[TorchDecorator] Cleaned up %d torches in chunk (%d, %d)", 
            cleanedCount, chunkX, chunkZ))
    end
    
    return cleanedCount
end

return TorchDecorator

