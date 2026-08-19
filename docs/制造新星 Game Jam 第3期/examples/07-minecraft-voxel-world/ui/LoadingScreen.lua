-- ====================================================================
-- ui/LoadingScreen.lua
-- Loading screen with progress bar
-- Uses urhox-libs/UI with Yoga layout
-- ====================================================================

local UI = require("urhox-libs/UI/init")

---@class LoadingScreen
local LoadingScreen = {}

-- UI references
local root_ = nil
local progressBar_ = nil
local phaseLabel_ = nil
local percentLabel_ = nil

-- Phase display names (中文)
local PHASE_NAMES = {
    terrain = "生成地形",
    trees = "种植树木",
    vegetation = "添加植被",
    heights = "计算高度",
    chunks = "构建区块",
    complete = "加载完成",
}

-- Phase weights for overall progress
local PHASE_WEIGHTS = {
    terrain = 0.50,     -- 50%
    trees = 0.10,       -- 10%
    vegetation = 0.10,  -- 10%
    heights = 0.20,     -- 20%
    chunks = 0.10,      -- 10%
}

-- Cumulative progress offsets
local PHASE_OFFSETS = {
    terrain = 0,
    trees = 0.50,
    vegetation = 0.60,
    heights = 0.70,
    chunks = 0.90,
    complete = 1.0,
}

---Show the loading screen
function LoadingScreen.show()
    if root_ then
        return  -- Already shown
    end

    -- Create full-screen overlay
    root_ = UI.Panel {
        id = "loading_screen",
        width = "100%",
        height = "100%",
        position = "absolute",
        top = 0,
        left = 0,
        backgroundColor = { 20, 20, 30, 255 },  -- Dark blue-gray
        justifyContent = "center",
        alignItems = "center",
        paddingTop = 120,  -- 整体向下偏移
        pointerEvents = "auto",  -- Block all input

        -- Content container
        UI.Panel {
            id = "loading_content",
            width = 400,
            alignItems = "center",
            gap = 20,

            -- Title
            UI.Label {
                id = "loading_title",
                text = "加载世界",
                fontSize = 28,
                fontColor = { 255, 255, 255, 255 },
                textAlign = "center",
            },

            -- Phase label
            UI.Label {
                id = "loading_phase",
                text = "初始化中...",
                fontSize = 16,
                fontColor = { 180, 180, 200, 255 },
                textAlign = "center",
            },

            -- Progress bar container
            UI.Panel {
                id = "progress_container",
                width = "100%",
                height = 24,
                backgroundColor = { 40, 40, 50, 255 },
                borderRadius = 12,
                overflow = "hidden",

                -- Progress fill
                UI.Panel {
                    id = "progress_fill",
                    width = 0,  -- Will be updated
                    height = "100%",
                    backgroundColor = { 80, 180, 80, 255 },  -- Green
                    borderRadius = 12,
                },
            },

            -- Percentage label
            UI.Label {
                id = "loading_percent",
                text = "0%",
                fontSize = 14,
                fontColor = { 150, 150, 170, 255 },
                textAlign = "center",
            },

            -- Tip text
            UI.Label {
                id = "loading_tip",
                text = "提示：按 F 键切换飞行模式",
                fontSize = 12,
                fontColor = { 100, 100, 120, 255 },
                textAlign = "center",
                marginTop = 40,
            },
        },
    }

    -- Store references for quick updates
    phaseLabel_ = root_:FindById("loading_phase")
    progressBar_ = root_:FindById("progress_fill")
    percentLabel_ = root_:FindById("loading_percent")

    -- Add to UI root
    local existingRoot = UI.GetRoot()
    if existingRoot then
        existingRoot:AddChild(root_)
    else
        UI.SetRoot(root_)
    end

    print("[LoadingScreen] Shown")
end

---Hide the loading screen
function LoadingScreen.hide()
    if root_ then
        root_:Destroy()
        root_ = nil
        progressBar_ = nil
        phaseLabel_ = nil
        percentLabel_ = nil
        print("[LoadingScreen] Hidden")
    end
end

---Update the loading progress
---@param progress table { phase: string, current: number, total: number }
function LoadingScreen.setProgress(progress)
    if not root_ then
        return
    end

    local phase = progress.phase or "terrain"
    local current = progress.current or 0
    local total = progress.total or 1

    -- Calculate phase progress (0-1)
    local phaseProgress = total > 0 and (current / total) or 0

    -- Calculate overall progress using weights
    local overallProgress
    if phase == "complete" then
        overallProgress = 1.0
    else
        local offset = PHASE_OFFSETS[phase] or 0
        local weight = PHASE_WEIGHTS[phase] or 0.1
        overallProgress = offset + (phaseProgress * weight)
    end

    -- Clamp to 0-1
    overallProgress = math.max(0, math.min(1, overallProgress))

    -- Update phase label
    if phaseLabel_ then
        local phaseName = PHASE_NAMES[phase] or phase
        phaseLabel_:SetText(phaseName)
    end

    -- Update progress bar width (percentage of container)
    if progressBar_ then
        local containerWidth = 400  -- Match progress_container width
        local fillWidth = math.floor(containerWidth * overallProgress)
        progressBar_:SetStyle({ width = fillWidth })
    end

    -- Update percentage label
    if percentLabel_ then
        local percent = math.floor(overallProgress * 100)
        percentLabel_:SetText(percent .. "%")
    end
end

---Check if loading screen is visible
---@return boolean
function LoadingScreen.isVisible()
    return root_ ~= nil
end

return LoadingScreen
