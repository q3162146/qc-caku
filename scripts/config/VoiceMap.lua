-- ============================================================================
-- config/VoiceMap.lua
-- 对话段 linesKey + 行号 → 配音路径。缺映射则 DialogueUI 静默。
-- ============================================================================

local VoiceMap = {}

local MAP = {
    oldman_greeting = { "audio/voice/oldman_greeting.ogg" },
    open_choice = { "audio/voice/oldman_open_choice.ogg" },
    legend_part1 = { "audio/voice/oldman_legend_part1.ogg" },
    legend_part2 = { "audio/voice/oldman_legend_part2.ogg" },
    legend_part3 = { "audio/voice/oldman_legend_part3.ogg" },
    quest_intro = { "audio/voice/oldman_quest_intro.ogg" },
    depart_guide = { "audio/voice/oldman_depart.ogg" },
    memory_guide = { "audio/voice/oldman_memory_guide.ogg" },
    offering_before = { "audio/voice/oldman_offering.ogg" },
    final_choice = { "audio/voice/narrator_final.ogg" },
    blossom_wood = { "audio/voice/sunu_blossom_wood.ogg" },
    blossom_fire = { "audio/voice/sunu_blossom_fire.ogg" },
    blossom_earth = { "audio/voice/sunu_blossom_earth.ogg" },
    blossom_metal = { "audio/voice/sunu_blossom_metal.ogg" },
    blossom_water = { "audio/voice/sunu_blossom_water.ogg" },
    noface_water = { "audio/voice/narrator_noface_water.ogg" },
    noface_sit = { "audio/voice/narrator_noface_sit.ogg" },
    noface_call = { "audio/voice/narrator_noface_call.ogg" },
}

---@param linesKey string|nil
---@param lineIndex number
---@return string|nil
function VoiceMap.Get(linesKey, lineIndex)
    if linesKey == nil then return nil end
    local rows = MAP[linesKey]
    if rows == nil then return nil end
    -- 只返回该行专属文件；整段单文件只在第 1 行返回，后续行 nil（不打断正在播的长配音）
    return rows[lineIndex]
end

return VoiceMap
