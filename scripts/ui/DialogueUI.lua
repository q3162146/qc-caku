-- ============================================================================
-- ui/DialogueUI.lua
-- 对话 + 三选：共用 StoryPanel 外壳；台词固定 2 行分页；三选右侧立绘。
-- ============================================================================

local UI = require "urhox-libs/UI"
local InputManager = require "game.InputManager"
local GameAudio = require "audio.GameAudio"
local VoiceMap = require "config.VoiceMap"
local StoryPanel = require "ui.StoryPanel"

local DialogueUI = {}

---@type boolean
local open_ = false
---@type table|nil
local state_ = nil
---@type Panel|nil
local layer_ = nil

-- ② 三选整屏应景底：直接透出 3D 场景（D1 Skybox = 水墨全景），不再铺静态图。
--    sceneBackdrop 保留：无 3D 场景的兜底环境（如纯 UI 调试）不使用。

local NPC_PORTRAIT = {
    ["守桃老人"] = "image/立绘/守桃老人.jpg",
    ["无面鬼"] = "image/立绘/无面鬼.png",
    ["素女"] = "image/立绘/素女.jpg",
    ["无幽"] = "image/立绘/无幽.jpg",
    ["旁白"] = "image/立绘/素女.jpg",
}

---@return Widget|nil
local function hudRoot()
    return UI.GetRoot()
end

local function ensureLayer()
    if layer_ ~= nil then return layer_ end
    local root = hudRoot()
    if root == nil then return nil end
    layer_ = UI.Panel {
        id = "dialogueLayer",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
        zIndex = 90,
        visible = false,
    }
    root:AddChild(layer_)
    return layer_
end

local function mountRoot(panel)
    local layer = ensureLayer()
    if layer == nil then
        print("[DialogueUI] 对话层挂载失败：HUD 根不存在")
        return
    end
    layer:ClearChildren()
    layer:AddChild(panel)
    layer:SetVisible(true)
end

---@return string
local function npcPortrait()
    local npc = state_ and state_.spec and state_.spec.npc
    if npc ~= nil and NPC_PORTRAIT[npc] ~= nil then
        return NPC_PORTRAIT[npc]
    end
    return "image/立绘/守桃老人.jpg"
end

local function currentPages()
    local s = state_
    if s == nil then return { "" } end
    return s.pages or { "" }
end

local function rebuildPages()
    local s = state_
    if s == nil then return end
    local spec = s.spec
    local lines = spec.lines or spec.intro or {}
    local raw = lines[s.lineIndex] or ""
    s.pages = StoryPanel.Paginate(raw)
    s.pageIndex = 1
end

function DialogueUI.IsOpen()
    return open_
end

function DialogueUI.Hide()
    if not open_ then return end
    GameAudio.StopVoice()
    if layer_ ~= nil then
        layer_:ClearChildren()
        layer_:SetVisible(false)
    end
    open_ = false
    state_ = nil
end

---@param spec table
function DialogueUI.ShowDialogue(spec)
    state_ = {
        spec = spec,
        phase = "text",
        lineIndex = 1,
        pageIndex = 1,
        pages = {},
        locked = false,
        onDone = spec.onDone,
        onChoose = nil,
    }
    open_ = true
    rebuildPages()
    RenderText()
end

---@param spec table
function DialogueUI.ShowChoice(spec)
    state_ = {
        spec = spec,
        phase = "text",
        lineIndex = 1,
        pageIndex = 1,
        pages = {},
        locked = false,
        onDone = nil,
        onChoose = spec.onChoose,
    }
    open_ = true
    rebuildPages()
    RenderText()
end

function DialogueUI.HandleInput()
    if not open_ or state_ == nil then return end
    if state_.phase ~= "text" then return end
    if InputManager.IsKeyPress(KEY_SPACE) or InputManager.IsKeyPress(KEY_RETURN) then
        AdvanceText()
    end
end

function RenderText()
    local s = state_
    if s == nil then return end
    local spec = s.spec
    local pages = currentPages()
    local text = pages[s.pageIndex] or ""
    local npc = spec.npc or ""
    local lines = spec.lines or spec.intro or {}
    local moreInLine = s.pageIndex < #pages
    local moreLines = s.lineIndex < #lines
    local hasMore = moreInLine or moreLines
    if s.pageIndex == 1 then
        local voice = VoiceMap.Get(spec.linesKey, s.lineIndex)
        if voice ~= nil then
            GameAudio.PlayVoice(voice)
        end
    end

    local shell = StoryPanel.Wrap({
        UI.Label {
            text = npc,
            fontSize = StoryPanel.NAME_SIZE,
            fontColor = StoryPanel.NAME_COLOR,
            width = "100%",
            visible = npc ~= "",
        },
        UI.Label {
            text = text,
            fontSize = StoryPanel.LINE_SIZE,
            fontColor = StoryPanel.TEXT_COLOR,
            width = "100%",
            maxLines = 2,
            lineHeight = 1.4,
            whiteSpace = "normal",
            marginTop = 8,
            textStroke = { width = 0.8, color = { 16, 10, 8, 160 } },
        },
        UI.Button {
            text = hasMore and "下一步" or "下一步",
            variant = "secondary",
            alignSelf = "flex-end",
            height = StoryPanel.BTN_HEIGHT,
            marginTop = 12,
            onClick = function()
                AdvanceText()
            end,
        },
    })
    mountRoot(UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
        children = { shell },
    })
end

function AdvanceText()
    local s = state_
    if s == nil or s.locked then return end
    local spec = s.spec
    local pages = currentPages()
    if s.pageIndex < #pages then
        GameAudio.PlaySfx("audio/sfx/sfx_ui_page.mp3")
        s.pageIndex = s.pageIndex + 1
        RenderText()
        return
    end
    local lines = spec.lines or spec.intro or {}
    if s.lineIndex < #lines then
        GameAudio.PlaySfx("audio/sfx/sfx_ui_page.mp3")
        s.lineIndex = s.lineIndex + 1
        rebuildPages()
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

function RenderChoice()
    local s = state_
    if s == nil then return end
    local spec = s.spec
    local inner = {
        UI.Label {
            text = spec.prompt or "",
            fontSize = StoryPanel.PROMPT_SIZE,
            fontColor = StoryPanel.TEXT_COLOR,
            width = "100%",
            maxLines = 2,
            lineHeight = 1.4,
            whiteSpace = "normal",
            textStroke = { width = 0.8, color = { 16, 10, 8, 160 } },
        },
    }
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
                height = StoryPanel.BTN_HEIGHT,
                marginTop = 8,
                onClick = function()
                    if s.locked then return end
                    GameAudio.PlaySfx("audio/sfx/sfx_ui_click.mp3")
                    s.locked = true
                    for _, b in ipairs(buttons) do
                        b:SetDisabled(true)
                    end
                    Finish(key)
                end,
            }
            table.insert(buttons, btn)
            table.insert(inner, btn)
        end
    end

    local shell = StoryPanel.Wrap(inner)
    -- ② 三选整屏应景底：不再铺静态图，直接透出 3D 场景（D1 Skybox 即水墨全景）。
    --    panel 不设任何背景色，仅叠线性渐变压暗保证选项可读。
    local portrait = UI.Panel {
        position = "absolute",
        right = 0,
        top = "12%",
        width = "42%",
        height = "58%",
        pointerEvents = "none",
    }
    local dimmer = UI.Panel {
        position = "absolute",
        top = 0, left = 0,
        width = "100%",
        height = "100%",
        -- ② 压暗改线性渐变：上部透出整屏水墨，下部加深保证选项可读可点
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 12, 8, 6, 30 },
            to = { 12, 8, 6, 150 },
        },
        pointerEvents = "none",
    }
    local panel = UI.Panel {
        position = "absolute",
        top = 0, left = 0,
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
    }
    panel:AddChild(dimmer)
    panel:AddChild(portrait)
    panel:AddChild(shell)
    mountRoot(panel)
    -- 右侧立绘：挂树后设图（NPC 辨识保留）
    portrait:SetBackgroundImage(npcPortrait())
end

---@param choiceKey string|nil
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
