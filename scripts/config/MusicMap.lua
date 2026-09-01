-- ============================================================================
-- config/MusicMap.lua
-- BGM 曲目映射：主菜单 / 三场景 / 结局。缺文件时 GameAudio 静默跳过。
-- ============================================================================

local MusicMap = {
    menu = "audio/music/bgm_theme.ogg",
    ending = "audio/music/bgm_ending.ogg",
    scene = {
        chaoyang_gukou = "audio/music/bgm_chaoyang.ogg",
        gu_nei_taolin = "audio/music/bgm_taolin.ogg",
        luoshui_yinshan = "audio/music/bgm_yinshan.ogg",
    },
}

return MusicMap
