-- ============================================================================
-- ui/ChapterCard.lua
-- 切章时展示章节卡（图片 + 回目），约 1.8s 或点击关闭。一次建卡，Show 只改图/文。
-- ============================================================================

local UI = require "urhox-libs/UI"
local GameAudio = require "audio.GameAudio"

local ChapterCard = {}

local CARDS = {
    ch0 = { image = "image/章节卡/ch0_桃花谷口.png", title = "楔子 · 桃花谷口", seal = "木" },
    ch1 = { image = "image/章节卡/ch1_春信至.png", title = "第一回 · 春信至，药师别妻", seal = "火" },
    ch2 = { image = "image/章节卡/ch4_洛水阴.png", title = "第四回 · 洛水阴，无面泪", seal = "水" },
    -- 运行时章节 id：ch2=洛水阴，ch3=记忆印，ch4=尾声（一夜飘零卡留给讲述段视觉，不单独切章）
    ch3 = { image = "image/章节卡/ch5_记忆印.png", title = "第五回 · 记忆印，六艺寻", seal = "欲知后事如何" },
    ch4 = { image = "image/章节卡/ch6_无涕桃.png", title = "尾声 · 无涕桃，人面何处", seal = "人面不知何处去" },
}

---@type Panel|nil
local root_ = nil
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

local function doHide()
    if root_ ~= nil then
        root_:SetVisible(false)
    end
    remain_ = 0
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
        backgroundColor = { 8, 6, 8, 250 },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 98,
        visible = false,
    }
    local card = UI.Panel {
        width = "88%",
        maxWidth = 420,
        flexDirection = "column",
        alignItems = "center",
        gap = 10,
        padding = 12,
        backgroundColor = { 22, 18, 16, 250 },
        borderRadius = 14,
    }
    art_ = UI.Panel {
        width = "100%",
        height = 420,
        borderRadius = 10,
        backgroundColor = { 30, 26, 24, 255 },
    }
    titleLabel_ = UI.Label {
        text = "",
        fontSize = 18,
        fontColor = { 246, 241, 231, 255 },
        textAlign = "center",
        width = "100%",
    }
    sealLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontColor = { 190, 160, 130, 255 },
        textAlign = "center",
        width = "100%",
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
            doHide()
        end,
    })
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
    if art_ ~= nil then
        art_:SetStyle({ backgroundImage = info.image })
    end
    if titleLabel_ ~= nil then titleLabel_:SetText(info.title) end
    if sealLabel_ ~= nil then sealLabel_:SetText(info.seal) end
    onHidden_ = onHidden
    remain_ = 1.8
    root_:SetVisible(true)
    GameAudio.PlaySfx("audio/sfx/sfx_bell.mp3", 0.6)
    print("[ChapterCard] 显示 " .. tostring(chapterId) .. " | " .. info.title)
end

function ChapterCard.Hide()
    doHide()
end

---@return boolean
function ChapterCard.IsOpen()
    return root_ ~= nil and root_:IsVisible()
end

---@param dt number
function ChapterCard.Update(dt)
    if remain_ <= 0 then return end
    remain_ = remain_ - dt
    if remain_ <= 0 then
        doHide()
    end
end

return ChapterCard
