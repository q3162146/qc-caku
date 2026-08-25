-- ============================================================================
-- flow/FlowController.lua
-- 最小流程控制器（段落化架构，快速开工包 ④⑧ / 设计文档 §8）
--
-- 职责边界：
--   - 只做"当前在哪一段、完成后去哪一段"（读段落表推进）；
--   - 玩法模块（本会话为桃花收集）只返回统一完成结果
--     { done, beliefDelta, unlocked, flag, next, timedOut }；
--   - 本模块负责把 beliefDelta/unlocked/flag 写入共享 PlayerData，
--     场景对象不持有任何跨段落状态。
--
-- 本会话段落类型：
--   video     媒体未接入 → 自动完成（打日志跳过，正式接入在演出会话）；
--   dialogue/choice 对话系统已接入（S2）→ 走 DialogueUI 真实交互；
--   explore   收集完场景标记点即完成（白模玩法闭环演示）；
--   end       收尾段落 → 按 next 循环（骨架期演示闭环，ch2~ch4 接入后移除）。
-- ============================================================================

local PlayerData = require "config.PlayerData"
local Chapters = require "config.Chapters"
local DialogueData = require "config.DialogueData"
local DialogueUI = require "ui.DialogueUI"
local SceneManager = require "game.SceneManager"
local PlayerController = require "game.PlayerController"
local MediaPlayer = require "media.MediaPlayer"

local FlowController = {}

---@type table|nil
local data_ = nil          -- 共享 PlayerData（经 Sanitize 清洗）
---@type table|nil
local state_ = nil         -- { chapterIndex, paragraphIndex, paragraph, collectCount, collected }

--- 初始化流程控制器（注入清洗后的 PlayerData）
---@param data table
function FlowController.Init(data)
    data_ = data
    MediaPlayer.SetCompleteHandler(function(result)
        CompleteParagraph(result)
    end)
end

--- 从第一段开始（演示：ch0/P01）
function FlowController.Start()
    if data_ == nil then
        print("[Flow] 未初始化（缺 PlayerData）")
        return
    end
    state_ = { chapterIndex = 1, paragraphIndex = 1, collected = 0 }
    PlayerController.SetBlossomHandler(FlowController.OnBlossomCollected)
    print("[Flow] 流程启动（白模演示）")
    EnterParagraph()
end

--- 进入当前段落
function EnterParagraph()
    ---@type table|nil
    local chapter = Chapters[state_.chapterIndex]
    if chapter == nil then
        print("[Flow] 章节不存在，流程结束")
        return
    end
    ---@type table|nil
    local p = chapter.paragraphs[state_.paragraphIndex]
    if p == nil then
        print("[Flow] 段落不存在，流程结束")
        return
    end
    state_.paragraph = p
    state_.collected = 0

    print("[Flow] 进入段落 " .. p.id .. "（" .. p.type .. "）" .. (p.desc or ""))

    -- 段落指定场景 → 切换白模场景；切换前显式释放剧情播放器
    if p.scene then
        MediaPlayer.Stop(true)
        SceneManager.LoadScene(p.scene)
    end

    -- 按类型处理
    if p.type == "video" then
        print("[Flow] 视频段落 " .. (p.video or "?") .. " → MediaPlayer")
        MediaPlayer.Play(p, data_)
    elseif p.type == "dialogue" or p.type == "choice" then
        StartDialogueParagraph(p)
    elseif p.type == "explore" then
        state_.collectCount = p.collectCount or 3
        print("[Flow] 探索段（" .. tostring(p.goal or "") .. "）：收集 "
            .. state_.collectCount .. " 个标记点后继续")
    elseif p.type == "end" then
        print("[Flow] 收尾段落（骨架期演示闭环）")
        CompleteParagraph({ done = true })
    end
end

--- 走近交互：触发初见台词（P02 等 interaction.trigger 命中时），播完完成段落
---@param p table 段落定义（含 p.interaction = { trigger, lines }）
function StartInteractionDialogue(p)
    local spec = DialogueData.Get(p.interaction.lines)
    if spec == nil then
        print("[Flow] 走近交互台词缺失（lines=" .. tostring(p.interaction.lines) .. "），自动通过")
        CompleteParagraph({ done = true })
        return
    end

    local dlg = {
        npc = spec.npc,
        lines = spec.lines,
    }
    dlg.onDone = function()
        CompleteParagraph({ done = true })
    end
    print("[Flow] 走近交互 " .. p.id .. "（" .. tostring(p.interaction.lines) .. "）")
    DialogueUI.ShowDialogue(dlg)
end

--- 启动对话/选择段落（S2：dialogue/choice → DialogueUI）
---@param p table 段落定义
function StartDialogueParagraph(p)
    local spec = DialogueData.Get(p.lines)
    if spec == nil then
        print("[Flow] 对话数据缺失（lines=" .. tostring(p.lines) .. "），自动通过")
        CompleteParagraph({ done = true })
        return
    end

    -- 副本注入回调（不改 DialogueData 原表）
    local dlg = {
        npc = spec.npc,
        intro = spec.intro,
        lines = spec.lines,
        prompt = spec.prompt,
        choices = spec.choices,
        choiceOrder = spec.choiceOrder,
    }

    if p.type == "choice" then
        dlg.onChoose = function(key)
            OnChoiceMade(p, key)
        end
        print("[Flow] 选择段 " .. p.id .. "（" .. tostring(p.lines) .. "）")
        DialogueUI.ShowChoice(dlg)
    else
        dlg.onDone = function()
            CompleteParagraph({ done = true })
        end
        print("[Flow] 对话段 " .. p.id .. "（" .. tostring(p.lines) .. "）")
        DialogueUI.ShowDialogue(dlg)
    end
end

--- 选择结果（规则层：按段落表 effect 处理数据，表现层不碰数据）
---@param p table 段落定义
---@param key string 选择键
function OnChoiceMade(p, key)
    if p.effect == "no_belief" then
        -- 开场三选：不计信念，只记录元叙事钩子（《02》；结局后对照回放）
        data_.flags.open_choice = key
        print("[Flow] 开场选择已记录 flags.open_choice = " .. key)
    elseif p.beliefMap ~= nil and p.beliefMap[key] ~= nil then
        -- 预留：后续选择段按段落表 beliefMap 加信念（S4 无面鬼互动等）
        local axis = p.beliefMap[key]
        if data_.belief[axis] ~= nil then
            data_.belief[axis] = data_.belief[axis] + 1
        end
    end
    CompleteParagraph({ done = true })
end

--- 玩法模块上报"拾取一个标记点"（规则：累计 → 达标返回统一完成结果）
---@param key string 标记键（五行键或交互点键）
function FlowController.OnBlossomCollected(key)
    if state_ == nil or state_.paragraph == nil then return end
    if DialogueUI.IsOpen() then return end   -- 对话中不收（避免与对话推进串台）
    local p = state_.paragraph
    if p.type ~= "explore" then return end

    -- 走近交互优先（P02 等 interaction.trigger 命中）：触发台词对话，播完即完成段落
    if p.interaction ~= nil then
        if key == p.interaction.trigger then
            StartInteractionDialogue(p)
        else
            -- 有交互点的探索段（P02）只认交互点完成，忽略沿途桃花等其它拾取，防误完成
            print("[Flow] 交互段 " .. p.id .. " 忽略无关拾取: " .. tostring(key))
        end
        return
    end

    -- 数据变化：写入共享 PlayerData（五行桃花 + 札记占位）
    if data_.blossoms[key] ~= nil then
        data_.blossoms[key] = true
    end
    state_.collected = state_.collected + 1
    print("[Flow] 桃花进度 " .. state_.collected .. "/" .. state_.collectCount)

    if state_.collected >= state_.collectCount then
        -- 统一完成结果（玩法模块契约）：按段落表数据驱动（《21》§2 on_complete）
        -- 采花本身不加信念（信念来自记忆印证/终局，见《05》§8）
        local onComplete = p.on_complete or {}
        CompleteParagraph({
            done = true,
            beliefDelta = p.beliefDelta,        -- 段落表声明才有
            unlocked = onComplete.unlock,       -- 段落表声明才有（如 P11 → {"P12"}）
            flag = p.flag,                      -- 段落表声明才有（跨段落标记）
        })
    end
end

--- 完成当前段落：应用结果 → 按契约推进到下一段
---@param result table { done, beliefDelta?, unlocked?, flag?, next? }
function CompleteParagraph(result)
    if state_ == nil or state_.paragraph == nil then return end
    local p = state_.paragraph
    result = result or {}

    -- 应用数据（规则与表现分离：这里只改数据）
    if result.beliefDelta then
        for axis, delta in pairs(result.beliefDelta) do
            if data_.belief[axis] ~= nil and type(delta) == "number" then
                data_.belief[axis] = data_.belief[axis] + delta
            end
        end
    end
    if result.unlocked then
        for _, entry in ipairs(result.unlocked) do
            data_.memories[entry] = true
        end
    end
    if result.flag then
        data_.flags[result.flag] = true
    end
    if result.done == false then
        print("[Flow] 段落 " .. p.id .. " 尚未完成，等待玩法模块继续")
        return
    end
    print("[Flow] 段落 " .. p.id .. " 完成 | 信念(重逢/放手/传说) = "
        .. data_.belief.reunion .. "/" .. data_.belief.release .. "/" .. data_.belief.legend)

    -- 推进：显式 next 优先，否则用段落表 next
    local nextId = result.next or p.next
    if nextId == nil then
        print("[Flow] 段落 " .. p.id .. " 无 next，流程终止")
        return
    end

    local ci, pi = FindParagraphIndex(nextId)
    if ci == nil then
        print("[Flow] 找不到下一段 " .. tostring(nextId) .. "，流程终止")
        return
    end
    state_.chapterIndex = ci
    state_.paragraphIndex = pi
    EnterParagraph()
end

--- 调试：强制完成当前段落（F5）
function FlowController.DebugForceComplete()
    if state_ == nil or state_.paragraph == nil then return end
    print("[Flow] 调试：强制完成段落 " .. state_.paragraph.id)
    MediaPlayer.Stop(true)
    DialogueUI.Hide()   -- 若对话开着，先关闭（避免回调悬空）
    CompleteParagraph({ done = true })
end

--- 当前段落 id
---@return string|nil
function FlowController.GetCurrentParagraphId()
    if state_ == nil or state_.paragraph == nil then return nil end
    return state_.paragraph.id
end

--- 按段落 id 定位（章索引、段索引）
---@param id string
---@return integer|nil, integer|nil
function FindParagraphIndex(id)
    for ci, chapter in ipairs(Chapters) do
        for pi, p in ipairs(chapter.paragraphs) do
            if p.id == id then
                return ci, pi
            end
        end
    end
    return nil, nil
end

return FlowController
