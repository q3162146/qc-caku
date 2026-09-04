-- ============================================================================
-- ui/GameGuide.lua
-- 游戏指引：P02 首次操作提示 + 主菜单常驻游戏说明。
-- ============================================================================

local UI = require "urhox-libs/UI"
local PlayerData = require "config.PlayerData"

local GameGuide = {}

---@type Panel|nil
local introRoot_ = nil
---@type Modal|nil
local helpModal_ = nil
---@type table|nil
local currentData_ = nil
---@type number
local introRemain_ = 0.0
---@type number
local introOpacity_ = 0.0
---@type boolean
local introFading_ = false

local INTRO_FADE_IN = 0.2
local INTRO_HOLD = 3.0
local INTRO_FADE_OUT = 0.45

local function SetIntroOpacity(value)
    introOpacity_ = value
    if introRoot_ ~= nil then
        introRoot_:SetStyle({ opacity = value })
    end
end

---@param uiRoot Widget
---@return boolean
function GameGuide.Create(uiRoot)
    if uiRoot == nil then return false end
    if introRoot_ ~= nil then return true end

    introRoot_ = UI.Panel {
        id = "gameGuideIntro",
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 99,
        visible = false,
        opacity = 0,
        backgroundColor = { 16, 14, 24, 190 },
        justifyContent = "center",
        alignItems = "center",
        onClick = function()
            GameGuide.Hide()
        end,
    }

    local introCard = UI.Panel {
        width = "80%",
        maxWidth = 560,
        padding = 24,
        backgroundColor = { 24, 20, 30, 235 },
        borderRadius = 18,
        borderWidth = 1,
        borderColor = { 220, 190, 145, 120 },
        boxShadow = {
            { x = 0, y = 8, blur = 24, spread = 0, color = { 0, 0, 0, 90 } },
        },
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "操作提示",
                fontSize = 26,
                fontColor = { 246, 241, 231, 255 },
                textAlign = "center",
                width = "100%",
                marginBottom = 16,
            },
            UI.Label {
                text = "左下摇杆 · 移动\n滑动屏幕 · 转动视角\n走近发光桃花/守桃老人 · 交互",
                fontSize = 23,
                lineHeight = 1.5,
                fontColor = { 255, 248, 236, 255 },
                textAlign = "center",
                whiteSpace = "normal",
                width = "100%",
            },
            UI.Label {
                text = "点击任意处关闭",
                fontSize = 14,
                fontColor = { 200, 185, 160, 255 },
                textAlign = "center",
                width = "100%",
                marginTop = 18,
            },
        },
    }
    introRoot_:AddChild(introCard)
    uiRoot:AddChild(introRoot_)

    local scroll = UI.ScrollView {
        width = "100%",
        height = 330,
        scrollY = true,
        showScrollbar = true,
        scrollbarInteractive = true,
        backgroundColor = { 18, 16, 22, 100 },
        borderRadius = 10,
        padding = 14,
    }
    local content = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 12,
        paddingBottom = 8,
    }
    -- 悬疑钩子 + 约定引言：先抓人，再点题。
    content:AddChild(UI.Label {
        text = "你是否好奇？为何春天的桃花，总是那么让人心动？因为桃花，总是伴随着许多故事。\n青丘之外，朝阳谷口，一个女子用十二年守候，只等春风再度拂起、满山桃花香时的那一个约定。",
        fontSize = 16,
        lineHeight = 1.5,
        fontColor = { 200, 185, 160, 255 },
        whiteSpace = "normal",
        width = "100%",
    })
    content:AddChild(UI.Divider { color = { 210, 176, 128, 90 }, spacing = 2 })
    content:AddChild(UI.Label {
        text = "操作",
        fontSize = 20,
        fontColor = { 246, 241, 231, 255 },
        width = "100%",
    })
    content:AddChild(UI.Label {
        text = "左下摇杆移动\n滑动屏幕转动视角",
        fontSize = 17,
        lineHeight = 1.45,
        fontColor = { 246, 241, 231, 255 },
        whiteSpace = "normal",
        width = "100%",
    })
    content:AddChild(UI.Divider { color = { 210, 176, 128, 90 }, spacing = 2 })
    content:AddChild(UI.Label {
        text = "玩法",
        fontSize = 20,
        fontColor = { 246, 241, 231, 255 },
        width = "100%",
    })
    content:AddChild(UI.Label {
        text = "走近发光桃花可采，集齐五行桃花；走近守桃老人会触发对白。三选会影响故事走向与信念，不同选择将导向不同结局。",
        fontSize = 17,
        lineHeight = 1.45,
        fontColor = { 246, 241, 231, 255 },
        whiteSpace = "normal",
        width = "100%",
    })
    content:AddChild(UI.Divider { color = { 210, 176, 128, 90 }, spacing = 2 })
    content:AddChild(UI.Label {
        text = "存档与故事",
        fontSize = 20,
        fontColor = { 246, 241, 231, 255 },
        width = "100%",
    })
    content:AddChild(UI.Label {
        text = "游戏会自动存档，随时可从主菜单「继续游戏」继续。\n《桃素洛无幽·素女篇》——一个关于等待、遗忘与重逢的故事。",
        fontSize = 17,
        lineHeight = 1.45,
        fontColor = { 246, 241, 231, 255 },
        whiteSpace = "normal",
        width = "100%",
    })
    scroll:AddChild(content)

    helpModal_ = UI.Modal {
        title = "游戏说明",
        size = "md",
        closeOnOverlay = true,
        closeOnEscape = true,
        showCloseButton = true,
        backgroundColor = { 28, 24, 20, 245 },
        borderColor = { 120, 90, 55, 255 },
        titleTextColor = { 235, 200, 120, 255 },
        titleFontSize = 20,
        borderRadius = 16,
        contentPadding = 16,
    }
    helpModal_:AddContent(scroll)
    uiRoot:AddChild(helpModal_)
    print("[GameGuide] 游戏指引已创建")
    return true
end

---@param data table
function GameGuide.SetData(data)
    currentData_ = data
end

---@param data table|nil 当前 PlayerData
---@return boolean 是否显示了首次提示
function GameGuide.ShowIntro(data)
    if introRoot_ == nil or type(data) ~= "table" or data.tutorial_seen == true then
        return false
    end
    currentData_ = data
    data.tutorial_seen = true
    PlayerData.Save(data)
    introRemain_ = INTRO_HOLD
    introFading_ = false
    introRoot_:SetVisible(true)
    SetIntroOpacity(0.0)
    print("[GameGuide] 首次进入 P02，显示操作提示")
    return true
end

function GameGuide.Hide()
    if introRoot_ == nil or not introRoot_:IsVisible() then return end
    introRemain_ = 0.0
    introFading_ = true
end

---@param dt number
function GameGuide.Update(dt)
    if introRoot_ == nil or not introRoot_:IsVisible() then return end
    if introFading_ then
        local nextOpacity = introOpacity_ - dt / INTRO_FADE_OUT
        if nextOpacity <= 0.0 then
            SetIntroOpacity(0.0)
            introRoot_:SetVisible(false)
            introFading_ = false
        else
            SetIntroOpacity(nextOpacity)
        end
        return
    end

    if introOpacity_ < 1.0 then
        SetIntroOpacity(math.min(1.0, introOpacity_ + dt / INTRO_FADE_IN))
    end
    introRemain_ = introRemain_ - dt
    if introRemain_ <= 0.0 then
        GameGuide.Hide()
    end
end

function GameGuide.ShowHelp()
    if helpModal_ == nil then return end
    helpModal_:Open()
    print("[GameGuide] 打开游戏说明")
end

function GameGuide.HideHelp()
    if helpModal_ ~= nil then
        helpModal_:Close()
    end
end

---@return boolean
function GameGuide.IsOpen()
    local introOpen = introRoot_ ~= nil and introRoot_:IsVisible()
    local helpOpen = helpModal_ ~= nil and helpModal_:IsOpen()
    return introOpen or helpOpen
end

return GameGuide
