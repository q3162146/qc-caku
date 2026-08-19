# Geometry 库

**使用 CustomGeometry 创建引擎内置模型不支持的基础形状**

---

## 📋 功能概览

| 函数 | 用途 | 示例场景 |
|------|------|---------|
| `Hemisphere` | 半球 | 水果切割、穹顶、碗 |
| `Arc` | 弧形/扇形 | 饼图、扇形菜单、弧形墙 |
| `Cone` | 圆锥/圆台 | 冰淇淋、漏斗、灯罩 |
| `Torus` | 圆环 | 甜甜圈、轮胎、管道接头 |
| `Disc` | 圆盘 | 硬币、按钮、盖子 |

---

## 🚀 快速开始

```lua
local Primitives = require "urhox-libs.Geometry.Primitives"

-- 创建一个红色半球（水果切开效果）
local node = scene_:CreateChild("FruitHalf")
node.position = Vector3(0, 1, 0)

local geom = Primitives.Hemisphere(node, {
    radius = 0.5,
    isUpper = true,
    outerColor = Color(0.85, 0.12, 0.12, 1.0),  -- 红色外皮
    innerColor = Color(1.0, 0.98, 0.85, 1.0),   -- 浅黄色果肉
})
```

---

## 📖 API 详解

### Primitives.Hemisphere(node, options)

创建半球几何体。

**参数**：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `radius` | number | 0.5 | 半径 |
| `segments` | number | 16 | 分段数，越大越平滑 |
| `rings` | number | segments/2 | 环数 |
| `isUpper` | boolean | true | true=上半球(Y≥0)，false=下半球(Y≤0) |
| `outerColor` | Color | 白色 | 外表面颜色 |
| `innerColor` | Color | 浅灰色 | 切面颜色 |
| `technique` | string | "Techniques/DiffVCol.xml" | 材质技术 |

**示例**：

```lua
-- 水果切割效果
local upperHalf = Primitives.Hemisphere(node1, {
    radius = 0.6,
    isUpper = true,
    outerColor = Color(0.2, 0.6, 0.25, 1.0),   -- 西瓜皮
    innerColor = Color(0.95, 0.25, 0.25, 1.0), -- 西瓜肉
    segments = 24,
})

local lowerHalf = Primitives.Hemisphere(node2, {
    radius = 0.6,
    isUpper = false,
    outerColor = Color(0.2, 0.6, 0.25, 1.0),
    innerColor = Color(0.95, 0.25, 0.25, 1.0),
})
```

---

### Primitives.Arc(node, options)

创建弧形或扇形几何体。

**参数**：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `innerRadius` | number | 0 | 内半径，为0时是扇形 |
| `outerRadius` | number | 1.0 | 外半径 |
| `startAngle` | number | 0 | 起始角度（度数） |
| `endAngle` | number | 90 | 结束角度（度数） |
| `height` | number | 0.1 | 厚度 |
| `segments` | number | 16 | 分段数 |
| `color` | Color | 白色 | 颜色 |

**示例**：

```lua
-- 扇形（内半径为0）
local sector = Primitives.Arc(node, {
    outerRadius = 1.0,
    startAngle = 0,
    endAngle = 120,  -- 120度扇形
    height = 0.1,
    color = Color(1, 0.5, 0, 1),
})

-- 弧形（有内半径）
local arc = Primitives.Arc(node, {
    innerRadius = 0.5,
    outerRadius = 1.0,
    startAngle = 0,
    endAngle = 180,  -- 半圆弧
    height = 0.2,
    color = Color(0.3, 0.6, 1, 1),
})
```

---

### Primitives.Cone(node, options)

创建圆锥或圆台几何体。

**参数**：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `bottomRadius` | number | 0.5 | 底部半径 |
| `topRadius` | number | 0 | 顶部半径，为0时是圆锥 |
| `height` | number | 1.0 | 高度 |
| `segments` | number | 16 | 分段数 |
| `capTop` | boolean | true | 是否封闭顶部 |
| `capBottom` | boolean | true | 是否封闭底部 |
| `color` | Color | 白色 | 颜色 |

**示例**：

```lua
-- 圆锥（顶部半径为0）
local cone = Primitives.Cone(node, {
    bottomRadius = 0.5,
    topRadius = 0,
    height = 1.0,
    color = Color(1, 0.8, 0.2, 1),  -- 黄色
})

-- 圆台（截头圆锥）
local frustum = Primitives.Cone(node, {
    bottomRadius = 0.6,
    topRadius = 0.3,
    height = 0.8,
    color = Color(0.6, 0.4, 0.2, 1),
})

-- 管道（无顶盖无底盖）
local pipe = Primitives.Cone(node, {
    bottomRadius = 0.5,
    topRadius = 0.5,  -- 等半径 = 圆柱
    height = 2.0,
    capTop = false,
    capBottom = false,
})
```

---

### Primitives.Torus(node, options)

创建圆环（甜甜圈）几何体。

**参数**：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `majorRadius` | number | 0.5 | 主半径（环中心到管道中心） |
| `minorRadius` | number | 0.2 | 管道半径 |
| `majorSegments` | number | 24 | 主分段数 |
| `minorSegments` | number | 12 | 管道分段数 |
| `color` | Color | 白色 | 颜色 |

**示例**：

```lua
-- 甜甜圈
local donut = Primitives.Torus(node, {
    majorRadius = 0.4,
    minorRadius = 0.15,
    color = Color(0.8, 0.5, 0.2, 1),  -- 棕色
})

-- 细环
local ring = Primitives.Torus(node, {
    majorRadius = 0.5,
    minorRadius = 0.05,
    color = Color(0.8, 0.7, 0.2, 1),  -- 金色
})
```

---

### Primitives.Disc(node, options)

创建圆盘几何体。

**参数**：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `radius` | number | 0.5 | 外半径 |
| `innerRadius` | number | 0 | 内半径，为0时是实心圆盘 |
| `height` | number | 0.05 | 厚度 |
| `segments` | number | 24 | 分段数 |
| `color` | Color | 白色 | 颜色 |

**示例**：

```lua
-- 硬币
local coin = Primitives.Disc(node, {
    radius = 0.3,
    height = 0.02,
    color = Color(0.8, 0.7, 0.2, 1),  -- 金色
    segments = 32,
})

-- 垫圈
local washer = Primitives.Disc(node, {
    radius = 0.4,
    innerRadius = 0.2,
    height = 0.05,
    color = Color(0.5, 0.5, 0.5, 1),  -- 灰色
})
```

---

## 💡 使用技巧

### 1. 调整分段数

分段数越大，形状越平滑，但顶点越多。推荐值：

| 场景 | 分段数 |
|------|--------|
| 远景物体 | 8-12 |
| 近景物体 | 16-24 |
| 特写/高质量 | 32+ |

### 2. 自定义材质

默认使用 `DiffVCol.xml`（顶点颜色+漫反射光照）。如需 PBR：

```lua
local geom = Primitives.Hemisphere(node, {
    radius = 0.5,
    technique = "Techniques/PBR/PBRNoTextureVCol.xml",
})

-- 手动设置 PBR 参数
local mat = geom:GetMaterial()
mat:SetShaderParameter("Metallic", Variant(0.5))
mat:SetShaderParameter("Roughness", Variant(0.3))
```

### 3. 与 FruitNinja3D 示例配合

原代码：
```lua
-- 旧代码（复杂）
CreateHemisphereGeometry(geom, radius, outerColor, innerColor, isTop)
```

新代码：
```lua
-- 新代码（简洁）
local Primitives = require "urhox-libs.Geometry.Primitives"
local geom = Primitives.Hemisphere(node, {
    radius = radius,
    isUpper = isTop,
    outerColor = outerColor,
    innerColor = innerColor,
})
```

---

## 🔗 相关资源

- `coding-insights/Graphics-Rendering/custom-geometry-for-missing-primitives.md` - 底层原理
- `examples/12-fruit-ninja-3d-game.lua` - 实际使用示例
- `docs/built-in-models.md` - 内置模型列表

---

**最后更新**: 2025-12-24

