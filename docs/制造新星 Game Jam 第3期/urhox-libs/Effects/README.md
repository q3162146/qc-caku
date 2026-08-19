# Effects Library - 特效工具库

粒子特效、音效和屏幕震动辅助库。

**版本**: v2.0 | **更新**: 2025-11-20

---

## 📚 API 速查

```lua
local Effects = require "Libs.effects.Effects"

-- 粒子特效
Effects.SpawnParticle(scene, parentNode, "Effect.pex", { scale, offset, duration })

-- 音效播放
local sound = Effects.PlaySound(scene, "sound.wav", { gain, frequency, position, autoRemove })
local bgm = Effects.PlaySoundLooped(scene, "music.ogg", { gain, soundType })

-- 音效控制
sound:Stop()
sound:FadeOut(duration)
bgm:FadeIn(duration, targetGain)

-- 屏幕震动
local shake = Effects.CreateScreenShake(cameraNode, intensity, duration)
shake:Update(timeStep)

-- 延迟删除
Effects.RemoveNodeAfter(node, delay)
```

---

## 🚀 快速开始

```lua
local Effects = require "Libs.effects.Effects"

function Start()
    scene_ = Scene()
    -- ...
end

function OnHit(position)
    local node = scene_:CreateChild("Hit")
    node.position2D = position

    -- 粒子(2秒后自动删除)
    Effects.SpawnParticle(scene_, node, "Urho2D/explosion.pex", {
        scale = 0.8,
        duration = 2.0
    })

    -- 音效(播放完自动删除)
    Effects.PlaySound(scene_, "Sounds/Hit.wav", {
        gain = 0.7
    })

    -- 父节点3秒后删除
    Effects.RemoveNodeAfter(node, 3.0)
end
```

---

## 📖 API 详解

### SpawnParticle - 创建粒子特效

```lua
Effects.SpawnParticle(scene, parentNode, effectPath, options)
```

**参数**:
- `scene` (Scene) - 场景对象 **[必需]**
- `parentNode` (Node) - 父节点 **[必需]**
- `effectPath` (string) - 粒子文件路径 (`.pex`)
- `options` (table) - 可选:
  - `scale` (number) - 缩放,默认 0.5
  - `offset` (Vector2) - 位置偏移
  - **`duration` (number) - 持续时间(秒),设置后自动删除**

**返回**: Node

---

### PlaySound - 播放音效(非循环)

```lua
Effects.PlaySound(scene, soundPath, options)
```

**参数**:
- `scene` (Scene) - 场景对象 **[必需]**
- `soundPath` (string) - 音效文件路径
- `options` (table) - 可选:
  - `gain` (number) - 音量 (0.0-1.0)
  - `frequency` (number) - 频率
  - `position` (Vector3) - 3D 音效位置
  - **`autoRemove` (boolean) - 播放完自动删除,默认 `true`**

**返回**: table `{ node, source, Stop(), FadeOut() }`

---

### PlaySoundLooped - 播放循环音效

```lua
Effects.PlaySoundLooped(scene, soundPath, options)
```

**参数**:
- `scene` (Scene) - 场景对象 **[必需]**
- `soundPath` (string) - 音效文件路径
- `options` (table) - 可选:
  - `gain` (number) - 音量
  - `soundType` (SoundType) - 类型,默认 `SOUND_EFFECT`

**返回**: table `{ node, source, Stop(), FadeIn(), FadeOut() }`

---

### 音效句柄方法

```lua
-- 停止并删除
soundHandle:Stop()

-- 淡出(duration, removeAfter)
soundHandle:FadeOut(2.0, true)

-- 淡入(仅循环音效)
bgmHandle:FadeIn(3.0, 0.8)
```

---

### RemoveNodeAfter - 延迟删除节点

```lua
Effects.RemoveNodeAfter(node, delay)
```

**参数**:
- `node` (Node) - 要删除的节点
- `delay` (number) - 延迟时间(秒)

---

### CreateScreenShake - 屏幕震动

```lua
Effects.CreateScreenShake(cameraNode, intensity, duration)
```

**参数**:
- `cameraNode` (Node) - 相机节点
- `intensity` (number) - 强度,默认 0.1
- `duration` (number) - 持续时间,默认 0.5

**返回**: table `{ Update(timeStep) }`

**使用**:
```lua
local shake = Effects.CreateScreenShake(cameraNode, 0.3, 1.0)

function HandleUpdate(eventType, eventData)
    shake:Update(eventData["TimeStep"]:GetFloat())
end
```

---

## 💡 常见用法

### 1. 击中特效

```lua
function OnEnemyHit(enemyNode)
    Effects.SpawnParticle(scene_, enemyNode, "Urho2D/impact.pex", {
        duration = 1.5
    })
    Effects.PlaySound(scene_, "Sounds/Hit.wav", { gain = 0.7 })

    local shake = Effects.CreateScreenShake(cameraNode, 0.2, 0.3)
end
```

### 2. 背景音乐管理

```lua
local bgm = nil

function StartMusic()
    bgm = Effects.PlaySoundLooped(scene_, "Music/BGM.ogg", {
        gain = 0,
        soundType = SOUND_MUSIC
    })
    bgm:FadeIn(2.0, 0.6)
end

function StopMusic()
    if bgm then
        bgm:FadeOut(1.5, true)
        bgm = nil
    end
end
```

### 3. 连击效果

```lua
local comboCount = 0

function OnComboHit()
    comboCount = comboCount + 1

    Effects.PlaySound(scene_, "Sounds/Combo.wav", {
        gain = 0.8,
        frequency = 1.0 + comboCount * 0.1  -- 频率递增
    })
end
```

---

## ⚠️ 重要变更 (v2.0)

### 必须传入 Scene

```lua
-- ✅ v2.0 正确
Effects.PlaySound(scene_, "Click.wav")

-- ❌ v1.0 旧API (不再支持)
Effects.PlaySound("Click.wav")
```

### 返回值统一为句柄

```lua
-- 所有音效函数都返回句柄
local sound = Effects.PlaySound(scene_, "test.wav")
sound:Stop()  -- 使用句柄方法
```

### 自动删除默认开启

- **粒子**: 设置 `duration` 自动删除
- **单次音效**: 默认播放完自动删除
- **循环音效**: 需要手动停止

---

## 🔧 从 v1.0 迁移

| v1.0 | v2.0 |
|------|------|
| `Effects.SpawnParticle(node, path, opts)` | `Effects.SpawnParticle(scene, node, path, opts)` |
| `Effects.PlaySound(path, opts)` | `Effects.PlaySound(scene, path, opts)` |
| `Effects.StopSound(sound)` | `sound:Stop()` |

---

## 📚 相关文档

- [libs 总览](../README.md)
- [EXAMPLES.md](../EXAMPLES.md)
- [TESTING.md](../TESTING.md)

---

**维护者**: UrhoX Team
