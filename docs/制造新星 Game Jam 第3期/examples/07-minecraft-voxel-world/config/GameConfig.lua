-- ====================================================================
-- config/GameConfig.lua
-- 游戏配置模块 - 集中管理所有常量
-- ====================================================================

local GameConfig = {}

-- ============================================
-- 世界大小预设 (修改这里切换世界大小)
-- ============================================
local WORLD_SIZE_PRESET = "medium" -- 可选: "tiny", "small", "medium", "large", "huge"

local WorldSizePresets = {
    tiny   = { distance = 2, height = 64 },   -- 64×64,   25 区块  (测试用)
    small  = { distance = 4, height = 64 },   -- 128×128, 81 区块  (轻量)
    medium = { distance = 6, height = 80 },   -- 192×192, 169 区块 (推荐)
    large  = { distance = 8, height = 96 },   -- 256×256, 289 区块 (较大)
    -- 不推荐更大的地图了， 再大内存会超过1G，在网页和手机上会很危险了
}

local preset = WorldSizePresets[WORLD_SIZE_PRESET] or WorldSizePresets.medium

-- 世界设置
GameConfig.World = {
    CHUNK_SIZE = 16,                      -- 区块宽度/深度（方块数）
    WORLD_HEIGHT = preset.height,         -- 世界高度（方块数）
    RENDER_DISTANCE = preset.distance,    -- 各方向渲染区块数
    BLOCK_SIZE = 2.0,                     -- 方块世界单位大小
    WATER_LEVEL = math.floor(preset.height * 0.47),  -- 水平面高度（约47%高度）
    MAX_CHUNK_REBUILDS_PER_FRAME = 1      -- 每帧最大区块重建数（避免挖地卡顿）
}

-- 玩家设置
GameConfig.Player = {
    HEIGHT = 1.8,                 -- 玩家高度（方块数）
    SPEED = 8.0,                  -- 移动速度
    FLY_SPEED = 16.0,             -- 飞行速度
    FLY_VERTICAL_SPEED = 12.0,    -- 飞行上下速度
    JUMP_SPEED = 12.0,            -- 跳跃速度
    GRAVITY = -25.0,              -- 重力加速度
    REACH_DISTANCE = 10.0,        -- 方块交互距离
    COLLISION_RADIUS = 0.3        -- 碰撞半径
}

-- 控制设置
GameConfig.Controls = {
    MOUSE_SENSITIVITY = 0.1,          -- 鼠标灵敏度
    TOUCH_LOOK_SENSITIVITY = 0.15,    -- 触摸视角灵敏度
    TOUCH_TAP_MAX_DISTANCE = 10,      -- Tap 判定最大移动距离（设计像素）
    TOUCH_TAP_MAX_DURATION = 300,     -- Tap 判定最大时长（毫秒）
}

-- 粒子效果设置
GameConfig.Particles = {
    GRAVITY = -20.0,              -- 粒子重力
    LIFETIME = 1.5,               -- 粒子生命周期（秒）
    COUNT_MIN = 8,                -- 最小粒子数
    COUNT_MAX = 12                -- 最大粒子数
}

-- 纹理图集设置
GameConfig.Texture = {
    ATLAS_SIZE = 16,              -- 图集大小（16x16格）
    TILE_SIZE = 1.0 / 16          -- 每格UV大小
}

-- 噪声生成设置
GameConfig.Noise = {
    SEED = 12345                  -- 世界生成种子
}

-- 相机设置
GameConfig.Camera = {
    FAR_CLIP = 500.0,             -- 远裁剪面
    FOV = 90.0,                   -- 视野角度
    FOG_START = 50.0,             -- 雾效起始距离
    FOG_END = 300.0,              -- 雾效结束距离
    -- 第三人称相机设置
    THIRD_PERSON_DISTANCE = 4.0,  -- 第三人称相机距离（方块数）
    THIRD_PERSON_HEIGHT = 0.8,    -- 第三人称相机高度偏移（相机比眼睛高1.5方块，角色在屏幕下方）
    THIRD_PERSON_COLLISION = true -- 第三人称相机碰撞检测
}

-- 昼夜循环设置
GameConfig.DayNight = {
    ENABLED = false,              -- 是否启用昼夜循环（默认关闭）
    DAY_DURATION = 600,           -- 1 游戏天 = 600 真实秒 (10分钟)
    START_TIME = 7.0,             -- 游戏开始时间 (早上7点)
    TIME_SCALE = 1.0,             -- 时间流速倍率 (1.0 = 正常)
}

-- ============================================
-- 功能开关（渐进式功能，让 AI 帮你实现！）
-- ============================================
-- 提示：这些功能的代码框架已搭好，但实现是 TODO
-- 打开开关后，告诉 AI "帮我实现树木生成" 即可！
-- 
GameConfig.Features = {
    -- 世界装饰（需要 AI 实现 WorldGenerator.lua 中的 TODO）
    GENERATE_TREES = false,       -- 树木生成 → tryPlaceTree()
    GENERATE_VEGETATION = false,  -- 花草生成 → tryPlaceVegetation()
    SPAWN_HOUSE = false,          -- 出生小屋 → self.house:generateAtSpawn()
}

-- 视觉效果设置
GameConfig.Effects = {
    -- 窒息盒子：相机穿入固体方块时显示方块内部视图（穿墙保护）
    SUFFOCATION_BOX_ENABLED = false,
}

return GameConfig
