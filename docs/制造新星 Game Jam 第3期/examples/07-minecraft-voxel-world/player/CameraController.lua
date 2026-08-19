-- ====================================================================
-- player/CameraController.lua
-- 相机控制器 - 第一人称/第三人称视角切换
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")

---@class CameraController
---@field player Player
---@field world World
---@field scene Scene
---@field firstPersonCameraNode Node
---@field firstPersonCamera Camera
---@field thirdPersonHeight number
---@field thirdPersonMinDistance number
---@field transitionSpeed number
local CameraController = {}
CameraController.__index = CameraController

-- 视角模式枚举
CameraController.ViewMode = {
    FIRST_PERSON = 1,       -- 第一人称
    THIRD_PERSON_BACK = 2,  -- 第三人称背后
    THIRD_PERSON_FRONT = 3  -- 第三人称正面（自拍视角）
}

---创建相机控制器
---@param player table Player实例
---@param world table World实例（用于碰撞检测）
---@return table CameraController实例
function CameraController.new(player, world)
    local self = setmetatable({}, CameraController)
    
    self.player = player
    self.world = world
    self.scene = player.scene
    
    -- 当前视角模式
    self.viewMode = CameraController.ViewMode.FIRST_PERSON
    
    -- 第一人称相机（已存在）
    self.firstPersonCamera = player:getCamera()
    self.firstPersonCameraNode = player:getCameraNode()
    
    -- 第三人称相机
    self.thirdPersonCameraNode = nil
    self.thirdPersonCamera = nil
    self.thirdPersonPivot = nil  -- 旋转轴心
    
    -- 第三人称相机参数
    self.thirdPersonDistance = Config.Camera.THIRD_PERSON_DISTANCE or 5.0
    self.thirdPersonHeight = Config.Camera.THIRD_PERSON_HEIGHT or 1.0
    self.thirdPersonMinDistance = 1.5  -- 最小距离（碰撞后）
    self.currentDistance = self.thirdPersonDistance  -- 当前实际距离
    
    -- 相机平滑过渡
    self.transitionSpeed = 10.0
    
    self:createThirdPersonCamera()
    
    return self
end

---创建第三人称相机
function CameraController:createThirdPersonCamera()
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local PLAYER_HEIGHT = Config.Player.HEIGHT
    
    -- ============================================
    -- Minecraft 风格第三人称相机结构：
    -- Player.node
    --   └── ThirdPersonPivot (位于眼睛高度，应用 pitch/yaw 旋转)
    --         └── ThirdPersonCamera (相对位置：后方+上方)
    -- 
    -- 相机继承 pivot 的旋转 → 与玩家视线方向一致 → 准星准确
    -- ============================================
    
    -- 创建第三人称相机轴心节点（跟随玩家位置，响应pitch/yaw旋转）
    self.thirdPersonPivot = self.player.node:CreateChild("ThirdPersonPivot")
    -- 轴心在玩家眼睛高度
    self.thirdPersonPivot.position = Vector3(0, (PLAYER_HEIGHT - 0.2) * BLOCK_SIZE, 0)
    
    -- 创建相机节点（在轴心后方+上方）
    self.thirdPersonCameraNode = self.thirdPersonPivot:CreateChild("ThirdPersonCamera")
    -- 加载景深（移动端不开启，节省性能）
    local platform = GetPlatform()
    if platform ~= "Android" and platform ~= "iOS" then
        local xmlFile = cache:GetResource("XMLFile", "EngineRes/PostProcess/DOFPrefab.xml")
        self.thirdPersonCameraNode:LoadXML(xmlFile:GetRoot())
    end
    -- 初始位置：后方 + 上方偏移，让角色在屏幕下方
    self.thirdPersonCameraNode.position = Vector3(0, self.thirdPersonHeight, -self.thirdPersonDistance) * BLOCK_SIZE
    -- 不调用 LookAt，保持局部旋转为单位四元数，继承父节点旋转
    self.thirdPersonCameraNode.rotation = Quaternion()
    
    -- 创建相机组件
    self.thirdPersonCamera = self.thirdPersonCameraNode:CreateComponent("Camera", LOCAL)
    self.thirdPersonCamera.farClip = Config.Camera.FAR_CLIP
    self.thirdPersonCamera.fov = Config.Camera.FOV
    
    -- 初始状态禁用第三人称相机节点
    self.thirdPersonPivot.enabled = false
    
    print("[CameraController] Third person camera created")
end

---切换到下一个视角模式
---@return number 新的视角模式
function CameraController:toggleViewMode()
    local ViewMode = CameraController.ViewMode
    
    if self.viewMode == ViewMode.FIRST_PERSON then
        self.viewMode = ViewMode.THIRD_PERSON_BACK
    elseif self.viewMode == ViewMode.THIRD_PERSON_BACK then
        self.viewMode = ViewMode.THIRD_PERSON_FRONT
    else
        self.viewMode = ViewMode.FIRST_PERSON
    end
    
    self:applyViewMode()
    
    local modeNames = {
        [ViewMode.FIRST_PERSON] = "第一人称",
        [ViewMode.THIRD_PERSON_BACK] = "第三人称(背后)",
        [ViewMode.THIRD_PERSON_FRONT] = "第三人称(正面)"
    }
    print("[CameraController] View mode changed to:", modeNames[self.viewMode])
    
    return self.viewMode
end

---设置视角模式
---@param mode number 视角模式
function CameraController:setViewMode(mode)
    self.viewMode = mode
    self:applyViewMode()
end

---应用当前视角模式
function CameraController:applyViewMode()
    local ViewMode = CameraController.ViewMode
    local player = self.player
    
    if self.viewMode == ViewMode.FIRST_PERSON then
        -- 第一人称模式
        self.firstPersonCameraNode.enabled = true
        self.thirdPersonPivot.enabled = false
        
        -- 显示第一人称手臂，隐藏身体
        if player.firstPersonArm then
            player.firstPersonArm:setVisible(true)
        end
        if player.body then
            player.body:setVisible(false)
        end
        
        -- 设置视口使用第一人称相机
        self:setActiveCamera(self.firstPersonCamera)
        
    else
        -- 第三人称模式
        self.firstPersonCameraNode.enabled = true  -- 保持第一人称节点用于视角计算
        self.thirdPersonPivot.enabled = true
        
        -- 隐藏第一人称手臂，显示身体
        if player.firstPersonArm then
            player.firstPersonArm:setVisible(false)
        end
        if player.body then
            player.body:setVisible(true)
            -- 第三人称背后时可以显示头部
            player.body:setHeadVisible(true)
        end
        
        -- 设置视口使用第三人称相机
        self:setActiveCamera(self.thirdPersonCamera)
    end
end

---设置活动相机
---@param camera Camera 相机组件
function CameraController:setActiveCamera(camera)
    local viewport = Viewport:new(self.scene, camera)
    renderer:SetViewport(0, viewport)
end

---获取当前活动相机
---@return Camera 当前相机
function CameraController:getActiveCamera()
    local ViewMode = CameraController.ViewMode
    if self.viewMode == ViewMode.FIRST_PERSON then
        return self.firstPersonCamera
    else
        return self.thirdPersonCamera
    end
end

---获取当前视角模式
---@return number 视角模式
function CameraController:getViewMode()
    return self.viewMode
end

---是否为第一人称模式
---@return boolean
function CameraController:isFirstPerson()
    return self.viewMode == CameraController.ViewMode.FIRST_PERSON
end

---更新第三人称相机（每帧调用）
---@param timeStep number 时间步长
function CameraController:update(timeStep)
    local ViewMode = CameraController.ViewMode
    
    if self.viewMode == ViewMode.FIRST_PERSON then
        return  -- 第一人称不需要额外处理
    end
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local player = self.player
    
    -- ============================================
    -- Minecraft 风格第三人称相机：
    -- 1. 相机朝向 = 玩家视线方向（继承 pivot 旋转）
    -- 2. 相机位置 = 玩家后方 + 上方偏移
    -- 3. 不需要 LookAt，准星自动准确
    -- ============================================
    
    -- 更新轴心旋转（跟随玩家视角）
    local pitch = player:getPitch()
    local yaw = player:getYaw()
    
    -- 第三人称正面时，相机在玩家前面
    if self.viewMode == ViewMode.THIRD_PERSON_FRONT then
        yaw = yaw + 180
    end
    
    self.thirdPersonPivot.rotation = Quaternion(pitch, yaw, 0)
    
    -- 计算目标相机距离
    local targetDistance = self.thirdPersonDistance
    
    -- 碰撞检测：防止相机穿墙
    if self.world and Config.Camera.THIRD_PERSON_COLLISION ~= false then
        local direction = self.thirdPersonPivot.worldRotation * Vector3(0, 0, -1)
        local pivotPos = self.thirdPersonPivot.worldPosition
        
        -- 简单的射线检测
        local hitDistance = self:raycastDistance(pivotPos, direction, targetDistance * BLOCK_SIZE)
        if hitDistance then
            -- 碰到障碍物，缩短距离
            local newDistance = (hitDistance / BLOCK_SIZE) - 0.3  -- 留一点余量
            targetDistance = math.max(self.thirdPersonMinDistance, newDistance)
        end
    end
    
    -- 平滑过渡距离
    self.currentDistance = self.currentDistance + (targetDistance - self.currentDistance) * timeStep * self.transitionSpeed
    
    -- ============================================
    -- 相机位置（相对于 pivot 的局部坐标）：
    -- - Z 负方向 = 后方（玩家背后）
    -- - Y 正方向 = 上方（让角色在屏幕下方）
    -- ============================================
    local heightOffset = self.thirdPersonHeight * BLOCK_SIZE  -- 相机比 pivot 高多少
    local distance = self.currentDistance * BLOCK_SIZE        -- 相机在 pivot 后方的距离
    
    self.thirdPersonCameraNode.position = Vector3(0, heightOffset, -distance)
    
    -- ============================================
    -- 关键：让相机向下倾斜，使视线穿过 pivot 位置
    -- 
    --     相机 C
    --          ╲
    --           ╲ pitchOffset (向下倾斜)
    --            ╲
    --     Pivot P ────→ 相机视线 = 玩家视线
    --
    -- pitchOffset = arctan(heightOffset / distance)
    -- ============================================
    local pitchOffset = 0
    if distance > 0.1 then  -- 避免除零
        pitchOffset = math.deg(math.atan(heightOffset / distance))
    end
    
    -- 应用局部旋转：向下倾斜 pitchOffset 度
    -- 负值表示向下看（pitch 正值是向上）
    self.thirdPersonCameraNode.rotation = Quaternion(-pitchOffset, 0, 0)
end

---射线检测距离
---@param origin Vector3 起点
---@param direction Vector3 方向
---@param maxDistance number 最大距离
---@return number|nil 碰撞距离，无碰撞返回nil
function CameraController:raycastDistance(origin, direction, maxDistance)
    if not self.world then
        return nil
    end
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local stepSize = BLOCK_SIZE * 0.5  -- 每步检测0.5个方块
    local steps = math.ceil(maxDistance / stepSize)
    
    for i = 1, steps do
        local distance = i * stepSize
        if distance > maxDistance then
            break
        end
        
        local checkPos = origin + direction * distance
        local bx, by, bz = self.world:worldToBlock(checkPos)
        local blockType = self.world:getBlock(bx, by, bz)
        
        if Blocks:isSolid(blockType) then
            return distance
        end
    end
    
    return nil
end

---获取第三人称相机距离
---@return number 距离
function CameraController:getThirdPersonDistance()
    return self.thirdPersonDistance
end

---设置第三人称相机距离
---@param distance number 距离
function CameraController:setThirdPersonDistance(distance)
    self.thirdPersonDistance = math.max(2.0, math.min(10.0, distance))
end

---滚轮调整距离
---@param delta number 滚轮增量（正数放大，负数缩小）
function CameraController:adjustDistance(delta)
    self.thirdPersonDistance = self.thirdPersonDistance - delta * 0.5
    self.thirdPersonDistance = math.max(2.0, math.min(10.0, self.thirdPersonDistance))
end

---销毁
function CameraController:destroy()
    if self.thirdPersonPivot then
        self.thirdPersonPivot:Remove()
        self.thirdPersonPivot = nil
    end
    self.thirdPersonCameraNode = nil
    self.thirdPersonCamera = nil
    print("[CameraController] Camera controller destroyed")
end

return CameraController

