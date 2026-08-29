# 版本历史

> AI 每次 POST-2 git commit 后自动追加到表头。最新版本在最上面。
> 用户可直接说"回退到 vX.X.X"。

| 版本 | 日期 | 变更摘要 |
|------|------|---------|
| v0.2.1-menu | 2026-08-30 | 正式主菜单 + 结局返回（用户提交 f2482ed/f47ecb2）：新增 `scripts/ui/MainMenu.lua`（标题「桃素洛无幽 · 素女篇」+ 开始游戏/继续游戏，无档隐藏继续）；启动不再自动续档；`end` 段触发 `onGameEnd` 返回主菜单（P43/P44/P45 播完→P99 不再循环 P01）；`PlayerData.Clear` 删 slot1 + 返回全新默认数据（belief/blossoms 重置）。TTM 补：`onStartGame_` 标注 `function\|nil`（原 table 致 LSP Error）、`doStart` 先 `MediaPlayer.Stop(true)`、启动日志改为「等待主菜单选择」。LSP 0 Error、官方构建成功、140 帧 lua_errors=0（启动只见 `[MainMenu] 已创建主菜单`，不进 P01）；二维码已生成待真机验证 |
| v0.1.9-P04v | 2026-08-29 | P04~P06 讲述段接入回忆视频（用户提交 568a0a6）：dialogue+video 段先播回忆视频（S2/S3/S4），播完经 completeHandler 再弹该段讲述对白；FlowController 加 `pendingDialogueAfterVideo_` + EnterParagraph 合成 video 段交给 MediaPlayer（断点 at=-1 不触发）。TTM 侧核对：闭包前向引用安全（回调运行期才调用）、`Stop(true)` 不触回调无状态残留、读档命中时视频优先播完再进对白。LSP 0 Error、官方构建成功、140 帧 lua_errors=0（字体缺失/无解码器为既有环境噪音）；二维码已生成待真机验证（P04~P06 先视频后对白→P07） |
| v0.1.7-S6 | 2026-08-26 | ①读档恢复：PlayerData 加磁盘 Save/Load(slot1)，FlowController 加 Resume(mediaPos.node)+自动存档，main 启动自动续档+F8/F9；②S6 连续 5 段接线：VIDEO_SOURCES 加 S6-1..5 占位、ch3(P31~P36)落地、MediaPlayer 断点三选泛化(真实段落可用)+信念+1，F10 直切链 |
| v0.1.6-S2 | 2026-08-26 | P02 走近守桃老人触发真实台词交互（旧“收集 1 个标记点”白模占位移除）；初见台词移至 P02，P03 精简为开场之问（三选不计信念）；`explore` 段新增 `interaction` 字段（data 驱动，FlowController 拦截触发） |
| v0.1.1-S1 | 2026-08-20 | S1：发布元数据改为 portrait；运行时请求 `SetOrientations("Portrait")` 并记录方向/尺寸；三场景改为 9:16 窄 X 深 Z 纵深布局；LSP Error 为空，官方构建成功，Lua runtime error 为 0，生成 540×960 竖屏截图 |
| v0.1.0 | 2026-08-20 | 创建单机 3D 白模骨架、严格单机校验、InputManager、三地点场景、玩家移动/相机/碰撞、Chapters 与 Flow 最小闭环；LSP Error 为空，官方构建成功，运行时 Lua 错误为 0 |
