# UrhoX Lua API Reference

API 来源有两处，均位于项目工作区根目录，LSP 自动加载：

- **`.emmylua/`** — 引擎 API 类型定义，每个类一个 `.d.lua`
- **`urhox-libs/`** — 引擎高层库源码（UI、Camera、Platform 等），既是可调用的库也是 API 参考

查 API：优先使用 LSP / MCP 工具查询（hover / goToDefinition / workspaceSymbol，本地开发使用 `maker-lua-lsp` 工具），也可直接读对应文件。

下方列出**部分**常用类名，按模块分类方便定位。

---

## Core — 场景图、引擎生命周期

`Scene` · `Node` · `Component` · `Serializable` · `Animatable` · `Object` · `Context` · `Engine` · `Timer` · `LogicComponent` · `LuaScriptInstance` 等

## Graphics — 渲染、相机、灯光、模型、材质

`Graphics` · `Renderer` · `Camera` · `Light` · `Zone` · `Skybox` · `StaticModel` · `AnimatedModel` · `StaticModelGroup` · `Model` · `Material` · `Technique` · `Texture` · `Texture2D` · `Texture2DArray` · `Texture3D` · `TextureCube` · `Drawable` · `Octree` · `Viewport` · `RenderPath` · `BillboardSet` · `CustomGeometry` · `DecalSet` · `RibbonTrail` · `Terrain` · `TerrainPatch` · `DepthOfField` · `ColorGrading` · `VideoPlayer` 等

## Animation — 骨骼动画、状态机

`Animation` · `AnimationController` · `AnimationState` · `AnimationStateMachine` · `BlendSpace` · `ObjectAnimation` · `ValueAnimation` · `Skeleton` 等

## Graphics 2D — 精灵、瓦片地图

`Sprite2D` · `SpriteSheet2D` · `StaticSprite2D` · `AnimatedSprite2D` · `StretchableSprite2D` · `AnimationSet2D` · `ParticleEffect2D` · `ParticleEmitter2D` · `TileMap2D` · `TileMapLayer2D` · `TmxFile2D` 等

## Physics 3D — 刚体、碰撞、载具

`PhysicsWorld` · `RigidBody` · `CollisionShape` · `CollisionLayer` · `Constraint` · `RaycastVehicle` · `KinematicCharacterController` · `CharacterComponent` 等

## Physics 2D — Box2D

`PhysicsWorld2D` · `RigidBody2D` · `CollisionShape2D` · `CollisionBox2D` · `CollisionCircle2D` · `CollisionEdge2D` · `CollisionChain2D` · `CollisionPolygon2D` · `Constraint2D` · `ConstraintDistance2D` · `ConstraintRevolute2D` · `ConstraintPrismatic2D` · `ConstraintWeld2D` · `ConstraintWheel2D` 等

## UI

游戏 UI 使用 `urhox-libs/UI`（Yoga Flexbox + NanoVG，40+ 控件），详见 `engine-docs/recipes/ui.md` 和 `urhox-libs/UI/` 源码。

`.emmylua/` 中的原生 Urho3D C++ UI 组件（`UIElement`、`Button`、`Text` 等）**已废弃，不建议使用**，仅供向后兼容。

## Audio

`Audio` · `Sound` · `SoundSource` · `SoundSource3D` · `SoundListener`

## Particles

`ParticleEffect` · `ParticleEmitter`

## Input

`Input` · `Controls` 等

## Navigation — 寻路

`NavigationMesh` · `DynamicNavigationMesh` · `CrowdAgent` · `CrowdManager` · `NavArea` · `Navigable` · `Obstacle` · `OffMeshConnection`

## IK

`IKSolver` · `IKEffector` · `IKConstraint`

## Network — 联机、HTTP

`Network` · `Connection` · `NetworkPriority` · `HttpClient` · `HttpManager` · `HttpRequest` · `HttpResponse` 等

## Resource — 资源管理

`Resource` · `ResourceCache` · `Image` · `Font` · `Localization` · `DownloadManager` 等

## IO — 文件、序列化

`File` · `FileSystem` · `Deserializer` · `Serializer` · `VectorBuffer` · `JSONFile` · `JSONValue` · `XMLFile` · `XMLElement` 等

## Math

`Vector2` · `Vector3` · `Vector4` · `Matrix3` · `Matrix3x4` · `Matrix4` · `Quaternion` · `Color` · `BoundingBox` · `Sphere` · `Plane` · `Ray` · `Rect` · `Spline` · `SplinePath` · `Random` 等

## NanoVG — 矢量绘图

`NanoVG` · `NanoVG.manual`

## Yoga — Flexbox 布局

`YogaLayout` · `YogaLayout.manual`

## Cloud / Score — 云变量、排行榜

`ClientCloud` · `ServerCloud` · `Score`

## Scene Extension — 大世界分区

`WorldPartition` · `WorldPartitionCell`

## Debug

`RuntimeDebugger` · `DebugHud` · `DebugRenderer` · `Console` · `Log` 等

## Utilities

`StringHash` · `Variant` · `Coroutine` 等

## Globals / Events — 全局对象、事件定义（常用）

全局对象（`cache`、`input`、`renderer` 等）定义在各自类的 `.d.lua` 底部，详见 [globals.md](globals.md)。`Events`（所有事件类型及其字段定义，编写事件回调必查）。

---

以上为部分常用类。未列出的 `.d.lua` 文件（`*LuaAPI` 全局注册桩、`*Enums`/`*Defs` 枚举常量、内部辅助类型等）由 LSP 自动消费，通常不需要手动查阅。
