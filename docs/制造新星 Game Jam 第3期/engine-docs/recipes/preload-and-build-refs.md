# 资源预下载与构建引用（预览版）

本文档介绍如何控制资源的构建引用策略、预下载策略，以及资源缺失的问题排查。

> 关于运行时 DWP 机制（占位、热替换、手动下载 API），详见 [边玩边下（DWP）](download-while-playing.md)。

---

## 概念

### 构建引用

`resources.json` 中的 `groups` 决定构建引用模式：

| 模式 | 触发条件 | 行为 |
|------|---------|------|
| **全量引用** | `groups` 中存在独立的 `**` 条目 | 所有本地资源入包 |
| **增强引用** | `groups` 中无独立的 `**` 条目（如 `scripts/**`） | 从根资源出发，递归追踪引用链，仅可达资源入包，未引用资源裁剪 |

构建器自动检测，无需手动配置。

### 预下载

`resources.json` 中的 `preload_groups` 决定哪些资源启动时预先下载，不在预下载组内的资源由引擎 DWP 按需下载。

---

## 典型配置

### 1. 全量引用 + 全预下载（早期版默认项）

所有资源入包，启动时全部预下载。最简单，无裁剪。

```jsonc
// resources.json
{
  "preload_groups": ["default"],
  "groups": {
    "default": ["**"]
  }
}
```

### 2. 增强引用 + 预下载

仅脚本引用链可达的资源入包，启动时预下载。适合资源量大但脚本只用到部分资源的项目。

```jsonc
// resources.json
{
  "preload_groups": ["default"],
  "groups": {
    "default": ["scripts/**"]
  }
}
```

### 3. 全量引用 + DWP （新版本默认项）

所有资源入包，不预下载，全部由引擎 DWP 按需下载。

```jsonc
// resources.json
{
  "preload_groups": [],
  "groups": {
    "default": ["**"]
  }
}
```

### 4. 增强引用 + DWP

仅可达资源入包，且不预下载，全部由引擎 DWP 按需下载。启动最快，适合资源量大的项目。

```jsonc
// resources.json
{
  "preload_groups": [],
  "groups": {
    "default": ["scripts/**"]
  }
}
```

---

## groups 模式说明

`groups` 的 glob 模式匹配的是资源相对于 `settings.json` 中 `asset_dirs` 的路径（`fs_path`）。同时也支持以 `asset_dirs` 目录名为前缀的路径：

```jsonc
// settings.json
{
  "$schema": "../schemas/settings.schema.json",
  "build": {
    "asset_dirs": ["../assets", "../scripts"]
  }
}
```

| 模式 | 匹配范围 |
|------|---------|
| `**` | 所有 asset_dir 下的所有文件 |
| `scripts/**` | `../scripts` 目录下的所有文件 |
| `**.lua` | 所有 asset_dir 下的 `.lua` 文件 |

---

## 标准引用计算

默认的引用计算基于 `uuid://{uuid}` 精确匹配 UUID 字符串，高效精准。主要用于引擎资源、依赖资源的关联，与路径无关，资源的路径或命名变更不受影响。

---

## 增强引用计算

1. `groups` 模式匹配的文件作为根资源
2. 从根资源出发，递归分析文本中引用的资源路径
3. 沿引用链递归展开，所有可达资源入包，其余裁剪

**示例引用链**：

```
main.lua                        ← groups 匹配，根资源
  → "config/game.json"          ← Lua 中的字符串字面量，命中资源路径
    → "Textures/player.png"     ← JSON 中的字符串值，命中资源路径
    → "Sounds/bgm.ogg"          ← 同上
```

**根据文本类型匹配字符串路径**，目前支持：`.lua` 提取单双引号字符串并跳过 require、`.json` 提取双引号字符串、引擎 xml 格式解析属性。

**兜底机制**：对于路径拼接场景，提取到的片段（如 `imageRoot .. imageId .. "_normal.png"`）精确匹配失败后，会用 endswith `"_normal.png"` 模糊匹配项目资源中符合的路径。但兜底匹配不保证覆盖所有拼接情况，**建议始终使用完整路径字面量**，避免依赖路径拼接。

---

## 切换指南

### 从全量引用切换到增强引用

将 `groups` 中的独立 `**` 改为具体模式：

```diff
 {
   "groups": {
-    "default": ["**"]
+    "default": ["scripts/**"]
   }
 }
```

### 从预下载切换到全 DWP

清空 `preload_groups`：

```diff
 {
-  "preload_groups": ["default"],
+  "preload_groups": [],
   ...
 }
```

构建日志会提示当前策略：

```
[INFO]  构建策略: 增强引用 — 检测到 groups 无全量通配 **，仅包含可达资源，未引用资源将被裁剪
[INFO]  预下载: 未启用 — 检测到 preload_groups 为空，全部资源由引擎 DWP 按需下载
```

> DWP 运行时细节（占位策略、手动下载 API、进度监听等），详见 [边玩边下（DWP）](download-while-playing.md)。

---

## 问题排查

运行时出现 `Could not find resource xxx` 时，按以下顺序排查：

| 原因 | 排查方式 |
|------|---------|
| 资源未被引用计算覆盖 | 增强引用模式下，资源路径通过复杂拼接生成（如 `"characters/" .. name .. ".png"`），构建器无法提取完整路径。解决方式：在代码中显式引用完整路径字面量，或将该资源或资源父级加入 groups 模式 |
| 资源未下载 | 未被加入预下载的非 DWP、非 Blocking 资源（资源分类详见 [DWP](download-while-playing.md)）。确认资源所在 group 是否已加入 `preload_groups`，或在运行时通过 `cache:DownloadResource` 手动下载 |
| 资源不存在或未被包含 | 检查文件是否在 `asset_dirs` 目录下，有对应的 `.meta` 文件，且被引用或被 groups 模式匹配 |
| 引号匹配干扰 | 同一行代码中，双引号字符串内含单引号（如 `"it's"`）可能干扰相邻资源路径的提取。避免在资源路径所在行混用引号，或将资源路径单独一行书写 |

> **构建产物的 manifest 中不存在的本地资源，运行时一定无法访问。**
