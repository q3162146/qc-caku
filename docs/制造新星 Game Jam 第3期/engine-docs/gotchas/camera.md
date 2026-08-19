# 相机系统陷阱 (Camera Gotchas)

本文档记录相机系统相关的已验证陷阱。

> ⚠️ **重要原则**：只记录确定性遇到的问题，不要添加未验证的"常识"！

---

## 📌 基础概念

```lua
-- camera 是 Camera 组件，通过节点获取
local cameraNode = scene_:CreateChild("Camera")
local camera = cameraNode:CreateComponent("Camera")

-- orthoSize 是 Camera 组件的属性（正交投影视野高度）
camera.orthographic = true  -- 启用正交投影
camera.orthoSize = 10.0     -- 设置视野高度
```

---

## 📋 问题列表

### 1. ⚠️ orthoSize 代表视野全高度，非半高度 ✅ 已验证

**问题描述**：正交相机的 `orthoSize` 参数代表**视野的全高度**，但引擎内部使用 `orthoSize * 0.5` 作为半高度参与计算。

**症状**：
- 手动计算屏幕到世界坐标转换时，结果与 `GetScreenRay` 有 2x 误差
- 缩放补偿量只有预期的一半，导致锚点漂移

**引擎内部实现**（来自 `Camera.cpp` 第 960 行）：
```cpp
float h = (1.0f / (orthoSize_ * 0.5f)) * zoom_;
```

**正确公式**：
```lua
-- 屏幕 NDC 到视图空间（乘以 0.5）
local viewX = ndcX * aspect * orthoSize * 0.5
local viewY = ndcY * orthoSize * 0.5
```

---

### 2. ⚠️ GetScreenRay 不使用缓存 ✅ 已验证

`Camera:GetScreenRay()` 每次调用都会基于当前相机状态实时计算。修改 `camera.orthoSize` 后立即调用即可获得正确结果，无需 `MarkDirty()` 或等待下一帧。

---

### 3. 📐 屏幕到世界坐标转换（推荐方案）

```lua
local function ScreenToWorld(screenX, screenY)
    local normalizedX = screenX / graphics.width
    local normalizedY = screenY / graphics.height
    local ray = camera:GetScreenRay(normalizedX, normalizedY)
    
    -- 与 y=0 平面相交
    if math.abs(ray.direction.y) < 0.001 then return nil end
    local t = -ray.origin.y / ray.direction.y
    if t < 0 then return nil end
    
    return Vector3(
        ray.origin.x + ray.direction.x * t,
        0,
        ray.origin.z + ray.direction.z * t
    )
end
```

---

### 4. 📐 缩放到鼠标位置的补偿公式

**核心原理**：缩放前后，鼠标指向的世界坐标保持不变

```lua
local function CalcZoomCompensation(mouseX, mouseY, oldOrthoSize, newOrthoSize)
    local aspect = graphics.width / graphics.height
    local ndcX = (mouseX / graphics.width) * 2 - 1
    local ndcY = 1 - (mouseY / graphics.height) * 2
    local deltaOrtho = oldOrthoSize - newOrthoSize
    
    -- 相机基向量（世界空间，cameraNode 为相机所在节点）
    local camRight = cameraNode.worldRight
    local camUp = cameraNode.worldUp
    local camForward = cameraNode.worldDirection

    -- 乘以 0.5（引擎使用 orthoSize * 0.5 作为半视野）
    local viewDeltaX = ndcX * aspect * deltaOrtho * 0.5
    local viewDeltaY = ndcY * deltaOrtho * 0.5
    
    -- 转换到世界空间（沿相机 right 和 up 方向）
    local offsetX = camRight.x * viewDeltaX + camUp.x * viewDeltaY
    local offsetY = camRight.y * viewDeltaX + camUp.y * viewDeltaY
    local offsetZ = camRight.z * viewDeltaX + camUp.z * viewDeltaY
    
    -- 射线与 y=0 平面相交的补偿
    if math.abs(camForward.y) > 0.001 then
        local t = -offsetY / camForward.y
        offsetX = offsetX + camForward.x * t
        offsetZ = offsetZ + camForward.z * t
    end
    
    return offsetX, offsetZ
end

-- 使用
local deltaX, deltaZ = CalcZoomCompensation(mouseX, mouseY, oldOrthoSize, newOrthoSize)
local camPos = cameraNode.position
cameraNode.position = Vector3(camPos.x + deltaX, camPos.y, camPos.z + deltaZ)
camera.orthoSize = newOrthoSize
```

---

## 📅 更新日志

| 日期 | 内容 | 验证来源 |
|------|------|---------|
| 2026-02-05 | orthoSize 的 0.5 因子、GetScreenRay 无缓存、缩放补偿公式 | 等距视角项目缩放补偿调试 |

---

**当前状态**：2 个已验证陷阱（#1 orthoSize、#2 GetScreenRay；#3/#4 为坐标换算参考方案）
