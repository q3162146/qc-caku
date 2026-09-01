-- ============================================================================
-- ui/EndingScreen.lua
-- 正式结局画面 + 制作名单：按 ending 键（round/release/legend）换标题与文案。
-- 一次建卡，Show 时只用 SetText/SetVisible 更新（UI 库 Widget 无 RemoveChild）。
-- ============================================================================

local UI = require "urhox-libs/UI"
local GameAudio = require "audio.GameAudio"

local EndingScreen = {}

---@type function|nil
local onReturn_ = nil   -- 返回主菜单回调（main 注入，避免与 MainMenu 循环 require）

local ENDING_COPY = {
    round = {
        title = "圆满 · 桃花又香",
        lines = {
            "春风再起。这一回，桃花不再只是替人守着念想。",
            "无幽：素女。",
            "素女：你回来了。……桃花，果然香了。",
        },
    },
    release = {
        title = "放手 · 无泪无悔",
        lines = {
            "谷口的桃花落成一条路。素女从桃树下走出来，回望一眼，转身走向山外。",
            "画外音（素女）：等待，终于可以结束。无泪，亦无悔。",
        },
    },
    legend = {
        title = "传说 · 会有新的旅人",
        lines = {
            "故事讲完了……还会有新的旅人，来听新的版本。",
            "这故事，你讲出了自己的版本。",
        },
    },
}

local CREDITS = {
    "《桃素洛无幽 · 素女篇》",
    "一个关于等待、遗忘与重逢的故事。",
    "文案与演出由 AI 辅助创作，",
    "感谢 Seedance 让桃花真的会落，让眼泪真的会流。",
}

local LINE_COUNT = 3

---@type Panel|nil
local root_ = nil
---@type Label|nil
local titleLabel_ = nil
---@type Label[]
local lineLabels_ = {}

local function doReturnToMenu()
    print("[EndingScreen] 返回主菜单")
    EndingScreen.Close()
    if onReturn_ ~= nil then
        onReturn_()
    end
end

--- 点「返回主菜单」后的回调（main 注入 MainMenu.Show）
---@param cb function|nil
function EndingScreen.SetOnReturn(cb)
    onReturn_ = cb
end

--- 显示对应结局卡（未知键回退 round）
---@param endingKey string|nil
function EndingScreen.Show(endingKey)
    if root_ == nil then return end
    local key = endingKey or "round"
    local copy = ENDING_COPY[key]
    if copy == nil then
        print("[EndingScreen] 未知结局键 " .. tostring(endingKey) .. "，回退 round")
        key = "round"
        copy = ENDING_COPY.round
    end
    if titleLabel_ ~= nil then
        titleLabel_:SetText(copy.title)
    end
    for i = 1, LINE_COUNT do
        local label = lineLabels_[i]
        if label ~= nil then
            local text = copy.lines[i]
            if text ~= nil and text ~= "" then
                label:SetText(text)
                label:SetVisible(true)
            else
                label:SetText("")
                label:SetVisible(false)
            end
        end
    end
    root_:SetVisible(true)
    GameAudio.PlaySfx("audio/sfx/sfx_ending_card.mp3")
    print("[EndingScreen] 显示结局卡 | key=" .. tostring(key) .. " | " .. tostring(copy.title))
end

function EndingScreen.Close()
    if root_ ~= nil then
        root_:SetVisible(false)
    end
end

---@return boolean
function EndingScreen.IsOpen()
    return root_ ~= nil and root_:IsVisible()
end

---@param uiRoot Widget
---@return boolean
function EndingScreen.Create(uiRoot)
    if root_ ~= nil then return true end
    if uiRoot == nil then return false end

    root_ = UI.Panel {
        id = "endingScreen",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        -- 氛围收口：底幕半透（原 245 近不透），让 3D 场景的结局落花透出（卡片自身不透保可读）
        backgroundColor = { 16, 14, 12, 170 },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 97,
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
        gap = 12,
        alignItems = "center",
    }

    titleLabel_ = UI.Label {
        text = "",
        fontSize = 22,
        fontColor = { 246, 241, 231, 255 },
        textAlign = "center",
        whiteSpace = "normal",
        width = "100%",
    }
    card:AddChild(titleLabel_)

    lineLabels_ = {}
    for i = 1, LINE_COUNT do
        local line = UI.Label {
            text = "",
            fontSize = 14,
            fontColor = { 210, 202, 190, 255 },
            textAlign = "center",
            whiteSpace = "normal",
            width = "100%",
            visible = false,
        }
        lineLabels_[i] = line
        card:AddChild(line)
    end

    card:AddChild(UI.Label {
        text = "— 制作名单 —",
        fontSize = 13,
        fontColor = { 190, 182, 170, 255 },
        marginTop = 8,
    })
    for i = 1, #CREDITS do
        card:AddChild(UI.Label {
            text = CREDITS[i],
            fontSize = 12,
            fontColor = { 168, 160, 148, 255 },
            textAlign = "center",
            whiteSpace = "normal",
            width = "100%",
        })
    end

    card:AddChild(UI.Button {
        text = "返回主菜单",
        variant = "primary",
        width = "100%",
        height = 50,
        marginTop = 8,
        onClick = function() doReturnToMenu() end,
    })

    root_:AddChild(card)
    uiRoot:AddChild(root_)
    print("[EndingScreen] 已创建结局画面")
    return true
end

return EndingScreen
