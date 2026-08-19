# UrhoX Lua Development Documentation

AI coding assistant reference for UrhoX Lua game development.

---

## Core Documentation

### [gotchas/](gotchas/index.md) ⚠️
常见陷阱与注意事项 - **只记录实际遇到并验证过的问题**（当前 7 个）。
- [物理系统](gotchas/physics.md)：Rolling Friction 不兼容、Collision Margin 过大
- [相机系统](gotchas/camera.md)：orthoSize 的 0.5 因子、GetScreenRay 无缓存、正交投影公式

### [API Reference](api/index.md)
Lua 5.4 API 模块文档，详细签名由 `.emmylua/` 接管。

**Quick links**:
- [Core](api/core.md) - Scene, Node, Component
- [Graphics](api/graphics.md) - StaticModel, Camera, Light, Material
- [Physics](api/physics.md) - RigidBody, CollisionShape
- [Physics 2D](api/physics-2d.md) - RigidBody2D, CollisionShape2D
- **UI → [recipes/ui.md](recipes/ui.md)**（urhox-libs/UI：Yoga + NanoVG，40+ 控件）
- [Audio](api/audio.md) - Sound, SoundSource
- [Input](api/input.md) - Keyboard, Mouse, Touch
- [Math](api/math.md) - Vector3, Quaternion, Color
- [Enums](api/enums.md) - All enumerations
- [Globals](api/globals.md) - Global functions and properties

---

## Recipes (Solutions)

### Ready
- [recipes/ui.md](recipes/ui.md) - **UI 开发指南（Yoga + NanoVG，40+ 控件）** ⭐
- [recipes/materials.md](recipes/materials.md) - 材质列表和参数
- [recipes/rendering.md](recipes/rendering.md) - 渲染配置（灯光组、天空盒/天空球、后效开关）
- [recipes/nanovg_bloom_glow_guide.md](recipes/nanovg_bloom_glow_guide.md) - NanoVG Bloom 发光特效
- [recipes/procedural-lua-headless.md](recipes/procedural-lua-headless.md) - 程序化 / 离线 Lua（用引擎跑一段脚本然后退出，写法搭配 `run-lua-headless` skill）

---

## Keyword Index

| Need | File |
|------|------|
| **常见陷阱/坑** | **gotchas/index.md** |
| API reference | api/index.md |
| Create scene | api/core.md |
| Add model | api/graphics.md |
| Camera | api/graphics.md |
| Lighting | api/graphics.md |
| Physics (3D) | api/physics.md |
| Physics (2D) | api/physics-2d.md |
| Collision | api/physics.md |
| **UI system (Yoga + NanoVG)** | **recipes/ui.md** |
| Audio | api/audio.md |
| Input | api/input.md |
| Math types | api/math.md |
| Enumerations | api/enums.md |
| Global functions | api/globals.md |
| **材质列表** | **recipes/materials.md** |
| **渲染/灯光组/天空盒/天空球** | **recipes/rendering.md** |
| **瓦片地形生成/加载** | **recipes/tile-terrain-guide.md** |

---

**Version**: v0.1.0-alpha  
**Status**: Core framework ready, content in development
