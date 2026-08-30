-- ============================================================================
-- scripts/lifeplate/lp_scene.lua
-- 《命盘·改命》实验模块：独立场景 + 输入 + 落印交互
-- 不引用素女篇 game/SceneManager / PlayerController / InputManager。
-- ============================================================================

local UI = require "urhox-libs/UI"
local Config = require "lifeplate.lp_config"
local Rules = require "lifeplate.lp_rules"
local Panel = require "lifeplate.lp_panel"

local M = {}

---@type Scene|nil
local scene_ = nil
---@type Node|nil
local cameraNode_ = nil
---@type Node|nil
local soundNode_ = nil
---@type SoundSource|nil
local soundSrc_ = nil
---@type LPState|nil
local state_ = nil
---@type table|nil
local selectedChoice_ = nil
---@type boolean
local busy_ = false
---@type number
local busyLeft_ = 0
---@type table|nil
local pendingResult_ = nil
---@type Light|nil
local glowLight_ = nil

local function log(msg)
    print("[lp 模块][scene] " .. msg)
end

local function preload(kind, path)
    local res = cache:GetResource(kind, path)
    if res == nil then
        log("资源未找到 | kind=" .. kind .. " | path=" .. path)
        return nil
    end
    log("资源已加载 | kind=" .. kind .. " | path=" .. path)
    return res
end

local function playSfx(path, gain)
    if soundSrc_ == nil then return end
    local sound = cache:GetResource("Sound", path)
    if sound == nil then
        log("音效缺失 | " .. path)
        return
    end
    soundSrc_:Play(sound, 0, gain or 0.9)
end

local function vibrate(crossed)
    local host = rawget(_G, "sdk")
    if type(host) ~= "userdata" and type(host) ~= "table" then
        log("sdk 不可用，跳过震动")
        return
    end
    local ok, result = pcall(function()
        if crossed then
            return host:VibrateLong()
        end
        return host:VibrateShort("medium")
    end)
    log("震动 | crossed=" .. tostring(crossed) .. " | ok=" .. tostring(ok) .. " | result=" .. tostring(result))
end

local function makeUnlit(r, g, b)
    local mat = Material:new()
    local tech = cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml")
    if tech ~= nil then
        mat:SetTechnique(0, tech)
    end
    mat:SetShaderParameter("MatDiffColor", Variant(Vector4(r, g, b, 1)))
    return mat
end

--- 搭建命盘独立场景（暗室 + 印台 + 朱砂灯）
---@param scene Scene
function M.Build(scene)
    scene_ = scene

    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/DarkNight.xml")
    if lightGroupFile ~= nil then
        local lightGroup = scene:CreateChild("LPLightGroup")
        lightGroup:LoadXML(lightGroupFile:GetRoot())
        local zone = lightGroup:GetComponent("Zone", true)
        if zone ~= nil then
            zone.fogColor = Color(0.08, 0.07, 0.06)
            zone.fogStart = 8.0
            zone.fogEnd = 28.0
        end
        log("已加载 LightGroup/DarkNight.xml")
    else
        local lightNode = scene:CreateChild("LPDirLight")
        lightNode.direction = Vector3(0.4, -1.0, 0.5)
        local light = lightNode:CreateComponent("Light")
        light.lightType = LIGHT_DIRECTIONAL
        light.color = Color(0.55, 0.48, 0.42)
        light.brightness = 0.7
        log("LightGroup 不可用，回退定向光")
    end

    local root = scene:CreateChild("LPSceneRoot")

    -- 地面
    local floor = root:CreateChild("Floor")
    floor.position = Vector3(0, -0.05, 0)
    floor.scale = Vector3(12, 0.1, 12)
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    floorModel:SetMaterial(makeUnlit(0.12, 0.10, 0.09))

    -- 印台
    local tableNode = root:CreateChild("SealTable")
    tableNode.position = Vector3(0, 0.35, 0)
    tableNode.scale = Vector3(1.8, 0.7, 1.8)
    local tableModel = tableNode:CreateComponent("StaticModel")
    tableModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    tableModel:SetMaterial(makeUnlit(0.22, 0.12, 0.08))

    -- 圆形印面（3D 点缀，主交互在 UI）
    local disc = root:CreateChild("SealDisc")
    disc.position = Vector3(0, 0.78, 0)
    disc.scale = Vector3(1.2, 0.05, 1.2)
    local discModel = disc:CreateComponent("StaticModel")
    discModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    discModel:SetMaterial(makeUnlit(0.42, 0.12, 0.10))

    -- 朱砂点光
    local glowNode = root:CreateChild("VermilionGlow")
    glowNode.position = Vector3(0, 1.4, 0)
    glowLight_ = glowNode:CreateComponent("Light")
    glowLight_.lightType = LIGHT_POINT
    glowLight_.color = Color(0.85, 0.18, 0.12)
    glowLight_.range = 6.0
    glowLight_.brightness = 1.6
    glowLight_.castShadows = false

    cameraNode_ = scene:CreateChild("LPCamera")
    cameraNode_.position = Vector3(0, 2.2, -4.2)
    cameraNode_:LookAt(Vector3(0, 0.8, 0))
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 80.0
    camera.fov = 42.0
    renderer:SetViewport(0, Viewport:new(scene, camera))

    soundNode_ = scene:CreateChild("LPSound")
    soundSrc_ = soundNode_:CreateComponent("SoundSource")
    soundSrc_.soundType = SOUND_EFFECT

    preload("Texture2D", Config.ASSETS.sealFace)
    preload("Texture2D", Config.ASSETS.taiji)
    preload("Texture2D", Config.ASSETS.inkBg)
    preload("Sound", Config.ASSETS.qing)
    preload("Sound", Config.ASSETS.stamp)

    input.mouseMode = MM_ABSOLUTE
    input.mouseVisible = true
    log("命盘场景已搭建")
end

local function refreshPanel(extra)
    if state_ == nil then return end
    extra = extra or {}
    extra.charging = busy_ and pendingResult_ ~= nil and pendingResult_.anyCross
    extra.bursting = false
    extra.crossed = pendingResult_ and pendingResult_.crossed or nil
    Panel.Refresh(state_, extra)
end

local function beginGame()
    state_ = Rules.newState()
    selectedChoice_ = nil
    busy_ = false
    busyLeft_ = 0
    pendingResult_ = nil
    Panel.ClearSelection()
    refreshPanel()
    log("新开一局 | 天定 命" .. Config.HEAVEN.ming
        .. " 缘" .. Config.HEAVEN.yuan
        .. " 成" .. Config.HEAVEN.cheng)
    Panel.Toast("观盘：选一印，再落印", "info")
end

local function onSelectIndex(index)
    if state_ == nil or busy_ then return end
    if Rules.isFinished(state_) then return end
    local node = Rules.currentNode(state_)
    if node == nil then return end
    local choice = node.choices[index]
    if choice == nil then return end
    selectedChoice_ = choice
    Panel.SetSelectedKey(choice.key)
    log("选定 | age=" .. tostring(node.age) .. " | " .. choice.label .. " | " .. choice.hint)
    Panel.Toast(choice.hint, "info")
    refreshPanel()
end

local function stamp()
    if state_ == nil or busy_ then return end
    if Rules.isFinished(state_) then
        log("已终局，忽略落印")
        return
    end
    if selectedChoice_ == nil then
        Panel.Toast("先选一印，再落印", "warning")
        log("落印被拒：未选择")
        return
    end

    local node = Rules.currentNode(state_)
    local result = Rules.applyChoice(state_, selectedChoice_)
    pendingResult_ = result
    busy_ = true
    busyLeft_ = result.anyCross and 0.85 or 0.45

    log("落印 | node=" .. tostring(node and node.id)
        .. " | choice=" .. selectedChoice_.label
        .. " | 终值 命" .. result.after.ming
        .. " 缘" .. result.after.yuan
        .. " 成" .. result.after.cheng
        .. " | 功德 " .. result.virtueAfter
        .. " | 跨线=" .. tostring(result.anyCross))

    playSfx(Config.ASSETS.stamp, 0.85)
    playSfx(Config.ASSETS.qing, 0.7)
    vibrate(result.anyCross)
    Panel.PlayStampFeedback(result.anyCross)
    if glowLight_ ~= nil then
        glowLight_.brightness = result.anyCross and 4.2 or 2.4
    end

    if result.anyCross then
        local names = {}
        if result.crossed.ming then names[#names + 1] = "命" end
        if result.crossed.yuan then names[#names + 1] = "缘" end
        if result.crossed.cheng then names[#names + 1] = "成" end
        Panel.Toast("改命！" .. table.concat(names, "·") .. " 越平线", "success")
    else
        Panel.Toast("印已落 · 未越平线", "info")
    end

    selectedChoice_ = nil
    Panel.ClearSelection()
    refreshPanel()
end

local function finishIfNeeded()
    if state_ == nil then return end
    if not Rules.isFinished(state_) then
        refreshPanel()
        return
    end
    local ending = Rules.ending(state_, state_.virtue)
    Panel.Refresh(state_, { crossed = pendingResult_ and pendingResult_.crossed })
    Panel.ShowEnding(ending)
    playSfx(Config.ASSETS.qing, 1.0)
    log("终局 | key=" .. ending.key
        .. " | " .. ending.title
        .. " | 命" .. ending.finals.ming
        .. " 缘" .. ending.finals.yuan
        .. " 成" .. ending.finals.cheng
        .. " | 功德 " .. ending.virtue)
    Panel.Toast(ending.title, ending.key == "jie" and "warning" or "success")
end

function M.StartSession()
    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })
    Panel.Create()
    Panel.SetOnSelectIndex(onSelectIndex)
    Panel.SetOnStamp(stamp)
    Panel.SetOnRestart(function()
        log("再走一局")
        beginGame()
    end)
    beginGame()
end

---@param dt number
function M.Update(dt)
    Panel.Update(dt)
    if glowLight_ ~= nil then
        local target = 1.6
        local cur = glowLight_.brightness
        glowLight_.brightness = cur + (target - cur) * math.min(1, dt * 2.2)
    end
    if busy_ then
        busyLeft_ = busyLeft_ - dt
        if busyLeft_ <= 0 then
            busy_ = false
            finishIfNeeded()
            pendingResult_ = nil
        end
    end
end

function M.HandleInput()
    if input:GetKeyPress(KEY_ESCAPE) then
        log("ESC 退出实验")
        engine:Exit()
        return
    end
    if busy_ then return end
    if input:GetKeyPress(KEY_1) then onSelectIndex(1) end
    if input:GetKeyPress(KEY_2) then onSelectIndex(2) end
    if input:GetKeyPress(KEY_3) then onSelectIndex(3) end
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        stamp()
    end
end

function M.Shutdown()
    Panel.Destroy()
    UI.Shutdown()
    if scene_ ~= nil then
        scene_:Clear()
    end
    scene_ = nil
    cameraNode_ = nil
    soundNode_ = nil
    soundSrc_ = nil
    glowLight_ = nil
    state_ = nil
    log("命盘场景已关闭")
end

return M
