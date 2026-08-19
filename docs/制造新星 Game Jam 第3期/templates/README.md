# 脚手架选择指南 (Scaffold Selection Guide)

本目录提供 4 个标准游戏脚手架（scaffold）。**写新游戏前请先在此选一个起手**，复制其内容作为项目入口脚本，再按注释填充游戏逻辑——不要从零开始（见 `AGENTS.md` 规则 #2）。

## 脚手架对比

| 脚手架文件 | 适用游戏类型 | 维度 | 相机 | 物理 | 含角色控制 | 典型示例游戏 |
|---|---|---|---|---|---|---|
| `scaffold-2d.lua` | 不使用物理的 2D 游戏 | 2D | 无（纯 UI/NanoVG，无 Scene/Viewport） | 无 | 否 | 消除、卡牌、简单的移动游戏 |
| `scaffold-2d-physics.lua` | 含物理的 2D 游戏 | 2D | 正交相机（orthographic）+ Viewport | Box2D（`PhysicsWorld2D`） | 否 | 平台跳跃等物理玩法 |
| `scaffold-3d-scene.lua` | 3D 场景展示 / 漫游 | 3D | 自由飞行相机（WASD + 鼠标右键） | 可选（默认注释关闭） | 否 | 建筑漫游、3D 可视化、产品/教育展示 |
| `scaffold-3d-character.lua` | 3D 角色游戏 | 3D | 第三人称相机（`ThirdPersonCamera`，越肩/瞄准切换） | 3D 物理（`PhysicsWorld` + `RigidBody`/`CollisionShape`） | 是（`CharacterComponent` + 动画 FSM + `GameHUD` 摇杆/按钮） | Fall Guys、Roblox、马里奥 3D 风格、第三人称射击 |

> 三个含场景的脚手架均使用 `urhox-libs/UI`（Yoga Flexbox + NanoVG）作为 UI 层；`scaffold-2d.lua` 完全基于 UI/NanoVG 渲染，无需 Scene。

## 如何选择

按下面的判断顺序走，命中即停：

- **2D 还是 3D？**
  - **2D**：
    - 需要重力、碰撞、刚体（平台跳跃、弹球等）→ `scaffold-2d-physics.lua`
    - 不需要物理（消除、卡牌、棋牌、纯 UI 交互）→ `scaffold-2d.lua`
  - **3D**：
    - 需要玩家操控一个可移动/跳跃的角色 → `scaffold-3d-character.lua`
    - 只展示/漫游场景，自由相机即可，无需角色 → `scaffold-3d-scene.lua`

简化记忆：**有角色 → 3d-character；只看场景 → 3d-scene；2D 要物理 → 2d-physics；2D 无物理 → 2d。**

## 云变量 / 排行榜（无需脚手架）

云变量、排行榜用 `clientCloud`（客户端）/ `serverCloud`（服务端）即可，**不属于脚手架，可与上面任意一个游戏脚手架组合使用**。

- 客户端示例：`examples/11-client-cloud-score-leaderboard-api.lua`
- 服务端示例：`examples/23-server-cloud-score-leaderboard-api`

## 使用方法

1. 选好脚手架后，**复制脚手架内容**到你的项目入口脚本（新文件）。
2. 按文件内 `[AI TODO]` / 注释提示，在对应函数里填充游戏内容与逻辑。
3. 移除占位演示代码（如占位卡片、示例方块）。

> 运行：`UrhoXRuntime.exe <你的脚本>.lua -tapcode_dir=<项目根目录> -skip_login`（脚本必须是第一个位置参数）。
