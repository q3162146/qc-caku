# 多语言资源变体指南（预览功能，原生平台尚未全面覆盖）

为不同语言提供不同版本的图片、音频等媒体资源（如中文标题图 → 英文标题图）。与 [i18n-translation.md](i18n-translation.md)（文本翻译）互补。

工作方式类似 Web 内容协商：同一个资源路径，引擎根据当前语言自动加载对应版本，代码无感知。缺少变体时降级到默认资源，不会报错。

## 操作流程

### 1. 确保 i18n 已启用

`.project/i18n.json` 中 `enabled: true`，且 `target_langs` 包含目标语言。

### 2. 放置变体文件

在默认资源**同目录**下，用 `@{lang}` 后缀命名：

```
assets/UI/
├── title.png            ← 默认（源语言）
├── title@en.png         ← 英文变体
├── title@ja.png         ← 日文变体
└── background.png       ← 无变体，所有语言共用
```

**规则**：默认资源（无 `@`）必须存在 | 语言码与 `i18n.json` 一致 | 只需为有差异的资源创建变体

### 3. 构建部署

构建工具自动扫描 `@` 文件并关联到默认资源。游戏代码**无需修改**。

## 运行时

```lua
-- 代码始终引用默认路径，引擎自动路由
local tex = cache:GetResource("Texture2D", "UI/title.png")
-- 英文环境 → title@en.png | 日文 → title@ja.png | 法文(无变体) → title.png

-- 切换语言：弹确认框，确认后自动 SetLanguage + 重启
i18n.RequestChangeLanguage("en")
```

## 适用场景

| 场景 | 做法 |
|------|------|
| 含文字的 UI 图片（logo、教程截图） | `logo.png` + `logo@en.png` |
| 多语言配音 | `narration.ogg` + `narration@en.ogg` |
| 语言专属字体 | `main_font.ttf` + `main_font@en.ttf` |
| 脚本/配置中的文字 | 用文本翻译（`_tr()`），不用资源变体 |

## API

| 接口 | 说明 |
|------|------|
| `i18n.RequestChangeLanguage(lang)` | 弹确认框，确认后切换语言并重启（推荐） |
| `i18n.SetLanguage(lang)` | 直接切换语言（不重启，内部使用） |
| `i18n.GetLanguage()` | 获取当前语言 |
| `i18n.GetSupportLanguages()` | 支持的语言列表，如 `{"zh_CN", "en"}` |
| `cache:SetVariantTag(priority, tag)` | 手动设置变体标签（i18n 自动调用，此外给扩展标签使用） |

## 多维变体（高级）

支持多个 `@` 后缀组合不同维度，顺序无关：

```
title@en@hd.png       ← 英文 + 高清
title@en.png          ← 英文
title@hd.png          ← 高清（任意语言）
title@review.png      ← 审核专用
title.png             ← 默认
```

优先级：review = 2100，i18n 语言标签 = 2000，自定义标签（如画质）< 2000。多标签同时生效时，引擎自动生成候选键序列，匹配第一个存在的变体。
