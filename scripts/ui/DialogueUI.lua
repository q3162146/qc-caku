-- ============================================================================
-- ui/DialogueUI.lua
-- 对话系统表现层（S2）：顺序对白 + 三选交互，统一用 urhox-libs/UI
--
-- 规则（快速开工包 ④ 第 2 条）：常规 UI 一律用 urhox-libs/UI，不混用 raw NanoVG。
-- 选项锁定（《21》§5）：选中后立即锁，防连点双加。
-- 本模块只做表现与输入收集；选择/推进后的数据变化由调用方（FlowController）处理。
-- ============================================================================

local UI = require "urhox-libs/UI"
local InputManager = require "game.InputManager"
local GameAudio = require "audio.GameAudio"
local VoiceMap = require "config.VoiceMap"

local DialogueUI = {}

---@type boolean
local open_ = false
---@type table|nil
local state_ = nil   -- { spec, phase, lineIndex, locked, onDone, onChoose }

--- 对话是否打开（主循环据此停玩家移动）
---@return boolean
function DialogueUI.IsOpen()
    return open_
end

--- 关闭对话（清空 UI 根）
function DialogueUI.Hide()
    if not open_ then return end
    GameAudio.StopVoice()
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", pointerEvents = "box-none" })
    open_ = false
    state_ = nil
end

--- 顺序对白：npc + 多行文本，"继续"或空格/回车逐行推进，播完回调 onDone
---@param spec table { npc?: string, lines: string[], onDone?: function }
function DialogueUI.ShowDialogue(spec)
    state_ = {
        spec = spec,
        phase = "text",
        lineIndex = 1,
        locked = false,
        onDone = spec.onDone,
        onChoose = nil,
    }
    open_ = true
    RenderText()
end

--- 三选交互：先 intro 文本（可选），后 prompt + 选项按钮；选中即锁并回调 onChoose(key)
---@param spec table { npc?: string, intro?: string[], prompt: string, choices: table, choiceOrder?: string[], onChoose: function }
function DialogueUI.ShowChoice(spec)
    state_ = {
        spec = spec,
        phase = "text",
        lineIndex = 1,
        locked = false,
        onDone = nil,
        onChoose = spec.onChoose,
    }
    open_ = true
    RenderText()
end

--- 主循环推进输入（空格/回车 = 继续）
function DialogueUI.HandleInput()
    if not open_ or state_ == nil then return end
    if state_.phase ~= "text" then return end
    if InputManager.IsKeyPress(KEY_SPACE) or InputManager.IsKeyPress(KEY_RETURN) then
        AdvanceText()
    end
end

--- 渲染文本阶段（对话行 / 选择前的 intro 行）
function RenderText()
    local s = state_
    if s == nil then return end
    local spec = s.spec
    local lines = spec.lines or spec.intro or {}
    local hasMore = s.lineIndex < #lines
    local text = lines[s.lineIndex] or ""
    local npc = spec.npc or ""
    local voice = VoiceMap.Get(spec.linesKey, s.lineIndex)
    if voice ~= nil then
        GameAudio.PlayVoice(voice)
    end

    UI.SetRoot(UI.Panel {
        position = "absolute",
        bottom = 0, left = 0, right = 0,
        padding = { 18, 22 },
        backgroundColor = { 16, 14, 24, 228 },
        children = {
            UI.Label {
                text = npc,
                fontSize = 15,
                fontColor = { 255, 214, 158, 255 },
                width = "100%",
            },
            UI.Label {
                text = text,
                fontSize = 18,
                fontColor = { 246, 241, 231, 255 },
                width = "100%",
                maxLines = 5,
                marginTop = 8,
            },
            UI.Button {
                text = hasMore and "继续 ›" or "下一步",
                variant = "secondary",
                alignSelf = "flex-end",
                marginTop = 10,
                onClick = function()
                    AdvanceText()
                end,
            },
        },
    })
end

--- 推进一行 / 文本播完进入下一阶段
function AdvanceText()
    local s = state_
    if s == nil or s.locked then return end
    local spec = s.spec
    local lines = spec.lines or spec.intro or {}
    if s.lineIndex < #lines then
        GameAudio.PlaySfx("audio/sfx/sfx_ui_page.mp3")
        s.lineIndex = s.lineIndex + 1
        RenderText()
        return
    end
    if spec.choices then
        s.phase = "choice"
        GameAudio.PlaySfx("audio/sfx/sfx_choice_open.mp3")
        RenderChoice()
    else
        Finish(nil)
    end
end

--- 渲染选择阶段（prompt + 选项按钮，选中即锁）
function RenderChoice()
    local s = state_
    if s == nil then return end
    local spec = s.spec

    local children = {
        UI.Label {
            text = spec.prompt or "",
            fontSize = 18,
            fontColor = { 246, 241, 231, 255 },
            width = "100%",
            maxLines = 3,
        },
    }

    -- 确定性顺序（choiceOrder 未声明时按 pairs 无序）
    local order = spec.choiceOrder
    if order == nil then
        order = {}
        for key in pairs(spec.choices) do
            table.insert(order, key)
        end
    end

    ---@type table[]
    local buttons = {}
    for _, key in ipairs(order) do
        local label = spec.choices[key]
        if label ~= nil then
            local btn = UI.Button {
                text = label,
                variant = "secondary",
                textAlign = "left",
                marginTop = 8,
                onClick = function()
                    if s.locked then return end
                    GameAudio.PlaySfx("audio/sfx/sfx_ui_click.mp3")
                    s.locked = true              -- 选项锁定：防连点双加（《21》§5）
                    for _, b in ipairs(buttons) do
                        b:SetDisabled(true)
                    end
                    Finish(key)
                end,
            }
            table.insert(buttons, btn)
            table.insert(children, btn)
        end
    end

    UI.SetRoot(UI.Panel {
        position = "absolute",
        bottom = 0, left = 0, right = 0,
        padding = { 18, 22 },
        backgroundColor = { 16, 14, 24, 235 },
        children = children,
    })
end

--- 结束对话：关闭 UI 并回调
---@param choiceKey string|nil 选择键（无选择时为 nil）
function Finish(choiceKey)
    local s = state_
    DialogueUI.Hide()
    if s == nil then return end
    if choiceKey ~= nil and s.onChoose ~= nil then
        s.onChoose(choiceKey)
    elseif s.onDone ~= nil then
        s.onDone()
    end
end

return DialogueUI
