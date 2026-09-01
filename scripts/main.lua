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
local MainMenu = require "ui.MainMenu"
local EndingScreen = require "ui.EndingScreen"
local ChapterCard = require "ui.ChapterCard"
local GameAudio = require "audio.GameAudio"
local MediaPlayer = require "media.MediaPlayer"
local MusicMap = require "config.MusicMap"
local PetalRain = require "game.PetalRain"
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

--- 保证 HUD 持久根存在（对话层/章节卡/主菜单都挂这里，禁止后续 SetRoot 冲掉）
local function EnsureHudRoot()
    local root = UI.GetRoot()
    if root == nil then
        root = UI.Panel {
            width = "100%",
            height = "100%",
            pointerEvents = "box-none",
        }
        UI.SetRoot(root)
    end
    return root
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
    -- GameHUD 摇杆 + 滑动视角；关平台默认屏上摇杆，避免双摇杆/RunJump
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
    EnsureHudRoot()

    -- 发布 UI：只保留主菜单 / 章节卡 / 对白 / 结局卡；调试按钮、场景横幅、存档菜单入口已移除
    GameAudio.Init(scene_)
    EndingScreen.Create(UI.GetRoot())
    ChapterCard.Create(UI.GetRoot())
    EndingScreen.SetOnReturn(function()
        -- 结局回主菜单：恢复主题曲 + 落花氛围还原
        GameAudio.PlayMusic(MusicMap.menu)
        PetalRain.SetDense(false)
        MainMenu.Show()
    end)

    FlowController.Init(data)
    -- 结局段 → 弹出对应结局卡 + 制作名单（点返回再进主菜单）
    FlowController.SetOnGameEnd(function(endingKey)
        EndingScreen.Show(endingKey)
        -- 结局氛围：终章曲 + 落花加浓（更密更慢；场景落花关闭时也开浓档点缀）
        GameAudio.PlayMusic(MusicMap.ending)
        PetalRain.SetDense(true)
    end)
    -- 主菜单：由玩家选择"开始游戏 / 继续游戏"（不再启动即自动续档）
    MainMenu.Create(UI.GetRoot())
    MainMenu.Show()
    GameAudio.PlayMusic(MusicMap.menu)   -- 主菜单主题曲（缺文件静默）

    -- 6. 事件订阅
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    print("=== 启动完成 ===")
    print("操作：WASD/方向键 移动 | 鼠标 视角 | 空格 跳跃 | 竖屏 9:16 纵深布局")
    print("调试快捷键仍保留（画面无按钮）：F5 完成 | F7 断点 | F8 保存 | F9 读档 | F10 S6链 | F2/F3/F4 场景 | ESC 退出")
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

    -- 正式剧情视频：Widget 自身负责解码与回调，主循环负责会话冻结自愈。
    if MediaPlayer.IsPlaying() then
        MediaPlayer.Update(timeStep)
    end

    -- 对话/菜单打开时：只处理对应输入，玩家停移动（防串台）
    GameAudio.Tick(timeStep)      -- dt 驱动 BGM 换曲淡入淡出
    PetalRain.Update(timeStep)    -- 落花发射器跟随玩家 XZ
    if ChapterCard.IsOpen() then
        ChapterCard.Update(timeStep)
    end

    if DialogueUI.IsOpen() or MainMenu.IsOpen() or EndingScreen.IsOpen() or ChapterCard.IsOpen() then
        PlayerController.ClearMovement()  -- 锁定移动（防摇杆在对话/菜单/结局卡/章节卡中串台）
        if DialogueUI.IsOpen() then
            DialogueUI.HandleInput()
        end
    else
        PlayerController.Update(timeStep)
    end

    -- 调试快捷键（画面无按钮；真机无键盘无影响）
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
