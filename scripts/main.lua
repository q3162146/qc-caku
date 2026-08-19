-- ============================================================================
-- main.lua ——《桃素洛无幽·素女篇》唯一业务入口
--
-- 职责（快速开工包 ④）：
--   1. 启动时读取 .project/settings.json，校验 multiplayer.enabled == false
--      （单机模式）；异常时打日志退出。
--   2. 创建场景（Octree/PhysicsWorld/DebugRenderer + 定向光）。
--   3. 初始化：PlayerData（存档契约）→ FlowController（段落化流程）
--      → SceneManager（三段白模）→ PlayerController（移动/相机/碰撞）。
--   4. 订阅 Update/PostUpdate。
--
-- 演示操作：
--   WASD/方向键 移动 | 鼠标 视角 | 空格 跳跃 | Shift 跑步
--   F5 强制完成当前段落 | F2/F3/F4 调试直切三场景 | ESC 退出
--
-- 本会话范围：项目骨架 + 三段白模 + 移动/相机/碰撞 + Chapters/flow 最小闭环。
-- 其余系统（对话/视频/UI/存档 IO）由后续会话实现。
-- ============================================================================

local PlayerData = require "config.PlayerData"
local Chapters = require "config.Chapters"
local SceneManager = require "game.SceneManager"
local PlayerController = require "game.PlayerController"
local FlowController = require "flow.FlowController"

---@type Scene|nil
local scene_ = nil

-- ============================================================================
-- 单机模式校验
-- ============================================================================

--- 读取并解析 .project/settings.json
---@return table|nil settings, string|nil err
local function ReadProjectSettings()
    if not cache:Exists(".project/settings.json") then
        return nil, "missing"
    end
    local file = cache:GetFile(".project/settings.json")
    if file == nil then
        return nil, "unreadable"
    end
    local content = file:ReadString()
    file:Close()
    if content == nil or content == "" then
        return nil, "empty"
    end
    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then
        return nil, "bad_json"
    end
    return data, nil
end

--- 校验单机模式：multiplayer.enabled 必须为 false
--- 配置缺失/损坏 → 本地开发放行（打日志）；明确多人 → 打日志退出
---@return boolean
function ValidateSinglePlayerConfig()
    local settings, err = ReadProjectSettings()
    if settings == nil then
        print("[main] 警告：.project/settings.json " .. tostring(err)
            .. "，跳过单机校验（本地开发）")
        return true
    end

    -- @runtime.multiplayer（构建期源配置）或顶层 multiplayer（运行时提升后）都检查
    local mp = settings.multiplayer
    if type(settings["@runtime"]) == "table" and type(settings["@runtime"].multiplayer) == "table" then
        mp = settings["@runtime"].multiplayer
    end

    local enabled = (type(mp) == "table") and (mp.enabled == true)
    if enabled then
        print("[main] 错误：multiplayer.enabled == true（多人模式），"
            .. "本作必须为单机模式，退出")
        engine:Exit()
        return false
    end

    print("[main] 单机模式校验通过（multiplayer.enabled = false）")
    return true
end

-- ============================================================================
-- 场景创建（灯光/物理，全局一次）
-- ============================================================================

function CreateScene()
    scene_ = Scene()

    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    local physics = scene_:CreateComponent("PhysicsWorld")
    physics:SetGravity(Vector3(0, -9.81, 0))

    -- 定向光（太阳）
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.9, 0.9, 0.9)
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    print("=== 桃素洛无幽·素女篇 启动（白模骨架会话） ===")

    -- 1. 单机模式校验（异常即退出）
    if not ValidateSinglePlayerConfig() then
        return
    end

    -- 2. 场景与玩家
    CreateScene()
    PlayerController.Create(scene_)
    SceneManager.Init(scene_, PlayerController)

    -- 3. 数据与流程（本会话无存档 IO，用全新数据）
    local data = PlayerData.Sanitize(nil)
    FlowController.Init(data)
    FlowController.Start()

    -- 4. 事件订阅
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    print("=== 启动完成 ===")
    print("操作：WASD/方向键 移动 | 鼠标 视角 | 空格 跳跃 | Shift 跑步")
    print("调试：F5 强制完成段落 | F2/F3/F4 直切三场景 | ESC 退出")
end

function Stop()
    print("[main] 停止")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    PlayerController.Update(timeStep)

    -- 调试快捷键
    if input:GetKeyPress(KEY_F5) then
        FlowController.DebugForceComplete()
    end
    if input:GetKeyPress(KEY_F2) then
        print("[main] 调试：直切场景 chaoyang_gukou（流程状态不变）")
        SceneManager.LoadScene("chaoyang_gukou")
    end
    if input:GetKeyPress(KEY_F3) then
        print("[main] 调试：直切场景 gu_nei_taolin（流程状态不变）")
        SceneManager.LoadScene("gu_nei_taolin")
    end
    if input:GetKeyPress(KEY_F4) then
        print("[main] 调试：直切场景 luoshui_yinshan（流程状态不变）")
        SceneManager.LoadScene("luoshui_yinshan")
    end
    if input:GetKeyPress(KEY_ESCAPE) then
        engine:Exit()
    end
end

---@param eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    PlayerController.PostUpdate(timeStep)
end
