-- ============================================================================
-- ui/MainMenu.lua
-- 封面：素女立绘全屏底 + 标题叠字 + 底部按钮分层（去掉居中卡片）。
-- ============================================================================

local UI = require "urhox-libs/UI"
local PlayerData = require "config.PlayerData"
local FlowController = require "flow.FlowController"
local MediaPlayer = require "media.MediaPlayer"
local EndingScreen = require "ui.EndingScreen"
local GameAudio = require "audio.GameAudio"
local StoryPanel = require "ui.StoryPanel"
local GameGuide = require "ui.GameGuide"
local StoryReview = require "ui.StoryReview"

local MainMenu = {}

---@type table|nil
local root_ = nil
---@type table|nil
local continueBtn_ = nil
---@type function|nil
local onStartGame_ = nil

local function doStart()
    MediaPlayer.Stop(true)
    EndingScreen.Close()
    local fresh = PlayerData.Clear()
    FlowController.Init(fresh)
    FlowController.Start()
    MainMenu.Close()
    if onStartGame_ ~= nil then
        onStartGame_()
    end
end

local function doContinue()
    local loaded = PlayerData.Load()
    if loaded == nil then
        print("[MainMenu] 继续失败：无本地存档")
        return
    end
    MediaPlayer.Stop(true)
    EndingScreen.Close()
    FlowController.Init(loaded)
    if not FlowController.Resume() then
        FlowController.Start()
    end
    MainMenu.Close()
    if onStartGame_ ~= nil then
        onStartGame_()
    end
end

function MainMenu.Show()
    if root_ == nil then return end
    local hasSave = PlayerData.Load() ~= nil
    if continueBtn_ ~= nil then
        continueBtn_:SetVisible(hasSave)
        continueBtn_:SetDisabled(not hasSave)
    end
    root_:SetVisible(true)
    print("[MainMenu] 显示主菜单" .. (hasSave and "（有存档，可继续）" or "（无存档）"))
end

function MainMenu.Close()
    if root_ ~= nil then
        root_:SetVisible(false)
    end
end

---@return boolean
function MainMenu.Create(uiRoot)
    if root_ ~= nil then return true end
    if uiRoot == nil then return false end

    root_ = UI.Panel {
        id = "mainMenu",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 96,
        visible = false,
    }
    local dim = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 12, 8, 6, 88 },
        pointerEvents = "none",
    }
    local titleBlock = UI.Panel {
        position = "absolute",
        top = "5%",
        left = "6%",
        right = "6%",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "桃素洛无幽",
                fontSize = 44,
                fontColor = { 48, 32, 15, 255 },
                fontWeight = "bold",
                letterSpacing = 2,
                textAlign = "center",
                width = "100%",
                textStroke = { width = 2.4, color = { 255, 214, 142, 255 } },
            },
            UI.Label {
                text = "素女篇",
                fontSize = 30,
                fontColor = { 74, 50, 32, 255 },
                fontWeight = "bold",
                letterSpacing = 1.5,
                textAlign = "center",
                width = "100%",
                marginTop = 8,
                textStroke = { width = 1.8, color = { 255, 214, 142, 255 } },
            },
            UI.Label {
                text = "一个关于等待、遗忘与重逢的故事",
                fontSize = 20,
                -- 副题深棕/棕红 + 细浅米描边：浅底高对比、立体不发白。
                fontColor = { 140, 70, 35, 255 },
                fontWeight = "bold",
                letterSpacing = 0.8,
                textAlign = "center",
                width = "100%",
                marginTop = 16,
                textStroke = { width = 0.8, color = { 255, 246, 232, 160 } },
            },
        },
    }
    continueBtn_ = UI.Button {
        text = "继续游戏",
        variant = "secondary",
        width = "100%",
        height = StoryPanel.BTN_HEIGHT,
        marginTop = 10,
        onClick = function()
            GameAudio.PlaySfx("audio/sfx/sfx_ui_confirm.mp3")
            doContinue()
        end,
    }
    local guideBtn = UI.Button {
        text = "游戏说明",
        variant = "secondary",
        width = "100%",
        height = StoryPanel.BTN_HEIGHT,
        marginTop = 10,
        onClick = function()
            GameAudio.PlaySfx("audio/sfx/sfx_ui_click.mp3")
            GameGuide.ShowHelp()
        end,
    }
    local reviewBtn = UI.Button {
        text = "剧情回顾",
        variant = "secondary",
        width = "100%",
        height = StoryPanel.BTN_HEIGHT,
        marginTop = 10,
        onClick = function()
            GameAudio.PlaySfx("audio/sfx/sfx_ui_click.mp3")
            StoryReview.Show()
        end,
    }
    local actions = UI.Panel {
        position = "absolute",
        left = "8%",
        right = "8%",
        bottom = "8%",
        children = {
            UI.Button {
                text = "开始游戏",
                variant = "primary",
                width = "100%",
                height = 52,
                onClick = function()
                    GameAudio.PlaySfx("audio/sfx/sfx_ui_confirm.mp3")
                    doStart()
                end,
            },
            continueBtn_,
            guideBtn,
            reviewBtn,
        },
    }
    root_:AddChild(dim)
    root_:AddChild(titleBlock)
    root_:AddChild(actions)
    uiRoot:AddChild(root_)
    -- 封面素女立绘全屏底：挂树之后设 backgroundImage（创建/挂树前设置会丢失）
    root_:SetBackgroundImage("image/立绘/素女.jpg")
    print("[MainMenu] 已创建主菜单")
    return true
end

---@param cb function|nil
function MainMenu.SetOnStart(cb)
    onStartGame_ = cb
end

---@return boolean
function MainMenu.IsOpen()
    return root_ ~= nil and root_:IsVisible()
end

return MainMenu
