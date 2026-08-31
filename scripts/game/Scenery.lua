-- ============================================================================
-- game/Scenery.lua
-- D2.5 场景遗漏补全：三景共用一条思路的地面/地平线/散点装饰模块
--
--   一、地面真实化：程序化 PlaneGeometry + 本地无缝贴图（周期噪声生成，见
--      _dev/d25_textures/gen_textures.py），SetUVTiling 按米平铺；覆层贴
--      白模地面盒顶上方 3cm，纯视觉不带碰撞（碰撞仍由白模地面盒提供）。
--   二、地平线过渡：边界墙内侧立"远山雾带"立面（透明 PNG：底部不透明山脊
--      轮廓→顶部渐隐），消除"平面硬切水墨 Skybox"；双层错位制造纵深。
--      （postopaque/DiffUnlitAlpha 立面，随场景雾色取同色系）
--   三、前景散点：草叶/落花/碎石撒点透明贴花双层面片 + 氛围道具散点
--      （复用 SceneProps.ASSETS 真实模型，纯视觉不带碰撞，不困住玩家）。
--
--   所有节点挂在调用方传入的容器节点下（随 SceneRoot 整组销毁）。
--   规范：长度米/Y 向上；贴图类 Technique 用 Diff/DiffAlpha/DiffUnlitAlpha；
--   CULL_NONE 避免立面朝向绕序问题。
-- ============================================================================

local SceneProps = require "game.SceneProps"

local Scenery = {}

--- 场景键 → 贴图/配色配置（key 对应 assets/textures/*_<key>.png）
local SCENERY_DEF = {
    chaoyang_gukou = {
        key = "chaoyang",
        -- 远山雾带基色/亮色（同 gen_textures.py FOG.chaoyang）
        bandBase = { 0.74, 0.65, 0.52 },
        scatterTint = Color(1, 1, 1, 1),
    },
    gu_nei_taolin = {
        key = "taolin",
        bandBase = { 0.48, 0.56, 0.48 },
        scatterTint = Color(1, 1, 1, 1),
    },
    luoshui_yinshan = {
        key = "yinshan",
        bandBase = { 0.26, 0.30, 0.38 },
        scatterTint = Color(0.85, 0.9, 1.0, 1),
    },
}

--- 创建平铺贴图材质（texture + technique + 每 tileMeters 米一贴）
---@param texPath string 贴图虚拟路径
---@param technique string Technique 路径
---@param tilingU number 水平重复次数
---@param tilingV number 垂直重复次数
---@param tint Color|nil 乘色
---@param cullNone boolean|nil
---@return Material|nil
local function MakeTiledMaterial(texPath, technique, tilingU, tilingV, tint, cullNone)
    local tex = cache:GetResource("Texture2D", texPath)
    if tex == nil then
        print("[Scenery] 警告：贴图加载失败: " .. texPath)
        return nil
    end
    local tech = cache:GetResource("Technique", technique)
    if tech == nil then
        print("[Scenery] 警告：Technique 不存在，回退 DiffAlpha: " .. technique)
        tech = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
    end
    if tech == nil then return nil end
    tex:SetAddressMode(COORD_U, ADDRESS_WRAP)
    tex:SetAddressMode(COORD_V, ADDRESS_WRAP)
    local mat = Material:new()
    mat:SetTechnique(0, tech)
    mat:SetTexture(TU_DIFFUSE, tex)
    mat:SetUVTiling(Vector2(tilingU, tilingV))
    if tint ~= nil then
        mat:SetShaderParameter("MatDiffColor", Variant(tint))
    end
    if cullNone then
        mat:SetCullMode(CULL_NONE)
    end
    return mat
end

--- 水平面片（PlaneGeometry 默认 XY 朝 +Z，绕 X -90° 铺地，法线朝上）
---@param parent Node
---@param name string
---@param sizeX number
---@param sizeZ number
---@param y number
---@param mat Material
---@param yaw? number 绕 Y 附加旋转（撒点层错开用）
---@return Node
local function AddFloorPlane(parent, name, sizeX, sizeZ, y, mat, yaw)
    local node = parent:CreateChild(name)
    local rot = Quaternion(-90, Vector3.RIGHT)
    if yaw ~= nil and yaw ~= 0 then
        rot = Quaternion(yaw, Vector3.UP) * rot
    end
    node:SetRotation(rot)
    node.position = Vector3(0, y, 0)
    ---@type StaticModel
    local sm = node:CreateComponent("StaticModel")
    sm.model = PlaneGeometry(sizeX, sizeZ):ToModel()
    sm:SetMaterial(mat)
    sm.castShadows = false
    return node
end

--- 垂直立面（雾带）：yaw 决定面向；CULL_NONE 双向可见
---@param parent Node
---@param name string
---@param width number
---@param height number
---@param pos Vector3
---@param yaw number
---@param mat Material
---@return Node
local function AddBillboard(parent, name, width, height, pos, yaw, mat)
    local node = parent:CreateChild(name)
    node:SetRotation(Quaternion(yaw, Vector3.UP))
    node.position = pos
    ---@type StaticModel
    local sm = node:CreateComponent("StaticModel")
    sm.model = PlaneGeometry(width, height):ToModel()
    sm:SetMaterial(mat)
    sm.castShadows = false
    return node
end

--- 一、地面真实化覆层（纹理草地/泥地/碎石，1 tile = 6m）
---@param parent Node 场景容器
---@param def table SCENERY_DEF 项
---@param sizeX number 地面宽（= 2*halfWidth，铺到边界墙）
---@param sizeZ number 地面深（= 2*halfDepth）
local function BuildGroundOverlay(parent, def, sizeX, sizeZ)
    -- DiffUnlit：水墨风地面不需要光照渐变（避免 PlaneGeometry 法线朝向导致的明暗问题），
    -- 场景雾仍会作用于它，与远景自然过渡；CULL_NONE 双保险防背面剔除
    local mat = MakeTiledMaterial("textures/ground_" .. def.key .. ".png",
        "Techniques/DiffUnlit.xml", sizeX / 6, sizeZ / 6, Color(1, 1, 1, 1), true)
    if mat == nil then return false end
    AddFloorPlane(parent, "Scenery_Ground", sizeX, sizeZ, 0.03, mat, 0)
    print("[Scenery] 地面覆层已铺设: " .. def.key .. " " .. sizeX .. "x" .. sizeZ)
    return true
end

--- 三a、撒点贴花（草叶/落花/碎石，双层错位；1 tile = 4m）
---@param parent Node
---@param def table
---@param sizeX number
---@param sizeZ number
local function BuildScatter(parent, def, sizeX, sizeZ)
    local path = "textures/scatter_" .. def.key .. ".png"
    local m1 = MakeTiledMaterial(path, "Techniques/DiffAlpha.xml",
        sizeX / 4, sizeZ / 4, def.scatterTint, true)
    local m2 = MakeTiledMaterial(path, "Techniques/DiffAlpha.xml",
        sizeX / 5.2, sizeZ / 5.2, def.scatterTint, true)
    if m1 == nil or m2 == nil then return end
    m2:SetUVOffset(Vector2(0.37, 0.61))
    AddFloorPlane(parent, "Scenery_Scatter1", sizeX, sizeZ, 0.06, m1, 0)
    AddFloorPlane(parent, "Scenery_Scatter2", sizeX, sizeZ, 0.09, m2, 47)
    print("[Scenery] 撒点贴花已铺设: " .. def.key)
end

--- 二、地平线过渡：边界墙改远山剪影 + 墙内纵深雾带
---   近相机的墙段顶缘总比任何"墙外矮带"高 → 外侧带藏不住墙。正解：墙本身就是
---   远景剪影——剥掉白模墙视觉（碰撞保留），墙面贴雾带贴图：山脊以下不透明、
---   以上透明露出水墨 Skybox，硬切消除且不形成走廊内壁。
---@param parent Node
---@param def table
---@param halfW number 边界半宽
---@param halfD number 边界半深
local function BuildHorizonBands(parent, def, halfW, halfD)
    local base = Color(def.bandBase[1], def.bandBase[2], def.bandBase[3], 1)
    local bandTexPath = "textures/fogband_" .. def.key .. ".png"

    -- 2a、四面墙改远山：WhiteBox.BoundaryWalls 命名 Wall1(+Z) Wall2(-Z) Wall3(+X) Wall4(-X)
    local wallH = 3.0
    local walls = {
        { name = "Wall1", len = halfW * 2 + 0.6, pos = Vector3(0, wallH / 2, halfD - 0.28),  yaw = 180 },
        { name = "Wall2", len = halfW * 2 + 0.6, pos = Vector3(0, wallH / 2, -halfD + 0.28), yaw = 0 },
        { name = "Wall3", len = halfD * 2 + 0.6, pos = Vector3(halfW - 0.28, wallH / 2, 0),  yaw = 270 },
        { name = "Wall4", len = halfD * 2 + 0.6, pos = Vector3(-halfW + 0.28, wallH / 2, 0), yaw = 90 },
    }
    for wi, w in ipairs(walls) do
        ---@type Node|nil
        local wallNode = parent:GetChild(w.name, true)
        if wallNode ~= nil then
            SceneProps.StripVisual(wallNode)  -- 碰撞保留，视觉换远山
        end
        local mat = MakeTiledMaterial(bandTexPath, "Techniques/DiffUnlitAlpha.xml",
            w.len / 24, 1.0, base, true)
        if mat ~= nil then
            AddBillboard(parent, "Scenery_WallBand" .. wi, w.len, wallH, w.pos, w.yaw, mat)
        end
    end

    -- 2b、墙内纵深剪影带（矮一档内收，制造远近层次）
    local inset, h = 2.6, 4.2
    local hw = halfW - inset
    local hd = halfD - inset
    local sides = {
        { w = halfW * 2 + 6, pos = Vector3(0, h / 2 - 0.3, hd),   yaw = 180 },
        { w = halfW * 2 + 6, pos = Vector3(0, h / 2 - 0.3, -hd),  yaw = 0 },
        { w = halfD * 2 + 6, pos = Vector3(hw, h / 2 - 0.3, 0),   yaw = 270 },
        { w = halfD * 2 + 6, pos = Vector3(-hw, h / 2 - 0.3, 0),  yaw = 90 },
    }
    for si, s in ipairs(sides) do
        local mat = MakeTiledMaterial(bandTexPath, "Techniques/DiffUnlitAlpha.xml",
            s.w / 30, 1.0, base, true)
        if mat ~= nil then
            AddBillboard(parent, "Scenery_Band2_" .. si, s.w, h, s.pos, s.yaw, mat)
        end
    end
    print("[Scenery] 地平线雾带已铺设: " .. def.key)
end

--- 三b、氛围道具散点（真实模型纯视觉；坐标手工避让交互点/触发点/主路）
---@param parent Node
---@param spots table[] { asset, x, z, s, yaw }
local function BuildAmbientProps(parent, spots)
    local n = 0
    for i, s in ipairs(spots) do
        local vis = SceneProps.AttachProp(parent, "Scenery_Prop" .. i, s.asset,
            Vector3(s.x, 0, s.z), s.s, s.yaw)
        if vis ~= nil then
            vis.castShadows = true
            n = n + 1
        end
    end
    print("[Scenery] 氛围道具散点: " .. n .. "/" .. #spots)
end

--- 构建整组场景装饰（由 SceneManager 在场景构建末尾调用）
---@param parent Node SceneRoot 容器
---@param sceneName string 场景键
---@param dims table { halfW, halfD } 边界半宽/半深（地面铺满用）
---@param ambient table[]|nil 氛围道具散点表
---@return boolean 是否至少铺上地面
function Scenery.Build(parent, sceneName, dims, ambient)
    local def = SCENERY_DEF[sceneName]
    if def == nil then
        print("[Scenery] 场景未配置装饰: " .. tostring(sceneName))
        return false
    end
    local sizeX = dims.halfW * 2
    local sizeZ = dims.halfD * 2
    local ok = BuildGroundOverlay(parent, def, sizeX, sizeZ)
    BuildScatter(parent, def, sizeX, sizeZ)
    BuildHorizonBands(parent, def, dims.halfW, dims.halfD)
    if ambient ~= nil then
        BuildAmbientProps(parent, ambient)
    end
    return ok
end

return Scenery
