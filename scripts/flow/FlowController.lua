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
local ChapterCard = require "ui.ChapterCard"
local GameAudio = require "audio.GameAudio"

local FlowController = {}

---@type table|nil
local data_ = nil          -- 共享 PlayerData（经 Sanitize 清洗）
---@type table|nil
local state_ = nil         -- { chapterIndex, paragraphIndex, paragraph, collectCount, collected }
---@type table|nil
local pendingDialogueAfterVideo_ = nil   -- 讲述段(对话+回忆视频)：视频播完后再进该段对白
---@type string|nil
local pendingEnding_ = nil   -- 最近进入的结局类型（round/release/legend），end 段回调带出
---@type function|nil
local onGameEnd_ = nil   -- 结局段进入时回调（main 注入 → 显示结局卡）
---@type number
local shownChapterIndex_ = 0   -- 已展示过章节卡的章号（切章才再弹）

--- 初始化流程控制器（注入清洗后的 PlayerData）
---@param data table
function FlowController.Init(data)
    data_ = data
    pendingEnding_ = nil
    pendingDialogueAfterVideo_ = nil
    shownChapterIndex_ = 0
    MediaPlayer.SetCompleteHandler(function(result)
        -- 讲述段(对话+回忆视频)：视频播完 → 播该段对白；否则按正常收尾推进
        if pendingDialogueAfterVideo_ ~= nil then
            local dlgP = pendingDialogueAfterVideo_
            pendingDialogueAfterVideo_ = nil
            StartDialogueParagraph(dlgP)
        else
            CompleteParagraph(result)
        end
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

--- 读档恢复：按 mediaPos.node 定位段落并续播；找不到则返回 false（回退 Start）。
--- 段落含 video 时由 MediaPlayer 依 data.mediaPos 做 seek 双确认恢复。
---@return boolean 是否成功续播
function FlowController.Resume()
    if data_ == nil then return false end
    local mp = data_.mediaPos
    if type(mp) ~= "table" or mp.node == nil or mp.node == "" then
        print("[Flow] 读档恢复跳过：mediaPos.node 为空")
        return false
    end
    local ci, pi = FindParagraphIndex(mp.node)
    if ci == nil then
        print("[Flow] 读档恢复失败：找不到段落 " .. tostring(mp.node))
        return false
    end
    state_ = { chapterIndex = ci, paragraphIndex = pi, collected = 0 }
    shownChapterIndex_ = ci   -- 续档不重弹章节卡
    PlayerController.SetBlossomHandler(FlowController.OnBlossomCollected)
    print("[Flow] 读档恢复：定位段落 " .. tostring(mp.node) .. "（" .. tostring(mp.video) .. " @ " .. tostring(mp.timeSec) .. "）")
    EnterParagraph()
    return true
end

--- 自动存档钩子：段落完成/场景进入时写磁盘（可被读档恢复覆盖）。
--- 仅在开头成功续播时才不强开；否则每次 Save 都是覆写 slot1。
---@return boolean
function FlowController.Persist()
    if data_ == nil then return false end
    return PlayerData.Save(data_)
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

    -- 切章：先出章节卡，关掉后再真正进入段落（不阻塞无卡资源）
    -- end 段（P99）从 ch4 跨回 ch1 时 chapterIndex 会变，但结局前不得弹章节卡
    if state_.chapterIndex ~= shownChapterIndex_ then
        shownChapterIndex_ = state_.chapterIndex
        if p.type ~= "end" then
            local chapterId = chapter.id or ("ch" .. tostring(state_.chapterIndex - 1))
            print("[Flow] 切章 " .. chapterId .. " → 章节卡")
            ChapterCard.Show(chapterId, function()
                EnterParagraph()
            end)
            return
        end
        print("[Flow] 结局段跳过章节卡 " .. tostring(p.id))
    end

    print("[Flow] 进入段落 " .. p.id .. "（" .. p.type .. "）" .. (p.desc or ""))

    -- 记录最近结局类型（P43/P44/P45 带 ending 字段），供 end 段回调带给 EndingScreen
    if p.ending ~= nil then
        pendingEnding_ = p.ending
        print("[Flow] 记录结局类型 " .. tostring(pendingEnding_))
    end

    -- 段落指定场景 → 切换白模场景；切换前显式释放剧情播放器
    if p.scene then
        MediaPlayer.Stop(true)
        SceneManager.LoadScene(p.scene)
        if p.scene == "luoshui_yinshan" then
            GameAudio.PlayAmbient("audio/sfx/sfx_wind.mp3")
        elseif p.scene == "chaoyang_gukou" then
            GameAudio.PlayAmbient("audio/sfx/sfx_wind.mp3")
        else
            GameAudio.PlayAmbient("audio/sfx/sfx_rain_snow.mp3")
        end
    end

    -- 关键状态落盘：进入新段落即更新 mediaPos.node（当前段落 id），供启动自动续档定位。
    -- 视频播放时的精确 timeSec 由 MediaPlayer 在断点/暂停/后台离散点持久化。
    data_.mediaPos.node = p.id
    PlayerData.Save(data_)

    -- 按类型处理
    -- 仅 explore 段启用作近拾取/交互（防其它段刷屏），由 PlayerController 维护进入半径边沿
    PlayerController.SetPickupsEnabled(p.type == "explore")
    if p.type == "video" then
        print("[Flow] 视频段落 " .. (p.video or "?") .. " → MediaPlayer")
        if not MediaPlayer.Play(p, data_) then
            print("[Flow] 视频无法播放，自动通过 " .. p.id)
            CompleteParagraph({ done = true })
        end
    elseif p.type == "dialogue" and p.video then
        -- 讲述段(对话+回忆视频，P04~P06)：先播回忆视频，播完再讲该段对白
        pendingDialogueAfterVideo_ = p
        print("[Flow] 讲述段 " .. p.id .. " 先播回忆视频 " .. tostring(p.video))
        if not MediaPlayer.Play({ id = p.id, type = "video", video = p.video,
            breakpoints = { { at = -1, act = "auto" } } }, data_) then
            print("[Flow] 回忆视频无法播放，直接进入讲述 " .. p.id)
            pendingDialogueAfterVideo_ = nil
            StartDialogueParagraph(p)
        end
    elseif p.type == "dialogue" or p.type == "choice" then
        StartDialogueParagraph(p)
    elseif p.type == "explore" then
        state_.collectCount = p.collectCount or 3
        -- 采集段按本段场景现有标记重新计数（新开局/重进 P11 不带旧档花朵）
        if p.hotspots ~= nil then
            for _, h in ipairs(p.hotspots) do
                data_.blossoms[h] = false
            end
            state_.collected = 0
        end
        print("[Flow] 探索段（" .. tostring(p.goal or "") .. "）：收集 "
            .. state_.collectCount .. " 个标记点后继续")
    elseif p.type == "end" then
        -- 正式结局：弹出结局卡 + 制作名单（不再演示循环 P99→P01）
        print("[Flow] 结局段落（弹出结局卡） | ending=" .. tostring(pendingEnding_))
        if onGameEnd_ ~= nil then
            onGameEnd_(pendingEnding_)
        end
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
        linesKey = p.interaction.lines,
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
        choiceOrder = spec.choiceOrder or p.choiceOrder,
        linesKey = p.lines,
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
    elseif p.recordFlag ~= nil then
        -- 叙事记录型选择（无面鬼互动 / 终局抉择等）：只写 flags，不计信念
        data_.flags[p.recordFlag] = key
        print("[Flow] 已记录 " .. p.recordFlag .. " = " .. key)
    elseif p.beliefMap ~= nil and p.beliefMap[key] ~= nil then
        -- 信念选择段：按段落表 beliefMap 加信念（S6 记忆印证 5 段等）
        local axis = p.beliefMap[key]
        if data_.belief[axis] ~= nil then
            data_.belief[axis] = data_.belief[axis] + 1
        end
    end
    CompleteParagraph({ done = true })
end

--- 玩法模块上报"拾取一个标记点"（规则：累计 → 达标返回统一完成结果）
---@param key string 标记键（五行键或交互点键）
---@param node? Node 被拾取标记节点（采集成功后随标记与光柱一并移除；对话中不消费，节点保留待下次轮询）
function FlowController.OnBlossomCollected(key, node)
    if state_ == nil or state_.paragraph == nil then return end
    if DialogueUI.IsOpen() then return end   -- 对话中不收（节点保留，待对话关闭后再轮询拾取）
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

    -- 采集段只认 hotspots / 五行桃花，忽略 Int_oldman 等交互点（防无独白也计入 5）
    local allowed = p.hotspots
    if allowed ~= nil then
        local ok = false
        for _, h in ipairs(allowed) do
            if h == key then
                ok = true
                break
            end
        end
        if not ok then
            print("[Flow] 采集段 " .. p.id .. " 忽略非桃花拾取: " .. tostring(key))
            return
        end
    elseif data_.blossoms[key] == nil then
        print("[Flow] 采集段 " .. p.id .. " 忽略未知拾取: " .. tostring(key))
        return
    end
    if data_.blossoms[key] == true then
        print("[Flow] 采集段 " .. p.id .. " 已拾取过: " .. tostring(key))
        return
    end

    -- 采集：先移除标记节点与其辨识光柱（避免对话中拾取丢失 / 残留空柱）
    if node ~= nil then
        local beacon = node.parent and node.parent:GetChild("Beacon_" .. key, true)
        if beacon ~= nil then beacon:Remove() end
        node:Remove()
    end

    -- 数据变化：写入共享 PlayerData（五行桃花 + 札记占位）
    data_.blossoms[key] = true
    if data_.journal ~= nil then
        data_.journal[key] = true
    end
    local n = 0
    for _, taken in pairs(data_.blossoms) do
        if taken then
            n = n + 1
        end
    end
    state_.collected = n
    print("[Flow] 桃花进度 " .. state_.collected .. "/" .. state_.collectCount .. " | 本朵=" .. tostring(key))

    -- 达到收集数后完成（拾取触发的独白播完后再判，避免与探索串台）
    local finish = function()
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

    -- 五行→独白（占位映射）：拾取触发素女内心独白，播完再判完成
    local monoKey = (p.blossomMonologue ~= nil) and p.blossomMonologue[key]
    if monoKey ~= nil then
        local spec = DialogueData.Get(monoKey)
        if spec ~= nil then
            local dlg = {
                npc = spec.npc,
                lines = spec.lines,
                linesKey = monoKey,
                onDone = finish,
            }
            print("[Flow] 拾取独白 " .. key .. "（" .. tostring(monoKey) .. "）")
            DialogueUI.ShowDialogue(dlg)
            return
        else
            -- 兜底：定位"独白数据缺失"（如 wood 独白未显示），记录 p 上下文
            print("[Flow] 独白数据缺失: key=" .. tostring(key) .. " monoKey=" .. tostring(monoKey)
                .. " p=" .. tostring(p.id) .. " type=" .. tostring(p.type))
        end
    else
        -- 兜底：定位"某五行无独白映射"，记录 p 上下文
        print("[Flow] 无独白映射: key=" .. tostring(key)
            .. " p=" .. tostring(p.id) .. " type=" .. tostring(p.type)
            .. " hasMonologue=" .. tostring(p.blossomMonologue ~= nil))
    end
    finish()
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

    -- 推进：显式 next 优先 → 段落表 resolveNext(data)（动态分支）→ 段落表 next
    local nextId = result.next
    if nextId == nil and type(p.resolveNext) == "function" then
        nextId = p.resolveNext(data_)
    end
    nextId = nextId or p.next
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

--- 调试：跳转到指定段落（FindParagraphIndex 定位），用于直测某条链（如 S6 连续 5 段）。S9 前可保留。
---@param id string 段落 id
---@return boolean 是否成功跳转
function FlowController.DebugJumpToParagraph(id)
    if data_ == nil then return false end
    local ci, pi = FindParagraphIndex(id)
    if ci == nil then
        print("[Flow] 调试跳转失败：找不到段落 " .. tostring(id))
        return false
    end
    state_ = { chapterIndex = ci, paragraphIndex = pi, collected = 0 }
    PlayerController.SetBlossomHandler(FlowController.OnBlossomCollected)
    print("[Flow] 调试跳转：进入段落 " .. tostring(id))
    EnterParagraph()
    return true
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

--- 结局段进入时的回调（main 注入：显示结局卡；参数为 ending 键）
---@param cb function|nil
function FlowController.SetOnGameEnd(cb)
    onGameEnd_ = cb
end

return FlowController
