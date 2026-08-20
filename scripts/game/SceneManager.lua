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

---@type Scene|nil
local scene_ = nil
---@type table|nil
local player_ = nil      -- PlayerController 实例（提供 SetPosition）
---@type Node|nil
local sceneRoot_ = nil
---@type string
local currentScene_ = ""

--- 场景氛围配置（雾色/环境光，随场景切换）
local SCENE_MOOD = {
    chaoyang_gukou = {
        ambient = Color(0.42, 0.40, 0.42),
        fog = Color(0.92, 0.85, 0.78),
        fogStart = 30.0,
        fogEnd = 120.0,
    },
    gu_nei_taolin = {
        ambient = Color(0.36, 0.38, 0.36),
        fog = Color(0.80, 0.82, 0.74),
        fogStart = 25.0,
        fogEnd = 90.0,
    },
    luoshui_yinshan = {
        ambient = Color(0.30, 0.30, 0.36),
        fog = Color(0.42, 0.44, 0.50),
        fogStart = 12.0,
        fogEnd = 60.0,
    },
}

--- 初始化
---@param scene Scene
---@param player table PlayerController 实例
function SceneManager.Init(scene, player)
    scene_ = scene
    player_ = player
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

    -- 构建白模
    local spawn = nil
    if sceneName == "chaoyang_gukou" then
        spawn = BuildChaoyangGukou(sceneRoot_)
    elseif sceneName == "gu_nei_taolin" then
        spawn = BuildGuNeiTaoLin(sceneRoot_)
    elseif sceneName == "luoshui_yinshan" then
        spawn = BuildLuoShuiYinShan(sceneRoot_)
    end

    -- 玩家回到出生点
    if player_ ~= nil and spawn ~= nil then
        player_:SetPosition(spawn)
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

--- 应用场景氛围（雾 + 环境光）
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

    -- 素女守望处（小台 + 素色标记）
    WhiteBox.Box(scene_, "WatchPlatform", Vector3(5, 0.25, 10), Vector3(3, 0.5, 3), { 0.78, 0.80, 0.82 })
    WhiteBox.Sphere(scene_, "WatchMarker", Vector3(5, 1.2, 10), 0.4, { 0.95, 0.93, 0.88 }, { unlit = true })

    -- 五朵五行桃花（谷口/桃树下/望夫崖/井边/守桃老人屋 的白模占位）
    local blossomSpots = {
        { key = "wood",   pos = Vector3(-6, 0.6, 14),   rgb = { 0.36, 0.72, 0.38 } },  -- 木（东）
        { key = "fire",   pos = Vector3(6, 0.6, -10),   rgb = { 0.90, 0.35, 0.30 } },  -- 火（南）
        { key = "earth",  pos = Vector3(0, 0.6, -20),   rgb = { 0.78, 0.62, 0.36 } },  -- 土（中）
        { key = "metal",  pos = Vector3(-6, 0.6, -14),  rgb = { 0.82, 0.82, 0.86 } },  -- 金（西）
        { key = "water",  pos = Vector3(4, 0.6, 20),    rgb = { 0.34, 0.55, 0.85 } },  -- 水（北）
    }
    for _, spot in ipairs(blossomSpots) do
        WhiteBox.BlossomMarker(scene_, spot.pos, spot.key, spot.rgb)
    end

    -- 守桃老人（S2 对话 NPC，白模：衣袍圆柱 + 头颅球 + 手杖）
    local oldManPos = Vector3(3, 0, -16)
    WhiteBox.Cylinder(scene_, "OldMan", Vector3(oldManPos.x, 0.75, oldManPos.z), 0.7, 1.5,
        { 0.46, 0.38, 0.32 })
    WhiteBox.Sphere(scene_, "OldManHead", Vector3(oldManPos.x, 1.75, oldManPos.z), 0.4,
        { 0.90, 0.82, 0.74 })
    -- 交互点（走近触发对话：P02 完成条件，节点名 Int_oldman）
    WhiteBox.Sphere(scene_, "Int_oldman", Vector3(oldManPos.x, 0.5, oldManPos.z + 1.8), 0.5,
        { 0.55, 0.85, 0.45 }, { unlit = true, trigger = true,
            layer = WhiteBox.LAYER_TRIGGER, mask = WhiteBox.LAYER_PLAYER })

    -- 边界墙
    WhiteBox.BoundaryWalls(scene_, 8.5, 25.5, 3.0, { 0.55, 0.42, 0.32 })

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

    -- 桃树群
    WhiteBox.PeachTree(scene_, "TaoA", Vector3(4, 0, 16), 1.2)
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
    WhiteBox.BoundaryWalls(scene_, 7.5, 22.5, 3.0, { 0.40, 0.40, 0.32 })

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

    -- 无面鬼处（石台 + 暗色标记）
    WhiteBox.Cylinder(scene_, "GhostStone", Vector3(2, 0.3, 16), 4.0, 0.6, { 0.28, 0.26, 0.30 })
    WhiteBox.Sphere(scene_, "GhostMarker", Vector3(2, 1.3, 16), 0.5, { 0.55, 0.30, 0.34 }, { unlit = true })

    -- 矿场小路（一排岩石球）
    local rockSpots = {
        Vector3(0, 0.25, -2), Vector3(1, 0.35, 5), Vector3(2, 0.45, 12), Vector3(3, 0.4, 19),
    }
    for i, pos in ipairs(rockSpots) do
        WhiteBox.Sphere(scene_, "Rock" .. i, pos, 0.5 + (i % 2) * 0.2, { 0.30, 0.30, 0.34 })
    end

    -- 三朵桃花（演示标记）
    WhiteBox.BlossomMarker(scene_, Vector3(-4, 0.6, -12), "earth", { 0.78, 0.62, 0.36 })
    WhiteBox.BlossomMarker(scene_, Vector3(2, 0.6, 16), "water", { 0.34, 0.55, 0.85 })
    WhiteBox.BlossomMarker(scene_, Vector3(0, 0.6, -2), "metal", { 0.82, 0.82, 0.86 })

    -- 边界墙
    local wallRgb = { 0.24, 0.24, 0.30 }
    WhiteBox.BoundaryWalls(scene_, 7.5, 22.5, 3.0, wallRgb)

    -- 出生点
    return Vector3(0, 0.1, 19)
end

return SceneManager
