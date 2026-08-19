-- ====================================================================
-- ui/UnderwaterOverlay.lua
-- 水下效果覆盖层 - 当相机在水中时显示水纹理全屏覆盖
-- 使用与世界水方块相同的 SingleLayerWater 材质
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")

---@class UnderwaterOverlay
---@field cameraNode Node 相机节点
---@field scene Scene 场景
---@field node Node 覆盖层节点
---@field customGeo CustomGeometry 自定义几何体
---@field material Material 水材质
---@field isActive boolean 是否激活
local UnderwaterOverlay = {}
UnderwaterOverlay.__index = UnderwaterOverlay

-- 覆盖层参数
local OVERLAY_DISTANCE = 0.15  -- 距离相机的距离（在近裁剪面之后）
local OVERLAY_SIZE = 0.5       -- 覆盖层半尺寸（会覆盖整个视野）

-- 调试开关
local DEBUG = false

---创建水下覆盖层
---@param cameraNode Node 相机节点
---@param scene Scene 场景
---@return UnderwaterOverlay
function UnderwaterOverlay.new(cameraNode, scene)
    local self = setmetatable({}, UnderwaterOverlay)
    
    self.cameraNode = cameraNode
    self.scene = scene
    self.isActive = false
    
    -- 创建覆盖层节点（作为相机子节点，跟随相机移动）
    self.node = cameraNode:CreateChild("UnderwaterOverlay", LOCAL)
    
    -- 创建自定义几何体
    self.customGeo = self.node:CreateComponent("CustomGeometry", LOCAL)
    
    -- 加载水材质
    self.material = cache:GetResource("Material", "Materials/SingleLayerWater.xml")
    if not self.material then
        -- 回退方案：创建简单的半透明蓝色材质
        if DEBUG then print("[UnderwaterOverlay] SingleLayerWater.xml not found, using fallback") end
        self.material = Material:new()
        local technique = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
        self.material:SetTechnique(0, technique)
        self.material:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.4, 0.8, 0.6)))
    else
        -- 克隆材质以避免影响世界水
        self.material = self.material:Clone()
        -- 调整水下效果参数（可以更浓郁一些）
        self.material:SetShaderParameter("WaterTint", Variant(Color(0.15, 0.35, 0.7)))
    end
    
    -- 双面渲染
    self.material.cullMode = CULL_NONE
    
    -- 构建全屏四边形
    self:buildQuad()
    
    -- 默认隐藏
    self.node.enabled = false
    
    if DEBUG then print("[UnderwaterOverlay] Created") end
    
    return self
end

---构建全屏覆盖四边形
function UnderwaterOverlay:buildQuad()
    local geo = self.customGeo
    
    geo:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 四边形位于相机前方，覆盖整个视野
    -- 顶点顺序：逆时针（从相机看是正面）
    local z = OVERLAY_DISTANCE
    local s = OVERLAY_SIZE
    
    -- 三角形 1: 左下 - 右下 - 右上
    -- 左下
    geo:DefineVertex(Vector3(-s, -s, z))
    geo:DefineNormal(Vector3(0, 0, -1))
    geo:DefineTexCoord(Vector2(0, 1))
    geo:DefineColor(Color(1, 1, 1, 0.7))
    
    -- 右下
    geo:DefineVertex(Vector3(s, -s, z))
    geo:DefineNormal(Vector3(0, 0, -1))
    geo:DefineTexCoord(Vector2(1, 1))
    geo:DefineColor(Color(1, 1, 1, 0.7))
    
    -- 右上
    geo:DefineVertex(Vector3(s, s, z))
    geo:DefineNormal(Vector3(0, 0, -1))
    geo:DefineTexCoord(Vector2(1, 0))
    geo:DefineColor(Color(1, 1, 1, 0.7))
    
    -- 三角形 2: 左下 - 右上 - 左上
    -- 左下
    geo:DefineVertex(Vector3(-s, -s, z))
    geo:DefineNormal(Vector3(0, 0, -1))
    geo:DefineTexCoord(Vector2(0, 1))
    geo:DefineColor(Color(1, 1, 1, 0.7))
    
    -- 右上
    geo:DefineVertex(Vector3(s, s, z))
    geo:DefineNormal(Vector3(0, 0, -1))
    geo:DefineTexCoord(Vector2(1, 0))
    geo:DefineColor(Color(1, 1, 1, 0.7))
    
    -- 左上
    geo:DefineVertex(Vector3(-s, s, z))
    geo:DefineNormal(Vector3(0, 0, -1))
    geo:DefineTexCoord(Vector2(0, 0))
    geo:DefineColor(Color(1, 1, 1, 0.7))
    
    geo:Commit()
    geo.material = self.material
    geo.castShadows = false
    
    if DEBUG then print("[UnderwaterOverlay] Quad built") end
end

---更新水下检测
---@param world table World 实例
function UnderwaterOverlay:update(world)
    if not world then
        return
    end
    
    -- 获取相机世界位置
    local camPos = self.cameraNode.worldPosition
    
    -- 转换为方块坐标
    local bx, by, bz = world:worldToBlock(camPos)
    local blockType = world:getBlock(bx, by, bz)
    
    -- 检测是否在水中
    local inWater = Blocks:isLiquid(blockType)
    
    if inWater and not self.isActive then
        -- 进入水中
        self.node.enabled = true
        self.isActive = true
        if DEBUG then print("[UnderwaterOverlay] Activated - in water at", bx, by, bz) end
    elseif not inWater and self.isActive then
        -- 离开水
        self.node.enabled = false
        self.isActive = false
        if DEBUG then print("[UnderwaterOverlay] Deactivated - left water") end
    end
end

---销毁覆盖层
function UnderwaterOverlay:destroy()
    if self.node then
        self.node:Remove()
        self.node = nil
    end
    self.customGeo = nil
    self.material = nil
    
    if DEBUG then print("[UnderwaterOverlay] Destroyed") end
end

return UnderwaterOverlay

