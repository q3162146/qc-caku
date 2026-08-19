# Surface Shader 编写教程

## 心智模型

Surface Shader 是给 Lua 游戏脚本使用的自定义材质脚本。你写一个 `.shader` 文件描述材质颜色、贴图、粗糙度、金属度、透明度或顶点形变，然后在 Lua 里把它设置到 `Material` 上。

你只需要关心两层：

| 文件 | 作用 |
|------|------|
| `assets/Shaders/BLGL/*.shader` | 写 Godot-style 的材质逻辑 |
| `scripts/*.lua` | 加载材质、设置贴图、挂到模型上 |

不要使用生成后的 shader 名、纹理槽位名或底层 Technique。Lua 层只使用 `.shader` 文件路径和 shader 源码里的 sampler 名。

---

## 最小例子：纯色无光照材质

资源路径：

```text
assets/
└── Shaders/
    └── BLGL/
        └── GlowBlue.shader
```

`assets/Shaders/BLGL/GlowBlue.shader`：

```glsl
shader_type spatial;
render_mode shading_model_unlit, cull_disabled;

void fragment() {
    ALBEDO = vec3(0.0, 0.75, 1.0);
    ALPHA = 1.0;
}
```

Lua 中使用：

```lua
local material = Material:new()
if not material:SetSurfaceShader("Shaders/BLGL/GlowBlue.shader") then
    print("failed to load surface shader")
    return
end

local model = node:CreateComponent("StaticModel")
model.model = cache:GetResource("Model", "Models/Box.mdl")
model:SetMaterial(material)
```

---

## 透明材质

写 `ALPHA` 不会自动变透明。需要显式加 `blend_mix`。

```glsl
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 tint_color = vec4(0.0, 0.75, 1.0, 0.35);

void fragment() {
    ALBEDO = tint_color.rgb;
    ALPHA = tint_color.a;
}
```

常用规则：

| 需求 | render_mode |
|------|-------------|
| 普通透明 | `blend_mix` |
| 双面透明 | `blend_mix, cull_disabled` |
| 不写深度的透明特效 | `blend_mix, depth_draw_never` |

---

## PBR 材质

PBR 适合受灯光、IBL、阴影影响的实体材质。

```glsl
shader_type spatial;
render_mode shading_model_pbr, cull_back;

uniform vec4 base_color : source_color = vec4(0.85, 0.35, 0.16, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    AO = 1.0;
    EMISSION = vec3(0.0);
}
```

PBR 常用输出：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ALBEDO` | `vec3` | 基础颜色 |
| `ALPHA` | `float` | 透明度，需配合 `blend_*` 才会透明 |
| `ROUGHNESS` | `float` | 粗糙度，0 光滑，1 粗糙 |
| `METALLIC` | `float` | 金属度，0 非金属，1 金属 |
| `AO` | `float` | 环境遮蔽 |
| `EMISSION` | `vec3` | 自发光 |
| `NORMAL_MAP` | `vec3` | 法线贴图采样结果，通常是 `texture(normal_map, UV).rgb` |
| `CLEARCOAT` | `float` | 清漆强度，只在 `shading_model_clearcoat` 下使用 |
| `CLEARCOAT_ROUGHNESS` | `float` | 清漆层粗糙度，只在 `shading_model_clearcoat` 下使用 |

---

## 清漆材质

清漆材质适合车漆、上釉陶瓷、亮面塑料等有额外表层高光的材质。

```glsl
shader_type spatial;
render_mode shading_model_clearcoat, cull_back;

uniform vec4 base_color : source_color = vec4(0.6, 0.05, 0.02, 1.0);
uniform float coat_strength : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float coat_roughness : hint_range(0.0, 1.0, 0.01) = 0.15;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    METALLIC = 0.0;
    SPECULAR = 0.5;
    ROUGHNESS = 0.35;
    AO = 1.0;
    CLEARCOAT = coat_strength;
    CLEARCOAT_ROUGHNESS = coat_roughness;
}
```

---

## 卡通材质（Toon）

卡通材质适合动漫、手绘、低多边形风格。光照被量化成色块（banding），明暗交界硬朗。

```glsl
shader_type spatial;
render_mode shading_model_toon, cull_back;

uniform vec4 base_color : source_color = vec4(0.35, 0.6, 0.9, 1.0);
uniform float band_softness : hint_range(0.0, 1.0, 0.01) = 0.2;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    ROUGHNESS = band_softness;
    METALLIC = 0.0;
    AO = 1.0;
}
```

要点：

- `ROUGHNESS` 同时控制明暗过渡带宽度和卡通高光斑大小：小 → 交界锐利、高光斑小而实；大 → 过渡柔和。
- `shading_model_toon` = toon 漫反射 + toon 高光斑（标准 Godot 卡通 look）。也支持 Godot 原生细粒度写法：
  - `render_mode diffuse_toon;` —— 只量化漫反射，高光保持 GGX
  - `render_mode diffuse_toon, specular_disabled;` —— 量化漫反射且无高光
- 阴影、IBL/环境光、lightmap 不参与量化（与 Godot 行为一致）；点光/聚光同样有 banding 效果。
- `METALLIC` / `SPECULAR` 仍按能量拆分参与计算（与 Godot 一致），卡通材质通常保持 `METALLIC = 0.0`。
- 前向与延迟渲染路径均支持。

---

## 自定义光照 `light()`

需要自己决定每盏实时灯如何影响材质时，可以像 Godot spatial shader 一样编写 `light()`。`fragment()` 仍然负责写 `ALBEDO`、`ROUGHNESS`、`METALLIC`、`AO`、`NORMAL_MAP`、`BACKLIGHT` 等材质属性；`light()` 负责根据当前灯光写 `DIFFUSE_LIGHT`、`SPECULAR_LIGHT`、`ALPHA`。

```glsl
shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.8, 0.45, 0.25, 1.0);
uniform float shadow_steps : hint_range(1.0, 6.0, 1.0) = 3.0;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    BACKLIGHT = base_color.rgb * 0.25;
    ROUGHNESS = 0.7;
    METALLIC = 0.0;
    AO = 1.0;
}

void light() {
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);
    float steps = max(shadow_steps, 1.0);
    float band = ceil(ndotl * steps) / steps;
    vec3 lit = ALBEDO * LIGHT_COLOR * ATTENUATION * band;
    vec3 back = BACKLIGHT * LIGHT_COLOR * ATTENUATION * (1.0 - ndotl);

    DIFFUSE_LIGHT += lit;
    DIFFUSE_LIGHT += back;
}
```

要点：

- `light()` 使用 Godot-style 的光照阶段语义，常用输入包括 `NORMAL`、`LIGHT`、`LIGHT_COLOR`、`ATTENUATION`、`VIEW`、`ALBEDO`、`ROUGHNESS`。
- 写了 `light()` 后，实时灯的直接光照由 `light()` 决定；如果还需要高光或透明度影响，在 `light()` 中显式写 `SPECULAR_LIGHT`、`ALPHA`；不需要高光时可以不写 `SPECULAR_LIGHT`。
- `BACKLIGHT` 在 `light()` 中是只读输入；需要背光参数时，在 `fragment()` 中写 `BACKLIGHT`，再在 `light()` 中读取它。
- 不需要自定义光照时，不写 `light()`，直接使用 PBR、Toon 或 Unlit 模型即可。

---

## 贴图采样

在 shader 中声明 sampler：

```glsl
shader_type spatial;
render_mode shading_model_pbr, cull_back;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear, repeat_enable;
uniform sampler2D orm_map : hint_default_white, filter_linear, repeat_enable;

void fragment() {
    vec4 base = texture(albedo_map, UV);
    vec3 normal_sample = texture(normal_map, UV).rgb;
    vec4 orm = texture(orm_map, UV);

    ALBEDO = base.rgb;
    ALPHA = base.a;
    AO = orm.r;
    ROUGHNESS = orm.g;
    METALLIC = orm.b;
    NORMAL_MAP = normal_sample;
}
```

Lua 中按 shader 源码里的 sampler 名设置贴图：

```lua
local material = Material:new()
if not material:SetSurfaceShader("Shaders/BLGL/MyPBR.shader") then
    print("failed to load surface shader")
    return
end

material:SetSurfaceTexture("albedo_map", cache:GetResource("Texture2D", "Textures/stone_albedo.png"))
material:SetSurfaceTexture("normal_map", cache:GetResource("Texture2D", "Textures/stone_normal.png"))
material:SetSurfaceTexture("orm_map", cache:GetResource("Texture2D", "Textures/stone_orm.png"))
```

关键规则：

- `SetSurfaceTexture()` 的第一个参数为 shader 里声明的 sampler 名。
- `filter_linear`、`filter_linear_mipmap`、`filter_nearest`、`repeat_enable`、`repeat_disable` 等 sampler 属性会自动应用到材质的采样状态。
- 同一张 ORM 贴图只采样一次，再拆通道：`R=AO`、`G=Roughness`、`B=Metallic`。
- v1 建议最多使用 6 张自定义贴图。

---

## 顶点动画

默认 `VERTEX` 是 object space，适合局部形变，会跟随物体自身变换。

```glsl
shader_type spatial;
render_mode shading_model_unlit, cull_disabled;

void vertex() {
    VERTEX.y += sin(TIME + VERTEX.x * 6.0) * 0.15;
}

void fragment() {
    ALBEDO = vec3(0.15, 0.8, 0.35);
    ALPHA = 1.0;
}
```

如果需要世界空间偏移，使用 `world_vertex_coords`：

```glsl
shader_type spatial;
render_mode shading_model_unlit, world_vertex_coords, cull_disabled;

void vertex() {
    VERTEX.y += sin(TIME + VERTEX.x * 4.0) * 0.05;
}

void fragment() {
    ALBEDO = vec3(0.2, 0.7, 1.0);
    ALPHA = 1.0;
}
```

选择建议：

| 需求 | 做法 |
|------|------|
| 物体局部鼓动、草叶摆动 | 默认 `VERTEX` |
| 世界坐标波浪、全局扫描线 | `world_vertex_coords` |
| 只改颜色、不改形状 | 不写 `vertex()` |

---

## vertex 到 fragment 传值

使用 `varying` 把顶点阶段的计算结果传给片元阶段。

```glsl
shader_type spatial;
render_mode shading_model_unlit, cull_disabled;

varying vec3 debug_color;

void vertex() {
    debug_color = vec3(UV, 1.0);
}

void fragment() {
    ALBEDO = debug_color;
    ALPHA = 1.0;
}
```

v1 只建议少量使用 `varying`。如果只是片元阶段能直接算出来的值，不要绕一圈 varying。

---

## 常用输入变量

| 变量 | 阶段 | 说明 |
|------|------|------|
| `UV` | vertex / fragment | 主 UV |
| `COLOR` | vertex / fragment | 顶点色，没有顶点色时通常为白色 |
| `VERTEX` | vertex | 顶点位置；默认 object space，`world_vertex_coords` 时为 world space |
| `NORMAL` | vertex / fragment | 法线 |
| `TIME` | vertex / fragment | 运行时间，适合动画 |
| `CAMERA_POSITION_WORLD` | vertex / fragment | 世界空间相机位置 |
| `SCREEN_UV` | fragment | 屏幕采样 UV，需要配合 `hint_screen_texture` 或 `hint_depth_texture` |
| `VIEWPORT_SIZE` | fragment | 当前视口尺寸 |
| `INV_PROJECTION_MATRIX` | fragment | Godot-compatible 反投影矩阵，用于从 depth 重建 view space |

常用函数：

```glsl
sin(x)
cos(x)
mix(a, b, t)
clamp(x, minValue, maxValue)
smoothstep(edge0, edge1, x)
texture(my_sampler, UV)
normalize(v)
dot(a, b)
```

---

## Uniform 参数

普通 uniform 可以直接在 shader 里给默认值：

```glsl
uniform vec4 tint_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0, 0.1) = 2.0;
```

多数 gameplay 脚本只需要使用默认值。如果需要运行时改参数，直接使用 shader 源码里的 uniform 名：

```lua
material:SetShaderParameter("pulse_speed", Variant(4.0))
material:SetShaderParameter("tint_color", Variant(Color(1.0, 0.2, 0.1, 1.0)))
```

贴图不要用 `SetShaderParameter()`，贴图统一使用：

```lua
material:SetSurfaceTexture("albedo_map", texture)
```

---

## 推荐模板

### 不透明 PBR 贴图材质

```glsl
shader_type spatial;
render_mode shading_model_pbr, cull_back;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear, repeat_enable;
uniform sampler2D orm_map : hint_default_white, filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
    vec4 base = texture(albedo_map, UV) * tint;
    vec3 normal_sample = texture(normal_map, UV).rgb;
    vec4 orm = texture(orm_map, UV);

    ALBEDO = base.rgb;
    ALPHA = 1.0;
    AO = orm.r;
    ROUGHNESS = orm.g;
    METALLIC = orm.b;
    NORMAL_MAP = normal_sample;
}
```

### 无光照特效材质

```glsl
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D mask_map : hint_default_white, filter_linear, repeat_enable;
uniform vec4 color_a : source_color = vec4(0.0, 0.6, 1.0, 0.2);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 0.8);

void fragment() {
    float mask = texture(mask_map, UV).r;
    vec4 color = mix(color_a, color_b, mask);
    ALBEDO = color.rgb;
    ALPHA = color.a;
}
```

---

## 当前不要使用

这些能力不是 gameplay Lua 层当前应使用的 Surface Shader v1 范围：

| 不要使用 | 替代做法 |
|----------|----------|
| `shader_type canvas_item` / `particles` / `sky` / `fog` | 只用 `shader_type spatial` |
| `ALPHA_SCISSOR_THRESHOLD` / `ALPHA_HASH_SCALE` | 暂不支持 alpha clip / alpha hash |
| normal-roughness texture | 暂不作为 v1 gameplay shader 输入 |
| 手写底层 sampler 槽位名 | 用源码 sampler 名 + `SetSurfaceTexture()` |
| 依赖生成后的 `.glsl` 文件路径 | 只引用自己的 `.shader` 文件 |

---

## 调试清单

1. `SetSurfaceShader()` 返回 `false`：检查 `.shader` 路径是否是 `Shaders/BLGL/xxx.shader`，以及文件是否在项目 `assets/` 资源目录下。
2. 贴图没生效：检查 `SetSurfaceTexture("name", texture)` 里的 `"name"` 是否和 shader 中 `uniform sampler2D name` 完全一致。
3. 写了 `ALPHA` 但不透明：检查 `render_mode` 是否包含 `blend_mix`。
4. PBR 看起来太黑：确认场景有 LightGroup 或灯光/Zone；无光照效果请用 `shading_model_unlit`。
5. shader 编译失败：先简化到最小 `ALBEDO` 输出，再逐步加回贴图、uniform 和顶点动画。
