-- ============================================================================
-- ui/DialogueUI.lua
-- 对话系统表现层（S2）：顺序对白 + 三选交互，统一用 urhox-libs/UI
--
-- 规则（快速开工包 ④ 第 2 条）：常规 UI 一律用 urhox-libs/UI，不混用 raw NanoVG。
-- 选项锁定（《21》§5）：选中后立即锁，防连点双加。
-- 本模块只做表现与输入收集；选择/推进后的数据变化由调用方（FlowController）处理。
-- 叠层：对话层挂到持久 HUD 根上，禁止 UI.SetRoot，避免冲掉章节卡/主菜单/存档菜单。
-- ============================================================================

local UI = require "urhox-libs/UI"
local InputManager = require "game.InputManager"
local GameAudio = require "audio.GameAudio"
local VoiceMap = require "config.VoiceMap"
local SceneManager = require "game.SceneManager"

local DialogueUI = {}

---@type boolean
local open_ = false
---@type table|nil
local state_ = nil   -- { spec, phase, lineIndex, locked, onDone, onChoose }
---@type Panel|nil
local layer_ = nil   -- 持久对话层（挂在 HUD 根上，Show/Hide 只改可见与子节点）

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

local function mountPanel(panel)
    local layer = ensureLayer()
    if layer == nil then
        print("[DialogueUI] 对话层挂载失败：HUD 根不存在")
        return
    end
    layer:ClearChildren()
    layer:AddChild(panel)
    layer:SetVisible(true)
end

local SCENE_BG = {
    chaoyang_gukou = "image/立绘/场景_朝阳谷口.png",
    luoshui_yinshan = "image/立绘/场景_洛水阴山.png",
    gu_nei_taolin = "image/立绘/场景_谷内桃林.png",
}

local NPC_PORTRAIT = {
    ["守桃老人"] = "image/立绘/守桃老人.jpg",
    ["无面鬼"] = "image/立绘/无面鬼.png",
    ["素女"] = "image/立绘/素女.jpg",
    ["旁白"] = "image/立绘/场景_朝阳谷口.png",
}

---@return string|nil
local function choiceBackdrop()
    local sceneId = SceneManager.GetCurrentScene and SceneManager.GetCurrentScene() or nil
    if sceneId ~= nil and SCENE_BG[sceneId] ~= nil then
        return SCENE_BG[sceneId]
    end
    local npc = state_ and state_.spec and state_.spec.npc
    if npc ~= nil and NPC_PORTRAIT[npc] ~= nil then
        return NPC_PORTRAIT[npc]
    end
    return "image/立绘/场景_朝阳谷口.png"
end

--- 对话是否打开（主循环据此停玩家移动）
---@return boolean
function DialogueUI.IsOpen()
    return open_
end

--- 关闭对话（只隐藏对话层，不替换 UI 根）
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

    local isNarrator = (npc == "旁白" or npc == "")
    mountPanel(UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                left = 10, right = 10, bottom = 16,
                padding = { 16, 18, 18, 18 },
                backgroundColor = { 42, 28, 18, 168 },
                borderRadius = 16,
                children = {
                    UI.Label {
                        text = npc,
                        fontSize = 18,
                        fontColor = { 255, 214, 158, 255 },
                        width = "100%",
                        visible = npc ~= "",
                    },
                    UI.Label {
                        text = text,
                        fontSize = isNarrator and 26 or 22,
                        fontColor = { 255, 248, 236, 255 },
                        width = "100%",
                        maxLines = 6,
                        marginTop = 8,
                    },
                    UI.Button {
                        text = hasMore and "继续 ›" or "下一步",
                        variant = "secondary",
                        alignSelf = "flex-end",
                        marginTop = 12,
                        onClick = function()
                            AdvanceText()
                        end,
                    },
                },
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
            fontSize = 22,
            fontColor = { 255, 248, 236, 255 },
            width = "100%",
            maxLines = 4,
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
                height = 52,
                marginTop = 10,
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

    local backdrop = choiceBackdrop()
    mountPanel(UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundImage = backdrop,
        backgroundColor = { 20, 12, 8, 90 },
        justifyContent = "flex-end",
        children = {
            UI.Panel {
                width = "100%",
                height = "42%",
                backgroundColor = { 12, 8, 6, 70 },
            },
            UI.Panel {
                width = "100%",
                padding = { 18, 16, 28, 16 },
                backgroundColor = { 42, 28, 18, 176 },
                children = children,
            },
        },
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
