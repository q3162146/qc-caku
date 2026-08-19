-- ====================================================================
-- rendering/ParticleSystem.lua
-- 粒子系统 - 方块破坏效果（完整优化版）
-- 优化：对象池 + 材质缓存 + TempPool + Swap-and-pop + 正确地面检测
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local Events = require("config.GameEvents")
local TempPool = require("utils.TempPool")

-- 常量本地化（避免热路径表查找）
local BLOCK_SIZE = Config.World.BLOCK_SIZE
local PARTICLE_GRAVITY = Config.Particles.GRAVITY
local PARTICLE_LIFETIME = Config.Particles.LIFETIME
local PARTICLE_COUNT_MIN = Config.Particles.COUNT_MIN
local PARTICLE_COUNT_MAX = Config.Particles.COUNT_MAX
local WORLD_HEIGHT = Config.World.WORLD_HEIGHT

-- 函数本地化
local floor = math.floor
local abs = math.abs
local random = math.random
local tempVec3 = TempPool.tempVec3

---@class ParticleSystem
---@field particles table
---@field materialCache table<string, Material>
---@field world World
---@field scene Scene
local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem

-- ====================================================================
-- 粒子节点对象池（避免频繁创建/销毁节点）
-- ====================================================================
local ParticlePool = {
    nodes = {},
    maxPoolSize = 50,
}

---从池中获取节点
---@param scene Node 场景
---@return Node, boolean 节点和是否新创建
function ParticlePool:acquire(scene)
    if #self.nodes > 0 then
        local node = self.nodes[#self.nodes]
        self.nodes[#self.nodes] = nil
        node.enabled = true
        return node, false
    end
    return scene:CreateChild("Particle", LOCAL), true
end

---归还节点到池中
---@param node Node 节点
function ParticlePool:release(node)
    if #self.nodes < self.maxPoolSize then
        node.enabled = false
        self.nodes[#self.nodes + 1] = node
    else
        node:Remove()
    end
end

-- ====================================================================
-- ParticleSystem 实现
-- ====================================================================

---创建粒子系统
---@param scene Node 场景节点
---@param world table World实例
---@return table ParticleSystem实例
function ParticleSystem.new(scene, world)
    local self = setmetatable({}, ParticleSystem)
    self.scene = scene
    self.world = world
    self.particles = {}  -- 活动粒子列表
    
    -- 材质缓存（按颜色，避免每次创建新 Material）
    self.materialCache = {}
    
    -- 订阅方块破坏事件
    SubscribeToEvent(Events.BLOCK_DESTROYED, function(eventType, eventData)
        local x = eventData["X"]:GetInt()
        local y = eventData["Y"]:GetInt()
        local z = eventData["Z"]:GetInt()
        local blockType = eventData["BlockType"]:GetInt()
        self:spawnBreakParticles(x, y, z, blockType)
    end)
    
    return self
end

---获取或创建材质（按颜色缓存）
---@param color Color 颜色
---@return Material 材质
function ParticleSystem:getMaterial(color)
    -- 使用整数颜色作为键（避免浮点比较问题）
    local r = floor(color.r * 255)
    local g = floor(color.g * 255)
    local b = floor(color.b * 255)
    local key = r * 65536 + g * 256 + b
    
    local mat = self.materialCache[key]
    if not mat then
        mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTexture.xml"))
        -- 调暗颜色以匹配 PBR 渲染的方块亮度
        local dimFactor = 0.65
        local dimmedColor = Color(color.r * dimFactor, color.g * dimFactor, color.b * dimFactor, color.a)
        mat:SetShaderParameter("MatDiffColor", Variant(dimmedColor))
        self.materialCache[key] = mat
    end
    
    return mat
end

---生成方块破坏粒子
---@param bx number 方块X坐标
---@param by number 方块Y坐标
---@param bz number 方块Z坐标
---@param blockType number 方块类型
function ParticleSystem:spawnBreakParticles(bx, by, bz, blockType)
    local blockCenter = self.world:blockToWorld(bx, by, bz)
    local color = Blocks:getColor(blockType)
    local centerX, centerY, centerZ = blockCenter.x, blockCenter.y, blockCenter.z
    
    -- 获取缓存的材质
    local material = self:getMaterial(color)
    
    -- 创建 8-12 个粒子
    local numParticles = PARTICLE_COUNT_MIN + floor(random() * (PARTICLE_COUNT_MAX - PARTICLE_COUNT_MIN + 1))
    local particles = self.particles
    
    for i = 1, numParticles do
        -- 方块内随机位置
        local offsetX = (random() - 0.5) * BLOCK_SIZE * 0.8
        local offsetY = (random() - 0.5) * BLOCK_SIZE * 0.8
        local offsetZ = (random() - 0.5) * BLOCK_SIZE * 0.8
        
        -- 随机速度（向外爆炸）
        local speed = 3.0 + random() * 4.0
        local velX = (random() - 0.5) * speed * 2
        local velY = random() * speed * 1.5 + 2.0  -- 向上偏移
        local velZ = (random() - 0.5) * speed * 2
        
        -- 随机大小
        local size = 0.15 + random() * 0.25
        
        -- 从对象池获取粒子节点
        local particleNode, isNew = ParticlePool:acquire(self.scene)
        
        -- 设置位置
        particleNode.position = tempVec3(centerX + offsetX, centerY + offsetY, centerZ + offsetZ)
        
        -- 设置缩放
        particleNode.scale = tempVec3(size, size, size)
        
        -- 获取或创建 StaticModel（复用节点时组件已存在）
        local particleModel = particleNode:GetComponent("StaticModel")
        if not particleModel then
            particleModel = particleNode:CreateComponent("StaticModel", LOCAL)
            particleModel.model = cache:GetResource("Model", "Models/Box.mdl")
        end
        particleModel.material = material
        
        -- 存储粒子数据
        local particle = {
            node = particleNode,
            velocity = Vector3(velX, velY, velZ),
            lifetime = PARTICLE_LIFETIME,
            age = 0,
            initialScale = size,
            rotationSpeed = Vector3(
                (random() - 0.5) * 720,
                (random() - 0.5) * 720,
                (random() - 0.5) * 720
            )
        }
        
        particles[#particles + 1] = particle
    end
end

---更新所有粒子
---@param timeStep number 时间步长
function ParticleSystem:update(timeStep)
    local particles = self.particles
    local world = self.world
    local i = 1
    local n = #particles
    
    while i <= n do
        local p = particles[i]
        p.age = p.age + timeStep
        
        -- 移除过期粒子（使用 swap-and-pop，O(1)）
        if p.age >= p.lifetime then
            ParticlePool:release(p.node)  -- 归还到对象池，而非销毁
            -- Swap with last element and pop
            particles[i] = particles[n]
            particles[n] = nil
            n = n - 1
            -- 不增加 i，重新检查交换过来的元素
        else
            -- 更新速度（应用重力）
            p.velocity.y = p.velocity.y + PARTICLE_GRAVITY * timeStep
            
            -- 更新位置
            local pos = p.node.position
            pos = pos + p.velocity * timeStep
            p.node.position = pos
            
            -- 更新旋转
            local rot = p.node.rotation
            local euler = rot:EulerAngles()
            euler.x = euler.x + p.rotationSpeed.x * timeStep
            euler.y = euler.y + p.rotationSpeed.y * timeStep
            euler.z = euler.z + p.rotationSpeed.z * timeStep
            p.node.rotation = Quaternion(euler.x, euler.y, euler.z)
            
            -- 淡出和缩小
            local lifeRatio = p.age / p.lifetime
            local scale = (1.0 - lifeRatio * 0.5) * p.initialScale
            p.node.scale = tempVec3(scale, scale, scale)
            
            -- 地面碰撞（从粒子位置往下检测，修复地下粒子问题）
            local blockX = floor(pos.x / BLOCK_SIZE)
            local blockY = floor(pos.y / BLOCK_SIZE)
            local blockZ = floor(pos.z / BLOCK_SIZE)
            
            -- 边界检查：世界底部以下视为空气
            local belowBlock = blockY > 0 and world:getBlock(blockX, blockY - 1, blockZ) or 0
            local currentBlock = world:getBlock(blockX, blockY, blockZ)
            
            -- 如果粒子在实心方块内部，向上弹出
            if Blocks:isSolid(currentBlock) then
                p.node.position = tempVec3(pos.x, (blockY + 1) * BLOCK_SIZE, pos.z)
                p.velocity.y = abs(p.velocity.y) * 0.3
            -- 如果粒子下方有实心方块且粒子在方块顶部以下
            elseif Blocks:isSolid(belowBlock) then
                local groundY = blockY * BLOCK_SIZE
                if pos.y < groundY then
                    p.node.position = tempVec3(pos.x, groundY, pos.z)
                    p.velocity.y = -p.velocity.y * 0.3
                    p.velocity.x = p.velocity.x * 0.8
                    p.velocity.z = p.velocity.z * 0.8
                    
                    if abs(p.velocity.y) < 1.0 then
                        p.velocity.y = 0
                    end
                end
            end
            
            i = i + 1
        end
    end
end

---获取活动粒子数量
---@return number 粒子数量
function ParticleSystem:getParticleCount()
    return #self.particles
end

---获取对象池状态（调试用）
---@return number 池中节点数
function ParticleSystem:getPoolSize()
    return #ParticlePool.nodes
end

return ParticleSystem
