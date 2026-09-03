-- ============================================================================
-- game/BlossomGlow.lua
-- 桃花标记发光特效（真机外观修复 ①）：让五朵五行桃花远处可辨、走近可采。
-- 每朵（Blossom_<key> 触发球为父节点）叠加：
--   1) 五行色点光源：对应 rgb、range 2.5、不投影，照亮周围地面；
--   2) 点光呼吸脉冲：Update 按 sin 轻微调整亮度，靠近时增亮提示可采；
--   3) 漂浮微光：每朵一个微型 ParticleEmitter（petal.png、≤12 粒、不投影）；
-- 不再创建 additive 无贴图发光球壳，避免桃花处出现白色实心球。
-- 挂在 Blossom_<key> 触发球节点下：FlowController 采集 node:Remove() 时
-- 子树（灯/粒子）随父节点一并移除，无需额外清理。
-- 开销：每朵 1 灯 1 发射器 ≤12 粒；同屏最多 5 朵 = 5 灯 + 60 粒，远低于性能红线。
-- ============================================================================

local PlayerController = require "game.PlayerController"

local BlossomGlow = {}

local PETAL_TEXTURE = "textures/petal.png"
local PETAL_TECH = "Techniques/DiffUnlitAlpha.xml"
local NEAR_RADIUS = 2.2        -- 靠近高亮半径（米；略大于采集半径 1.6 提前给提示）
local PULSE_SPEED = 2.4       -- 呼吸角速度（rad/s)
local NEAR_BOOST = 1.35       -- 靠近时点光增亮

--- 五行配色（与 SceneManager blossomSpots rgb 一致；点光/外壳同色）
local BLOSSOM_RGB = {
    wood = { 0.36, 0.72, 0.38 },
    fire = { 0.90, 0.35, 0.30 },
    earth = { 0.78, 0.62, 0.36 },
    metal = { 0.82, 0.82, 0.86 },
    water = { 0.34, 0.55, 0.85 },
}

---@class BlossomGlowEntry
---@field bNode Node 触发球节点
---@field light Light|nil 点光源
---@field emitter ParticleEmitter|nil 微光粒子
---@field phase number 呼吸相位（错开各朵脉动）
---@field near boolean 当前是否靠近
local entries_ = {}           ---@type BlossomGlowEntry[]
local time_ = 0

--- 微光粒子效果（花瓣贴图 + 极少量上浮闪烁粒子）
---@param mat Material
---@return ParticleEffect|nil
local function MakeSparkleEffect(mat)
    local fx = ParticleEffect()
    fx:SetMaterial(mat)
    fx:SetNumParticles(12)
    fx:SetEmitterType(EMITTER_SPHERE)
    fx:SetEmitterSize(Vector3(0.5, 0.5, 0.5))
    fx:SetMinDirection(Vector3(0, 1, 0))
    fx:SetMaxDirection(Vector3(0, 1, 0))
    fx:SetConstantForce(Vector3(0, 0.35, 0))   -- 轻微上浮
    fx:SetDampingForce(0.6)
    fx:SetActiveTime(-1)
    fx:SetInactiveTime(-1)
    fx:SetMinEmissionRate(2)
    fx:SetMaxEmissionRate(4)
    fx:SetMinParticleSize(Vector2(0.05, 0.05))
    fx:SetMaxParticleSize(Vector2(0.10, 0.10))
    fx:SetMinTimeToLive(1.5)
    fx:SetMaxTimeToLive(2.5)
    fx:SetMinVelocity(0.1)
    fx:SetMaxVelocity(0.3)
    fx:SetMinRotationSpeed(-180)
    fx:SetMaxRotationSpeed(180)
    fx:SetSorted(true)
    fx:AddColorTime(Color(1, 1, 1, 0), 0.0)
    fx:AddColorTime(Color(1, 1, 1, 0.9), 0.2)
    fx:AddColorTime(Color(1, 1, 1, 0.9), 0.7)
    fx:AddColorTime(Color(1, 1, 1, 0), 1.0)
    return fx
end

--- 给一朵桃花挂发光组（挂在触发球节点下，采集移除时随父节点消失）
---@param bNode Node Blossom_<key> 触发球节点
---@param key string 五行键
function BlossomGlow.Attach(bNode, key)
    if bNode == nil then return end
    local rgb = BLOSSOM_RGB[key] or { 1, 0.8, 0.9 }

    -- 1) 点光源（五行色、range 2.5、不投影）
    local lightNode = bNode:CreateChild("GlowLight_" .. key)
    ---@type Light
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = Color(rgb[1], rgb[2], rgb[3])
    light.brightness = 1.2
    light.range = 2.5
    light.castShadows = false

    -- 2) 漂浮微光粒子（花瓣贴图，轻量）
    ---@type ParticleEmitter|nil
    local emitter = nil
    local petalTex = cache:GetResource("Texture2D", PETAL_TEXTURE)
    local petalTech = cache:GetResource("Technique", PETAL_TECH)
    if petalTex ~= nil and petalTech ~= nil then
        local pmat = Material:new()
        pmat:SetTechnique(0, petalTech)
        pmat:SetTexture(TU_DIFFUSE, petalTex)
        local fx = MakeSparkleEffect(pmat)
        local pnode = bNode:CreateChild("GlowSparkle_" .. key)
        pnode.position = Vector3(0, 0.5, 0)
        emitter = pnode:CreateComponent("ParticleEmitter")
        emitter:SetEffect(fx)
        emitter.castShadows = false
    end

    table.insert(entries_, {
        bNode = bNode,
        light = light,
        emitter = emitter,
        phase = #entries_ * 1.3,   -- 错开各朵呼吸相位
        near = false,
    })
end

--- 场景加载后按 Blossom_<key> 节点名批量挂发光（仅对仍存活的标记）
---@param scene Scene
function BlossomGlow.AttachAll(scene)
    entries_ = {}
    local children = scene:GetChildren(true)
    for _, child in ipairs(children) do
        local key = string.match(child.name, "^Blossom_(%w+)$")
        if key ~= nil then
            BlossomGlow.Attach(child, key)
        end
    end
    print("[BlossomGlow] 已挂发光组 ×" .. tostring(#entries_))
end

--- 每帧：呼吸脉冲 + 靠近高亮
---@param dt number
function BlossomGlow.Update(dt)
    time_ = time_ + dt
    local pnode = PlayerController.GetNode()
    local px, pz = 0, 0
    local hasPlayer = pnode ~= nil
    if hasPlayer then
        px, pz = pnode.position.x, pnode.position.z
    end

    -- 存活过滤：采集移除（node:Remove()）后父级为 nil，惰性清理注册表
    local alive = {}
    for _, e in ipairs(entries_) do
        if e ~= nil and e.bNode ~= nil and e.bNode:GetParent() ~= nil then
            table.insert(alive, e)

            local near = false
            if hasPlayer then
                local wp = e.bNode.worldPosition
                local dx = wp.x - px
                local dz = wp.z - pz
                near = (dx * dx + dz * dz) <= NEAR_RADIUS * NEAR_RADIUS
            end
            e.near = near

            -- 呼吸脉冲：只调整点光亮度；靠近时增亮作为采集提示。
            if e.light ~= nil then
                e.light.brightness = (near and 2.2 or 1.2)
                    + 0.3 * math.sin(time_ * PULSE_SPEED + e.phase)
            end
        end
    end
    entries_ = alive
end

return BlossomGlow
