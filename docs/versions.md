# 版本历史

> AI 每次 POST-2 git commit 后自动追加到表头。最新版本在最上面。
> 用户可直接说"回退到 vX.X.X"。

| 版本 | 日期 | 变更摘要 |
|------|------|---------|
| v0.1.1-S1 | 2026-08-20 | S1：发布元数据改为 portrait；运行时请求 `SetOrientations("Portrait")` 并记录方向/尺寸；三场景改为 9:16 窄 X 深 Z 纵深布局；LSP Error 为空，官方构建成功，Lua runtime error 为 0，生成 540×960 竖屏截图 |
| v0.1.0 | 2026-08-20 | 创建单机 3D 白模骨架、严格单机校验、InputManager、三地点场景、玩家移动/相机/碰撞、Chapters 与 Flow 最小闭环；LSP Error 为空，官方构建成功，运行时 Lua 错误为 0 |
