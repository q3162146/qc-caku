-- ====================================================================
-- network/Shared.lua
-- 共享常量/事件/工具
-- ====================================================================

local Shared = {}

-- 远程事件
Shared.EVENTS = {
    -- 客户端 → 服务器
    CLIENT_READY = "MC_ClientReady",
    BLOCK_ACTION = "MC_BlockAction",        -- 方块操作请求

    -- 服务器 → 客户端
    ASSIGN_PLAYER = "MC_AssignPlayer",      -- 分配玩家ID
    WORLD_SYNC = "MC_WorldSync",            -- 世界同步（种子 + 变更列表）
    BLOCK_CHANGED = "MC_BlockChanged",      -- 方块变化广播（运行时）
    PLAY_SOUND = "MC_PlaySound",            -- 音效播放
    PLAY_PARTICLE = "MC_PlayParticle",      -- 粒子效果
}

-- 节点变量名
Shared.VARS = {
    ENTITY_TYPE = "EntityType",     -- "player"
    PLAYER_ID = "PlayerId",
    PLAYER_NAME = "PlayerName",
    PLAYER_COLOR = "PlayerColor",
}

-- 方块操作类型
Shared.BLOCK_ACTION = {
    DESTROY = 1,
    PLACE = 2,
}

-- 服务器接收事件
Shared.SERVER_EVENTS = {
    Shared.EVENTS.CLIENT_READY,
    Shared.EVENTS.BLOCK_ACTION,
}

-- 客户端接收事件
Shared.CLIENT_EVENTS = {
    Shared.EVENTS.ASSIGN_PLAYER,
    Shared.EVENTS.WORLD_SYNC,
    Shared.EVENTS.BLOCK_CHANGED,
    Shared.EVENTS.PLAY_SOUND,
    Shared.EVENTS.PLAY_PARTICLE,
}

-- 注册函数（双方都需要注册所有事件）
function Shared.RegisterServerEvents()
    for _, eventName in ipairs(Shared.SERVER_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
    for _, eventName in ipairs(Shared.CLIENT_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

function Shared.RegisterClientEvents()
    for _, eventName in ipairs(Shared.SERVER_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
    for _, eventName in ipairs(Shared.CLIENT_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

-- 工具函数

-- 缓存连接标签（弱引用，connection 被 GC 时自动清理）
local connectionLabelCache_ = setmetatable({}, { __mode = "k" })

--- 获取连接的可读标签（用于日志/调试，不要用作 table key）
--- @param connection Connection
--- @return string|nil
function Shared.GetConnectionLabel(connection)
    if not connection then return nil end
    
    local cached = connectionLabelCache_[connection]
    if cached then return cached end
    
    local label = tostring(connection:GetAddress()) .. ":" .. tostring(connection:GetPort())
    connectionLabelCache_[connection] = label
    return label
end

return Shared
