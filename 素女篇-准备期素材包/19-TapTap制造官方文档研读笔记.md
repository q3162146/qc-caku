# 19-TapTap 制造官方文档研读笔记（2026-08-14）

> 用途：准备期提前研读官方文档/教程，把交接文档第五节第 7 步"能力确认"提前答掉大半；8/19 建项目后只需编辑器内实测收尾。
> 边界提醒：以下多为 TapTap 生态公开文档与社区教程，**最终能力以 TapTap 制造编辑器内实测为准**（8/19 后第一件事，见《12》第 6 节）。

---

## 1. 官方文档入口

| 资源 | 链接 | 内容 | 对本项目的价值 |
|------|------|------|----------------|
| TapTap 开发者文档（官网） | [developer.taptap.io](https://developer.taptap.io/docs/) | 平台开发者文档总入口（物料、审核、发布） | 发布流程、商店物料规范 |
| 物料要求 | [store-material](https://developer.taptap.io/docs/zh-Hans/store/store-material/) | 商店页物料（视频/截图/图标/主视觉）规格 | 9/6 提交审核、商店页物料准备（对照《16》） |
| TapTap 制造服务协议 | [tpp315.com](https://www.tpp315.com/doc/taptap-maker-agreement/) | 制造工具使用协议（生成内容版权/积分/合规） | 合规边界、AI 内容标注要求（对照《04》合规 2/3 条） |

## 2. 已确认/待确认的能力清单（对应《12》第 6 节四问）

| 《12》问题 | 准备期结论（2026-08-14） | 8/19 编辑器实测项 |
|-----------|--------------------------|-------------------|
| ① 视频播放接入方式（视频资源/UI 视频组件/场景视频纹理）与格式码率 | 未找到 TapTap 制造专属视频组件文档；TapTap 生态有 `tap.createVideo` 视频 API（[文档](https://developer.taptap.cn/minigameapidoc/dev/api/media/video/tap.createVideo/)），但制造为 UrhoX+Lua 编辑器，接入方式需实测确认 | **必须实测**：视频资源/视频纹理/UI 组件三种方式哪个可用、MP4 编码与码率上限 |
| ② 自定义字体上传（书法体/楷体）、生僻字渲染 | TapTap 生态有 `tap.loadFont` 字体加载 API（[文档](https://developer.taptap.cn/minigameapidoc/dev/api/render/font/tap.loadFont/)）；制造内是否支持上传字体、生僻字（如"无涕"）需实测 | **必须实测**：字体上传路径、书法体/楷体、生僻字缺字 |
| ③ 结局分享卡生成/截图 API | 未查到制造内截图/分享卡 API 文档 | **必须实测**：截图 API、分享卡保存/分享 |
| ④ 音频支持格式 | 未查到制造内音频格式文档 | **必须实测**：配音/音效/音乐的导入格式（MP3/WAV/OGG？） |

> 补充：TapTap 生态有屏幕方向 API `tap.setDeviceOrientation`（[文档](https://developer.taptap.cn/minigameapidoc/dev/api/device/orientation/tap.setDeviceOrientation/)）——竖屏 9:16 目标（《13》）需确认制造内锁定方向方式。

## 3. 官方/社区教程与经验（已收集）

| 资源 | 链接 | 价值 |
|------|------|------|
| TapTap 制造上手指南 | [taptap.cn/moment/777645108861338642](https://www.taptap.cn/moment/777645108861338642) | 建项目、素材上传、AI 协作基本流程 |
| UI 教程（省积分、精准还原布局） | [taptap.cn/moment/802553300242137302](https://www.taptap.cn/moment/802553300242137302) | 对 S8 UI 打磨、控制 Token 消耗有用 |
| 《塔拉拉调教指南》 | [taptap.cn/moment/789403125017480907](https://www.taptap.cn/moment/789403125017480907) | 与 AI 开发 Agent 协作的提示词技巧 |
| TapTap 制造 3D 模型注意事项 | [taptap.cn/moment/787447985632969326](https://www.taptap.cn/moment/787447985632969326) | 场景白模、模型尺度（配合《12》§1 规范 4） |
| TapTap 制造无门槛开放测试 | [taptap.cn/moment/837353116297855382](https://www.taptap.cn/moment/837353116297855382) | 确认工具开放状态（报名资格相关） |
| 制作负责人访谈（姜黎） | [品玩](https://www.pingwest.com/a/312284) | 理解制造的产品定位与能力边界 |
| 零基础开发者体验帖 | [taptap.cn/moment/817725270562704439](https://www.taptap.cn/moment/817725270562704439) | 了解常见坑（Token 消耗、生成失败等） |
| 制作 3D 模型注意事项（社区） | [taptap.cn/moment/787447985632969326](https://www.taptap.cn/moment/787447985632969326) | 同上 |

## 4. 服务协议要点（合规速记）

> 完整条款以 [服务协议](https://www.tpp315.com/doc/taptap-maker-agreement/) 原文为准，以下为研读提示：

- **生成内容归属/授权**：AI 生成内容的使用边界以协议为准，发布前核对平台 AI 内容标注要求（与《04》合规第 3 条一致）。
- **积分使用**：活动积分仅限绑定项目使用（与《04》一致），滥用可能取消资格。
- **原创与合规**：素材须原创或已授权，符合平台内容规范（与《04》合规第 2 条一致）。
- **账号与绑定**：每个账号绑定一个合规新项目，绑定后不可改绑（与《04》一致）。

## 4b. 审核与发布（补充检索 2026-08-14）

| 主题 | 链接 | 要点 |
|------|------|------|
| 游戏审核规范细则 | [developer.taptap.io 审核规范](https://developer.taptap.io/docs/zh-Hans/store/store-agree/)、[taptap.cn 开发者文档](https://developer.taptap.cn/docs/store/release/publish/agree/) | 提交审核前逐条对照（9/6 提交前必查） |
| 宣发物料指引（小游戏） | [宣发物料指引](https://developer.taptap.cn/minigameapidoc/quick-start/guide/game-publish/material/) | 商店页视频/截图/图标规格（对照《16》） |
| 截图生成 API（分享卡线索） | [Canvas.toTempFilePath](https://developer.taptap.cn/minigameapidoc/dev/api/render/canvas/Canvas.toTempFilePath/) | Canvas 截图导出为临时文件——**结局分享卡**（《12》问题 ③）在 TapTap 小游戏生态有实现路径；制造内是否可用仍需实测 |
| 视频 API | [tap.createVideo](https://developer.taptap.cn/minigameapidoc/dev/api/media/video/tap.createVideo/) | 生态内视频对象 API；制造内接入方式待实测 |
| 录音 API | [RecorderManager.start](https://developer.taptap.cn/minigameapidoc/dev/api/media/recorder/RecorderManager.start/) | 生态内录音 API（本项目不直接需要，可忽略） |

## 5. 8/19 收尾动作（基于本笔记）

1. 建项目后把本笔记第 2 节四问 + 竖屏方向问题一次性抛给 TTM AI 开发 Agent（对照《12》第 6 节）
2. 对照官方"物料要求"与"宣发物料指引"核对《16》商店页物料规格（视频 ≤1GB、截图、主视觉）
3. 通读服务协议与审核规范细则原文，若有与《04》冲突处立即更新
4. 分享卡：若制造支持 Canvas 截图（对照 `Canvas.toTempFilePath` 思路），S7 实现结局分享卡；不支持则退回"生成图片保存"方案
5. 把实测结论回写本笔记（在"8/19 编辑器实测项"列打勾）
