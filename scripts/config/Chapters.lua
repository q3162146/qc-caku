-- ============================================================================
-- config/Chapters.lua
-- 《桃素洛无幽·素女篇》段落表（Chapters）骨架
--
-- 段落化架构（快速开工包 ④⑧ / 《21-互动影游双案例应用清单》）：
--   - 全部剧情按段落表数据驱动；
--   - 流程控制器只做"当前在哪一段、完成后去哪一段"；
--   - 玩法模块只返回统一完成结果 { done, beliefDelta, unlocked, flag, next, timedOut }；
--   - 不得直接跳段或改剧情推进状态。
--
-- 本会话（首轮白模骨架）：
--   - type="video"   视频演出段：媒体模块未接入，流程自动完成（打日志跳过）；
--   - type="explore" 探索白模段：收集场景内全部桃花标记点后完成（演示玩法闭环）；
--   - type="end"     演示收尾：循环回 P01（后续会话接入真实段落流程后移除）。
-- ============================================================================

local Chapters = {
    {
        id = "ch0",
        title = "楔子·桃花谷口",
        seal = "wood",              -- 五行方位印章（木）
        paragraphs = {
            -- P01 开场演出（Seedance S1）：朝阳谷口全景 → 探索
            {
                id = "P01",
                type = "video",
                video = "S1",
                breakpoints = { { at = -1, act = "auto" } },   -- 播完自动继续
                next = "P02",
                scene = "chaoyang_gukou",
            },
            -- P02 自由探索·朝阳谷口：收集 5 朵五行桃花（白模演示）
            {
                id = "P02",
                type = "explore",
                scene = "chaoyang_gukou",
                collectCount = 5,   -- 该段落需收集的标记点数量
                desc = "探索朝阳谷口，收集 5 朵桃花（谷口/桃树下/望夫崖/井边/守桃老人屋）",
                next = "P03",
            },
            -- P03 回忆·离别（Seedance S2）：核心台词"必然重逢"
            {
                id = "P03",
                type = "video",
                video = "S2",
                next = "P04",
            },
            -- P04 自由探索·谷内桃林：白模演示（守桃老人屋/井/桃树群/望夫崖）
            {
                id = "P04",
                type = "explore",
                scene = "gu_nei_taolin",
                collectCount = 3,
                flag = "visited_taolin",   -- 完成时写入跨段落标记（演示）
                desc = "探索谷内桃林：守桃老人屋、井、桃树群、望夫崖",
                next = "P05",
            },
            -- P05 自由探索·洛水阴山：白模演示（小镇/无面鬼处/矿场小路）
            {
                id = "P05",
                type = "explore",
                scene = "luoshui_yinshan",
                collectCount = 3,
                flag = "met_ghost",        -- 完成时写入跨段落标记（演示）
                desc = "探索洛水阴山：小镇、无面鬼处、矿场小路",
                next = "P06",
            },
            -- P06 演示收尾：白模闭环演示结束，循环回 P01
            {
                id = "P06",
                type = "end",
                desc = "白模演示完成（S1~S9 演出与正式段落表在后续会话接入）",
                next = "P01",
            },
        },
    },
    -- 后续章节（ch1 谷内桃林 / ch2 洛水阴山 / ch3 终局）在演出接入会话中补充，
    -- 完整段落表结构示例见快速开工包 ⑤。
}

return Chapters
