-- ============================================================================
-- config/Chapters.lua
-- 《桃素洛无幽·素女篇》段落表（Chapters）骨架 —— 按《21-互动影游双案例应用清单》§2
--
-- 段落化架构铁律（《21》§3）：
--   - 段落表 = 内容关系数据；运行时只做"当前在哪一段、完成后去哪一段"；
--   - 玩法模块统一返回 { done, beliefDelta, unlocked, flag, next, timedOut }；
--   - 换剧本只改数据，不重写运行时。
--
-- 本章节骨架范围（S1 骨架期，对应《12》§4）：
--   - ch0 楔子 + ch1 收集 的结构、段落 id、类型、next 链与《21》§2 完全一致；
--   - video / dialogue / choice 类型：媒体与对话系统未接入，运行时自动通过（打日志）；
--   - explore 类型：白模演示用"收集标记点"完成（P02 走近老人 / P11 采花×5）；
--   - P99 为骨架期临时收尾（演示循环回 P01），ch2~ch4 接入后移除。
-- ============================================================================

local Chapters = {
    {
        id = "ch0",
        title = "楔子·桃花谷口",
        seal = "wood",              -- 印章：木
        paragraphs = {
            -- P01 开场演出（Seedance S1）
            {
                id = "P01",
                type = "video",
                video = "S1",
                breakpoints = { { at = -1, act = "auto" } },
                next = "P02",
                scene = "chaoyang_gukou",
            },
            -- P02 探索：走近守桃老人（交互点 Int_oldman，走近触发初见台词；不再用收集标记点代替）
            {
                id = "P02",
                type = "explore",
                scene = "chaoyang_gukou",
                goal = "reach_oldman",
                collectCount = 1,   -- 兼容字段：仍有标记数概念，但走近交互按 interaction 触发
                interaction = {
                    trigger = "oldman",         -- 交互点键（PlayerController 识别 Int_<key> → key）
                    lines = "oldman_greeting",  -- DialogueData 键（初见台词）
                },
                desc = "探索朝阳谷口，走近守桃老人",
                next = "P03",
            },
            -- P03 开场三选（不计信念：effect = "no_belief"，见《05》§8）
            {
                id = "P03",
                type = "choice",
                npc = "守桃老人",
                lines = "open_choice",
                choices = {
                    reunion = "我信重逢",
                    release = "我信放手",
                    legend = "我信传说",
                },
                effect = "no_belief",
                next = "P04",
            },
            -- P04~P06 讲述（第一~三回，插入回忆视频 S2/S3/S4）
            {
                id = "P04",
                type = "dialogue",
                npc = "守桃老人",
                lines = "legend_part1",
                video = "S2",
                next = "P05",
            },
            {
                id = "P05",
                type = "dialogue",
                npc = "守桃老人",
                lines = "legend_part2",
                video = "S3",
                next = "P06",
            },
            {
                id = "P06",
                type = "dialogue",
                npc = "守桃老人",
                lines = "legend_part3",
                video = "S4",
                next = "P07",
            },
            -- P07 接任务：五朵桃花
            {
                id = "P07",
                type = "dialogue",
                npc = "守桃老人",
                lines = "quest_intro",
                next = "P11",
            },
        },
    },
    {
        id = "ch1",
        title = "收集·朝阳之谷",
        seal = "fire",              -- 印章：火
        paragraphs = {
            -- P11 探索采花×5（谷口/桃树下/望夫崖/井边/守桃老人屋，拾取触发独白+札记解锁）
            {
                id = "P11",
                type = "explore",
                scene = "chaoyang_gukou",
                goal = "collect_5_blossoms",
                collectCount = 5,
                hotspots = { "valley_gate", "peach_tree", "cliff", "well", "oldman_house" },
                on_complete = { unlock = { "P12" } },
                desc = "收集 5 朵桃花（五行：木火土金水）",
                next = "P12",
            },
            -- P12 对话：前往洛水阴山
            {
                id = "P12",
                type = "dialogue",
                npc = "守桃老人",
                lines = "depart_guide",
                next = "P99",
            },
            -- P99 骨架期临时收尾：白模演示循环回 P01；ch2~ch4 接入后移除
            {
                id = "P99",
                type = "end",
                desc = "骨架期演示闭环（ch2 洛水阴山 / ch3 六艺 / ch4 终局 待后续会话）",
                next = "P01",
            },
        },
    },
    {
        -- ch3 第五回·记忆印，六艺寻（S6 记忆印证 5 段连播接线；正式 S6-x 视频未到位，用占位素材）
        id = "ch3",
        title = "第五回·记忆印，六艺寻",
        seal = "metal",            -- 印章：金（与 ch1 五行的"金"区隔仅作占位，章节卡样式后续定）
        paragraphs = {
            -- P31 引导对话（进入六艺试炼前）
            {
                id = "P31",
                type = "dialogue",
                npc = "守桃老人",
                lines = "memory_guide",
                next = "P32",
            },
            -- P32~P36 记忆印证×5：每段视频 S6-x + 播完/断点暂停 → 解读三选（信念+1）
            -- 断点 at 为占位（正式 S6-x 到位后按《21》§5 真机校正）
            {
                id = "P32",
                type = "video",
                video = "S6-1",
                breakpoints = {
                    {
                        at = 4.0,
                        act = "choice",
                        prompt = "礼·素女为什么没有拦他？",
                        options = {
                            reunion = "她懂他的执着",
                            release = "她怕拦了就走不成",
                            legend = "她只等故事发生",
                        },
                        choiceOrder = { "reunion", "release", "legend" },
                        beliefMap = { reunion = "reunion", release = "release", legend = "legend" },
                    },
                },
                scene = "luoshui_yinshan",
                next = "P33",
            },
            {
                id = "P33",
                type = "video",
                video = "S6-2",
                breakpoints = {
                    {
                        at = 4.0,
                        act = "choice",
                        prompt = "乐·那曲琴声听成了什么？",
                        options = {
                            reunion = "等你回来",
                            release = "一路平安",
                            legend = "桃花落在水面",
                        },
                        choiceOrder = { "reunion", "release", "legend" },
                        beliefMap = { reunion = "reunion", release = "release", legend = "legend" },
                    },
                },
                next = "P34",
            },
            {
                id = "P34",
                type = "video",
                video = "S6-3",
                breakpoints = {
                    {
                        at = 4.0,
                        act = "choice",
                        prompt = "射·那支箭穿过桃花枝，准还是不准？",
                        options = {
                            reunion = "偏了半寸，心里多了个人",
                            release = "心无旁骛，一箭中的",
                            legend = "花落才重要",
                        },
                        choiceOrder = { "reunion", "release", "legend" },
                        beliefMap = { reunion = "reunion", release = "release", legend = "legend" },
                    },
                },
                next = "P35",
            },
            {
                id = "P35",
                type = "video",
                video = "S6-4",
                breakpoints = {
                    {
                        at = 4.0,
                        act = "choice",
                        prompt = "御·回望谷口时看见什么？",
                        options = {
                            reunion = "一抹素衣身影",
                            release = "谷口已经空了",
                            legend = "满谷的桃花",
                        },
                        choiceOrder = { "reunion", "release", "legend" },
                        beliefMap = { reunion = "reunion", release = "release", legend = "legend" },
                    },
                },
                next = "P36",
            },
            {
                id = "P36",
                type = "video",
                video = "S6-5",
                breakpoints = {
                    {
                        at = 4.0,
                        act = "choice",
                        prompt = "书/数·那味药是「当归」还是「不归」？",
                        options = {
                            reunion = "当归，应当归家",
                            release = "不归，本没打算回头",
                            legend = "药方上有个没写完的话",
                        },
                        choiceOrder = { "reunion", "release", "legend" },
                        beliefMap = { reunion = "reunion", release = "release", legend = "legend" },
                    },
                },
                -- ch4 尾声尚未接线，此处指向未建段 P41（CompleteParagraph 会打印"找不到下一段"作为收尾提示）
                next = "P41",
            },
        },
    },
    -- ch2 第四回·洛水阴 / ch4 尾声·终局：演出接入会话补充
}

return Chapters
