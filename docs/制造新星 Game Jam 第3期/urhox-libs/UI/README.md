# UrhoX UI Widget Library

基于 **Yoga Flexbox + NanoVG** 的游戏 UI 控件库。

---

## 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│                       Widget Tree                           │
│   ┌────────┐      ┌────────┐      ┌────────┐               │
│   │ Panel  │─────▶│ Button │─────▶│ Label  │               │
│   └───┬────┘      └───┬────┘      └───┬────┘               │
│       │               │               │                     │
│       ▼               ▼               ▼                     │
│   ┌────────┐      ┌────────┐      ┌────────┐               │
│   │YGNode  │─────▶│YGNode  │─────▶│YGNode  │   Yoga 布局树  │
│   └────────┘      └────────┘      └────────┘               │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ YGNodeCalculateLayout()
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               Layout Results (x, y, width, height)          │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 遍历 Widget 树渲染
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                         NanoVG                              │
│   nvgBeginFrame()                                           │
│   nvgRoundedRect(), nvgText(), nvgFill(), nvgStroke()...    │
│   nvgEndFrame()                                             │
└─────────────────────────────────────────────────────────────┘
```

### 三层职责

| 层 | 职责 | 技术 |
|----|------|------|
| **Widget** | 控件逻辑、子节点管理、事件处理、状态管理 | Lua |
| **Layout** | Flexbox 布局计算 | Yoga |
| **Render** | 矢量图形绘制 | NanoVG |

### 核心流程

```lua
-- 1. 创建 Widget 树（同时创建 Yoga 节点树）
local root = Panel { ... children ... }

-- 2. 计算布局（基础像素）
YGNodeCalculateLayout(root.node, baseWidth, baseHeight, YGDirectionLTR)

-- 3. 每帧渲染（由 UI.Render() 自动处理）
UI.Render()  -- 框架自动遍历 Widget 树，递归调用 Render(nvg)
```

---

## 设计原则

### 1. Widget = Yoga 节点封装 + NanoVG 渲染

每个 Widget 持有一个 `YGNodeRef`，样式直接映射到 Yoga API：

```lua
-- Widget 内部
self.node = YGNodeNew()
YGNodeStyleSetWidth(self.node, props.width)
YGNodeStyleSetHeight(self.node, props.height)
YGNodeStyleSetPadding(self.node, YGEdgeAll, props.padding)
```

### 2. 声明式创建

使用 Lua table 描述 UI 结构，简洁易读：

```lua
local ui = Panel {
    width = 400, padding = 16,
    flexDirection = "column", gap = 12,

    Label { text = "Game Menu", fontSize = 24 },
    Button { text = "Start", onClick = onStart },
    Button { text = "Settings", onClick = onSettings },
}
```

### 3. 组合优于继承

**来源**: [React - Composition vs Inheritance](https://legacy.reactjs.org/docs/composition-vs-inheritance.html)

```lua
-- ✅ 组合方式
local PrimaryButton = function(props)
    return Button(merge(props, { variant = "primary" }))
end

-- ✅ 容器组合
local Card = Panel {
    children = { header, content, footer }
}
```

### 4. Stateless vs Stateful

| 类型 | 特点 | 示例 |
|------|------|------|
| **Stateless** | 无内部状态，props 决定一切 | Label, Image, Icon, Panel |
| **Stateful** | 有内部状态 (hover/pressed/focused) | Button, Slider, TextField, Checkbox |

### 5. 受控/非受控模式

**来源**: [Ant Design](https://ant.design/docs/react/faq/)

```lua
-- 受控：外部控制值
Slider { value = state.volume, onChange = function(v) state.volume = v end }

-- 非受控：内部管理值
Slider { defaultValue = 50, onChange = function(v) print(v) end }
```

---

## UI Scale 机制

### 设计目标

简化组件代码，让组件开发者（包括第三方/AI）无需关心 scale 转换。

**核心原则**：组件只使用基础像素，所有 scale 转换由 UI 框架统一处理。

### 坐标系统

| 坐标系 | 说明 | 使用位置 |
|--------|------|----------|
| **基础像素** | 设计尺寸，与 scale 无关 | 组件代码、Yoga 布局、NanoVG 渲染 |
| **屏幕像素** | 实际显示尺寸 = 基础像素 × scale | 系统事件输入 |

### Yoga 基础像素布局 + 像素对齐

**Yoga 在基础像素空间布局**，通过 `YGConfigSetPointScaleFactor` 确保像素对齐，避免黑边：

```
屏幕 1920px，scale = 2，7 个 flex:1 子元素
Yoga 在基础像素空间（960px），PointScaleFactor = 2

布局计算：960 / 7 = 137.14...
像素对齐：Yoga 内部 × 2 舍入后 / 2，确保结果 × scale 是整数像素
结果：137, 137, 137, 137, 137.5, 137.5, 137 = 960（基础像素）
渲染：× scale 后精确对齐屏幕像素，无黑边
```

### 核心流程

```
┌─────────────────────────────────────────────────────────┐
│  UI 框架层 - 2 个转换点                                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. 事件分发（入口）:                                   │
│     鼠标 screenX=200（屏幕像素）                         │
│         ↓                                               │
│     200 / scale = 100 → 传给组件（基础像素）            │
│                                                         │
│  2. 渲染（出口）:                                       │
│     nvgScale(scale) 全局设置                             │
│     组件用 137.5 渲染 → NanoVG 内部 × scale = 275       │
│                                                         │
│  Yoga 布局：                                            │
│     YGConfigSetPointScaleFactor(config, scale)          │
│     组件传入基础像素 → Yoga 返回基础像素（已像素对齐）  │
│                                                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  组件层 - 只使用基础像素，无需任何 scale 计算           │
├─────────────────────────────────────────────────────────┤
│  Yoga API:                                              │
│     YGNodeStyleSetWidth(node, 100)  -- 直接用基础像素   │
│     YGNodeCalculateLayout(node, w, h)  -- 基础像素      │
│                                                         │
│  Render:                                                │
│     local l = self:GetAbsoluteLayout()  -- 137.5 浮点   │
│     nvgRect(nvg, l.x, l.y, l.w, l.h)    -- NanoVG 支持  │
│                                                         │
│  HitTest:                                               │
│     local l = self:GetAbsoluteLayout()  -- 基础像素     │
│     return x >= l.x and x <= l.x + l.w ...              │
└─────────────────────────────────────────────────────────┘
```

### 精度保证：浮点数全程传递

**关键**：`GetLayout()` 返回浮点数，不能取整！

```lua
function Widget:GetLayout()
    -- Yoga 在基础像素空间布局，直接返回结果
    return {
        x = YGNodeLayoutGetLeft(self.node),
        y = YGNodeLayoutGetTop(self.node),
        w = YGNodeLayoutGetWidth(self.node),
        h = YGNodeLayoutGetHeight(self.node)
    }
    -- ❌ 不要 math.floor()！浮点数确保像素对齐
end
```

**精度链条**：
```
Yoga 返回 137.5（基础像素，已像素对齐）
    ↓
GetLayout 直接返回 137.5（浮点数）
    ↓
nvgRect(nvg, 137.5, ...)         ← NanoVG 原生支持浮点
    ↓
nvgScale(2) 内部：137.5 × 2 = 275（精确屏幕像素）✓
```

### 函数职责

| 函数 | 返回值 | 用途 |
|------|--------|------|
| `GetLayout()` | 基础像素（浮点数） | 渲染、HitTest |
| `GetAbsoluteLayout()` | 基础像素（浮点数） | 渲染、HitTest（绝对坐标） |

### 框架层转换点汇总

| 位置 | 转换 | 说明 |
|------|------|------|
| `UI.Init()` | YGConfigSetPointScaleFactor | 设置 Yoga 像素对齐因子 |
| `UI.HandleMouseMove/Down/Up()` | / scale | 屏幕像素 → 基础像素 |
| `UI.Render()` | nvgScale(scale) | 基础像素 → 屏幕像素 |

### 渲染流程

```lua
function UI.Render()
    nvgBeginFrame(nvg, screenWidth, screenHeight, 1.0)

    -- UI 框架设置全局缩放（唯一的渲染转换点）
    nvgScale(nvg, scale, scale)

    -- 组件使用基础像素（浮点数）渲染
    root:Render(nvg)

    nvgEndFrame(nvg)
end
```

### 事件分发流程

```lua
-- UI 框架层：将屏幕像素转换为基础像素
function UI.HandlePointerMove(event)
    local scale = Theme.GetScale()
    event.x = event.x / scale  -- 转换为基础像素
    event.y = event.y / scale

    local widget = findWidgetAt(event.x, event.y)
    widget:OnPointerMove(event)  -- 组件收到的坐标已是基础像素
end

-- 组件层：只使用基础像素，重写 OnPointer* 方法
function Widget:HitTest(x, y)  -- x, y 已经是基础像素
    local l = self:GetAbsoluteLayout()  -- 基础像素
    return x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h
end
```

### 组件代码示例

组件代码非常简单，无需任何 scale 处理：

```lua
function Button:Render(nvg)
    local l = self:GetAbsoluteLayout()        -- 基础像素（浮点数）
    local radius = self.props.borderRadius    -- 基础像素
    local fontSize = self.props.fontSize      -- 基础像素

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, radius)  -- NanoVG 支持浮点
    -- ... nvgScale 自动处理缩放
end

function Button:HitTest(x, y)  -- x, y 已转换为基础像素
    local l = self:GetAbsoluteLayout()
    return x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h
end

function Button:OnClick(event)
    -- event.x, event.y 已转换为基础像素
    print("Clicked at: " .. event.x .. ", " .. event.y)
end
```

### 坐标系总结

| 数据 | 坐标系 | 说明 |
|------|--------|------|
| Yoga 输入/输出 | 基础像素 | YGConfigSetPointScaleFactor 确保像素对齐 |
| `GetLayout()` | 基础像素（浮点） | Yoga 直接返回 |
| `GetAbsoluteLayout()` | 基础像素（浮点） | 用于渲染和 HitTest |
| `renderOffsetX_` | 基础像素 | 手动定位 |
| `absoluteLayout` | 基础像素 | 手动定位 |
| 系统鼠标坐标（原始） | 屏幕像素 | UI 框架层转换 |
| `event.x`, `event.y` | 基础像素 | 已由 UI 框架转换 |
| `Theme.FontSize()` | 基础像素 | 用于 nvgFontSize（nvgScale 会自动缩放） |

### 第三方组件开发指南

对于第三方/AI 开发者，只需记住一条规则：

> **所有坐标都是基础像素，无需任何 scale 计算。**

```lua
-- ✅ 正确：直接使用基础像素
function MyWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    nvgRect(nvg, l.x, l.y, l.w, l.h)  -- 浮点数 OK
end

function MyWidget:HitTest(x, y)
    local l = self:GetAbsoluteLayout()
    return x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h
end

-- ❌ 错误：不要手动乘/除 scale
function MyWidget:Render(nvg)
    local scale = Theme.GetScale()
    local l = self:GetAbsoluteLayout()
    nvgRect(nvg, l.x * scale, l.y * scale, l.w * scale, l.h * scale)  -- 错！
end
```

### NanoVG 浮点数支持

NanoVG 所有坐标参数都是 `float`，完美支持浮点数：

```c
// NanoVG API - 所有参数都是 float
void nvgRect(NVGcontext* ctx, float x, float y, float w, float h);
void nvgRoundedRect(NVGcontext* ctx, float x, float y, float w, float h, float r);
void nvgText(NVGcontext* ctx, float x, float y, const char* string);
```

**字体缩放原理**：

```cpp
// nanovg.cpp
float nvgText(...) {
    float scale = nvg__getFontScale(state);  // 从 transform 提取缩放
    fonsSetSize(ctx->fs, state->fontSize * scale);  // 实际渲染尺寸
    // ...
}
```

- `nvgFontSize(14)` + `nvgScale(2)` → 实际渲染 28px 字体（不是 14px 放大）
- `nvgTextBounds` 返回值自动转换为 local coordinate space（基础像素）

---

## 目录结构

```
urhox-libs/UI/
├── README.md              # 本文档
├── init.lua               # 入口，导出所有控件
│
├── core/                  # 核心模块
│   ├── Widget.lua         # Widget 基类
│   ├── UI.lua             # UI 管理器（根节点、事件分发）
│   ├── Theme.lua          # 主题系统
│   └── Style.lua          # 样式工具函数
│
├── widgets/               # 控件实现
│   ├── Panel.lua          # 容器面板
│   ├── Label.lua          # 文本
│   ├── Image.lua          # 图片
│   ├── Button.lua         # 按钮
│   ├── Slider.lua         # 滑动条
│   ├── ProgressBar.lua    # 进度条
│   ├── Toggle.lua         # 开关
│   ├── Checkbox.lua       # 复选框
│   ├── TextField.lua      # 输入框
│   ├── ScrollView.lua     # 滚动视图
│   ├── ListView.lua       # 列表
│   └── ...
│
└── themes/                # 预设主题
    ├── default.lua
    └── dark.lua
```

---

## 核心 API

### Widget 基类

```lua
---@class Widget
---@field node YGNodeRef      -- Yoga 布局节点
---@field parent Widget|nil   -- 父控件
---@field children Widget[]   -- 子控件列表
---@field props table         -- 外部传入的属性
---@field state table         -- 内部状态 (Stateful 控件)

local Widget = {}

-------------------------------------------------
-- 生命周期
-------------------------------------------------
function Widget:new(props)           -- 创建，同时创建 YGNode
function Widget:Destroy()            -- 销毁，递归释放 YGNode

-------------------------------------------------
-- 子节点管理
-------------------------------------------------
function Widget:AddChild(child)      -- 添加子节点，调用 YGNodeInsertChild
function Widget:RemoveChild(child)   -- 移除子节点，调用 YGNodeRemoveChild
function Widget:ClearChildren()      -- 清空子节点

-------------------------------------------------
-- 样式 & 布局
-------------------------------------------------
function Widget:SetStyle(style)      -- 设置样式，映射到 YGNodeStyleSetXxx
function Widget:GetLayout()          -- 获取布局结果 { x, y, w, h }

-------------------------------------------------
-- 渲染
-------------------------------------------------
function Widget:Render(nvg)          -- NanoVG 渲染（子类重写）
-- 子节点由框架自动递归渲染，无需手动调用

-------------------------------------------------
-- 声明式构建（可选）
-------------------------------------------------
function Widget:Build()              -- 返回子节点数组，框架自动添加

-------------------------------------------------
-- 事件
-------------------------------------------------
function Widget:HitTest(x, y)        -- 碰撞检测
function Widget:OnPointerEnter()     -- 指针进入（推荐）
function Widget:OnPointerLeave()     -- 指针离开（推荐）
function Widget:OnPointerDown()      -- 指针按下（推荐）
function Widget:OnPointerUp()        -- 指针释放（推荐）
function Widget:OnClick()            -- 点击

-------------------------------------------------
-- 状态 (Stateful 控件)
-------------------------------------------------
function Widget:SetState(newState)   -- 更新状态，触发重绘
```

### 样式属性

样式属性直接映射到 Yoga API：

```lua
local style = {
    -------------------------------------------------
    -- 尺寸
    -------------------------------------------------
    width = 100,                -- YGNodeStyleSetWidth
    height = 50,                -- YGNodeStyleSetHeight
    minWidth = 50,              -- YGNodeStyleSetMinWidth
    maxWidth = 200,             -- YGNodeStyleSetMaxWidth
    minHeight = 30,             -- YGNodeStyleSetMinHeight
    maxHeight = 100,            -- YGNodeStyleSetMaxHeight

    -------------------------------------------------
    -- Flex 布局
    -------------------------------------------------
    flexDirection = "column",   -- "row" | "column" | "row-reverse" | "column-reverse"
    justifyContent = "center",  -- "flex-start" | "center" | "flex-end" | "space-between" | "space-around" | "space-evenly"
    alignItems = "center",      -- "flex-start" | "center" | "flex-end" | "stretch"
    alignSelf = "auto",         -- "auto" | "flex-start" | "center" | "flex-end" | "stretch"
    flexGrow = 1,               -- 放大比例
    flexShrink = 0,             -- 缩小比例
    flexBasis = "auto",         -- 基准尺寸
    gap = 8,                    -- 子元素间距

    -------------------------------------------------
    -- 边距
    -------------------------------------------------
    margin = 10,                -- 四边 or { top, right, bottom, left }
    marginTop = 10,
    marginRight = 10,
    marginBottom = 10,
    marginLeft = 10,

    padding = 16,               -- 四边 or { top, right, bottom, left }
    paddingTop = 16,
    paddingRight = 16,
    paddingBottom = 16,
    paddingLeft = 16,

    -------------------------------------------------
    -- 定位
    -------------------------------------------------
    position = "relative",      -- "relative" | "absolute"
    top = 0,
    right = 0,
    bottom = 0,
    left = 0,

    -------------------------------------------------
    -- 外观 (NanoVG 渲染用)
    -------------------------------------------------
    backgroundColor = { 50, 55, 70, 230 },   -- RGBA
    borderColor = { 100, 100, 120, 255 },
    borderWidth = 1,
    borderRadius = 8,

    -------------------------------------------------
    -- 文字 (Label/Button 等)
    -------------------------------------------------
    fontSize = 16,
    fontColor = { 255, 255, 255, 255 },
    fontFamily = "sans",
    textAlign = "center",       -- "left" | "center" | "right"
}
```

### UI 管理器

```lua
local UI = {}

-------------------------------------------------
-- 初始化 & 销毁
-------------------------------------------------
function UI.Init(options)            -- 初始化 NanoVG，加载字体
function UI.Shutdown()               -- 销毁资源

-------------------------------------------------
-- 根节点
-------------------------------------------------
function UI.SetRoot(widget)          -- 设置根节点
function UI.GetRoot()                -- 获取根节点
function UI.FindById(id)             -- 从当前根节点递归查找控件（GetRoot():FindById(id) 的兜底简写）

-------------------------------------------------
-- 布局 & 渲染
-------------------------------------------------
function UI.Layout()                 -- 调用 YGNodeCalculateLayout
function UI.Render()                 -- 渲染整棵树（自动递归渲染子节点）

-------------------------------------------------
-- 事件分发
-------------------------------------------------
function UI.HandlePointerMove(event) -- 分发指针移动
function UI.HandlePointerDown(event) -- 分发指针按下
function UI.HandlePointerUp(event)   -- 分发指针释放
function UI.HandleKeyDown(key)       -- 分发键盘按下
function UI.HandleKeyUp(key)         -- 分发键盘释放
function UI.HandleTextInput(text)    -- 分发文本输入

-------------------------------------------------
-- 自动事件订阅 (autoEvents)
-------------------------------------------------
-- 启用/禁用（细粒度控制）
function UI.EnableAutoEventsInput()   -- 启用输入事件（鼠标/触摸/键盘）
function UI.DisableAutoEventsInput()  -- 禁用输入事件
function UI.EnableAutoEventsUpdate()  -- 启用 Update 事件
function UI.DisableAutoEventsUpdate() -- 禁用 Update 事件
function UI.EnableAutoEventsRender()  -- 启用渲染事件
function UI.DisableAutoEventsRender() -- 禁用渲染事件

-- 启用/禁用（全部）
function UI.EnableAutoEvents()        -- 启用所有自动事件
function UI.DisableAutoEvents()       -- 禁用所有自动事件

-- 查询状态
function UI.IsAutoEventsEnabled()        -- 是否有任意自动事件启用
function UI.IsAutoEventsInputEnabled()   -- 是否启用了输入事件
function UI.IsAutoEventsUpdateEnabled()  -- 是否启用了 Update 事件
function UI.IsAutoEventsRenderEnabled()  -- 是否启用了渲染事件

-------------------------------------------------
-- 主题
-------------------------------------------------
function UI.SetTheme(theme)          -- 设置主题
function UI.GetTheme()               -- 获取当前主题
```

---

## 主题系统

### 主题定义

```lua
-- themes/default.lua
return {
    -------------------------------------------------
    -- 颜色
    -------------------------------------------------
    colors = {
        -- 主色
        primary = { 70, 130, 180, 255 },
        primaryHover = { 90, 150, 200, 255 },
        primaryPressed = { 50, 110, 160, 255 },

        -- 背景
        background = { 30, 30, 40, 255 },
        surface = { 50, 55, 70, 230 },
        surfaceHover = { 60, 65, 80, 230 },

        -- 文字
        text = { 255, 255, 255, 255 },
        textSecondary = { 180, 180, 180, 255 },
        textDisabled = { 100, 100, 100, 255 },

        -- 边框
        border = { 100, 100, 120, 255 },

        -- 语义色
        success = { 80, 180, 80, 255 },
        warning = { 220, 180, 50, 255 },
        error = { 220, 80, 80, 255 },
    },

    -------------------------------------------------
    -- 间距 (4px 基准)
    -------------------------------------------------
    spacing = {
        xs = 4,
        sm = 8,
        md = 16,
        lg = 24,
        xl = 32,
    },

    -------------------------------------------------
    -- 圆角
    -------------------------------------------------
    radius = {
        sm = 4,
        md = 8,
        lg = 16,
        full = 9999,
    },

    -------------------------------------------------
    -- 字体
    -------------------------------------------------
    typography = {
        fontFamily = "sans",
        h1 = { fontSize = 32 },
        h2 = { fontSize = 24 },
        h3 = { fontSize = 20 },
        body = { fontSize = 16 },
        caption = { fontSize = 12 },
    },

    -------------------------------------------------
    -- 控件默认样式
    -------------------------------------------------
    components = {
        Button = {
            height = 44,
            paddingHorizontal = 16,
            borderRadius = 8,
        },
        Panel = {
            borderRadius = 8,
        },
        TextField = {
            height = 40,
            paddingHorizontal = 12,
            borderRadius = 4,
        },
    },
}
```

### 主题使用

```lua
-- 设置主题
UI.SetTheme(require("themes/dark"))

-- 控件内部读取主题
function Button:Render(nvg)
    local theme = UI.GetTheme()
    local color = self.state == "pressed" and theme.colors.primaryPressed
               or self.state == "hover" and theme.colors.primaryHover
               or theme.colors.primary
    -- ...
end
```

---

## 控件列表

### 基础控件 (P0)

| 控件 | 类型 | 说明 |
|------|------|------|
| **Panel** | Stateless | 容器，背景色 + 圆角 |
| **Label** | Stateless | 文本显示 |
| **Image** | Stateless | 图片显示 |
| **Button** | Stateful | 按钮，hover/pressed 状态 |
| **Slider** | Stateful | 滑动条 |
| **ProgressBar** | Stateless | 进度条 |
| **Toggle** | Stateful | 开关 |
| **Checkbox** | Stateful | 复选框 |
| **TextField** | Stateful | 文本输入框 |

### 容器控件 (P1)

| 控件 | 说明 |
|------|------|
| **ScrollView** | 滚动视图，裁剪 + 滚动偏移 |
| **ListView** | 列表，虚拟化渲染 |
| **GridView** | 网格，虚拟化渲染 |
| **TabView** | 标签页切换 |
| **Dropdown** | 下拉选择框 |

### 游戏控件 (P2)

| 控件 | 说明 |
|------|------|
| **Dialog** | 对话框/模态窗口 |
| **Toast** | 轻提示通知 |
| **Tooltip** | 悬浮提示 |
| **Joystick** | 虚拟摇杆 |
| **SkillButton** | 技能按钮 (CD 冷却) |
| **ItemSlot** | 物品槽 |
| **HealthBar** | 血条 |

---

## 使用示例

### 基本使用（自动事件模式，推荐）

```lua
local UI = require("urhox-libs/UI")

function Start()
    -- 初始化（autoEvents 默认启用，自动订阅所有事件）
    UI.Init {
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
        autoEvents = true,  -- 默认值，可省略
        designSize = 1080,  -- 设计分辨率基准
    }

    -- 创建 UI
    local root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = UI.theme.colors.background,

        UI.Panel {
            width = 400, padding = 16,
            flexDirection = "column", gap = 12,
            backgroundColor = UI.theme.colors.surface,
            borderRadius = UI.theme.radius.lg,

            UI.Label {
                text = "Welcome to UrhoX",
                fontSize = 24,
                textAlign = "center",
            },

            UI.Button {
                text = "Start Game",
                onClick = function() StartGame() end,
            },
        },
    }

    UI.SetRoot(root)
    -- autoEvents = true 时无需手动订阅事件
end

function Stop()
    UI.Shutdown()
end
```

### autoEvents 细粒度控制

```lua
-- 方式 1: 禁用所有自动事件（完全手动控制）
UI.Init {
    autoEvents = false,
}

-- 方式 2: 细粒度控制各类事件
UI.Init {
    autoEvents = {
        input = true,   -- 鼠标/触摸/键盘事件（自动转发到 UI）
        update = true,  -- Update 事件（调用 UI.Update(dt)）
        render = false, -- 渲染事件（需要自己控制渲染时机）
    },
}

-- 运行时动态切换
UI.DisableAutoEventsRender()  -- 禁用自动渲染
UI.EnableAutoEventsRender()   -- 重新启用自动渲染

-- 查询状态
if UI.IsAutoEventsRenderEnabled() then
    print("自动渲染已启用")
end
```

### autoEvents 各选项说明

| 选项 | 默认 | 说明 |
|------|------|------|
| `input` | true | 订阅 MouseMove/MouseButtonDown/MouseButtonUp/MouseWheel/TouchBegin/TouchMove/TouchEnd/KeyDown/KeyUp/TextInput/InputFocus 事件 |
| `update` | true | 订阅 Update 事件，每帧调用 `UI.Update(dt)` |
| `render` | true | 订阅 NanoVGRender 事件，每帧调用 `UI.Render()` |

### 典型场景

**场景 1: 需要在 UI 渲染前/后绘制其他内容**
```lua
UI.Init {
    autoEvents = { input = true, update = true, render = false },
}

SubscribeToEvent(nvg, "NanoVGRender", function()
    -- 先绘制背景
    DrawBackground()
    -- 渲染 UI
    UI.Render()
    -- 最后绘制 HUD
    DrawHUD()
end)
```

**场景 2: 需要自己控制 Update 时机（如暂停游戏时不更新 UI）**
```lua
UI.Init {
    autoEvents = { input = true, update = false, render = true },
}

function HandleUpdate(eventType, eventData)
    if not gamePaused then
        local dt = eventData["TimeStep"]:GetFloat()
        UI.Update(dt)
    end
end
```

**场景 3: 纯 UI 应用（使用全部默认自动事件）**
```lua
UI.Init {
    autoEvents = true,  -- 或省略，使用默认值
}
-- 无需手动订阅任何事件
```

### 手动事件模式（完全控制）

```lua
local UI = require("urhox-libs/UI")

function Start()
    -- 禁用所有自动事件
    UI.Init {
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
        autoEvents = false,  -- 完全手动控制
    }

    -- 创建 UI...
    UI.SetRoot(root)

    -- 手动订阅事件
    SubscribeToEvent("Update", function(_, e)
        local dt = e["TimeStep"]:GetFloat()
        UI.Update(dt)
    end)

    SubscribeToEvent("PreRenderUI", function()
        UI.Render()
    end)

    SubscribeToEvent("MouseMove", function(_, e)
        UI.HandleMouseMove(e["X"]:GetInt(), e["Y"]:GetInt())
    end)

    SubscribeToEvent("MouseButtonDown", function(_, e)
        UI.HandleMouseDown(e["X"]:GetInt(), e["Y"]:GetInt(), e["Button"]:GetInt())
    end)

    SubscribeToEvent("MouseButtonUp", function(_, e)
        UI.HandleMouseUp(e["X"]:GetInt(), e["Y"]:GetInt(), e["Button"]:GetInt())
    end)
end

function Stop()
    UI.Shutdown()
end
```

### 动态更新

```lua
-- 方式 1: 使用 Setter 方法
scoreLabel:SetText("Score: " .. score)

-- 方式 2: 通过 ID 访问
local scoreLabel = UI.FindById("scoreLabel")
if scoreLabel then
    scoreLabel:SetText("Score: " .. score)
end

-- 方式 3: 数据绑定（可选扩展）
local state = Observable { score = 0 }
UI.Label { text = state:Map(function(s) return "Score: " .. s.score end) }
state.score = 100  -- 自动更新
```

### 自定义控件

使用 `Widget:Extend()` 创建自定义控件：

```lua
-- 带图标的按钮
local IconButton = UI.Button:Extend("IconButton")

function IconButton:Init(props)
    props = props or {}
    -- 调用父类初始化
    UI.Button.Init(self, props)
    -- 自定义属性
    self.icon = props.icon
    self.iconSize = props.iconSize or 24
end

function IconButton:Render(nvg)
    local l = self:GetAbsoluteLayout()

    -- 背景
    self:RenderFullBackground(nvg)

    -- 图标
    if self.icon then
        local img = nvgCreateImage(nvg, self.icon, 0)
        local ix = l.x + 12
        local iy = l.y + (l.h - self.iconSize) / 2
        nvgBeginPath(nvg)
        nvgRect(nvg, ix, iy, self.iconSize, self.iconSize)
        nvgFillPaint(nvg, nvgImagePattern(nvg, ix, iy, self.iconSize, self.iconSize, 0, img, 1))
        nvgFill(nvg)
    end

    -- 文字
    local tx = self.icon and (l.x + 12 + self.iconSize + 8) or (l.x + l.w / 2)
    local align = self.icon and NVG_ALIGN_LEFT or NVG_ALIGN_CENTER
    nvgFontSize(nvg, 16)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(nvg, bit.bor(align, NVG_ALIGN_MIDDLE))
    nvgText(nvg, tx, l.y + l.h / 2, self.props.text or "")
end

-- 使用
IconButton {
    icon = "Textures/Icons/play.png",
    text = "Play",
    onPress = function() StartGame() end,
}
```

---

## 开发大纲

### Phase 1: 核心框架

#### 1.1 Widget 基类 (`core/Widget.lua`)

```
□ 基础结构
  □ 属性定义: node, parent, children, props, state
  □ 元表设置: __call 支持 Widget { props }
  □ 类继承机制: Widget:extend(name)

□ 生命周期
  □ new(props) - 创建实例 + YGNodeNew()
  □ Destroy() - 递归销毁 + YGNodeFreeRecursive()

□ 子节点管理
  □ AddChild(child) - 添加 + YGNodeInsertChild
  □ RemoveChild(child) - 移除 + YGNodeRemoveChild
  □ ClearChildren() - 清空所有子节点
  □ FindById(id) - 递归查找子节点

□ 样式系统
  □ SetStyle(style) - 批量设置样式
  □ ApplyStyleToYoga(style) - 样式映射到 Yoga API
  □ 支持的样式属性:
    □ 尺寸: width, height, minWidth, maxWidth, minHeight, maxHeight
    □ Flex: flexDirection, justifyContent, alignItems, alignSelf
    □ Flex 属性: flexGrow, flexShrink, flexBasis
    □ 间距: gap, margin*, padding*
    □ 定位: position, top, right, bottom, left

□ 布局
  □ GetLayout() - 返回 { x, y, w, h }
  □ GetAbsoluteLayout() - 返回绝对坐标 (累加父节点偏移)

□ 渲染
  □ Render(nvg) - 虚方法，子类重写（只绘制自身，子节点由框架自动渲染）
  □ RenderBackground(nvg) - 绘制背景色 + 圆角
  □ RenderBorder(nvg) - 绘制边框

□ 声明式构建
  □ Build() - 返回子节点数组，框架自动添加到 widget 树

□ 事件
  □ HitTest(x, y) - 点是否在控件内
  □ OnPointerEnter() / OnPointerLeave() - 指针进入/离开
  □ OnPointerDown() / OnPointerUp() - 指针按下/释放
  □ OnClick() - 点击
  □ OnFocus() / OnBlur() - 焦点

□ 状态 (Stateful)
  □ SetState(newState) - 合并状态
  □ GetState() - 获取当前状态
```

#### 1.2 UI 管理器 (`core/UI.lua`)

```
□ 初始化
  □ Init(options) - 创建 NanoVG context，加载字体
    □ options.fonts: [{ name, path }]
    □ options.theme: 初始主题
  □ Shutdown() - 销毁 NanoVG，释放资源

□ 根节点管理
  □ SetRoot(widget) - 设置根节点
  □ GetRoot() - 获取根节点

□ 布局
  □ Layout() - 调用 YGNodeCalculateLayout
  □ MarkLayoutDirty() - 标记需要重新布局

□ 渲染
  □ Render() - 框架自动遍历 Widget 树，递归调用 Render(nvg)
  □ GetNVGContext() - 获取 NanoVG context

□ 事件分发
  □ HandlePointerMove(x, y)
    □ 遍历 Widget 树做 HitTest
    □ 更新 hoveredWidget
    □ 触发 OnPointerEnter/OnPointerLeave
  □ HandlePointerDown(x, y, button)
    □ 更新 pressedWidget
    □ 更新 focusedWidget
    □ 触发 OnPointerDown
  □ HandlePointerUp(x, y, button)
    □ 触发 OnPointerUp
    □ 判断 OnClick (同一控件按下释放)
  □ HandleKeyDown(key) / HandleKeyUp(key)
  □ HandleTextInput(text)
  □ HandleWheel(dx, dy)

□ 焦点管理
  □ SetFocus(widget) - 设置焦点
  □ GetFocus() - 获取当前焦点
  □ ClearFocus() - 清除焦点

□ 内部状态
  □ hoveredWidget - 当前悬停的控件
  □ pressedWidget - 当前按下的控件
  □ focusedWidget - 当前焦点控件
```

#### 1.3 样式工具 (`core/Style.lua`)

```
□ 样式字符串转 Yoga 枚举
  □ flexDirectionToYoga(str) - "column" → YGFlexDirectionColumn
  □ justifyContentToYoga(str) - "center" → YGJustifyCenter
  □ alignItemsToYoga(str) - "center" → YGAlignCenter
  □ positionTypeToYoga(str) - "absolute" → YGPositionTypeAbsolute

□ 样式合并
  □ merge(...styles) - 合并多个样式表
  □ defaults(style, defaultStyle) - 填充默认值

□ 颜色工具
  □ parseColor(color) - 支持多种格式
    □ { r, g, b, a } - RGBA 数组
    □ "#RRGGBB" / "#RRGGBBAA" - 十六进制
    □ "rgb(r,g,b)" / "rgba(r,g,b,a)" - CSS 格式
  □ colorToRGBA(color) - 统一转为 { r, g, b, a }
```

#### 1.4 主题系统 (`core/Theme.lua`)

```
□ 主题管理
  □ SetTheme(theme) - 设置当前主题
  □ GetTheme() - 获取当前主题
  □ ExtendTheme(base, overrides) - 扩展主题

□ 主题访问
  □ theme.colors.primary
  □ theme.spacing.md
  □ theme.radius.lg
  □ theme.typography.body
  □ theme.components.Button
```

#### 1.5 入口文件 (`init.lua`)

```
□ 导出所有模块
  □ UI = require("core/UI")
  □ Widget = require("core/Widget")
  □ Theme = require("core/Theme")
  □ 所有控件...

□ 快捷访问
  □ UI.Panel = Panel
  □ UI.Label = Label
  □ UI.Button = Button
  □ ...
```

#### 1.6 基础控件

**Panel (`widgets/Panel.lua`)**
```
□ 类型: Stateless
□ Props:
  □ backgroundColor: 背景色
  □ borderColor: 边框色
  □ borderWidth: 边框宽度
  □ borderRadius: 圆角
  □ children: 子节点数组
□ 渲染:
  □ RenderBackground() - 圆角矩形
  □ RenderBorder() - 描边
  □ 子节点由框架自动渲染
```

**Label (`widgets/Label.lua`)**
```
□ 类型: Stateless
□ Props:
  □ text: 文本内容
  □ fontSize: 字号
  □ fontColor: 颜色
  □ fontFamily: 字体
  □ textAlign: 对齐方式 (left/center/right)
  □ lineHeight: 行高
  □ maxLines: 最大行数 (截断)
□ 渲染:
  □ nvgFontSize / nvgFontFace
  □ nvgTextAlign
  □ nvgText / nvgTextBox
□ 布局:
  □ 根据文本内容计算自适应尺寸 (可选)
```

**Button (`widgets/Button.lua`)**
```
□ 类型: Stateful
□ Props:
  □ text: 按钮文字
  □ disabled: 是否禁用
  □ variant: 变体 (primary/secondary/danger)
  □ onClick: 点击回调
□ State:
  □ hovered: boolean
  □ pressed: boolean
□ 渲染:
  □ 根据 state 选择颜色 (normal/hover/pressed/disabled)
  □ 背景 + 文字
□ 事件:
  □ OnPointerEnter → SetState({ hovered = true })
  □ OnPointerLeave → SetState({ hovered = false })
  □ OnPointerDown → SetState({ pressed = true })
  □ OnPointerUp → SetState({ pressed = false }), 触发 OnClick
```

---

### Phase 2: 基础控件

**Image (`widgets/Image.lua`)**
```
□ 类型: Stateless
□ Props:
  □ src: 图片路径
  □ fit: 填充模式 (contain/cover/fill/none)
  □ tint: 着色
□ 实现:
  □ nvgCreateImage 加载图片 (缓存)
  □ nvgImagePattern 绘制
  □ 根据 fit 计算绘制区域
```

**Slider (`widgets/Slider.lua`)**
```
□ 类型: Stateful
□ Props:
  □ value / defaultValue: 当前值 (受控/非受控)
  □ min / max: 范围
  □ step: 步长
  □ disabled: 禁用
  □ onChange: 值变化回调
□ State:
  □ dragging: boolean
  □ internalValue: number (非受控模式)
□ 渲染:
  □ 轨道 (track): 背景条
  □ 填充 (fill): 已选部分
  □ 滑块 (thumb): 可拖拽圆点
□ 事件:
  □ OnPointerDown → 开始拖拽
  □ OnPointerMove (全局) → 更新值
  □ OnPointerUp → 结束拖拽
```

**ProgressBar (`widgets/ProgressBar.lua`)**
```
□ 类型: Stateless
□ Props:
  □ value: 当前值 (0-1 或 0-100)
  □ max: 最大值
  □ color: 填充色
  □ backgroundColor: 背景色
  □ showLabel: 是否显示百分比
□ 渲染:
  □ 背景条
  □ 填充条 (宽度 = value/max * 总宽度)
  □ 可选: 百分比文字
```

**Toggle (`widgets/Toggle.lua`)**
```
□ 类型: Stateful
□ Props:
  □ value / defaultValue: boolean
  □ disabled: boolean
  □ onChange: 回调
□ State:
  □ internalValue: boolean (非受控)
□ 渲染:
  □ 背景: 圆角矩形，颜色根据开关状态
  □ 滑块: 圆形，位置根据状态左/右
  □ 可选: 动画过渡
```

**Checkbox (`widgets/Checkbox.lua`)**
```
□ 类型: Stateful
□ Props:
  □ checked / defaultChecked: boolean
  □ label: 文字标签
  □ disabled: boolean
  □ onChange: 回调
□ State:
  □ hovered, pressed
  □ internalChecked (非受控)
□ 渲染:
  □ 方框 + 勾选图标
  □ 可选: 标签文字
```

**TextField (`widgets/TextField.lua`)**
```
□ 类型: Stateful
□ Props:
  □ value / defaultValue: string
  □ placeholder: 占位符
  □ disabled / readonly: boolean
  □ maxLength: 最大长度
  □ onChange: 回调
  □ onSubmit: 回车回调
□ State:
  □ focused: boolean
  □ cursorPosition: number
  □ selectionStart / selectionEnd: number
  □ internalValue: string (非受控)
□ 渲染:
  □ 背景框
  □ 文字 / 占位符
  □ 光标 (闪烁动画)
  □ 选区高亮
□ 事件:
  □ OnFocus / OnBlur
  □ OnTextInput → 插入字符
  □ OnKeyDown → 处理退格、方向键、回车等
```

---

### Phase 3: 容器控件

**ScrollView (`widgets/ScrollView.lua`)**
```
□ 类型: Stateful
□ Props:
  □ horizontal: boolean - 水平滚动
  □ vertical: boolean - 垂直滚动
  □ showScrollbar: boolean
  □ children: 内容
□ State:
  □ scrollX, scrollY: number
  □ contentWidth, contentHeight: number
□ 实现:
  □ 内容区域用独立 YGNode 计算
  □ 渲染时 nvgScissor 裁剪
  □ 渲染时 nvgTranslate 偏移
□ 事件:
  □ onWheel → 更新 scrollX/scrollY
  □ 拖拽滚动条
```

**ListView (`widgets/ListView.lua`)**
```
□ 类型: Stateful
□ Props:
  □ data: array - 数据源
  □ renderItem: function(item, index) → Widget
  □ itemHeight: number - 固定行高 (虚拟化必需)
  □ keyExtractor: function(item, index) → string
□ State:
  □ scrollY: number
  □ visibleRange: { start, end }
□ 实现:
  □ 虚拟化: 只渲染可见区域的 item
  □ 计算可见范围: start = floor(scrollY / itemHeight)
  □ 复用/回收 item Widget
```

**GridView (`widgets/GridView.lua`)**
```
□ 类型: Stateful
□ Props:
  □ data: array
  □ renderItem: function
  □ columns: number - 列数
  □ itemWidth / itemHeight: 单元格尺寸
  □ gap: 间距
□ 实现:
  □ 虚拟化: 只渲染可见行
  □ 计算可见行范围
```

**TabView (`widgets/TabView.lua`)**
```
□ 类型: Stateful
□ Props:
  □ tabs: [{ label, content }]
  □ activeIndex / defaultActiveIndex
  □ onChange: 切换回调
□ State:
  □ internalActiveIndex
□ 渲染:
  □ Tab 栏: 水平排列的 Tab 按钮
  □ 内容区: 当前激活 Tab 的 content
```

**Dropdown (`widgets/Dropdown.lua`)**
```
□ 类型: Stateful
□ Props:
  □ options: [{ label, value }]
  □ value / defaultValue
  □ placeholder
  □ onChange
□ State:
  □ isOpen: boolean
  □ hoveredIndex: number
□ 渲染:
  □ 触发器: 显示当前选中值
  □ 下拉菜单: position=absolute，渲染 options
□ 事件:
  □ 点击触发器 → toggle isOpen
  □ 点击选项 → 选中并关闭
  □ 点击外部 → 关闭
```

---

### Phase 4: 游戏控件

**Dialog (`widgets/Dialog.lua`)**
```
□ 类型: Stateful
□ Props:
  □ visible: boolean
  □ title: string
  □ content: Widget 或 string
  □ buttons: [{ label, onClick, variant }]
  □ onClose: 关闭回调
  □ closeOnOverlay: 点击遮罩关闭
□ 渲染:
  □ 遮罩层 (半透明黑色)
  □ 对话框面板 (居中)
  □ 标题栏 + 关闭按钮
  □ 内容区
  □ 按钮栏
```

**Toast (`widgets/Toast.lua`)**
```
□ 类型: Stateful
□ API:
  □ Toast.show({ message, duration, type })
  □ Toast.success(message)
  □ Toast.error(message)
  □ Toast.warning(message)
□ 实现:
  □ 全局 Toast 容器 (顶部居中或右上角)
  □ 队列管理多个 Toast
  □ 自动消失 (duration)
  □ 进入/退出动画
```

**Tooltip (`widgets/Tooltip.lua`)**
```
□ 类型: Stateful
□ Props:
  □ content: string 或 Widget
  □ placement: top/bottom/left/right
  □ delay: 延迟显示时间
  □ children: 触发元素
□ 实现:
  □ hover 触发元素 → 延迟显示 Tooltip
  □ position=absolute，计算位置避免超出屏幕
  □ 箭头指向触发元素
```

**Joystick (`widgets/Joystick.lua`)**
```
□ 类型: Stateful
□ Props:
  □ size: 摇杆尺寸
  □ deadZone: 死区半径
  □ onChange: function(x, y) - 归一化 -1~1
  □ onStart / onEnd
□ State:
  □ active: boolean
  □ thumbX, thumbY: 滑块位置
□ 渲染:
  □ 底座圆形
  □ 滑块圆形
□ 事件:
  □ touch/mouse 拖拽
  □ 限制滑块在底座范围内
  □ 释放后回弹到中心
```

**SkillButton (`widgets/SkillButton.lua`)**
```
□ 类型: Stateful
□ Props:
  □ icon: 技能图标
  □ cooldown: 冷却时间 (秒)
  □ currentCooldown: 当前剩余冷却
  □ disabled: boolean
  □ onClick
□ State:
  □ hovered, pressed
□ 渲染:
  □ 图标
  □ 冷却遮罩 (扇形或从上到下)
  □ 冷却时间数字
  □ 禁用状态灰色
```

**ItemSlot (`widgets/ItemSlot.lua`)**
```
□ 类型: Stateful
□ Props:
  □ item: { icon, count, rarity, ... } 或 nil
  □ size: 格子尺寸
  □ onClick
  □ onDragStart / onDragEnd / onDrop
□ State:
  □ hovered, pressed
  □ dragging
□ 渲染:
  □ 背景框 (根据 rarity 不同颜色)
  □ 物品图标
  □ 数量角标
  □ 空槽位样式
```

**HealthBar (`widgets/HealthBar.lua`)**
```
□ 类型: Stateless
□ Props:
  □ current: 当前血量
  □ max: 最大血量
  □ showLabel: 显示数值
  □ color: 血条颜色 (或根据百分比渐变)
  □ backgroundColor
  □ height
□ 渲染:
  □ 背景条
  □ 血量条 (宽度 = current/max)
  □ 可选: 数值文字
  □ 可选: 低血量时颜色变化/闪烁
```

---

### Phase 5: 高级功能 (可选)

**动画系统**
```
□ Tween 动画
  □ UI.Animate(widget, { props }, duration, easing)
  □ 支持的 easing: linear, easeIn, easeOut, easeInOut
□ 过渡动画
  □ Widget 显示/隐藏时的淡入淡出
  □ 状态变化时的颜色过渡
```

**数据绑定**
```
□ Observable 状态
  □ local state = Observable { count = 0 }
  □ state:Bind("count") → 返回绑定对象
  □ 修改 state.count 自动触发 UI 更新
□ 计算属性
  □ state:Computed(function(s) return s.a + s.b end)
```

**国际化 (i18n)**
```
□ UI.SetLocale("zh-CN")
□ UI.T("button.confirm") → "确认"
□ Label { text = UI.T("welcome") }
```

**无障碍 (Accessibility)**
```
□ 键盘导航 (Tab 切换焦点)
□ 屏幕阅读器支持 (aria labels)
```

---

## 自定义组件开发指南

本节介绍如何继承 `Widget` 基类创建自定义组件。

### 基本结构

```lua
-- MyWidget.lua
local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")

---@class MyWidget : Widget
local MyWidget = Widget:Extend("MyWidget")

-- 构造函数
function MyWidget:Init(props)
    props = props or {}

    -- 设置默认值
    props.width = props.width or 100
    props.height = props.height or 40

    -- 内部状态
    self.customState_ = 0

    -- 必须调用父类 Init
    Widget.Init(self, props)
end

-- 渲染（必须实现）
function MyWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()

    -- 绘制背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, 4)
    nvgFillColor(nvg, nvgRGBA(50, 50, 60, 255))
    nvgFill(nvg)
    -- 子节点由框架自动渲染
end

return MyWidget
```

### 生命周期方法

| 方法 | 说明 | 是否必须 |
|------|------|----------|
| `Init(props)` | 构造函数，初始化属性和状态 | 是 |
| `Build()` | 声明式构建，返回子节点数组 | 否 |
| `Render(nvg)` | 每帧渲染，绘制组件外观（子节点由框架自动渲染） | 是 |
| `Update(dt)` | 每帧更新，处理动画/计时器 | 否 |
| `Destroy()` | 销毁时清理资源 | 否 |

> **注意**: `Render()` 只需绘制组件自身，子节点由框架自动递归渲染。如需特殊处理（如裁剪、滚动），可实现 `CustomRenderChildren(nvg, renderFn)`。

### Build() 声明式构建

`Build()` 方法允许以声明式方式构建组件树，类似 React 的 `render()` 或 Flutter 的 `build()`。

```lua
local MyComponent = Widget:Extend("MyComponent")

function MyComponent:Init(props)
    Widget.Init(self, props)
end

-- 框架自动调用 Build()，将返回的子节点添加到组件树
function MyComponent:Build()
    return {
        UI.Panel {
            flexDirection = "row",
            gap = 10,
            children = self:CreateItems(),  -- 使用 children 属性传递子节点数组
        }
    }
end

function MyComponent:CreateItems()
    local items = {}
    for i = 1, 5 do
        table.insert(items, UI.Label { text = "Item " .. i })
    end
    return items
end
```

**要点**:
- `Build()` 在 `Init()` 之后自动调用
- 返回子节点数组，框架自动添加到 widget 树
- 使用 `children = array` 传递动态生成的子节点（不要写成 `children` 漏掉 `=`）

### 事件处理（跨平台）

UI 系统使用统一的 `PointerEvent` 处理鼠标、触摸、手写笔输入，实现跨平台兼容。

#### Pointer 事件（推荐）

子类应该重写这些方法实现交互：

| 方法 | 说明 | 返回值 |
|------|------|--------|
| `HitTest(x, y)` | 判断点击是否命中 | `boolean` |
| `OnPointerEnter(event)` | 指针进入区域 | - |
| `OnPointerLeave(event)` | 指针离开区域 | - |
| `OnPointerDown(event)` | 指针按下 | `boolean` (是否消费) |
| `OnPointerUp(event)` | 指针释放 | `boolean` |
| `OnPointerMove(event)` | 指针移动 | - |
| `OnPointerCancel(event)` | 指针取消（如来电中断） | - |

#### PointerEvent 结构

```lua
---@class PointerEvent
event.type        -- "PointerDown" | "PointerUp" | "PointerMove" | "PointerEnter" | "PointerLeave" | "PointerCancel"
event.pointerId   -- 指针 ID（mouse=0, touch=finger id）
event.pointerType -- "mouse" | "touch" | "pen"
event.x           -- X 坐标（基础像素，已转换）
event.y           -- Y 坐标（基础像素，已转换）
event.button      -- 触发事件的按钮（0=左/主要, 1=中, 2=右）
event.buttons     -- 当前按下的按钮位掩码
event.pressure    -- 压力值（0.0-1.0，鼠标按下时为 0.5）
event.isPrimary   -- 是否主指针
event.deltaX      -- X 移动增量（PointerMove 时）
event.deltaY      -- Y 移动增量（PointerMove 时）
event.timestamp   -- 事件时间戳（毫秒）
event.target      -- 目标 Widget
```

#### PointerEvent 便捷方法

```lua
-- 判断方法
event:IsPrimaryAction()  -- 是否主要操作（推荐！触摸总是 true，鼠标只有左键是 true）
event:IsTouch()          -- 是否触摸事件
event:IsMouse()          -- 是否鼠标事件
event:IsPen()            -- 是否手写笔事件
event:IsPrimaryButton()  -- 是否左键/主要按钮
event:IsSecondaryButton()-- 是否右键
event:IsMiddleButton()   -- 是否中键

-- 事件控制
event:StopPropagation()  -- 停止事件冒泡到父节点
event:PreventDefault()   -- 阻止默认行为
```

#### 跨平台示例

```lua
function MyButton:OnPointerDown(event)
    -- 使用 IsPrimaryAction() 实现跨平台
    -- 鼠标：只响应左键
    -- 触摸：响应任意手指（支持多点触控场景）
    if event:IsPrimaryAction() then
        self.state.pressed = true
    end
    return true  -- 消费事件
end

function MyButton:OnPointerUp(event)
    if event:IsPrimaryAction() then
        self.state.pressed = false
    end
    return true
end

function MyButton:OnPointerEnter(event)
    self.state.hovered = true
end

function MyButton:OnPointerLeave(event)
    self.state.hovered = false
    self.state.pressed = false
end
```

#### 手势事件（触摸优化）

针对触摸设备优化的高级手势：

| 方法 | 说明 | 触发条件 |
|------|------|----------|
| `OnClick(event)` | 点击 | 快速按下释放 |
| `OnTap(event)` | 轻触 | 触摸快速点击 |
| `OnDoubleTap(event)` | 双击 | 连续两次快速点击 |
| `OnLongPressStart(event)` | 长按开始 | 按住超过阈值时间 |
| `OnLongPressEnd(event)` | 长按结束 | 长按后释放 |
| `OnSwipe(event)` | 滑动 | 快速滑动手势 |
| `OnPanStart(event)` | 拖动开始 | 按住并移动 |
| `OnPanMove(event)` | 拖动中 | 拖动过程 |
| `OnPanEnd(event)` | 拖动结束 | 释放拖动 |
| `OnPinchStart(event)` | 缩放开始 | 双指捏合 |
| `OnPinchMove(event)` | 缩放中 | 双指移动 |
| `OnPinchEnd(event)` | 缩放结束 | 双指释放 |
| `OnWheel(dx, dy)` | 滚轮 | 鼠标滚轮 |

#### 手势示例

```lua
-- 点击处理（推荐用于按钮）
function MyButton:OnClick(event)
    if self:IsDisabled() then
        return false  -- 不消费，继续传递
    end
    self:DoAction()
    return true  -- 消费事件
end

-- 拖动处理
function MyDraggable:OnPanStart(event)
    self.dragStartX_ = event.x
    self.dragStartY_ = event.y
    return true
end

function MyDraggable:OnPanMove(event)
    local dx = event.x - self.dragStartX_
    local dy = event.y - self.dragStartY_
    self:Move(dx, dy)
    return true
end

-- 长按处理
function MyItem:OnLongPressStart(event)
    self:ShowContextMenu(event.x, event.y)
    return true
end
```

#### 传统 Mouse 事件（已废弃）

以下方法保留用于向后兼容，**新代码请使用 OnPointer* 方法**：

```lua
function Widget:OnMouseEnter()              -- 已废弃，用 OnPointerEnter
function Widget:OnMouseLeave()              -- 已废弃，用 OnPointerLeave
function Widget:OnMouseDown(x, y, button)   -- 已废弃，用 OnPointerDown
function Widget:OnMouseUp(x, y, button)     -- 已废弃，用 OnPointerUp
```

### 坐标系统（重要！）

**框架自动处理 UI Scale，组件代码全程使用基础像素**：

```lua
function MyWidget:Render(nvg)
    -- GetAbsoluteLayout() 返回基础像素
    local l = self:GetAbsoluteLayout()

    -- 直接使用，无需乘/除 scale
    nvgRect(nvg, l.x, l.y, l.w, l.h)

    -- Theme.FontSize() 返回基础像素
    nvgFontSize(nvg, Theme.FontSize(14))

    -- nvgTextBounds() 返回基础像素
    local width = nvgTextBounds(nvg, 0, 0, "Hello")
end

function MyWidget:HitTest(x, y)
    -- x, y 已经是基础像素
    local l = self:GetAbsoluteLayout()
    return x >= l.x and x <= l.x + l.w
       and y >= l.y and y <= l.y + l.h
end
```

**禁止在组件中使用 `Theme.GetScale()`！** 框架层会自动处理：
- `YGConfigSetPointScaleFactor`: Yoga 像素对齐
- `UI.Render()`: `nvgScale(scale)` 统一缩放渲染
- 事件坐标: 屏幕像素 → 基础像素

### 动态尺寸变更

使用 `SetWidth()` / `SetHeight()` 方法，自动通知布局更新：

```lua
function MyWidget:UpdateSize(newWidth, newHeight)
    self:SetWidth(newWidth)   -- 传入基础像素
    self:SetHeight(newHeight) -- 自动通知布局
end

-- ✅ 正确：使用封装方法（推荐）
self:SetWidth(width)

-- ✅ 也正确：直接调用 Yoga API（基础像素）
YGNodeStyleSetWidth(self.node, width)  -- 直接用基础像素，无需 * scale
Widget._notifyLayoutDirty()
```

### 文字测量

使用 `UI.MeasureTextWidth()` 精确测量文字宽度：

```lua
local UI = require("urhox-libs/UI/Core/UI")

function MyWidget:CalculateTextWidth(text)
    local fontSize = Theme.FontSize(self.props.fontSize)
    -- 返回基础像素宽度
    return UI.MeasureTextWidth(text, fontSize, "sans")
end
```

### 完整示例：带倒计时的按钮

```lua
local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class CountdownButton : Widget
local CountdownButton = Widget:Extend("CountdownButton")

function CountdownButton:Init(props)
    props = props or {}
    props.width = props.width or 120
    props.height = props.height or 40
    props.text = props.text or "Click"
    props.fontSize = props.fontSize or 14
    props.cooldown = props.cooldown or 3  -- 冷却时间（秒）

    -- 内部状态
    self.state = {
        hovered = false,
        pressed = false,
        cooldownRemaining = 0,
    }

    Widget.Init(self, props)
end

-- 每帧更新冷却计时
function CountdownButton:Update(dt)
    if self.state.cooldownRemaining > 0 then
        self.state.cooldownRemaining = self.state.cooldownRemaining - dt

        -- 更新显示文字宽度
        local text = self:GetDisplayText()
        local fontSize = Theme.FontSize(self.props.fontSize)
        local textWidth = UI.MeasureTextWidth(text, fontSize, "sans")
        local newWidth = math.max(80, textWidth + 32)
        if newWidth ~= self.props.width then
            self:SetWidth(newWidth)
        end
    end
end

function CountdownButton:GetDisplayText()
    if self.state.cooldownRemaining > 0 then
        return string.format("%.1fs", self.state.cooldownRemaining)
    end
    return self.props.text
end

function CountdownButton:IsDisabled()
    return self.state.cooldownRemaining > 0
end

function CountdownButton:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local disabled = self:IsDisabled()

    -- 背景颜色
    local bgColor
    if disabled then
        bgColor = { 60, 60, 70, 255 }
    elseif self.state.pressed then
        bgColor = { 50, 100, 140, 255 }
    elseif self.state.hovered then
        bgColor = { 80, 140, 190, 255 }
    else
        bgColor = { 70, 130, 180, 255 }
    end

    -- 绘制背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, 6)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    nvgFill(nvg)

    -- 绘制文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, Theme.FontSize(self.props.fontSize))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local textColor = disabled and { 120, 120, 130, 255 } or { 255, 255, 255, 255 }
    nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4]))
    nvgText(nvg, l.x + l.w / 2, l.y + l.h / 2, self:GetDisplayText())
    -- 子节点由框架自动渲染
end

function CountdownButton:HitTest(x, y)
    local l = self:GetAbsoluteLayout()
    return x >= l.x and x <= l.x + l.w
       and y >= l.y and y <= l.y + l.h
end

function CountdownButton:OnPointerEnter(event)
    self.state.hovered = true
end

function CountdownButton:OnPointerLeave(event)
    self.state.hovered = false
    self.state.pressed = false
end

function CountdownButton:OnPointerDown(event)
    if not self:IsDisabled() then
        self.state.pressed = true
    end
    return true  -- 消费事件
end

function CountdownButton:OnPointerUp(event)
    self.state.pressed = false
    return true
end

function CountdownButton:OnClick(event)
    if self:IsDisabled() then
        return false
    end

    -- 开始冷却
    self.state.cooldownRemaining = self.props.cooldown

    -- 调用回调
    if self.props.onClick then
        self.props.onClick(self)
    end

    return true
end

return CountdownButton
```

### 最佳实践

**1. 始终调用父类方法**
```lua
function MyWidget:Init(props)
    -- 设置默认值...
    Widget.Init(self, props)  -- 必须调用
end

function MyWidget:Destroy()
    -- 清理资源...
    Widget.Destroy(self)  -- 必须调用
end
```

**2. 使用内部状态命名约定**
```lua
-- 私有成员使用下划线后缀
self.internalValue_ = 0
self.cachedLayout_ = nil

-- 状态表用于交互状态
self.state = {
    hovered = false,
    pressed = false,
}
```

**3. 避免在 Render 中修改状态**
```lua
-- ❌ 错误
function MyWidget:Render(nvg)
    self.frameCount = self.frameCount + 1  -- 不要在 Render 中修改状态
end

-- ✅ 正确
function MyWidget:Update(dt)
    self.frameCount = self.frameCount + 1  -- 在 Update 中修改状态
end
```

**4. HitTest 返回值**
```lua
-- 返回 false: 点击穿透到下层
function Overlay:HitTest(x, y)
    return false  -- 总是穿透
end

-- 返回 true: 捕获点击
function Button:HitTest(x, y)
    local l = self:GetAbsoluteLayout()
    return x >= l.x and x <= l.x + l.w
       and y >= l.y and y <= l.y + l.h
end
```

**5. 事件消费**
```lua
function MyWidget:OnClick(event)
    if self:HandleClick() then
        return true   -- 消费事件，不再传递
    end
    return false      -- 不消费，继续传递给父节点
end
```

**6. 使用辅助渲染方法**
```lua
function MyWidget:Render(nvg)
    -- Widget 基类提供的辅助方法
    self:RenderBackground(nvg, color, radius)
    self:RenderBorder(nvg, color, width, radius)
    self:RenderShadow(nvg, layout)
    -- 子节点由框架自动渲染，无需手动调用
end
```

---

## 参考资料

- [Yoga Layout](https://yogalayout.com/) - Flexbox 布局引擎
- [NanoVG](https://github.com/memononen/nanovg) - 矢量图形渲染
- [React - Composition vs Inheritance](https://legacy.reactjs.org/docs/composition-vs-inheritance.html)
- [Flutter - StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [Ant Design](https://ant.design/) - 受控/非受控模式
- [Unity UI Toolkit](https://docs.unity3d.com/Manual/UIToolkits.html) - Yoga 布局参考
