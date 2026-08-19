-- ====================================================================
-- player/Player.lua
-- 玩家状态和属性
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local FirstPersonArm = require("player.FirstPersonArm")
local PlayerBody = require("player.PlayerBody")

---@class Player
---@field scene Scene
---@field node Node
---@field cameraNode Node
---@field camera Camera
---@field velocity Vector3
---@field yaw number
---@field pitch number
---@field isOnGround boolean
---@field selectedBlockType integer
---@field selectedBlockIndex integer
---@field firstPersonArm FirstPersonArm
---@field body PlayerBody
---@field isLocal boolean
local Player = {}
Player.__index = Player

---创建新的玩家实例
---@param scene Scene 场景节点
---@return table Player实例
function Player.new(scene)
    local self = setmetatable({}, Player)
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local PLAYER_HEIGHT = Config.Player.HEIGHT
    
    -- 保存场景引用
    self.scene = scene
    
    -- 创建玩家节点
    self.node = scene:CreateChild("Player")
    self.node.position = Vector3(0, 100 * BLOCK_SIZE, 0)  -- 高处开始，会落到地面
    
    -- 创建相机节点（玩家子节点，位于眼睛高度）
    -- 加载景深（移动端不开启，节省性能）
    local platform = GetPlatform()
    if platform ~= "Android" and platform ~= "iOS" then
        self.cameraNode = scene:InstantiateXML("EngineRes/PostProcess/DOFPrefab.xml", Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
        self.cameraNode.name = "Camera"
        self.cameraNode.parent = self.node
    else
        self.cameraNode = self.node:CreateChild("Camera", LOCAL)
    end
    -- 位置
    self.cameraNode.position = Vector3(0, (PLAYER_HEIGHT - 0.2) * BLOCK_SIZE, 0)
    
    -- 创建相机组件
    self.camera = self.cameraNode:CreateComponent("Camera", LOCAL)
    self.camera.farClip = Config.Camera.FAR_CLIP
    self.camera.fov = Config.Camera.FOV
    
    -- 状态
    self.velocity = Vector3(0, 0, 0)
    self.yaw = 0
    self.pitch = 0
    self.isOnGround = false
    self.selectedBlockType = Blocks.GRASS
    self.selectedBlockIndex = 1  -- 物品栏索引
    
    -- 创建第一人称手臂
    self.firstPersonArm = FirstPersonArm.new(self, scene)
    
    -- 创建玩家身体（第三人称可见，联机时同步）
    self.body = PlayerBody.new(self)
    -- 初始状态隐藏身体（第一人称模式）
    self.body:setVisible(false)
    
    return self
end

---获取玩家位置
---@return Vector3 位置
function Player:getPosition()
    return self.node.position
end

---设置玩家位置
---@param pos Vector3 位置
function Player:setPosition(pos)
    self.node.position = pos
end

---获取眼睛位置（相机世界坐标）
---@return Vector3 眼睛位置
function Player:getEyePosition()
    if self.cameraNode then
        return self.cameraNode.worldPosition
    end
    -- 服务器/远程玩家：估算眼睛位置
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local PLAYER_HEIGHT = Config.Player.HEIGHT
    return self.node.position + Vector3(0, (PLAYER_HEIGHT - 0.2) * BLOCK_SIZE, 0)
end

---获取视线方向
---@return Vector3 方向向量
function Player:getLookDirection()
    if self.cameraNode then
        return self.cameraNode.worldDirection
    end
    -- 服务器/远程玩家：从 yaw/pitch 计算
    return Quaternion(self.pitch, self.yaw, 0) * Vector3.FORWARD
end

---获取相机节点
---@return Node|nil 相机节点
function Player:getCameraNode()
    return self.cameraNode
end

---获取相机组件
---@return Camera|nil 相机组件
function Player:getCamera()
    return self.camera
end

---更新相机旋转
function Player:updateCamera()
    self.pitch = math.max(-89, math.min(89, self.pitch))
    if self.cameraNode then
        self.cameraNode.rotation = Quaternion(self.pitch, self.yaw, 0)
    end
end

---选择方块类型
---@param blockType number 方块类型
function Player:selectBlock(blockType)
    self.selectedBlockType = blockType
end

---选择物品栏槽位
---@param index number 槽位索引（1-11）
function Player:selectSlot(index)
    -- 与 Hotbar.lua 保持一致（默认只提供基础方块）
    local hotbarBlocks = {
        Blocks.GRASS, Blocks.DIRT, Blocks.STONE, Blocks.WOOD,
        Blocks.LEAVES, Blocks.SAND
    }
    if index >= 1 and index <= #hotbarBlocks then
        self.selectedBlockIndex = index
        self.selectedBlockType = hotbarBlocks[index]
    end
end

---获取当前选中的方块类型
---@return number 方块类型
function Player:getSelectedBlockType()
    return self.selectedBlockType
end

---获取当前选中的槽位索引
---@return number 槽位索引
function Player:getSelectedSlotIndex()
    return self.selectedBlockIndex
end

---设置速度
---@param velocity Vector3 速度向量
function Player:setVelocity(velocity)
    self.velocity = velocity
end

---获取速度
---@return Vector3 速度向量
function Player:getVelocity()
    return self.velocity
end

---设置是否在地面
---@param onGround boolean 是否在地面
function Player:setOnGround(onGround)
    self.isOnGround = onGround
end

---获取是否在地面
---@return boolean 是否在地面
function Player:getOnGround()
    return self.isOnGround
end

---设置偏航角
---@param yaw number 偏航角（度）
function Player:setYaw(yaw)
    self.yaw = yaw
end

---获取偏航角
---@return number 偏航角（度）
function Player:getYaw()
    return self.yaw
end

---设置俯仰角
---@param pitch number 俯仰角（度）
function Player:setPitch(pitch)
    self.pitch = pitch
end

---获取俯仰角
---@return number 俯仰角（度）
function Player:getPitch()
    return self.pitch
end

---更新玩家（每帧调用）
---@param timeStep number 时间步长
function Player:update(timeStep)
    -- 更新第一人称手臂动画
    if self.firstPersonArm then
        self.firstPersonArm:update(timeStep)
    end
    
    -- 更新玩家身体（行走动画等）
    if self.body then
        self.body:update(timeStep)
    end
end

---触发手臂挥动动画（攻击/放置方块时）
function Player:swingArm()
    -- 第一人称手臂动画
    if self.firstPersonArm then
        self.firstPersonArm:swing()
    end
    -- 第三人称身体手臂动画（联机时其他玩家可见）
    if self.body then
        self.body:swingArm()
    end
end

---设置第一人称手臂可见性
---@param visible boolean 是否可见
function Player:setArmVisible(visible)
    if self.firstPersonArm then
        self.firstPersonArm:setVisible(visible)
    end
end

---获取第一人称手臂实例
---@return table|nil FirstPersonArm实例
function Player:getFirstPersonArm()
    return self.firstPersonArm
end

---获取玩家身体实例
---@return table|nil PlayerBody实例
function Player:getBody()
    return self.body
end

---设置玩家身体可见性
---@param visible boolean 是否可见
function Player:setBodyVisible(visible)
    if self.body then
        self.body:setVisible(visible)
    end
end

-- ============================================
-- 网络模式支持
-- ============================================

---从已有节点创建玩家（联机/单机通用）
---@param node Node 玩家节点
---@param isLocal boolean 是否为本地玩家
---@return table Player实例
function Player.fromNode(node, isLocal)
    local self = setmetatable({}, Player)

    self.node = node
    self.scene = node.scene
    self.isLocal = isLocal

    -- 状态初始化
    self.velocity = Vector3(0, 0, 0)
    self.yaw = 0
    self.pitch = 0
    self.isOnGround = false
    self.selectedBlockType = Blocks.GRASS
    self.selectedBlockIndex = 1

    -- 服务器：不创建任何渲染组件
    if IsServerMode() then
        self.cameraNode = nil
        self.camera = nil
        self.firstPersonArm = nil
        self.body = nil
        return self
    end

    -- 本地玩家：创建相机和手臂
    if isLocal then
        self:createCamera()
        self.firstPersonArm = FirstPersonArm.new(self, self.scene)
        self.body = PlayerBody.new(self)
        self.body:setVisible(false)
    else
        -- 远程玩家：只创建可见的身体
        self.cameraNode = nil
        self.camera = nil
        self.firstPersonArm = nil
        self.body = PlayerBody.new(self)
        self.body:setVisible(true)
    end

    return self
end

---创建相机（内部方法）
function Player:createCamera()
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local PLAYER_HEIGHT = Config.Player.HEIGHT

    -- 创建相机节点（LOCAL 模式，不同步）
    local mode = IsNetworkMode() and LOCAL or nil
    -- 加载景深（移动端不开启，节省性能）
    local platform = GetPlatform()
    if platform ~= "Android" and platform ~= "iOS" then
        self.cameraNode = self.scene:InstantiateXML("EngineRes/PostProcess/DOFPrefab.xml", Vector3.ZERO, Quaternion.IDENTITY, mode)
        self.cameraNode.name = "Camera"
        self.cameraNode.parent = self.node
    else
        self.cameraNode = self.node:CreateChild("Camera", mode)
    end
    self.cameraNode.position = Vector3(0, (PLAYER_HEIGHT - 0.2) * BLOCK_SIZE, 0)

    -- 创建相机组件
    self.camera = self.cameraNode:CreateComponent("Camera", mode)
    self.camera.farClip = Config.Camera.FAR_CLIP
    self.camera.fov = Config.Camera.FOV
end

return Player
