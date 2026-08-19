-- ====================================================================
-- world/DayNightCycle.lua
-- 昼夜循环系统 - 平滑过渡的日/夜光照变化
-- ====================================================================
--
-- 时段模型:
-- - 日出过渡 (5:00 - 7:00)   → night 插值到 day
-- - 白天稳定 (7:00 - 17:00)  → day 参数
-- - 日落过渡 (17:00 - 19:00) → day 插值到 night
-- - 夜晚稳定 (19:00 - 5:00)  → night 参数 (跨夜处理)
--
-- ====================================================================

---@class DayNightCycle
---@field dayDuration number
---@field fogStart number
---@field fogEnd number
---@field scene Scene
local DayNightCycle = {}
DayNightCycle.__index = DayNightCycle

-- ====================================================================
-- 光照参数定义 (简化为日/夜两套)
-- ====================================================================

-- 参数来自 LightGroup/Daytime.xml 和 Night.xml
-- 策略：日夜过渡时切换 LightGroup 预设，环境光/IBL/SH 随预设整套切换（在过渡中点跳变一次）；
--       太阳颜色/亮度、fogColor 这些 live 参数则逐帧平滑插值。
-- 注意：环境光不能在 Lua 层插值——引擎对 PBR/lit 硬下发 cAmbientColor=(0,0,0,0)（Batch.cpp），
--       zone.ambientColor 赋值是 no-op；环境光来自预设里烘焙的 SphericalHarmonicsL2 + Env Spec。
--       要更平滑可离线烘焙 Dawn.xml/Dusk.xml 中间预设，在过渡段切换多个预设逼近。
local LIGHT_PARAMS = {
    day = {
        -- LightGroup 预设名
        lightGroup = "Daytime",
        -- Zone 参数 (fogColor 可逐帧插值; ambientColor 由预设 SH 决定，无法 Lua 插值)
        fogColor = Color(0.5, 0.7, 1.0, 1),
        -- Light 参数
        sunColor = Color(1.0, 0.93, 0.9, 1),
        sunBrightness = 3.0,
    },
    night = {
        -- LightGroup 预设名
        lightGroup = "Night",
        -- Zone 参数 (fogColor 可逐帧插值; ambientColor 由预设 SH 决定，无法 Lua 插值)
        fogColor = Color(0.02, 0.05, 0.1, 1),
        -- Light 参数
        sunColor = Color(0.15, 0.42, 0.98, 1),  -- 月光蓝色
        sunBrightness = 0.8,
    },
}

-- ====================================================================
-- 构造函数
-- ====================================================================

---创建昼夜循环系统
---@param options table { scene, zone, sunLight, sunNode, lightGroup, startTime, dayDuration }
---@return DayNightCycle
function DayNightCycle.new(options)
    options = options or {}
    local self = setmetatable({}, DayNightCycle)
    
    -- 场景引用（用于切换 LightGroup）
    self.scene = options.scene
    self.lightGroup = options.lightGroup  -- 当前 LightGroup 节点
    
    -- 组件引用
    self.zone = options.zone
    self.sunLight = options.sunLight
    self.sunNode = options.sunNode
    
    -- 时间参数
    self.currentTime = options.startTime or 7.0      -- 游戏时间 (0-24)
    self.dayDuration = options.dayDuration or 600    -- 真实秒数 = 1 游戏天
    self.paused = false
    self.timeScale = options.timeScale or 1.0
    
    -- 保存初始雾效距离（用于保持一致）
    self.fogStart = options.fogStart or 30.0
    self.fogEnd = options.fogEnd or 200.0
    
    -- 当前 LightGroup 预设名（用于检测是否需要切换）
    self.currentPreset = nil
    
    -- 太阳旋转平滑插值参数
    self.sunRotationLerpSpeed = options.sunRotationLerpSpeed or 5.0  -- 插值速度
    self.currentSunRotation = nil  -- 当前实际旋转（用于平滑插值）
    
    -- 初始应用光照
    self:applyCurrentLighting()
    
    return self
end

-- ====================================================================
-- 时间管理
-- ====================================================================

---获取当前游戏时间
---@return number 时间 (0-24)
function DayNightCycle:getTime()
    return self.currentTime
end

---设置游戏时间
---@param hour number 时间 (0-24)
function DayNightCycle:setTime(hour)
    self.currentTime = hour % 24
    self:applyCurrentLighting()
end

---增加游戏时间
---@param hours number 增加的小时数
function DayNightCycle:addTime(hours)
    self.currentTime = (self.currentTime + hours) % 24
    self:applyCurrentLighting()
    print(string.format("[DayNight] Time set to %02d:%02d (%s)", 
        math.floor(self.currentTime), 
        math.floor((self.currentTime % 1) * 60),
        self:getPhase()))
end

---暂停时间流逝
function DayNightCycle:pause()
    self.paused = true
end

---恢复时间流逝
function DayNightCycle:resume()
    self.paused = false
end

---检查是否暂停
---@return boolean
function DayNightCycle:isPaused()
    return self.paused
end

---设置时间流速
---@param scale number 倍率 (1.0 = 正常)
function DayNightCycle:setTimeScale(scale)
    self.timeScale = scale
end

---获取时间流速
---@return number
function DayNightCycle:getTimeScale()
    return self.timeScale
end

-- ====================================================================
-- 阶段判断
-- ====================================================================

---获取当前阶段名称
---@return string "dawn" | "day" | "dusk" | "night"
function DayNightCycle:getPhase()
    local hour = self.currentTime
    
    if hour >= 5 and hour < 7 then
        return "dawn"
    elseif hour >= 7 and hour < 17 then
        return "day"
    elseif hour >= 17 and hour < 19 then
        return "dusk"
    else
        return "night"
    end
end

---获取当前阶段和插值信息
---@return string phase, string fromPhase, string toPhase, number t
function DayNightCycle:getPhaseInfo()
    local hour = self.currentTime
    
    -- 日出过渡 (5-7): night → day
    if hour >= 5 and hour < 7 then
        return "dawn", "night", "day", (hour - 5) / 2
    -- 白天稳定 (7-17)
    elseif hour >= 7 and hour < 17 then
        return "day", "day", "day", 1
    -- 日落过渡 (17-19): day → night
    elseif hour >= 17 and hour < 19 then
        return "dusk", "day", "night", (hour - 17) / 2
    -- 夜晚 (19-24 或 0-5): 跨夜处理
    else
        return "night", "night", "night", 1
    end
end

---检查是否为白天
---@return boolean
function DayNightCycle:isDay()
    local phase = self:getPhase()
    return phase == "day" or phase == "dawn"
end

-- ====================================================================
-- 更新循环
-- ====================================================================

---每帧更新
---@param timeStep number 帧时间步长
function DayNightCycle:update(timeStep)
    if self.paused then 
        return 
    end
    
    -- 更新时间
    local hoursPerSecond = 24 / self.dayDuration
    self.currentTime = self.currentTime + timeStep * hoursPerSecond * self.timeScale
    
    -- 时间回绕
    if self.currentTime >= 24 then
        self.currentTime = self.currentTime - 24
    end
    
    -- 应用光照变化
    self:applyCurrentLighting()
    
    -- 更新太阳旋转（传入 timeStep 用于平滑插值）
    self:updateSunRotation(timeStep)
end

-- ====================================================================
-- 光照应用
-- ====================================================================

---应用当前时间的光照参数
function DayNightCycle:applyCurrentLighting()
    -- 获取插值信息
    local phase, fromPhase, toPhase, t = self:getPhaseInfo()
    local fromParams = LIGHT_PARAMS[fromPhase]
    local toParams = LIGHT_PARAMS[toPhase]
    
    -- 插值并应用
    self:applyLighting(fromParams, toParams, t)
end

---线性插值辅助函数
---@param a number
---@param b number
---@param t number
---@return number
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- 注意：Urho3D 内置 Quaternion:Slerp(rhs, t) 和 Quaternion:Nlerp(rhs, t, shortestPath)
-- 用于四元数球面插值，避免角度跳变导致的抖动

---切换 LightGroup 预设
---@param presetName string 预设名称 ("Daytime", "Night" 等)
function DayNightCycle:switchLightGroup(presetName)
    if not self.scene or not presetName then
        return false
    end
    
    -- 如果已经是当前预设，不切换
    if self.currentPreset == presetName then
        return false
    end
    
    -- 移除旧的 LightGroup
    if self.lightGroup then
        self.lightGroup:Remove()
        self.lightGroup = nil
    end
    
    -- 加载新的 LightGroup（使用 LOCAL 模式）
    self.lightGroup = self.scene:InstantiateXML("LightGroup/" .. presetName .. ".xml", Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
    
    -- 更新组件引用
    self.zone = self.lightGroup:GetComponent("Zone")
    local sunNode = self.lightGroup:GetChild("Directional Light")
    if sunNode then
        self.sunNode = sunNode
        self.sunLight = sunNode:GetComponent("Light")
    end
    
    -- 重新应用雾效距离
    if self.zone then
        self.zone.fogStart = self.fogStart
        self.zone.fogEnd = self.fogEnd
    end
    
    self.currentPreset = presetName
    print("[DayNight] Switched to LightGroup: " .. presetName)
    return true
end

---插值并应用光照参数
---@param from table 起始参数
---@param to table 目标参数
---@param t number 插值因子 (0-1)
function DayNightCycle:applyLighting(from, to, t)
    -- 确定目标 LightGroup 预设
    -- 在过渡中点 (t >= 0.5) 时切换到目标预设
    local targetPreset
    if t < 0.5 then
        targetPreset = from.lightGroup
    else
        targetPreset = to.lightGroup
    end
    
    -- 切换 LightGroup（如果需要）
    self:switchLightGroup(targetPreset)
    
    -- 应用 Zone 参数
    if self.zone then
        -- fogColor 是 live 参数，逐帧平滑插值
        -- (ambientColor 不在此处理：引擎硬下发 cAmbientColor=0，环境光随 LightGroup 预设整套切换)
        self.zone.fogColor = from.fogColor:Lerp(to.fogColor, t)

        -- 保持雾效距离不变
        self.zone.fogStart = self.fogStart
        self.zone.fogEnd = self.fogEnd
    end
    
    -- 应用太阳光参数
    if self.sunLight then
        self.sunLight.color = from.sunColor:Lerp(to.sunColor, t)
        self.sunLight.brightness = lerp(from.sunBrightness, to.sunBrightness, t)
    end
end

---计算目标太阳 pitch 角度
---@return number pitch 角度
function DayNightCycle:calculateTargetSunPitch()
    local hour = self.currentTime
    local sunPitch
    
    if hour >= 6 and hour <= 18 then
        -- 白天：太阳从东升到西落
        local dayProgress = (hour - 6) / 12  -- 0 到 1
        sunPitch = math.sin(dayProgress * math.pi) * 60 + 10  -- 10° 到 70° 再到 10°
    else
        -- 夜间：太阳在地平线以下
        local nightProgress
        if hour > 18 then
            nightProgress = (hour - 18) / 12  -- 18:00 开始
        else
            nightProgress = (hour + 6) / 12   -- 从 0:00 继续
        end
        sunPitch = -10 - math.sin(nightProgress * math.pi) * 30  -- 地平线以下
    end
    
    return sunPitch
end

---更新太阳节点旋转（使用平滑插值避免抖动）
---@param timeStep number 帧时间步长（可选，用于平滑插值）
function DayNightCycle:updateSunRotation(timeStep)
    if not self.sunNode then 
        return 
    end
    
    -- 太阳角度计算：
    -- 6:00 地平线 (0°) → 12:00 最高点 (60°) → 18:00 地平线 (0°)
    -- 夜间太阳在地平线以下
    local targetPitch = self:calculateTargetSunPitch()
    local targetYaw = 45  -- 保持 yaw 不变
    
    -- 创建目标四元数
    local targetRotation = Quaternion(targetPitch, targetYaw, 0)
    
    -- 初始化当前旋转（首次调用时）
    if not self.currentSunRotation then
        self.currentSunRotation = targetRotation
        self.sunNode.rotation = targetRotation
        return
    end
    
    -- 使用引擎内置 Slerp 平滑插值（避免角度跳变导致的抖动）
    -- 计算插值因子：基于时间步长和插值速度
    timeStep = timeStep or 0.016  -- 默认约 60fps
    local lerpFactor = math.min(1.0, timeStep * self.sunRotationLerpSpeed)
    
    -- 球面插值到目标旋转（使用引擎原生 Slerp 方法）
    self.currentSunRotation = self.currentSunRotation:Slerp(targetRotation, lerpFactor)
    
    -- 应用平滑后的旋转
    self.sunNode.rotation = self.currentSunRotation
end

-- ====================================================================
-- 格式化输出
-- ====================================================================

---获取格式化的时间字符串
---@return string "HH:MM" 格式
function DayNightCycle:getTimeString()
    local h = math.floor(self.currentTime)
    local m = math.floor((self.currentTime % 1) * 60)
    return string.format("%02d:%02d", h, m)
end

---获取阶段的显示名称
---@return string
function DayNightCycle:getPhaseDisplayName()
    local phase = self:getPhase()
    local names = {
        dawn = "Dawn",
        day = "Day",
        dusk = "Dusk",
        night = "Night",
    }
    return names[phase] or phase
end

return DayNightCycle

