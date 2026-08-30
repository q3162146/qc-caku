-- ============================================================================
-- main.lua ——《桃素洛无幽·素女篇》唯一业务入口
-- 实验模块已封存到 _dev/（见该目录 README）；本文件走素女篇原 Start()。
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
local SaveMenu = require "ui.SaveMenu"
local MainMenu = require "ui.MainMenu"
local EndingScreen = require "ui.EndingScreen"
local ChapterCard = require "ui.ChapterCard"
local GameAudio = require "audio.GameAudio"
local MediaPlayer = require "media.MediaPlayer"
local VideoSpike = require "experiments.VideoSpike"
local UI = require "urhox-libs/UI"

---@type Scene|nil
local scene_ = nil

-- ============================================================================
-- 单机模式校验
-- ============================================================================

--- 读取开发环境项目设置。发布包不携带 .project 工作区目录，
--- 发布模式由框架注入的 IsNetworkMode() 校验。
---@return table|nil settings, string|nil err, string|nil source
local function ReadProjectSettings()
    if not fileSystem:FileExists(".project/settings.json") then
        return nil, "workspace_config_unavailable", "runtime"
    end
    local file = File(".project/settings.json", FILE_READ)
    if file == nil or not file:IsOpen() then
        return nil, "unreadable", ".project/settings.json"
    end
    local content = file:ReadString()
    file:Close()
    if content == nil or content == "" then
        return nil, "empty", ".project/settings.json"
    end
    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then
        return nil, "bad_json", ".project/settings.json"
    end
    return data, nil, ".project/settings.json"
end

--- 校验单机模式：配置可用时严格读取配置；发布包无工作区配置时由框架判断。
---@return boolean
function ValidateSinglePlayerConfig()
    local settings, err, source = ReadProjectSettings()
    if settings == nil then
        if err == "workspace_config_unavailable" then
            if IsNetworkMode() then
                print("[main] 错误：发布运行时处于联网模式，本作必须为单机，退出")
                engine:Exit()
                return false
            end
            print("[main] 单机模式校验通过 | source=IsNetworkMode() | networkMode=false")
            return true
        end
        print("[main] 错误：项目设置 " .. tostring(source) .. " " .. tostring(err) .. "，退出")
        engine:Exit()
        return false
    end

    local runtime = settings["@runtime"]
    local mp = type(runtime) == "table" and runtime.multiplayer or nil
    if type(mp) ~= "table" or type(mp.enabled) ~= "boolean" then
        print("[main] 错误：" .. tostring(source) .. " 缺少明确的 @runtime.multiplayer.enabled，退出")
        engine:Exit()
        return false
    end
    if mp.enabled ~= false then
        print("[main] 错误：multiplayer.enabled 必须为 false，退出")
        engine:Exit()
        return false
    end

    print("[main] 单机模式校验通过 | source=" .. tostring(source) .. " | multiplayer.enabled=false")
    return true
end

function ConfigurePortraitOrientation()
    graphics:SetOrientations("Portrait")
    print("[main] 竖屏方向请求: Portrait | 当前方向配置: "
        .. tostring(graphics:GetOrientations()))
    print("[main] 画面尺寸: " .. tostring(graphics:GetWidth()) .. "x"
        .. tostring(graphics:GetHeight()) .. " | DPR=" .. tostring(graphics:GetDPR()))
end

-- 真机触屏入口：S9 发布前移除。Spike 运行时会暂时接管 UI 根节点，结束后恢复此根节点。
local function CreateVideoSpikeTrigger()
    local root = UI.GetRoot()
    if root == nil then
        root = UI.Panel {
            width = "100%",
            height = "100%",
            pointerEvents = "box-none",
        }
        UI.SetRoot(root)
    end

    local trigger = UI.Button {
        text = "Spike",
        variant = "secondary",
        position = "absolute",
        top = 12,
        left = 192,
        width = 82,
        height = 38,
        fontSize = 14,
        onClick = function()
            print("[main] 触屏：视频生命周期 Spike")
            VideoSpike.Toggle()
        end,
    }
    root:AddChild(trigger)

    local breakpointTrigger = UI.Button {
        text = "断点",
        variant = "secondary",
        position = "absolute",
        top = 12,
        left = 102,
        width = 82,
        height = 38,
        fontSize = 14,
        onClick = function()
            print("[main] 触屏：视频断点测试 Hook")
            MediaPlayer.ToggleBreakpointTest()
        end,
    }
    root:AddChild(breakpointTrigger)

    -- F10 直切 S6 记忆印证链（ch3/P31）触屏入口：S9 前移除
    local s6Trigger = UI.Button {
        text = "S6链",
        variant = "secondary",
        position = "absolute",
        top = 12,
        left = 12,
        width = 82,
        height = 38,
        fontSize = 14,
        onClick = function()
            print("[main] 触屏：直切 S6 记忆印证链（ch3/P31）")
            MainMenu.Close()
            MediaPlayer.Stop(true)
            FlowController.DebugJumpToParagraph("P31")
        end,
    }
    root:AddChild(s6Trigger)

    -- F5 强制完成当前段落触屏入口：S9 前移除
    local forceCompleteTrigger = UI.Button {
        text = "完成",
        variant = "secondary",
        position = "absolute",
        top = 58,
        left = 12,
        width = 82,
        height = 38,
        fontSize = 14,
        onClick = function()
            print("[main] 触屏：强制完成当前段落")
            FlowController.DebugForceComplete()
        end,
    }
    root:AddChild(forceCompleteTrigger)

    -- F8 保存触屏入口：S9 前移除
    local saveTrigger = UI.Button {
        text = "保存",
        variant = "secondary",
        position = "absolute",
        top = 58,
        left = 102,
        width = 82,
        height = 38,
        fontSize = 14,
        onClick = function()
            print("[main] 触屏：保存当前进度到 slot1")
            FlowController.Persist()
        end,
    }
    root:AddChild(saveTrigger)

    -- F9 读档续播触屏入口：S9 前移除
    local loadTrigger = UI.Button {
        text = "读档",
        variant = "secondary",
        position = "absolute",
        top = 58,
        left = 192,
        width = 82,
        height = 38,
        fontSize = 14,
        onClick = function()
            print("[main] 触屏：从 slot1 读档并续播")
            local loaded = PlayerData.Load()
            if loaded == nil then
                print("[main] 读档续播失败：无本地存档")
            else
                MediaPlayer.Stop(true)
                FlowController.Init(loaded)
                if not FlowController.Resume() then
                    FlowController.Start()
                end
            end
        end,
    }
    root:AddChild(loadTrigger)
    print("[main] 已创建左上角调试触屏入口：Spike(F6)/断点(F7)/S6链(F10)/完成(F5)/保存(F8)/读档(F9)（S9 前移除）")
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
    print("=== 桃素洛无幽·素女篇 启动（S2 对话会话） ===")

    -- 1. 单机模式校验（异常即退出）
    if not ValidateSinglePlayerConfig() then
        return
    end

    -- 2. 竖屏方向（发布元数据 + 运行时双层实测）
    ConfigurePortraitOrientation()

    -- 2. 输入抽象层
    InputManager.Initialize({ touchSensitivity = 2 })
    -- GameHUD 提供自己的触屏摇杆+触摸视角，关平台默认屏上摇杆避免双摇杆
    InputManager.DisableScreenJoystick()

    -- 3. UI 系统（对话/选项/字幕统一用 urhox-libs/UI）
    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })

    -- 3. 场景与玩家
    CreateScene()
    PlayerController.Create(scene_)
    SceneManager.Init(scene_, PlayerController)

    -- 4. 数据：启动只探测本地存档是否存在（供主菜单「继续游戏」），不再自动续档
    local data = PlayerData.Load()
    if data ~= nil then
        print("[main] 检测到本地存档，等待主菜单选择开始/继续")
    else
        data = PlayerData.Sanitize(nil)
    end
    CreateVideoSpikeTrigger()

    -- 场景名横幅（顶部居中，随场景切换更新；白模下辨识当前场景用）——S9 前可保留/移除
    local bannerPanel = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0,
        height = 60,
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "none",
        zIndex = 85,
    }
    local sceneBanner = UI.Label {
        text = "「朝阳谷口」",
        fontSize = 20,
        fontColor = { 255, 245, 230, 255 },
    }
    bannerPanel:AddChild(sceneBanner)
    UI.GetRoot():AddChild(bannerPanel)
    SceneManager.SetOnSceneLoaded(function(name)
        if sceneBanner ~= nil then
            sceneBanner:SetText("「" .. tostring(name) .. "」")
        end
    end)

    -- 存档/读档菜单（正式界面，把 F8/F9 做成菜单；S9 前保留）
    GameAudio.Init(scene_)
    SaveMenu.Create(UI.GetRoot())
    EndingScreen.Create(UI.GetRoot())
    ChapterCard.Create(UI.GetRoot())
    EndingScreen.SetOnReturn(function()
        MainMenu.Show()
    end)

    FlowController.Init(data)
    -- 结局段 → 弹出对应结局卡 + 制作名单（点返回再进主菜单）
    FlowController.SetOnGameEnd(function(endingKey)
        EndingScreen.Show(endingKey)
    end)
    -- 主菜单：由玩家选择"开始游戏 / 继续游戏"（不再启动即自动续档）
    MainMenu.Create(UI.GetRoot())
    MainMenu.Show()

    -- 6. 事件订阅
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    print("=== 启动完成 ===")
    print("操作：WASD/方向键 移动 | 鼠标 视角 | 空格 跳跃 | 竖屏 9:16 纵深布局")
    print("调试：F5 强制完成段落 | F6 视频生命周期 Spike | F7 视频断点测试 Hook | F8 保存 | F9 读档续播 | F10 直切 S6 记忆印证链 | F2/F3/F4 直切三场景 | ESC 退出")
end

function Stop()
    MediaPlayer.Stop(true)
    GameAudio.StopAll()
    InputManager.Shutdown()
    UI.Shutdown()
    print("[main] 停止")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 正式剧情视频：Widget 自身负责解码与回调，主循环负责会话冻结自愈
    if MediaPlayer.IsPlaying() then
        MediaPlayer.Update(timeStep)
    end

    -- 视频生命周期 Spike（实验模块）：激活时每帧驱动其计时器/状态机
    if VideoSpike.IsActive() then
        VideoSpike.Update(timeStep)
    end

    -- 对话/菜单打开时：只处理对应输入，玩家停移动（防串台）
    GameAudio.Tick()
    if ChapterCard.IsOpen() then
        ChapterCard.Update(timeStep)
    end

    if DialogueUI.IsOpen() or SaveMenu.IsOpen() or MainMenu.IsOpen() or EndingScreen.IsOpen() or ChapterCard.IsOpen() then
        PlayerController.ClearMovement()   -- 锁定移动（防 GameHUD 摇杆在对话/菜单/结局卡/章节卡中串台）
        if DialogueUI.IsOpen() then
            DialogueUI.HandleInput()
        end
    else
        PlayerController.Update(timeStep)
    end

    -- 调试快捷键
    if InputManager.IsKeyPress(KEY_F6) then
        print("[main] 调试：视频生命周期 Spike")
        VideoSpike.Toggle()
    end
    if InputManager.IsKeyPress(KEY_F7) then
        print("[main] 调试：视频断点测试 Hook")
        MediaPlayer.ToggleBreakpointTest()
    end
    if InputManager.IsKeyPress(KEY_F5) then
        FlowController.DebugForceComplete()
    end
    if InputManager.IsKeyPress(KEY_F8) then
        print("[main] 调试：保存当前进度到 slot1")
        FlowController.Persist()
    end
    if InputManager.IsKeyPress(KEY_F9) then
        print("[main] 调试：从 slot1 读档并续播")
        local loaded = PlayerData.Load()
        if loaded == nil then
            print("[main] 读档续播失败：无本地存档")
        else
            MediaPlayer.Stop(true)
            FlowController.Init(loaded)
            if not FlowController.Resume() then
                FlowController.Start()
            end
        end
    end
    if InputManager.IsKeyPress(KEY_F10) then
        print("[main] 调试：直切 S6 记忆印证链（ch3/P31）")
        MainMenu.Close()
        MediaPlayer.Stop(true)
        FlowController.DebugJumpToParagraph("P31")
    end
    if InputManager.IsKeyPress(KEY_F2) then
        print("[main] 调试：直切场景 chaoyang_gukou（流程状态不变）")
        MainMenu.Close()
        EndingScreen.Close()
        MediaPlayer.Stop(true)
        SceneManager.LoadScene("chaoyang_gukou")
        PlayerController.SetLook(180, -8)
    end
    if InputManager.IsKeyPress(KEY_F3) then
        print("[main] 调试：直切场景 gu_nei_taolin（流程状态不变）")
        MainMenu.Close()
        EndingScreen.Close()
        MediaPlayer.Stop(true)
        SceneManager.LoadScene("gu_nei_taolin")
        PlayerController.SetLook(180, -6)
    end
    if InputManager.IsKeyPress(KEY_F4) then
        print("[main] 调试：直切场景 luoshui_yinshan（流程状态不变）")
        MainMenu.Close()
        EndingScreen.Close()
        MediaPlayer.Stop(true)
        SceneManager.LoadScene("luoshui_yinshan")
        PlayerController.SetLook(160, -6)
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
