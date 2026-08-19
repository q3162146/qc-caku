# NanoVG Bloom/Glow 模拟指南

本文档指导如何在 NanoVG 中模拟 HDR Bloom/Glow 效果。

## 支持的形状

| 形状 | 使用函数 |
|------|----------|
| 圆形 | `nvgRadialGradient` |
| 圆角矩形 | `nvgBoxGradient` |
| 任意形状 | 不支持，需要引擎级 Blur Shader |

## 推荐参数

经过测试，以下参数组合效果较好：

```lua
-- Bloom 参数 (全局常量，与示例 59_NanoVG_Bloom.lua 一致)
local BLOOM_INNER_ALPHA = 0.45   -- 中心亮度
local BLOOM_MID_ALPHA = 0.6      -- 实心核心大小 (渐变起点)
local BLOOM_OUTER_ALPHA = 0.1    -- bloom 范围倍数
local BLOOM_SIZE = 2.0           -- 基础大小倍数
```

### 参数说明

| 参数 | 范围 | 作用 |
|------|------|------|
| `BLOOM_INNER_ALPHA` | 0-1 | 控制中心亮度，值越大中心越亮 |
| `BLOOM_MID_ALPHA` | 0-1 | 控制渐变起点位置，0=从圆心开始渐变，1=有较大实心核心 |
| `BLOOM_OUTER_ALPHA` | 0-1 | 控制 bloom 范围，值越大范围越广 |
| `BLOOM_SIZE` | 0.5-5 | 基础半径倍数 |

### ⚠️ 重要：HDR 颜色在外部计算

```lua
-- ✅ 正确：在调用 DrawBloom 前计算 HDR 颜色
local hdrR, hdrG, hdrB = r * brightness, g * brightness, b * brightness
DrawCircleBloom(ctx, x, y, radius, hdrR, hdrG, hdrB)

-- ❌ 错误：不要在 DrawBloom 函数内部再乘 intensity/brightness
function DrawBloom(x, y, radius, r, g, b, intensity)
    local hdrR = r * intensity  -- 这会导致双重放大！
end
```

### ⚠️ 重要：只在 brightness > 1.0 时绘制 bloom

```lua
-- 只有超过阈值才需要 bloom，否则就是普通圆
if brightness > 1.0 then
    DrawCircleBloom(ctx, x, y, radius, hdrR, hdrG, hdrB)
end
```

## 实现代码

### 基础 Bloom 绘制函数

```lua
--- 绘制圆形 bloom 效果 (与示例 59_NanoVG_Bloom.lua 一致)
-- @param ctx NVGContextWrapper NanoVG 上下文
-- @param x number 圆心 X
-- @param y number 圆心 Y
-- @param radius number 核心圆半径
-- @param r number HDR 红色分量 (已经是 HDR 值，可 > 1.0)
-- @param g number HDR 绿色分量 (已经是 HDR 值，可 > 1.0)
-- @param b number HDR 蓝色分量 (已经是 HDR 值，可 > 1.0)
-- 注意：r, g, b 应该在调用前已计算好 (如 r * brightness)，函数内部不再乘任何系数
function DrawCircleBloom(ctx, x, y, radius, r, g, b)
    -- 计算 bloom 范围
    local maxRadius = radius * BLOOM_SIZE * (1.0 + BLOOM_OUTER_ALPHA * 3.0)

    -- 计算渐变起点 (实心核心大小)
    local innerR = radius * BLOOM_MID_ALPHA * 0.5

    -- 中心 alpha (直接使用常量)
    local alpha = BLOOM_INNER_ALPHA

    -- 绘制 bloom 渐变 (直接使用传入的颜色，不再乘任何系数)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, maxRadius)
    local grad = nvgRadialGradient(ctx, x, y, innerR, maxRadius,
        nvgRGBAf(r, g, b, alpha),
        nvgRGBAf(r, g, b, 0))
    nvgFillPaint(ctx, grad)
    nvgFill(ctx)
end
```

### 带 HDR 阈值的发光圆形

```lua
--- 绘制带 bloom 的发光圆形 (与示例一致)
-- @param ctx NVGContextWrapper
-- @param x number 圆心 X
-- @param y number 圆心 Y
-- @param radius number 圆半径
-- @param r number 基础红色 (0-1)
-- @param g number 基础绿色 (0-1)
-- @param b number 基础蓝色 (0-1)
-- @param brightness number 亮度倍数 (>1 触发 bloom，推荐 1.0~2.0)
function DrawGlowingCircle(ctx, x, y, radius, r, g, b, brightness)
    -- 在此处计算 HDR 颜色 (brightness 乘到颜色上)
    local hdrR = r * brightness
    local hdrG = g * brightness
    local hdrB = b * brightness

    -- ⚠️ 关键：只在 brightness > 1.0 时绘制 bloom
    -- brightness <= 1.0 时就是普通圆，不需要 bloom
    if brightness > 1.0 then
        DrawCircleBloom(ctx, x, y, radius, hdrR, hdrG, hdrB)
    end

    -- 绘制核心圆 (应用 tonemapping，防止过曝)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius)
    nvgFillColor(ctx, nvgRGBAf(math.min(1, hdrR), math.min(1, hdrG), math.min(1, hdrB), 1.0))
    nvgFill(ctx)
end
```

### 推荐 brightness 值

| 场景 | brightness | 说明 |
|------|-----------|------|
| 普通元素 | 1.0 | 无 bloom，正常渲染 |
| 轻微发光 | 1.1~1.2 | 微弱 bloom |
| 标准发光 | 1.3~1.5 | 适中 bloom (推荐) |
| 强烈发光 | 1.5~2.0 | 明显 bloom |
| 动态脉动 | `1.5 + sin(t) * 0.5` | 1.0~2.0 范围变化 |

### ACES Tonemapping (可选)

对于 HDR 颜色，可以使用 ACES tonemapping 来保留高光细节：

```lua
--- ACES Tonemapping
-- @param x number HDR 颜色分量 (可 > 1.0)
-- @return number LDR 颜色分量 (0-1)
function ACESTonemap(x)
    local a = 2.51
    local b = 0.03
    local c = 2.43
    local d = 0.59
    local e = 0.14
    return math.max(0, math.min(1, (x * (a * x + b)) / (x * (c * x + d) + e)))
end

-- 使用示例
local ldrR = ACESTonemap(hdrR)
local ldrG = ACESTonemap(hdrG)
local ldrB = ACESTonemap(hdrB)
```

## 矩形 Bloom (BoxGradient)

对于圆角矩形，使用 `nvgBoxGradient`：

```lua
--- 绘制矩形 bloom 效果 (与示例一致)
-- @param ctx NVGContextWrapper
-- @param x number 左上角 X
-- @param y number 左上角 Y
-- @param w number 宽度
-- @param h number 高度
-- @param cornerRadius number 圆角半径
-- @param feather number 羽化范围 (bloom 扩散距离)
-- @param r, g, b number HDR 颜色 (已计算好，可 > 1.0)
function DrawRectBloom(ctx, x, y, w, h, cornerRadius, feather, r, g, b)
    local alpha = BLOOM_INNER_ALPHA

    nvgBeginPath(ctx)
    nvgRect(ctx, x - feather, y - feather, w + feather * 2, h + feather * 2)
    local grad = nvgBoxGradient(ctx, x, y, w, h, cornerRadius, feather,
        nvgRGBAf(r, g, b, alpha),
        nvgRGBAf(r, g, b, 0))
    nvgFillPaint(ctx, grad)
    nvgFill(ctx)
end

--- 绘制带 bloom 的发光矩形
function DrawGlowingRect(ctx, x, y, w, h, cornerRadius, r, g, b, brightness)
    local hdrR, hdrG, hdrB = r * brightness, g * brightness, b * brightness
    local feather = math.max(w, h) * 0.3 * BLOOM_SIZE

    -- 只在 brightness > 1.0 时绘制 bloom
    if brightness > 1.0 then
        DrawRectBloom(ctx, x, y, w, h, cornerRadius, feather, hdrR, hdrG, hdrB)
    end

    -- 绘制核心矩形
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, cornerRadius)
    nvgFillColor(ctx, nvgRGBAf(math.min(1, hdrR), math.min(1, hdrG), math.min(1, hdrB), 1))
    nvgFill(ctx)
end
```

## 使用场景

### 适合使用 NanoVG Bloom 的场景

- 粒子效果 (圆形)
- UI 按钮高亮
- 能量球/光球
- 简单的发光指示器

### 不适合的场景

- 任意形状的发光 (需要后处理 Shader)
- 文字发光 (效果有限)
- 需要高斯衰减的精确 bloom

## 性能注意事项

1. **单层渐变最高效** - 避免多层叠加，会产生硬边界且增加 draw call
2. **控制 bloom 数量** - 每个 bloom 是一次 draw call
3. **按需绘制** - 只在 brightness > 1 时绘制 bloom

## 参考示例

完整示例参见：
- `engine/bin/Data/LuaScripts/59_NanoVG_Bloom.lua` - Bloom 核心用法示例（推荐）

示例中的关键设计：
1. `DrawCircleBloom` 接收已计算好的 HDR 颜色，内部不再乘任何系数
2. `DrawGlowingCircle` 在 `brightness > 1.0` 时才调用 bloom
3. 使用全局常量 `BLOOM_INNER_ALPHA` 等，而不是传递 params 表

## ❌ 常见错误

### 错误1：在 DrawBloom 内部再乘 intensity

```lua
-- ❌ 错误实现
function DrawBloom(x, y, radius, r, g, b, intensity)
    local hdrR = r * intensity  -- 双重放大！
    ...
end

-- 调用时
drawBloom(x, y, r, g, b, 1.5)  -- r, g, b 已经是归一化颜色，又乘了 1.5
```

**正确做法**：HDR 颜色在调用前计算好，`DrawCircleBloom` 直接使用传入的颜色。

### 错误2：无条件绘制 bloom

```lua
-- ❌ 错误：所有元素都加 bloom
drawCircleBloom(x, y, radius, r, g, b)  -- 没有 brightness 判断

-- ✅ 正确：只在 brightness > 1.0 时绘制
if brightness > 1.0 then
    drawCircleBloom(x, y, radius, hdrR, hdrG, hdrB)
end
```

### 错误3：brightness 值过高

```lua
-- ❌ 错误：brightness 太高导致光晕过大
local brightness = 2.5  -- 太高！

-- ✅ 正确：推荐 1.1 ~ 1.5 范围
local brightness = 1.3
```

### 错误4：给所有元素都加 bloom

飞船、敌人、背景星星等不需要 bloom 效果，只给子弹、粒子、经验碎片等小型发光元素添加。

## 已知限制

1. **线性衰减** - 边缘衰减不够自然，无法模拟高斯曲线
2. **只支持简单形状** - 圆形 (RadialGradient)、矩形 (BoxGradient)
3. **多层叠加有硬边界** - 每层渐变的 outerRadius 处会有可见边界
