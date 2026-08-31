-- ============================================================================
-- game/SceneManager.lua
-- 场景管理器：三段白模场景的构建与切换
--
--   朝阳谷口   chaoyang_gukou   明亮/桃花漫山：出生点、素女守望处、无涕桃、5 朵五行桃花
--   谷内桃林   gu_nei_taolin    清幽：守桃老人屋、井、桃树群、望夫崖
--   洛水阴山   luoshui_yinshan  异域/雾霭：小镇、无面鬼处、矿场小路
--
-- 场景切换 = 移除旧场景容器节点 → 重建 → 玩家回到出生点。
-- 所有白模内容挂在 scene 下的容器节点 "SceneRoot" 中，便于整组销毁。
-- ============================================================================

local WhiteBox = require "game.WhiteBox"

local SceneManager = {}

-- C 阶段 NPC 3D 模型（create_3d_asset 生成；虚拟路径加载，加载失败回退原白模保玩法）
--   守桃老人：rig 服务侧 not riggable → 回退静态 texture 版 MDL（NPC 本静止，静态可接受）
--   无面鬼：rig 成功但 NPC 不播动画，用 rig 版 MDL（脚底在包围盒 Min Y=0，落地方便）
-- 模型包围盒（model-info 实测）：
--   老人 texture-2：Size ≈ (0.37, 1.0, 0.44)，中心居中（Min Y ≈ -0.5）
--   无面鬼 rig-1：Size ≈ (1.0, 0.89, 0.79)，Min Y = 0
local OLDMAN_MODEL = "model/0cc0e7462fb948eca0f19b89bc280e0f/Meshes/texture-2-5c110f9c-c50a-47d4-a55a-ddf40487ee0f.mdl"
local OLDMAN_MATERIAL = "model/0cc0e7462fb948eca0f19b89bc280e0f/Materials/texture-2-5c110f9c-c50a-47d4-a55a-ddf40487ee0f_00_tripo_node_906c0bfe-1b6c-449a-a961-ef3c15017f83_material.xml"
local NOFACE_MODEL = "model/a95df9a8c56e4bc6a37831cb6f8c5892/Meshes/rig-1-b23c4dcd-4f9f-4bf6-8667-53e85d62cf22.mdl"
local NOFACE_MATERIAL = "model/a95df9a8c56e4bc6a37831cb6f8c5892/Materials/rig-1-b23c4dcd-4f9f-4bf6-8667-53e85d62cf22_00_tripo_material_93788dd0-9aa3-4813-aae8-8d7b2107ab93.xml"
local OLDMAN_HEIGHT = 1.9  -- 目标身高（米；原白模柱 1.5+头球顶 2.15，取 1.9 贴"1.8-2m"）
local NOFACE_SCALE = 1.25  -- 蜷坐目标高 ≈1.12m（base 0.893 × 1.25），坐石台上不显小

--- 在 parent 下挂 NPC 模型（虚拟路径 Model+Material；失败返回 nil，调用方回退白模）
---@param parent Node
---@param modelPath string
---@param matPath string
---@param scale number 整体等比缩放
---@param yOffset number 子节点 Y 偏移（使脚底落在 parent 原点）
---@param yaw number 绕 Y 朝向角（度；视觉正面 +X，+90° 转 +Z，同 B 阶段素女实测）
---@return Node|nil
local function AttachNpcModel(parent, modelPath, matPath, scale, yOffset, yaw)
    local mdl = cache:GetResource("Model", modelPath)
    if mdl == nil then
        print("[SceneManager] 警告：NPC 模型加载失败，回退白模: " .. modelPath)
        return nil
    end
    local node = parent:CreateChild("NpcModelNode")
    local sm = node:CreateComponent("StaticModel")
    sm:SetModel(mdl)
    local mat = cache:GetResource("Material", matPath)
    if mat ~= nil then
        sm:SetMaterial(mat)
    end
    sm.castShadows = true
    node.scale = Vector3(scale, scale, scale)
    node.position = Vector3(0, yOffset, 0)
    node:SetRotation(Quaternion(yaw, Vector3.UP))
    print("[SceneManager] NPC 模型已加载: " .. modelPath)
    return node
end

---@type Scene|nil
local scene_ = nil
---@type table|nil
local player_ = nil      -- PlayerController 实例（提供 SetPosition）
---@type Node|nil
local sceneRoot_ = nil
---@type string
local currentScene_ = ""
---@type function|nil
local onSceneLoaded_ = nil

--- 场景氛围配置（雾色/环境光/主光，随场景切换）
local SCENE_MOOD = {
    chaoyang_gukou = {
        name = "朝阳谷口",
        ambient = Color(0.42, 0.40, 0.42),
        fog = Color(0.92, 0.85, 0.78),
        fogStart = 30.0,
        fogEnd = 120.0,
        fogDensity = 1.0,
        lightColor = Color(0.95, 0.90, 0.82),
        lightBrightness = 1.05,
    },
    gu_nei_taolin = {
        name = "谷内桃林",
        ambient = Color(0.36, 0.38, 0.36),
        fog = Color(0.80, 0.82, 0.74),
        fogStart = 25.0,
        fogEnd = 90.0,
        fogDensity = 1.0,
        lightColor = Color(0.82, 0.88, 0.78),
        lightBrightness = 0.92,
    },
    luoshui_yinshan = {
        name = "洛水阴山",
        ambient = Color(0.22, 0.24, 0.32),
        fog = Color(0.36, 0.40, 0.50),
        -- 第三人称相机约 6.8m，fogStart 须大于相机距离，否则整屏被雾吃掉
        fogStart = 18.0,
        fogEnd = 70.0,
        fogDensity = 1.2,
        heightFog = false,
        lightColor = Color(0.62, 0.68, 0.84),
        lightBrightness = 0.62,
    },
}

--- 初始化
---@param scene Scene
---@param player table PlayerController 实例
function SceneManager.Init(scene, player)
    scene_ = scene
    player_ = player
end

--- 注册"场景加载完成"回调（用于显示场景名横幅等）
---@param cb function|nil function(name: string)
function SceneManager.SetOnSceneLoaded(cb)
    onSceneLoaded_ = cb
end

---@return string
function SceneManager.GetCurrentScene()
    return currentScene_
end

--- 加载指定场景（销毁旧场景内容并重建）
---@param sceneName string 场景键（见 SCENE_MOOD）
---@return boolean 是否成功
function SceneManager.LoadScene(sceneName)
    if scene_ == nil then
        print("[SceneManager] 未初始化")
        return false
    end
    if not SCENE_MOOD[sceneName] then
        print("[SceneManager] 未知场景: " .. tostring(sceneName))
        return false
    end

    -- 销毁旧场景容器
    if sceneRoot_ ~= nil then
        sceneRoot_:Remove()
        sceneRoot_ = nil
    end
    sceneRoot_ = scene_:CreateChild("SceneRoot")
    currentScene_ = sceneName

    -- 应用氛围
    ApplyMood(SCENE_MOOD[sceneName])

    -- 场景名回传（用于顶部横幅等）
    if onSceneLoaded_ ~= nil then
        onSceneLoaded_(SCENE_MOOD[sceneName].name or sceneName)
    end

    -- 构建白模
    local spawn = nil
    if sceneName == "chaoyang_gukou" then
        spawn = BuildChaoyangGukou(sceneRoot_)
    elseif sceneName == "gu_nei_taolin" then
        spawn = BuildGuNeiTaoLin(sceneRoot_)
    elseif sceneName == "luoshui_yinshan" then
        spawn = BuildLuoShuiYinShan(sceneRoot_)
    end

    -- 玩家回到出生点（PlayerController.SetPosition 为 dot 风格 API，勿用冒号调用）
    if player_ ~= nil and spawn ~= nil then
        player_.SetPosition(spawn)
        print("[SceneManager] 玩家出生点: " .. tostring(spawn.x) .. ", " .. tostring(spawn.y) .. ", " .. tostring(spawn.z))
    end

    print("[SceneManager] 场景已加载: " .. sceneName)
    return true
end

--- 当前场景名
---@return string
function SceneManager.GetCurrentScene()
    return currentScene_
end

--- 应用场景氛围（雾 + 环境光 + 主光）
---@param mood table
function ApplyMood(mood)
    local zoneNode = scene_:GetChild("Zone", true)
    if zoneNode == nil then
        zoneNode = scene_:CreateChild("Zone")
    end
    local zone = zoneNode:GetOrCreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = mood.ambient
    zone.fogColor = mood.fog
    zone.fogStart = mood.fogStart
    zone.fogEnd = mood.fogEnd
    zone.fogDensity = mood.fogDensity or 1.0
    if mood.heightFog then
        zone.heightFog = true
        zone.fogHeight = mood.fogHeight or 3.0
        zone.fogHeightScale = mood.fogHeightScale or 0.3
    else
        zone.heightFog = false
    end

    local lightNode = scene_:GetChild("DirectionalLight", true)
    if lightNode ~= nil then
        ---@type Light|nil
        local light = lightNode:GetComponent("Light")
        if light ~= nil then
            if mood.lightColor ~= nil then
                light.color = mood.lightColor
            end
            if mood.lightBrightness ~= nil then
                light.brightness = mood.lightBrightness
            end
        end
    end
end

--- ============================================================================
--- 场景 1：朝阳谷口（明亮，桃花漫山）
--- ============================================================================
function BuildChaoyangGukou(root)
    local scene_ = root
    -- 地面：暖色土黄
    WhiteBox.Ground(scene_, "Ground", 18, 52, { 0.82, 0.68, 0.52 })

    -- 无涕桃（中央，略大）
    WhiteBox.PeachTree(scene_, "WutiTao", Vector3(0, 0, 0), 1.6)
    -- 终局点缀：无涕桃周围一圈矮石板 + 粉/白光柱（不改树本身，ch0/ch1 采集不受影响）
    local ring = {
        { Vector3(2.4, 0.12, 0.0),  { 0.96, 0.82, 0.86 } },
        { Vector3(-2.4, 0.12, 0.0), { 0.96, 0.88, 0.90 } },
        { Vector3(0.0, 0.12, 2.4),  { 0.94, 0.78, 0.84 } },
        { Vector3(0.0, 0.12, -2.4), { 0.96, 0.88, 0.90 } },
        { Vector3(1.7, 0.12, 1.7),  { 0.95, 0.80, 0.86 } },
        { Vector3(-1.7, 0.12, 1.7), { 0.96, 0.86, 0.90 } },
        { Vector3(1.7, 0.12, -1.7), { 0.94, 0.78, 0.84 } },
        { Vector3(-1.7, 0.12, -1.7),{ 0.96, 0.88, 0.90 } },
    }
    for i, item in ipairs(ring) do
        local pos, rgb = item[1], item[2]
        WhiteBox.Box(scene_, "WutiTaoRing" .. i, pos, Vector3(0.55, 0.24, 0.55), { 0.72, 0.62, 0.52 })
        WhiteBox.Beacon(scene_, "Beacon_WutiTao_" .. i, Vector3(pos.x, 0.4, pos.z), rgb, 1.1)
    end
    -- 无涕桃柔和点光（局部点缀，不改主光基调）
    local taoLightNode = scene_:CreateChild("WutiTaoGlow")
    taoLightNode.position = Vector3(0, 2.2, 0)
    local taoLight = taoLightNode:CreateComponent("Light")
    taoLight.lightType = LIGHT_POINT
    taoLight.color = Color(1.0, 0.78, 0.86)
    taoLight.brightness = 0.55
    taoLight.range = 6.0
    taoLight.castShadows = false

    -- 素女守望处（小台 + 素色标记）
    WhiteBox.Box(scene_, "WatchPlatform", Vector3(5, 0.25, 10), Vector3(3, 0.5, 3), { 0.78, 0.80, 0.82 })
    WhiteBox.Sphere(scene_, "WatchMarker", Vector3(5, 1.2, 10), 0.4, { 0.95, 0.93, 0.88 }, { unlit = true })

    -- 五朵五行桃花（谷口/桃树下/望夫崖/井边/守桃老人屋 的白模占位）
    local blossomSpots = {
        { key = "wood",   pos = Vector3(-6, 0.6, 14),   rgb = { 0.36, 0.72, 0.38 } },  -- 木（东）
        { key = "fire",   pos = Vector3(4.5, 0.6, -6),  rgb = { 0.90, 0.35, 0.30 } },  -- 火（南，主路东侧，避开老人交互点）
        { key = "earth",  pos = Vector3(0, 0.6, -20),   rgb = { 0.78, 0.62, 0.36 } },  -- 土（中）
        { key = "metal",  pos = Vector3(-6, 0.6, -14),  rgb = { 0.82, 0.82, 0.86 } },  -- 金（西）
        { key = "water",  pos = Vector3(4, 0.6, 20),    rgb = { 0.34, 0.55, 0.85 } },  -- 水（北）
    }
    for _, spot in ipairs(blossomSpots) do
        WhiteBox.BlossomMarker(scene_, spot.pos, spot.key, spot.rgb)
    end

    -- 守桃老人（S2 对话 NPC：C 阶段换 3D 模型，古风拄杖老者；加载失败回退原白模柱+头球）
    local oldManPos = Vector3(3, 0, -16)
    local oldManNode = scene_:CreateChild("OldMan")
    oldManNode.position = oldManPos
    -- 模型中心居中（Min Y ≈ -0.5）→ 子节点上移半身高使脚底落地；
    -- 视觉正面实测 +90° 朝 -Z（C 阶段截图），故 -90° 使正面朝 +Z（Int_oldman/玩家来向）
    local oldManModel = AttachNpcModel(oldManNode, OLDMAN_MODEL, OLDMAN_MATERIAL,
        OLDMAN_HEIGHT, OLDMAN_HEIGHT / 2, -90)
    if oldManModel == nil then
        WhiteBox.Cylinder(oldManNode, "OldManBody", Vector3(0, 0.75, 0), 0.7, 1.5,
            { 0.46, 0.38, 0.32 })
        WhiteBox.Sphere(oldManNode, "OldManHead", Vector3(0, 1.75, 0), 0.4,
            { 0.90, 0.82, 0.74 })
    else
        -- 模型无碰撞：补圆柱 GROUND 碰撞体（与原白模柱等效，防穿身）
        local body = oldManNode:CreateComponent("RigidBody")
        body.collisionLayer = WhiteBox.LAYER_GROUND
        body.collisionMask = 0xFFFF
        local shape = oldManNode:CreateComponent("CollisionShape")
        shape:SetCylinder(0.7, OLDMAN_HEIGHT, Vector3(0, OLDMAN_HEIGHT / 2, 0))
    end
    -- 交互点（走近触发对话：P02 完成条件，节点名 Int_oldman）
    WhiteBox.Sphere(scene_, "Int_oldman", Vector3(oldManPos.x, 0.5, oldManPos.z + 1.8), 0.5,
        { 0.55, 0.85, 0.45 }, { unlit = true, trigger = true,
            layer = WhiteBox.LAYER_TRIGGER, mask = WhiteBox.LAYER_PLAYER })
    -- 守桃老人辨识光柱（白模下让人一眼看出"走近这位老人交互"）
    WhiteBox.Beacon(scene_, "Beacon_oldman", Vector3(oldManPos.x, 0.6, oldManPos.z), { 0.95, 0.82, 0.45 }, 2.4)
    -- 献花前氛围：老人旁暖色矮灯（不改 Int_oldman / Beacon_oldman）
    WhiteBox.Cylinder(scene_, "OldManLampPost",
        Vector3(oldManPos.x + 1.4, 0.7, oldManPos.z - 0.6), 0.16, 1.4, { 0.42, 0.32, 0.24 })
    WhiteBox.Sphere(scene_, "OldManLamp",
        Vector3(oldManPos.x + 1.4, 1.55, oldManPos.z - 0.6), 0.28, { 1.0, 0.82, 0.48 }, { unlit = true })
    WhiteBox.Beacon(scene_, "Beacon_oldman_lamp",
        Vector3(oldManPos.x + 1.4, 0.4, oldManPos.z - 0.6), { 1.0, 0.78, 0.42 }, 1.2)
    local lampLightNode = scene_:CreateChild("OldManWarmLight")
    lampLightNode.position = Vector3(oldManPos.x + 1.4, 1.6, oldManPos.z - 0.6)
    local lampLight = lampLightNode:CreateComponent("Light")
    lampLight.lightType = LIGHT_POINT
    lampLight.color = Color(1.0, 0.72, 0.38)
    lampLight.brightness = 0.7
    lampLight.range = 4.5
    lampLight.castShadows = false

    -- 边界墙
    -- 边界墙（R12 根因修复：后墙外移 25.5→32，给第三人称相机留 space；distance 6.8 不被墙碰撞压回）
    WhiteBox.BoundaryWalls(scene_, 8.5, 32.0, 3.0, { 0.55, 0.42, 0.32 })

    -- 出生点
    return Vector3(0, 0.1, 22)
end

--- ============================================================================
--- 场景 2：谷内桃林（清幽）
--- ============================================================================
function BuildGuNeiTaoLin(root)
    local scene_ = root
    -- 地面：偏绿土色
    WhiteBox.Ground(scene_, "Ground", 16, 46, { 0.62, 0.62, 0.48 })

    -- 守桃老人屋（盒屋 + 斜顶）
    WhiteBox.Box(scene_, "OldManHouse", Vector3(-4, 1.2, -14), Vector3(5, 2.4, 4.5), { 0.66, 0.52, 0.38 })
    WhiteBox.Box(scene_, "OldManHouseRoof", Vector3(-4, 2.9, -14), Vector3(6, 0.4, 5.5), { 0.52, 0.36, 0.28 })

    -- 井（圆台 + 小盒井架）
    WhiteBox.Cylinder(scene_, "Well", Vector3(-2, 0.4, 10), 1.6, 0.8, { 0.60, 0.58, 0.54 })
    WhiteBox.Box(scene_, "WellFrame", Vector3(-2, 1.2, 10), Vector3(1.8, 0.3, 1.8), { 0.55, 0.50, 0.45 })

    -- 桃树群（R12 近景靠边：TaoA 原 (4,0,16) 距出生点仅 3m，树冠易压右中下画幅 → 右移外扩）
    WhiteBox.PeachTree(scene_, "TaoA", Vector3(7, 0, 15), 1.2)
    WhiteBox.PeachTree(scene_, "TaoB", Vector3(6, 0, 4), 1.0)
    WhiteBox.PeachTree(scene_, "TaoC", Vector3(-3, 0, -19), 1.1)

    -- 望夫崖（斜坡 + 崖顶平台）
    WhiteBox.Box(scene_, "CliffRamp", Vector3(4, 1.25, -15), Vector3(5, 2.5, 5), { 0.48, 0.42, 0.36 })
    WhiteBox.Box(scene_, "CliffTop", Vector3(6, 3.5, -15), Vector3(4, 1, 5), { 0.46, 0.40, 0.34 })
    WhiteBox.Sphere(scene_, "CliffMarker", Vector3(6, 4.8, -15), 0.4, { 0.90, 0.70, 0.75 }, { unlit = true })

    -- 三朵桃花（演示标记）
    WhiteBox.BlossomMarker(scene_, Vector3(-5, 0.6, -14), "wood", { 0.36, 0.72, 0.38 })
    WhiteBox.BlossomMarker(scene_, Vector3(6, 0.6, -15), "fire", { 0.90, 0.35, 0.30 })
    WhiteBox.BlossomMarker(scene_, Vector3(-2, 0.6, 10), "water", { 0.34, 0.55, 0.85 })

    -- 边界墙
    -- 边界墙（R12 根因修复：后墙外移 22.5→29，给相机留 space）
    WhiteBox.BoundaryWalls(scene_, 7.5, 29.0, 3.0, { 0.40, 0.40, 0.32 })

    -- 出生点（入口）
    return Vector3(0, 0.1, 19)
end

--- ============================================================================
--- 场景 3：洛水阴山（异域/雾霭）
--- ============================================================================
function BuildLuoShuiYinShan(root)
    local scene_ = root
    -- 地面：暗色石板
    WhiteBox.Ground(scene_, "Ground", 16, 46, { 0.32, 0.32, 0.38 })

    -- 小镇（几座高低错落的盒屋）
    WhiteBox.Box(scene_, "TownHouse1", Vector3(-4, 1.0, -12), Vector3(4, 2.0, 4), { 0.40, 0.36, 0.40 })
    WhiteBox.Box(scene_, "TownHouse2", Vector3(2, 1.4, -4), Vector3(4, 2.8, 4), { 0.44, 0.38, 0.42 })
    WhiteBox.Box(scene_, "TownHouse3", Vector3(-3, 0.8, 8), Vector3(4.5, 1.6, 4), { 0.38, 0.34, 0.38 })
    -- 异域山镇：再加 3 座高低错落的暗灰/冷色盒屋与屋棚
    WhiteBox.Box(scene_, "TownHouse4", Vector3(5.2, 1.6, -14), Vector3(3.2, 3.2, 3.4), { 0.34, 0.36, 0.44 })
    WhiteBox.Box(scene_, "TownHouse4Roof", Vector3(5.2, 3.4, -14), Vector3(3.8, 0.28, 4.0), { 0.26, 0.28, 0.36 })
    WhiteBox.Box(scene_, "TownHouse5", Vector3(-5.6, 1.2, -2), Vector3(3.0, 2.4, 3.2), { 0.32, 0.34, 0.40 })
    WhiteBox.Box(scene_, "TownShed", Vector3(5.4, 0.7, 4), Vector3(3.6, 1.4, 2.6), { 0.30, 0.32, 0.38 })
    WhiteBox.Box(scene_, "TownShedRoof", Vector3(5.4, 1.5, 4), Vector3(4.2, 0.18, 3.2), { 0.24, 0.26, 0.34 })

    -- 山泉/井：石台 + 小盒井架（呼应「无面鬼喝山泉」）
    WhiteBox.Cylinder(scene_, "SpringWell", Vector3(-5.2, 0.35, 14), 1.8, 0.7, { 0.36, 0.40, 0.48 })
    WhiteBox.Cylinder(scene_, "SpringWater", Vector3(-5.2, 0.62, 14), 1.2, 0.16, { 0.28, 0.42, 0.58 }, { unlit = true })
    WhiteBox.Box(scene_, "SpringFrame", Vector3(-5.2, 1.15, 14), Vector3(2.0, 0.22, 2.0), { 0.30, 0.32, 0.38 })
    WhiteBox.Box(scene_, "SpringPostL", Vector3(-6.05, 1.5, 14), Vector3(0.16, 0.9, 0.16), { 0.26, 0.28, 0.34 })
    WhiteBox.Box(scene_, "SpringPostR", Vector3(-4.35, 1.5, 14), Vector3(0.16, 0.9, 0.16), { 0.26, 0.28, 0.34 })
    WhiteBox.Beacon(scene_, "Beacon_spring", Vector3(-5.2, 0.5, 14), { 0.40, 0.62, 0.82 }, 1.4)

    -- 无面鬼处（石台 + C 阶段 3D 模型：白衣/空脸/泪痕蜷坐鬼，坐在石台顶；失败回退原暗红球）
    -- R12 近景靠边：原 x=2 石台直径 4 左缘压出生→小镇中心路线 → 右移到 x=3.5 让出中线
    WhiteBox.Cylinder(scene_, "GhostStone", Vector3(3.5, 0.3, 16), 4.0, 0.6, { 0.28, 0.26, 0.30 })
    local ghostNode = scene_:CreateChild("GhostMarker")
    -- 石台顶面 y=0.6；x 偏 +0.55 让开台心 Beacon_ghost 光柱与 Blossom_water 球（原样保留），
    -- 仍在"约(3.5,·,16)"台顶范围内，真机截图实测光柱穿脸遮挡
    ghostNode.position = Vector3(4.05, 0.6, 16)
    -- rig 版包围盒 Min Y=0 → 子节点无需上移即脚底落台面；
    -- 视觉正面实测 +90° 朝 -Z，故 -90° 使正面朝 +Z（出生点/玩家来向）
    local ghostModel = AttachNpcModel(ghostNode, NOFACE_MODEL, NOFACE_MATERIAL,
        NOFACE_SCALE, 0, -90)
    if ghostModel == nil then
        WhiteBox.Sphere(ghostNode, "GhostMarkerBall", Vector3(0, 0.7, 0), 0.5,
            { 0.55, 0.30, 0.34 }, { unlit = true })
    else
        -- 模型无碰撞：补小圆柱 GROUND 碰撞体（防跳上石台穿身）
        local body = ghostNode:CreateComponent("RigidBody")
        body.collisionLayer = WhiteBox.LAYER_GROUND
        body.collisionMask = 0xFFFF
        local shape = ghostNode:CreateComponent("CollisionShape")
        shape:SetCylinder(1.0, 1.2, Vector3(0, 0.6, 0))
    end
    -- 无面鬼处更醒目：暗红/冷色光柱 + 局部冷光
    WhiteBox.Beacon(scene_, "Beacon_ghost", Vector3(3.5, 0.6, 16), { 0.72, 0.22, 0.28 }, 3.2)
    WhiteBox.Beacon(scene_, "Beacon_ghost_cold", Vector3(4.4, 0.5, 16.8), { 0.38, 0.48, 0.72 }, 2.0)
    local ghostLightNode = scene_:CreateChild("GhostGlow")
    ghostLightNode.position = Vector3(3.5, 1.8, 16)
    local ghostLight = ghostLightNode:CreateComponent("Light")
    ghostLight.lightType = LIGHT_POINT
    ghostLight.color = Color(0.72, 0.28, 0.36)
    ghostLight.brightness = 0.8
    ghostLight.range = 5.5
    ghostLight.castShadows = false

    -- 矿场小路（岩石球 + 矮灯）
    local rockSpots = {
        Vector3(0, 0.25, -2), Vector3(1, 0.35, 5), Vector3(2, 0.45, 12), Vector3(3, 0.4, 19),
        Vector3(-1.2, 0.3, 2), Vector3(0.4, 0.4, 8.5), Vector3(1.6, 0.32, 15.5),
        Vector3(-0.6, 0.28, 11), Vector3(4.2, 0.38, 10),
    }
    for i, pos in ipairs(rockSpots) do
        WhiteBox.Sphere(scene_, "Rock" .. i, pos, 0.5 + (i % 2) * 0.2, { 0.30, 0.30, 0.34 })
    end
    local mineLamps = {
        Vector3(-0.8, 0.4, 1.5), Vector3(1.8, 0.4, 9.2), Vector3(2.6, 0.4, 17.4),
    }
    for i, pos in ipairs(mineLamps) do
        WhiteBox.Box(scene_, "MineLampPost" .. i, Vector3(pos.x, 0.55, pos.z), Vector3(0.14, 1.1, 0.14), { 0.22, 0.22, 0.28 })
        WhiteBox.Sphere(scene_, "MineLamp" .. i, Vector3(pos.x, 1.2, pos.z), 0.22, { 0.85, 0.72, 0.42 }, { unlit = true })
        WhiteBox.Beacon(scene_, "Beacon_mine_" .. i, pos, { 0.82, 0.68, 0.38 }, 1.0)
    end

    -- 三朵桃花（演示标记；water 跟随无面鬼石台右移）
    WhiteBox.BlossomMarker(scene_, Vector3(-4, 0.6, -12), "earth", { 0.78, 0.62, 0.36 })
    WhiteBox.BlossomMarker(scene_, Vector3(3.5, 0.6, 16), "water", { 0.34, 0.55, 0.85 })
    WhiteBox.BlossomMarker(scene_, Vector3(0, 0.6, -2), "metal", { 0.82, 0.82, 0.86 })

    -- 边界墙（R12 根因修复：后墙外移 22.5→29，给相机留 space）
    local wallRgb = { 0.24, 0.24, 0.30 }
    WhiteBox.BoundaryWalls(scene_, 7.5, 29.0, 3.0, wallRgb)

    -- 出生点
    return Vector3(0, 0.1, 19)
end

return SceneManager
