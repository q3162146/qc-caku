-- ============================================================================
-- game/SceneProps.lua
-- D2 场景道具：真实模型（create_3d_asset/Tripo 生成）挂载工具
--
--   设计约定（与 C 阶段 NPC 模型接入同款，失败回退保玩法）：
--     - 资产为虚拟路径加载：model/<asset_id>/Meshes/<asset_id>.mdl（assets/ 为资源根）
--     - 包围盒全部"中心居中"（model-info 实测 Min Y ≈ -sizeY/2）：
--       AttachProp 以【底面中心贴地】定位，node.y = groundY - minY * scaleY
--     - 视觉节点不带碰撞；原白模的 RigidBody+CollisionShape 由调用方保留
--     - StripVisual：移除白模节点的 StaticModel 只留碰撞，视觉交给真实模型
-- ============================================================================

local SceneProps = {}

---@class PropAssetDef
---@field model string 虚拟路径 .mdl
---@field mat string 虚拟路径材质 .xml
---@field size table { x, y, z } 包围盒尺寸（米，model-info 实测）
---@field minY number 包围盒 Min Y（中心居中 → 约 -sizeY/2）

--- 资产登记表（asset_id 对应 create_3d_asset 交付目录）
---@type table<string, PropAssetDef>
SceneProps.ASSETS = {
    -- 国风桃树（粉白桃花满枝）—— 无涕桃 / TaoA/B/C
    peach_tree = {
        model = "model/84cda7a28c08423dbec47ee97a685e58/Meshes/84cda7a28c08423dbec47ee97a685e58.mdl",
        mat = "model/84cda7a28c08423dbec47ee97a685e58/Materials/84cda7a28c08423dbec47ee97a685e58_00_tripo_material_c00a4e3d-83b1-4e9f-a347-2f91ad34bd7b.xml",
        size = { x = 0.748, y = 0.881, z = 0.998 }, minY = -0.440,
    },
    -- 粉色桃花花枝丛 —— 五行桃花采集点视觉
    blossom = {
        model = "model/c881f0de4ed64247a9e91bd5900bcac6/Meshes/c881f0de4ed64247a9e91bd5900bcac6.mdl",
        mat = "model/c881f0de4ed64247a9e91bd5900bcac6/Materials/c881f0de4ed64247a9e91bd5900bcac6_00_tripo_material_0d21ada7-f860-465d-92cb-ad6d1f56976f.xml",
        size = { x = 0.557, y = 0.971, z = 0.998 }, minY = -0.485,
    },
    -- 风格化灰色岩石 —— 洛水阴山碎石 / 无面鬼石台（非等比压扁复用）
    rock = {
        model = "model/6b69ee99a1ff4efda91db3de3d503485/Meshes/6b69ee99a1ff4efda91db3de3d503485.mdl",
        mat = "model/6b69ee99a1ff4efda91db3de3d503485/Materials/6b69ee99a1ff4efda91db3de3d503485_00_tripo_material_c1957caa-29c0-4368-8ef3-76d634dbcbae.xml",
        size = { x = 0.908, y = 0.998, z = 0.854 }, minY = -0.499,
    },
    -- 古风石制灯柱（暖黄灯笼）—— 老人旁矮灯 / 矿灯×3
    lamp_post = {
        model = "model/770f22b96e9c46dd854d9f814a61ca00/Meshes/770f22b96e9c46dd854d9f814a61ca00.mdl",
        mat = "model/770f22b96e9c46dd854d9f814a61ca00/Materials/770f22b96e9c46dd854d9f814a61ca00_00_tripo_material_e959b8da-be96-4019-9714-3733ab6a65ba.xml",
        size = { x = 0.346, y = 0.998, z = 0.350 }, minY = -0.499,
    },
    -- 青灰扁平石板 —— 无涕桃环石×8
    stone_slab = {
        model = "model/a9f447684de04c1db6c3872162414b39/Meshes/a9f447684de04c1db6c3872162414b39.mdl",
        mat = "model/a9f447684de04c1db6c3872162414b39/Materials/a9f447684de04c1db6c3872162414b39_00_tripo_material_730fe7a7-01d0-4814-a980-8a32ea412445.xml",
        size = { x = 0.998, y = 0.131, z = 0.998 }, minY = -0.065,
    },
    -- 石制观景台/望夫石祭台 —— WatchPlatform(5,·,10)
    watch_altar = {
        model = "model/0625824a2cc3471f924a6f96e56bc715/Meshes/0625824a2cc3471f924a6f96e56bc715.mdl",
        mat = "model/0625824a2cc3471f924a6f96e56bc715/Materials/0625824a2cc3471f924a6f96e56bc715_00_tripo_material_4da04a96-a9c7-4a76-93ae-fd572145f729.xml",
        size = { x = 0.912, y = 0.939, z = 0.998 }, minY = -0.470,
    },
    -- 破旧老屋（泥墙茅草顶）—— 守桃老人屋
    old_house = {
        model = "model/bf34f67d9c3a44d6b9beb9b12a02d8ad/Meshes/bf34f67d9c3a44d6b9beb9b12a02d8ad.mdl",
        mat = "model/bf34f67d9c3a44d6b9beb9b12a02d8ad/Materials/bf34f67d9c3a44d6b9beb9b12a02d8ad_00_tripo_material_fa107f52-a5cb-41c3-b9b8-2ac84f8311cb.xml",
        size = { x = 0.998, y = 0.783, z = 0.998 }, minY = -0.392,
    },
    -- 古风石井（井栏+木架辘轳）—— 谷内井
    well = {
        model = "model/1c8ac533923741678064ca2402a08b5d/Meshes/1c8ac533923741678064ca2402a08b5d.mdl",
        mat = "model/1c8ac533923741678064ca2402a08b5d/Materials/1c8ac533923741678064ca2402a08b5d_00_tripo_material_edbe1c33-6864-4e52-baeb-2654de9b0086.xml",
        size = { x = 0.834, y = 0.998, z = 0.893 }, minY = -0.499,
    },
    -- 陡峭崖壁（顶有平台）—— 望夫崖
    cliff = {
        model = "model/7b992c424cc04b579bc80b18d72b6ab1/Meshes/7b992c424cc04b579bc80b18d72b6ab1.mdl",
        mat = "model/7b992c424cc04b579bc80b18d72b6ab1/Materials/7b992c424cc04b579bc80b18d72b6ab1_00_tripo_material_d02ab1fe-4c08-4ecb-bec9-00f873517af0.xml",
        size = { x = 0.869, y = 0.893, z = 0.998 }, minY = -0.446,
    },
    -- 阴山镇暗色民居（石墙木屋斜瓦顶）—— TownHouse×5/TownShed
    town_house = {
        model = "model/8149d8f352c44a5f853bd2cf33f74d9c/Meshes/8149d8f352c44a5f853bd2cf33f74d9c.mdl",
        mat = "model/8149d8f352c44a5f853bd2cf33f74d9c/Materials/8149d8f352c44a5f853bd2cf33f74d9c_00_tripo_material_3ac6ad8a-0d21-4e23-b6c5-64a5eaca59c2.xml",
        size = { x = 0.693, y = 0.916, z = 0.998 }, minY = -0.458,
    },
    -- 山泉古井（深色石栏+清泉）—— 洛水阴山泉井
    spring_well = {
        model = "model/099150bbd8284dd89e4ba95b9d8bd16c/Meshes/099150bbd8284dd89e4ba95b9d8bd16c.mdl",
        mat = "model/099150bbd8284dd89e4ba95b9d8bd16c/Materials/099150bbd8284dd89e4ba95b9d8bd16c_00_tripo_material_8236b6fa-d434-4815-8dfe-713a510d90e7.xml",
        size = { x = 0.963, y = 0.916, z = 0.998 }, minY = -0.458,
    },
}

--- 在 parent 下挂一个真实模型视觉节点（底面中心贴地；不带碰撞）
--- 支持父节点非单位缩放/非原点位置（如挂在 Blossom 触发球下随采集一并移除），
--- 内部按父节点 worldPosition/scale 换算局部坐标，视觉落点始终为世界坐标
---@param parent Node 父节点（场景根 / 触发球节点等）
---@param name string 视觉节点名（如 "WutiTao_Visual"）
---@param assetKey string SceneProps.ASSETS 键
---@param groundPos Vector3 【世界坐标】底面中心位置（贴地点）
---@param scale number|table 目标【世界】缩放：等比 number，或非等比 { x, y, z }
---@param yaw? number 绕 Y 朝向角（度）
---@return Node|nil 视觉节点（模型加载失败返回 nil，调用方保留原白模视觉）
function SceneProps.AttachProp(parent, name, assetKey, groundPos, scale, yaw)
    local def = SceneProps.ASSETS[assetKey]
    if def == nil then
        print("[SceneProps] 未知资产键: " .. tostring(assetKey))
        return nil
    end

    local mdl = cache:GetResource("Model", def.model)
    if mdl == nil then
        print("[SceneProps] 警告：模型加载失败，保留白模视觉: " .. def.model)
        return nil
    end

    local sx, sy, sz
    if type(scale) == "table" then
        sx, sy, sz = scale.x or 1, scale.y or 1, scale.z or 1
    else
        sx, sy, sz = scale, scale, scale
    end

    -- 父节点变换补偿：局部 = (世界 - 父世界位置) / 父缩放（父无旋转场景成立）
    local pw = parent.worldPosition
    local ps = parent.scale

    local node = parent:CreateChild(name)
    node.scale = Vector3(sx / ps.x, sy / ps.y, sz / ps.z)
    -- 中心居中模型：底面贴地 → 中心世界 y = groundY - minY*scaleY（minY 为负）
    local worldY = groundPos.y - def.minY * sy
    node.position = Vector3(
        (groundPos.x - pw.x) / ps.x,
        (worldY - pw.y) / ps.y,
        (groundPos.z - pw.z) / ps.z)
    if yaw ~= nil and yaw ~= 0 then
        node:SetRotation(Quaternion(yaw, Vector3.UP))
    end

    local sm = node:CreateComponent("StaticModel")
    sm:SetModel(mdl)
    local mat = cache:GetResource("Material", def.mat)
    if mat ~= nil then
        sm:SetMaterial(mat)
    end
    sm.castShadows = true
    return node
end

--- 移除白模节点的视觉（StaticModel），保留 RigidBody/CollisionShape 碰撞
---@param node Node|nil
function SceneProps.StripVisual(node)
    if node == nil then return end
    ---@type StaticModel|nil
    local sm = node:GetComponent("StaticModel")
    if sm ~= nil then
        node:RemoveComponent(sm)
    end
end

return SceneProps
