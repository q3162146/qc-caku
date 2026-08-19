# 《桃素洛无幽·素女篇》— 项目核心记忆

> AI 自维护项目状态。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.1.0
- 进度: 单机 3D 白模骨架完成
- 上次交付: 创建唯一入口、PlayerData/Chapters/FlowController、三地点白模、移动/第三人称相机、基础碰撞与 InputManager；完成 LSP/构建/运行验证

## 项目概况
- TapTap 制造 × Seedance 主题赛单机叙事游戏。
- 入口为 `scripts/main.lua`，运行时严格校验 `.project/settings.json` 的 `@runtime.multiplayer.enabled == false`。
- 当前只做白模与最小段落闭环：`P01 → P02 → P03 → P04~P07 → P11 → P12 → P99`。
- 三地点键：`chaoyang_gukou`、`gu_nei_taolin`、`luoshui_yinshan`。
- 规则状态集中在 `PlayerData`，剧情关系集中在 `config/Chapters.lua`，推进集中在 `flow/FlowController.lua`。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 唯一业务入口、单机校验、场景基础设施、生命周期 |
| `scripts/game/InputManager.lua` | 平台触摸初始化与 KEY/MOUSE 枚举查询封装 |
| `scripts/game/PlayerController.lua` | 玩家胶囊碰撞、移动、跳跃、第三人称相机、触发器事件 |
| `scripts/game/SceneManager.lua` | 三个白模场景创建/销毁/切换 |
| `scripts/game/WhiteBox.lua` | 程序化材质、基础几何、碰撞体与触发器 |
| `scripts/config/PlayerData.lua` | 固定存档字段、类型清洗、schemaVersion/mediaPos 契约 |
| `scripts/config/Chapters.lua` | 段落数据表与统一完成结果字段骨架 |
| `scripts/flow/FlowController.lua` | 读取段落、消费完成结果、应用共享状态、推进 next |
| `screenshots/chaoyang_gukou.png` | 初始朝阳谷口白模验证截图 |

## 有效决策
- D-001: 本轮只实现骨架、白模、移动/相机/碰撞与最小 flow，不接入视频、完整存档 IO、后续章节、正式角色和其他系统（0.1.0）。
- D-002: 常规对话 UI 继续使用 `urhox-libs/UI`；本轮不使用 raw NanoVG（0.1.0）。
- D-003: 场景白模全部挂在 `SceneRoot` 下，切换时整组移除；出生点统一以安全地面高度 0.6 米设置（0.1.0）。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| 单机校验 | `scripts/main.lua` | 已完成；缺失/损坏/多人配置均日志退出 |
| 玩家状态字段 | `scripts/config/PlayerData.lua` | 已完成骨架；含 schemaVersion、belief、blossoms、memories、journal、flags、mediaPos |
| 统一完成结果 | `scripts/flow/FlowController.lua` | 已完成最小消费；`done=false` 不推进 |
| 三地点白模 | `scripts/game/SceneManager.lua` | 已完成 |
| 视频恢复/释放 | 后续 media 模块 | 未实现，按用户要求留待后续 |

## 避雷清单
- POST 是记忆存活唯一入口，每次交付后必须执行 3 步 POST。
- **运行时读取 `.project/settings.json` 要用 `fileSystem:FileExists` + `File(path, FILE_READ)`；`cache:Exists` 只检查资源缓存，运行时可能报告 missing。**
- **白模场景构建函数必须把 `SceneRoot` 作为父节点传入，不能在创建了容器后仍把对象挂到 `scene_`，否则旧场景碰撞体不会清理。**
- **验证器的 shader cache/audio/默认字体报错可能来自无图形沙箱环境；先单独检查 Lua runtime error 和节点/组件统计。**
- **InputManager 是项目输入抽象层；底层 `input` 只能在 `game/InputManager.lua` 内使用，业务模块通过封装查询。**

## 最近变更
- v0.1.0: 完成《桃素洛无幽·素女篇》单机 3D 白模骨架、严格配置校验、InputManager、场景根节点清理、统一完成结果最小闭环；LSP Error 为空，官方构建成功，运行时 Lua 错误为 0。

## 下一步
1. 接入媒体模块：S1~S9 播放生命周期、`mediaPos` 写入和三步 seek 恢复状态机。
2. 把 P02 老人触发从白模收集回调拆为真实交互玩法模块。
3. 补全 ch2/ch3/ch4 段落表与无面鬼/六艺/终局结果契约。
4. 最后再接正式模型、声音、桃花粒子与中文字体资源。

## 恢复指令（新会话必执行）
1. 读本文件 → 获取项目状态和避雷清单。
2. 读 `docs/memory-index.md` → 恢复项目上下文。
3. 读 `docs/persona.md` → 加载用户画像和偏好。
4. 自测：项目是什么？上次做了什么？下一步？不够清楚就多读文件。
5. 如有 likely_next_task → 预加载相关文件。
6. 详细规则见 memory-system skill。
