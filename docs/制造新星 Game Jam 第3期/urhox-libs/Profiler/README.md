# urhox-libs/Profiler

通用性能分析器，用于 UrhoX Lua 项目。

## 特性

- 📊 **函数级别追踪** - 精确测量每个函数的执行时间
- 📈 **帧时间统计** - 平均/P50/P95/P99/最大帧时间
- 💾 **内存监控** - 当前/峰值/趋势
- 🗑️ **GC 分配追踪** - 找出内存分配热点
- 🔥 **热点排序** - 按总耗时自动排序
- 📋 **完整报告** - 可视化面板 + 文本报告

## 快速开始

### 1. 导入

```lua
-- 方式 1: 导入完整模块
local Profiler = require("urhox-libs/Profiler/init")

-- 方式 2: 只导入核心（无 UI 依赖）
local ProfilerCore = require("urhox-libs/Profiler/Profiler")
```

### 2. 初始化 UI

```lua
local Profiler = require("urhox-libs/Profiler/init")

-- 创建 UI 实例
local profilerUI = Profiler.UI:new()

-- 添加到 UI 管理器
uiManager:addWidget(profilerUI:build())
```

### 3. 添加追踪

```lua
-- 方式 1: begin/end
Profiler.Core:beginScope("MyFunction")
-- ... 你的代码 ...
Profiler.Core:endScope("MyFunction")

-- 方式 2: measure 闭包
local result = Profiler.Core:measure("Calculate", function()
    return heavyCalculation()
end)

-- 方式 3: 函数包装
local wrappedFunc = Profiler.Core:wrap("ProcessData", originalFunc)
```

### 4. 在 Update 中调用

```lua
function HandleUpdate(timeStep)
    -- 记录帧时间
    Profiler.Core:recordFrame(timeStep)
    
    -- 更新 UI
    profilerUI:update()
end
```

### 5. 绑定快捷键

```lua
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    if key == KEY_BACKQUOTE then
        local ctrlDown = input:GetQualifierDown(QUAL_CTRL)
        local altDown = input:GetQualifierDown(QUAL_ALT)
        
        if altDown then
            -- Alt + ` : 重置数据
            Profiler.Core:reset()
        elseif ctrlDown then
            -- Ctrl + ` : 展开/收起报告
            profilerUI:toggleReport()
        else
            -- ` : 打开/关闭面板
            profilerUI:toggle()
        end
        return
    end
end
```

### 快捷键说明

| 快捷键 | 功能 |
|--------|------|
| **`** | 打开/关闭面板 |
| **Ctrl + `** | 展开/收起报告 |
| **Alt + `** | 重置数据 |

## UI 面板功能

### 实时显示

- **Frame Time** - 帧时间统计 (Avg/P95/P99/Max)
- **Memory** - 内存使用 (Current/Peak/Trend)
- **Frame Distribution** - 帧时间直方图
- **Hotspots** - 热点函数列表

### 按钮

| 按钮 | 功能 |
|------|------|
| 🔄 Reset | 重置所有性能数据 |
| 📋 Report | 展开/收起完整报告 |
| 🖨️ Print | 打印报告到控制台 |
| × | 关闭面板 |

### 热点指示器

| 符号 | 含义 |
|------|------|
| `!!` (红) | 占比 >10%，严重热点 |
| `!` (橙) | 占比 >5%，需要关注 |
| `*` (黄) | 占比 >1%，轻微热点 |
| `-` (绿) | 占比 <1%，正常 |

## API 参考

### Profiler.Core

```lua
-- 初始化/重置
Profiler.Core:init()
Profiler.Core:reset()
Profiler.Core:setEnabled(enabled)

-- 作用域追踪
Profiler.Core:beginScope(name)
Profiler.Core:endScope(name) -> elapsed_ms
Profiler.Core:measure(name, fn) -> result
Profiler.Core:wrap(name, fn) -> wrapped_fn

-- 帧记录
Profiler.Core:recordFrame(deltaTime)

-- 数据获取
Profiler.Core:getFrameStats() -> { avg, min, max, p50, p95, p99, fps, count }
Profiler.Core:getMemoryStats() -> { current, peak, trend, samples }
Profiler.Core:getHotspots(limit) -> [{ name, totalTime, callCount, avgTime, percentOfSession }]
Profiler.Core:getGCHotspots(limit) -> [{ name, totalAlloc, samples, avgAlloc }]
Profiler.Core:getFrameHistogram() -> { bins, maxCount, distribution, totalFrames }

-- 报告
Profiler.Core:generateReport() -> string
Profiler.Core:printReport()
Profiler.Core:getSummary() -> string
Profiler.Core:getSessionTime() -> seconds
```

### Profiler.UI

```lua
-- 创建
local ui = Profiler.UI:new()
local widget = ui:build()

-- 控制
ui:toggle()
ui:setVisible(visible)
ui:isVisible() -> boolean

-- 更新 (每帧调用)
ui:update()

-- 报告
ui:toggleReport()

-- 自定义
ui:setHotkeyHint(keyName)
```

## 最佳实践

### 1. 追踪粒度

```lua
-- 好：追踪主要模块
Profiler.Core:beginScope("Physics.Update")
Profiler.Core:beginScope("Render.Draw")

-- 避免：追踪过于细粒度的函数
-- Profiler.Core:beginScope("Vector3.Add")  -- 开销可能大于追踪价值
```

### 2. 嵌套追踪

```lua
function ChunkBuilder:build()
    Profiler.Core:beginScope("Chunk.Build")
    
    Profiler.Core:beginScope("Chunk.GenTerrain")
    self:generateTerrain()
    Profiler.Core:endScope("Chunk.GenTerrain")
    
    Profiler.Core:beginScope("Chunk.GenMesh")
    self:generateMesh()
    Profiler.Core:endScope("Chunk.GenMesh")
    
    Profiler.Core:endScope("Chunk.Build")
end
```

### 3. 条件追踪

```lua
-- 只在开发模式下追踪
if DEBUG_MODE then
    Profiler.Core:beginScope("ExpensiveDebugCheck")
    self:validateState()
    Profiler.Core:endScope("ExpensiveDebugCheck")
end
```

## 文件结构

```
urhox-libs/Profiler/
├── init.lua          # 入口文件
├── Profiler.lua      # 核心分析器 (无外部依赖)
├── ProfilerUI.lua    # UI 面板 (依赖 urhox-libs/UI)
└── README.md         # 本文档
```

## 依赖

- **Profiler.lua** - 无外部依赖，纯 Lua
- **ProfilerUI.lua** - 依赖 `urhox-libs/UI`

## 版本

- v1.0.0 - 初始版本

## License

MIT

