# 内置模型尺寸参考

**引擎基础模型的精确尺寸数据**

---

## 📏 长度单位

**UrhoX 引擎的长度单位是米（meter）**

所有尺寸数据单位均为米。

---

## ⚠️ 重要

**在使用基础模型时，绝不要猜测尺寸！**

两种获取尺寸的正确方法：
1. ✅ 查看本文档的尺寸表
2. ✅ 使用 `model.boundingBox` 动态获取

---

## 📐 基础模型尺寸表

| 模型 | 路径 | 包围盒尺寸 (X × Y × Z) | 说明 |
|------|------|------------------|------|
| **Box** | `Models/Box.mdl` | 1.0 × 1.0 × 1.0 | 标准立方体 |
| **Sphere** | `Models/Sphere.mdl` | 1.0 × 1.0 × 1.0 | 直径1.0，半径0.5 |
| **Cylinder** | `Models/Cylinder.mdl` | 1.0 × 1.0 × 1.0 | 高度1.0 |
| **Cone** | `Models/Cone.mdl` | 0.9958 × 1.0 × 0.9958 | ⚠️ 底面略小 |
| **Plane** | `Models/Plane.mdl` | 1.0 × 0.002 × 1.0 | ⚠️ 几乎无厚度 |
| **Pyramid** | `Models/Pyramid.mdl` | 1.0 × 1.0 × 1.0 | 四棱锥 |
| **Torus** | `Models/Torus.mdl` | 1.2776 × 0.2555 × 1.2776 | ⚠️ 扁平且宽 |

---

## 💡 动态获取尺寸，推荐使用 boundingBox

### 使用 boundingBox 获取模型尺寸

```lua
local model = node:CreateComponent("StaticModel")
model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

-- 获取模型边界框
local bbox = model.boundingBox
local size = bbox.size  -- Vector3(宽, 高, 深)

print("Model size:", size.x, size.y, size.z)
```


---

## ⚠️ 特别注意

### Torus（最不规则）
- 宽度 1.2776（超过1.0）
- 高度 0.2555（很小）
- 贴地: `y = 0.128`

### Plane（几乎无厚度）
- 高度仅 0.002
- 作地面: `y = 0`
- 作墙壁需旋转: `rotation = Quaternion(90, 0, 0)`

### Cone（底面略小）
- 底面 0.9958（不是1.0）
- 碰撞检测要用实际值

---

## 🔍 调试验证

```lua
-- 绘制模型边界框
function DebugDrawBounds(node)
    local model = node:GetComponent("StaticModel")
    local debugRenderer = scene_:GetComponent("DebugRenderer")
    
    if model and debugRenderer then
        debugRenderer:AddBoundingBox(
            model.worldBoundingBox,
            Color(1, 1, 0),
            false
        )
    end
end
```

---

## 🔧 缺失形状：优先用程序化几何体 API

**当需要内置模型没有的形状（球/柱/环/多面体/胶囊/圆角盒/星形/挤出/管/凸包/贴花/茶壶…）时，优先用 three.js 兼容的程序化几何体 API**，几乎不用手写顶点循环：

```lua
-- 名称/参数与 three.js 完全一致，:ToModel() 挂到 StaticModel
obj.model = CapsuleGeometry(0.5, 1.0):ToModel()
obj.model = RoundedBoxGeometry(1, 1, 1, 4, 0.15):ToModel()
```

详见 **[recipes/procedural-geometry.md](procedural-geometry.md)**（可用几何体清单 + 与 three.js 的差异）。

仅当需要**完全自定义、上述 API 也没有**的形状时，才手写 CustomGeometry：

| 需求形状 | 内置支持 | 解决方案 |
|---------|---------|---------|
| 半球（水果切开效果） | ❌ | CustomGeometry |
| 圆锥台/截锥体 | ❌ | CustomGeometry |
| 楔形/斜面 | ❌ | CustomGeometry |
| 扇形/弧形 | ❌ | CustomGeometry |
| 胶囊体（非物理） | ❌ | CustomGeometry |
| 任意多边形柱体 | ❌ | CustomGeometry |

### 示例：创建半球

```lua
--- 创建半球几何体（如水果切开效果）
---@param node Node 要附加几何体的节点
---@param radius number 半球半径
---@param segments number 分段数（推荐 16-32）
---@param isUpperHalf boolean true=上半球, false=下半球
local function CreateHemisphere(node, radius, segments, isUpperHalf)
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)
    
    local rings = math.floor(segments / 2)
    
    for ring = 0, rings do
        local phi
        if isUpperHalf then
            phi = (ring / rings) * (math.pi / 2)
        else
            phi = (math.pi / 2) + (ring / rings) * (math.pi / 2)
        end
        
        for seg = 0, segments do
            local theta = (seg / segments) * math.pi * 2
            local x = radius * math.sin(phi) * math.cos(theta)
            local y = radius * math.cos(phi)
            local z = radius * math.sin(phi) * math.sin(theta)
            
            geom:DefineVertex(Vector3(x, y, z))
            geom:DefineNormal(Vector3(x/radius, y/radius, z/radius))
            geom:DefineTexCoord(Vector2(seg/segments, ring/rings))
        end
    end
    
    -- 生成三角形索引（此处简化，完整版见 coding-insights）
    geom:Commit()
    return geom
end
```

### CustomGeometry 关键点

| 要点 | 说明 |
|------|------|
| **顶点顺序** | 逆时针绕序 = 正面朝外 |
| **法线方向** | 必须指向外部，否则光照错误 |
| **性能** | 分段数越高越平滑，推荐 16-32 |

**记住**: 内置模型没有的形状 → CustomGeometry

详见：`examples/07-minecraft-voxel-world.lua`（CustomGeometry 大规模使用示例）

---

**最后更新**: 2026-01-30

