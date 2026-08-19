-- ====================================================================
-- config/GameEvents.lua
-- 游戏事件定义 - 用于模块间解耦通信
-- ====================================================================

local GameEvents = {
    -- 方块事件
    BLOCK_CHANGED = "MC_BlockChanged",       -- 方块变化
    BLOCK_DESTROYED = "MC_BlockDestroyed",   -- 方块被破坏
    BLOCK_PLACED = "MC_BlockPlaced",         -- 方块被放置
    
    -- 玩家事件
    PLAYER_MOVED = "MC_PlayerMoved",         -- 玩家移动
    PLAYER_JUMPED = "MC_PlayerJumped",       -- 玩家跳跃
    PLAYER_BLOCK_SELECTED = "MC_BlockSelected", -- 玩家选择方块
    
    -- 区块事件
    CHUNK_LOADED = "MC_ChunkLoaded",         -- 区块加载
    CHUNK_UNLOADED = "MC_ChunkUnloaded",     -- 区块卸载
    CHUNK_DIRTY = "MC_ChunkDirty",           -- 区块需要重建
    
    -- 游戏状态
    GAME_PAUSED = "MC_GamePaused",           -- 游戏暂停
    GAME_RESUMED = "MC_GameResumed",         -- 游戏恢复
    DEBUG_TOGGLED = "MC_DebugToggled"        -- 调试模式切换
}

return GameEvents
