-- ============================================================================
-- game/WhiteBox.lua
-- 白模构建工具：程序化材质 + 基础几何体（地面/墙体/盒/柱/球/触发器）
--
-- 规范（AGENTS.md 规则 #9.4）：
--   - 程序化材质只用 PBRNoTexture 系列 / NoTextureUnlit；
--   - 世界单位米、Y 轴向上；
--   - 模型尺寸用 boundingBox 动态获取（此处几何体统一用节点 scale，不写死尺寸）。
-- 碰撞层（与 PlayerController 共用）：
--   GROUND=1 静态地形 / PLAYER=2 玩家 / TRIGGER=4 触发器（桃花标记点等）
-- ============================================================================

local WhiteBox = {}

WhiteBox.LAYER_GROUND = 1
WhiteBox.LAYER_PLAYER = 2
WhiteBox.LAYER_TRIGGER = 4

--- 创建程序化材质
---@param rgb table {r,g,b} 0~1
---@param alpha? number 透明度（<1 用透明 technique）
---@param unlit? boolean 无光照（发光/标记用）
---@return Material
function WhiteBox.CreateMaterial(rgb, alpha, unlit)
    local mat = Material:new()
    if unlit then
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    elseif alpha and alpha < 0.999 then
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    else
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    end
    mat:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], alpha or 1)))
    return mat
end

--- 创建基础盒子（可带碰撞）
---@param scene Scene
---@param name string
---@param position Vector3
---@param size Vector3 盒子尺寸（米）
---@param rgb table
---@param opts? table { collision?: boolean, layer?: integer, mask?: integer, trigger?: boolean, alpha?: number, unlit?: boolean }
---@return Node
function WhiteBox.Box(scene, name, position, size, rgb, opts)
    opts = opts or {}
    local node = scene:CreateChild(name)
    node.position = position
    node.scale = size

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(WhiteBox.CreateMaterial(rgb, opts.alpha, opts.unlit))
    model.castShadows = true

    if opts.collision ~= false then
        local body = node:CreateComponent("RigidBody")
        body.collisionLayer = opts.layer or WhiteBox.LAYER_GROUND
        body.collisionMask = opts.mask or 0xFFFF
        body.trigger = opts.trigger or false
        if opts.trigger then
            body.collisionEventMode = COLLISION_ALWAYS
        end
        local shape = node:CreateComponent("CollisionShape")
        shape:SetBox(Vector3.ONE)   -- 尺寸由节点 scale 提供
    end

    return node
end

--- 创建圆柱（井台/树干等）
---@param diameter number
---@param height number
---@param opts? table 同 Box
function WhiteBox.Cylinder(scene, name, position, diameter, height, rgb, opts)
    opts = opts or {}
    local node = scene:CreateChild(name)
    node.position = position
    node.scale = Vector3(diameter, height, diameter)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    model:SetMaterial(WhiteBox.CreateMaterial(rgb, opts.alpha, opts.unlit))
    model.castShadows = true

    if opts.collision ~= false then
        local body = node:CreateComponent("RigidBody")
        body.collisionLayer = opts.layer or WhiteBox.LAYER_GROUND
        body.collisionMask = opts.mask or 0xFFFF
        body.trigger = opts.trigger or false
        if opts.trigger then
            body.collisionEventMode = COLLISION_ALWAYS
        end
        local shape = node:CreateComponent("CollisionShape")
        shape:SetCylinder(1.0, 1.0)
    end

    return node
end

--- 创建球体（树冠/岩石/标记点）
---@param diameter number
---@param opts? table 同 Box
function WhiteBox.Sphere(scene, name, position, diameter, rgb, opts)
    opts = opts or {}
    local node = scene:CreateChild(name)
    node.position = position
    node.scale = Vector3(diameter, diameter, diameter)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    model:SetMaterial(WhiteBox.CreateMaterial(rgb, opts.alpha, opts.unlit))
    model.castShadows = true

    if opts.collision ~= false then
        local body = node:CreateComponent("RigidBody")
        body.collisionLayer = opts.layer or WhiteBox.LAYER_GROUND
        body.collisionMask = opts.mask or 0xFFFF
        body.trigger = opts.trigger or false
        if opts.trigger then
            body.collisionEventMode = COLLISION_ALWAYS
        end
        local shape = node:CreateComponent("CollisionShape")
        shape:SetSphere(1.0)
    end

    return node
end

--- 创建地面（Box 铺平）
---@param sizeX number
---@param sizeZ number
---@param y? number 地面顶面高度（默认 0）
function WhiteBox.Ground(scene, name, sizeX, sizeZ, rgb, y)
    y = y or 0
    -- 地面盒中心在 y-0.5，顶面恰好在 y
    return WhiteBox.Box(scene, name, Vector3(0, y - 0.5, 0), Vector3(sizeX, 1, sizeZ), rgb, {
        layer = WhiteBox.LAYER_GROUND,
        mask = 0xFFFF,
    })
end

--- 创建四周边界墙（防走出白模区域）
--- 真机修复 ②：墙厚 0.5→1.5m 防 ×4 提速 KCC 隧穿；墙体内移使【内侧面】位于
--- half + 0.5（即玩家硬钳制边界外再留 0.5m 余量，胶囊半径 0.35 → 永不贴墙/穿墙）。
---@param scene Scene
---@param halfWidth number 半宽（X 轴，= 玩家硬钳制边界）
---@param halfDepth number 半深（Z 轴，= 玩家硬钳制边界）
---@param height number 墙高
---@param rgb table
---@param thickness number|nil 墙厚（默认 1.5）
function WhiteBox.BoundaryWalls(scene, halfWidth, halfDepth, height, rgb, thickness)
    local wallThickness = thickness or 1.5
    local margin = 0.5                       -- 钳制边界→墙内侧面余量
    local innerX = halfWidth + margin        -- 墙内侧面位置
    local innerZ = halfDepth + margin
    local cx = innerX + wallThickness / 2    -- 墙中心（内侧面之外）
    local cz = innerZ + wallThickness / 2
    local walls = {
        { 0,  cz, innerX * 2 + wallThickness, wallThickness },
        { 0, -cz, innerX * 2 + wallThickness, wallThickness },
        {  cx, 0, wallThickness, innerZ * 2 + wallThickness },
        { -cx, 0, wallThickness, innerZ * 2 + wallThickness },
    }
    for i, w in ipairs(walls) do
        WhiteBox.Box(scene, "Wall" .. i, Vector3(w[1], height / 2, w[2]),
            Vector3(w[3], height, w[4]), rgb, {
                layer = WhiteBox.LAYER_GROUND,
                mask = 0xFFFF,
            })
    end
end

--- 创建一棵桃树（树干圆柱 + 粉色树冠球 ×2）
---@param position Vector3
---@param scale number 整体缩放
function WhiteBox.PeachTree(scene, name, position, scale)
    scale = scale or 1
    WhiteBox.Cylinder(scene, name .. "_Trunk",
        Vector3(position.x, 0.4 * scale + position.y, position.z),
        0.3 * scale, 0.8 * scale, { 0.42, 0.26, 0.16 })
    -- 树冠：一大一小两个球，粉色调
    WhiteBox.Sphere(scene, name .. "_Canopy",
        Vector3(position.x, 1.35 * scale + position.y, position.z),
        1.1 * scale, { 0.95, 0.72, 0.78 })
    WhiteBox.Sphere(scene, name .. "_Canopy2",
        Vector3(position.x + 0.45 * scale, 1.15 * scale + position.y, position.z + 0.3 * scale),
        0.7 * scale, { 0.90, 0.65, 0.72 })
end

--- 创建桃花收集标记点（触发器，碰撞到即收集）
--- 节点名自动编码为 "Blossom_<key>"，碰撞处理器按节点名识别
---@param position Vector3
---@param key string 五行键（wood/fire/earth/metal/water）
---@param rgb table
function WhiteBox.BlossomMarker(scene, position, key, rgb)
    local node = WhiteBox.Sphere(scene, "Blossom_" .. key, position, 0.6, rgb, {
        layer = WhiteBox.LAYER_TRIGGER,
        mask = WhiteBox.LAYER_PLAYER,
        trigger = true,
        unlit = true,
    })
    -- 光柱：醒目标识"这是可采撷的桃花"，解决白模下难分辨的问题
    WhiteBox.Beacon(scene, "Beacon_" .. key, position, rgb)
    return node
end

--- 采集/交互辨识光柱：细长自发光圆柱，白模下让人一眼看出"这里有可采撷/可交互目标"
---@param scene Scene
---@param name string 光柱节点名（与目标 key 关联，便于拾取后一并移除）
---@param position Vector3 目标参考位置（取其 x/z，y 作为光柱底部）
---@param rgb table
---@param height? number 光柱高（默认 1.5）
function WhiteBox.Beacon(scene, name, position, rgb, height)
    local h = height or 1.5
    return WhiteBox.Cylinder(scene, name or "Beacon", Vector3(position.x, position.y + h / 2, position.z),
        0.10, h, rgb, { unlit = true, alpha = 0.85, collision = false })
end

return WhiteBox
