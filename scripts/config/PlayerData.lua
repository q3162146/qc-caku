-- ============================================================================
-- config/PlayerData.lua
-- 《桃素洛无幽·素女篇》存档数据契约（快速开工包 ⑤ 原文）
--
-- 规则：固定字段、类型检查、默认值兜底；防老存档缺字段崩溃。
-- 所有跨段落状态（信念/线索/标记）写入共享 PlayerData，场景对象不持有。
-- ============================================================================

local PlayerData = {}

--- 存档结构版本：加载时校验，低版本走迁移/兜底
PlayerData.SCHEMA_VERSION = 2

--- 生成一份全新的默认 PlayerData
---@return table
function PlayerData.New()
    return {
        schemaVersion = PlayerData.SCHEMA_VERSION,           -- 存档结构版本
        belief = { reunion = 0, release = 0, legend = 0 },   -- 信念值（重逢/放手/传说）
        blossoms = {                                         -- 五行桃花（木火土金水）
            wood = false, fire = false, earth = false, metal = false, water = false,
        },
        memories = {},      -- 已解锁记忆片段
        journal = {},       -- 旅人札记条目
        flags = {},         -- 跨段落临时标记（喂水/陪坐/唤名 → 终局回声；章节解锁位）
        ending = "",        -- "reunion" / "release" / "legend"
        endingsSeen = {},   -- 结局收集（标题 0/3）
        playCount = 0,      -- 通关次数
        mediaPos = {        -- 媒体位置（读档/断点恢复契约；剧情视频播放/暂停时写入）
            node = "",      -- 当前段落 id（如 "P22"）
            video = "",     -- 当前视频 id（如 "S5"）
            breakpoint = 0, -- 断点序号（该视频第几个暂停点，从 1 起；0 = 非断点）
            timeSec = 0,    -- 精确时间（秒）
        },
    }
end

--- 存档兜底：类型检查 + 默认值填充
--- 老存档缺字段 / 字段类型错误时不会崩溃，回退到默认值。
---@param raw table|nil 从磁盘读出的原始存档
---@return table 清洗后的 PlayerData
function PlayerData.Sanitize(raw)
    local data = PlayerData.New()
    if type(raw) ~= "table" then
        print("[PlayerData] 存档为空或损坏，使用全新默认数据")
        return data
    end

    -- schemaVersion（当前版本不做迁移，仅记录）
    if type(raw.schemaVersion) == "number" then
        data.schemaVersion = raw.schemaVersion
    end

    -- belief：三个信念轴，只接受数字
    if type(raw.belief) == "table" then
        for axis in pairs(data.belief) do
            if type(raw.belief[axis]) == "number" then
                data.belief[axis] = raw.belief[axis]
            end
        end
    end

    -- blossoms：五行桃花，只接受布尔
    if type(raw.blossoms) == "table" then
        for key in pairs(data.blossoms) do
            if type(raw.blossoms[key]) == "boolean" then
                data.blossoms[key] = raw.blossoms[key]
            end
        end
    end

    -- map 型字段：memories / journal / endingsSeen
    for _, field in ipairs({ "memories", "journal", "endingsSeen" }) do
        if type(raw[field]) == "table" then
            local copy = {}
            for k, v in pairs(raw[field]) do
                if (type(k) == "string" or type(k) == "number")
                    and (type(v) == "boolean" or type(v) == "string" or type(v) == "number") then
                    copy[k] = v
                end
            end
            data[field] = copy
        end
    end

    -- flags：跨段落标记，只接受 string -> boolean/string/number 的映射
    if type(raw.flags) == "table" then
        for k, v in pairs(raw.flags) do
            if type(k) == "string" and (type(v) == "boolean" or type(v) == "string" or type(v) == "number") then
                data.flags[k] = v
            end
        end
    end

    -- ending / playCount
    if type(raw.ending) == "string" then data.ending = raw.ending end
    if type(raw.playCount) == "number" then data.playCount = raw.playCount end

    -- mediaPos：媒体恢复契约
    if type(raw.mediaPos) == "table" then
        local mp = raw.mediaPos
        if type(mp.node) == "string" then data.mediaPos.node = mp.node end
        if type(mp.video) == "string" then data.mediaPos.video = mp.video end
        if type(mp.breakpoint) == "number" then data.mediaPos.breakpoint = mp.breakpoint end
        if type(mp.timeSec) == "number" then data.mediaPos.timeSec = mp.timeSec end
    end

    return data
end

--- 拷贝 PlayerData（避免引用共享；JSON 序列化用 cjson，见 recipes/json.md）
---@param data table
---@return table
function PlayerData.Clone(data)
    return cjson.decode(cjson.encode(data))
end

return PlayerData
