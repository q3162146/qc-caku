-- ============================================================================
-- ui/StoryReview.lua
-- 主菜单常驻剧情回顾：章回体完整剧情 + 可滚动阅读。
-- ============================================================================

local UI = require "urhox-libs/UI"
local StoryData = require "config.StoryReview"

local StoryReview = {}

---@type Modal|nil
local modal_ = nil

---@param uiRoot Widget
---@return boolean
function StoryReview.Create(uiRoot)
    if uiRoot == nil then return false end
    if modal_ ~= nil then return true end

    local scroll = UI.ScrollView {
        width = "100%",
        height = 430,
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
        gap = 10,
        paddingBottom = 12,
    }

    for index, chapter in ipairs(StoryData) do
        content:AddChild(UI.Label {
            text = chapter.title,
            fontSize = 20,
            fontColor = { 235, 200, 120, 255 },
            width = "100%",
            marginTop = index == 1 and 0 or 4,
        })
        content:AddChild(UI.Label {
            text = chapter.text,
            fontSize = 16,
            lineHeight = 1.55,
            fontColor = { 246, 241, 231, 255 },
            whiteSpace = "normal",
            width = "100%",
        })
        if index < #StoryData then
            content:AddChild(UI.Divider {
                color = { 210, 176, 128, 90 },
                spacing = 2,
            })
        end
    end

    scroll:AddChild(content)

    modal_ = UI.Modal {
        title = "剧情回顾",
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
        onClose = function()
            print("[StoryReview] 关闭剧情回顾")
        end,
    }
    modal_:AddContent(scroll)
    uiRoot:AddChild(modal_)
    print("[StoryReview] 剧情回顾已创建 | 章节数=" .. tostring(#StoryData))
    return true
end

function StoryReview.Show()
    if modal_ == nil then return end
    modal_:Open()
    print("[StoryReview] 打开剧情回顾")
end

function StoryReview.Hide()
    if modal_ ~= nil then
        modal_:Close()
    end
end

---@return boolean
function StoryReview.IsOpen()
    return modal_ ~= nil and modal_:IsOpen()
end

return StoryReview
