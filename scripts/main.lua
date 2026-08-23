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
local InputManager = require "game.InputManager"
local FlowController = require "flow.FlowController"
local DialogueUI = require "ui.DialogueUI"
local VideoSpike = require "experiments.VideoSpike"
local UI = require "urhox-libs/UI"

---@type Scene|nil
local scene_ = nil

-- ============================================================================
-- 单机模式校验
-- ============================================================================

--- 读取并解析 .project/settings.json
---@return table|nil settings, string|nil err
local function ReadProjectSettings()
    if not fileSystem:FileExists(".project/settings.json") then
        return nil, "missing"
    end
    local file = File(".project/settings.json", FILE_READ)
    if file == nil or not file:IsOpen() then
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
--- 配置缺失/损坏/多人模式 → 打日志退出
---@return boolean
function ValidateSinglePlayerConfig()
    local settings, err = ReadProjectSettings()
    if settings == nil then
        print("[main] 错误：.project/settings.json " .. tostring(err) .. "，退出")
        engine:Exit()
        return false
    end

    local runtime = settings["@runtime"]
    local mp = type(runtime) == "table" and runtime.multiplayer or nil
    if type(mp) ~= "table" or type(mp.enabled) ~= "boolean" then
        print("[main] 错误：缺少明确的 @runtime.multiplayer.enabled，退出")
        engine:Exit()
        return false
    end
    if mp.enabled ~= false then
        print("[main] 错误：multiplayer.enabled 必须为 false，退出")
        engine:Exit()
        return false
    end

    print("[main] 单机模式校验通过（multiplayer.enabled = false）")
    return true
end

function ConfigurePortraitOrientation()
    graphics:SetOrientations("Portrait")
    print("[main] 竖屏方向请求: Portrait | 当前方向配置: "
        .. tostring(graphics:GetOrientations()))
    print("[main] 画面尺寸: " .. tostring(graphics:GetWidth()) .. "x"
        .. tostring(graphics:GetHeight()) .. " | DPR=" .. tostring(graphics:GetDPR()))
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

--- 调试：真机触屏触发 Spike 的角标按钮（真机无 F6 键盘；S9 发布前移除）
local spikeButton_ = nil
local function ShowSpikeDebugButton()
    if spikeButton_ then return end
    local root = UI.Panel {
        id = "spikeDebugRoot",
        width = "100%", height = "100%",
        pointerEvents = "box-none",  -- 透传，避免拦截游戏输入（虚拟摇杆/跳跃）
    }
    local btn = UI.Button {
        id = "spikeDebugBtn",
        text = "Spike",
        position = "absolute", top = 28, right = 20,
        width = 96, height = 34,
        variant = "secondary",
        fontSize = 14,
        marginTop = 0, marginLeft = 0, marginRight = 0, marginBottom = 0,
        onClick = function()
            print("[main] 调试：视频生命周期 Spike（触屏按钮）")
            VideoSpike.Toggle()
        end,
    }
    root:AddChild(btn)
    spikeButton_ = btn
    UI.SetRoot(root)
end

function Start()
    print("=== 桃素洛无幽·素女篇 启动（S2 对话会话） ===")

    -- 1. 单机模式校验（异常即退出）
    if not ValidateSinglePlayerConfig() then
        return
    end

    -- 2. 竖屏方向（发布元数据 + 运行时双层实测）
    ConfigurePortraitOrientation()

    -- 2. 输入抽象层
    InputManager.Initialize({ touchSensitivity = 2 })

    -- 3. UI 系统（对话/选项/字幕统一用 urhox-libs/UI）
    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })

    -- 3.1 真机触屏 Spike 调试按钮（无 F6 键盘的入口；S9 前移除）
    ShowSpikeDebugButton()

    -- 3. 场景与玩家
    CreateScene()
    PlayerController.Create(scene_)
    SceneManager.Init(scene_, PlayerController)

    -- 4. 数据与流程（本会话无存档 IO，用全新数据）
    local data = PlayerData.Sanitize(nil)
    FlowController.Init(data)
    FlowController.Start()

    -- 6. 事件订阅
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    print("=== 启动完成 ===")
    print("操作：WASD/方向键 移动 | 鼠标 视角 | 空格 跳跃 | 竖屏 9:16 纵深布局")
    print("调试：F5 强制完成段落 | F6/右上角Spike按钮 视频生命周期 Spike | F2/F3/F4 直切三场景 | ESC 退出")
end

function Stop()
    InputManager.Shutdown()
    UI.Shutdown()
    print("[main] 停止")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 视频生命周期 Spike（实验模块）：激活时每帧驱动其计时器/状态机
    if VideoSpike.IsActive() then
        VideoSpike.Update(timeStep)
    end

    -- 对话打开时：只处理对话输入，玩家停移动（防串台）
    if DialogueUI.IsOpen() then
        DialogueUI.HandleInput()
    else
        PlayerController.Update(timeStep)
    end

    -- 调试快捷键
    if InputManager.IsKeyPress(KEY_F6) then
        print("[main] 调试：视频生命周期 Spike")
        VideoSpike.Toggle()
    end
    if InputManager.IsKeyPress(KEY_F5) then
        FlowController.DebugForceComplete()
    end
    if InputManager.IsKeyPress(KEY_F2) then
        print("[main] 调试：直切场景 chaoyang_gukou（流程状态不变）")
        SceneManager.LoadScene("chaoyang_gukou")
    end
    if InputManager.IsKeyPress(KEY_F3) then
        print("[main] 调试：直切场景 gu_nei_taolin（流程状态不变）")
        SceneManager.LoadScene("gu_nei_taolin")
    end
    if InputManager.IsKeyPress(KEY_F4) then
        print("[main] 调试：直切场景 luoshui_yinshan（流程状态不变）")
        SceneManager.LoadScene("luoshui_yinshan")
    end
    if InputManager.IsKeyPress(KEY_ESCAPE) then
        engine:Exit()
    end
end

---@param eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    PlayerController.PostUpdate(timeStep)
end
