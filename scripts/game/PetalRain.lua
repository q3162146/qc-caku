-- ============================================================================
-- game/PetalRain.lua
-- 桃花雨粒子：下落粉色花瓣（BillboardSet + ParticleEmitter，世界空间模拟）。
--   - 桃谷/桃林常驻；阴山关闭（SetScene 按场景键开关，随玩家 XZ 跟随裁剪范围）；
--   - 结局氛围 SetDense(true)：更密更慢（换 dense 粒子参数档）；
--   - 低开销：粒子数 ≤300、castShadows=false、unlit alpha 混合；
--   - 风格贴水墨：软粉花瓣贴图 + 场景 tint 随氛围（朝阳暖粉/桃林清粉）。
-- 节点挂 scene 根（不随 SceneRoot 销毁），切场景只换参数不重建。
-- ============================================================================

local PlayerController = require "game.PlayerController"

local PetalRain = {}

local PETAL_TEXTURE = "textures/petal.png"
local PETAL_TECH = "Techniques/DiffUnlitAlpha.xml"
local EMITTER_HEIGHT = 6.5          -- 发射盒中心高度（米，玩家头顶上方）

--- 场景开关与 tint（仅桃谷/桃林落花；tint 贴场景氛围光色）
local SCENE_ENABLE = {
    chaoyang_gukou = true,
    gu_nei_taolin = true,
}
local SCENE_TINT = {
    chaoyang_gukou = Color(1.0, 0.84, 0.88, 1),   -- 朝阳暖粉
    gu_nei_taolin = Color(0.98, 0.82, 0.90, 1),   -- 桃林清粉
}

---@type Node|nil
local node_ = nil
---@type ParticleEmitter|nil
local emitter_ = nil
---@type ParticleEffect|nil
local normalFx_ = nil
---@type ParticleEffect|nil
local denseFx_ = nil
---@type Material|nil
local material_ = nil
---@type boolean
local enabled_ = false
---@type boolean
local dense_ = false

--- 构建一档粒子参数（normal=常驻疏落 / dense=结局更密更慢）
---@param mat Material
---@param dense boolean
---@return ParticleEffect
local function BuildEffect(mat, dense)
    local fx = ParticleEffect()
    fx:SetMaterial(mat)
    fx:SetNumParticles(dense and 300 or 140)
    fx:SetEmitterType(EMITTER_BOX)
    fx:SetEmitterSize(Vector3(18, 0.6, 18))
    -- 近乎向下、略带水平散布的初速方向
    fx:SetMinDirection(Vector3(-0.3, -1, -0.3))
    fx:SetMaxDirection(Vector3(0.3, -1, 0.3))
    -- 微重力 + 阻尼 → 缓慢飘落（dense 更慢）
    fx:SetConstantForce(dense and Vector3(0.2, -0.55, 0.08) or Vector3(0.25, -1.0, 0.1))
    fx:SetDampingForce(0.8)
    fx:SetActiveTime(-1)      -- 持续发射（由 emitting 开关控制）
    fx:SetInactiveTime(-1)
    fx:SetMinEmissionRate(dense and 26 or 12)
    fx:SetMaxEmissionRate(dense and 32 or 16)
    -- 花瓣尺寸：近景可辨、远景成点（首版 0.07~0.15 偏小，截图实测调大）
    fx:SetMinParticleSize(Vector2(0.10, 0.10))
    fx:SetMaxParticleSize(Vector2(0.22, 0.22))
    fx:SetMinTimeToLive(dense and 8 or 5)
    fx:SetMaxTimeToLive(dense and 12 or 8)
    fx:SetMinVelocity(dense and 0.2 or 0.4)
    fx:SetMaxVelocity(dense and 0.5 or 0.9)
    -- 飘落翻转（水墨花瓣打旋）
    fx:SetMinRotation(0)
    fx:SetMaxRotation(360)
    fx:SetMinRotationSpeed(-240)
    fx:SetMaxRotationSpeed(240)
    fx:SetSorted(true)
    -- 透明度淡入淡出（顶点色 alpha 曲线；RGB 白，场景 tint 走材质 MatDiffColor）
    fx:AddColorTime(Color(1, 1, 1, 0), 0.0)
    fx:AddColorTime(Color(1, 1, 1, 0.85), 0.12)
    fx:AddColorTime(Color(1, 1, 1, 0.85), 0.75)
    fx:AddColorTime(Color(1, 1, 1, 0), 1.0)
    return fx
end

--- 创建落花发射器（全局一次，挂 scene 根）
---@param scene Scene
function PetalRain.Create(scene)
    if node_ ~= nil then return end

    local tex = cache:GetResource("Texture2D", PETAL_TEXTURE)
    local tech = cache:GetResource("Technique", PETAL_TECH)
    if tex == nil or tech == nil then
        print("[PetalRain] 警告：花瓣贴图/Technique 缺失，落花禁用 | tex="
            .. tostring(tex ~= nil) .. " tech=" .. tostring(tech ~= nil))
        return
    end
    material_ = Material:new()
    material_:SetTechnique(0, tech)
    material_:SetTexture(TU_DIFFUSE, tex)

    normalFx_ = BuildEffect(material_, false)
    denseFx_ = BuildEffect(material_, true)

    node_ = scene:CreateChild("PetalRain")
    node_.position = Vector3(0, EMITTER_HEIGHT, 0)
    emitter_ = node_:CreateComponent("ParticleEmitter")
    emitter_:SetEffect(normalFx_)
    emitter_.castShadows = false
    emitter_:SetEmitting(false)
    print("[PetalRain] 落花粒子已创建（默认关闭，随场景启用）")
end

--- 按场景键开关落花（阴山无桃花；切场景不清粒子，存量自然落完）
---@param sceneKey string
function PetalRain.SetScene(sceneKey)
    enabled_ = SCENE_ENABLE[sceneKey] == true
    if emitter_ == nil then return end
    local tint = SCENE_TINT[sceneKey]
    if tint ~= nil and material_ ~= nil then
        material_:SetShaderParameter("MatDiffColor", Variant(tint))
    end
    emitter_:SetEmitting(enabled_)
    print("[PetalRain] 场景 " .. tostring(sceneKey) .. " → 落花 "
        .. (enabled_ and "开" or "关"))
end

--- 结局氛围：更密更慢（换参数档；不影响开关状态）
---@param on boolean
function PetalRain.SetDense(on)
    dense_ = on
    if emitter_ == nil then return end
    emitter_:SetEffect(on and denseFx_ or normalFx_)
    print("[PetalRain] 结局氛围落花 " .. (on and "加浓" or "恢复"))
end

--- 每帧：发射器跟随玩家 XZ（落花始终围绕镜头范围，视野外自然裁剪）
---@param dt number
function PetalRain.Update(dt)
    if node_ == nil then return end
    local pnode = PlayerController.GetNode()
    if pnode == nil then return end
    local p = pnode.position
    node_.position = Vector3(p.x, EMITTER_HEIGHT, p.z)
end

---@return boolean
function PetalRain.IsEnabled()
    return enabled_
end

---@return boolean
function PetalRain.IsDense()
    return dense_
end

return PetalRain
