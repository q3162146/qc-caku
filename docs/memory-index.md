<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时先读取 CLAUDE.md、本文件和 docs/persona.md。 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：桃素洛无幽·素女篇
当前版本：0.1.1-S1
简述：TapTap 制造 × Seedance 主题赛单机叙事游戏；已完成单机 3D 白模骨架与 S1 竖屏 9:16 布局调整。
最后巩固：2026-08-20

## 项目概况
- UrhoX Lua 单机项目，唯一入口 `scripts/main.lua`。
- 三地点白模：朝阳谷口、谷内桃林、洛水阴山。
- 玩家移动/跳跃/第三人称相机/基础碰撞已接入。
- 章节数据驱动，当前骨架段落为 `P01→P02→P03→P04~P07→P11→P12→P99`。
- S1 已将发布配置设为 portrait，并在运行时调用 `graphics:SetOrientations("Portrait")`。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 单机校验、竖屏方向请求与唯一入口 |
| `scripts/game/InputManager.lua` | 输入抽象层 |
| `scripts/game/PlayerController.lua` | 移动、相机、角色碰撞；竖屏镜头距离/高度已调整 |
| `scripts/game/SceneManager.lua` | 三场景 9:16 纵深白模和 SceneRoot 生命周期 |
| `scripts/game/WhiteBox.lua` | 白模几何、材质、可配置宽深边界墙、碰撞 |
| `scripts/config/PlayerData.lua` | 固定字段和类型兜底 |
| `scripts/config/Chapters.lua` | 段落表 |
| `scripts/flow/FlowController.lua` | 统一结果消费与段落推进 |
| `screenshots/s1/chaoyang_portrait.png` | 540×960 竖屏比例白模截图 |

## 有效决策
- D-001：本轮不接视频、完整存档 IO、正式资产和后续章节。
- D-002：常规 UI 采用 `urhox-libs/UI`，本轮无 raw NanoVG。
- D-003：白模挂在 `SceneRoot`，切换整组销毁；玩家出生高度固定为 0.6 米。
- D-004：portrait 元数据和运行时 `SetOrientations("Portrait")` 双层请求已完成；无窗口验证只能证明 API 接受，不能证明制造/真机锁屏。
- D-005：三场景采用窄 X、深 Z 的 9:16 纵深构图，不维护横竖双布局。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| 单机配置 | `scripts/main.lua` | 已完成，配置异常退出 |
| 屏幕方向 | `.project/project.json` + `scripts/main.lua` | portrait + Portrait 请求已接入，真机待确认 |
| PlayerData | `scripts/config/PlayerData.lua` | 骨架完成，含媒体字段 |
| Chapters | `scripts/config/Chapters.lua` | 当前两章骨架完成 |
| 完成结果 | `scripts/flow/FlowController.lua` | `done=false` 不推进 |
| 媒体恢复 | 后续模块 | 未开始 |

## 避雷清单
- 一次会话只做一个 S 任务；结束时让 TTM 复盘代码并列待办。
- 22 的视频/音频规格是首轮兼容性测试起点；23 字符集共 1441 字符，正文不用书法体。
- 剧情播放器 1 个，带循环背景最多 2 个；播完 Destroy/Dispose。
- 分享卡先预生成三张，真机确认后再做运行时分享。
- 首次真机必须测后台/前台/通知栏返回、多播放器内存、音画同步。
- `cache:Exists` 不等于运行时普通文件存在；settings 使用 `fileSystem:FileExists` 与 `File`。
- `SetOrientations("Portrait")` 已被本地运行时接受，但合法值和制造/真机锁屏仍需验证。
- 场景内容必须挂到 `SceneRoot`，否则切换后旧碰撞体残留。
- InputManager 封装所有业务输入访问。
- 验证环境可能缺 shader/audio/默认字体；先看 Lua 错误、场景统计和截图。

## 最近变更
- v0.1.1-S1：完成 portrait 元数据、运行时方向请求、三个白模的 9:16 纵深重排、相机镜头调整；LSP Error 为空，官方构建通过，Lua runtime error 为 0，生成 540×960 截图。
- v0.1.0：创建单机白模骨架，完成三场景、PlayerData、Chapters、Flow、移动相机与基础碰撞。

## 下一步
1. TTM/真机复盘 S1：实际锁屏、刘海安全区、9:16 视频适配、三个场景镜头裁切。
2. 独立 S 任务接入一个短 S1 视频完整生命周期。
3. 采用 22 规格制作测试视频，并用 23 字符集完成字体预检。
4. 后续做 P02 真实老人交互、媒体断点存档和 ch2/ch3/ch4。
