# 材质系统

> 🔴 **优先使用 `materials` Skill** - 完整的材质选择指南（包括 35+ 预制材质库）已整合到 Skill 中。

---

## 📌 何时使用 materials Skill

| 场景 | 做法 |
|------|------|
| 搭建 3D 场景（室内/室外/工业） | → 使用 `materials` Skill |
| 选择预制材质（地面/墙面/金属等） | → 使用 `materials` Skill |
| 创建程序化纯色材质 | → 见下方快速参考 或 使用 Skill |
| 不确定用什么材质 | → 使用 `materials` Skill |

**使用** `materials` skill。

---

## ⚡ 程序化材质快速参考

> 以下是程序化材质的快速参考，完整指南请查阅 `materials` Skill。

### 🔴 只用这三个 Technique（不要猜测其他路径！）

| 效果 | Technique 路径 |
|------|---------------|
| 不透明 PBR | `Techniques/PBR/PBRNoTexture.xml` |
| 透明 PBR | `Techniques/PBR/PBRNoTextureAlpha.xml` |
| 无光照 | `Techniques/NoTextureUnlit.xml` |

### 不透明 PBR（默认首选）

```lua
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
mat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, 1.0)))
mat:SetShaderParameter("Metallic", Variant(0.0))    -- 0=非金属, 1=金属
mat:SetShaderParameter("Roughness", Variant(0.5))   -- 0=光滑, 1=粗糙
```

### 透明 PBR（玻璃/冰/水晶）

```lua
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
mat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, 0.3)))  -- A=透明度
mat:SetShaderParameter("Roughness", Variant(0.05))
```

### 自发光

```lua
mat:SetShaderParameter("MatEmissiveColor", Variant(Color(1.0, 0.5, 0.2)))
-- 颜色值 >1.0 可增强发光强度
```

### 水面（使用预制材质）

```lua
local mat = cache:GetResource("Material", "Materials/SingleLayerWater.xml")
mat:SetShaderParameter("WaterTint", Variant(Color(0.2, 0.4, 0.8)))  -- RGB，无Alpha
```

---

## 📋 常见效果参数

| 效果 | Metallic | Roughness |
|------|----------|-----------|
| 光滑金属 | 0.9-1.0 | 0.1-0.2 |
| 磨砂金属 | 0.9-1.0 | 0.4-0.6 |
| 塑料 | 0.0 | 0.3-0.5 |
| 橡胶 | 0.0 | 0.7-0.9 |
| 陶瓷 | 0.0 | 0.1-0.3 |

---

## 🚫 不要使用

以下 Techniques 需要贴图，**不能用于程序化纯色材质**：

```
Techniques/PBR/PBRMetallicRoughDiffNormalSpec.xml  -- 需要贴图
Techniques/PBR/PBRDiffNormal.xml                   -- 需要贴图
```

---

> 💡 **完整指南**：预制材质库、场景材质推荐、详细参数说明 → 查阅 `materials` Skill

