# 程序化几何体（three.js 兼容）

**你已经会 three.js 的几何体——这套 API 的类名、参数顺序、默认值、语义都和 three.js 完全一致，直接按 three.js 记忆写即可。**

引擎在底层生成顶点，Lua 只传参。坐标系自动处理，规则只有一条：

- **参数化形体**（Box/Sphere/Cylinder/Torus/TorusKnot…只传标量参数的）：与 three.js 渲染效果一致，正面朝向、绕序都不用操心；
- **显式坐标输入**（点云/路径点/顶点表/截面/2D 轮廓/贴花位置）：**你给的坐标就是引擎世界坐标，逐字生效，不会被翻转**。`ExtrudeGeometry` 沿 +Z 挤出 depth（实体占 z∈[0,depth]），`ShapeGeometry` 面朝 +Z。

> 需要 `built-in-models.md` 里没有的形状（球/柱/环/多面体/星形/文字轮廓挤出…）→ **优先用这套 API**，不要手写 CustomGeometry 循环。

---

## 用法：两条出图路径

每个 `XxxGeometry(...)` 返回一个 geometry 对象，用它生成可渲染内容：

```lua
-- 路径 A（推荐）：ToModel() → StaticModel.model
local node = scene_:CreateChild("Box")
local obj = node:CreateComponent("StaticModel")
obj.model = BoxGeometry(1, 1, 1):ToModel()
obj.material = material          -- 任意材质；纯色见 materials skill（Techniques/PBR/PBRNoTexture.xml）

-- 路径 B：FillCustomGeometry(cg)（动态/一次性）
local cg = node:CreateComponent("CustomGeometry")
SphereGeometry(1, 32, 16):FillCustomGeometry(cg)
cg:SetMaterial(material)
```

`ToModel()` 生成的 Model 可复用到多个节点，省内存：

```lua
local shared = BoxGeometry(1, 1, 1):ToModel()
for i = 1, 10 do
    local n = scene_:CreateChild("b" .. i)
    n.position = Vector3(i * 1.5, 0, 0)
    n:CreateComponent("StaticModel").model = shared
end
```

---

## 可用几何体（参数同 three.js，仅列名）

**Core**：`BoxGeometry` `PlaneGeometry` `SphereGeometry` `CylinderGeometry` `ConeGeometry` `CircleGeometry` `RingGeometry` `TorusGeometry` `TorusKnotGeometry` `TubeGeometry` `LatheGeometry` `CapsuleGeometry` `TetrahedronGeometry` `OctahedronGeometry` `IcosahedronGeometry` `DodecahedronGeometry` `PolyhedronGeometry` `ShapeGeometry` `ExtrudeGeometry` `EdgesGeometry` `WireframeGeometry`

**Addons**：`RoundedBoxGeometry` `BoxLineGeometry` `ParametricGeometry` `ConvexGeometry` `LoftGeometry` `DecalGeometry` `TeapotGeometry`

> 忘了某个的参数？回忆 three.js 同名构造函数即可，一模一样（如 `CylinderGeometry(radiusTop, radiusBottom, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength)`）。

---

## ⚠️ 与 three.js 的差异（只有这几处）

| 项 | three.js | 这里 |
|---|---|---|
| 顶点数据怎么拿 | `geometry.attributes` | 用 `:ToModel()` / `:FillCustomGeometry(cg)` 出图 |
| 数组类参数 | Vector2/Vector3 对象数组 | **Lua 表** `{ Vector2(..), .. }`（见下） |
| Parametric 曲面函数 | 传 JS 函数 | **传字符串名**：`ParametricGeometry("Klein", 25, 25)`；内置 `"Klein"` `"Plane"` `"Mobius"` `"Mobius3D"` |
| 线几何材质 | — | `EdgesGeometry`/`WireframeGeometry`/`BoxLineGeometry` 无法线，材质须用无光照 `Techniques/NoTextureUnlit.xml`，否则发黑 |
| 暂不支持 | — | `ExtrudeGeometry` 无 bevel；`ShapeGeometry`/`ExtrudeGeometry` 不支持带洞轮廓；**`TextGeometry` 暂不可用** |
| 部分扫掠弧段方位 | 按 three.js 坐标推算 | `thetaStart`/`phiStart` 弧段与 three.js **渲染效果**一致；不要按引擎世界坐标推算弧段落在哪一侧（如需精确方位，生成后旋转节点） |

### 收表参数的几何体
```lua
LatheGeometry({ Vector2(0,-0.5), Vector2(0.4,0), Vector2(0,0.5) }, 24)   -- 2D 剖面绕 Y 轴旋转
TubeGeometry({ Vector3(-2,0,0), Vector3(0,1,1), Vector3(2,0,0) }, 64, 0.2, 8)  -- 路径点(Catmull-Rom)
ConvexGeometry({ Vector3(...), Vector3(...), ... })              -- 点云凸包
ShapeGeometry({ Vector2(...), ... })                             -- 2D 轮廓 → 平面片
ExtrudeGeometry({ Vector2(...), ... }, 0.5)                      -- 2D 轮廓 → 立体（depth=0.5）
PolyhedronGeometry({ x,y,z, ... }, { i0,i1,i2, ... }, 1, 0)      -- 顶点/索引：扁平数字表，索引 0 基
```

> 表里的 Vector2/Vector3 都按**引擎世界坐标逐字使用**，不会被镜像。`ShapeGeometry`/`ExtrudeGeometry` 的 2D 轮廓顺时针/逆时针写都可以（内部自动归一化，同 three.js）；`PolyhedronGeometry` 的三角形索引**必须按外向绕序**给——面法线 `(v1-v0)×(v2-v0)` 指向实体外部（同 three.js，索引绕序无法自动归一化）。

### 派生几何体（输入是另一个 geometry 对象）
```lua
local box = BoxGeometry(1, 1, 1, 2, 2, 2)
WireframeGeometry(box):ToModel()     -- 全部三角边 → 线框
EdgesGeometry(box, 1):ToModel()      -- 只保留硬边（第二参 = 阈值角度，单位度）
DecalGeometry(SphereGeometry(1.3), Vector3(0,0,1.3), Quaternion(), Vector3(1,1,3))  -- 贴花投影到 mesh（位置/朝向按引擎世界坐标）
```

---

## 对象方法

`:ToModel()` · `:FillCustomGeometry(cg)` · `:GetVertexCount()` · `:GetIndexCount()` · `:GetBoundingBox()` · `:SetDynamic(true)`（每帧重建时）

---

**记住**：按 three.js 写 `XxxGeometry(...)` → `:ToModel()` 挂到 `StaticModel.model`；数组参数用 Lua 表，Parametric 用字符串，线几何用 `NoTextureUnlit`。参数化形体坐标系引擎自动兜底；显式坐标逐字生效。

---

*最后更新: 2026-07-10*
