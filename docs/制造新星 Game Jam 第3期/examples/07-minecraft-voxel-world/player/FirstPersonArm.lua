-- ====================================================================
-- player/FirstPersonArm.lua
-- 第一人称手臂 - 显示玩家手臂和手持方块
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local TextureAtlas = require("rendering.TextureAtlas")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")

---@class FirstPersonArm
---@field player Player
---@field cameraNode Node
---@field swingDuration number
local FirstPersonArm = {}
FirstPersonArm.__index = FirstPersonArm

-- 手臂颜色配置（Minecraft 风格肤色）
local ARM_SKIN_COLOR = Color(0.91, 0.71, 0.55)  -- 皮肤色
local ARM_SLEEVE_COLOR = Color(0.3, 0.5, 0.8)   -- 衣服袖子颜色（蓝色）

---创建第一人称手臂
---@param player table Player实例
---@param scene table Scene实例
---@return table FirstPersonArm实例
function FirstPersonArm.new(player, scene)
    local self = setmetatable({}, FirstPersonArm)
    
    self.player = player
    self.scene = scene
    self.cameraNode = player:getCameraNode()
    self.rootNode = nil
    self.pivotNode = nil  -- 旋转轴心节点（在大臂根部）
    self.handBlockNode = nil
    self.handBlockModel = nil
    self.armSegments = {}
    self.visible = true
    
    -- 动画状态
    self.swingTime = 0
    self.isSwinging = false
    self.swingDuration = 0.15  -- 更快的挥动速度
    self.bobTime = 0
    
    self:createArm()
    
    return self
end

---创建手臂几何体
function FirstPersonArm:createArm()
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    
    -- ============================================
    -- 节点层次结构（用于正确的旋转轴心）：
    -- cameraNode
    --   └── rootNode (位置偏移，不旋转)
    --         └── pivotNode (旋转轴心在大臂根部)
    --               └── armNode (整条手臂)
    --                     ├── upperArm (上臂/袖子)
    --                     ├── lowerArm (下臂/皮肤)
    --                     ├── hand (手掌)
    --                     └── handBlock (手持方块)
    -- ============================================
    
    -- 根节点：位置偏移（屏幕右下角）
    -- X: 正值向右，Y: 负值向下，Z: 正值向前
    self.rootNode = self.cameraNode:CreateChild("FirstPersonArm", LOCAL)
    -- 稍微靠近画面中心，让手臂露出更多
    self.rootNode.position = Vector3(0.50, -0.45, 0.35) * BLOCK_SIZE

    -- 旋转轴心节点：位于大臂根部，动画旋转应用在这里
    self.pivotNode = self.rootNode:CreateChild("ArmPivot", LOCAL)
    self.pivotNode.position = Vector3(0, 0, 0)
    -- 手臂指向准星方向（向前偏左上）
    self.pivotNode.rotation = Quaternion(15, 25, -10)

    -- 手臂容器节点
    local armNode = self.pivotNode:CreateChild("Arm", LOCAL)
    
    -- ============================================
    -- 手臂参数（统一粗细，无缝连接）
    -- ============================================
    local armThickness = 0.15  -- 手臂粗细
    local upperArmLength = 0.28  -- 上臂长度
    local lowerArmLength = 0.38  -- 下臂长度
    local handLength = 0.14      -- 手掌长度
    
    -- 上臂起点偏移（向后，让根部藏在画面边缘外）
    local upperArmOffset = -0.18  -- 向后偏移
    
    -- ============================================
    -- 上臂（袖子）- 大部分藏在画面边缘外
    -- ============================================
    local upperArmNode = armNode:CreateChild("UpperArm", LOCAL)
    -- 上臂向后偏移，让根部藏起来
    upperArmNode.position = Vector3(0, 0, upperArmOffset + upperArmLength * 0.5) * BLOCK_SIZE
    upperArmNode.scale = Vector3(armThickness, armThickness, upperArmLength) * BLOCK_SIZE
    local upperArmModel = upperArmNode:CreateComponent("StaticModel", LOCAL)
    upperArmModel.model = cache:GetResource("Model", "Models/Box.mdl")
    upperArmModel.material = self:createSolidMaterial(ARM_SLEEVE_COLOR)
    table.insert(self.armSegments, upperArmNode)

    -- ============================================
    -- 下臂（皮肤）- 紧接上臂，无缝连接
    -- ============================================
    local lowerArmNode = armNode:CreateChild("LowerArm", LOCAL)
    -- 下臂起点 = 上臂终点（考虑偏移）
    local lowerArmStart = upperArmOffset + upperArmLength
    lowerArmNode.position = Vector3(0, 0, lowerArmStart + lowerArmLength * 0.5) * BLOCK_SIZE
    lowerArmNode.scale = Vector3(armThickness, armThickness, lowerArmLength) * BLOCK_SIZE
    local lowerArmModel = lowerArmNode:CreateComponent("StaticModel", LOCAL)
    lowerArmModel.model = cache:GetResource("Model", "Models/Box.mdl")
    lowerArmModel.material = self:createSolidMaterial(ARM_SKIN_COLOR)
    table.insert(self.armSegments, lowerArmNode)

    -- ============================================
    -- 手掌 - 紧接下臂
    -- ============================================
    local handNode = armNode:CreateChild("Hand", LOCAL)
    local handStart = lowerArmStart + lowerArmLength
    handNode.position = Vector3(0, 0, handStart + handLength * 0.5) * BLOCK_SIZE
    handNode.scale = Vector3(armThickness * 1.1, armThickness * 0.9, handLength) * BLOCK_SIZE
    local handModel = handNode:CreateComponent("StaticModel", LOCAL)
    handModel.model = cache:GetResource("Model", "Models/Box.mdl")
    handModel.material = self:createSolidMaterial(ARM_SKIN_COLOR)
    table.insert(self.armSegments, handNode)

    -- ============================================
    -- 手持方块 - 在手掌前方（使用真实纹理）
    -- ============================================
    self.handBlockNode = armNode:CreateChild("HandBlock", LOCAL)
    local blockStart = handStart + handLength + 0.12
    self.handBlockNode.position = Vector3(0, 0.02, blockStart) * BLOCK_SIZE
    self.handBlockNode.scale = Vector3(1, 1, 1)  -- scale 在 CustomGeometry 中处理
    self.handBlockNode.rotation = Quaternion(0, 45, 0)  -- 稍微旋转更好看

    -- 使用 CustomGeometry 创建带纹理的方块
    self.handBlockGeometry = self.handBlockNode:CreateComponent("CustomGeometry", LOCAL)
    self.handBlockGeometry:SetNumGeometries(1)
    
    -- 保存方块大小
    self.handBlockSize = 0.28 * BLOCK_SIZE
    
    -- 缓存当前方块类型，用于检测变化
    self.currentBlockType = nil
    
    -- ============================================
    -- 火把光源节点（在手持物品位置）
    -- ============================================
    self.torchLightNode = nil
    self.torchLight = nil
    self.torchFlickerTime = 0  -- 火焰闪烁计时器
    
    -- 初始更新方块显示
    self:updateHandBlock()
    
    print("[FirstPersonArm] First person arm created with pivot at shoulder")
end

---创建纯色材质
---@param color Color 颜色
---@return Material 材质
function FirstPersonArm:createSolidMaterial(color)
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    return material
end

---创建方块材质（使用纹理图集）
---@param blockType number 方块类型
---@return Material 材质
function FirstPersonArm:createBlockMaterial(blockType)
    local block = Blocks:get(blockType)
    if not block then
        return self:createSolidMaterial(Color(0.5, 0.5, 0.5))
    end
    
    -- 获取当前材质包
    local pack = TexturePackManager:getCurrent()
    if not pack then
        -- 没有材质包时使用纯色
        return self:createSolidMaterial(block.color)
    end
    
    -- 创建带纹理的材质
    local material = Material:new()
    local textures = pack:generate()
    
    if pack.isPBR and textures.normal and textures.specular then
        -- PBR 材质
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRMetallicRoughDiffNormalSpec.xml"))
        material:SetTexture(TU_DIFFUSE, textures.diffuse)
        material:SetTexture(TU_NORMAL, textures.normal)
        material:SetTexture(TU_SPECULAR, textures.specular)
    else
        -- 普通 Diffuse 材质
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/Diff.xml"))
        material:SetTexture(TU_DIFFUSE, textures.diffuse or textures)
    end
    
    -- 使用方块颜色作为顶点色
    material:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1)))
    
    return material
end

---更新手持方块显示（使用真实纹理）
function FirstPersonArm:updateHandBlock()
    local blockType = self.player:getSelectedBlockType()
    local block = Blocks:get(blockType)
    
    if not block or blockType == Blocks.AIR then
        -- 空气方块时隐藏手持物品
        if self.handBlockNode then
            self.handBlockNode.enabled = false
        end
        -- 隐藏火把光源
        self:setTorchLightEnabled(false)
        return
    end
    
    -- 显示方块
    if self.handBlockNode then
        self.handBlockNode.enabled = true
    end
    
    -- 只有方块类型改变时才重建几何体
    if self.currentBlockType == blockType then
        return
    end
    
    print("[FirstPersonArm] Block type changed from", self.currentBlockType, "to", blockType, "name:", block.name)
    self.currentBlockType = blockType
    
    -- 重新创建 CustomGeometry 组件（确保完全清除旧数据）
    if self.handBlockGeometry then
        self.handBlockNode:RemoveComponent(self.handBlockGeometry)
        self.handBlockGeometry = nil
    end
    self.handBlockGeometry = self.handBlockNode:CreateComponent("CustomGeometry", LOCAL)
    self.handBlockGeometry:SetNumGeometries(1)
    
    -- 根据物品类型选择不同的渲染方式
    if block.isItem then
        -- 手持物品渲染（如火把）
        self:buildItemGeometry(blockType)
        -- 如果有光源，启用火把光源
        if block.hasLight then
            self:setTorchLightEnabled(true, block.lightColor, block.lightRadius)
        else
            self:setTorchLightEnabled(false)
        end
    else
        -- 普通方块渲染
        self:buildBlockGeometry(blockType)
        self:setTorchLightEnabled(false)
    end
end

---构建带纹理的方块几何体
---@param blockType number 方块类型
function FirstPersonArm:buildBlockGeometry(blockType)
    local block = Blocks:get(blockType)
    if not block then 
        print("[FirstPersonArm] ERROR: block is nil for type", blockType)
        return 
    end
    
    local geom = self.handBlockGeometry
    if not geom then
        print("[FirstPersonArm] ERROR: geom is nil")
        return
    end
    
    local size = self.handBlockSize
    local halfSize = size * 0.5
    
    -- 获取纹理包
    local pack = TexturePackManager:getCurrent()
    if not pack then 
        print("[FirstPersonArm] ERROR: no texture pack")
        return 
    end
    
    -- 获取纹理坐标信息
    local tileSize = 1.0 / 16  -- 图集 16x16
    local textures = block.textures or { top = {0,0}, side = {0,0}, bottom = {0,0} }
    
    print("[FirstPersonArm] Building geometry for block:", block.name, 
          "top(row,col):", textures.top[1], textures.top[2],
          "side(row,col):", textures.side[1], textures.side[2])
    
    -- 开始定义几何体（组件是新创建的，无需清除）
    geom:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 定义6个面
    local faces = {
        -- +X 面 (右) - side
        { normal = {1,0,0}, uvIdx = textures.side, verts = {
            {halfSize, -halfSize, -halfSize, 1, 1},
            {halfSize, halfSize, -halfSize, 1, 0},
            {halfSize, halfSize, halfSize, 0, 0},
            {halfSize, -halfSize, -halfSize, 1, 1},
            {halfSize, halfSize, halfSize, 0, 0},
            {halfSize, -halfSize, halfSize, 0, 1},
        }},
        -- -X 面 (左) - side
        { normal = {-1,0,0}, uvIdx = textures.side, verts = {
            {-halfSize, -halfSize, halfSize, 1, 1},
            {-halfSize, halfSize, halfSize, 1, 0},
            {-halfSize, halfSize, -halfSize, 0, 0},
            {-halfSize, -halfSize, halfSize, 1, 1},
            {-halfSize, halfSize, -halfSize, 0, 0},
            {-halfSize, -halfSize, -halfSize, 0, 1},
        }},
        -- +Y 面 (顶) - top
        { normal = {0,1,0}, uvIdx = textures.top, verts = {
            {-halfSize, halfSize, -halfSize, 0, 0},
            {-halfSize, halfSize, halfSize, 0, 1},
            {halfSize, halfSize, halfSize, 1, 1},
            {-halfSize, halfSize, -halfSize, 0, 0},
            {halfSize, halfSize, halfSize, 1, 1},
            {halfSize, halfSize, -halfSize, 1, 0},
        }},
        -- -Y 面 (底) - bottom
        { normal = {0,-1,0}, uvIdx = textures.bottom, verts = {
            {-halfSize, -halfSize, halfSize, 0, 1},
            {-halfSize, -halfSize, -halfSize, 0, 0},
            {halfSize, -halfSize, -halfSize, 1, 0},
            {-halfSize, -halfSize, halfSize, 0, 1},
            {halfSize, -halfSize, -halfSize, 1, 0},
            {halfSize, -halfSize, halfSize, 1, 1},
        }},
        -- +Z 面 (前) - side
        { normal = {0,0,1}, uvIdx = textures.side, verts = {
            {-halfSize, -halfSize, halfSize, 0, 1},
            {halfSize, -halfSize, halfSize, 1, 1},
            {halfSize, halfSize, halfSize, 1, 0},
            {-halfSize, -halfSize, halfSize, 0, 1},
            {halfSize, halfSize, halfSize, 1, 0},
            {-halfSize, halfSize, halfSize, 0, 0},
        }},
        -- -Z 面 (后) - side
        { normal = {0,0,-1}, uvIdx = textures.side, verts = {
            {halfSize, -halfSize, -halfSize, 0, 1},
            {-halfSize, -halfSize, -halfSize, 1, 1},
            {-halfSize, halfSize, -halfSize, 1, 0},
            {halfSize, -halfSize, -halfSize, 0, 1},
            {-halfSize, halfSize, -halfSize, 1, 0},
            {halfSize, halfSize, -halfSize, 0, 0},
        }},
    }
    
    for _, face in ipairs(faces) do
        local uvIdx = face.uvIdx or {0, 0}
        -- textures 格式是 {row, col}，所以 uvIdx[1]=row=v, uvIdx[2]=col=u
        local u0 = uvIdx[2] * tileSize  -- col -> u (水平)
        local v0 = uvIdx[1] * tileSize  -- row -> v (垂直)
        local normal = Vector3(face.normal[1], face.normal[2], face.normal[3])
        
        for _, vert in ipairs(face.verts) do
            local x, y, z, lu, lv = vert[1], vert[2], vert[3], vert[4], vert[5]
            local u = u0 + lu * tileSize
            local v = v0 + lv * tileSize
            geom:DefineVertex(Vector3(x, y, z))
            geom:DefineNormal(normal)
            geom:DefineTexCoord(Vector2(u, v))
        end
    end
    
    geom:Commit()
    
    -- 设置材质
    local material = self:createBlockMaterialWithTexture()
    geom:SetMaterial(0, material)
end

---创建带纹理的方块材质
---@return Material 材质
function FirstPersonArm:createBlockMaterialWithTexture()
    local pack = TexturePackManager:getCurrent()
    if not pack then
        return self:createSolidMaterial(Color(0.5, 0.5, 0.5))
    end
    
    local textures = pack:generate()
    local material = Material:new()
    
    if pack.isPBR and textures.normal and textures.specular then
        -- PBR 材质
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRMetallicRoughDiffNormalSpec.xml"))
        material:SetTexture(TU_DIFFUSE, textures.diffuse)
        material:SetTexture(TU_NORMAL, textures.normal)
        material:SetTexture(TU_SPECULAR, textures.specular)
    else
        -- 普通 Diffuse 材质
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/Diff.xml"))
        material:SetTexture(TU_DIFFUSE, textures.diffuse or textures)
    end
    
    material:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1)))
    
    return material
end

-- ============================================
-- 火把/物品渲染
-- ============================================

---构建手持物品几何体（如火把）
---@param blockType number 物品类型
function FirstPersonArm:buildItemGeometry(blockType)
    local block = Blocks:get(blockType)
    if not block then return end
    
    local geom = self.handBlockGeometry
    if not geom then return end
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    
    -- 火把参数（细长的棍子 + 火焰顶部）
    local stickWidth = 0.04 * BLOCK_SIZE   -- 木棍粗细
    local stickHeight = 0.55 * BLOCK_SIZE  -- 木棍长度（加长）
    local flameWidth = 0.10 * BLOCK_SIZE   -- 火焰宽度
    local flameHeight = 0.15 * BLOCK_SIZE  -- 火焰高度
    
    geom:BeginGeometry(0, TRIANGLE_LIST)
    
    -- 木棍颜色（棕色）
    local stickColor = Color(0.5, 0.3, 0.1)
    -- 火焰颜色（超高亮度自发光，产生强烈 bloom 效果）
    local flameColorBottom = Color(5.0, 3.0, 0.8)  -- 底部橙色（超高亮度）
    local flameColorTop = Color(6.0, 5.0, 2.0)     -- 顶部黄白色（极亮）
    
    local hw = stickWidth * 0.5
    local hh = stickHeight * 0.5
    
    -- ============================================
    -- 绘制木棍（4个面的长方体）
    -- ============================================
    local stickFaces = {
        -- +X 面
        { normal = {1,0,0}, verts = {
            {hw, -hh, -hw}, {hw, hh, -hw}, {hw, hh, hw},
            {hw, -hh, -hw}, {hw, hh, hw}, {hw, -hh, hw},
        }},
        -- -X 面
        { normal = {-1,0,0}, verts = {
            {-hw, -hh, hw}, {-hw, hh, hw}, {-hw, hh, -hw},
            {-hw, -hh, hw}, {-hw, hh, -hw}, {-hw, -hh, -hw},
        }},
        -- +Z 面
        { normal = {0,0,1}, verts = {
            {-hw, -hh, hw}, {hw, -hh, hw}, {hw, hh, hw},
            {-hw, -hh, hw}, {hw, hh, hw}, {-hw, hh, hw},
        }},
        -- -Z 面
        { normal = {0,0,-1}, verts = {
            {hw, -hh, -hw}, {-hw, -hh, -hw}, {-hw, hh, -hw},
            {hw, -hh, -hw}, {-hw, hh, -hw}, {hw, hh, -hw},
        }},
    }
    
    for _, face in ipairs(stickFaces) do
        local normal = Vector3(face.normal[1], face.normal[2], face.normal[3])
        for _, vert in ipairs(face.verts) do
            geom:DefineVertex(Vector3(vert[1], vert[2], vert[3]))
            geom:DefineNormal(normal)
            geom:DefineColor(stickColor)
        end
    end
    
    -- ============================================
    -- 绘制火焰（交叉的两个面，带颜色渐变）
    -- ============================================
    local flameBaseY = hh  -- 火焰底部在木棍顶部
    local flameTopY = hh + flameHeight
    local fhw = flameWidth * 0.5
    
    -- 火焰面1（X-Y平面）
    local flameFace1 = {
        {-fhw, flameBaseY, 0, flameColorBottom},
        {fhw, flameBaseY, 0, flameColorBottom},
        {fhw * 0.3, flameTopY, 0, flameColorTop},
        {-fhw, flameBaseY, 0, flameColorBottom},
        {fhw * 0.3, flameTopY, 0, flameColorTop},
        {-fhw * 0.3, flameTopY, 0, flameColorTop},
    }
    
    -- 火焰面2（Y-Z平面，与面1交叉）
    local flameFace2 = {
        {0, flameBaseY, -fhw, flameColorBottom},
        {0, flameBaseY, fhw, flameColorBottom},
        {0, flameTopY, fhw * 0.3, flameColorTop},
        {0, flameBaseY, -fhw, flameColorBottom},
        {0, flameTopY, fhw * 0.3, flameColorTop},
        {0, flameTopY, -fhw * 0.3, flameColorTop},
    }
    
    -- 绘制两个火焰面（双面）
    for _, face in ipairs({flameFace1, flameFace2}) do
        -- 正面
        for _, vert in ipairs(face) do
            geom:DefineVertex(Vector3(vert[1], vert[2], vert[3]))
            geom:DefineNormal(Vector3(0, 0, 1))
            geom:DefineColor(vert[4])
        end
        -- 背面（反向顶点顺序）
        for i = #face, 1, -1 do
            local vert = face[i]
            geom:DefineVertex(Vector3(vert[1], vert[2], vert[3]))
            geom:DefineNormal(Vector3(0, 0, -1))
            geom:DefineColor(vert[4])
        end
    end
    
    geom:Commit()
    
    -- 使用 Unlit 自发光材质（不受光照影响，火焰始终明亮）
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlitVCol.xml"))
    geom:SetMaterial(0, material)
    
    print("[FirstPersonArm] Built torch geometry (longer stick, brighter flame)")
end

---设置火把光源启用状态
---@param enabled boolean 是否启用
---@param lightColor Color|nil 光源颜色
---@param lightRadius number|nil 光源范围
function FirstPersonArm:setTorchLightEnabled(enabled, lightColor, lightRadius)
    if enabled then
        -- 创建或更新光源
        if not self.torchLightNode then
            self.torchLightNode = self.handBlockNode:CreateChild("TorchLight", LOCAL)
            self.torchLightNode.position = Vector3(0, 0.3, 0)  -- 火焰顶部位置

            self.torchLight = self.torchLightNode:CreateComponent("Light", LOCAL)
            self.torchLight.lightType = LIGHT_POINT
            self.torchLight.castShadows = false  -- 手持光源不投射阴影（性能考虑）
        end
        
        -- 设置光源参数
        self.torchLight.color = lightColor or Color(1.0, 0.8, 0.4)
        self.torchLight.range = (lightRadius or 12) * Config.World.BLOCK_SIZE
        self.torchLight.brightness = 5.0  -- 超亮光源，产生强 bloom
        self.torchLightNode.enabled = true
        
        print("[FirstPersonArm] Torch light enabled")
    else
        -- 禁用光源
        if self.torchLightNode then
            self.torchLightNode.enabled = false
        end
    end
end

---更新火把闪烁效果
---@param timeStep number 时间步长
function FirstPersonArm:updateTorchFlicker(timeStep)
    if not self.torchLight or not self.torchLightNode or not self.torchLightNode.enabled then
        return
    end
    
    self.torchFlickerTime = self.torchFlickerTime + timeStep
    
    -- 使用多个正弦波叠加产生自然的闪烁效果
    local flicker = 1.0 
        + math.sin(self.torchFlickerTime * 8) * 0.15
        + math.sin(self.torchFlickerTime * 13) * 0.08
        + math.sin(self.torchFlickerTime * 21) * 0.05
    
    -- 亮度在 4.0 到 6.0 之间波动，产生强烈 bloom
    self.torchLight.brightness = 5.0 * flicker
    
    -- 颜色也稍微变化（更红/更黄）
    local colorShift = math.sin(self.torchFlickerTime * 5) * 0.05
    self.torchLight.color = Color(1.0, 0.8 + colorShift, 0.4 - colorShift * 0.5)
end

---触发挥动动画（攻击/放置方块时调用）
function FirstPersonArm:swing()
    self.isSwinging = true
    self.swingTime = 0
end

---更新（每帧调用）
---@param timeStep number 时间步长
function FirstPersonArm:update(timeStep)
    if not self.visible or not self.rootNode then
        return
    end
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    
    -- ============================================
    -- 行走摇晃动画（Bob）
    -- ============================================
    local velocity = self.player:getVelocity()
    local isMoving = math.abs(velocity.x) > 0.1 or math.abs(velocity.z) > 0.1
    
    if isMoving and self.player:getOnGround() then
        self.bobTime = self.bobTime + timeStep * 8
    else
        -- 缓慢回归
        self.bobTime = self.bobTime + timeStep * 2
    end
    
    local bobX = math.sin(self.bobTime) * 0.03
    local bobY = math.abs(math.cos(self.bobTime * 2)) * 0.02
    
    if not isMoving then
        bobX = bobX * 0.2
        bobY = bobY * 0.2
    end
    
    -- ============================================
    -- 挥动动画（Swing）- 向下砸的动作
    -- 旋转应用到 pivotNode，轴心在大臂根部
    -- ============================================
    local swingPitch = 0  -- 围绕 X 轴旋转（上下摆动）
    
    if self.isSwinging then
        self.swingTime = self.swingTime + timeStep
        local progress = self.swingTime / self.swingDuration
        
        if progress >= 1 then
            self.isSwinging = false
            self.swingTime = 0
        else
            -- 向下砸的动作曲线：先快速抬起，然后用力砸下
            -- 使用非对称曲线：前20%上抬，后80%下砸
            -- 幅度适中，避免暴露根部
            if progress < 0.2 then
                -- 快速上抬阶段（手臂抬起，pitch 减小）
                local upProgress = progress / 0.2
                swingPitch = -15 * math.sin(upProgress * math.pi * 0.5)
            else
                -- 用力下砸阶段（手臂砸下，pitch 增大）
                local downProgress = (progress - 0.2) / 0.8
                swingPitch = -15 + 35 * math.sin(downProgress * math.pi * 0.5)
            end
        end
    end
    
    -- ============================================
    -- 应用动画
    -- ============================================
    
    -- 根节点位置（加上行走摇晃）
    local baseOffset = Vector3(0.50, -0.45, 0.35)
    local animatedPos = (baseOffset + Vector3(bobX, bobY, 0)) * BLOCK_SIZE
    self.rootNode.position = animatedPos
    
    -- 旋转应用到轴心节点（大臂根部）
    -- 手臂指向准星方向（向前偏左上）
    local basePitch = 15   -- 前倾角度（小 = 更水平）
    local baseYaw = 25     -- 向左偏（正 = 向左）
    local baseRoll = -10   -- 侧倾
    if self.pivotNode then
        self.pivotNode.rotation = Quaternion(basePitch + swingPitch, baseYaw, baseRoll)
    end
    
    -- ============================================
    -- 检查方块选择变化
    -- ============================================
    self:updateHandBlock()
    
    -- ============================================
    -- 更新火把闪烁效果
    -- ============================================
    self:updateTorchFlicker(timeStep)
end

---设置可见性
---@param visible boolean 是否可见
function FirstPersonArm:setVisible(visible)
    self.visible = visible
    if self.rootNode then
        self.rootNode.enabled = visible
    end
end

---获取可见性
---@return boolean 是否可见
function FirstPersonArm:isVisible()
    return self.visible
end

---销毁
function FirstPersonArm:destroy()
    -- 清理火把光源
    if self.torchLightNode then
        self.torchLightNode:Remove()
        self.torchLightNode = nil
        self.torchLight = nil
    end
    
    if self.rootNode then
        self.rootNode:Remove()
        self.rootNode = nil
    end
    self.armSegments = {}
    print("[FirstPersonArm] First person arm destroyed")
end

return FirstPersonArm

