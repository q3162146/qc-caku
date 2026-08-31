-- ============================================================================
-- ui/StoryPanel.lua
-- 统一底部面板（对话台词 / 三选共用同一外壳）
-- 规格：宽 92%、底边约 3% 屏高、最小高度约 28%、圆角 16、暖棕灰半透明。
-- ============================================================================

local UI = require "urhox-libs/UI"

local StoryPanel = {}

StoryPanel.WIDTH = "92%"
StoryPanel.MIN_HEIGHT = "28%"
StoryPanel.BOTTOM = "3%"
StoryPanel.PADDING = 20
StoryPanel.RADIUS = 16
-- ③ 底条降透明：alpha 205→110，让水墨画面透出（文字加细描边保可读，见 DialogueUI）
StoryPanel.BG = { 32, 26, 20, 110 }
StoryPanel.BORDER = { 210, 176, 128, 90 }
StoryPanel.NAME_SIZE = 16
StoryPanel.LINE_SIZE = 24
StoryPanel.PROMPT_SIZE = 20
StoryPanel.NAME_COLOR = { 255, 214, 158, 255 }
StoryPanel.TEXT_COLOR = { 255, 248, 236, 255 }
StoryPanel.BTN_HEIGHT = 44

--- 按约 14 字/行切成最多 2 行的页（中文按字计，英文按空格）
---@param text string
---@return string[]
function StoryPanel.Paginate(text)
    local pages = {}
    if text == nil or text == "" then
        return { "" }
    end
    local chars = {}
    for _, c in utf8.codes(text) do
        chars[#chars + 1] = utf8.char(c)
    end
    local perLine = 14
    local perPage = perLine * 2
    local i = 1
    while i <= #chars do
        local chunk = table.concat(chars, "", i, math.min(#chars, i + perPage - 1))
        pages[#pages + 1] = chunk
        i = i + perPage
    end
    if #pages == 0 then pages[1] = text end
    return pages
end

---@param inner Widget[]
---@return Panel
function StoryPanel.Wrap(inner)
    return UI.Panel {
        position = "absolute",
        left = "4%",
        right = "4%",
        bottom = StoryPanel.BOTTOM,
        width = StoryPanel.WIDTH,
        minHeight = StoryPanel.MIN_HEIGHT,
        padding = StoryPanel.PADDING,
        backgroundColor = StoryPanel.BG,
        borderRadius = StoryPanel.RADIUS,
        borderWidth = 1,
        borderColor = StoryPanel.BORDER,
        children = inner,
    }
end

return StoryPanel
