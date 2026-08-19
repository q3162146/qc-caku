-- ====================================================================
-- ui/SuffocationBox.lua
-- 窒息盒子 - 当相机穿入方块时显示方块内部视图
-- 模拟 Minecraft 的窒息效果
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")

---@class SuffocationBox
---@field cameraNode Node 相机节点
---@field scene Scene 场景
---@field boxes table 盒子节点数组（最多支持8个同时穿入的方块）
---@field texturePack table 纹理包
---@field activeBoxCount number 当前激活的盒子数量
local SuffocationBox = {}
SuffocationBox.__index = SuffocationBox

-- 最大同时穿入的方块数（相机可能穿入多个相邻方块）
local MAX_BOXES = 8

-- 调试开关（生产环境应设为 false）
local DEBUG = false

-- 检测参数（相对于 BLOCK_SIZE 的系数）
local NEAR_CLIP_FACTOR = 0.35   -- 近裁剪面距离系数
local SIDE_OFFSET_FACTOR = 0.3  -- 水平偏移系数
local VERT_OFFSET_FACTOR = 0.25 -- 垂直偏移系数
local BOX_SHRINK = 0.02         -- 盒子收缩量（避免与世界方块重叠）

-- 检测点数量
local CHECK_POINT_COUNT = 10

-- 预分配的检测位置数组（避免每帧创建新 table）
local _checkPositions = {}
for i = 1, CHECK_POINT_COUNT do
    _checkPositions[i] = Vector3(0, 0, 0)
end

-- 预分配的穿入方块数据（使用数值 key 避免字符串分配）
local _penetratedBlocks = {}  -- [数值key] = {blockType, bx, by, bz}
local _penetratedBlockData = {}  -- 预分配的数据槽
for i = 1, MAX_BOXES do
    _penetratedBlockData[i] = { blockType = 0, bx = 0, by = 0, bz = 0 }
end

---计算方块坐标的数值 key（避免字符串分配）
---假设坐标范围 -32768 ~ 32767（足够大多数场景）
---@param bx number
---@param by number
---@param bz number
---@return number
local function blockKey(bx, by, bz)
    -- 使用位运算或简单乘法生成唯一 key
    -- bx, by, bz 各占 16 位，总共 48 位，Lua number 可以精确表示
    return (bx + 32768) * 4294967296 + (by + 32768) * 65536 + (bz + 32768)
end

-- 注意：所有调试日志都使用 `if DEBUG then print(...) end` 内联形式
-- 这样在 DEBUG = false 时完全不会有任何字符串操作开销

---创建窒息盒子
---@param cameraNode Node 相机节点
---@param scene Scene 场景
---@return SuffocationBox
function SuffocationBox.new(cameraNode, scene)
    local self = setmetatable({}, SuffocationBox)
    
    self.cameraNode = cameraNode
    self.scene = scene
    self.activeBoxCount = 0
    
    -- 获取纹理包
    self.texturePack = TexturePackManager:getCurrent()
    local textures = self.texturePack:generate()
    
    -- 创建多个盒子节点（预分配）
    self.boxes = {}
    for i = 1, MAX_BOXES do
        local box = {
            node = nil,
            customGeo = nil,
            material = nil,
            blockType = 0,
            blockX = nil,
            blockY = nil,
            blockZ = nil,
            isActive = false
        }
        
        -- 创建节点（作为场景子节点）
        box.node = scene:CreateChild("SuffocationBox_" .. i, LOCAL)
        box.node.position = Vector3(0, 0, 0)
        
        -- 创建自定义几何体
        box.customGeo = box.node:CreateComponent("CustomGeometry", LOCAL)
        box.customGeo:SetNumGeometries(1)
        
        -- 创建材质（使用 NoTextureUnlit 确保简单渲染）
        box.material = Material:new()
        local technique = cache:GetResource("Technique", "Techniques/DiffUnlit.xml")
        box.material:SetTechnique(0, technique)
        
        -- 设置纹理
        if textures and textures.diffuse then
            box.material:SetTexture(TU_DIFFUSE, textures.diffuse)
        end
        
        -- 禁用背面剔除（双面渲染）
        box.material.cullMode = CULL_NONE
        
        -- 高渲染优先级，确保在世界方块之后渲染
        box.material.renderOrder = 200
        
        -- 深度偏移：让盒子稍微"靠近"相机，避免与世界方块 z-fighting
        -- constantBias: 固定偏移量（负值表示靠近相机）
        -- slopeScaledBias: 斜率缩放偏移
        box.material.depthBias = BiasParameters(-0.00005, -1.0)
        
        -- 调暗模拟内部光照（方块内部应该更暗）
        box.material:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.35, 0.35, 1.0)))
        
        box.customGeo:SetMaterial(box.material)
        
        -- 初始隐藏
        box.node.enabled = false
        
        self.boxes[i] = box
    end
    
    if DEBUG then
        print("[SuffocationBox] Created with " .. MAX_BOXES .. " box slots!")
    end
    
    return self
end

---构建内面朝外的盒子几何体（完整6个面，不排除任何面）
---@param box table 盒子数据
---@param blockType number 方块类型
function SuffocationBox:buildGeometry(box, blockType)
    -- 盒子尺寸（使用方块大小，稍微收缩避免与世界方块边缘重叠）
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local s = (BLOCK_SIZE / 2) - BOX_SHRINK
    
    -- 获取方块信息
    local block = Blocks:get(blockType)
    if not block then
        if DEBUG then
            print("[SuffocationBox] Warning: Block type " .. tostring(blockType) .. " not found!")
        end
        return false
    end
    
    local blockTextures = block.textures
    
    if not blockTextures then
        if DEBUG then
            print("[SuffocationBox] Warning: Block " .. (block.name or "unknown") .. " has no textures!")
        end
        return false
    end
    
    -- 调试输出（只在 DEBUG 模式下执行字符串拼接）
    if DEBUG then
        local blockName = block.name or "unknown"
        print(string.format("[SuffocationBox] Building geometry for block %d (%s), textures: top=%s, side=%s", 
            blockType, blockName,
            blockTextures.top and string.format("{%d,%d}", blockTextures.top[1], blockTextures.top[2]) or "nil",
            blockTextures.side and string.format("{%d,%d}", blockTextures.side[1], blockTextures.side[2]) or "nil"))
    end
    
    -- 获取各面的纹理 UV（内联以避免闭包开销）
    local texturePack = self.texturePack
    
    box.customGeo:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 定义6个面（从内部看的正确绕序 - 逆时针）
    -- 所有面都渲染，依靠材质的 CULL_NONE 和深度偏移来避免问题
    local allFaces = {
        -- 后面 (Z-) - 从内部看是 Z+ 方向
        { 
            verts = {{-s,-s,-s}, {s,-s,-s}, {s,s,-s}, {-s,s,-s}},
            normal = {0, 0, 1},
            texType = "side"
        },
        -- 前面 (Z+) - 从内部看是 Z- 方向
        {
            verts = {{s,-s,s}, {-s,-s,s}, {-s,s,s}, {s,s,s}},
            normal = {0, 0, -1},
            texType = "side"
        },
        -- 左面 (X-) - 从内部看是 X+ 方向
        {
            verts = {{-s,-s,s}, {-s,-s,-s}, {-s,s,-s}, {-s,s,s}},
            normal = {1, 0, 0},
            texType = "side"
        },
        -- 右面 (X+) - 从内部看是 X- 方向
        {
            verts = {{s,-s,-s}, {s,-s,s}, {s,s,s}, {s,s,-s}},
            normal = {-1, 0, 0},
            texType = "side"
        },
        -- 上面 (Y+) - 从内部看是 Y- 方向
        {
            verts = {{-s,s,-s}, {s,s,-s}, {s,s,s}, {-s,s,s}},
            normal = {0, -1, 0},
            texType = "top"
        },
        -- 下面 (Y-) - 从内部看是 Y+ 方向
        {
            verts = {{-s,-s,s}, {s,-s,s}, {s,-s,-s}, {-s,-s,-s}},
            normal = {0, 1, 0},
            texType = "bottom"
        },
    }
    
    for _, face in ipairs(allFaces) do
        local verts = face.verts
        local normal = face.normal
        
        -- 内联 getUV 逻辑（避免闭包开销）
        local texCoord = blockTextures[face.texType] or blockTextures.side or blockTextures.top
        local u0, v0, u1, v1 = 0, 0, 1, 1
        if texCoord and texturePack then
            u0, v0, u1, v1 = texturePack:getTileUV(texCoord[1], texCoord[2])
        end
        
        -- UV 坐标（左下、右下、右上、左上）
        local uvs = {
            {u0, v1}, {u1, v1}, {u1, v0}, {u0, v0}
        }
        
        -- 三角形 1: 0, 1, 2
        for i = 1, 3 do
            local v = verts[i]
            box.customGeo:DefineVertex(Vector3(v[1], v[2], v[3]))
            box.customGeo:DefineNormal(Vector3(normal[1], normal[2], normal[3]))
            box.customGeo:DefineTexCoord(Vector2(uvs[i][1], uvs[i][2]))
        end
        
        -- 三角形 2: 0, 2, 3
        local indices = {1, 3, 4}
        for _, idx in ipairs(indices) do
            local v = verts[idx]
            box.customGeo:DefineVertex(Vector3(v[1], v[2], v[3]))
            box.customGeo:DefineNormal(Vector3(normal[1], normal[2], normal[3]))
            box.customGeo:DefineTexCoord(Vector2(uvs[idx][1], uvs[idx][2]))
        end
    end
    
    box.customGeo:Commit()
    box.blockType = blockType
    
    if DEBUG then
        print("[SuffocationBox] Geometry built successfully for block " .. blockType)
    end
    return true
end

---更新（每帧调用）
---@param world table World实例
function SuffocationBox:update(world)
    if not self.cameraNode or not world then
        self:hideAll()
        return
    end
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    
    -- 获取相机位置和方向（这些是引擎返回的引用，不会分配新内存）
    local camPos = self.cameraNode.worldPosition
    local lookDir = self.cameraNode.worldDirection
    local camRight = self.cameraNode.worldRight
    local camUp = self.cameraNode.worldUp
    
    -- 近裁剪面检测参数（使用配置常量）
    local nearClipDist = NEAR_CLIP_FACTOR * BLOCK_SIZE
    local sideOffset = SIDE_OFFSET_FACTOR * BLOCK_SIZE
    local vertOffset = VERT_OFFSET_FACTOR * BLOCK_SIZE
    
    -- 计算前方中心点的分量（避免创建临时 Vector3）
    local fcX = camPos.x + lookDir.x * nearClipDist
    local fcY = camPos.y + lookDir.y * nearClipDist
    local fcZ = camPos.z + lookDir.z * nearClipDist
    
    -- 更新预分配的检测位置（复用 Vector3，避免每帧分配）
    -- 1: 相机位置
    _checkPositions[1].x = camPos.x
    _checkPositions[1].y = camPos.y
    _checkPositions[1].z = camPos.z
    -- 2: 前方中心
    _checkPositions[2].x = fcX
    _checkPositions[2].y = fcY
    _checkPositions[2].z = fcZ
    -- 3: 右
    _checkPositions[3].x = fcX + camRight.x * sideOffset
    _checkPositions[3].y = fcY + camRight.y * sideOffset
    _checkPositions[3].z = fcZ + camRight.z * sideOffset
    -- 4: 左
    _checkPositions[4].x = fcX - camRight.x * sideOffset
    _checkPositions[4].y = fcY - camRight.y * sideOffset
    _checkPositions[4].z = fcZ - camRight.z * sideOffset
    -- 5: 上
    _checkPositions[5].x = fcX + camUp.x * vertOffset
    _checkPositions[5].y = fcY + camUp.y * vertOffset
    _checkPositions[5].z = fcZ + camUp.z * vertOffset
    -- 6: 下
    _checkPositions[6].x = fcX - camUp.x * vertOffset
    _checkPositions[6].y = fcY - camUp.y * vertOffset
    _checkPositions[6].z = fcZ - camUp.z * vertOffset
    -- 7: 右上
    _checkPositions[7].x = fcX + camRight.x * sideOffset + camUp.x * vertOffset
    _checkPositions[7].y = fcY + camRight.y * sideOffset + camUp.y * vertOffset
    _checkPositions[7].z = fcZ + camRight.z * sideOffset + camUp.z * vertOffset
    -- 8: 左上
    _checkPositions[8].x = fcX - camRight.x * sideOffset + camUp.x * vertOffset
    _checkPositions[8].y = fcY - camRight.y * sideOffset + camUp.y * vertOffset
    _checkPositions[8].z = fcZ - camRight.z * sideOffset + camUp.z * vertOffset
    -- 9: 右下
    _checkPositions[9].x = fcX + camRight.x * sideOffset - camUp.x * vertOffset
    _checkPositions[9].y = fcY + camRight.y * sideOffset - camUp.y * vertOffset
    _checkPositions[9].z = fcZ + camRight.z * sideOffset - camUp.z * vertOffset
    -- 10: 左下
    _checkPositions[10].x = fcX - camRight.x * sideOffset - camUp.x * vertOffset
    _checkPositions[10].y = fcY - camRight.y * sideOffset - camUp.y * vertOffset
    _checkPositions[10].z = fcZ - camRight.z * sideOffset - camUp.z * vertOffset
    
    -- 清空上一帧的数据（使用数值 key，避免字符串分配）
    for k in pairs(_penetratedBlocks) do
        _penetratedBlocks[k] = nil
    end
    local blockCount = 0
    
    -- 收集所有穿入的固体方块
    for i = 1, CHECK_POINT_COUNT do
        local pos = _checkPositions[i]
        local bx, by, bz = world:worldToBlock(pos)
        local blockType = world:getBlock(bx, by, bz)
        
        if Blocks:isSolid(blockType) then
            local key = blockKey(bx, by, bz)
            if not _penetratedBlocks[key] then
                blockCount = blockCount + 1
                if blockCount <= MAX_BOXES then
                    -- 复用预分配的数据槽
                    local data = _penetratedBlockData[blockCount]
                    data.blockType = blockType
                    data.bx = bx
                    data.by = by
                    data.bz = bz
                    _penetratedBlocks[key] = blockCount  -- 存储索引而非数据
                end
            end
        end
    end
    
    -- 更新盒子
    for i = 1, blockCount do
        local blockData = _penetratedBlockData[i]
        local box = self.boxes[i]
        local bx, by, bz = blockData.bx, blockData.by, blockData.bz
        local blockType = blockData.blockType
        
        -- 计算方块中心的世界坐标
        local blockCenterX = (bx + 0.5) * BLOCK_SIZE
        local blockCenterY = (by + 0.5) * BLOCK_SIZE
        local blockCenterZ = (bz + 0.5) * BLOCK_SIZE
        
        -- 检查是否需要重建几何体（方块类型改变）
        local needRebuild = (box.blockType ~= blockType)
        
        -- 检查位置是否改变
        local positionChanged = (box.blockX ~= bx) or (box.blockY ~= by) or (box.blockZ ~= bz)
        
        if needRebuild then
            self:buildGeometry(box, blockType)
        end
        
        -- 更新位置状态（无论是否重建都要更新）
        if needRebuild or positionChanged then
            box.blockX = bx
            box.blockY = by
            box.blockZ = bz
            box.node.position = Vector3(blockCenterX, blockCenterY, blockCenterZ)
        end
        
        -- 显示盒子
        if not box.isActive then
            box.node.enabled = true
            box.isActive = true
        end
    end
    
    -- 隐藏多余的盒子
    for i = blockCount + 1, MAX_BOXES do
        local box = self.boxes[i]
        if box.isActive then
            box.node.enabled = false
            box.isActive = false
            box.blockX = nil
            box.blockY = nil
            box.blockZ = nil
        end
    end
    
    self.activeBoxCount = blockCount
end

---隐藏所有盒子
function SuffocationBox:hideAll()
    for i = 1, MAX_BOXES do
        local box = self.boxes[i]
        if box.isActive then
            box.node.enabled = false
            box.isActive = false
        end
    end
    self.activeBoxCount = 0
end

---销毁
function SuffocationBox:destroy()
    for i = 1, MAX_BOXES do
        local box = self.boxes[i]
        if box then
            -- 清理材质引用
            if box.material then
                box.material = nil
            end
            -- 清理几何体引用
            if box.customGeo then
                box.customGeo = nil
            end
            -- 移除节点
            if box.node then
                box.node:Remove()
                box.node = nil
            end
        end
    end
    self.boxes = {}
    self.texturePack = nil
    if DEBUG then
        print("[SuffocationBox] Destroyed")
    end
end

return SuffocationBox
