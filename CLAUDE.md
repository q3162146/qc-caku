# 《桃素洛无幽·素女篇》— 项目核心记忆

> AI 自维护项目状态。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.1.1-S1
- 进度: S1 竖屏 portrait 双层配置与三场景 9:16 白模布局完成
- 上次交付: 将 `.project/project.json` 改为 portrait；入口调用 `graphics:SetOrientations("Portrait")` 并记录运行时方向/尺寸；三场景改为窄 X、深 Z 的纵深白模布局；完成 LSP、官方构建和 9:16 截图验证

## 项目概况
- TapTap 制造 × Seedance 主题赛单机叙事游戏。
- 入口为 `scripts/main.lua`，运行时严格校验 `.project/settings.json` 的 `@runtime.multiplayer.enabled == false`。
- 当前只做白模与最小段落闭环：`P01 → P02 → P03 → P04~P07 → P11 → P12 → P99`。
- 三地点键：`chaoyang_gukou`、`gu_nei_taolin`、`luoshui_yinshan`。
- 规则状态集中在 `PlayerData`，剧情关系集中在 `config/Chapters.lua`，推进集中在 `flow/FlowController.lua`。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 唯一业务入口、单机校验、竖屏请求、场景基础设施、生命周期 |
| `scripts/game/InputManager.lua` | 平台触摸初始化与 KEY/MOUSE 枚举查询封装 |
| `scripts/game/PlayerController.lua` | 玩家胶囊碰撞、移动、跳跃、第三人称相机、触发器事件 |
| `scripts/game/SceneManager.lua` | 三个 9:16 纵深白模场景创建/销毁/切换 |
| `scripts/game/WhiteBox.lua` | 程序化材质、基础几何、宽深可配置边界墙与触发器 |
| `scripts/config/PlayerData.lua` | 固定存档字段、类型清洗、schemaVersion/mediaPos 契约 |
| `scripts/config/Chapters.lua` | 段落数据表与统一完成结果字段骨架 |
| `scripts/flow/FlowController.lua` | 读取段落、消费完成结果、应用共享状态、推进 next |
| `screenshots/s1/chaoyang_portrait.png` | 540×960 竖屏比例白模验证截图 |

## 有效决策
- D-001: 本轮只实现骨架、白模、移动/相机/碰撞与最小 flow，不接入视频、完整存档 IO、后续章节、正式角色和其他系统（0.1.0）。
- D-002: 常规对话 UI 继续使用 `urhox-libs/UI`；本轮不使用 raw NanoVG（0.1.0）。
- D-003: 场景白模全部挂在 `SceneRoot` 下，切换时整组移除；出生点统一以安全地面高度 0.6 米设置（0.1.0）。
- D-004: S1 先完成发布元数据 portrait + 运行时 `SetOrientations("Portrait")` 双层请求；运行时验证器接受该值，但无窗口环境无法证明制造/真机实际锁屏（0.1.1-S1）。
- D-005: 三场景按 9:16 纵深构图重排：窄 X 轴、深 Z 轴、主体沿纵深分布；未创建横竖双布局（0.1.1-S1）。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| 单机校验 | `scripts/main.lua` | 已完成；缺失/损坏/多人配置均日志退出 |
| 屏幕方向 | `.project/project.json` + `scripts/main.lua` | portrait + `SetOrientations("Portrait")` 已接入；真机锁屏待回归 |
| 玩家状态字段 | `scripts/config/PlayerData.lua` | 已完成骨架；含 schemaVersion、belief、blossoms、memories、journal、flags、mediaPos |
| 统一完成结果 | `scripts/flow/FlowController.lua` | 已完成最小消费；`done=false` 不推进 |
| 三地点白模 | `scripts/game/SceneManager.lua` | 已完成 9:16 纵深布局 |
| 视频恢复/释放 | 后续 media 模块 | 未实现，按任务纪律留待后续 |

## 避雷清单
- 一次会话只做一个 S 任务；完成后让 TTM 复盘代码并列待办。
- 文档 22 的 MP4/H.264、yuv420p、AAC-LC、48kHz、30fps、1080×1920、码率档位是兼容性测试起点，不是平台硬上限。
- 23 字符集共 1441 个唯一字符；正文不用书法体，书法体只用于章节名/题词并需逐字预检。
- 剧情播放器 1 个，连循环背景最多 2 个；播放完成必须 Destroy/Dispose；循环背景优先粒子或静态图。
- 分享卡先预生成三张；真机确认截图/分享链路后再升级运行时生成。
- 首次真机必须测后台/前台/通知栏返回、多播放器内存和音画同步。
- 运行时读取 `.project/settings.json` 要用 `fileSystem:FileExists` + `File(path, FILE_READ)`；`cache:Exists` 只检查资源缓存。
- `SetOrientations` 合法值仅当前运行时实测为 `Portrait` 被接受，制造/真机锁屏仍未确认，不能据此跳过真机测试。
- 白模场景构建函数必须把 `SceneRoot` 作为父节点传入，否则旧场景碰撞体不会清理。
- 验证器的 shader cache/audio/默认字体报错可能来自无图形沙箱；先单独检查 Lua runtime error、节点/组件统计和截图。
- InputManager 是项目输入抽象层；底层 `input` 只能在 `game/InputManager.lua` 内使用。

## 最近变更
- v0.1.1-S1: 完成 portrait 元数据、运行时方向请求、窄宽深场景布局、第三人称相机适配；LSP Error 为空，官方构建成功，9:16 截图生成，Lua runtime error 为 0。
- v0.1.0: 完成《桃素洛无幽·素女篇》单机 3D 白模骨架、严格配置校验、InputManager、场景根节点清理、统一完成结果最小闭环。

## 下一步
1. 让 TTM/真机复盘 S1：确认 portrait 是否实际锁定、刘海/安全区、9:16 视频适配和三场景镜头裁切。
2. 在独立 S 任务中接入一个短 S1 视频生命周期：创建、onReady、Seek、连续两次时间确认、暂停、onEnded、Destroy。
3. 在媒体接入前确认 22 的转码测试样本与 23 字符集字体预检。
4. 后续再做 P02 真实老人交互、媒体断点存档和 ch2/ch3/ch4。

## 恢复指令（新会话必执行）
1. 读本文件 → 获取项目状态和避雷清单。
2. 读 `docs/memory-index.md` → 恢复项目上下文。
3. 读 `docs/persona.md` → 加载用户画像和偏好。
4. 自测：项目是什么？上次做了什么？下一步？不够清楚就多读文件。
5. 如有 likely_next_task → 预加载相关文件。
6. 详细规则见 memory-system skill。
