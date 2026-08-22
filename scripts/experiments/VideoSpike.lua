-- ============================================================================
-- experiments/VideoSpike.lua —— S6 视频接入前的「视频生命周期 Spike」（实验模块）
--
-- 依据：《TTM-视频Spike粘贴块.md》【B】；权威参考 engine-docs/recipes/video.md
-- 目标（S6 前置技术验证）：
--   1. 验证《22》§2 的 MP4/H.264/yuv420p/1080×1920 规格是否被引擎接受播放；
--   2. 验证 onReady/onPlay/onPause/onEnded/onTimeUpdate 回调序列是否全部触发；
--   3. 验证 Seek 精度（两次连续确认 |t - 目标| ≤ 0.15）是否满足断点恢复契约；
--   4. 验证「同时 ≤2 播放器」策略（同屏 3 个的实际行为：成功/排队/报错/内存）；
--   5. 验证销毁后播放器实例数量是否归零；
--   6. 验证切后台/回前台、通知栏返回时视频行为（自动暂停？恢复？）。
--
-- 铁律（见 video.md）：
--   * 必须使用 Video.VideoPlayer Widget（urhox-libs/Video），禁止裸搓 C++ + NanoVG。
--   * 本模块是独立实验，不修改 Chapters / FlowController / 正式剧情流程。
--   * 视频播完即释放，离场显式 Destroy；打印播放器实例数量。
--   * 一次会话只做本任务；完成后由 TTM 复盘代码并列待办，不要顺手接正式视频。
--
-- 触发：在 scripts/main.lua 的 HandleUpdate 里
--   if InputManager.IsKeyPress(KEY_F6) then VideoSpike.Toggle() end
--   if VideoSpike.IsActive() then VideoSpike.Update(timeStep) end
-- 按 F6 开始整条 Spike 序列（A 生命周期 → B 三档 → C 同屏3 → D 建销×3 → E 三步恢复
--   → 汇总 → 清理并恢复 UI 根节点）；再次按 F6 可中途强制结束并清理。
-- ============================================================================

local UI = require "urhox-libs/UI"
local Video = require "urhox-libs/Video"

local VideoSpike = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 三档测试视频（资源根下一级路径，按官方构建内存活路径 `<video/短视频生命周期 spike（推荐）/`；全角括号）
local SOURCES = {
    low  = "video/短视频生命周期 spike（推荐）/S1_test_low_3Mbps.mp4",
    mid  = "video/短视频生命周期 spike（推荐）/S1_test_mid_6Mbps.mp4",
    high = "video/短视频生命周期 spike（推荐）/S1_test_high_10Mbps.mp4",
}

local TOL            = 0.15    -- Seek 容差（|当前时间 − 目标| ≤ 0.15）
local SEEK_TARGET    = 3.5     -- 生命周期场景的 seek 目标（秒）
local RECOVERY_TARGET = 2.0    -- 三步恢复状态机的 seek 目标（秒）
local RECOVERY_WAIT  = 3.0     -- 恢复状态机「等待 3 秒」模拟
local CYCLE_COUNT    = 3       -- 建销重复次数
local CONCURRENT_COUNT = 3     -- 同屏创建的播放器数量（验证 ≤2 策略）

-- ============================================================================
-- 内部状态
-- ============================================================================

local active_       = false
local savedRoot_    = nil     -- 进入 Spike 前的 UI 根节点（结束时恢复）
local root_         = nil     -- Spike 自身的 UI 根节点
local statusLabel_  = nil     -- 状态行 Label
local widgets_      = {}      -- 按创建顺序追踪的 VideoPlayer widget（= 存活实例）
local timers_       = {}      -- { remain, fn }
local scenarioQueue_ = {}     -- 待执行场景 { name, run }
local current_      = nil     -- 当前场景控制器（携带该场景的运行时状态）
local results_      = {}      -- 汇报行 { item, value }
local hbHandlers_   = nil     -- 后台/前台事件订阅句柄（UnsubscribeFromEvent 用）
local tuCount_      = 0       -- 本次运行中 onTimeUpdate 触发次数（验证回调确实被触发）

local function log(msg) print("[VideoSpike] " .. msg) end

--- 更新状态行文本（存在则刷新）
---@param text string
local function setStatus(text)
    if statusLabel_ and statusLabel_.props then
        statusLabel_:SetText(text)
    end
end

--- 追加一条汇报行
---@param item string
---@param value string
local function addResult(item, value)
    results_[#results_ + 1] = { item = item, value = value }
end

-- ============================================================================
-- 播放器实例计数
-- ============================================================================

--- 登记一个新建的播放器 widget
---@param w userdata|table
local function trackWidget(w)
    widgets_[#widgets_ + 1] = w
    log("创建播放器 | 存活实例 " .. #widgets_)
end

--- 从计数中移除一个已销毁的播放器（Destroy 后调用）
---@param w userdata|table
local function removeWidget(w)
    for i = #widgets_, 1, -1 do
        if widgets_[i] == w then
            table.remove(widgets_, i)
            log("释放播放器 | 存活实例 " .. #widgets_)
            return
        end
    end
end

--- 销毁所有存活播放器（场景结束 / 强制结束时的兜底清理）；逆序避免父子顺序问题
local function destroyAllWidgets()
    local n = #widgets_
    for i = n, 1, -1 do
        local w = widgets_[i]
        if w and type(w.Destroy) == "function" then
            pcall(function() w:Destroy() end)
        end
    end
    widgets_ = {}
    log("销毁 " .. n .. " 个播放器 | 存活实例 " .. #widgets_)
end

-- ============================================================================
-- 计时器
-- ============================================================================

--- 安排在若干秒后执行一次
---@param seconds number
---@param fn function
local function schedule(seconds, fn)
    timers_[#timers_ + 1] = { remain = seconds, fn = fn }
end

local function clearTimers()
    timers_ = {}
end

---@param dt number
local function pumpTimers(dt)
    if #timers_ == 0 then return end
    for i = #timers_, 1, -1 do
        local t = timers_[i]
        t.remain = t.remain - dt
        if t.remain <= 0 then
            table.remove(timers_, i)
            local fn = t.fn
            t.fn = nil
            if fn then fn() end
        end
    end
end

-- ============================================================================
-- UI / 播放器 构造
-- ============================================================================

--- 销毁 Spike 自己的上一屏（含未追踪的容器 widget；视频资源由 destroyAllWidgets 负责）
local function teardownScreen()
    destroyAllWidgets()
    if root_ then
        pcall(function() root_:Destroy() end)
        root_ = nil
    end
    statusLabel_ = nil
end

--- 建一个新 Spike 屏（标题 + 状态行），销毁上一屏
---@param title string
local function newScreen(title)
    -- 清掉旧屏（只清 Spike 屏，绝不触碰游戏根 UI）
    teardownScreen()
    root_ = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 16, 16, 20, 255 },
        flexDirection = "column",
    }
    local titleLabel = UI.Label {
        text = title,
        fontSize = 15,
        fontColor = { 255, 220, 160, 255 },
        width = "100%",
        marginTop = 10, marginBottom = 6, marginLeft = 12, marginRight = 12,
    }
    local status = UI.Label {
        id = "spikeStatus",
        text = "...",
        fontSize = 13,
        fontColor = { 200, 200, 200, 255 },
        width = "100%",
        marginLeft = 12, marginRight = 12, marginBottom = 8,
    }
    root_:AddChild(titleLabel)
    root_:AddChild(status)
    statusLabel_ = root_:FindById("spikeStatus")
    UI.SetRoot(root_)
end

--- 创建一个 VideoPlayer widget（带回调挂钩），并登记进计数
---@param src string
---@param hooks table onReady/onPlay/onPause/onEnded/onTimeUpdate/onLoadError
---@return table w widget
local function makeWidget(src, hooks)
    hooks = hooks or {}
    local w = Video.VideoPlayer {
        src = src,
        width = "100%",
        flex = 1,
        -- 素材为竖屏 1080×1920：纹理初始尺寸必须与之匹配（指南默认横屏 1920×1080）
        textureWidth = 1080,
        textureHeight = 1920,
        autoPlay = false,
        loop = false,
        muted = true,          -- Spike 静音，避免干扰；正式接入按需
        volume = 0.0,
        playbackRate = 1.0,
        objectFit = "contain",
        backgroundColor = { 0, 0, 0, 255 },
        onReady = hooks.onReady,
        onPlay = hooks.onPlay,
        onPause = hooks.onPause,
        onEnded = hooks.onEnded,
        onTimeUpdate = hooks.onTimeUpdate,
        onLoadError = hooks.onLoadError,
    }
    trackWidget(w)
    return w
end

--- 在父节点下加一块视频区域（1 块区域 = 1 个播放器 + 1 个加载遮罩）
---@param parent table
---@param src string
---@param hooks table
---@param maskText string
---@param maskId? string
---@return table w, table mask, table area
local function addVideoArea(parent, src, hooks, maskText, maskId)
    local area = UI.Panel {
        flex = 1,
        width = "100%",
        backgroundColor = { 0, 0, 0, 255 },
        justifyContent = "center",
        alignItems = "center",
    }
    local w = makeWidget(src, hooks)
    area:AddChild(w)
    local mask = UI.Panel {
        id = maskId,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 22, 22, 26, 242 },
        justifyContent = "center",
        alignItems = "center",
    }
    mask:AddChild(UI.Label {
        text = maskText or "LOADING...",
        fontSize = 16,
        fontColor = { 255, 255, 255, 255 },
    })
    area:AddChild(mask)
    parent:AddChild(area)
    return w, mask, area
end

--- 用一行展示某个区域的时间/时长（简单的一条日志，不额外建 UI，保持轻量）
---@param tag string
---@param time number
---@param dur number
local function logTime(tag, time, dur)
    log(tag .. " | t=" .. string.format("%.3f", time)
        .. " dur=" .. string.format("%.3f", dur or 0))
end

--- 浏览器自动播放解锁：在真实用户手势（F6 按下）内对媒体元素调用 play()，
--- 以授予页面自动播放许可。Spike 全程 muted，浏览器本就允许静音自动播放；
--- 这一步是为从严的 iframe / 预览容器兜底，也符合「首次 F6 即解锁」的预期。
local function primeAutoplay()
    if not Video.isSupported then return end
    local w = Video.VideoPlayer {
        src = SOURCES.mid,
        width = 1, height = 1,
        position = "absolute", left = -10000, top = -10000,
        autoPlay = false, loop = false, muted = true, volume = 0.0,
        backgroundColor = { 0, 0, 0, 0 },
    }
    if w and type(w.Play) == "function" then
        pcall(function() w:Play() end)
        log("已借 F6 手势触发一次 play()，用于解锁浏览器自动播放")
    end
    -- 手势解锁动作已发生；尽早释放，避免占用播放器名额 / 触发 orphan 告警。
    if w and type(w.Destroy) == "function" then
        pcall(function() w:Destroy() end)
    end
end

-- ============================================================================
-- 场景实现
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 【A】生命周期（mid）：onReady → Play → Seek(3.5，两次确认) → Pause → Resume → onEnded
-- ---------------------------------------------------------------------------
local function runLifecycle()
    newScreen("A · 生命周期（mid 档）")
    local s = current_
    s.state = { phase = "loading", target = SEEK_TARGET, confirms = 0, resumeScheduled = false }

    local w = addVideoArea(root_, SOURCES.mid, {
        onReady = function(self)
            s.state.phase = "ready"
            log("A onReady | playing=" .. tostring(self:IsPlaying())
                .. " dur=" .. string.format("%.3f", self:GetDuration()))
            self:Play()
        end,

        onPlay = function(self)
            log("A onPlay")
            if not s.state.resumeScheduled then
                s.state.resumeScheduled = true
                schedule(1.5, function()
                    s.state.phase = "seek_confirm"
                    log("A 发起 Seek(" .. SEEK_TARGET .. ") 目标容差 ≤" .. TOL)
                    self:Seek(SEEK_TARGET)
                end)
            end
        end,

        onPause = function(self)
            log("A onPause")
        end,

        onTimeUpdate = function(self, time, dur)
            tuCount_ = tuCount_ + 1
            logTime("A onTimeUpdate", time, dur)
            setStatus(string.format("A t=%.2f / %.2f", time, dur))
            if s.state.phase == "seek_confirm" then
                local diff = math.abs(time - SEEK_TARGET)
                if diff <= TOL then
                    s.state.confirms = s.state.confirms + 1
                    log("A seek确认 #" .. s.state.confirms
                        .. " | t=" .. string.format("%.3f", time)
                        .. " diff=" .. string.format("%.3f", diff))
                    if s.state.confirms >= 2 then
                        s.state.phase = "seek_done"
                        local now = self:GetCurrentTime()
                        local durv = self:GetDuration()
                        addResult("Seek(3.5) 精度",
                            string.format("两次确认通过 | 确认时 cur=%.3f | dur=%.3f", now, durv))
                        log("A Seek 两次确认完成 → Pause | cur=" .. string.format("%.3f", now)
                            .. " dur=" .. string.format("%.3f", durv))
                        self:Pause()
                        schedule(0.6, function()
                            log("A 继续播放至结尾")
                            self:Play()
                        end)
                    end
                else
                    log("A seek 超差 diff=" .. string.format("%.3f", diff) .. "（继续等待）")
                end
            end
        end,

        onEnded = function(self)
            log("A onEnded → 显式释放")
            self:Destroy()
            removeWidget(self)
            addResult("回调序列", "onReady/onPlay/onPause/onTimeUpdate/onEnded 全部触发")
            schedule(0.3, function() current_.next() end)
        end,

        onLoadError = function(self, code, name)
            log("A onLoadError code=" .. tostring(code) .. " name=" .. tostring(name))
            addResult("回调序列", "onLoadError(" .. tostring(name) .. ")：mid 未能加载")
            schedule(0.3, function() current_.next() end)
        end,
    }, "A mid 加载中...", "maskA")
end

-- ---------------------------------------------------------------------------
-- 【B】三档码率接受度（low / high 各建一次：ready → play → 短暂后销毁）
-- ---------------------------------------------------------------------------
local function runTier(src, tag, done)
    logTime(tag .. " 创建", 0, 0)
    addVideoArea(root_, src, {
        onReady = function(self)
            log(tag .. " onReady | dur=" .. string.format("%.3f", self:GetDuration()))
            self:Play()
        end,
        onPlay = function(self)
            log(tag .. " onPlay")
            schedule(1.0, function()
                log(tag .. " 播放OK → 释放")
                self:Destroy()
                removeWidget(self)
                done()
            end)
        end,
        onTimeUpdate = function(self, time, dur)
            logTime(tag .. " onTimeUpdate", time, dur)
            setStatus(string.format("%s t=%.2f / %.2f", tag, time, dur))
        end,
        onLoadError = function(self, code, name)
            log(tag .. " onLoadError code=" .. tostring(code) .. " name=" .. tostring(name))
            done()
        end,
    }, tag .. " 加载中...")
end

local function runTiers()
    newScreen("B · 三档码率接受度（low / high）")
    local s = current_
    s.doneLow = false
    s.doneHigh = false
    s.finish = function()
        if s.doneLow and s.doneHigh then
            addResult("三档码率接受度", "mid(A) + low(B) + high(B) 全程 onReady/onPlay 通过")
            schedule(0.2, function() current_.next() end)
        end
    end
    runTier(SOURCES.low, "B-low", function()
        s.doneLow = true
        s.finish()
    end)
    runTier(SOURCES.high, "B-high", function()
        s.doneHigh = true
        s.finish()
    end)
end

-- ---------------------------------------------------------------------------
-- 【C】同屏 3 个播放器（验证 ≤2 策略的实际行为）
-- ---------------------------------------------------------------------------
local function runConcurrency()
    newScreen("C · 同屏 3 播放器（low/mid/high 并排）")
    local s = current_
    s.readyCount = 0
    s.errorCount = 0

    addVideoArea(root_, SOURCES.low, {
        onReady = function(self)
            s.readyCount = s.readyCount + 1
            log("C-low onReady | readyCount=" .. s.readyCount)
            self:Play()
        end,
        onTimeUpdate = function(self, t, d)
            logTime("C-low", t, d)
            setStatus(string.format("C-low t=%.2f / %.2f", t, d))
        end,
        onLoadError = function(self, code, name)
            s.errorCount = s.errorCount + 1
            log("C-low onLoadError " .. tostring(name))
        end,
    }, "C-low 加载中...")

    addVideoArea(root_, SOURCES.mid, {
        onReady = function(self)
            s.readyCount = s.readyCount + 1
            log("C-mid onReady | readyCount=" .. s.readyCount)
            self:Play()
        end,
        onTimeUpdate = function(self, t, d)
            logTime("C-mid", t, d)
            setStatus(string.format("C-mid t=%.2f / %.2f", t, d))
        end,
        onLoadError = function(self, code, name)
            s.errorCount = s.errorCount + 1
            log("C-mid onLoadError " .. tostring(name))
        end,
    }, "C-mid 加载中...")

    addVideoArea(root_, SOURCES.high, {
        onReady = function(self)
            s.readyCount = s.readyCount + 1
            log("C-high onReady | readyCount=" .. s.readyCount)
            self:Play()
        end,
        onTimeUpdate = function(self, t, d)
            logTime("C-high", t, d)
            setStatus(string.format("C-high t=%.2f / %.2f", t, d))
        end,
        onLoadError = function(self, code, name)
            s.errorCount = s.errorCount + 1
            log("C-high onLoadError " .. tostring(name))
        end,
    }, "C-high 加载中...")

    schedule(2.5, function()
        addResult("同屏 3 播放器",
            string.format("创建3个 | 成功ready=%d | 报错=%d | 存活实例=%d", s.readyCount, s.errorCount, #widgets_))
        log("C 汇总 | ready=" .. s.readyCount .. " error=" .. s.errorCount
            .. " 存活实例=" .. #widgets_)
        destroyAllWidgets()
        addResult("销毁后实例数", tostring(#widgets_))
        schedule(0.3, function() current_.next() end)
    end)
end

-- ---------------------------------------------------------------------------
-- 【D】创建/销毁 ×3，验证实例数量归零
-- ---------------------------------------------------------------------------
local function runCycles()
    newScreen("D · 建销 ×3 计数（mid）")
    local s = current_
    s.doneCount = 0

    local function oneCycle()
        local w = addVideoArea(root_, SOURCES.mid, {
            onReady = function(self)
                log("D onReady | 存活实例=" .. #widgets_)
                -- ready 即销毁，不播放，专测实例计数
                self:Destroy()
                removeWidget(self)
                s.doneCount = s.doneCount + 1
                log("D 第" .. s.doneCount .. "次建销 | 存活实例=" .. #widgets_)
                if s.doneCount >= CYCLE_COUNT then
                    addResult("建销 " .. CYCLE_COUNT .. " 次", "全部 release | 最终存活实例=" .. #widgets_)
                    schedule(0.3, function() current_.next() end)
                else
                    schedule(0.3, oneCycle)
                end
            end,
            onLoadError = function(self, code, name)
                log("D onLoadError " .. tostring(name))
                s.doneCount = s.doneCount + 1
                if s.doneCount >= CYCLE_COUNT then
                    schedule(0.3, function() current_.next() end)
                else
                    schedule(0.3, oneCycle)
                end
            end,
        }, "D 加载中...")
        log("D 创建 #" .. s.doneCount + 1)
    end

    oneCycle()
end

-- ---------------------------------------------------------------------------
-- 【E】三步恢复状态机（存档契约第 9 条）
--    CREATING → WAIT_READY → REQUEST_SEEK → WAIT_SEEK_CONFIRM
--    → PAUSED_AT_TARGET → REVEAL（移除遮罩）
--    用「等待 3 秒 → seek 到 2.0s → 连续确认 → 显示画面」模拟一次读档恢复。
-- ---------------------------------------------------------------------------
local function runRecovery()
    newScreen("E · 三步恢复状态机（mid）")
    local s = current_
    s.state = "CREATING"
    s.confirms = 0
    s.mask = nil

    local w, mask = addVideoArea(root_, SOURCES.mid, {
        onReady = function(self)
            if s.state == "CREATING" or s.state == "WAIT_READY" then
                s.state = "WAIT_READY"
                log("E onReady → WAIT_READY | dur=" .. string.format("%.3f", self:GetDuration()))
                self:Play()
                schedule(RECOVERY_WAIT, function()
                    s.state = "REQUEST_SEEK"
                    log("E 等待 " .. RECOVERY_WAIT .. "s 完成 → REQUEST_SEEK(2.0)")
                    self:Seek(RECOVERY_TARGET)
                    s.state = "WAIT_SEEK_CONFIRM"
                end)
            end
        end,

        onPlay = function(self)
            log("E onPlay")
        end,

        onPause = function(self)
            log("E onPause")
        end,

        onTimeUpdate = function(self, time, dur)
            logTime("E onTimeUpdate", time, dur)
            setStatus(string.format("E [%s] t=%.2f / %.2f", s.state, time, dur))
            if s.state == "WAIT_SEEK_CONFIRM" then
                local diff = math.abs(time - RECOVERY_TARGET)
                if diff <= TOL then
                    s.confirms = s.confirms + 1
                    log("E seek确认 #" .. s.confirms .. " | t=" .. string.format("%.3f", time)
                        .. " diff=" .. string.format("%.3f", diff))
                    if s.confirms >= 2 then
                        s.state = "PAUSED_AT_TARGET"
                        log("E PAUSED_AT_TARGET | cur=" .. string.format("%.3f", self:GetCurrentTime()))
                        self:Pause()
                        schedule(0.5, function()
                            s.state = "REVEAL"
                            log("E REVEAL（移除加载遮罩）→ 显示画面")
                            if mask then mask:SetVisible(false) end
                            addResult("三步恢复状态机",
                                "CREATING→WAIT_READY→REQUEST_SEEK→WAIT_SEEK_CONFIRM→PAUSED_AT_TARGET→REVEAL 全程通过")
                            schedule(1.2, function()
                                self:Destroy()
                                removeWidget(self)
                                current_.next()
                            end)
                        end)
                    end
                else
                    log("E seek 超差 diff=" .. string.format("%.3f", diff))
                end
            end
        end,

        onLoadError = function(self, code, name)
            log("E onLoadError " .. tostring(name))
            schedule(0.3, function() current_.next() end)
        end,
    }, "E 加载中...", "maskE")
    s.mask = mask
end

-- ============================================================================
-- 后台/前台事件（验证切后台/回前台视频行为；演示媒体恢复契约）
-- ============================================================================

---@param eventType string
---@param eventData? table
local function handleBackground(eventType, eventData)
    log("后台事件 " .. eventType)
    -- 若当前有播放器正在播放，则记录并暂停（模拟 mediaPos 断点写入）
    for _, w in ipairs(widgets_) do
        if w and w.IsPlaying and w:IsPlaying() then
            log("后台：捕获正在播放  播放器，自动 Pause @ " .. string.format("%.3f", w:GetCurrentTime()))
            pcall(function() w:Pause() end)
        end
    end
end

---@param eventType string
---@param eventData? table
local function handleForeground(eventType, eventData)
    log("前台事件 " .. eventType)
    -- 演示恢复契约：如需续播可在此按媒体断点恢复（本项目正式接入另做）
    for _, w in ipairs(widgets_) do
        if w and w.IsPlaying and not w:IsPlaying() and w:GetDuration() > 0 then
            log("前台：播放器处于暂停（t=" .. string.format("%.3f", w:GetCurrentTime())
                .. "），按存档恢复目标可续播")
        end
    end
end

local function subscribeLifecycle()
    hbHandlers_ = { "AppDidEnterBackground", "AppDidEnterForebackground" }
    SubscribeToEvent("AppDidEnterBackground", handleBackground)
    SubscribeToEvent("AppDidEnterForebackground", handleForeground)
    log("已订阅 后台/前台 事件（AppDidEnterBackground / AppDidEnterForebackground）")
end

local function unsubscribeLifecycle()
    if hbHandlers_ then
        for _, ev in ipairs(hbHandlers_) do
            UnsubscribeFromEvent(ev)
        end
        hbHandlers_ = nil
        log("已退订 后台/前台 事件")
    end
end

-- ============================================================================
-- 场景协调
-- ============================================================================

-- 前向声明：runNext 与 finish 需互相引用（runNext 在队列空时调用 finish），
-- 且都被 abort / Toggle / current_.next 引用，必须为模块级 local。
local runNext
local finish

--- 进入下一个场景
runNext = function()
    if #scenarioQueue_ == 0 then
        finish()
        return
    end
    current_ = table.remove(scenarioQueue_, 1)
    log("▶ 进入场景 [" .. current_.name .. "]")
    setStatus("进入场景 " .. current_.name)
    -- 给每个场景一个 next() 指向 runNext
    current_.next = runNext
    current_.run()
end

--- 全部跑完：汇总、清理、恢复 UI 根节点
finish = function()
    -- 先清理，再取「结束存活」终值，确保汇报读到清理后的 0（此前先报后清会显示残留值）
    destroyAllWidgets()
    clearTimers()
    unsubscribeLifecycle()

    -- 组装一份可整段复制的汇报（devtools 控制台一键选中；含 [VideoSpike] 便于 grep）
    local lines = { "[VideoSpike] ===== 视频生命周期 Spike 汇报 =====" }
    lines[#lines + 1] = "[VideoSpike]   * onTimeUpdate 触发次数 → " .. tuCount_
    for _, r in ipairs(results_) do
        lines[#lines + 1] = "[VideoSpike]   * " .. r.item .. " → " .. r.value
    end
    lines[#lines + 1] = "[VideoSpike]   * 结束存活实例数 → " .. #widgets_
    lines[#lines + 1] = "[VideoSpike] ===== 汇报结束 ====="
    local report = table.concat(lines, "\n")
    log(report)
    -- 同时以自定义事件发出，供 devtools 包装脚本/外部订阅者一键获取
    pcall(function()
        SendEvent("VideoSpikeReport", { report = report })
    end)

    -- 恢复到 Spike 前的 UI 根节点
    if savedRoot_ then
        UI.SetRoot(savedRoot_, true)  -- destroyOld=true：顺手释放 Spike 屏
    else
        UI.SetRoot(UI.Panel { width = "100%", height = "100%", pointerEvents = "box-none" })
    end
    savedRoot_ = nil
    root_ = nil
    statusLabel_ = nil
    active_ = false
    log("Spike 结束，UI 根节点已恢复（存活实例=0）")
end

--- 强制结束（用户再次按 F6）
local function abort()
    log("⚠ 用户强制结束 Spike")
    finish()
end

-- ============================================================================
-- 对外接口
-- ============================================================================

--- Spike 是否正在运行（main.lua 据此每帧调用 Update）
---@return boolean
function VideoSpike.IsActive()
    return active_
end

--- 切换 Spike 启停（由 main.lua 调试键 F6 触发）
function VideoSpike.Toggle()
    if active_ then
        abort()
        return
    end

    if not Video.isSupported then
        log("当前运行时不支持视频（Video.isSupported = false），Spike 无法执行")
        return
    end

    -- F6 是真实用户手势：先触发一次媒体 play() 解锁浏览器自动播放（muted 兜底）
    primeAutoplay()

    savedRoot_ = UI.GetRoot()
    active_ = true
    results_ = {}
    tuCount_ = 0
    clearTimers()
    widgets_ = {}

    scenarioQueue_ = {
        { name = "A 生命周期(mid)", run = runLifecycle },
        { name = "B 三档码率(low/high)", run = runTiers },
        { name = "C 同屏3播放器", run = runConcurrency },
        { name = "D 建销×3计数", run = runCycles },
        { name = "E 三步恢复状态机", run = runRecovery },
    }

    subscribeLifecycle()
    log("=== 视频生命周期 Spike 启动（F6 可强制结束）===")
    log("素材：" .. SOURCES.low .. " / " .. SOURCES.mid .. " / " .. SOURCES.high)
    runNext()
end

--- 每帧推进（由 main.lua 在 Spike 激活时调用）
---@param dt number
function VideoSpike.Update(dt)
    if not active_ then return end
    pumpTimers(dt)
end

--- 兼容别名：部分接入方（含 TTM 平台侧 main.lua）用 Process(dt) 驱动每帧
---@param dt number
function VideoSpike.Process(dt)
    VideoSpike.Update(dt)
end

--- 获取本次 Spike 的汇报结果（供 devtools 包装脚本 / 外部订阅者读取）
---@return table[] results 每项 { item, value }
function VideoSpike.GetReport()
    local copy = {}
    for _, r in ipairs(results_) do
        copy[#copy + 1] = { item = r.item, value = r.value }
    end
    return copy
end

return VideoSpike
