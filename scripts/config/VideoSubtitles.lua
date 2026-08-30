-- ============================================================================
-- config/VideoSubtitles.lua
-- 剧情视频字幕 + 章回名。键 = videoId（S1 / S6-1 / S7 …）。
-- 值：{ title, cues = { { at, text }, ... } }；未配则 MediaPlayer 静默。
-- 时长按 15s 正式片分段，at 为该句开始秒。
-- ============================================================================

local DialogueData = require "config.DialogueData"

local VideoSubtitles = {}

---@param linesKey string
---@return {at:number, text:string}[]
local function cuesFromDialogue(linesKey)
    local spec = DialogueData.Get(linesKey)
    if spec == nil or spec.lines == nil then return {} end
    local n = #spec.lines
    if n == 0 then return {} end
    local cues = {}
    local span = 15.0 / n
    for i = 1, n do
        cues[#cues + 1] = { at = (i - 1) * span, text = spec.lines[i] }
    end
    return cues
end

local DATA = {
    S1 = {
        title = "楔子 · 桃花谷口",
        cues = {
            { at = 0.0, text = "青丘国以南，往西，夷山下有一谷，名唤朝阳。" },
            { at = 6.5, text = "谷口桃花终年不落。" },
            { at = 10.5, text = "村里人却说，这里藏着一个等了十二年的故事。" },
        },
    },
    S2 = {
        title = "第一回 · 春信至，药师别妻",
        cues = cuesFromDialogue("legend_part1"),
    },
    S3 = {
        title = "第二回 · 十二载，桃花不谢",
        cues = cuesFromDialogue("legend_part2"),
    },
    S4 = {
        title = "第三回 · 春风起，一夜飘零",
        cues = cuesFromDialogue("legend_part3"),
    },
    S5 = {
        title = "第四回 · 洛水阴，无面泪",
        cues = {
            { at = 0.0, text = "他蜷坐在山泉边，混着血与泪饮下山泉。" },
            { at = 7.0, text = "眼窝处微光一闪，随即又黯淡下去。" },
        },
    },
    ["S6-1"] = {
        title = "第五回 · 记忆印，六艺寻 · 礼",
        cues = {
            { at = 0.0, text = "临行那日，素女站在谷口，没有伸手拦他。" },
            { at = 7.0, text = "记忆没有对错，只有你愿意相信的样子。" },
        },
    },
    ["S6-2"] = {
        title = "第五回 · 记忆印，六艺寻 · 乐",
        cues = {
            { at = 0.0, text = "琴声落进水里，像桃花落在水面。" },
            { at = 7.0, text = "那曲琴声，听成了什么？" },
        },
    },
    ["S6-3"] = {
        title = "第五回 · 记忆印，六艺寻 · 射",
        cues = {
            { at = 0.0, text = "一支箭穿过桃花枝。准，还是不准？" },
            { at = 7.0, text = "花落的样子，比靶心更难忘。" },
        },
    },
    ["S6-4"] = {
        title = "第五回 · 记忆印，六艺寻 · 御",
        cues = {
            { at = 0.0, text = "他回望谷口。那一眼，看见了什么？" },
            { at = 7.0, text = "素衣、空谷，还是满山的桃花。" },
        },
    },
    ["S6-5"] = {
        title = "第五回 · 记忆印，六艺寻 · 书数",
        cues = {
            { at = 0.0, text = "药方上添的那一味——当归，还是不归？" },
            { at = 7.0, text = "药方上有字，也有没写完的话。" },
        },
    },
    S7 = {
        title = "尾声 · 圆满 · 桃花又香",
        cues = {
            { at = 0.0, text = "春风再起。这一回，桃花不再只是替人守着念想。" },
            { at = 6.0, text = "无幽：素女。" },
            { at = 9.5, text = "素女：你回来了。……桃花，果然香了。" },
        },
    },
    S8 = {
        title = "尾声 · 放手 · 无泪无悔",
        cues = {
            { at = 0.0, text = "谷口的桃花落成一条路。" },
            { at = 5.0, text = "素女从桃树下走出来，回望一眼。" },
            { at = 9.0, text = "转身走向山外。等待，终于可以结束。" },
            { at = 12.5, text = "无泪，亦无悔。" },
        },
    },
    S9 = {
        title = "尾声 · 传说 · 会有新的旅人",
        cues = {
            { at = 0.0, text = "故事讲完了……还会有新的旅人，来听新的版本。" },
            { at = 8.0, text = "这故事，你讲出了自己的版本。" },
        },
    },
}

---@param videoId string|nil
---@return table|nil { title:string, cues:table }
function VideoSubtitles.Get(videoId)
    if videoId == nil or videoId == "" then return nil end
    return DATA[videoId]
end

---@param videoId string|nil
---@param timeSec number|nil
---@return string|nil
function VideoSubtitles.CueAt(videoId, timeSec)
    local pack = VideoSubtitles.Get(videoId)
    if pack == nil or pack.cues == nil or timeSec == nil then return nil end
    local text = nil
    for i = 1, #pack.cues do
        local cue = pack.cues[i]
        if type(cue.at) == "number" and timeSec + 0.05 >= cue.at then
            text = cue.text
        end
    end
    return text
end

return VideoSubtitles
