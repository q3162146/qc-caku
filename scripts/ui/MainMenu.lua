-- ============================================================================
-- ui/MainMenu.lua
-- 主菜单：标题 + 开始游戏 / 继续游戏（有存档才显示）。把"启动即自动续档"改为玩家主动选择。
-- 白模阶段单档 slot1；S9 前可保留为正式主菜单框架。
-- ============================================================================

local UI = require "urhox-libs/UI"
local PlayerData = require "config.PlayerData"
local FlowController = require "flow.FlowController"
local MediaPlayer = require "media.MediaPlayer"

local MainMenu = {}

---@type table|nil
local root_ = nil
---@type table|nil
local continueBtn_ = nil
---@type function|nil
local onStartGame_ = nil   -- 开始新游戏后的回调（main 注入，用于关闭媒体/场景等）

--- 开始新游戏（清档重置）
local function doStart()
    MediaPlayer.Stop(true)             -- 停掉结局/讲述残留媒体，避免与新开局串台
    local fresh = PlayerData.Clear()   -- 删除存档 + 全新默认数据
    FlowController.Init(fresh)
    FlowController.Start()
    MainMenu.Close()
    if onStartGame_ ~= nil then
        onStartGame_()
    end
end

--- 继续游戏（读档续播；与 F9 一致）
local function doContinue()
    local loaded = PlayerData.Load()
    if loaded == nil then
        print("[MainMenu] 继续失败：无本地存档")
        return
    end
    MediaPlayer.Stop(true)
    FlowController.Init(loaded)
    if not FlowController.Resume() then
        FlowController.Start()
    end
    MainMenu.Close()
    if onStartGame_ ~= nil then
        onStartGame_()
    end
end

--- 显示主菜单（若尚未创建则先建）
function MainMenu.Show()
    if root_ == nil then return end
    -- 有存档才显示"继续"
    local hasSave = PlayerData.Load() ~= nil
    if continueBtn_ ~= nil then
        continueBtn_:SetVisible(hasSave)
        continueBtn_:SetDisabled(not hasSave)
    end
    root_:SetVisible(true)
end

function MainMenu.Close()
    if root_ ~= nil then
        root_:SetVisible(false)
    end
end

---@return boolean 是否已创建
function MainMenu.Create(uiRoot)
    if root_ ~= nil then return true end
    if uiRoot == nil then return false end

    root_ = UI.Panel {
        id = "mainMenu",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 16, 14, 12, 245 },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 96,
        visible = false,
    }
    local card = UI.Panel {
        width = "84%",
        maxWidth = 420,
        backgroundColor = { 30, 26, 24, 250 },
        borderRadius = 16,
        paddingH = 22,
        paddingV = 24,
        flexDirection = "column",
        gap = 14,
        alignItems = "center",
    }
    card:AddChild(UI.Label {
        text = "桃素洛无幽 · 素女篇",
        fontSize = 26,
        fontColor = { 246, 241, 231, 255 },
    })
    card:AddChild(UI.Label {
        text = "一个关于等待、遗忘与重逢的故事",
        fontSize = 13,
        fontColor = { 190, 182, 170, 255 },
    })
    card:AddChild(UI.Button {
        text = "开始游戏",
        variant = "primary",
        width = "100%",
        height = 50,
        onClick = function() doStart() end,
    })
    continueBtn_ = UI.Button {
        text = "继续游戏",
        variant = "secondary",
        width = "100%",
        height = 50,
        onClick = function() doContinue() end,
    }
    card:AddChild(continueBtn_)
    root_:AddChild(card)
    uiRoot:AddChild(root_)

    print("[MainMenu] 已创建主菜单")
    return true
end

--- 开始/继续新游戏后的回调（main 注入）
---@param cb function|nil
function MainMenu.SetOnStart(cb)
    onStartGame_ = cb
end

---@return boolean
function MainMenu.IsOpen()
    return root_ ~= nil and root_:IsVisible()
end

return MainMenu