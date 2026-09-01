-- ============================================================================
-- ui/ChapterCard.lua
-- 切章：整屏应景场景底 + 中间水墨卡（印章/题跋保留）。
-- ============================================================================

local UI = require "urhox-libs/UI"
local GameAudio = require "audio.GameAudio"

local ChapterCard = {}

-- ④ 章节卡整屏应景底改用 D1 水墨全景（场景_*.png 为白模氛围截图，已弃用）
local CARDS = {
    ch0 = {
        image = "image/章节卡/ch0_桃花谷口.png",
        scene = "image/backdrop_chaoyang_20260831015902.png",
        title = "楔子 · 桃花谷口",
        seal = "木",
    },
    ch1 = {
        -- 真机修复 ③：原 ch1 卡图为灰蓝雾山与朝阳谷剧情地点不符 → 换暖金桃谷版（标题/印章不变）
        image = "image/章节卡/ch1_春信至_暖.png",
        scene = "image/backdrop_chaoyang_20260831015902.png",
        title = "收集 · 朝阳之谷",
        seal = "火",
    },
    ch2 = {
        image = "image/章节卡/ch4_洛水阴.png",
        scene = "image/backdrop_yinshan_20260831015900.png",
        title = "第四回 · 洛水阴，无面泪",
        seal = "水",
    },
    ch3 = {
        image = "image/章节卡/ch5_记忆印.png",
        scene = "image/backdrop_yinshan_20260831015900.png",
        title = "第五回 · 记忆印，六艺寻",
        seal = "金",
    },
    ch4 = {
        image = "image/章节卡/ch6_无涕桃.png",
        scene = "image/backdrop_chaoyang_20260831015902.png",
        title = "尾声 · 无涕桃，人面何处",
        seal = "人面不知何处去，桃花依旧笑春风",
    },
}

---@type Panel|nil
local root_ = nil
---@type Panel|nil
local sceneBg_ = nil
---@type Panel|nil
local art_ = nil
---@type Label|nil
local titleLabel_ = nil
---@type Label|nil
local sealLabel_ = nil
---@type function|nil
local onHidden_ = nil
---@type number
local remain_ = 0

-- 真机修复 ③：淡入淡出过渡（opacity 驱动，避免背景"突然弹出"）
local FADE_IN_T = 0.35
local FADE_OUT_T = 0.35
local HOLD_T = 1.8          -- 全显后自动隐藏等待秒数
---@type "closed"|"in"|"hold"|"out"
local fadeState_ = "closed"
---@type number
local alpha_ = 0

local function setAlpha(a)
    alpha_ = a
    if root_ ~= nil then
        root_:SetStyle({ opacity = a })
    end
end

--- 进入淡出（隐藏动画），完成后才 SetVisible(false) + 回调
local function beginFadeOut()
    if fadeState_ == "out" or fadeState_ == "closed" then return end
    fadeState_ = "out"
end

local function doHide()
    if root_ ~= nil then
        root_:SetVisible(false)
    end
    remain_ = 0
    fadeState_ = "closed"
    setAlpha(0)
    local cb = onHidden_
    onHidden_ = nil
    if cb ~= nil then cb() end
end

---@param uiRoot Widget
---@return boolean
function ChapterCard.Create(uiRoot)
    if root_ ~= nil then return true end
    if uiRoot == nil then return false end
    root_ = UI.Panel {
        id = "chapterCard",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 98,
        visible = false,
    }
    sceneBg_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 18, 12, 10, 80 },
    }
    local dim = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 12, 8, 6, 90 },
        pointerEvents = "none",
    }
    local card = UI.Panel {
        width = "86%",
        maxWidth = 420,
        flexDirection = "column",
        alignItems = "center",
        alignSelf = "center",
        marginTop = "10%",
        gap = 10,
        padding = 12,
        backgroundColor = { 28, 22, 18, 210 },
        borderRadius = 16,
        borderWidth = 1,
        borderColor = { 210, 176, 128, 90 },
    }
    art_ = UI.Panel {
        width = "100%",
        height = 360,
        borderRadius = 10,
        backgroundColor = { 30, 26, 24, 255 },
    }
    titleLabel_ = UI.Label {
        text = "",
        fontSize = 20,
        fontColor = { 246, 241, 231, 255 },
        textAlign = "center",
        width = "100%",
    }
    sealLabel_ = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = { 190, 160, 130, 255 },
        textAlign = "center",
        width = "100%",
        maxLines = 2,
        whiteSpace = "normal",
    }
    card:AddChild(art_)
    card:AddChild(titleLabel_)
    card:AddChild(sealLabel_)
    card:AddChild(UI.Button {
        text = "继续 ›",
        variant = "primary",
        width = "100%",
        height = 46,
        onClick = function()
            GameAudio.PlaySfx("audio/sfx/sfx_ui_confirm.mp3")
            beginFadeOut()   -- 淡出过渡后再隐藏（不再硬切）
        end,
    })
    root_:AddChild(sceneBg_)
    root_:AddChild(dim)
    root_:AddChild(card)
    uiRoot:AddChild(root_)
    print("[ChapterCard] 已创建章节卡")
    return true
end

---@param chapterId string
---@param onHidden function|nil
function ChapterCard.Show(chapterId, onHidden)
    if root_ == nil then
        if onHidden ~= nil then onHidden() end
        return
    end
    local info = CARDS[chapterId] or CARDS.ch0
    if sceneBg_ ~= nil then
        sceneBg_:SetStyle({ backgroundImage = info.scene })
    end
    if art_ ~= nil then
        art_:SetStyle({ backgroundImage = info.image })
    end
    if titleLabel_ ~= nil then titleLabel_:SetText(info.title) end
    if sealLabel_ ~= nil then sealLabel_:SetText(info.seal) end
    onHidden_ = onHidden
    remain_ = HOLD_T
    root_:SetVisible(true)
    fadeState_ = "in"
    setAlpha(0)   -- 从全透起步淡入
    GameAudio.PlaySfx("audio/sfx/sfx_bell.mp3", 0.6)
    print("[ChapterCard] 显示 " .. tostring(chapterId) .. " | " .. info.title)
end

function ChapterCard.Hide()
    beginFadeOut()
end

---@return boolean
function ChapterCard.IsOpen()
    return root_ ~= nil and root_:IsVisible()
end

---@param dt number
function ChapterCard.Update(dt)
    if fadeState_ == "closed" then return end

    if fadeState_ == "in" then
        local a = alpha_ + dt / FADE_IN_T
        if a >= 1 then
            setAlpha(1)
            fadeState_ = "hold"
        else
            setAlpha(a)
        end
    elseif fadeState_ == "hold" then
        if remain_ > 0 then
            remain_ = remain_ - dt
            if remain_ <= 0 then
                beginFadeOut()   -- 自动淡出
            end
        end
    elseif fadeState_ == "out" then
        local a = alpha_ - dt / FADE_OUT_T
        if a <= 0 then
            doHide()
        else
            setAlpha(a)
        end
    end
end

return ChapterCard
