# 多语言翻译指南（预览功能，原生平台尚未全面覆盖）

自动化多语言系统：从项目资源（脚本/配置/XML）中提取可翻译字符串，构建时将原文替换为 **翻译键**（如 `"t_1710742800_a3f2b1c9"`），运行时按语言查表翻译。

媒体资源（图片/音频/字体）的多语言方案见 [i18n-resource.md](i18n-resource.md)（资源变体）。

## 操作流程

当用户要求添加多语言支持时，按以下步骤执行：

### 0. 配置

确保 `.project/i18n.json` 中：
- `enabled: true`
- `target_langs` 包含目标语言（如 `["en"]`）

### 1. 提取

调用 MCP 工具 `i18n_extract`，扫描项目生成 `i18n/{lang}.pending.json`。

### 2. 翻译 pending.json

`pending.json` 以原文为键，填入译文为值：

```json
{
  "加载中...": "Loading...",
  "第 {0} 关": "Level {0}",
  "确认退出？": "Quit?"
}
```

**必须遵守：**
- 保留占位符：`{0}`, `{1}`, `{name}`, `%d`, `%s` 等原样保留
- 保留转义符：`\n`, `\t`, `\"` 保持不变
- 空值 = 未翻译：跳过的条目保持 `""`
- 不要修改键，只填写值
- 文件过大时分块翻译后合并

### 3. 应用

再次调用 `i18n_extract` 或 `build`，已填写的翻译会自动合并到 `i18n/{lang}.json`。

### 4. 构建

执行 `build`，构建时自动完成原文→ **翻译键** 替换，并生成运行时翻译文件。

### 修改已有翻译

直接编辑 `i18n/{lang}.json`，找到原文对应的条目修改译文：

```json
{
  "加载中...": "Loading...",
  "确认退出？": "Quit?"
}
```

`{lang}.json` 以原文为 key、译文为 value。用 grep 搜索原文即可定位，无需读取整个文件。

## 提取策略

字符串进入翻译管线有两种途径，可混合使用：

- **自动提取（默认）**：开发中无需关心 i18n。提取时逐行扫描项目资源，通过 `extract_rules` 正则匹配提取，再经三层排除规则过滤误匹配。
- **显式标记**：在脚本中直接使用 `_tr("文本")` 标记需要翻译的字符串，精准可控。用 `_raw("文本")` 保持原文，避免自动提取。

### 排除误匹配

当 `i18n_extract` 提取了不该翻译的字符串时，在 `.project/i18n.json` 中调整排除规则：

| 排除规则 | 用途 | 示例 |
|---------|------|------|
| `function_excludes` | 排除函数的字符串参数（仅脚本） | `"GetResource"`, `"print"` |
| `context_excludes` | 按同行上下文正则排除（前缀/后缀） | `require` 语句 |
| `content_excludes` | 按提取内容排除 | URL、文件路径 |

或在脚本中用 `_raw("文本")` 逐条精准排除。

## 构建与运行时

### 构建转换

构建时原文被替换为 **翻译键**（`t_xxx`）：

| 源码 | 构建产物 |
|------|---------|
| `"加载中..."` | `_tr("t_xxx")` |
| `"第 " .. level .. " 关"` | `_tr("t_xxx", level)`，`t_xxx` → `"第 {0} 关"` |
| `_raw("中文键")` | `"中文键"` |
| JSON/XML 中 `"加载中..."` | `"t_xxx"` |

**反查**：产物中看到 `t_xxx` → 在 `registry.json` 中查找原文和来源位置。

### 运行时 API

| 接口 | 说明 |
|------|------|
| `_tr(key, ...)` | 翻译函数，查表将 `t_xxx` 翻译为当前语言文本，支持 `{0}` 占位符，可在源码中显式标记翻译 |
| `_raw(text)` | 标记文本原样返回，不翻译 |
| `i18n.GetLanguage()` | 获取当前语言（优先级：用户偏好 > 系统语言 > `source_lang`） |
| `i18n.SetLanguage(lang)` | 切换语言并加载对应翻译表（内部使用） |
| `i18n.GetSupportLanguages()` | 获取支持的语言 |
| `i18n.GetLanguageDisplay(lang?)` | 获取语言显示名（如 `"简体中文"`），优先读 `i18n.json` 的 `lang_to_display`，有内置 fallback |

切语言用 `i18n.RequestChangeLanguage(lang)`（弹确认框 + 自动重启）

### 消费侧兜底 hook

以下接口内置了 `_tr()` hook，传入 `t_xxx` 会自动翻译：

`nvgText`、`nvgTextBox`、`nvgTextBounds`、`nvgTextBoxBounds`、`string.format`、`Text3D:SetText` 等

JSON/XML 中的 `t_xxx` 依赖这些 hook 翻译。

## 语言命名规范

语言代码遵循 BCP 47：语言码（ISO 639-1）+ 区域码（ISO 3166-1），如 `en`、`zh_CN`。**无歧义用裸码，有歧义加区域**：`en`、`ja`、`ko`、`zh_CN`、`zh_TW`。

- 不要写 `en_US`（`en` 能匹配所有英语变体）
- 不要写 `zh` 或 `zh_Hans`（无法区分简繁）
- 中文必须带区域：`zh_CN`（简体）、`zh_TW`（繁体）

此规范仅影响系统语言自动匹配的命中率，不影响用户手动选择语言。

## 配置：.project/i18n.json

自动化多语言提取的核心配置，定义提取规则、排除规则和翻译输出选项。AI 和用户均可修改。

| 字段 | 说明 |
|------|------|
| `enabled` | `true` 启用构建时多语言，`false` 跳过 |
| `source_lang` | 源语言（如 `"zh_CN"`） |
| `target_langs` | 目标语言数组（如 `["en"]`） |
| `file_exts` | 扫描的文件类型（默认：`[".lua", ".json", ".xml"]`） |
| `extract_rules` | 逐行正则提取规则（详见 schema） |
| `function_excludes` | 排除的函数名（仅脚本） |
| `context_excludes` | 同行上下文正则排除 |
| `content_excludes` | 按提取内容排除 |
| `lang_to_display` | 语言显示名映射（如 `{"zh_CN": "简体中文", "en": "English"}`），用于语言选择 UI |

完整字段参考 `schemas/i18n.schema.json`。

## 文件位置

| 文件 | 用途 | AI 操作 |
|------|------|---------|
| `i18n/{lang}.pending.json` | 待翻译条目（填入译文后再次调用 `i18n_extract`，自动合并到 `{lang}.json`） | 批量翻译时编辑此文件 |
| `i18n/{lang}.json` | 累积翻译表（原文→译文，只含已翻译条目） | 修改已有翻译时 grep 原文定位编辑 |
| `i18n/registry.json` | 原文 → 翻译键映射及来源位置 | 勿编辑，可用于溯源 `t_xxx` 出处 |
| `i18n/.cache.json` | 提取缓存 | 勿编辑 |

**翻译进度**：打开 `{lang}.pending.json`，有内容 = 有未翻译条目，空 `{}` = 全部已翻译。
