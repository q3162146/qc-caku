# 渲染配置说明

> UrhoX 渲染系统的关键配置：灯光预设 / 雾 / 天空盒

---

## 灯光组 (LightGroup)

LightGroup 预设是一个 **打包好的"光照 + 大气"配置**——加载它就同时配好了方向光（太阳）、雾。多数项目直接用预设即可，不用自己创建 Light / Zone。

### 🔴 核心规则：LightGroup 已包含 Zone，不要重复创建

**LightGroup XML 内部结构**：

```
LightGroup node
├── Zone component         ← 环境光、雾效、IBL、Bloom、SH 光照
└── Directional Light node
    └── Light component    ← 主光源、阴影、CSM
```

**LightGroup 已经包含了完整的 Zone 和方向光配置**（其 Zone 的 priority=-1）。加载 LightGroup 后，场景中就已有 Zone，**不要再手动创建 Zone**——手动创建的 Zone 默认 priority=0，会覆盖 LightGroup 的 Zone，导致预设的 IBL、SH 光照、Bloom、雾效等参数全部丢失。如需调整 Zone 参数，应获取 LightGroup 中已有的 Zone（见下方示例）。

```lua
-- ✅ 正确：只加载 LightGroup，不创建额外的 Zone
local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())
-- 场景光照已完整配置，无需其他操作

-- ❌ 错误：加载 LightGroup 后又手动创建 Zone
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())
-- 新 Zone 的 priority=0 > LightGroup Zone 的 priority=-1
-- 整个 Zone 被替换，LightGroup 预设的全部参数（IBL、SH、Bloom、雾效等）都会丢失
local zone = scene_:CreateComponent("Zone")
zone.fogColor = Color(0.5, 0.6, 0.8)
```

### 加载后访问 Zone 和 Light

如果需要在运行时微调 LightGroup 中的参数：

```lua
-- 加载
local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())

-- 获取 Zone（第二个参数 true = 递归查找子节点）
local zone = lightGroup:GetComponent("Zone", true)
zone.fogColor = Color(0.5, 0.6, 0.8)        -- 调整雾色
zone.fogStart = 100                          -- 雾起始距离（米）
zone.fogEnd = 500                            -- 雾终止距离（米）
-- 注意：ambientColor 已废弃（shader 中被归零），环境光由 SH 球谐驱动，通过 LightGroup 预设配置

-- 获取方向光（同样递归查找）
local light = lightGroup:GetComponent("Light", true)
light.brightness = 3.0                       -- 调整亮度
light.color = Color(1, 0.9, 0.8)            -- 调整光色
light.castShadows = true                     -- 开关阴影
```

### 可用预设

| 文件 | 说明 | 光色 | 亮度 |
|------|------|------|------|
| `LightGroup/Daytime.xml` | 白天（推荐默认） | 暖白 | 3 |
| `LightGroup/Dusk.xml` | 黄昏 | 橙色 | 5 |
| `LightGroup/Sandstorm.xml` | 沙尘暴 | 暖黄 | 6 |
| `LightGroup/Night.xml` | 夜晚 | 冷蓝 | 0.8 |
| `LightGroup/Midnight.xml` | 午夜 | 冷蓝 | 1.1 |
| `LightGroup/DarkNight.xml` | 暗夜 | 紫蓝 | 1.3 |
| `LightGroup/BloodNight.xml` | 血夜 | 冷白 | 0.55 |

**选择建议**：
- 一般 3D 场景 → `Daytime`
- 温暖氛围 → `Dusk` 或 `Sandstorm`
- 恐怖/悬疑 → `DarkNight` 或 `BloodNight`
- 宁静夜景 → `Night` 或 `Midnight`

### Zone 包含的主要能力

LightGroup 的 Zone 已预设了以下全部配置，**无需手动配置**：

- 远景雾效（深度雾、高度雾）
- IBL 环境光照（球谐漫射光照 + 环境反射）
- 后效（泛光、暗角等）
- 水面反射

### 雾效系统

Zone 支持两种雾效，可同时启用：

**深度雾/距离雾（Depth Fog）**：基于相机距离的线性雾，物体在 `fogStart`～`fogEnd`（米）之间逐渐被雾覆盖。`fogDensity` 控制深度雾的浓度（默认 1.0，仅影响深度雾，不影响高度雾），设为 0 等价于关闭深度雾，< 1.0 雾更稀薄，> 1.0 雾更浓厚。LightGroup 预设已配置，默认启用。

**高度雾（Height Fog）**：基于世界 Y 坐标的雾，低于 `fogHeight` 的区域产生雾效，`fogHeightScale` 控制衰减速度。需 `heightFog = true` 显式开启。

```lua
local zone = lightGroup:GetComponent("Zone", true)

-- 深度雾
zone.fogColor = Color(0.6, 0.7, 0.9)
zone.fogStart = 50    -- 起始距离（米）
zone.fogEnd = 300     -- 终止距离（米）
zone.fogDensity = 1.0 -- 深度雾浓度（默认 1.0，0=关闭深度雾，<1 稀薄 >1 浓厚，不影响高度雾）

-- 高度雾（需显式开启）
zone.heightFog = true
zone.fogHeight = 5.0       -- 雾面高度（世界 Y 坐标，米）
zone.fogHeightScale = 0.5  -- 衰减速度（越大衰减越快）
```

> LightGroup 内部细节（XML 字段）由引擎管理，**Lua 层把它当黑盒**——加载就用，需要更细控制时按下面方法在 Lua 里覆盖。

### 环境光 / IBL / SH 只能换 LightGroup 预设

LightGroup XML 里烘焙了 **环境光球谐 (SphericalHarmonicsL2)、环境镜面反射 cubemap (Env Spec Texture)、环境贴图角度** 等。这些**没暴露给 Lua**，唯一改法是切换到另一个 LightGroup 预设：

```lua
-- 想换"白天的环境氛围"为"夜晚的"——直接换预设
local lgNode = scene_:GetChild("LightGroup")  -- 必须先有已加载的 LightGroup
lgNode:RemoveAllComponents()  -- 清旧
local f = cache:GetResource("XMLFile", "LightGroup/Night.xml")
lgNode:LoadXML(f:GetRoot())
```

> ⚠️ **不要试图通过 `zone.ambientColor` 改环境光**——引擎已硬下发 `cAmbientColor=(0,0,0,0)`，赋值是 no-op。环境光、IBL 立方体反射、SH 漫反射都只能通过整套 LightGroup 切换。如果现有预设都不满足，需要美术离线烘焙新预设（不在 Lua 范围）。

---

## 自建点光 / 追光（火把 / 车灯 / 室内灯）

LightGroup 只管太阳和环境，**点光（Point）和追光（Spot）必须自己建**。典型场景：火把、室内灯泡、车灯、手电、霓虹灯、爆炸光闪。

> ⚠️ 下方示例的 brightness 值需配合 **auto-exposure** 使用（`zone.autoExposureEnabled = true`），否则会过曝。详见下方"brightness 取值参考"。

```lua
-- 篝火光（Point Light）
local lightNode = scene_:CreateChild("Campfire")
lightNode.position = Vector3(5, 0.5, 0)
local light = lightNode:CreateComponent("Light")
light.lightType = LIGHT_POINT
light.color     = Color(1.0, 0.6, 0.2)   -- 暖橙色
light.brightness = 80                     -- 亮度（需开启 auto-exposure，见下方参考）
light.range     = 12.0                    -- 光照半径（米）
light.castShadows = false                 -- 点光阴影开销大，看需求
```

```lua
-- 手电 / 车灯（Spot Light）
local lightNode = cameraNode:CreateChild("Flashlight")
lightNode.direction = Vector3(0, 0, 1)
local light = lightNode:CreateComponent("Light")
light.lightType  = LIGHT_SPOT
light.color      = Color(1, 1, 1)
light.brightness = 3000                  -- Spot 较远距离需更高值（需开启 auto-exposure）
light.range      = 20.0
light.fov        = 45.0                   -- 光锥张角（度）
```

### brightness 取值参考

引擎衰减公式与 UE 一致（`1/(d²+1)` + 窗口函数），配合 auto-exposure 使用时 `brightness` 可直接对标 UE 的坎德拉量级。下面是经 UE 美术对齐后的推荐值：

| 用途 | brightness | range | 说明 |
|---|---|---|---|
| 暗房间小蜡烛 | 1 | 3 - 5 | 微弱暖光 |
| 室内灯泡 / 台灯 | 30 | 6 - 12 | 普通房间照明 |
| 火把（单根） | 25 - 30 | 5 - 8 | 小火焰，照亮周围几米 |
| 篝火（火堆） | 80 | 8 - 15 | 大火堆，照亮营地，能看到 bloom |
| 路灯 | 500 | 15 - 25 | 高杆照明 |
| 车灯 / 手电 | 3000 | 20 - 40 | 配 Spot + 较远 range |
| 爆炸 / 闪电瞬闪 | 5000+ | 视场景 | 短暂触发，配合 HDR/Bloom |

> **需要开启 auto-exposure**：`zone.autoExposureEnabled = true`（Zone 属性）。开启后引擎会自动调节曝光，上述值可直接使用。不开启 auto-exposure 时，这些值会严重过曝，需改用更小的经验值（蜡烛 ~0.5、台灯 ~5、篝火 ~8、路灯 ~30）。
>
> **何时开启 auto-exposure**：auto-exposure 会增加一个亮度直方图 RT，带宽接近翻倍。**推荐在以下场景开启**：场景有明暗区域切换（室内↔室外）、多种强度光源共存（蜡烛 + 路灯）、需要物理准确的灯光效果。**不建议开启的场景**：纯 2D 游戏、固定视角且光照不变的简单场景、对移动端性能敏感的项目。

---

## 自定义 Zone（覆盖雾参数）

**先问自己：能不能直接用现成 LightGroup 预设？**——能的话别建 Zone，加载 XML 就完事。需要换天气就换 XML（`Daytime.xml` → `Night.xml`）。

**真正需要自建 Zone 的场景**：

- **风格化的特殊效果**——预设里没有的，比如近距浓毒雾（fogStart=1.5, fogEnd=15）、地牢级深红雾色等
- **运行时动态调节**——根据天气系统/玩家行为实时改 fogColor / fogStart / fogEnd（LightGroup XML 是静态的）
- **局部分区雾**——同场景里室内 vs 室外不同雾密度，用 priority 高的小 bbox Zone 覆盖局部

### Zone 在 Lua 能设的属性

```lua
local zoneNode = scene_:CreateChild("Zone")
local zone = zoneNode:CreateComponent("Zone")

-- 必设：bbox 要覆盖玩家可能去的所有位置
zone.boundingBox  = BoundingBox(Vector3(-500, -500, -500), Vector3(500, 500, 500))

-- 雾：典型的"远景柔和大气雾"参数
zone.fogColor     = Color(0.55, 0.60, 0.65, 1.0)   -- 偏冷灰，跟天空淡蓝协调
zone.fogStart     = 50.0                            -- 50m 开始有雾
zone.fogEnd       = 250.0                           -- 250m 完全融入雾色
-- zone.fogDensity = 1.0                            -- 深度雾浓度（默认 1.0，0=关闭深度雾，<1 稀薄 >1 浓厚，不影响高度雾）

-- 优先级：默认 0；大于 LightGroup 的 -1 即可自动接管（见下方"跟 LightGroup 共存"）
-- 多 Zone 重叠时数大者赢
zone.priority     = 0

-- 自动曝光（明暗区域切换时推荐开启，有性能开销）
-- zone.autoExposureEnabled = true

-- 高级（少见场景）
-- zone.override    = false      -- 见下方"farClip 陷阱"
-- zone.heightFog   = false      -- 启用高度雾
-- zone.fogHeight   = 0          -- 高度雾起点 Y
-- zone.fogHeightScale = 0       -- 高度雾衰减
```

### 怎么选参数

| 场景类型 | fogStart / fogEnd | fogColor 风格 |
|---|---|---|
| **晴天 / 清晰远景** | 80 / 300+ | 跟天空淡蓝一致（0.5-0.7 灰蓝）|
| **阴天 / 雾蒙蒙** | 30 / 150 | 浅灰白（约 0.6, 0.6, 0.65）|
| **夜晚** | 20 / 100 | 暗蓝（约 0.05, 0.08, 0.15）|
| **浓雾 / 视野受限** | 5 / 40 | 跟环境基调匹配（沙暴用暖色、有毒环境用异色等）|

数值是参考起点，按实际场景调整。需要"几乎贴脸都看不清"的极端浓雾场景，可以下到 fogStart=2 / fogEnd=15。

**boundingBox 选择**：取相机能去到的最远位置 + 余量。如果不确定就 ±1000 兜底（覆盖大多数游戏世界）。

### 跟 LightGroup 共存：自动按 priority 覆盖

LightGroup 预设里带的 Zone 是 **`priority = -1`**（背景级）。任意新建 Zone 默认 `priority = 0`，自动赢——所以加载了 LightGroup 之后**直接建自己的 Zone 就行，不用清理 LightGroup**。

```lua
-- 加载 LightGroup（带个低优先级 Zone）
local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())

-- 直接建自己的 Zone，priority=0 > LightGroup 的 -1，自动覆盖
local zoneNode = scene_:CreateChild("Zone")
local zone = zoneNode:CreateComponent("Zone")
-- ...按上面"Zone 在 Lua 能设的属性"里的方式设置 fog 等
```

> 自建 Zone 没生效（看到的还是 LightGroup 的雾）？检查相机当前位置是否在你的 Zone bbox 内。Zone 是按"相机位置在哪个 Zone 内 → 该 Zone 接管"判定的。

### ⚠️ 雾"看不见" / "再远也清晰"的两个陷阱

#### 1. fogColor 跟天空盒地平线色不一致 → 远处看到色差线

雾把远处物体染成 fogColor。如果同时有天空盒，天空底部颜色 ≠ fogColor → 地平线一道明显接缝。

**协调原则**：让天空盒的地平线颜色 ≈ fogColor，过渡才自然。

#### 2. `camera.farClip` 远超 Zone bbox → 远端 fog 被引擎稀释

引擎逻辑：每个物体根据自身位置找所属 Zone。远处物体超出你 Zone 的 bbox 时 → 被分配到 LightGroup 的低优先级 Zone 或引擎默认 Zone（不同的 fog 参数）→ 远端 fog 突然变淡或变色。

**修法二选一**：
- 把 Zone bbox 加大到覆盖 farClip 范围（推荐，简单）
- 或显式 `zone.override = true`（让引擎跳过远端 Zone 查找）

```lua
-- 例：相机 farClip = 2000，Zone bbox 至少要 ±2000
zone.boundingBox = BoundingBox(Vector3(-2000,-2000,-2000), Vector3(2000,2000,2000))
-- 或：
zone.override = true
```

---

## 自定义天空盒

LightGroup 预设 **不包含天空盒**——它配置的是背景纯色（来自 Zone.fogColor）。要可见的天空（渐变 / cubemap 全景）必须额外创建。

### 模型 + Technique 的对应关系

天空盒统一使用 **`Box.mdl` + `Techniques/DiffSkybox.xml`**。Skybox shader 在 **postopaque pass** 渲染、**不计算雾**——天空与雾彻底解耦，无论 fog 多浓天空都正常可见。

| 想要的效果 | 贴图来源 |
|---|---|
| **程序化渐变天空**（天顶→地平线→地面 三色过渡）| 运行时生成 cubemap（见下方 `MakeGradientCubemap`）|
| **Cubemap 全景**（星空、云海、日落照片、HDRI 全景）| 从文件加载 cubemap（`.xml` 描述 6 面 `.dds`）|

### ⚠️ 别用 `DiffUnlit.xml` 当天空 technique

```lua
-- ❌ 错误：DiffUnlit 是普通几何体 shader，会按距离应用雾
--   用了它，近距浓雾下天空被染成 fogColor，再也看不见
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
```

### 程序化渐变天空（推荐做法）

运行时生成 6 面 cubemap，颜色由**视线仰角**决定——全方位无缝，不受相机旋转影响。

```lua
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"

-- 白天（使用内置预设）
SkyUtils.CreateGradientSky(scene_, SkyUtils.Presets.Day)

-- 黄昏
SkyUtils.CreateGradientSky(scene_, SkyUtils.Presets.Sunset)

-- 自定义配色
SkyUtils.CreateGradientSky(scene_, {
    zenith   = Color(0.06, 0.18, 0.52),  -- 天顶色
    horizon  = Color(0.28, 0.52, 0.82),  -- 地平线色（建议 == fogColor）
    ground   = Color(0.15, 0.25, 0.35),  -- 地面色（可选，默认 horizon × 0.7）
    skyExp   = 0.5,                       -- 渐变指数（<1 集中在地平线，>1 更平）
    hdrBoost = 2.0,                       -- ACES 曝光补偿（默认 2.0）
})
```

> 颜色只是参考，实际项目应由美术根据场景风格调整。`hdrBoost` 补偿 Skybox shader 的 ACES 色调映射——不加的话天空会偏暗偏灰。

**底层 API**（需要更细控制时）：

```lua
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"
-- 只生成 cubemap 贴图，不创建节点
local tex = SkyUtils.MakeGradientCubemap({ zenith = ..., horizon = ... })
-- 自己创建材质和 Skybox 节点
```

### Cubemap 全景天空

```lua
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffSkybox.xml"))
-- 替换为你的 cubemap 资源路径（.xml 描述 6 面 .dds/.png）
mat:SetTexture(TU_DIFFUSE, cache:GetResource("TextureCube", "Textures/YourSkybox.xml"))
-- 注意：文件加载的 DDS cubemap 通常已是 HDR 值，不需要 MatDiffColor boost
-- （仅程序化生成的 LDR cubemap 才需要 MatDiffColor=2x 补偿 ACES）

local skyNode = scene_:CreateChild("Sky")
local skybox = skyNode:CreateComponent("Skybox")
skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
skybox:SetMaterial(mat)
```

### 预制 Cubemap 天空球

官方预制了多款 cubemap 天空球资源，通过 `uuid://` 协议直接加载，无需自备贴图。

#### 可用预设

**写实风格**：

| UUID | 说明 |
|------|------|
| `uuid://E4ehad-5axjv7Ml9zasxNx06` | 写实天空 A |
| `uuid://E_LhMeSIwE-bKC9lR3h2XYq1` | 写实天空 B |
| `uuid://ENC1IXaQqFYisE64aHW9CwX0` | 写实天空 C |
| `uuid://GNxJASZSCM8_0Qv-m3hrFG9c` | 写实天空 D |

**卡通风格**：

| UUID | 说明 |
|------|------|
| `uuid://FLDDYX_pywJHfYE8c3Jwx0vF` | 卡通天空 A |
| `uuid://GJ8nsQ8Du2jNH7SS-dkUFW8K` | 卡通天空 B |
| `uuid://G66LIcifaqH6u2b4cR-wnXd9` | 卡通天空 C |
| `uuid://HNmLET7gY1d6IAwqWCyBqzZz` | 卡通天空 D |
| `uuid://ENfIIRN-9-n9fRN85B3Axnif` | 卡通天空 E |

#### 用法

```lua
-- 加载预制 cubemap 天空球（以写实风格 A 为例）
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffSkybox.xml"))
mat:SetTexture(TU_DIFFUSE, cache:GetResource("TextureCube", "uuid://E4ehad-5axjv7Ml9zasxNx06"))

local skyNode = scene_:CreateChild("Sky")
local skybox = skyNode:CreateComponent("Skybox")
skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
skybox:SetMaterial(mat)
```

**选择建议**：
- PBR / 写实渲染风格 → 写实天空
- 低多边形 / 卡通渲染风格 → 卡通天空
- 不确定 → 先试 `uuid://E4ehad-5axjv7Ml9zasxNx06`（写实天空 A），风格最通用

---

## 常见视觉问题排查

| 症状 | 原因 | 修法 |
|---|---|---|
| 程序化天空颜色偏暗偏灰 | Skybox shader 内部做 ACES 色调映射，LDR 值（0~1）被过度压缩 | `mat:SetShaderParameter("MatDiffColor", Variant(Vector4(2.0, 2.0, 2.0, 1.0)))` 推到 HDR 范围 |
| fogColor 设了饱和色（红/粉）→ 整个场景都染成那个颜色 | fog 不只影响天空地平线——**所有超过 fogStart 的物体都会被染成 fogColor** | fogColor 用低饱和的自然色（灰蓝/灰白/暖灰），避免纯色 |
| 远处物体的 fog 突然变色或消失 | 远处物体超出 Zone bbox → 被分配到 LightGroup 的 Zone（不同 fog） | 加大 Zone bbox 覆盖 farClip，或 `zone.override = true` |

---

## 自定义环境光

Zone 支持运行时从天空球或指定纹理自动生成环境光照（漫射 SH + 镜面反射 IBL），在后台异步完成，不阻塞主线程。适用于需要让环境反射和漫射光照匹配场景天空的场景。

### 环境光来源模式

| 模式 | 说明 |
|------|------|
| `AMBIENT_PREBAKED`（默认） | 使用预烘焙的 SH 系数和 specular cubemap（由 LightGroup 或手动设置） |
| `AMBIENT_SKYBOX` | 自动从场景 Skybox 组件获取 cubemap 并烘焙 SH + IBL |

### 基本用法

```lua
-- 方式 1：自动从 Skybox 烘焙（最简单）
zone.ambientSource = AMBIENT_SKYBOX
zone.ambientIntensity = 1.0
-- View.cpp 自动找到场景中的 Skybox，获取其纹理并触发后台烘焙

-- 方式 2：手动指定源纹理
zone.ambientSource = AMBIENT_PREBAKED
local cubemap = cache:GetResource("TextureCube", "Textures/MySky.ktx")
zone.sourceTexture = cubemap      -- 触发后台烘焙
zone.ambientIntensity = 1.0

-- 方式 3：使用全景图（Texture2D 自动转 cubemap）
local panorama = cache:GetResource("Texture2D", "Textures/Environment.hdr")
zone.sourceTexture = panorama     -- 自动转 cubemap 后烘焙
```

### 参数说明

| 属性 | 类型 | 说明 |
|------|------|------|
| `ambientSource` | `AmbientSource` | 环境光来源模式（`AMBIENT_PREBAKED` / `AMBIENT_SKYBOX`） |
| `sourceTexture` | `Texture*` | 源纹理，可以是 TextureCube 或 Texture2D（全景图）。填入后自动触发后台烘焙 |
| `ambientIntensity` | `float` | 统一的环境光强度（同时设置漫射和镜面反射强度） |

### 烘焙行为

- **后台异步**：烘焙在后台线程中执行，不阻塞渲染
- **缓存复用**：相同纹理的烘焙结果会被自动缓存，再次设置同一纹理时即时生效，无需重复烘焙
- **状态恢复**：烘焙结果与预烘焙数据独立存储，将 `ambientSource` 切回 `AMBIENT_PREBAKED` 时自动恢复预烘焙数据
- **全景图支持**：`sourceTexture` 设置 Texture2D 时自动在后台执行全景图→cubemap 转换后再烘焙

### 注意事项

- LightGroup 预设已包含预烘焙的 SH 和 specular cubemap，使用 `AMBIENT_SKYBOX` 模式会覆盖预设值（切回 `AMBIENT_PREBAKED` 可恢复）
- `ambientIntensity` 默认值为 0.3，使用烘焙模式时通常需要设为 1.0 以获得正确亮度

---

## 后效（Post Effects）

后效全部挂在 **Zone 组件**上。加载 LightGroup 后，从中拿到 Zone 再操作：

```lua
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())
local zone = lightGroup:GetComponent("Zone", true)
```

游戏脚本可调的 3 个后效：

| 后效 | 用途 | 默认 |
|---|---|---|
| Vignette | 暗角，氛围感 | OFF |
| AutoExposure | 室内↔室外明暗自动适配 | OFF |
| GaussianBlur | 全屏模糊，做暂停菜单/弹窗背景虚化 | OFF |

### Vignette（暗角）

LightGroup 预设里已经内置 vignette 贴图，直接开即可：

```lua
zone.vignetteEnabled   = true
zone.vignetteIntensity = 1.0   -- 默认 1.0 适合大多数场景；值越大暗角越浓
```

`vignetteIntensity` 与暗角浓度成正比：

| 视感 | `vignetteIntensity` |
|---|---|
| 柔和暗角（默认，绝大多数场景） | 1.0 |
| 较浓 | 2 ~ 3 |
| 电影感 | 4 ~ 5 |
| 大面积压黑 | 6+ |

需要换贴图时（中心高亮、四角偏暗的灰度 PNG）：

```lua
zone.vignetteTexture = cache:GetResource("Texture2D", "Textures/MyVignette.png")
```

### AutoExposure（自动曝光）

```lua
zone.autoExposureEnabled = true
```

适合：场景有明暗切换（如室内↔室外、白天↔夜晚切换）、需要物理光照单位的项目。
不适合：纯 2D、固定光照的简单场景、性能敏感的低端设备——会增加一组亮度直方图 RT，约一个全屏 pass 开销。

### GaussianBlur（全屏模糊）

典型用法：游戏暂停时把整个场景虚化，再叠菜单 UI 上去。

```lua
-- 暂停时
zone:SetAttribute("Gaussian Blur Enable", Variant(true))

-- 恢复时
zone:SetAttribute("Gaussian Blur Enable", Variant(false))
```

⚠️ 这个开关目前只能走 `SetAttribute`，没有 Lua property（其它后效都有 property）。

### 综合示例：夜景 + 暗角 + 自动曝光

```lua
local lg = scene_:CreateChild("LightGroup")
lg:LoadXML(cache:GetResource("XMLFile", "LightGroup/Night.xml"):GetRoot())
local zone = lg:GetComponent("Zone", true)

zone.autoExposureEnabled = true
zone.vignetteEnabled     = true
zone.vignetteIntensity   = 2.0   -- 比默认略浓
```

---

## 相关文档

- [材质列表](./materials.md) — 物体材质（PBR）

---

[返回文档索引](../index.md)
