# 动画状态机 (AnimationStateMachine)

> **让角色根据移动/跳跃等状态自动切换动画**

---

## 概念速览

- **动画状态机与游戏逻辑是分离的**——它只是一种数据驱动角色动画的机制，不包含任何游戏逻辑（移动、物理、输入等）。游戏逻辑负责计算角色状态，然后把结果（速度、是否着地等）作为参数喂给状态机，状态机只负责据此播放正确的动画。
- **AnimationStateMachine** 组件根据参数自动切换动画状态
- 配置写在 `.fsm` JSON 文件，动画混合配置写在 `.blendspace` JSON 文件
- 参数由 Lua 脚本每帧喂入（`SetFloat` / `SetBool` / `SetTrigger`）
- 节点上必须同时有 **AnimationController** 组件
- **禁止**在同一个节点上同时用 AnimationStateMachine 和 AnimationController 的 `Play`/`PlayExclusive` 等接口直接播放动画，两者会互相干扰导致非预期表现。选择其一：要么用状态机驱动动画，要么用 AnimationController 手动控制

---

## 快速开始

### 最小示例：角色移动 + 跳跃

**1. 创建 BlendSpace1D**（`scripts/FSM/MovementBlendSpace.blendspace`）：

```json
{
    "type": "BlendSpace1D",
    "name": "MovementBlendSpace",
    "parameter": "moveSpeed",
    "points": [
        { "value": 0, "animation": "Idle.ani", "speed": 1.0 },
        { "value": 2, "animation": "Walk.ani", "speed": 1.0 },
        { "value": 5, "animation": "Run.ani", "speed": 1.0 }
    ]
}
```

**2. 创建 FSM**（`scripts/FSM/Character.fsm`）：

```json
{
    "name": "CharacterFSM",
    "defaultBlendTime": 0.2,

    "parameters": {
        "moveSpeed": { "type": "float", "default": 0.0, "min": 0.0, "max": 10.0 },
        "isGrounded": { "type": "bool", "default": true },
        "jump": { "type": "trigger" }
    },

    "layers": [
        {
            "name": "Base",
            "defaultState": "Locomotion",
            "states": {
                "Locomotion": {
                    "blendSpace": "FSM/MovementBlendSpace.blendspace",
                    "loop": true
                },
                "JumpStart": {
                    "animation": "JumpStart.ani",
                    "loop": false,
                    "speed": 1.0,
                    "blendTime": 0.1
                },
                "JumpAir": {
                    "animation": "JumpAir.ani",
                    "loop": true,
                    "speed": 1.0
                },
                "JumpLanding": {
                    "animation": "JumpLanding.ani",
                    "loop": false,
                    "speed": 1.0
                }
            },
            "transitions": [
                { "from": "*", "to": "JumpStart", "condition": "jump", "priority": 10, "blendTime": 0.1 },
                { "from": "JumpStart", "to": "JumpAir", "condition": "animationFinished and not isGrounded", "blendTime": 0.15 },
                { "from": "JumpStart", "to": "Locomotion", "condition": "isGrounded", "blendTime": 0.2 },
                { "from": "Locomotion", "to": "JumpAir", "condition": "not isGrounded", "priority": 5, "blendTime": 0.2 },
                { "from": "JumpAir", "to": "JumpLanding", "condition": "isGrounded and stateTime > 0.5", "priority": 2, "blendTime": 0.1 },
                { "from": "JumpAir", "to": "Locomotion", "condition": "isGrounded", "priority": 1, "blendTime": 0.2 },
                { "from": "JumpLanding", "to": "Locomotion", "condition": "animationFinished or moveSpeed > 0.5", "blendTime": 0.2 }
            ]
        }
    ]
}
```

**3. Lua 驱动代码**：

```lua
-- 获取组件（节点上必须已有 AnimatedModel）
node:GetOrCreateComponent("AnimationController")
local fsm = node:GetOrCreateComponent("AnimationStateMachine")

-- 加载 FSM
local jsonFile = cache:GetResource("JSONFile", "FSM/Character.fsm")
fsm:LoadFromJSONFile(jsonFile)
fsm:Start()

-- 每帧更新参数（在 Update 中）
-- 方式一：使用引擎物理（配合 CharacterComponent，参考 examples/22-third-person-shooter）
local character = node:GetComponent("CharacterComponent")
fsm:SetFloat("moveSpeed", character:GetMoveSpeed())
fsm:SetBool("isGrounded", character:IsOnGround() and not character:IsJumping())
if character:IsJumpStarted() then
    fsm:SetTrigger("jump")
end

-- 方式二：自定义物理（自己维护状态）
fsm:SetFloat("moveSpeed", currentSpeed)
fsm:SetBool("isGrounded", isOnGround)
if jumpPressed then
    fsm:SetTrigger("jump")
end

-- 查询当前状态
local state = fsm:GetCurrentState(0)  -- 层 0
```

---

## .fsm 文件格式

### 顶层结构

```json
{
    "name": "FSM 名称",
    "defaultBlendTime": 0.2,
    "_animationPaths": { },
    "boneMasks": { },
    "parameters": { },
    "layers": [ ]
}
```

| 字段 | 说明 |
|------|------|
| `name` | FSM 名称 |
| `defaultBlendTime` | 默认动画过渡时间（秒） |
| `_animationPaths` | 可选，**纯注释，引擎不解析此字段**。仅供人类阅读，记录 uuid 对应的动画名称，可省略 |
| `boneMasks` | 骨骼遮罩定义（多层 FSM 用） |
| `parameters` | 参数定义 |
| `layers` | 动画层数组 |

### parameters（参数）

参数名完全由开发者自定义，状态机不关心它们的语义。游戏逻辑通过 `SetFloat`/`SetBool`/`SetTrigger` 喂入值，状态机只根据 `transitions` 中的条件表达式评估这些值来决定状态切换——这正是表现与逻辑分离的体现。

```json
"parameters": {
    "moveSpeed":  { "type": "float", "default": 0.0, "min": 0.0, "max": 10.0 },
    "direction":  { "type": "float", "default": 0.0, "min": -180.0, "max": 180.0 },
    "isGrounded": { "type": "bool",  "default": true },
    "weaponType": { "type": "int",   "default": 0, "min": 0, "max": 10 },
    "jump":       { "type": "trigger" }
}
```

| 类型 | 说明 | Lua 设置方式 |
|------|------|-------------|
| `float` | 浮点数，可选 min/max | `fsm:SetFloat("name", value)` |
| `int` | 整数，可选 min/max | `fsm:SetInt("name", value)` |
| `bool` | 布尔值 | `fsm:SetBool("name", value)` |
| `trigger` | 触发器，触发后自动重置 | `fsm:SetTrigger("name")` |

### layers（动画层）

```json
"layers": [
    {
        "name": "Base",
        "defaultState": "Locomotion",
        "boneMask": "UpperBody",
        "weight": 1.0,
        "blendMode": "lerp",
        "states": { },
        "transitions": [ ]
    }
]
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 层名称 |
| `defaultState` | 是 | 初始状态 |
| `boneMask` | 否 | 引用 boneMasks 中定义的遮罩名 |
| `weight` | 否 | 层权重，默认 1.0 |
| `blendMode` | 否 | `"lerp"`（替换，默认）或 `"additive"`（叠加） |

### states（状态）

三种状态类型：

```json
"states": {
    "Locomotion": {
        "blendSpace": "FSM/MovementBlendSpace.blendspace",
        "loop": true
    },
    "JumpStart": {
        "animation": "Animations/JumpStart.ani",
        "loop": false,
        "speed": 1.0,
        "blendTime": 0.1
    },
    "Empty": {
        "empty": true
    }
}
```

| 字段 | 说明 |
|------|------|
| `animation` | 单动画路径（支持 `uuid://` 或相对路径） |
| `blendSpace` | BlendSpace 文件路径 |
| `empty` | 空状态，该层不播放动画 |
| `loop` | 是否循环 |
| `speed` | 播放速度，默认 1.0 |
| `blendTime` | 进入此状态的过渡时间（覆盖 defaultBlendTime） |
| `blendInTime` | 进入过渡时间（更精确控制） |
| `blendOutTime` | 离开过渡时间 |
| `boneMask` | 状态级骨骼遮罩（覆盖层级设置） |
| `events` | 动画事件数组（见下文） |

**动画事件**：

```json
"events": [
    { "name": "FootStep", "time": 0.3 },
    { "name": "AttackHit", "time": 0.5, "normalized": true, "data": { "damage": 10 } }
]
```

| 字段 | 说明 |
|------|------|
| `name` | 事件名 |
| `time` | 触发时间 |
| `normalized` | 可选，true 时 time 为 0-1 归一化值 |
| `data` | 可选，自定义数据 |

### transitions（过渡）

```json
"transitions": [
    {
        "from": "*",
        "to": "JumpStart",
        "condition": "jump",
        "priority": 10,
        "blendTime": 0.1
    }
]
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `from` | 是 | 源状态名，`"*"` 匹配任意状态，也支持数组 `["StateA", "StateB"]` |
| `to` | 是 | 目标状态名 |
| `condition` | 是 | 条件表达式（见下文） |
| `priority` | 否 | 优先级，越高越先评估，默认 0 |
| `blendTime` | 否 | 过渡时间（覆盖 defaultBlendTime） |
| `exitTime` | 否 | 归一化退出时间 (0-1) |

### boneMasks（骨骼遮罩）

用于多层 FSM，让不同层控制不同身体部位：

```json
"boneMasks": {
    "UpperBody": {
        "startBone": "Bip001 Spine"
    },
    "LowerBody": {
        "bones": ["Root", "Bip001", "Bip001 Pelvis", "Bip001 L Thigh", "Bip001 R Thigh"]
    }
}
```

| 方式 | 说明 |
|------|------|
| `startBone` | 指定根骨骼，所有子骨骼自动包含 |
| `bones` | 显式列出骨骼名列表 |

### condition 表达式语法

**运算符**：`and`, `or`, `not`, `>`, `<`, `>=`, `<=`, `==`, `!=`, `()`

**内置变量**（每层独立）：

| 变量 | 类型 | 说明 |
|------|------|------|
| `stateTime` | float | 当前状态已播放时间（秒） |
| `normalizedTime` | float | 当前动画归一化时间（0-1） |
| `animationFinished` | bool | 非循环动画是否播放完毕 |

**函数**：`abs(x)`, `min(x, y)`, `max(x, y)`, `clamp(x, min, max)`

**示例**：

```
"moveSpeed > 0.5"
"animationFinished and isGrounded"
"jump and weaponType == 0"
"isGrounded and stateTime > 0.5"
"not isGrounded and stateTime > 0.1"
"(animationFinished or moveSpeed > 0.5) and not isCrouching"
```

---

## .blendspace 文件格式

### BlendSpace1D — 单参数混合

用于 moveSpeed 驱动 Idle / Walk / Run 之间的平滑过渡：

```json
{
    "type": "BlendSpace1D",
    "name": "MovementBlendSpace",
    "parameter": "moveSpeed",
    "points": [
        { "value": 0, "animation": "uuid://待机动画uuid", "speed": 1.0 },
        { "value": 2, "animation": "uuid://行走动画uuid", "speed": 1.0 },
        { "value": 5, "animation": "uuid://奔跑动画uuid", "speed": 1.0 }
    ]
}
```

| 字段 | 说明 |
|------|------|
| `type` | 固定 `"BlendSpace1D"` |
| `parameter` | 驱动参数名（对应 FSM 的 parameters） |
| `points[].value` | 参数值 |
| `points[].animation` | 动画 uuid（推荐 `uuid://...` 格式） |
| `points[].speed` | 播放速度 |

### BlendSpace2D — 双参数混合

用于 direction + moveSpeed 驱动 8 方向移动动画：

```json
{
    "type": "BlendSpace2D",
    "name": "LocomotionPolar",
    "mode": "polar",
    "parameterX": "direction",
    "parameterY": "moveSpeed",
    "points": [
        { "x": 0.0,    "y": 0.0, "animation": "uuid://待机动画uuid",     "speed": 1.0 },
        { "x": 0.0,    "y": 2.0, "animation": "uuid://前行走uuid",       "speed": 1.0 },
        { "x": 0.0,    "y": 5.0, "animation": "uuid://前奔跑uuid",       "speed": 1.0 },
        { "x": 180.0,  "y": 2.0, "animation": "uuid://后行走uuid",       "speed": 1.0 },
        { "x": 180.0,  "y": 5.0, "animation": "uuid://后奔跑uuid",       "speed": 1.0 },
        { "x": -180.0, "y": 2.0, "animation": "uuid://后行走uuid",       "speed": 1.0 },
        { "x": -180.0, "y": 5.0, "animation": "uuid://后奔跑uuid",       "speed": 1.0 },
        { "x": 90.0,   "y": 2.0, "animation": "uuid://右行走uuid",       "speed": 1.0 },
        { "x": 90.0,   "y": 5.0, "animation": "uuid://右奔跑uuid",       "speed": 1.0 },
        { "x": -90.0,  "y": 2.0, "animation": "uuid://左行走uuid",       "speed": 1.0 },
        { "x": -90.0,  "y": 5.0, "animation": "uuid://左奔跑uuid",       "speed": 1.0 }
    ]
}
```

**mode 类型**：

| mode | 说明 | 适用场景 |
|------|------|---------|
| `polar` | 方向（-180~180 度）+ 速度 | 8 方向移动（最常用） |
| `triangulation` | Delaunay 三角剖分 | 散点分布 |
| `gradient` | 分轴插值 | 十字布局 |

**polar 模式 8 方向布点**：

```
              前 (0°)
              Walk(y=2) / Run(y=5)
              |
  左(-90°) ── Idle(0,0) ── 右(90°)
              |
              后 (±180°)
```

> 注意：后方(180°)和(-180°)使用相同动画，需要同时注册两个点。

---

## Lua API

> **最佳实践**：通过 `.fsm` 配置文件定义状态和过渡，Lua 代码只负责加载 FSM 和喂参数。不建议在 Lua 中用 `AddStateFromPath`/`AddTransition` 等 API 动态构建状态机——配置文件更直观、易维护，也便于复用。

### 加载和启动

```lua
-- 确保节点有 AnimationController
node:GetOrCreateComponent("AnimationController")

-- 创建或获取 AnimationStateMachine
local fsm = node:GetOrCreateComponent("AnimationStateMachine")

-- 从文件加载
local jsonFile = cache:GetResource("JSONFile", "FSM/Character.fsm")
fsm:LoadFromJSONFile(jsonFile)

-- 启动（进入默认状态）
fsm:Start()
```

### 每帧更新参数

```lua
function HandleUpdate(eventType, eventData)
    fsm:SetFloat("moveSpeed", character:GetMoveSpeed())
    fsm:SetBool("isGrounded", character:IsOnGround())

    -- trigger 只在需要时调用（会自动重置）
    if jumpPressed then
        fsm:SetTrigger("jump")
    end
end
```

### 查询状态

```lua
fsm:GetCurrentState(0)          -- 层 0 当前状态名
fsm:IsInState("Locomotion", 0)  -- 是否在某状态
fsm:IsAnimationFinished(0)      -- 当前动画是否播完
fsm:GetStateTime(0)             -- 当前状态已播放秒数
fsm:GetNormalizedTime(0)        -- 归一化时间 0-1
fsm:IsTransitioning(0)          -- 是否正在过渡
fsm:ForceState("Locomotion", 0) -- 强制切换（跳过过渡）
```

### 层权重控制

```lua
fsm:SetLayerWeight(2, 0.5)   -- 按层索引设置权重（层索引从 0 开始）
```

---

## 进阶：多层 FSM

多层 FSM 让不同身体部位同时播放不同动画。

典型架构（参考 `examples/22-third-person-shooter`）：

| 层 | 名称 | boneMask | 用途 |
|----|------|----------|------|
| 0 | Base | 无（全身） | 移动、跳跃 |
| 1 | LowerBody | LowerBody | 持枪时下半身跳跃 |
| 2 | UpperBody | UpperBody | 射击、换弹、近战 |
| 3 | FullBody | 无（全身） | 表情、死亡（最高优先级） |

**关键设计**：
- 不需要播放动画的层用 `"empty": true` 空状态作为默认
- FullBody 层的 die 过渡用 `"from": "*"` + 最高 priority，确保任何状态都能触发
- UpperBody 层切换武器类型时，通过条件表达式 `weaponType == 1` 选择对应动画

---

## 官方模板

`engine-docs/recipes/templates/fsm/` 目录下提供了开箱即用的模板：

| 文件 | 说明 |
|------|------|
| `StandardLocomotion_Template.fsm` | FSM 模板，将 `$PLACEHOLDER$` 替换为实际动画 uuid |
| `MovementBlendSpace1D_Template.blendspace` | 1D 混合空间模板（前后移动） |
| `MovementBlendSpace2D_Polar_Template.blendspace` | 2D Polar 混合空间模板（8 方向移动） |

---

## 常见问题

| 问题 | 解决方案 |
|------|---------|
| 状态不切换 | 检查 condition 表达式是否正确，确认参数每帧更新 |
| 动画不播放 | 确认节点有 AnimationController 组件 |
| 多层动画冲突 | 检查 boneMask 是否正确配置，检查层 weight |
| trigger 不触发 | trigger 触发后自动重置，确保在正确时机调用 SetTrigger |
| BlendSpace 动画抖动 | 检查参数值范围是否与 points 的 value/x/y 匹配 |
