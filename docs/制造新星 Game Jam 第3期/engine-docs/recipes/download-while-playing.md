# 边玩边下（Download While Playing）

## 心智模型

DWP 的工作方式**类似浏览器加载网页**：

| 浏览器 | UrhoX DWP |
|--------|-----------|
| `<head>` 中的 CSS/JS — 阻塞渲染，必须先加载 | **Render-blocking 资源**（脚本、配置、可序列化资源等）— 启动前预加载 |
| `<img src="...">` — 先占位，图片到了自动显示 | **DWP 媒体资源**（纹理、动画、音效等）— 先占位，下载后热替换 |
| `fetch()` — 异步请求，主动获取 | **非 render-blocking 资源** — 可通过 `GetResourceAsync` / `DownloadResource` 主动下载 |

**几乎不需要关心 DWP**。当通过 `cache:GetResource()` 获取 DWP 类型资源时（如 `cache:GetResource("Texture2D", uri)`），DWP 自动触发。而且很多场景下你不会直接调用它：Prefab/序列化场景由引擎反序列化时内部调用，UI 系统的图片字体由 UI 库内部加载，DWP 均自动生效。

---

## 资源分类

### Render-blocking（启动前预加载，类似 `<script>` / `<link rel="stylesheet">`）

> 以下为当前的 render-blocking 扩展名列表，后续版本可能调整。

| 扩展名 | 说明 |
|--------|------|
| `.lua` | 脚本 |
| `.json` `.xml` `.material` | 配置、序列化数据、材质 |
| `.prefab` `.effect` | Node预制体、特效预制体 |
| `.fsm` `.blendspace` | 动画状态机、动画混合空间 |

Render-blocking 资源在脚本启动前已全部就绪，可在游戏脚本中直接通过 `cache:GetResource()` 使用，无需额外处理。

### DWP 媒体资源（占位→热替换，类似 `<img src="...">`）

DWP 按运行时资源**类型** 判断是否支持占位热替换。资源未就绪时会显示占位（默认纹理、T-pose、静音等），下载完成后自动替换为真实资源，**这是正常的 DWP 行为**。

| 资源类型 | 常见扩展名 |
|---------|-----------|
| `Texture2D` / `Texture3D` / `TextureCube` / `Texture2DArray` | `.png` `.jpg` `.tga` `.dds` `.ktx` 等 |
| `Image` | `.png` `.jpg` `.tga` 等 |
| `Model` | `.mdl` |
| `Animation` / `LogicalAnimation` | `.ani` |
| `Sound` | `.ogg` `.mp3` `.wav` 等 |
| `Font` | `.ttf` `.otf` 等 |

### 其他资源（需手动下载）

不属于上述两类的资源（如 `.bin`、`.dat`、`.csv` 等自定义数据文件），引擎**既不会预加载，也没有占位机制**。直接调用 `cache:GetResource()` 会返回 nil 并产生负缓存。

正确用法：先通过 `GetResourceAsync` 或 `DownloadResource` 确保资源就绪后再使用。

---

## 什么时候需要手动介入

大多数资源的加载和下载由引擎自动完成。只有以下场景需要脚本主动介入：

- **消除视觉跳变** — DWP 媒体资源先显示占位再热替换，如果不希望玩家看到跳变：
  - `ObserveDownloads`（推荐）— 无需知道具体资源，监测所有后台下载，可下载期间展示 loading 遮罩
  - `GetResourceAsync` — 针对单个资源，等真实资源就绪后再使用
- **已知资源的预下载** — 进入下一关前预下载该关卡的资源，用 `DownloadResources`（需提供资源列表）
- **其他类型资源** — 非 render-blocking、非 DWP 类型的资源必须主动下载后使用（见上方"其他资源"）

---

## API

> 仅上述场景需要以下接口，其余情况 DWP 自动生效。

所有 DWP 相关 API 统一在 `cache` 对象上。URI 参数接受项目资源及其引用的远端资源（如官方资源库）的路径（`uuid://{uuid}` 或 `{virtual_path}`），不支持任意第三方 URL。完整类型签名见 `.emmylua/ResourceCache.extensions.d.lua`。

```lua
local cache = GetCache()
```

### 异步加载

异步下载（如需）并加载资源，完成后回调。适用于等待真实资源就绪、加载未预加载的资源等场景。

```lua
cache:GetResourceAsync("Texture2D", "Textures/unlocked_skin.png", function(resource)
    if resource then skinSprite:SetTexture(resource) end
end)
```

### 下载

> Render-blocking 资源由引擎自动预下载。以下是**脚本运行时**主动发起的下载。

```lua
cache:DownloadResource(uri, function(success, errorMessage)
    if success then ... end
end)

-- 批量下载：递归依赖 或 直接列出
local refs = cache:GetResRefs("Environment/Props/Fence05/Fence05.prefab", true)
cache:DownloadResources(refs,
    function(success, failedCount) ... end,           -- onComplete
    function(completed, total, downloadedBytes, totalBytes)  -- onProgress（可选）
        UpdateProgressBar(completed / total)
    end)

cache:CancelDownload(uri)                -- 取消单个
cache:CancelDownloadGroup(groupId)       -- 取消批量（groupId 由 DownloadResources 返回）
cache:GetDownloadState(uri)              -- → DOWNLOAD_PENDING / DOWNLOADING / COMPLETED / FAILED / CANCELLED
```

### 全局下载进度观察

无需指定具体资源，自动监测**所有后台下载活动**。适合在关卡入口展示 loading 遮罩。

```lua
-- 传入 onComplete：activeCount 归零时自动结束观察
cache:ObserveDownloads(
    function(completedCount, totalCount, completedBytes)
        UpdateLoadingBar(completedCount / totalCount)
    end,
    function(completedBytes) HideLoadingScreen() end  -- onComplete（不传则持续观察）
)

-- 持续观察模式，需手动结束
local id = cache:ObserveDownloads(function(completed, total, bytes) ... end)
cache:StopObservingDownloads(id)
```

### 资源查询

```lua
cache:GetResInfo(uri)           -- → { uuid, fsPath, size, source, ext } | nil
cache:GetResRefs(uri, true)     -- 递归依赖列表（uuid:// 形式），includeSelf 默认 false
cache:GetResVirtualPath(uri)    -- → "Textures/hero.png"
cache:GetResUuid(uri)           -- → "B_J0gVyL..."（裸 UUID）
cache:GetResUuidPath(uri)       -- → "uuid://B_J0gVyL..."
```

---

## 从全量下载迁移到 DWP

旧项目默认全量预加载所有资源（通过 `.project/resources.json` 的 `preload_groups` 配置）。要启用 DWP：

清空 `preload_groups` 字段（设为 `[]` 或删除）即可。

```jsonc
// .project/resources.json — 启用 DWP
{
  "preload_groups": [],  // 仅清空该字段
  ...
}
```

---

## 注意事项

| 事项 | 说明 |
|------|------|
| **URI 来源** | 资源接口只接受 `uuid://{uuid}` 或 `{virtual_path}`，不支持第三方 URL。VideoPlayer 额外支持 `https://` URL |
| **负缓存** | 对未下载的非 DWP 资源调用 `GetResource` 会产生负缓存（后续调用直接返回 nil）；发起下载时会自动清理，但下载完成前不要调用 `GetResource` 以免重新污染 |
| **自动去重** | 同一资源多次调用 `DownloadResource` 不会重复下载 |
| **不要轮询** | 应使用下载接口的回调参数，不要写 `while GetDownloadState() ~= COMPLETED` 循环 |
| **`Exists()` 仅检查本地** | `cache:Exists(uri)` 检查资源是否已在本地，不触发下载与载入 |
| **服务端模式** | 服务端额外把 `.mdl` 加入 render-blocking（物理碰撞依赖）；DWP 媒体资源一般不参与逻辑，服务端仅占位不下载 |

---

## 相关文档

- [资源预下载与构建引用](preload-and-build-refs.md) — 资源的构建引用策略、预下载策略、资源缺失排查
