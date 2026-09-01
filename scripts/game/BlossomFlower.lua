-- ============================================================================
-- game/BlossomFlower.lua
-- 真机修复 ①（桃花视觉）：程序化粉色桃花簇，替换 Blossom_<key> 触发球的
-- 灰白占位球视觉。纯本地程序化几何 + 材质，零网络依赖 → 真机必显示
-- （真实桃花模型走 DWP 属媒体资源，真机可能占位空窗；程序花簇兜底）。
--
-- 设计（每朵，挂在 Blossom_<key> 触发球节点下，采集随父节点一并移除）：
--   1) 剥掉触发球的 StaticModel 视觉（TRIGGER 碰撞/节点名/位置原样保留）；
--   2) 一支短花枝（细圆柱）+ 3 朵五瓣桃花（压扁球体做花瓣，水墨粉）
--      + 五行色花蕊（与 BlossomGlow 点光同色，五朵可辨）；
--   3) 轻量花瓣飘落：每朵一个微型粒子发射器（≤6 粒、缓慢下落打旋）。
-- 发光（壳/点光/呼吸/靠近高亮/微光）由 BlossomGlow 继续提供，本模块不重复。
--
-- 几何共享：花瓣/花蕊/花枝模型各生成一次（ToModel 复用），材质共享，
-- 花蕊材质按五行键惰性创建（5 个）。单朵 11 个 StaticModel + 1 发射器（≤6 粒），
-- 同屏最多 5 朵 = 55 小几何 + 30 粒，远低于性能红线。
-- ============================================================================

local SceneProps = require "game.SceneProps"

local BlossomFlower = {}

local PETAL_TECH = "Techniques/DiffUnlitAlpha.xml"   -- 飘落花瓣（贴图透明）
local FALL_TEXTURE = "textures/petal.png"

--- 水墨粉花瓣 / 花枝棕 / 五行花蕊色（与 BlossomGlow BLOSSOM_RGB 一致）
local PETAL_RGB = { 0.98, 0.78, 0.84 }
local PETAL_TIP_RGB = { 1.0, 0.88, 0.92 }      -- 外层花瓣稍亮，层次
local BRANCH_RGB = { 0.42, 0.28, 0.20 }
local STAMEN_RGB = {
    wood = { 0.55, 0.90, 0.55 },
    fire = { 1.00, 0.55, 0.45 },
    earth = { 0.95, 0.80, 0.50 },
    metal = { 0.95, 0.95, 1.00 },
    water = { 0.55, 0.75, 1.00 },
}

-- 共享几何/材质（EnsureShared 惰性创建）
---@type Model|nil
local petalModel_ = nil
---@type Model|nil
local stamenModel_ = nil
---@type Model|nil
local branchModel_ = nil
---@type Model|nil
local budModel_ = nil
---@type Material|nil
local petalMat_ = nil
---@type Material|nil
local petalTipMat_ = nil
---@type Material|nil
local branchMat_ = nil
---@type Material|nil
local fallMat_ = nil
---@type table<string, Material>
local stamenMats_ = {}
local ready_ = false

--- 纯色材质（光照 PBR，贴场景氛围光：阴山冷光下花瓣泛冷粉）
---@param rgb table
---@param emissive? number 自发光强度（0~1；桃花在阴山暗景保底可见）
---@return Material
local function MakeSolidMaterial(rgb, emissive)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
    if emissive ~= nil and emissive > 0 then
        mat:SetShaderParameter("MatEmissiveColor",
            Variant(Color(rgb[1] * emissive, rgb[2] * emissive, rgb[3] * emissive, 1)))
    end
    return mat
end

--- 一次性生成共享几何/材质（失败保持占位球视觉，玩法不破）
local function EnsureShared()
    if ready_ then return true end
    local ok, err = pcall(function()
        petalModel_ = SphereGeometry(1, 10, 8):ToModel()
        stamenModel_ = SphereGeometry(1, 8, 6):ToModel()
        branchModel_ = CylinderGeometry(0.016, 0.030, 0.58, 7, 1):ToModel()
        budModel_ = SphereGeometry(1, 8, 6):ToModel()
    end)
    if not ok or petalModel_ == nil then
        print("[BlossomFlower] 警告：程序化几何生成失败，保留占位球视觉: " .. tostring(err))
        return false
    end
    -- 花瓣带轻量自发光（0.35）：阴山暗景/雾中保底粉色可见，桃谷晨景不刺眼
    petalMat_ = MakeSolidMaterial(PETAL_RGB, 0.35)
    petalTipMat_ = MakeSolidMaterial(PETAL_TIP_RGB, 0.40)
    branchMat_ = MakeSolidMaterial(BRANCH_RGB)

    -- 飘落花瓣材质（共享；tint 淡粉）
    local tex = cache:GetResource("Texture2D", FALL_TEXTURE)
    local tech = cache:GetResource("Technique", PETAL_TECH)
    if tex ~= nil and tech ~= nil then
        fallMat_ = Material:new()
        fallMat_:SetTechnique(0, tech)
        fallMat_:SetTexture(TU_DIFFUSE, tex)
        fallMat_:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.85, 0.90, 1)))
    end
    ready_ = true
    print("[BlossomFlower] 共享几何/材质已生成（花瓣=" .. (fallMat_ ~= nil and "含飘落" or "无贴图仅花簇") .. "）")
    return true
end

--- 五行花蕊材质（惰性缓存）
---@param key string
---@return Material
local function GetStamenMaterial(key)
    local mat = stamenMats_[key]
    if mat == nil then
        local rgb = STAMEN_RGB[key] or { 1.0, 0.85, 0.55 }
        -- 花蕊自发光强一档（0.6）：五行色是可辨关键，暗景必亮
        mat = MakeSolidMaterial(rgb, 0.6)
        stamenMats_[key] = mat
    end
    return mat
end

--- 一朵五瓣桃花（局部原点为花心，+Y 朝上；花瓣压扁球体绕心环排、外端微翘）
---@param parent Node
---@param name string
---@param pos Vector3 相对 parent 的位置
---@param yaw number 绕 Y 朝向（度；各朵错开花瓣相位）
---@param scale number 花径缩放（1.0 ≈ 0.45m 花径）
---@param stamenMat Material
---@return Node
local function BuildFlower(parent, name, pos, yaw, scale, stamenMat)
    local flower = parent:CreateChild(name)
    flower.position = pos
    flower:SetRotation(Quaternion(yaw, Vector3.UP))
    flower.scale = Vector3(scale, scale, scale)

    -- 5 片花瓣：72° 环排，径向外展、外端微翘（绕 X 负角 = +Z 端抬起）
    for i = 1, 5 do
        local ang = (i - 1) * 72
        local rad = math.rad(ang)
        local petal = flower:CreateChild("P" .. i)
        petal.position = Vector3(math.sin(rad) * 0.085, 0.008, math.cos(rad) * 0.085)
        petal:SetRotation(Quaternion(ang, Vector3.UP) * Quaternion(-16, Vector3.RIGHT))
        petal.scale = Vector3(0.078, 0.024, 0.135)
        local sm = petal:CreateComponent("StaticModel")
        sm.model = petalModel_
        -- 隔片深浅交错，花更立体（共享材质已由 EnsureShared 初始化，收窄为 Material）
        local pmat = (i % 2 == 1) and petalMat_ or petalTipMat_
        sm:SetMaterial(pmat --[[@as Material]])
        sm.castShadows = false
    end

    -- 花蕊（五行色小球，五朵可辨的关键）
    local stamen = flower:CreateChild("Stamen")
    stamen.position = Vector3(0, 0.03, 0)
    stamen.scale = Vector3(0.052, 0.042, 0.052)
    local sm2 = stamen:CreateComponent("StaticModel")
    sm2.model = stamenModel_
    sm2:SetMaterial(stamenMat)
    sm2.castShadows = false

    return flower
end

--- 轻量花瓣飘落：花簇顶部微型发射器（≤6 粒、缓慢下落打旋；无贴图时跳过）
---@param cluster Node
---@param key string
local function AttachPetalFall(cluster, key)
    if fallMat_ == nil then return end
    local fx = ParticleEffect()
    fx:SetMaterial(fallMat_)
    fx:SetNumParticles(6)
    fx:SetEmitterType(EMITTER_BOX)
    fx:SetEmitterSize(Vector3(0.42, 0.22, 0.42))
    fx:SetMinDirection(Vector3(-0.25, -1, -0.25))
    fx:SetMaxDirection(Vector3(0.25, -1, 0.25))
    fx:SetConstantForce(Vector3(0.18, -0.75, 0.10))
    fx:SetDampingForce(0.7)
    fx:SetActiveTime(-1)
    fx:SetInactiveTime(-1)
    fx:SetMinEmissionRate(1.2)
    fx:SetMaxEmissionRate(2.2)
    fx:SetMinParticleSize(Vector2(0.07, 0.07))
    fx:SetMaxParticleSize(Vector2(0.13, 0.13))
    fx:SetMinTimeToLive(2.6)
    fx:SetMaxTimeToLive(4.6)
    fx:SetMinVelocity(0.15)
    fx:SetMaxVelocity(0.45)
    fx:SetMinRotation(0)
    fx:SetMaxRotation(360)
    fx:SetMinRotationSpeed(-220)
    fx:SetMaxRotationSpeed(220)
    fx:SetSorted(true)
    fx:AddColorTime(Color(1, 1, 1, 0), 0.0)
    fx:AddColorTime(Color(1, 1, 1, 0.9), 0.15)
    fx:AddColorTime(Color(1, 1, 1, 0.85), 0.75)
    fx:AddColorTime(Color(1, 1, 1, 0), 1.0)

    local node = cluster:CreateChild("FlowerPetalFall_" .. key)
    node.position = Vector3(0, 0.55, 0)
    local emitter = node:CreateComponent("ParticleEmitter")
    emitter:SetEffect(fx)
    emitter.castShadows = false
end

local CLUSTER_SCALE = 1.45   -- 整簇缩放（花冠高出触发球顶，远处一眼可辨）

--- 一簇桃花：短花枝 + 3 朵花 + 1 颗花苞，挂在触发球节点下。
--- 簇底世界落点 = 传入的世界坐标（沿用 DressBlossom 已调好的避让/落点策略：
--- 崖顶火桃花 standY=4.0、石台前水桃花让出台心等），采集随父节点一并移除
---@param bNode Node Blossom_<key> 触发球节点（父级；只平移无旋转缩放）
---@param key string 五行键
---@param baseWorld Vector3 簇底面中心【世界坐标】落点
---@param yaw number 绕 Y 朝向角（度；各朵错开花枝方向）
local function BuildCluster(bNode, key, baseWorld, yaw)
    local cluster = bNode:CreateChild("FlowerCluster_" .. key)
    -- 父节点（触发球节点带 scale=0.6）变换补偿：局部 = (世界 - 父世界位置) / 父缩放
    -- （同 SceneProps.AttachProp 策略；父无旋转）
    local bw = bNode.worldPosition
    local ps = bNode.scale
    cluster.position = Vector3(
        (baseWorld.x - bw.x) / ps.x,
        (baseWorld.y - bw.y) / ps.y,
        (baseWorld.z - bw.z) / ps.z)
    local cs = CLUSTER_SCALE / ps.x
    cluster.scale = Vector3(cs, cs, cs)
    if yaw ~= nil and yaw ~= 0 then
        cluster:SetRotation(Quaternion(yaw, Vector3.UP))
    end

    local stamenMat = GetStamenMaterial(key)

    -- 主花枝（底端接地，顶端微倾）
    local branch = cluster:CreateChild("Branch")
    branch.position = Vector3(0, 0.29, 0)
    branch:SetRotation(Quaternion(5, Vector3.RIGHT) * Quaternion(0, Vector3.UP))
    local bsm = branch:CreateComponent("StaticModel")
    bsm.model = branchModel_
    bsm:SetMaterial(branchMat_ --[[@as Material]])
    bsm.castShadows = true

    -- 枝顶花苞（含苞待放，点缀）
    local bud = cluster:CreateChild("Bud")
    bud.position = Vector3(0.02, 0.60, 0.03)
    bud.scale = Vector3(0.035, 0.042, 0.035)
    local budSm = bud:CreateComponent("StaticModel")
    budSm.model = budModel_
    budSm:SetMaterial(petalMat_ --[[@as Material]])
    budSm.castShadows = false

    -- 3 朵花（高低错落、朝向各异）
    BuildFlower(cluster, "FlowerA", Vector3(0.0, 0.52, 0.02), 0, 1.0, stamenMat)
    BuildFlower(cluster, "FlowerB", Vector3(0.14, 0.40, -0.06), 72, 0.8, stamenMat)
    BuildFlower(cluster, "FlowerC", Vector3(-0.12, 0.32, 0.07), 198, 0.68, stamenMat)

    AttachPetalFall(cluster, key)
end

--- 给一朵 Blossom_<key> 触发球挂程序化粉色桃花簇（替换灰白占位球视觉）。
--- 剥触发球自身 StaticModel（TRIGGER 碰撞/节点名/位置原样保留），不影响已挂
--- 子节点（发光壳等）；采集移除（node:Remove()）时子树随父节点一并消失。
--- 纯本地程序化几何 + 材质，零网络依赖 → 真机必显示（替代 DWP 占位空窗的
--- 真实桃花模型路径，保证"一眼可辨可采"）。
---@param bNode Node|nil Blossom_<key> 触发球节点
---@param baseWorld Vector3 簇底面中心【世界坐标】落点
---@param yaw? number 绕 Y 朝向角（度）
function BlossomFlower.Dress(bNode, baseWorld, yaw)
    if bNode == nil then return end
    local key = string.match(bNode.name, "^Blossom_(%w+)$")
    if key == nil then return end
    if not EnsureShared() then
        -- 程序化失败：保留占位球视觉，玩法不破（与真实模型回退同策略）
        return
    end
    SceneProps.StripVisual(bNode)
    BuildCluster(bNode, key, baseWorld, yaw or 0)
    print("[BlossomFlower] 桃花簇已挂: " .. key)
end

return BlossomFlower
