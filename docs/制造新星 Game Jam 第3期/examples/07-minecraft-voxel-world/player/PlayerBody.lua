-- ====================================================================
-- player/PlayerBody.lua
-- 玩家身体模型 - Minecraft Steve 风格方块人
-- 用于第三人称视角和联机时其他玩家可见
-- ====================================================================

local Config = require("config.GameConfig")

---@class PlayerBody
---@field player Player
---@field playerNode Node
---@field swingArmDuration number
---@field swingArmMaxAngle number
local PlayerBody = {}
PlayerBody.__index = PlayerBody

-- 身体颜色配置（Minecraft Steve 风格）
local SKIN_COLOR = Color(0.91, 0.71, 0.55)      -- 皮肤色
local SHIRT_COLOR = Color(0.2, 0.7, 0.9)        -- 青色衬衫
local PANTS_COLOR = Color(0.2, 0.2, 0.6)        -- 深蓝色裤子
local SHOES_COLOR = Color(0.3, 0.3, 0.3)        -- 深灰色鞋子
local HAIR_COLOR = Color(0.28, 0.18, 0.10)     -- 深棕色头发

-- 身体部位尺寸配置（方块单位，基于 Minecraft 像素比例）
-- Minecraft Steve: 头 8x8x8, 躯干 8x12x4, 手臂 4x12x4, 腿 4x12x4
-- 换算为方块单位（1方块 = 16像素）
-- 注意：使用普通 table 而非 Vector3，避免 Lua 绑定的算术运算问题
local BODY_PARTS = {
    head = {
        size = {0.5, 0.5, 0.5},           -- 8/16 = 0.5
        offset = {0, 1.5, 0},             -- 头顶在1.8高度，头中心在1.5
        color = SKIN_COLOR
    },
    torso = {
        size = {0.5, 0.75, 0.25},         -- 宽8, 高12, 厚4
        offset = {0, 0.875, 0},           -- 躯干中心
        color = SHIRT_COLOR
    },
    armLeft = {
        size = {0.25, 0.75, 0.25},        -- 宽4, 高12, 厚4
        offset = {-0.375, 0.875, 0},      -- 左手臂
        pivotOffset = {0, 0.375, 0},      -- 旋转轴心在肩膀
        color = SHIRT_COLOR
    },
    armRight = {
        size = {0.25, 0.75, 0.25},
        offset = {0.375, 0.875, 0},       -- 右手臂
        pivotOffset = {0, 0.375, 0},
        color = SHIRT_COLOR
    },
    legLeft = {
        size = {0.22, 0.75, 0.22},        -- 稍细避免与躯干z-fighting
        offset = {-0.12, 0.375, 0},       -- 左腿（稍微靠内）
        pivotOffset = {0, 0.375, 0},      -- 旋转轴心在胯部
        color = PANTS_COLOR
    },
    legRight = {
        size = {0.22, 0.75, 0.22},        -- 稍细避免与躯干z-fighting
        offset = {0.12, 0.375, 0},        -- 右腿（稍微靠内）
        pivotOffset = {0, 0.375, 0},
        color = PANTS_COLOR
    }
}

---创建玩家身体
---@param player table Player实例
---@return table PlayerBody实例
function PlayerBody.new(player)
    local self = setmetatable({}, PlayerBody)
    
    self.player = player
    self.scene = player.scene
    self.playerNode = player.node
    
    -- 身体部件节点
    self.bodyNode = nil
    self.parts = {}
    self.pivots = {}  -- 用于动画的旋转轴心节点
    
    -- 可见性状态
    self.visible = true
    self.headVisible = true
    
    -- 动画状态
    self.walkTime = 0
    self.isWalking = false
    self.lastPosition = nil  -- 上一帧位置（用于远程玩家速度检测）
    
    -- 挥臂动画状态
    self.swingArmTime = 0           -- 挥臂动画进度 [0, 1]
    self.isSwingingArm = false      -- 是否正在挥臂
    self.swingArmDuration = 0.15    -- 挥臂动画持续时间（秒）- 更快
    self.swingArmMaxAngle = 90      -- 挥臂最大角度
    
    self:createBody()
    
    return self
end

---创建身体几何体
function PlayerBody:createBody()
    local BLOCK_SIZE = Config.World.BLOCK_SIZE

    -- 判断是否需要 LOCAL 模式（联网模式下使用 LOCAL 避免与服务器冲突）
    local mode = IsNetworkMode() and LOCAL or REPLICATED

    -- 创建身体根节点（挂载在玩家节点下）
    self.bodyNode = self.playerNode:CreateChild("PlayerBody", mode)
    self.bodyNode.position = Vector3(0, 0, 0)

    -- 创建各个身体部位
    for partName, partConfig in pairs(BODY_PARTS) do
        local partNode
        local pivotNode = nil

        -- 从 table 创建 Vector3
        local offset = partConfig.offset
        local size = partConfig.size

        -- 如果有旋转轴心（手臂和腿需要动画）
        if partConfig.pivotOffset then
            local pivotOff = partConfig.pivotOffset

            -- 创建轴心节点
            pivotNode = self.bodyNode:CreateChild(partName .. "_pivot", mode)
            -- 轴心位置 = offset + pivotOffset
            pivotNode.position = Vector3(
                (offset[1] + pivotOff[1]) * BLOCK_SIZE,
                (offset[2] + pivotOff[2]) * BLOCK_SIZE,
                (offset[3] + pivotOff[3]) * BLOCK_SIZE
            )
            self.pivots[partName] = pivotNode

            -- 部件节点挂载在轴心下
            partNode = pivotNode:CreateChild(partName, mode)
            -- 部件相对轴心的偏移 = -pivotOffset
            partNode.position = Vector3(
                -pivotOff[1] * BLOCK_SIZE,
                -pivotOff[2] * BLOCK_SIZE,
                -pivotOff[3] * BLOCK_SIZE
            )
        else
            -- 直接挂载在身体节点下
            partNode = self.bodyNode:CreateChild(partName, mode)
            partNode.position = Vector3(
                offset[1] * BLOCK_SIZE,
                offset[2] * BLOCK_SIZE,
                offset[3] * BLOCK_SIZE
            )
        end

        -- 设置缩放
        partNode.scale = Vector3(
            size[1] * BLOCK_SIZE,
            size[2] * BLOCK_SIZE,
            size[3] * BLOCK_SIZE
        )

        -- 创建模型组件
        local model = partNode:CreateComponent("StaticModel", mode)
        model.model = cache:GetResource("Model", "Models/Box.mdl")
        model.material = self:createSolidMaterial(partConfig.color)

        self.parts[partName] = {
            node = partNode,
            model = model,
            config = partConfig
        }
    end
    
    -- 添加头部细节（眼睛、嘴巴等可选）
    self:addHeadDetails()
    
    print("[PlayerBody] Player body created with", self:countParts(), "parts")
end

---添加头部细节（眼睛、眉毛、鼻子、嘴巴）
---Minecraft Steve 风格像素脸
---头部 8x8 像素，1像素 = 0.0625 单位（在 -0.5 到 +0.5 范围内）
function PlayerBody:addHeadDetails()
    local headNode = self.parts.head.node

    -- 判断是否需要 LOCAL 模式（联网模式下使用 LOCAL 避免与服务器冲突）
    local mode = IsNetworkMode() and LOCAL or REPLICATED

    -- ============================================
    -- 像素单位（8x8 头 = 1.0 单位宽高）
    -- 1 像素 = 1/8 = 0.125 单位
    -- ============================================
    local PX = 0.125  -- 1像素
    local FACE_Z = 0.505  -- 略微突出避免 z-fighting
    local DETAIL_THICKNESS = 0.02

    -- 颜色定义
    local WHITE = Color(1, 1, 1)
    local PUPIL_COLOR = Color(0.2, 0.12, 0.08)  -- 深棕色瞳孔
    local EYEBROW_COLOR = Color(0.25, 0.15, 0.08)  -- 深棕色眉毛
    local NOSE_COLOR = Color(0.82, 0.62, 0.48)  -- 比皮肤稍深的鼻子
    local MOUTH_COLOR = Color(0.45, 0.25, 0.18)  -- 嘴巴颜色

    -- ============================================
    -- 眉毛（让表情更生动）
    -- 位置：眼睛上方，各2像素宽
    -- ============================================
    local BROW_Y = 0.22  -- 眉毛Y位置
    local BROW_WIDTH = PX * 2.5
    local BROW_HEIGHT = PX * 0.8
    local BROW_SPACING = PX * 1.8  -- 眉毛中心距

    local leftBrow = headNode:CreateChild("LeftBrow", mode)
    leftBrow.position = Vector3(-BROW_SPACING, BROW_Y, FACE_Z)
    leftBrow.scale = Vector3(BROW_WIDTH, BROW_HEIGHT, DETAIL_THICKNESS)
    local leftBrowModel = leftBrow:CreateComponent("StaticModel", mode)
    leftBrowModel.model = cache:GetResource("Model", "Models/Box.mdl")
    leftBrowModel.material = self:createSolidMaterial(EYEBROW_COLOR)

    local rightBrow = headNode:CreateChild("RightBrow", mode)
    rightBrow.position = Vector3(BROW_SPACING, BROW_Y, FACE_Z)
    rightBrow.scale = Vector3(BROW_WIDTH, BROW_HEIGHT, DETAIL_THICKNESS)
    local rightBrowModel = rightBrow:CreateComponent("StaticModel", mode)
    rightBrowModel.model = cache:GetResource("Model", "Models/Box.mdl")
    rightBrowModel.material = self:createSolidMaterial(EYEBROW_COLOR)

    -- ============================================
    -- 眼睛（Minecraft Steve 风格）
    -- 眼白 2x1 像素，瞳孔 1x1 像素居右
    -- ============================================
    local EYE_Y = 0.08  -- 眼睛Y位置
    local EYE_WIDTH = PX * 2.2  -- 眼白宽度
    local EYE_HEIGHT = PX * 1.2  -- 眼白高度
    local EYE_SPACING = PX * 1.8  -- 眼睛中心距

    -- 左眼眼白
    local leftEye = headNode:CreateChild("LeftEye", mode)
    leftEye.position = Vector3(-EYE_SPACING, EYE_Y, FACE_Z)
    leftEye.scale = Vector3(EYE_WIDTH, EYE_HEIGHT, DETAIL_THICKNESS)
    local leftEyeModel = leftEye:CreateComponent("StaticModel", mode)
    leftEyeModel.model = cache:GetResource("Model", "Models/Box.mdl")
    leftEyeModel.material = self:createSolidMaterial(WHITE)

    -- 左眼瞳孔（偏向鼻子方向，即右侧）
    local PUPIL_SIZE = PX * 1.0
    local leftPupil = headNode:CreateChild("LeftPupil", mode)
    leftPupil.position = Vector3(-EYE_SPACING + PX * 0.4, EYE_Y, FACE_Z + 0.01)
    leftPupil.scale = Vector3(PUPIL_SIZE, PUPIL_SIZE, DETAIL_THICKNESS)
    local leftPupilModel = leftPupil:CreateComponent("StaticModel", mode)
    leftPupilModel.model = cache:GetResource("Model", "Models/Box.mdl")
    leftPupilModel.material = self:createSolidMaterial(PUPIL_COLOR)

    -- 右眼眼白
    local rightEye = headNode:CreateChild("RightEye", mode)
    rightEye.position = Vector3(EYE_SPACING, EYE_Y, FACE_Z)
    rightEye.scale = Vector3(EYE_WIDTH, EYE_HEIGHT, DETAIL_THICKNESS)
    local rightEyeModel = rightEye:CreateComponent("StaticModel", mode)
    rightEyeModel.model = cache:GetResource("Model", "Models/Box.mdl")
    rightEyeModel.material = self:createSolidMaterial(WHITE)

    -- 右眼瞳孔（偏向鼻子方向，即左侧）
    local rightPupil = headNode:CreateChild("RightPupil", mode)
    rightPupil.position = Vector3(EYE_SPACING - PX * 0.4, EYE_Y, FACE_Z + 0.01)
    rightPupil.scale = Vector3(PUPIL_SIZE, PUPIL_SIZE, DETAIL_THICKNESS)
    local rightPupilModel = rightPupil:CreateComponent("StaticModel", mode)
    rightPupilModel.model = cache:GetResource("Model", "Models/Box.mdl")
    rightPupilModel.material = self:createSolidMaterial(PUPIL_COLOR)

    -- ============================================
    -- 鼻子（Minecraft Steve 有一个小鼻子）
    -- 位置：眼睛下方中央，2x1 像素
    -- ============================================
    local NOSE_WIDTH = PX * 1.5
    local NOSE_HEIGHT = PX * 1.0
    local NOSE_Y = -0.06

    local nose = headNode:CreateChild("Nose", mode)
    nose.position = Vector3(0, NOSE_Y, FACE_Z + 0.01)  -- 稍微突出
    nose.scale = Vector3(NOSE_WIDTH, NOSE_HEIGHT, DETAIL_THICKNESS * 2)
    local noseModel = nose:CreateComponent("StaticModel", mode)
    noseModel.model = cache:GetResource("Model", "Models/Box.mdl")
    noseModel.material = self:createSolidMaterial(NOSE_COLOR)

    -- ============================================
    -- 嘴巴（经典 Steve 风格）
    -- 位置：下巴上方，4x1 像素宽
    -- ============================================
    local MOUTH_WIDTH = PX * 3.5
    local MOUTH_HEIGHT = PX * 0.8
    local MOUTH_Y = -0.22

    local mouth = headNode:CreateChild("Mouth", mode)
    mouth.position = Vector3(0, MOUTH_Y, FACE_Z)
    mouth.scale = Vector3(MOUTH_WIDTH, MOUTH_HEIGHT, DETAIL_THICKNESS)
    local mouthModel = mouth:CreateComponent("StaticModel", mode)
    mouthModel.model = cache:GetResource("Model", "Models/Box.mdl")
    mouthModel.material = self:createSolidMaterial(MOUTH_COLOR)

    -- ============================================
    -- 头发（贴在头部表面的薄片，不破坏方块形状）
    -- 头发环绕头部上半部分（除了正脸下方）
    -- ============================================
    local HAIR_Y = 0.28  -- 头发中心 Y 位置
    local HAIR_HEIGHT = PX * 3.5  -- 头发高度
    local SIDE_X = 0.505  -- 侧面 X 位置

    -- 前额刘海（贴在前脸上方，宽度延伸到边缘与侧面重叠）
    local bangs = headNode:CreateChild("Bangs", mode)
    bangs.position = Vector3(0, 0.38, FACE_Z)
    bangs.scale = Vector3(1.02, PX * 1.8, DETAIL_THICKNESS)  -- 宽度略超边缘确保连接
    local bangsModel = bangs:CreateComponent("StaticModel", mode)
    bangsModel.model = cache:GetResource("Model", "Models/Box.mdl")
    bangsModel.material = self:createSolidMaterial(HAIR_COLOR)

    -- 左侧头发（完整覆盖左侧，Z 方向延伸到前脸）
    local leftSide = headNode:CreateChild("HairLeft", mode)
    leftSide.position = Vector3(-SIDE_X, HAIR_Y, 0)  -- Z 居中
    leftSide.scale = Vector3(DETAIL_THICKNESS, HAIR_HEIGHT, 1.02)  -- 完全覆盖，略超边缘
    local leftSideModel = leftSide:CreateComponent("StaticModel", mode)
    leftSideModel.model = cache:GetResource("Model", "Models/Box.mdl")
    leftSideModel.material = self:createSolidMaterial(HAIR_COLOR)

    -- 右侧头发（完整覆盖右侧，Z 方向延伸到前脸）
    local rightSide = headNode:CreateChild("HairRight", mode)
    rightSide.position = Vector3(SIDE_X, HAIR_Y, 0)
    rightSide.scale = Vector3(DETAIL_THICKNESS, HAIR_HEIGHT, 1.02)
    local rightSideModel = rightSide:CreateComponent("StaticModel", mode)
    rightSideModel.model = cache:GetResource("Model", "Models/Box.mdl")
    rightSideModel.material = self:createSolidMaterial(HAIR_COLOR)

    -- 后脑头发（完整覆盖后脑勺，与两侧无缝衔接）
    local BACK_Z = -0.505
    local backHair = headNode:CreateChild("HairBack", mode)
    backHair.position = Vector3(0, HAIR_Y, BACK_Z)
    backHair.scale = Vector3(1.02, HAIR_HEIGHT, DETAIL_THICKNESS)  -- 宽度略超边缘确保连接
    local backHairModel = backHair:CreateComponent("StaticModel", mode)
    backHairModel.model = cache:GetResource("Model", "Models/Box.mdl")
    backHairModel.material = self:createSolidMaterial(HAIR_COLOR)

    -- 头顶头发（完整覆盖头顶，与四周头发无缝衔接）
    local TOP_Y = 0.505  -- 头顶 Y 位置（略高于头部表面避免 z-fighting）
    local topHair = headNode:CreateChild("HairTop", mode)
    topHair.position = Vector3(0, TOP_Y, 0)
    topHair.scale = Vector3(1.02, DETAIL_THICKNESS, 1.02)  -- 完全覆盖头顶，略超边缘确保连接
    local topHairModel = topHair:CreateComponent("StaticModel", mode)
    topHairModel.model = cache:GetResource("Model", "Models/Box.mdl")
    topHairModel.material = self:createSolidMaterial(HAIR_COLOR)
end

---创建纯色材质
---@param color Color 颜色
---@return Material 材质
function PlayerBody:createSolidMaterial(color)
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    return material
end

---统计部件数量
---@return number 部件数量
function PlayerBody:countParts()
    local count = 0
    for _ in pairs(self.parts) do
        count = count + 1
    end
    return count
end

---更新身体（每帧调用）
---@param timeStep number 时间步长
function PlayerBody:update(timeStep)
    if not self.visible or not self.bodyNode then
        return
    end
    
    -- 更新身体朝向（跟随玩家偏航角）
    local yaw = self.player:getYaw()
    self.bodyNode.rotation = Quaternion(0, yaw, 0)
    
    -- 更新行走动画
    self:updateWalkAnimation(timeStep)
    
    -- 更新挥臂动画（覆盖行走动画中的右手臂）
    self:updateSwingArmAnimation(timeStep)
end

---更新行走动画
---@param timeStep number 时间步长
function PlayerBody:updateWalkAnimation(timeStep)
    -- 优先使用 velocity（本地玩家）
    local velocity = self.player:getVelocity()
    local speed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
    
    -- 如果 velocity 没有水平速度，尝试用位置变化检测（远程玩家）
    if speed < 0.1 and timeStep > 0 then
        local currentPos = self.player:getPosition()
        if self.lastPosition then
            local dx = currentPos.x - self.lastPosition.x
            local dz = currentPos.z - self.lastPosition.z
            speed = math.sqrt(dx * dx + dz * dz) / timeStep
        end
        self.lastPosition = Vector3(currentPos.x, currentPos.y, currentPos.z)
    end
    
    -- 检测是否在行走
    self.isWalking = speed > 0.5 and self.player:getOnGround()
    
    if self.isWalking then
        -- 行走时更新动画时间（速度与移动速度成正比）
        local animSpeed = math.min(speed * 3, 15)  -- 动画速度，最快15
        self.walkTime = self.walkTime + timeStep * animSpeed
    else
        -- 停止时平滑归位
        self.walkTime = self.walkTime * 0.85
        if math.abs(self.walkTime) < 0.01 then
            self.walkTime = 0
        end
    end
    
    -- 应用手臂和腿的摆动动画
    local swingAngle = math.sin(self.walkTime) * 45  -- 摆动幅度 ±45度（更大）
    
    -- 左手臂向前时右腿向后，反之亦然（跑步姿态）
    if self.pivots.armLeft then
        self.pivots.armLeft.rotation = Quaternion(swingAngle, 0, 0)
    end
    -- 右手臂仅在不挥臂时跟随行走动画
    if self.pivots.armRight and not self.isSwingingArm then
        self.pivots.armRight.rotation = Quaternion(-swingAngle, 0, 0)
    end
    if self.pivots.legLeft then
        self.pivots.legLeft.rotation = Quaternion(-swingAngle, 0, 0)
    end
    if self.pivots.legRight then
        self.pivots.legRight.rotation = Quaternion(swingAngle, 0, 0)
    end
end

---设置整体可见性
---@param visible boolean 是否可见
function PlayerBody:setVisible(visible)
    self.visible = visible
    if self.bodyNode then
        -- 使用 SetDeepEnabled 确保递归禁用所有子节点
        self.bodyNode:SetDeepEnabled(visible)
    end
end

---设置头部可见性（第一人称时隐藏头部避免遮挡）
---@param visible boolean 是否可见
function PlayerBody:setHeadVisible(visible)
    self.headVisible = visible
    if self.parts.head and self.parts.head.node then
        -- 使用 SetDeepEnabled 确保眼睛、嘴巴等子节点也被禁用
        self.parts.head.node:SetDeepEnabled(visible)
    end
end

---获取可见性
---@return boolean 是否可见
function PlayerBody:isVisible()
    return self.visible
end

---获取身体根节点
---@return Node 身体根节点
function PlayerBody:getBodyNode()
    return self.bodyNode
end

---更新挥臂动画
---@param timeStep number 时间步长
function PlayerBody:updateSwingArmAnimation(timeStep)
    if not self.isSwingingArm then
        return
    end
    
    -- 更新动画进度
    self.swingArmTime = self.swingArmTime + timeStep / self.swingArmDuration
    
    if self.swingArmTime >= 1 then
        -- 动画结束
        self.swingArmTime = 0
        self.isSwingingArm = false
        return
    end
    
    -- 使用正弦曲线实现平滑的挥动效果
    -- 0 -> 1: 从静止位置快速挥到最大角度，然后回到静止
    -- 使用 sin(t * PI) 曲线：0 -> 1 -> 0
    local progress = math.sin(self.swingArmTime * math.pi)
    local swingAngle = progress * self.swingArmMaxAngle
    
    -- 应用到右手臂（向前下方挥动，X轴负向旋转）
    if self.pivots.armRight then
        self.pivots.armRight.rotation = Quaternion(-swingAngle, 0, 0)
    end
end

---触发手臂挥动动画（攻击时调用）
function PlayerBody:swingArm()
    -- 如果已经在挥臂中，重新开始动画
    self.swingArmTime = 0
    self.isSwingingArm = true
end

---销毁
function PlayerBody:destroy()
    if self.bodyNode then
        self.bodyNode:Remove()
        self.bodyNode = nil
    end
    self.parts = {}
    self.pivots = {}
    print("[PlayerBody] Player body destroyed")
end

return PlayerBody

