<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时先读取 CLAUDE.md、本文件和 docs/persona.md。 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：桃素洛无幽·素女篇
当前版本：0.1.0
简述：TapTap 制造 × Seedance 主题赛单机叙事游戏的 3D 白模与段落化流程骨架。
最后巩固：2026-08-20

## 项目概况
- UrhoX Lua 单机项目，唯一入口 `scripts/main.lua`。
- 三地点白模：朝阳谷口、谷内桃林、洛水阴山。
- 玩家移动/跳跃/第三人称相机/基础碰撞已接入。
- 章节数据驱动，当前骨架段落为 `P01→P02→P03→P04~P07→P11→P12→P99`。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 单机校验与唯一入口 |
| `scripts/game/InputManager.lua` | 输入抽象层 |
| `scripts/game/PlayerController.lua` | 移动、相机、角色碰撞 |
| `scripts/game/SceneManager.lua` | 三场景白模和 SceneRoot 生命周期 |
| `scripts/game/WhiteBox.lua` | 白模几何、材质、碰撞 |
| `scripts/config/PlayerData.lua` | 固定字段和类型兜底 |
| `scripts/config/Chapters.lua` | 段落表 |
| `scripts/flow/FlowController.lua` | 统一结果消费与段落推进 |
| `screenshots/chaoyang_gukou.png` | 初始白模截图 |

## 有效决策
- D-001：本轮不接视频、完整存档 IO、正式资产和后续章节。
- D-002：常规 UI 采用 `urhox-libs/UI`，本轮无 raw NanoVG。
- D-003：白模挂在 `SceneRoot`，切换整组销毁；玩家出生高度固定为 0.6 米以避免 Vector3 绑定读取异常。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| 单机配置 | `scripts/main.lua` | 已完成，配置异常退出 |
| PlayerData | `scripts/config/PlayerData.lua` | 骨架完成，含媒体字段 |
| Chapters | `scripts/config/Chapters.lua` | 当前两章骨架完成 |
| 完成结果 | `scripts/flow/FlowController.lua` | `done=false` 不推进 |
| 媒体恢复 | 后续模块 | 未开始 |

## 避雷清单
- TodoWrite 必须前置创建并包含 POST-1/2/3。
- `cache:Exists` 不等于运行时普通文件存在；读取 `.project/settings.json` 用 `fileSystem:FileExists` 与 `File`。
- 场景内容必须挂到 `SceneRoot`，否则切换后旧碰撞体残留。
- InputManager 封装所有业务输入访问，业务模块不得直接查询底层 `input`。
- 验证环境可能缺预编译 shader、音频设备和中文字体；先以 Lua runtime error、场景统计和截图判断业务结果。

## 最近变更
- v0.1.0：创建单机白模骨架，LSP Error 为空，官方构建成功；运行验证 Lua 错误为 0，节点 24、组件 64；已生成朝阳谷口截图。

## 下一步
1. 媒体播放器生命周期与断点恢复三步状态机。
2. P02 真实老人交互玩法。
3. ch2/ch3/ch4 和终局信念结果。
4. 正式模型、音频、粒子与中文字体。
