# TTM 初始化粘贴块（④⑤⑥ 合并 · 纯复制粘贴）

> **使用**：在 TapTap 制造项目内的 TTM（AI 开发 Agent）会话中，粘贴下方「粘贴内容」整段。
> **前置（不要粘贴）**：
> - ① 报名已通过 ✅
> - ② 项目已新建并绑定活动（你已在网页处理）
> - ③ 先向项目上传文档包（TTM 需要读）：
>   - 素女篇-游戏设计与演出分镜.md
>   - 02-剧本与对白全文.md
>   - 05-评审维度强化-抉择系统与叙事创新.md
>   - 06-中国传统文化元素融入方案.md
>   - 08-旅人札记文案.md
>   - **21-互动影游双案例应用清单.md**（TTM 必读：段落化架构 + 媒体恢复规格）
>   - 12-TTM开工提示词包.md

══════════════════════════════════════════════════
以下全部为粘贴内容（从【④】到文末，整段复制）
══════════════════════════════════════════════════

【④ 初始化提示词】

> 请先阅读我上传的设计文档，然后为我新建一个单机叙事游戏项目《桃素洛无幽·素女篇》。这是 TapTap 制造 × Seedance 主题赛的参赛作品，核心要求如下：
>
> 1. 遵守引擎规范：scripts/main.lua 为唯一业务入口；启动时读取 .project/settings.json，校验 multiplayer.enabled 为 false（单机模式），异常时打日志退出；模块按功能拆分，单文件不超过 1500 行；资源路径从资源根下一级开始，使用 cache:GetResource，禁止本地绝对路径。
> 2. 常规 UI（对话、选项、字幕、任务提示、札记）统一使用 urhox-libs/UI；自定义特效（桃花粒子等）用 raw NanoVG；不混用。
> 3. 输入使用 InputManager 抽象层，事件必须用 KEY_*/MOUSEB_* 枚举，禁止数字常量。
> 4. 世界单位用米，Y 轴向上；角色高度约 1.6~1.8 米；模型尺寸用 boundingBox 动态获取。
> 5. 规则与表现分离：输入 → 规则判断 → 数据变化 → 表现；演出/动画/音频函数内禁止修改游戏数据。
> 6. 数据安全：PlayerData/GameData 提前定义固定字段，存档加载做类型检查与默认值兜底。
> 7. 日志用 print("[模块名] 消息")。
> 8. **段落化架构（必做，详见《21-互动影游双案例应用清单》）**：全部剧情按段落表（Chapters）数据驱动；流程控制器只负责"当前在哪一段、完成后去哪一段"，玩法模块只返回统一完成结果 `{ done, beliefDelta, unlocked, flag, next }`，不得直接跳段或改剧情推进状态。所有跨段落状态（信念/线索/标记）写入共享 PlayerData，场景对象不持有。
> 9. **存档契约（必做）**：PlayerData 包含 schemaVersion（版本化迁移）、mediaPos（当前段落/视频/断点序号/精确时间，剧情视频播放时写入）、flags（跨段落临时标记）。读档恢复采用三步状态机：播放器就绪 → seek 确认到达目标时间 → 移除遮罩显示；"可播放"不等于"已到目标时间"。
> 10. **视频资源（必做）**：剧情视频（S1~S9）播放结束即释放，离场显式销毁播放器；循环背景（桃花粒子、章节卡背景）可销毁重建；限制同时存在的视频实例数量（建议 ≤2，真机核对）。
>
> 本会话只做：创建项目骨架、三个场景的白模（朝阳谷口/谷内桃林/洛水阴山）、玩家移动与相机、基础碰撞、段落表数据文件（Chapters）骨架与流程控制器（flow.lua）最小实现。完成后列出下一步建议，不要继续实现其他系统。

【⑤ 数据结构 + 段落契约（随④一起粘贴）】

```lua
PlayerData = {
  schemaVersion = 2,                -- 存档结构版本：加载时校验，低版本走迁移/兜底
  belief = { reunion = 0, release = 0, legend = 0 }, -- 信念值
  blossoms = { wood = false, fire = false, earth = false, metal = false, water = false }, -- 五行桃花
  memories = {},      -- 已解锁记忆片段
  journal = {},       -- 旅人札记条目
  flags = {},         -- 跨段落临时标记（喂水/陪坐/唤名 → 终局回声；章节解锁位）
  ending = "",        -- "reunion" / "release" / "legend"
  endingsSeen = {},   -- 结局收集（标题 0/3）
  playCount = 0,      -- 通关次数
  mediaPos = {        -- 媒体位置（读档/断点恢复契约；剧情视频播放/暂停时写入）
    node = "",        -- 当前段落 id（如 "P22"）
    video = "",       -- 当前视频 id（如 "S5"）
    breakpoint = 0,   -- 断点序号（该视频第几个暂停点，从 1 起；0 = 非断点）
    timeSec = 0,      -- 精确时间（秒）
  },
}
```

```lua
-- 统一完成契约：所有玩法模块结束时返回，流程控制器只认 done
local result = {
  done        = true,           -- 必填：本段落是否完成
  beliefDelta = {},             -- 可选：{ reunion=1 } / { release=1 } / { legend=1 }
  unlocked    = {},             -- 可选：解锁条目 { "journal_01", "blossom_wood" }
  flag        = nil,            -- 可选：写入 flags 的跨段落标记（如 "fed_water"）
  next        = nil,            -- 可选：显式指定下一段；缺省用段落表 next
  timedOut    = false,          -- 可选：超时/失败标记（为限时玩法预留，素女篇暂无用例）
}
```

```lua
-- 段落表结构示例（完整版见《21》§2）
Chapters = {
  { id = "ch0", title = "楔子·桃花谷口", seal = "wood",
    paragraphs = {
      { id = "P01", type = "video",   video = "S1", breakpoints = {{ at = -1, act = "auto" }}, next = "P02" },
      { id = "P03", type = "choice",  npc = "守桃老人", lines = "open_choice",
        choices = { reunion = "我信重逢", release = "我信放手", legend = "我信传说" },
        effect = "no_belief", next = "P04" },
      -- ...
    } },
  -- ...
}
```

【⑤-附 完整骨架段落表（ch0/ch1，建议直接采用此结构，与《21》§2 一致）】

```lua
Chapters = {
  { id = "ch0", title = "楔子·桃花谷口", seal = "wood",
    paragraphs = {
      { id = "P01", type = "video",   video = "S1", breakpoints = {{ at = -1, act = "auto" }}, next = "P02", scene = "chaoyang_gukou" },
      { id = "P02", type = "explore", scene = "chaoyang_gukou", goal = "reach_oldman", next = "P03" },
      { id = "P03", type = "choice",  npc = "守桃老人", lines = "open_choice",
        choices = { reunion = "我信重逢", release = "我信放手", legend = "我信传说" },
        effect = "no_belief", next = "P04" },
      { id = "P04", type = "dialogue", npc = "守桃老人", lines = "legend_part1", video = "S2", next = "P05" },
      { id = "P05", type = "dialogue", npc = "守桃老人", lines = "legend_part2", video = "S3", next = "P06" },
      { id = "P06", type = "dialogue", npc = "守桃老人", lines = "legend_part3", video = "S4", next = "P07" },
      { id = "P07", type = "dialogue", npc = "守桃老人", lines = "quest_intro", next = "P11" },
    } },
  { id = "ch1", title = "收集·朝阳之谷", seal = "fire",
    paragraphs = {
      { id = "P11", type = "explore", scene = "chaoyang_gukou", goal = "collect_5_blossoms",
        hotspots = { "valley_gate", "peach_tree", "cliff", "well", "oldman_house" },
        on_complete = { unlock = { "P12" } }, next = "P12" },
      { id = "P12", type = "dialogue", npc = "守桃老人", lines = "depart_guide", next = "P21" },
    } },
  -- ch2 洛水阴山 / ch3 六艺记忆印证 / ch4 终局：后续会话按《21》§2 结构补充
}
```

【⑥ 向 TTM 抛八问（开工后第一件事）】

1. 视频播放的接入方式：视频资源 / UI 视频组件 / 场景视频纹理？支持哪些格式与码率？
2. 是否支持上传自定义字体（书法体/楷体）？生僻字渲染是否有坑？
3. 结局分享卡如何生成并保存到本地/分享？（是否支持截图 API，参考 Canvas.toTempFilePath 思路）
4. 音效/音乐支持的音频格式。
5. 如何锁定竖屏方向（9:16）？新建项目默认窗口方向是什么？（参考 tap.setDeviceOrientation 思路，实测制造内是否可用）
6. 视频播放是否支持 **seek 到指定时间并暂停**？一个场景能否同时存在多个播放器（剧情视频 + 循环背景）？播放器实例数量有无上限？
7. 视频的 **解码器就绪 / 首帧就绪 / 播放完成 / 暂停** 是否有独立事件或回调？能否据此实现"先确认播放位置，再移除遮罩显示"？
8. 应用 **切后台 / 回前台 / 通知栏返回** 的事件回调是什么？后台时视频是否自动暂停或释放？

> 第 6~8 问来自《21》§9：视频断点恢复、读档闪帧、前后台卡帧是制造的真实高频坑，先问清能力再写 S6/S8。
