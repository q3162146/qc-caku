# 程序化 / 离线 Lua（用引擎跑一段脚本然后退出）

> 本文档讲**怎么写**这类脚本。**怎么调用 / 走哪个 CLI**在 `run-lua-headless` skill 里。
>
> 🔴 **运行环境**：程序化 / 离线 Lua 依赖托管（maker 云端）的 headless 运行时工具链（配套 `run-lua-headless` skill），本地开源环境一般用不到。下文 `/workspace/...` 为云端沙箱的绝对路径布局。

## 何时走这条路

需要一次性用引擎接口算个东西、写个文件、然后退出。典型场景：

- **程序化贴图**：噪声纹理、调色板、placeholder PNG、UI atlas 拼合
- **数据预生成**：用 `math.random` + 项目业务规则生成关卡数据 / 配置 JSON
- **批处理 Prefab / Scene**：字段迁移、批量调参、版本升级
- **离线烘焙**：CPU 物理预解算、Navigation mesh 烘焙、字体光栅化到位图

跟"游戏脚本"的根本区别：

| 维度 | 游戏脚本 | 程序化脚本 |
|---|---|---|
| 入口 | `function Start()` 起，主循环里持续 Update | `function Start()` 起，做完一次性工作就 `engine:Exit()` |
| 渲染 | 真渲染、看效果 | 不产出渲染像素，只做计算和落盘 |
| 落盘 | 相对路径（写到游戏隔离 savedata） | 绝对路径（写到 `/workspace/assets/...` 直接交付项目） |
| 失败处理 | 弹错、recover、继续跑 | 立即 fail-loud（写 log、非零退出码） |

## 脚本模板（必须遵守）

```lua
function Start()
    local ok, err = pcall(function()
        -- 你的工作写在这里
    end)
    if not ok then
        log:Write(LOG_ERROR, "[procedural] " .. tostring(err))
    end
    engine:Exit()   -- ★ 必须 ★ 不调就卡主循环，命中调用方超时
end
```

三个不变量：

1. **`pcall` 包住业务逻辑**——别让 Lua 报错把整个进程崩掉、把日志方向带偏。
2. **失败用 `log:Write(LOG_ERROR, ...)` 记**——上游能从 stdout 读到准确错因。
3. **`engine:Exit()` 必须在 `pcall` 之外**——无论成功失败都要退。

## 能做什么、不能做什么

这个模式是离线/批处理用途，**不产出渲染像素**。

| ✅ 能 | ❌ 不能 |
|---|---|
| `Image:SetPixel / SetSize / Resize / SavePNG / SaveJPG / SaveTGA / Clear` 等 CPU 像素操作 | 任何需要看到屏幕渲染结果的能力 |
| `Scene:LoadXML / SaveXML`、`Node:CreateChild`、组件序列化 | RenderToTexture、shader 后处理、compute、skybox 卷积 |
| Lua 全套，`require` 项目的 `urhox-libs/` | UI 真正渲染像素（创建 UIElement 不报错，但看不到结果） |
| `cache:GetFile` / `cache:GetResource` 读项目 assets | `Audio` 播放 |
| `RigidBody` / `CollisionShape` 物理模拟 step | 任何对 `Renderer` 输出做截图 |
| `NavigationMesh:Build()` | |
| `FreeType` 字体光栅到 `Image` | |

判别口诀：**接口名带 "GPU / Render / Shader / Texture upload" 的多半出不来结果，带 "Image / Scene / File / Resource" 的多半能用。**

## 实例：噪声贴图

```lua
function Start()
    local ok, err = pcall(function()
        local img = Image()
        local W, H = 256, 256
        img:SetSize(W, H, 4)
        math.randomseed(42)
        for y = 0, H - 1 do
            for x = 0, W - 1 do
                local n = (math.sin(x * 0.05) + math.cos(y * 0.05)) * 0.5 + 0.5
                img:SetPixel(x, y, Color(n, n * 0.6, 1.0 - n, 1.0))
            end
        end
        assert(img:SavePNG("/workspace/assets/Textures/noise.png"), "SavePNG failed")
        print("[procedural] wrote /workspace/assets/Textures/noise.png")
    end)
    if not ok then log:Write(LOG_ERROR, "[procedural] " .. tostring(err)) end
    engine:Exit()
end
```

## 实例：Prefab 字段迁移

```lua
function Start()
    local ok, err = pcall(function()
        local files = cache:GetFileSystem():ScanDir(
            "/workspace/assets/Prefabs/", "*.xml", SCAN_FILES, false)
        for _, name in ipairs(files) do
            local fullPath = "/workspace/assets/Prefabs/" .. name
            local scene = Scene()
            scene:LoadXML(File(scene:GetContext(), fullPath, FILE_READ))
            -- 在这里改字段，例如把所有旧 "Speed" 属性 *= 2
            for _, node in ipairs(scene:GetChildren(true)) do
                local body = node:GetComponent("RigidBody")
                if body then body:SetMass(body:GetMass() * 2) end
            end
            assert(scene:SaveXML(File(scene:GetContext(), fullPath, FILE_WRITE)))
            print("[procedural] migrated " .. name)
        end
    end)
    if not ok then log:Write(LOG_ERROR, "[procedural] " .. tostring(err)) end
    engine:Exit()
end
```

## 实例：用 `urhox-libs` 跑业务计算

```lua
local LevelGen = require("urhox-libs/MyProject/LevelGen")

function Start()
    local ok, err = pcall(function()
        local levels = LevelGen.generate(20, { seed = 12345, difficulty = "hard" })
        local f = File(GetContext(), "/workspace/assets/Data/levels.json", FILE_WRITE)
        f:WriteString(cjson.encode(levels))
        f:Close()
    end)
    if not ok then log:Write(LOG_ERROR, tostring(err)) end
    engine:Exit()
end
```

## 落盘约定

- **正式产物** → `/workspace/assets/...`（项目正常资源位置，游戏脚本能 `cache:GetResource()` 直接用）
- **临时 / 调试** → `/tmp/...` 或 `/workspace/.tmp/...`
- **不要写**：`/workspace/scripts/`（脚本目录混入数据文件会污染） / 系统目录 / 引擎目录

## 日志和错误诊断

**没有文件日志**，全部走 stdout。默认日志级别 = **WARNING**，`INFO` 级被过滤：

| 来源 | 是否出现在 stdout |
|---|---|
| `print(...)` | ✅ 总是（走 `LOG_RAW`，不受 level 过滤） |
| `log:Write(LOG_WARNING, ...)` / `log:Write(LOG_ERROR, ...)` | ✅ |
| `log:Write(LOG_INFO, ...)` | ❌ 被默认级别吞掉，**用 `print(...)` 代替做进度提示** |
| 引擎自身的 WARNING / ERROR 日志 | ✅ |
| 引擎自身的 INFO 日志（init chatter） | ❌ 被吞掉，这正是我们要的 |

- Lua 抛 error 但被 `pcall` 接住 → `err` 字符串完整、行号准确，**一定 `log:Write(LOG_ERROR, ...)` 出来**（不然 stdout 上看不到）
- 没被 `pcall` 接住 → 进程未必崩，但 `Start()` 提前结束，`engine:Exit()` 不会被调，最后超时

## 相关

- `run-lua-headless` skill：CLI 怎么调
- [`file-storage.md`](file-storage.md)：游戏脚本的 File API 用法（与程序化脚本的绝对路径写盘对照）
- [`materials.md`](materials.md)：Material 用法（程序化模式下材质能创建、能 `SaveXML`，看不到渲染结果）
