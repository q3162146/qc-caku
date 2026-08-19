-- ====================================================================
-- utils/TempPool.lua
-- 临时对象池 - 避免频繁创建 Vector/Quaternion/Color 导致 GC 压力
-- ====================================================================

local TempPool = {}

-- 预分配的复用对象（单例模式，用于临时计算）
-- 注意：这些对象在使用后会被覆盖，不要持有引用
local tempVector3 = Vector3()
local tempVector2 = Vector2()
local tempQuaternion = Quaternion()
local tempColor = Color()

-- 对象池（用于需要持有引用的场景）
local vector3Pool = {}
local vector2Pool = {}
local vector3PoolIndex = 0
local vector2PoolIndex = 0

-- ====================================================================
-- 单例复用（最高效，适用于立即使用不持有的场景）
-- ====================================================================

---获取临时 Vector3（立即使用，不要持有引用）
---@param x number
---@param y number
---@param z number
---@return Vector3
function TempPool.tempVec3(x, y, z)
    tempVector3.x = x
    tempVector3.y = y
    tempVector3.z = z
    return tempVector3
end

---获取临时 Vector2（立即使用，不要持有引用）
---@param x number
---@param y number
---@return Vector2
function TempPool.tempVec2(x, y)
    tempVector2.x = x
    tempVector2.y = y
    return tempVector2
end

---获取临时 Quaternion（立即使用，不要持有引用）
---@param x number pitch 或 x 分量
---@param y number yaw 或 y 分量
---@param z number roll 或 z 分量
---@return Quaternion
function TempPool.tempQuat(x, y, z)
    -- 使用欧拉角设置（pitch, yaw, roll）
    tempQuaternion:FromEulerAngles(x, y, z)
    return tempQuaternion
end

---获取临时 Color（立即使用，不要持有引用）
---@param r number
---@param g number
---@param b number
---@param a number|nil 默认 1.0
---@return Color
function TempPool.tempColor(r, g, b, a)
    tempColor.r = r
    tempColor.g = g
    tempColor.b = b
    tempColor.a = a or 1.0
    return tempColor
end

-- ====================================================================
-- 对象池模式（适用于需要多个临时对象的场景）
-- ====================================================================

---重置对象池索引（在批量操作开始时调用）
function TempPool.resetPools()
    vector3PoolIndex = 0
    vector2PoolIndex = 0
end

---从池中获取 Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function TempPool.getVec3(x, y, z)
    vector3PoolIndex = vector3PoolIndex + 1
    local v = vector3Pool[vector3PoolIndex]
    if not v then
        v = Vector3()
        vector3Pool[vector3PoolIndex] = v
    end
    v.x = x
    v.y = y
    v.z = z
    return v
end

---从池中获取 Vector2
---@param x number
---@param y number
---@return Vector2
function TempPool.getVec2(x, y)
    vector2PoolIndex = vector2PoolIndex + 1
    local v = vector2Pool[vector2PoolIndex]
    if not v then
        v = Vector2()
        vector2Pool[vector2PoolIndex] = v
    end
    v.x = x
    v.y = y
    return v
end

---预热对象池（可选，减少首次使用时的分配）
---@param vec3Count number Vector3 预分配数量
---@param vec2Count number Vector2 预分配数量
function TempPool.warmup(vec3Count, vec2Count)
    for i = 1, vec3Count do
        if not vector3Pool[i] then
            vector3Pool[i] = Vector3()
        end
    end
    for i = 1, vec2Count do
        if not vector2Pool[i] then
            vector2Pool[i] = Vector2()
        end
    end
    print(string.format("[TempPool] Warmed up: %d Vector3, %d Vector2", vec3Count, vec2Count))
end

---获取池状态（调试用）
---@return table { vec3Used, vec3Total, vec2Used, vec2Total }
function TempPool.getStats()
    return {
        vec3Used = vector3PoolIndex,
        vec3Total = #vector3Pool,
        vec2Used = vector2PoolIndex,
        vec2Total = #vector2Pool
    }
end

return TempPool
