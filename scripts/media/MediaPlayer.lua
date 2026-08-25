-- ============================================================================
-- media/MediaPlayer.lua
-- S6 正式剧情视频媒体会话
--
-- 说明：当前项目尚无正式 S1~S13 剧情视频，VIDEO_SOURCES 暂以 S1 Spike
-- 测试素材占位。测试素材与正式素材在内容上不同，正式资产到位后只需替换映射。
--
-- 状态：CREATING → READY/SEEK_READ → PLAY → PAUSED_AT_BREAKPOINT → ENDED
-- 读档恢复：就绪 → Seek → 两次时间确认 → 移除遮罩
-- 真机兼容：Seek 最多三次；失败后自然播放到目标或从当前位置继续。
-- ============================================================================

local UI = require "urhox-libs/UI"
local Video = require "urhox-libs/Video"
local PlayerData = require "config.PlayerData"

local MediaPlayer = {}

--- 统一日志前缀。
--- 必须先定义：下方 renderBreakpointChoices / handleBreakpointChoice 在定义时即引用本 local；
--- 若放在它们之后，Lua 会因词法作用域把它们绑定到全局 log（真机上为非可调用对象）而崩溃。
---@param message string
local function log(message)
    print("[MediaPlayer] " .. message)
end

local VIDEO_SOURCES = {
    -- 临时占位：正式 S1~S13 到位后逐项替换为对应剧情视频。
    S1 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S2 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S3 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S4 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S5 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S6 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S7 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S8 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S9 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S10 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S11 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S12 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    S13 = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    -- S6 记忆印证 5 段（ch3/P32~P36）：正式 S6-x 素材未到位，先占位同测试视频；
    --   正式素材到位后逐项替换（仍走"播完或断点暂停 → 解读三选 → 信念+1"）。
    ["S6-1"] = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    ["S6-2"] = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    ["S6-3"] = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    ["S6-4"] = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    ["S6-5"] = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
}

local SEEK_TOLERANCE = 0.15
local MAX_SEEK_ATTEMPTS = 3
local FREEZE_GAP = 1.5
local MAX_FREEZE_RECOVERIES = 3

---@type table|nil
local session_ = nil
---@type table|nil
local savedRoot_ = nil
---@type table|nil
local videoRoot_ = nil
---@type table|nil
local player_ = nil
---@type function|nil
local completeHandler_ = nil
---@type boolean
local breakpointTest_ = false
---@type table|nil
local breakpointTestData_ = nil
---@type function|nil
local breakpointTestChoiceHandler_ = nil
---@type function|nil
local breakpointTestResumeHandler_ = nil
---@type function|nil
local resumeFromBreakpoint

local BREAKPOINT_TEST_PARAGRAPH = {
    id = "DEBUG_BREAKPOINT_TEST",
    type = "video",
    video = "S1",
    breakpoints = {
        {
            at = 4.0,
            act = "choice",
            options = {
                reunion = "相信重逢",
                release = "选择放手",
                legend = "相信传说",
            },
            choiceOrder = { "reunion", "release", "legend" },
        },
    },
}

local function isBreakpointTestSession()
    return session_ ~= nil and session_.paragraph.id == BREAKPOINT_TEST_PARAGRAPH.id
end

--- 当前段落当前的断点定义（按 breakpointIndex 取；无则 nil）
---@return table|nil
local function currentBreakpoint()
    if session_ == nil or session_.paragraph == nil then return nil end
    local bps = session_.paragraph.breakpoints or {}
    return bps[session_.breakpointIndex]
end

--- 该段落是否含"选择型"断点（act=choice 且有 options）——用于构建/显示三选按钮
---@return boolean
local function paragraphHasChoiceBreakpoint()
    if session_ == nil or session_.paragraph == nil then return false end
    local bps = session_.paragraph.breakpoints or {}
    for _, bp in ipairs(bps) do
        if bp.act == "choice" and bp.options ~= nil then
            return true
        end
    end
    return false
end

--- 取段落第一个"选择型"断点（构建按钮用；本作每段一个选择断点）
---@return table|nil
local function getChoiceBreakpoint()
    if session_ == nil or session_.paragraph == nil then return nil end
    local bps = session_.paragraph.breakpoints or {}
    for _, bp in ipairs(bps) do
        if bp.act == "choice" and bp.options ~= nil then
            return bp
        end
    end
    return nil
end

local function renderBreakpointChoices()
    if session_ == nil or session_.choiceButtons == nil then return end
    if not paragraphHasChoiceBreakpoint() then return end
    local bp = currentBreakpoint()
    if session_.maskText ~= nil then
        session_.maskText:SetText((bp and bp.prompt) or "断点交互，请选择")
    end
    if session_.breakpointButton ~= nil then
        session_.breakpointButton:SetVisible(false)
        session_.breakpointButton:SetDisabled(true)
    end
    for _, button in ipairs(session_.choiceButtons) do
        button:SetVisible(true)
    end
    session_.phase = "PAUSED_AT_BREAKPOINT"
    log("断点读档 Seek 双确认完成 | 断点不重复触发 | 显示三选")
end

--- 取当前 belief 轴数值（仅供日志）
---@param axis string
---@return number
local function scene_belief_value(axis)
    local belief = session_ and session_.data and session_.data.belief
    if belief == nil then return 0 end
    return belief[axis] or 0
end

local function handleBreakpointChoice(key)
    if session_ == nil or session_.phase ~= "PAUSED_AT_BREAKPOINT" then return end
    if session_.choiceLocked then return end
    session_.choiceLocked = true
    for _, button in ipairs(session_.choiceButtons or {}) do
        button:SetDisabled(true)
    end

    -- 按当前断点 beliefMap 向对应信念轴 +1（数据驱动）；无 beliefMap 时键名即轴名
    local bp = currentBreakpoint()
    local axis = (bp and bp.beliefMap and bp.beliefMap[key]) or key
    local belief = session_.data and session_.data.belief
    if axis ~= nil and belief ~= nil and belief[axis] ~= nil then
        belief[axis] = belief[axis] + 1
    end
    log("断点交互选择已锁定 | key=" .. tostring(key)
        .. " | belief=" .. tostring(axis and scene_belief_value(axis) or 0))
    resumeFromBreakpoint()
end

---@param value number
---@return string
local function formatTime(value)
    return string.format("%.3f", value or 0)
end

---@param videoId string
---@return string|nil
local function videoSource(videoId)
    return VIDEO_SOURCES[videoId]
end

---@param data table
---@param paragraph table
---@param breakpointIndex number
---@param timeSec number
local function writeMediaPosition(data, paragraph, breakpointIndex, timeSec)
    if data == nil or type(data.mediaPos) ~= "table" then return end
    data.mediaPos.node = paragraph.id or ""
    data.mediaPos.video = paragraph.video or ""
    data.mediaPos.breakpoint = breakpointIndex or 0
    data.mediaPos.timeSec = math.max(0, timeSec or 0)
    log("写入 mediaPos | node=" .. tostring(data.mediaPos.node)
        .. " video=" .. tostring(data.mediaPos.video)
        .. " breakpoint=" .. tostring(data.mediaPos.breakpoint)
        .. " timeSec=" .. formatTime(data.mediaPos.timeSec))
end

local function clearMediaPosition(data)
    if data == nil or type(data.mediaPos) ~= "table" then return end
    data.mediaPos.node = ""
    data.mediaPos.video = ""
    data.mediaPos.breakpoint = 0
    data.mediaPos.timeSec = 0
end

local function destroyPlayer()
    if player_ == nil then return end
    local oldPlayer = player_
    player_ = nil
    pcall(function()
        if oldPlayer.Stop then oldPlayer:Stop() end
    end)
    pcall(function()
        if oldPlayer.Destroy then oldPlayer:Destroy() end
    end)
    log("显式 Destroy 剧情播放器 | 存活实例=0")
end

local function restoreRoot()
    if videoRoot_ ~= nil then
        pcall(function() videoRoot_:Destroy() end)
        videoRoot_ = nil
    end
    if savedRoot_ ~= nil then
        UI.SetRoot(savedRoot_, true)
    else
        UI.SetRoot(UI.Panel {
            width = "100%",
            height = "100%",
            pointerEvents = "box-none",
        })
    end
    savedRoot_ = nil
end

local function unsubscribeLifecycle()
    if session_ == nil or not session_.lifecycleSubscribed then return end
    UnsubscribeFromEvent("AppDidEnterBackground")
    UnsubscribeFromEvent("AppDidEnterForebackground")
    session_.lifecycleSubscribed = false
    log("退订生命周期辅助事件")
end

local function teardown(releaseRoot)
    unsubscribeLifecycle()
    destroyPlayer()
    if releaseRoot then
        restoreRoot()
    end
end

--- 把当前 mediaPos 落盘（离散点：断点暂停/onPause/后台回调），供启动自动续档。
--- 不在 onTimeUpdate 每帧调用，避免高频写盘。
local function persistMediaPosition()
    if session_ == nil or session_.data == nil then return end
    PlayerData.Save(session_.data)
end

---@param eventType string|StringHash
---@param eventData? table
local function handleBackground(eventType, eventData)
    if session_ == nil then return end
    log("生命周期辅助日志：AppDidEnterBackground | 不依赖该事件恢复")
    if player_ ~= nil and player_:IsPlaying() then
        writeMediaPosition(session_.data, session_.paragraph, session_.breakpointIndex,
            player_:GetCurrentTime())
        persistMediaPosition()
    end
end

---@param eventType string|StringHash
---@param eventData? table
local function handleForeground(eventType, eventData)
    log("生命周期辅助日志：AppDidEnterForebackground | 由冻结自愈负责续播")
end

local function subscribeLifecycle()
    SubscribeToEvent("AppDidEnterBackground", handleBackground)
    SubscribeToEvent("AppDidEnterForebackground", handleForeground)
    session_.lifecycleSubscribed = true
    log("已订阅生命周期辅助事件；后台/前台不作为恢复前提")
end

local function hideMask()
    if session_ ~= nil and session_.mask ~= nil then
        session_.mask:SetVisible(false)
    end
end

local function showMask()
    if session_ ~= nil and session_.mask ~= nil then
        session_.mask:SetVisible(true)
    end
end

local function completePlayback()
    if session_ == nil or session_.completionSent then return end
    session_.completionSent = true
    local paragraph = session_.paragraph
    local callback = completeHandler_
    local isTest = isBreakpointTestSession()
    log("ENDED | 段落 " .. tostring(paragraph.id) .. " 播放完成，先释放再推进")
    clearMediaPosition(session_.data)
    teardown(true)
    session_ = nil
    if isTest then
        breakpointTest_ = false
        breakpointTestData_ = nil
        breakpointTestChoiceHandler_ = nil
        breakpointTestResumeHandler_ = nil
        log("断点测试 Hook 结束 | 不推进正式 Flow | 存活实例=0")
        return
    end
    if callback then
        callback({ done = true })
    end
end

local function failPlayback(reason)
    if session_ == nil or session_.completionSent then return end
    local failedSession = session_
    failedSession.failed = true
    log("播放失败 | " .. tostring(reason) .. " | 保留当前段落，不自动跳过")
    if failedSession.maskText ~= nil then
        failedSession.maskText:SetText("视频加载失败，请检查正式素材")
    end
    unsubscribeLifecycle()
    destroyPlayer()
    session_ = nil
    restoreRoot()
end

local function simulateBreakpointRead()
    if not isBreakpointTestSession() then return end
    log("断点测试：模拟读档 | 保留 mediaPos.timeSec="
        .. formatTime(breakpointTestData_.mediaPos.timeSec))
    local data = breakpointTestData_
    breakpointTest_ = false
    MediaPlayer.Play(BREAKPOINT_TEST_PARAGRAPH, data)
    breakpointTest_ = true
end

local function revealAndPlay()
    if session_ == nil or player_ == nil then return end
    if paragraphHasChoiceBreakpoint() and session_.breakpointIndex >= 1 then
        player_:Pause()
        session_.recoveryConfirmed = true
        showMask()
        renderBreakpointChoices()
        return
    end
    if session_.breakpointButton ~= nil then
        session_.breakpointButton:SetVisible(false)
        session_.breakpointButton:SetDisabled(true)
    end
    session_.phase = "PLAY"
    session_.recoveryConfirmed = true
    hideMask()
    log("读档恢复确认完成 | 移除遮罩 | 继续播放")
    player_:Play()
end

local function finishNaturalRecovery()
    if session_ == nil or player_ == nil then return end
    session_.phase = "PLAY"
    session_.recoveryConfirmed = true
    hideMask()
    log("Seek 降级完成 | 自然播放/当前位置已到恢复目标 | 移除遮罩")
end

local function naturalRecovery(time)
    if session_ == nil or player_ == nil then return end
    if time >= session_.recoveryTarget - SEEK_TOLERANCE then
        player_:Pause()
        finishNaturalRecovery()
        player_:Play()
        return
    end
    if time >= session_.recoveryTarget then
        finishNaturalRecovery()
    end
end

local function retrySeek()
    if session_ == nil or player_ == nil then return false end
    if session_.seekAttempts >= MAX_SEEK_ATTEMPTS then return false end
    session_.seekAttempts = session_.seekAttempts + 1
    log("Seek(" .. formatTime(session_.recoveryTarget) .. ") 重试 #"
        .. tostring(session_.seekAttempts))
    player_:Seek(session_.recoveryTarget)
    return true
end

local function downgradeRecovery(time)
    if session_ == nil then return end
    session_.seekFallback = true
    session_.seekFallbackTime = time
    log("Seek 连续失败，降级恢复 | target=" .. formatTime(session_.recoveryTarget)
        .. " current=" .. formatTime(time)
        .. " | 差异=" .. formatTime(time - session_.recoveryTarget))
    if time >= session_.recoveryTarget then
        finishNaturalRecovery()
    else
        session_.phase = "SEEK_NATURAL"
        log("降级策略：自然播放到 target=" .. formatTime(session_.recoveryTarget))
    end
end

local function onSeekTimeUpdate(time)
    if session_ == nil or player_ == nil then return end
    local diff = math.abs(time - session_.recoveryTarget)
    if diff <= SEEK_TOLERANCE then
        session_.seekConfirms = session_.seekConfirms + 1
        log("Seek确认 #" .. tostring(session_.seekConfirms)
            .. " | current=" .. formatTime(time)
            .. " diff=" .. formatTime(diff))
        if session_.seekConfirms >= 2 then
            player_:Pause()
            revealAndPlay()
        end
        return
    end

    session_.seekConfirms = 0
    log("Seek偏差 | current=" .. formatTime(time)
        .. " target=" .. formatTime(session_.recoveryTarget)
        .. " diff=" .. formatTime(diff))
    if not retrySeek() then
        downgradeRecovery(time)
    end
end

resumeFromBreakpoint = function()
    if session_ == nil or player_ == nil then return end
    if session_.phase ~= "PAUSED_AT_BREAKPOINT" then return end
    if session_.breakpointButton ~= nil then
        session_.breakpointButton:SetDisabled(true)
    end
    session_.phase = "PLAY"
    log("断点交互完成 | breakpoint=" .. tostring(session_.breakpointIndex)
        .. " | 继续播放")
    for _, button in ipairs(session_.choiceButtons or {}) do
        button:SetVisible(false)
    end
    hideMask()
    if session_.duration > 0
        and player_:GetCurrentTime() >= session_.duration - 0.05 then
        log("断点交互后已处于视频结尾 | 立即 ENDED")
        completePlayback()
        return
    end
    player_:Play()
end

local function pauseAtBreakpoint(index, time)
    if session_ == nil or player_ == nil then return end
    session_.phase = "PAUSED_AT_BREAKPOINT"
    session_.breakpointIndex = index
    writeMediaPosition(session_.data, session_.paragraph, index, time)
    persistMediaPosition()
    player_:Pause()
    showMask()
    -- 选择型断点：显示三选（真实段落 vs 断点测试均可）；断点测试额外保留"模拟读档恢复"按钮
    if isBreakpointTestSession() then
        if session_.maskText ~= nil then
            session_.maskText:SetText("断点命中：点击模拟读档恢复")
        end
        if session_.breakpointButton ~= nil then
            session_.breakpointButton:SetText("模拟读档恢复")
            session_.breakpointButton:SetVisible(true)
        end
        renderBreakpointChoices()
    elseif paragraphHasChoiceBreakpoint() then
        renderBreakpointChoices()
    else
        if session_.maskText ~= nil then
            session_.maskText:SetText("剧情断点")
        end
        if session_.breakpointButton ~= nil then
            session_.breakpointButton:SetText("继续")
            session_.breakpointButton:SetVisible(true)
        end
    end
    log("到达断点 #" .. tostring(index) .. " | at=" .. formatTime(time)
        .. " | 已暂停并等待交互")
end

local function checkBreakpoint(time)
    if session_ == nil or session_.paragraph == nil then return end
    if session_.phase ~= "PLAY" then return end
    local breakpoints = session_.paragraph.breakpoints or {}
    for index, breakpoint in ipairs(breakpoints) do
        local at = breakpoint.at
        if type(at) == "number" and at >= 0
            and index > session_.breakpointIndex
            and time >= at
            and time < (session_.duration - 0.5) then
            pauseAtBreakpoint(index, time)
            return
        end
    end
end

local function onReady(self)
    if session_ == nil or session_.player ~= self then return end
    session_.phase = "READY"
    session_.duration = self:GetDuration()
    log("CREATING → READY | video=" .. tostring(session_.paragraph.video)
        .. " duration=" .. formatTime(session_.duration)
        .. " | 当前正式素材为测试占位")

    local target = session_.resumeTarget
    if target ~= nil and target > 0 then
        session_.phase = "SEEK_READ"
        session_.recoveryTarget = math.min(target, math.max(0, session_.duration - 0.05))
        session_.seekAttempts = 0
        session_.seekConfirms = 0
        showMask()
        self:Play()
        retrySeek()
        log("读档恢复：READY → SEEK_READ，遮罩保持到双确认")
    else
        session_.recoveryConfirmed = true
        hideMask()
        session_.phase = "PLAY"
        self:Play()
        log("READY → PLAY | 无匹配 mediaPos，正常播放")
    end
end

local function onPlay(self)
    if session_ == nil or session_.player ~= self then return end
    if session_.phase == "PAUSED_AT_BREAKPOINT" then
        self:Pause()
        log("断点暂停态拦截意外 Play | 等待三选")
        return
    end
    session_.lastTime = self:GetCurrentTime()
    log("onPlay | phase=" .. tostring(session_.phase)
        .. " current=" .. formatTime(session_.lastTime))
end

local function onPause(self)
    if session_ == nil or session_.player ~= self then return end
    local time = self:GetCurrentTime()
    writeMediaPosition(session_.data, session_.paragraph, session_.breakpointIndex, time)
    persistMediaPosition()
    log("onPause | current=" .. formatTime(time))
end

local function onTimeUpdate(self, time, duration)
    if session_ == nil or session_.player ~= self then return end
    session_.duration = duration or session_.duration
    session_.lastTime = time

    -- 真机暂停态可能继续派发时间更新，不能只依赖 onEnded；接近时长即结束。
    if session_.phase ~= "PAUSED_AT_BREAKPOINT"
        and session_.duration > 0 and time >= session_.duration - 0.05 then
        log("达到视频结尾 | current=" .. formatTime(time)
            .. " dur=" .. formatTime(session_.duration) .. " | 强制 ENDED")
        completePlayback()
        return
    end

    if session_.phase == "SEEK_READ" then
        onSeekTimeUpdate(time)
        return
    end
    if session_.phase == "SEEK_NATURAL" then
        naturalRecovery(time)
        return
    end
    if session_.phase == "PLAY" then
        writeMediaPosition(session_.data, session_.paragraph,
            session_.breakpointIndex, time)
        checkBreakpoint(time)
    end
end

local function onEnded(self)
    if session_ == nil or session_.player ~= self then return end
    completePlayback()
end

local function onLoadError(self, code, name)
    if session_ == nil or session_.player ~= self then return end
    failPlayback("code=" .. tostring(code) .. " name=" .. tostring(name))
end

---@param paragraph table
---@param data table
---@return boolean
function MediaPlayer.Play(paragraph, data)
    if paragraph == nil or data == nil then
        log("Play 失败：缺少 paragraph 或 PlayerData")
        return false
    end
    if paragraph.video == nil or paragraph.video == "" then
        log("Play 失败：段落 " .. tostring(paragraph.id) .. " 缺少 video")
        return false
    end
    if not Video.isSupported then
        log("当前运行时不支持 Video.VideoPlayer（需要 PC WASM/真机视频运行时）")
        return false
    end

    MediaPlayer.Stop(true)
    local source = videoSource(paragraph.video)
    if source == nil then
        log("Play 失败：未找到 videoId(" .. tostring(paragraph.video) .. ") 映射")
        return false
    end

    savedRoot_ = UI.GetRoot()
    session_ = {
        paragraph = paragraph,
        data = data,
        phase = "CREATING",
        duration = 0,
        breakpointIndex = 0,
        lastTime = nil,
        freezeElapsed = 0,
        freezeRecoveries = 0,
        resumeTarget = nil,
        recoveryTarget = 0,
        seekAttempts = 0,
        seekConfirms = 0,
        recoveryConfirmed = false,
        completionSent = false,
        failed = false,
    }

    local mediaPos = data.mediaPos
    if type(mediaPos) == "table"
        and mediaPos.node == paragraph.id
        and mediaPos.video == paragraph.video
        and type(mediaPos.timeSec) == "number"
        and mediaPos.timeSec > 0 then
        session_.resumeTarget = mediaPos.timeSec
        session_.breakpointIndex = math.max(0, math.floor(mediaPos.breakpoint or 0))
        log("命中读档位置 | node=" .. paragraph.id
            .. " breakpoint=" .. tostring(session_.breakpointIndex)
            .. " timeSec=" .. formatTime(session_.resumeTarget))
    end

    local resumeCallback = nil
    local mask = UI.Panel {
        id = "mediaMask",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 8, 8, 12, 250 },
        justifyContent = "center",
        alignItems = "center",
        gap = 12,
        zIndex = 90,
    }
    local maskText = UI.Label {
        text = "加载剧情视频...",
        fontSize = 18,
        fontColor = { 246, 241, 231, 255 },
    }
    local breakpointButton = UI.Button {
        text = "继续",
        variant = "primary",
        visible = false,
        onClick = function()
            if isBreakpointTestSession() then
                simulateBreakpointRead()
            elseif resumeCallback then
                resumeCallback()
            end
        end,
    }
    -- 选择型断点：为任意含 act=choice 且有 options 的段落构建三选按钮
    ---@type table|nil { at: number, act: string, options: table, choiceOrder: table, beliefMap: table, prompt?: string }
    local choiceBreakpoint = nil
    local bpList = paragraph.breakpoints or {}
    for _, bp in ipairs(bpList) do
        if bp.act == "choice" and bp.options ~= nil then
            choiceBreakpoint = bp
            break
        end
    end
    local choiceButtons = {}
    if choiceBreakpoint ~= nil and choiceBreakpoint.options ~= nil then
        local order = choiceBreakpoint.choiceOrder
        if order == nil then
            order = {}
            for key in pairs(choiceBreakpoint.options) do
                order[#order + 1] = key
            end
        end
        for _, key in ipairs(order) do
            local button = UI.Button {
                text = choiceBreakpoint.options[key],
                variant = "secondary",
                width = "100%",
                height = 52,
                marginTop = 6,
                zIndex = 100,
                visible = false,
                onClick = function()
                    handleBreakpointChoice(key)
                end,
            }
            choiceButtons[#choiceButtons + 1] = button
            mask:AddChild(button)
        end
    end
    mask:AddChild(maskText)
    mask:AddChild(breakpointButton)

    local player = Video.VideoPlayer {
        id = "storyVideoPlayer",
        width = "100%",
        flex = 1,
        textureWidth = 1080,
        textureHeight = 1920,
        autoPlay = false,
        loop = false,
        muted = false,
        volume = 1.0,
        playbackRate = 1.0,
        objectFit = "contain",
        backgroundColor = { 0, 0, 0, 255 },
        onReady = onReady,
        onPlay = onPlay,
        onPause = onPause,
        onEnded = onEnded,
        onTimeUpdate = onTimeUpdate,
        onLoadError = onLoadError,
    }
    player_ = player
    session_.player = player
    session_.mask = mask
    session_.maskText = maskText
    session_.breakpointButton = breakpointButton
    session_.choiceButtons = choiceButtons
    session_.choiceLocked = false
    resumeCallback = resumeFromBreakpoint

    videoRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 255 },
        children = { player, mask },
    }
    UI.SetRoot(videoRoot_)
    subscribeLifecycle()
    player:SetSrc(source)
    log("CREATING | " .. tostring(paragraph.id)
        .. " | videoId=" .. tostring(paragraph.video)
        .. " | source=" .. source
        .. " | 同屏剧情播放器=1，循环背景=0")
    return true
end

---@param dt number
function MediaPlayer.Update(dt)
    if session_ == nil or player_ == nil then return end
    if session_.failed then return end

    if session_.phase == "PLAY" and player_:IsPlaying() then
        local now = player_:GetCurrentTime()
        if session_.lastTime == nil then
            session_.lastTime = now
        elseif math.abs(now - session_.lastTime) < 0.001 then
            session_.freezeElapsed = session_.freezeElapsed + dt
            if session_.freezeElapsed >= FREEZE_GAP
                and session_.freezeRecoveries < MAX_FREEZE_RECOVERIES then
                session_.freezeRecoveries = session_.freezeRecoveries + 1
                writeMediaPosition(session_.data, session_.paragraph,
                    session_.breakpointIndex, now)
                log("冻结自愈 #" .. tostring(session_.freezeRecoveries)
                    .. " | mediaPos.timeSec=" .. formatTime(now)
                    .. " | Pause → Play")
                player_:Pause()
                player_:Play()
                session_.freezeElapsed = 0
            end
        else
            if session_.freezeRecoveries > 0 then
                log("冻结自愈后时间恢复推进 | current=" .. formatTime(now))
            end
            session_.lastTime = now
            session_.freezeElapsed = 0
        end
    end
end

---@return boolean
function MediaPlayer.IsPlaying()
    return player_ ~= nil and player_:IsPlaying() and session_ ~= nil and not session_.failed
end

---@return boolean
function MediaPlayer.IsActive()
    return session_ ~= nil and player_ ~= nil and not session_.failed
end

---@param release boolean
function MediaPlayer.Stop(release)
    if session_ == nil and player_ == nil then return end
    log("Stop(" .. tostring(release) .. ") | 显式停止媒体会话")
    if player_ ~= nil and player_:IsPlaying() and session_ ~= nil then
        writeMediaPosition(session_.data, session_.paragraph,
            session_.breakpointIndex, player_:GetCurrentTime())
    end
    if release then
        local oldSession = session_
        local wasBreakpointTest = breakpointTest_
        teardown(true)
        session_ = nil
        if wasBreakpointTest then
            breakpointTest_ = false
            breakpointTestData_ = nil
            breakpointTestChoiceHandler_ = nil
            breakpointTestResumeHandler_ = nil
        end
        if oldSession ~= nil then
            log("媒体会话已释放 | 存活实例=0")
        end
    elseif player_ ~= nil then
        player_:Pause()
    end
end

---@param callback function
function MediaPlayer.SetCompleteHandler(callback)
    completeHandler_ = callback
end

---@return string|nil
function MediaPlayer.GetPhase()
    return session_ and session_.phase or nil
end

--- 启动/停止断点测试 Hook（S9 前移除）
function MediaPlayer.ToggleBreakpointTest()
    if breakpointTest_ then
        log("断点测试 Hook 强制结束")
        MediaPlayer.Stop(true)
        breakpointTest_ = false
        breakpointTestData_ = nil
        breakpointTestChoiceHandler_ = nil
        breakpointTestResumeHandler_ = nil
        return
    end
    if not Video.isSupported then
        log("断点测试 Hook 无法启动：当前运行时不支持视频")
        return
    end
    breakpointTest_ = true
    breakpointTestData_ = PlayerData.Sanitize(nil)
    breakpointTestChoiceHandler_ = handleBreakpointChoice
    breakpointTestResumeHandler_ = resumeFromBreakpoint
    log("断点测试 Hook 启动 | at=4.0 | 三选 | F7/断点按钮")
    MediaPlayer.Play(BREAKPOINT_TEST_PARAGRAPH, breakpointTestData_)
end

---@return boolean
function MediaPlayer.IsBreakpointTestActive()
    return breakpointTest_
end

return MediaPlayer
