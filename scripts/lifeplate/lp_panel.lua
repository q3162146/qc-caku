-- ============================================================================
-- scripts/lifeplate/lp_panel.lua
-- 《命盘·改命》实验模块：命盘面板 UI（urhox-libs/UI，竖屏响应式）
-- 观盘态：印面 + 三道印文 + 太极小章 + 档位 chip
-- 落印：磬 + 震动 + 朱砂晕开 + 太极轻转；跨线「蓄力→爆发」
-- ============================================================================

local UI = require "urhox-libs/UI"
local Config = require "lifeplate.lp_config"
local Rules = require "lifeplate.lp_rules"

local M = {}

---@class LPPanelRefs
---@field root SafeAreaView
---@field yearLabel Label
---@field mottoLabel Label
---@field nodeTitle Label
---@field promptLabel Label
---@field virtueLabel Label
---@field sealFace Panel
---@field taiji Panel
---@field vermilion Panel
---@field choiceRow Panel
---@field actionBtn Button
---@field choiceBtns Button[]
---@field feedbackLabel Label
---@field endingCard Panel
---@field endingTitle Label
---@field endingScroll Label
---@field palace table<string, LPPalaceView>
---@field onSelectIndex fun(index: number)|nil

local refs_ = nil ---@type LPPanelRefs|nil
local onStamp_ = nil ---@type function|nil
local onRestart_ = nil ---@type function|nil
local selectedKey_ = nil ---@type string|nil
local anim_ = {
    taijiRot = 0,
    taijiSpin = 0,
    vermilion = 0,
    burst = 0,
    charge = 0,
    charging = false,
}

local PALACE_KEYS = { "ming", "yuan", "cheng" }

local function log(msg)
    print("[lp 模块][panel] " .. msg)
end

local function rgba(c, a)
    return { c[1], c[2], c[3], a or c[4] or 255 }
end

---@class LPPalaceView
---@field key string
---@field block Panel
---@field nameLabel Label
---@field valueLabel Label
---@field chip Chip

---@param palace table
---@return LPPalaceView
local function makePalaceBlock(palace)
    local valueLabel = UI.Label {
        id = "lp_val_" .. palace.key,
        text = "天定 0",
        fontSize = 13,
        fontColor = rgba(palace.color),
        textAlign = "center",
    }
    local nameLabel = UI.Label {
        id = "lp_name_" .. palace.key,
        text = palace.name .. " · " .. palace.motto,
        fontSize = 16,
        fontWeight = "bold",
        fontColor = rgba(palace.color),
        textAlign = "center",
    }
    local chip = UI.Chip {
        id = "lp_chip_" .. palace.key,
        label = "平 · 蓝",
        variant = "filled",
        color = "primary",
        size = "sm",
    }
    local block = UI.Panel {
        id = "lp_palace_" .. palace.key,
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        alignItems = "center",
        gap = 4,
        paddingV = 6,
        paddingH = 4,
        backgroundColor = { 255, 248, 236, 72 },
        borderRadius = 10,
        children = { nameLabel, valueLabel, chip },
    }
    return {
        key = palace.key,
        block = block,
        nameLabel = nameLabel,
        valueLabel = valueLabel,
        chip = chip,
    }
end

---@param state LPState
---@param extra table|nil
function M.Refresh(state, extra)
    if refs_ == nil then return end
    extra = extra or {}
    local node = Rules.currentNode(state)
    local finished = Rules.isFinished(state)
    local finals = Rules.finals(state)

    if node ~= nil and not finished then
        refs_.yearLabel:SetText("第 " .. tostring(node.age) .. " 岁 · " .. Config.MASTER_NAME)
        refs_.nodeTitle:SetText(node.kind .. " · " .. node.title)
        refs_.promptLabel:SetText(node.prompt)
        refs_.promptLabel:SetVisible(true)
        refs_.choiceRow:SetVisible(true)
        refs_.actionBtn:SetVisible(true)
        refs_.endingCard:SetVisible(false)
    else
        refs_.yearLabel:SetText("终局 · " .. Config.MASTER_NAME)
        refs_.nodeTitle:SetText("长卷铺开")
        refs_.promptLabel:SetVisible(false)
        refs_.choiceRow:SetVisible(false)
        refs_.actionBtn:SetVisible(false)
        refs_.endingCard:SetVisible(true)
    end

    refs_.mottoLabel:SetText(Config.PALACE_MOTTO)
    refs_.virtueLabel:SetText("功德 " .. tostring(state.virtue))

    for i = 1, #PALACE_KEYS do
        local key = PALACE_KEYS[i]
        local palace = refs_.palace[key]
        local value = finals[key]
        local band = Rules.bandOf(value)
        palace.valueLabel:SetText(string.format("%+d", value))
        palace.valueLabel:SetFontColor(band.color)
        palace.chip:SetLabel(band.name .. " · " .. band.grade)
        palace.chip:SetColor(band.chip)
        palace.block:SetBackgroundColor({ band.color[1], band.color[2], band.color[3], 36 })
        if extra.crossed and extra.crossed[key] then
            palace.block:SetBorderColor({ 196, 48, 36, 220 })
            palace.block:SetBorderWidth(2)
        else
            palace.block:SetBorderColor({ 0, 0, 0, 0 })
            palace.block:SetBorderWidth(0)
        end
    end

    -- 选择按钮：按当前节点重建文本/可用态
    if node ~= nil and not finished then
        for i = 1, 3 do
            local btn = refs_.choiceBtns[i]
            local choice = node.choices[i]
            if choice ~= nil then
                btn:SetVisible(true)
                btn:SetDisabled(false)
                btn:SetText(choice.label)
                if selectedKey_ == choice.key then
                    btn:SetBackgroundColor({ 168, 36, 28, 230 })
                    btn:SetText("● " .. choice.label)
                else
                    btn:SetBackgroundColor({ 56, 36, 32, 210 })
                    btn:SetText(choice.label)
                end
            else
                btn:SetVisible(false)
                btn:SetDisabled(true)
            end
        end
        refs_.actionBtn:SetDisabled(selectedKey_ == nil)
        if extra.charging then
            refs_.actionBtn:SetText("蓄力…")
        elseif extra.bursting then
            refs_.actionBtn:SetText("改命！")
        else
            refs_.actionBtn:SetText("历一岁·落印")
        end
    end
end

---@param ending table
function M.ShowEnding(ending)
    if refs_ == nil then return end
    refs_.endingTitle:SetText(ending.title)
    refs_.endingScroll:SetText(ending.scroll)
    refs_.endingCard:SetVisible(true)
    refs_.choiceRow:SetVisible(false)
    refs_.actionBtn:SetVisible(false)
    refs_.promptLabel:SetVisible(false)
    log("长卷铺开 | ending=" .. tostring(ending.key))
end

---@param msg string
---@param kind string|nil
function M.Toast(msg, kind)
    if refs_ == nil then return end
    kind = kind or "info"
    refs_.feedbackLabel:SetText(msg)
    if kind == "success" then
        refs_.feedbackLabel:SetFontColor({ 132, 36, 28, 255 })
    elseif kind == "warning" then
        refs_.feedbackLabel:SetFontColor({ 132, 72, 28, 255 })
    else
        refs_.feedbackLabel:SetFontColor({ 92, 64, 48, 255 })
    end
end

--- 朱砂晕开 + 太极轻转；跨线时蓄力→爆发
---@param crossed boolean
function M.PlayStampFeedback(crossed)
    anim_.vermilion = 1.0
    anim_.taijiSpin = crossed and 420 or 160
    if crossed then
        anim_.charging = true
        anim_.charge = 0
        anim_.burst = 0
        log("跨线反馈：蓄力→爆发")
    else
        anim_.charging = false
        anim_.burst = 0.55
        log("落印反馈：朱砂晕开")
    end
end

---@param dt number
function M.Update(dt)
    if refs_ == nil then return end

    if anim_.charging then
        anim_.charge = anim_.charge + dt * 1.35
        if anim_.charge >= 1 then
            anim_.charging = false
            anim_.burst = 1
            anim_.taijiSpin = anim_.taijiSpin + 280
            log("爆发")
        end
        local pulse = 0.72 + 0.28 * math.sin(anim_.charge * 14)
        refs_.sealFace:SetOpacity(pulse)
        refs_.actionBtn:SetText("蓄力…")
    else
        refs_.sealFace:SetOpacity(1)
    end

    if anim_.burst > 0 then
        anim_.burst = math.max(0, anim_.burst - dt * 1.4)
        local a = math.floor(70 + 150 * anim_.burst)
        refs_.sealFace:SetBorderColor({ 196, 36, 28, a })
        refs_.sealFace:SetBorderWidth(2 + 6 * anim_.burst)
    else
        refs_.sealFace:SetBorderWidth(1)
        refs_.sealFace:SetBorderColor({ 120, 72, 48, 90 })
    end

    if anim_.vermilion > 0 then
        anim_.vermilion = math.max(0, anim_.vermilion - dt * 0.85)
        refs_.vermilion:SetVisible(true)
        refs_.vermilion:SetOpacity(anim_.vermilion * 0.72)
    else
        refs_.vermilion:SetVisible(false)
        refs_.vermilion:SetOpacity(0)
    end

    if anim_.taijiSpin > 0 then
        local step = math.min(anim_.taijiSpin, 240 * dt)
        anim_.taijiRot = (anim_.taijiRot + step) % 360
        anim_.taijiSpin = anim_.taijiSpin - step
        refs_.taiji:SetStyle({ rotate = anim_.taijiRot })
        refs_.taiji:SetOpacity(1)
    else
        refs_.taiji:SetStyle({ rotate = anim_.taijiRot })
        refs_.taiji:SetOpacity(1)
    end
end

---@return string|nil
function M.GetSelectedKey()
    return selectedKey_
end

function M.ClearSelection()
    selectedKey_ = nil
end

---@param key string|nil
function M.SetSelectedKey(key)
    selectedKey_ = key
end

---@param cb function
function M.SetOnStamp(cb)
    onStamp_ = cb
end

---@param cb function
function M.SetOnRestart(cb)
    onRestart_ = cb
end

local function selectChoice(index)
    if refs_ == nil then return end
    log("点选选项 index=" .. tostring(index))
    if refs_.onSelectIndex then
        refs_.onSelectIndex(index)
    end
end

---@param fn fun(index: number)
function M.SetOnSelectIndex(fn)
    if refs_ ~= nil then
        refs_.onSelectIndex = fn
    end
end

---@return Widget
function M.Create()
    selectedKey_ = nil
    anim_.taijiRot = 0
    anim_.taijiSpin = 0
    anim_.vermilion = 0
    anim_.burst = 0
    anim_.charge = 0
    anim_.charging = false

    local yearLabel = UI.Label {
        id = "lp_year",
        text = "第 16 岁 · 命主",
        fontSize = 20,
        fontWeight = "bold",
        fontColor = { 42, 28, 22, 255 },
        textAlign = "center",
    }
    local mottoLabel = UI.Label {
        id = "lp_motto",
        text = Config.PALACE_MOTTO,
        fontSize = 13,
        fontColor = { 92, 72, 56, 255 },
        textAlign = "center",
    }
    local nodeTitle = UI.Label {
        id = "lp_node_title",
        text = "正 · 束发初遇",
        fontSize = 16,
        fontColor = { 132, 36, 28, 255 },
        textAlign = "center",
    }
    local promptLabel = UI.Label {
        id = "lp_prompt",
        text = "",
        fontSize = 14,
        fontColor = { 56, 44, 36, 255 },
        textAlign = "center",
        whiteSpace = "normal",
        maxLines = 3,
    }
    local virtueLabel = UI.Label {
        id = "lp_virtue",
        text = "功德 0",
        fontSize = 13,
        fontColor = { 132, 92, 36, 255 },
        textAlign = "center",
    }
    local feedbackLabel = UI.Label {
        id = "lp_feedback",
        text = "观盘 · 先选一印",
        fontSize = 13,
        fontColor = { 92, 64, 48, 255 },
        textAlign = "center",
        whiteSpace = "normal",
        maxLines = 2,
    }

    local palaceRefs = {}
    local palaceRowChildren = {}
    for i = 1, #Config.PALACES do
        local block = makePalaceBlock(Config.PALACES[i])
        palaceRefs[block.key] = block
        palaceRowChildren[#palaceRowChildren + 1] = block.block
    end
    local palaceRow = UI.Panel {
        id = "lp_palace_row",
        width = "100%",
        flexDirection = "row",
        gap = 8,
        children = palaceRowChildren,
    }

    local vermilion = UI.Panel {
        id = "lp_vermilion",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        borderRadius = 12,
        backgroundColor = { 176, 28, 22, 120 },
        pointerEvents = "none",
        visible = false,
        opacity = 0,
    }

    local taiji = UI.Panel {
        id = "lp_taiji",
        width = 72,
        height = 72,
        borderRadius = 36,
        backgroundImage = Config.ASSETS.taiji,
        backgroundFit = "contain",
        backgroundColor = { 0, 0, 0, 0 },
    }

    local sealFace = UI.Panel {
        id = "lp_seal_face",
        width = "86%",
        aspectRatio = 1,
        maxWidth = 360,
        maxHeight = 360,
        borderRadius = 12,
        backgroundImage = Config.ASSETS.sealFace,
        backgroundFit = "cover",
        borderWidth = 1,
        borderColor = { 120, 72, 48, 90 },
        justifyContent = "center",
        alignItems = "center",
        overflow = "hidden",
        children = { taiji, vermilion },
    }

    local choiceBtns = {}
    for i = 1, 3 do
        local idx = i
        choiceBtns[i] = UI.Button {
            id = "lp_choice_" .. i,
            text = "选项" .. i,
            variant = "secondary",
            width = "100%",
            height = 44,
            fontSize = 14,
            backgroundColor = { 56, 36, 32, 210 },
            textColor = { 255, 244, 230, 255 },
            onClick = function()
                selectChoice(idx)
            end,
        }
    end
    local choiceRow = UI.Panel {
        id = "lp_choices",
        width = "100%",
        flexDirection = "column",
        gap = 8,
        children = choiceBtns,
    }

    local actionBtn = UI.Button {
        id = "lp_stamp_btn",
        text = "历一岁·落印",
        variant = "primary",
        width = "100%",
        height = 52,
        fontSize = 18,
        backgroundColor = { 168, 36, 28, 255 },
        textColor = { 255, 244, 230, 255 },
        onClick = function()
            if onStamp_ ~= nil then
                onStamp_()
            end
        end,
    }

    local endingTitle = UI.Label {
        id = "lp_ending_title",
        text = "",
        fontSize = 22,
        fontWeight = "bold",
        fontColor = { 132, 36, 28, 255 },
        textAlign = "center",
    }
    local endingScroll = UI.Label {
        id = "lp_ending_scroll",
        text = "",
        fontSize = 14,
        fontColor = { 48, 36, 28, 255 },
        textAlign = "center",
        whiteSpace = "normal",
        maxLines = 6,
    }
    local restartBtn = UI.Button {
        text = "再走一局",
        variant = "secondary",
        width = "100%",
        height = 44,
        onClick = function()
            if onRestart_ ~= nil then
                onRestart_()
            end
        end,
    }
    local endingCard = UI.Panel {
        id = "lp_ending",
        width = "100%",
        padding = 16,
        gap = 10,
        backgroundColor = { 255, 248, 236, 230 },
        borderRadius = 12,
        visible = false,
        children = { endingTitle, endingScroll, restartBtn },
    }

    local content = UI.Panel {
        id = "lp_content",
        width = "100%",
        flexDirection = "column",
        alignItems = "center",
        gap = 10,
        paddingH = 18,
        paddingV = 12,
        children = {
            yearLabel,
            mottoLabel,
            virtueLabel,
            sealFace,
            palaceRow,
            nodeTitle,
            promptLabel,
            feedbackLabel,
            choiceRow,
            actionBtn,
            endingCard,
        },
    }

    local scroller = UI.ScrollView {
        id = "lp_scroll",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexShrink = 1,
        scrollY = true,
        showScrollbar = false,
        children = { content },
    }

    local root = UI.SafeAreaView {
        id = "lp_root",
        edges = "all",
        nativeMenuInset = true,
        width = "100%",
        height = "100%",
        backgroundImage = Config.ASSETS.inkBg,
        backgroundFit = "cover",
        backgroundColor = { 236, 226, 208, 255 },
        children = { scroller },
    }

    refs_ = {
        root = root,
        yearLabel = yearLabel,
        mottoLabel = mottoLabel,
        nodeTitle = nodeTitle,
        promptLabel = promptLabel,
        virtueLabel = virtueLabel,
        sealFace = sealFace,
        taiji = taiji,
        vermilion = vermilion,
        choiceRow = choiceRow,
        choiceBtns = choiceBtns,
        actionBtn = actionBtn,
        feedbackLabel = feedbackLabel,
        endingCard = endingCard,
        endingTitle = endingTitle,
        endingScroll = endingScroll,
        palace = palaceRefs,
        onSelectIndex = nil,
    }

    UI.SetRoot(root)
    log("命盘面板已创建")
    return root
end

function M.Destroy()
    refs_ = nil
    selectedKey_ = nil
    onStamp_ = nil
    onRestart_ = nil
    log("命盘面板已销毁")
end

return M
