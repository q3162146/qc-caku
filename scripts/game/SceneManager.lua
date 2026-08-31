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
local Backdrop = require "game.Backdrop"
local SceneProps = require "game.SceneProps"
local Scenery = require "game.Scenery"
-- DWP 下载扩展（真机按需下载远程依赖；预热道具模型/材质/贴图减少占位期）
require "urhox-libs.Engine.ResourceCacheExtensions"

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

-- ============================================================================
-- D2 场景补齐辅助：白模道具 → 真实模型视觉替换（保留原白模碰撞）
-- ============================================================================

--- 取 root 子树内多个名字的节点（跳过不存在的）
---@param root Node
---@param names string[]
---@return Node[]
local function GetNodes(root, names)
    ---@type Node[]
    local out = {}
    for _, n in ipairs(names) do
        ---@type Node|nil
        local node = root:GetChild(n, true)
        if node ~= nil then
            table.insert(out, node)
        end
    end
    return out
end

--- 白模节点组 → 单个真实模型视觉替换：
---   视觉加载成功 → 剥掉全部白模节点的 StaticModel（碰撞体原样保留）
---   视觉加载失败 → 保留白模视觉，玩法不破（与 C 阶段 NPC 回退同策略）
---@param parent Node 视觉节点挂载父级（场景根 / Blossom 节点）
---@param whiteNodes Node[] 需剥视觉的白模节点列表
---@param visName string 视觉节点名
---@param assetKey string SceneProps.ASSETS 键
---@param groundPos Vector3 视觉底面中心位置（贴地/贴台面）
---@param scale number|table 等比或 { x, y, z } 非等比
---@param yaw? number 绕 Y 朝向角（度；制造同类道具的朝向差异）
local function SwapToProp(parent, whiteNodes, visName, assetKey, groundPos, scale, yaw)
    local vis = SceneProps.AttachProp(parent, visName, assetKey, groundPos, scale, yaw)
    if vis ~= nil then
        for _, n in ipairs(whiteNodes) do
            SceneProps.StripVisual(n)
        end
    end
    return vis
end

--- D2 桃花视觉替换：真实桃花丛挂在 Blossom_<key> 节点下（采集移除时随父节点一并消失）
--- 触发球本体剥视觉（保留 TRIGGER 碰撞与节点名/位置不动）
---@param bNode Node|nil Blossom_<key> 触发球节点
---@param visXZ table { x, z } 视觉底面【世界坐标】（触发点旁/井沿等避让后位置）
---@param standY number 视觉底面贴附面高度（地面 0 / 石台顶 0.6）
---@param yaw? number
local function DressBlossom(bNode, visXZ, standY, yaw)
    if bNode == nil then return end
    -- 挂触发球下（AttachProp 内部做父变换补偿，传世界坐标即可）
    local vis = SceneProps.AttachProp(bNode, "Vis", "blossom",
        Vector3(visXZ.x, standY, visXZ.z), 1.05, yaw)
    if vis ~= nil then
        SceneProps.StripVisual(bNode)
    end
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
-- D 阶段 D1：远景为水墨全景 cubemap Skybox（见 game/Backdrop.lua），
--   雾色与 skyHorizon 取远景画雾带同色系，边界墙/地面与远景地平线自然过渡；
--   skyZenith/skyHorizon 同时作 cubemap 加载失败时渐变天空回退配色。
local SCENE_MOOD = {
    chaoyang_gukou = {
        name = "朝阳谷口",
        ambient = Color(0.42, 0.40, 0.42),
        fog = Color(0.90, 0.84, 0.74),
        fogStart = 30.0,
        fogEnd = 120.0,
        fogDensity = 1.0,
        lightColor = Color(0.95, 0.90, 0.82),
        lightBrightness = 1.05,
        -- 回退渐变天空配色（暖金晨空，贴朝阳谷口远景画）
        skyZenith = Color(0.55, 0.48, 0.38),
        skyHorizon = Color(0.90, 0.84, 0.74),
    },
    gu_nei_taolin = {
        name = "谷内桃林",
        ambient = Color(0.36, 0.38, 0.36),
        fog = Color(0.80, 0.83, 0.76),
        fogStart = 25.0,
        fogEnd = 90.0,
        fogDensity = 1.0,
        lightColor = Color(0.82, 0.88, 0.78),
        lightBrightness = 0.92,
        -- 回退渐变天空配色（清幽青绿）
        skyZenith = Color(0.42, 0.52, 0.46),
        skyHorizon = Color(0.80, 0.83, 0.76),
    },
    luoshui_yinshan = {
        name = "洛水阴山",
        ambient = Color(0.22, 0.24, 0.32),
        fog = Color(0.46, 0.50, 0.56),
        -- 第三人称相机约 6.8m，fogStart 须大于相机距离，否则整屏被雾吃掉
        fogStart = 18.0,
        fogEnd = 80.0,
        fogDensity = 1.2,
        heightFog = false,
        lightColor = Color(0.62, 0.68, 0.84),
        lightBrightness = 0.62,
        -- 回退渐变天空配色（阴山冷雾青灰）
        skyZenith = Color(0.16, 0.18, 0.24),
        skyHorizon = Color(0.46, 0.50, 0.56),
    },
}

--- D2.5-四：真实道具 DWP 预热 + 资产清单诊断
---   白模道具的 .mdl 为 render-blocking（真机必然在包内），贴图属 DWP 媒体资源
---   （真机首见先占位后热替换，表现为"帧偏空/白模感"）。场景加载时先发起全部
---   道具模型/材质/贴图依赖下载，缩短占位空窗；同时打印 manifest 清单便于真机排查。
local function WarmPropsAsync()
    ---@type string[]
    local uris = {}
    ---@type table<string, boolean>
    local seen = {}
    local function AddUri(u)
        if not seen[u] then
            seen[u] = true
            table.insert(uris, u)
        end
    end
    for key, def in pairs(SceneProps.ASSETS) do
        local inModel = cache.GetResInfo ~= nil and cache:GetResInfo(def.model) ~= nil
        local inMat = cache.GetResInfo ~= nil and cache:GetResInfo(def.mat) ~= nil
        print(string.format("[SceneManager] 道具清单 %s: model=%s mat=%s",
            key, inModel and "在包" or "缺失", inMat and "在包" or "缺失"))
        AddUri(def.model)
        AddUri(def.mat)
        if cache.GetResRefs ~= nil then
            for _, r in ipairs(cache:GetResRefs({ def.model, def.mat }, true)) do
                AddUri(r)
            end
        end
    end
    if cache.DownloadResources == nil then
        print("[SceneManager] 运行时无 DWP 下载 API，跳过道具预热（交由 uuid 路由）")
        return
    end
    print("[SceneManager] 道具 DWP 预热中（" .. #uris .. " 个依赖）…")
    cache:DownloadResources(uris, function(success, failed)
        print("[SceneManager] 道具预热完成: success=" .. tostring(success)
            .. " failed=" .. tostring(failed))
    end)
end

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

    -- D1 远景：水墨全景 cubemap Skybox（不随 SceneRoot 销毁；失败回退渐变天空）
    Backdrop.Apply(scene_, sceneName, SCENE_MOOD[sceneName])

    -- 场景名回传（用于顶部横幅等）
    if onSceneLoaded_ ~= nil then
        onSceneLoaded_(SCENE_MOOD[sceneName].name or sceneName)
    end

    -- D2.5-四：真机道具在位加固——先发起 DWP 预热全部真实道具的模型/材质/贴图
    -- 依赖，减少真机"先占位白模后热替换"的空窗期；并输出资产清单日志供排查
    WarmPropsAsync()

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
    -- 地面：暖金色（D2 调色贴朝阳远景画雾带 0.90/0.84/0.74）
    -- D2.5：地面铺满边界墙脚（17×64 = 2×8.5/2×32），消除原 18×52 与墙间的地缝
    WhiteBox.Ground(scene_, "Ground", 17, 64, { 0.86, 0.76, 0.58 })

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
        { key = "wood",   pos = Vector3(-6, 0.6, 14),   rgb = { 0.36, 0.72, 0.38 }, yaw = 0 },    -- 木（东）
        { key = "fire",   pos = Vector3(4.5, 0.6, -6),  rgb = { 0.90, 0.35, 0.30 }, yaw = 70 },   -- 火（南，主路东侧，避开老人交互点）
        { key = "earth",  pos = Vector3(0, 0.6, -20),   rgb = { 0.78, 0.62, 0.36 }, yaw = 140 },  -- 土（中）
        { key = "metal",  pos = Vector3(-6, 0.6, -14),  rgb = { 0.82, 0.82, 0.86 }, yaw = 210 },  -- 金（西）
        { key = "water",  pos = Vector3(4, 0.6, 20),    rgb = { 0.34, 0.55, 0.85 }, yaw = 280 },  -- 水（北）
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
    -- D2 调色：暖金贴朝阳远景画雾带
    WhiteBox.BoundaryWalls(scene_, 8.5, 32.0, 3.0, { 0.74, 0.63, 0.50 })

    -- ========== D2 场景补齐：白模道具 → 真实模型视觉（碰撞/触发/光柱原位不动） ==========
    -- 无涕桃 → 真实桃树（原白模树冠顶 ≈3.0m → 模型等比 3.4；树干圆柱碰撞保留）
    SwapToProp(scene_, GetNodes(scene_, { "WutiTao_Trunk", "WutiTao_Canopy", "WutiTao_Canopy2" }),
        "WutiTao_Visual", "peach_tree", Vector3(0, 0, 0), 3.4, 20)
    -- 环石×8 → 真实石板（底面贴地，位置不动）
    for i = 1, 8 do
        local ringName = "WutiTaoRing" .. i
        ---@type Node|nil
        local ringNode = scene_:GetChild(ringName, true)
        if ringNode ~= nil then
            local rp = ringNode.position
            -- 非等比：XZ 0.6m 见方、高 ≈0.29m（贴原白模石板 0.55×0.24×0.55）
            SwapToProp(scene_, { ringNode }, ringName .. "_Visual", "stone_slab",
                Vector3(rp.x, 0, rp.z), { x = 0.6, y = 2.2, z = 0.6 }, i * 45)
        end
    end
    -- 素女守望处 → 观景台/望夫石（XZ 铺满原 3×3 碰撞台；望夫石圆润石体立台上）
    SwapToProp(scene_, GetNodes(scene_, { "WatchPlatform", "WatchMarker" }),
        "WatchPlatform_Visual", "watch_altar", Vector3(5, 0, 10), { x = 3.2, y = 1.0, z = 3.2 }, -15)
    -- 老人旁矮灯 → 真实古风灯柱（暖点光保留）
    SwapToProp(scene_, GetNodes(scene_, { "OldManLampPost", "OldManLamp" }),
        "OldManLamp_Visual", "lamp_post",
        Vector3(oldManPos.x + 1.4, 0, oldManPos.z - 0.6), 1.6, 0)
    -- 五朵桃花 → 真实桃花丛（触发球节点名/位置/碰撞不动；采集随父节点一并移除）
    for _, spot in ipairs(blossomSpots) do
        DressBlossom(scene_:GetChild("Blossom_" .. spot.key, true),
            { x = spot.pos.x, z = spot.pos.z }, 0, spot.yaw)
    end

    -- ========== D2.5 场景补全：地面真实化 + 撒点 + 地平线雾带 + 氛围散点 ==========
    -- 散点全部纯视觉不带碰撞；坐标避开交互点/触发点/主路（不改任何坐标与触发）
    Scenery.Build(scene_, "chaoyang_gukou", { halfW = 8.5, halfD = 32 }, {
        -- 谷缘桃树丛（贴边，填充空旷外围）
        { asset = "peach_tree", x = -7.0, z = 26,   s = 1.8, yaw = 30 },
        { asset = "peach_tree", x = 6.9,  z = -25,  s = 2.0, yaw = 120 },
        { asset = "peach_tree", x = -7.3, z = -6,   s = 1.6, yaw = 210 },
        { asset = "peach_tree", x = 7.2,  z = 2,    s = 1.7, yaw = 300 },
        -- 花丛点缀
        { asset = "blossom",    x = -4.5, z = 27,   s = 1.0, yaw = 15 },
        { asset = "blossom",    x = 5.8,  z = 25,   s = 0.9, yaw = 195 },
        { asset = "blossom",    x = -7.6, z = 8,    s = 1.0, yaw = 75 },
        { asset = "blossom",    x = 7.7,  z = -12,  s = 0.9, yaw = 255 },
        -- 小石块
        { asset = "rock",       x = -3.5, z = 26.5, s = 0.7, yaw = 40 },
        { asset = "rock",       x = 3.2,  z = 27,   s = 0.5, yaw = 90 },
        { asset = "rock",       x = -7.4, z = 18,   s = 0.8, yaw = 160 },
        { asset = "rock",       x = 7.5,  z = 15,   s = 0.6, yaw = 220 },
        { asset = "rock",       x = -2.5, z = -26,  s = 0.7, yaw = 280 },
        -- 蜿蜒小径石板（出生→无涕桃 主路点景，视觉不挡路）
        { asset = "stone_slab", x = 0.6,  z = 14,   s = 0.8, yaw = 12 },
        { asset = "stone_slab", x = -0.7, z = 9,    s = 0.8, yaw = 40 },
        { asset = "stone_slab", x = 0.8,  z = 5,    s = 0.8, yaw = 77 },
    })

    -- 出生点
    return Vector3(0, 0.1, 22)
end

--- ============================================================================
--- 场景 2：谷内桃林（清幽）
--- ============================================================================
function BuildGuNeiTaoLin(root)
    local scene_ = root
    -- 地面：青绿清幽（D2 调色贴桃林远景画雾带 0.80/0.83/0.76）
    -- D2.5：铺满边界墙脚（15×58 = 2×7.5/2×29），修复原 16×46 在 ±Z 墙脚留 6m 可坠地缝
    WhiteBox.Ground(scene_, "Ground", 15, 58, { 0.55, 0.62, 0.48 })

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

    -- 边界墙（D1：青绿灰贴谷内桃林远景雾带，过渡自然）
    -- 边界墙（R12 根因修复：后墙外移 22.5→29，给相机留 space）
    -- D2 调色：青绿清幽贴桃林远景雾带
    WhiteBox.BoundaryWalls(scene_, 7.5, 29.0, 3.0, { 0.50, 0.56, 0.46 })

    -- ========== D2 场景补齐：白模道具 → 真实模型视觉（碰撞/触发/光柱原位不动） ==========
    -- 守桃老人屋 → 真实老屋（碰撞盒 5×2.4×4.5 保留，视觉贴地覆盖盒体）
    SwapToProp(scene_, GetNodes(scene_, { "OldManHouse", "OldManHouseRoof" }),
        "OldManHouse_Visual", "old_house", Vector3(-4, 0, -14), { x = 5.2, y = 3.3, z = 5.2 }, 15)
    -- 井 → 真实石井（井栏+木架辘轳；碰撞圆柱保留）
    SwapToProp(scene_, GetNodes(scene_, { "Well", "WellFrame" }),
        "Well_Visual", "well", Vector3(-2, 0, 10), 1.9, 30)
    -- 桃树×3 → 真实桃树（按白模缩放比例换算：目标高 ≈ 1.65×原 scale）
    local taoTrees = {
        { name = "TaoA", pos = Vector3(7, 0, 15), s = 2.6, yaw = 40 },
        { name = "TaoB", pos = Vector3(6, 0, 4), s = 2.2, yaw = 130 },
        { name = "TaoC", pos = Vector3(-3, 0, -19), s = 2.4, yaw = 250 },
    }
    for _, t in ipairs(taoTrees) do
        SwapToProp(scene_,
            GetNodes(scene_, { t.name .. "_Trunk", t.name .. "_Canopy", t.name .. "_Canopy2" }),
            t.name .. "_Visual", "peach_tree", t.pos, t.s, t.yaw)
    end
    -- 望夫崖 → 真实崖壁（保留斜坡/崖顶碰撞；CliffMarker 白模球一并剥视觉，整组归真实崖壁）
    SwapToProp(scene_, GetNodes(scene_, { "CliffRamp", "CliffTop", "CliffMarker" }),
        "Cliff_Visual", "cliff", Vector3(6, 0, -15), 4.5, -10)
    -- 三朵桃花 → 真实桃花丛（触发点原位不动；wood 视觉移到屋前避让老屋模型）
    DressBlossom(scene_:GetChild("Blossom_wood", true), { x = -5.0, z = -10.8 }, 0, 60)
    DressBlossom(scene_:GetChild("Blossom_fire", true), { x = 6, z = -13.6 }, 4.0, 200)
    DressBlossom(scene_:GetChild("Blossom_water", true), { x = -0.9, z = 10.9 }, 0, 300)

    -- ========== D2.5 场景补全：地面真实化 + 撒点 + 地平线雾带 + 氛围散点 ==========
    -- 散点纯视觉不带碰撞；避开老屋(-4,-14)/井(-2,10)/望夫崖(6,-15)/三朵桃花
    Scenery.Build(scene_, "gu_nei_taolin", { halfW = 7.5, halfD = 29 }, {
        -- 补桃树（青绿桃林密度）
        { asset = "peach_tree", x = -6.2, z = 20,   s = 1.9, yaw = 65 },
        { asset = "peach_tree", x = 6.3,  z = 22,   s = 1.7, yaw = 150 },
        { asset = "peach_tree", x = -6.5, z = -22,  s = 1.8, yaw = 235 },
        { asset = "peach_tree", x = 3.0,  z = -24,  s = 1.6, yaw = 320 },
        { asset = "peach_tree", x = 0.5,  z = 24,   s = 2.0, yaw = 10 },
        -- 花丛/篱笆点景（石条做矮篱意象）
        { asset = "blossom",    x = -2.5, z = 24,   s = 0.9, yaw = 45 },
        { asset = "blossom",    x = 4.8,  z = 12,   s = 1.0, yaw = 130 },
        { asset = "blossom",    x = -6.3, z = 2,    s = 0.9, yaw = 215 },
        { asset = "stone_slab", x = -0.9, z = -8,   s = 0.7, yaw = 20 },
        { asset = "stone_slab", x = 1.2,  z = -11,  s = 0.7, yaw = 65 },
        -- 小石块
        { asset = "rock",       x = -5.0, z = 25,   s = 0.6, yaw = 30 },
        { asset = "rock",       x = 5.5,  z = -25,  s = 0.7, yaw = 110 },
        { asset = "rock",       x = 2.0,  z = 17,   s = 0.5, yaw = 190 },
    })

    -- 出生点（入口）
    return Vector3(0, 0.1, 19)
end

--- ============================================================================
--- 场景 3：洛水阴山（异域/雾霭）
--- ============================================================================
function BuildLuoShuiYinShan(root)
    local scene_ = root
    -- 地面：冷雾夜色（D2 调色偏青蓝，贴阴山远景雾带 0.46/0.50/0.56）
    -- D2.5：铺满边界墙脚（15×58 = 2×7.5/2×29），修复原 16×46 在 ±Z 墙脚留 6m 可坠地缝
    WhiteBox.Ground(scene_, "Ground", 15, 58, { 0.26, 0.29, 0.36 })

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
    -- D1：冷灰青贴洛水阴山远景雾色；D2：冷雾夜色加深
    local wallRgb = { 0.24, 0.27, 0.34 }
    WhiteBox.BoundaryWalls(scene_, 7.5, 29.0, 3.0, wallRgb)

    -- ========== D2 场景补齐：白模道具 → 真实模型视觉（碰撞/触发/光柱原位不动） ==========
    -- 小镇民居×5+屋棚 → 真实山镇民居（非等比对齐原白模盒体尺寸；朝向各异）
    local townHouses = {
        { name = "TownHouse1", pos = Vector3(-4, 0, -12), s = { x = 4.0, y = 2.3, z = 4.0 }, yaw = 10 },
        { name = "TownHouse2", pos = Vector3(2, 0, -4), s = { x = 4.0, y = 3.0, z = 4.0 }, yaw = 100 },
        { name = "TownHouse3", pos = Vector3(-3, 0, 8), s = { x = 4.5, y = 1.9, z = 4.0 }, yaw = 190 },
        { name = "TownHouse4", pos = Vector3(5.2, 0, -14), s = { x = 3.4, y = 3.6, z = 3.6 }, yaw = 260, roof = "TownHouse4Roof" },
        { name = "TownHouse5", pos = Vector3(-5.6, 0, -2), s = { x = 3.2, y = 2.6, z = 3.4 }, yaw = 55 },
        { name = "TownShed", pos = Vector3(5.4, 0, 4), s = { x = 3.6, y = 1.5, z = 2.8 }, yaw = 330, roof = "TownShedRoof" },
    }
    for _, h in ipairs(townHouses) do
        local stripNames = { h.name }
        if h.roof ~= nil then
            table.insert(stripNames, h.roof)
        end
        SwapToProp(scene_, GetNodes(scene_, stripNames),
            h.name .. "_Visual", "town_house", h.pos, h.s, h.yaw)
    end
    -- 山泉井 → 真实泉井（石栏+清泉；Beacon_spring 光柱保留）
    SwapToProp(scene_,
        GetNodes(scene_, { "SpringWell", "SpringWater", "SpringFrame", "SpringPostL", "SpringPostR" }),
        "SpringWell_Visual", "spring_well", Vector3(-5.2, 0, 14), 2.1, 20)
    -- 无面鬼石台 → 真实巨石（非等比压扁：顶面 ≈0.6 对齐原圆柱碰撞顶/无面鬼坐位）
    SwapToProp(scene_, GetNodes(scene_, { "GhostStone" }),
        "GhostStone_Visual", "rock", Vector3(3.5, 0, 16), { x = 4.4, y = 0.6, z = 4.4 }, 25)
    -- 碎石×9 → 真实岩石（小尺寸点缀）
    for i = 1, 9 do
        local rockName = "Rock" .. i
        ---@type Node|nil
        local rockNode = scene_:GetChild(rockName, true)
        if rockNode ~= nil then
            local rp = rockNode.position
            local dia = 0.5 + (i % 2) * 0.2
            SwapToProp(scene_, { rockNode }, rockName .. "_Visual", "rock",
                Vector3(rp.x, 0, rp.z), dia * 1.1, i * 40)
        end
    end
    -- 矿灯×3 → 真实灯柱（暖灯点光效果由 unlit 灯罩贴图自带；Beacon 光柱保留）
    for i = 1, 3 do
        local mp = mineLamps[i]
        SwapToProp(scene_, GetNodes(scene_, { "MineLampPost" .. i, "MineLamp" .. i }),
            "MineLamp_Visual_" .. i, "lamp_post",
            Vector3(mp.x, 0, mp.z), 1.3, i * 90)
    end
    -- 三朵桃花 → 真实桃花丛（触发点原位不动；视觉避让建筑/岩石/石台中心）
    DressBlossom(scene_:GetChild("Blossom_earth", true), { x = -4.0, z = -9.6 }, 0, 120)
    -- water 视觉立石台前缘地面（触发点台心原位不动；台顶已立无面鬼，视觉不挤台顶）
    DressBlossom(scene_:GetChild("Blossom_water", true), { x = 3.5, z = 13.2 }, 0, 240)
    DressBlossom(scene_:GetChild("Blossom_metal", true), { x = 0.8, z = -2.6 }, 0, 0)

    -- ========== D2.5 场景补全：地面真实化 + 撒点 + 地平线雾带 + 氛围散点 ==========
    -- 散点纯视觉不带碰撞；避开小镇民居/泉井(-5.2,14)/鬼石台(3.5,16)/碎石/矿灯
    Scenery.Build(scene_, "luoshui_yinshan", { halfW = 7.5, halfD = 29 }, {
        -- 石堆（冷色碎石，填充空旷外围）
        { asset = "rock",       x = -6.5, z = 20,  s = 1.2, yaw = 25 },
        { asset = "rock",       x = 6.5,  z = 24,  s = 1.0, yaw = 95 },
        { asset = "rock",       x = -6.8, z = -20, s = 1.3, yaw = 165 },
        { asset = "rock",       x = 1.5,  z = 26,  s = 0.9, yaw = 235 },
        { asset = "rock",       x = 6.8,  z = -24, s = 1.1, yaw = 305 },
        { asset = "rock",       x = -1.5, z = -26, s = 1.0, yaw = 15 },
        -- 枯枝/瓦片意象（扁平石板散点）
        { asset = "stone_slab", x = -1.0, z = 12,  s = 0.6, yaw = 40 },
        { asset = "stone_slab", x = 0.5,  z = 22,  s = 0.6, yaw = 100 },
        { asset = "stone_slab", x = 4.5,  z = -19, s = 0.7, yaw = 160 },
        -- 冷色花丛点景
        { asset = "blossom",    x = -3.5, z = 24,  s = 0.8, yaw = 50 },
        { asset = "blossom",    x = 6.0,  z = 8,   s = 0.8, yaw = 200 },
    })

    -- 出生点
    return Vector3(0, 0.1, 19)
end

return SceneManager
