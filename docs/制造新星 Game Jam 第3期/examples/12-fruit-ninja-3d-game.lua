-- ============================================================================
-- 3D Fruit Ninja - 3D 水果忍者
-- 基于 UrhoX 引擎开发
-- ============================================================================
--
-- 玩法说明:
--   - 水果从屏幕底部抛出
--   - 用鼠标/触摸滑动切割水果
--   - 切到水果得分，水果分裂成两半
--   - 漏掉水果扣生命
--   - 切到炸弹游戏结束
--
-- 控制:
--   - 鼠标左键拖动: 切割
--   - ESC: 退出
--
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- 引入 Primitives 库（半球、弧形等自定义几何体）
local Primitives = require "urhox-libs.Geometry.Primitives"

-- ============================================================================
-- 1. 配置常量
-- ============================================================================

local CONFIG = {
    -- 游戏设置
    Title = "3D Fruit Ninja",

    -- 相机设置 (正面视角)
    CameraPos = Vector3(0, 3, -15),  -- 相机位置
    CameraTarget = Vector3(0, 3, 0), -- 看向的目标点

    -- 游戏区域 (单位: 米)
    AreaWidth = 16,      -- X: -8 到 8
    AreaHeight = 12,     -- Y: -2 到 10
    SpawnY = -3,         -- 水果生成Y位置
    DestroyY = -5,       -- 水果销毁Y位置

    -- 水果设置
    FruitSpawnInterval = 0.8,    -- 生成间隔 (秒)
    FruitSpawnCount = 1,         -- 每次生成数量 (1-3)
    FruitMinVelocityY = 15,      -- 最小向上速度
    FruitMaxVelocityY = 20,      -- 最大向上速度
    FruitMaxVelocityX = 5,       -- 最大水平速度
    FruitAngularSpeed = 6,       -- 旋转速度

    -- 炸弹设置
    BombChance = 0.15,           -- 炸弹出现概率 (15%)
    BombRadius = 0.35,           -- 炸弹半径 (较小)

    -- 游戏规则
    MaxLives = 3,                -- 最大生命值
    ScorePerFruit = 10,          -- 每个水果得分
    ComboMultiplier = 1.5,       -- 连击加成

    -- 物理设置
    Gravity = Vector3(0, -20, 0), -- 重力

    -- 切割设置
    SlashMinDistance = 20,       -- 最小滑动距离 (像素)
    SlashTrailLength = 10,       -- 轨迹点数量
}

-- 水果类型定义 (优化材质参数 + 不同大小 + 椭圆形状)
-- shape: {x, y, z} 缩放比例，nil 表示球形
-- weight: 出现权重，数值越大出现概率越高
local FRUIT_TYPES = {
    {
        name = "Apple",
        radius = 0.6,
        shape = {1.0, 0.9, 1.0},                   -- 略扁
        weight = 20,                                -- 中等大小，高概率
        color = Color(0.85, 0.12, 0.12, 1.0),
        innerColor = Color(1.0, 0.98, 0.85, 1.0),
        metallic = 0.0,
        roughness = 0.25,
        emissive = Color(0.15, 0.02, 0.02, 1.0),
        emissiveMul = 0.3,
    },
    {
        name = "Orange",
        radius = 0.65,
        shape = nil,                                -- 球形
        weight = 20,                                -- 中等大小，高概率
        color = Color(1.0, 0.55, 0.0, 1.0),
        innerColor = Color(1.0, 0.75, 0.3, 1.0),
        metallic = 0.0,
        roughness = 0.45,
        emissive = Color(0.2, 0.1, 0.0, 1.0),
        emissiveMul = 0.2,
    },
    {
        name = "Watermelon",
        radius = 1.0,                               -- 最大
        shape = {1.2, 0.85, 1.0},                  -- 横向椭圆
        weight = 5,                                 -- 最大，低概率
        color = Color(0.2, 0.6, 0.25, 1.0),        -- 浅绿色
        innerColor = Color(0.95, 0.25, 0.25, 1.0), -- 红色果肉
        metallic = 0.0,
        roughness = 0.35,
        emissive = Color(0.02, 0.1, 0.03, 1.0),
        emissiveMul = 0.2,
    },
    {
        name = "Lemon",
        radius = 0.5,
        shape = {0.7, 1.0, 0.7},                   -- 纵向椭圆
        weight = 15,                                -- 中等
        color = Color(1.0, 0.92, 0.15, 1.0),
        innerColor = Color(1.0, 1.0, 0.75, 1.0),
        metallic = 0.0,
        roughness = 0.3,
        emissive = Color(0.2, 0.18, 0.02, 1.0),
        emissiveMul = 0.25,
    },
    {
        name = "Banana",
        radius = 0.55,
        shape = {0.5, 1.3, 0.5},                   -- 细长
        weight = 15,                                -- 中等
        color = Color(1.0, 0.85, 0.2, 1.0),
        innerColor = Color(1.0, 0.95, 0.7, 1.0),
        metallic = 0.0,
        roughness = 0.35,
        emissive = Color(0.2, 0.15, 0.02, 1.0),
        emissiveMul = 0.25,
    },
    {
        name = "Grape",
        radius = 0.4,                               -- 最小
        shape = nil,
        weight = 8,                                 -- 小，较低概率
        color = Color(0.45, 0.15, 0.55, 1.0),
        innerColor = Color(0.75, 0.55, 0.85, 1.0),
        metallic = 0.05,
        roughness = 0.15,
        emissive = Color(0.08, 0.02, 0.1, 1.0),
        emissiveMul = 0.3,
    },
    {
        name = "Pear",
        radius = 0.6,
        shape = {0.8, 1.1, 0.8},                   -- 梨形
        weight = 17,                                -- 中等大小，较高概率
        color = Color(0.75, 0.8, 0.25, 1.0),
        innerColor = Color(0.95, 0.95, 0.8, 1.0),
        metallic = 0.0,
        roughness = 0.3,
        emissive = Color(0.12, 0.13, 0.03, 1.0),
        emissiveMul = 0.2,
    },
}

-- 计算总权重，用于加权随机
local FRUIT_TOTAL_WEIGHT = 0
for _, fruit in ipairs(FRUIT_TYPES) do
    FRUIT_TOTAL_WEIGHT = FRUIT_TOTAL_WEIGHT + (fruit.weight or 10)
end

-- 根据权重随机选择水果
function SelectRandomFruit()
    local rand = math.random() * FRUIT_TOTAL_WEIGHT
    local cumulative = 0
    for _, fruit in ipairs(FRUIT_TYPES) do
        cumulative = cumulative + (fruit.weight or 10)
        if rand <= cumulative then
            return fruit
        end
    end
    return FRUIT_TYPES[1]  -- fallback
end

-- ============================================================================
-- 2. 全局变量
-- ============================================================================

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Camera
local camera_ = nil
---@type Octree
local octree_ = nil
---@type PhysicsWorld
local physicsWorld_ = nil

-- NanoVG 上下文
local nvg_ = nil
local nvgFont_ = -1

-- 游戏状态
local GameState = {
    MENU = 1,
    PLAYING = 2,
    GAMEOVER = 3,
}
local gameState_ = GameState.MENU
local score_ = 0
local lives_ = CONFIG.MaxLives
local combo_ = 0
local comboTimer_ = 0

-- 水果管理
local fruits_ = {}           -- 活跃的水果列表
local fruitHalves_ = {}      -- 切割后的半水果
local spawnTimer_ = 0        -- 生成计时器

-- 切割系统
local slashPoints_ = {}      -- 滑动轨迹点
local isSlashing_ = false    -- 是否正在滑动
local slashedFruits_ = {}    -- 本次滑动已切割的水果 (防止重复切割)

-- 特效
local scorePopups_ = {}      -- 分数弹出动画

-- 屏幕尺寸
local screenWidth_ = 0
local screenHeight_ = 0

-- ============================================================================
-- 3. 生命周期函数
-- ============================================================================

function Start()
    SampleStart()
    graphics.windowTitle = CONFIG.Title

    -- 获取屏幕尺寸
    screenWidth_ = graphics:GetWidth()
    screenHeight_ = graphics:GetHeight()

    -- 初始化
    CreateScene()
    SetupCamera()
    InitNanoVG()
    SubscribeToEvents()

    print("=== 3D Fruit Ninja Started ===")
end

function Stop()
    if nvg_ then
        nvgDelete(nvg_)
        nvg_ = nil
    end
    print("=== Game Stopped ===")
end

-- ============================================================================
-- 4. 场景初始化
-- ============================================================================

function CreateScene()
    scene_ = Scene()

    -- 创建八叉树
    octree_ = scene_:CreateComponent("Octree")

    -- 创建调试渲染器
    scene_:CreateComponent("DebugRenderer")

    -- 创建物理世界
    physicsWorld_ = scene_:CreateComponent("PhysicsWorld")
    physicsWorld_:SetGravity(CONFIG.Gravity)

    -- 加载光照
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    -- 创建背景 (简单的深色平面)
    CreateBackground()
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = CONFIG.CameraPos

    camera_ = cameraNode_:CreateComponent("Camera")
    camera_.nearClip = 0.1
    camera_.farClip = 100.0
    camera_.fov = 60.0

    -- 让相机看向目标点
    cameraNode_:LookAt(CONFIG.CameraTarget)

    -- 设置视口
    local viewport = Viewport:new(scene_, camera_)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true
end

function CreateBackground()
    -- 创建主背景 (深蓝色木质风格)
    local bgNode = scene_:CreateChild("Background")
    bgNode.position = Vector3(0, 3, 6)
    bgNode.scale = Vector3(35, 25, 0.5)

    local bgModel = bgNode:CreateComponent("StaticModel")
    bgModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local bgMat = Material:new()
    bgMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    bgMat:SetShaderParameter("MatDiffColor", Variant(Color(0.08, 0.1, 0.15, 1.0)))  -- 深蓝黑色
    bgMat:SetShaderParameter("Metallic", Variant(0.0))
    bgMat:SetShaderParameter("Roughness", Variant(0.75))  -- 木质粗糙度
    bgModel:SetMaterial(bgMat)
    bgModel.castShadows = false

    -- 创建装饰性边框 (左)
    CreateBorderDecoration(Vector3(-12, 3, 4), Vector3(0.3, 18, 0.3), Color(0.4, 0.25, 0.15, 1.0))
    -- 创建装饰性边框 (右)
    CreateBorderDecoration(Vector3(12, 3, 4), Vector3(0.3, 18, 0.3), Color(0.4, 0.25, 0.15, 1.0))

    -- 创建底部木板
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(0, -4, 3)
    floorNode.scale = Vector3(30, 1, 4)

    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.22, 0.12, 1.0)))  -- 木头颜色
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorMat:SetShaderParameter("Roughness", Variant(0.7))
    floorModel:SetMaterial(floorMat)
    floorModel.castShadows = false
end

function CreateBorderDecoration(pos, scale, color)
    local node = scene_:CreateChild("Border")
    node.position = pos
    node.scale = scale

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.65))
    model:SetMaterial(mat)
    model.castShadows = true
end

function InitNanoVG()
    nvg_ = nvgCreate(1)  -- 1 = NVG_ANTIALIAS
    if nvg_ then
        nvgFont_ = nvgCreateFont(nvg_, "sans", "Fonts/MiSans-Regular.ttf")
    end
end

-- ============================================================================
-- 5. 事件处理
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(nvg_, "NanoVGRender", "HandleRenderUI")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
end

function HandleScreenMode(eventType, eventData)
    screenWidth_ = graphics:GetWidth()
    screenHeight_ = graphics:GetHeight()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if gameState_ == GameState.PLAYING then
        UpdateGameLogic(dt)
    end

    -- 更新特效
    UpdateEffects(dt)
end

function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        if gameState_ == GameState.MENU then
            StartGame()
        elseif gameState_ == GameState.GAMEOVER then
            RestartGame()
        elseif gameState_ == GameState.PLAYING then
            StartSlash(input.mousePosition.x, input.mousePosition.y)
        end
    end
end

function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        EndSlash()
    end
end

function HandleMouseMove(eventType, eventData)
    if isSlashing_ and gameState_ == GameState.PLAYING then
        UpdateSlash(input.mousePosition.x, input.mousePosition.y)
    end
end

function HandleTouchBegin(eventType, eventData)
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()

    if gameState_ == GameState.MENU then
        StartGame()
    elseif gameState_ == GameState.GAMEOVER then
        RestartGame()
    elseif gameState_ == GameState.PLAYING then
        StartSlash(x, y)
    end
end

function HandleTouchEnd(eventType, eventData)
    EndSlash()
end

function HandleTouchMove(eventType, eventData)
    if isSlashing_ and gameState_ == GameState.PLAYING then
        local x = eventData["X"]:GetInt()
        local y = eventData["Y"]:GetInt()
        UpdateSlash(x, y)
    end
end

-- ============================================================================
-- 6. 游戏逻辑
-- ============================================================================

function StartGame()
    gameState_ = GameState.PLAYING
    score_ = 0
    lives_ = CONFIG.MaxLives
    combo_ = 0
    comboTimer_ = 0

    -- 清除所有水果
    ClearAllFruits()

    print("Game Started!")
end

function RestartGame()
    StartGame()
end

function GameOver()
    gameState_ = GameState.GAMEOVER
    print("Game Over! Final Score: " .. score_)
end

function UpdateGameLogic(dt)
    -- 更新生成计时器
    spawnTimer_ = spawnTimer_ + dt
    if spawnTimer_ >= CONFIG.FruitSpawnInterval then
        spawnTimer_ = 0
        SpawnFruits()
    end

    -- 更新连击计时器
    if combo_ > 0 then
        comboTimer_ = comboTimer_ + dt
        if comboTimer_ > 1.5 then
            combo_ = 0
            comboTimer_ = 0
        end
    end

    -- 更新水果
    UpdateFruits(dt)

    -- 更新半水果
    UpdateFruitHalves(dt)
end

function ClearAllFruits()
    for _, fruit in ipairs(fruits_) do
        if fruit.node then
            fruit.node:Remove()
        end
    end
    fruits_ = {}

    for _, half in ipairs(fruitHalves_) do
        if half.node then
            half.node:Remove()
        end
    end
    fruitHalves_ = {}
end

-- ============================================================================
-- 7. 水果系统
-- ============================================================================

function SpawnFruits()
    local count = math.random(1, CONFIG.FruitSpawnCount)

    for i = 1, count do
        -- 随机决定是水果还是炸弹
        if math.random() < CONFIG.BombChance then
            SpawnBomb()
        else
            SpawnFruit()
        end
    end
end

function SpawnFruit()
    -- 使用加权随机选择水果类型
    local fruitType = SelectRandomFruit()
    local radius = fruitType.radius or 0.5  -- 使用水果自己的大小

    -- 随机位置 (在底部区域)
    local x = (math.random() - 0.5) * CONFIG.AreaWidth * 0.8
    local y = CONFIG.SpawnY
    local z = 0

    -- 创建水果节点
    local node = scene_:CreateChild("Fruit")
    node.position = Vector3(x, y, z)

    -- 添加模型
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

    -- 设置PBR材质 (优化: 使用水果特定的材质参数)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(fruitType.color))
    mat:SetShaderParameter("Metallic", Variant(fruitType.metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(fruitType.roughness or 0.3))
    -- 添加自发光效果让水果更鲜艳
    if fruitType.emissive then
        -- PBRNoTexture 的发光颜色直接通过颜色值强度控制
        local emissiveColor = fruitType.emissive
        local emissiveMul = fruitType.emissiveMul or 0.2
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
            emissiveColor.r * emissiveMul * 5,
            emissiveColor.g * emissiveMul * 5,
            emissiveColor.b * emissiveMul * 5
        )))
    end
    model:SetMaterial(mat)
    model.castShadows = true

    -- 设置缩放 (Sphere模型直径为1，所以缩放 = 半径 * 2)
    -- 支持椭圆形状
    local diameter = radius * 2
    if fruitType.shape then
        node.scale = Vector3(
            diameter * fruitType.shape[1],
            diameter * fruitType.shape[2],
            diameter * fruitType.shape[3]
        )
    else
        node.scale = Vector3(diameter, diameter, diameter)
    end

    -- 添加物理刚体 (大水果更重)
    local body = node:CreateComponent("RigidBody")
    body:SetMass(0.1 + radius * 0.3)  -- 质量随大小变化
    body:SetFriction(0.5)
    body:SetRestitution(0.3)
    body:SetCollisionLayer(1)
    body:SetCollisionMask(0)  -- 不与其他物体碰撞，只受重力

    -- 添加碰撞形状
    local shape = node:CreateComponent("CollisionShape")
    shape:SetSphere(diameter)

    -- 计算初速度
    local velocityY = CONFIG.FruitMinVelocityY + math.random() * (CONFIG.FruitMaxVelocityY - CONFIG.FruitMinVelocityY)
    local velocityX = (math.random() - 0.5) * CONFIG.FruitMaxVelocityX * 2
    -- 如果水果在左边，给它向右的速度，反之亦然
    if x < 0 then
        velocityX = math.abs(velocityX)
    else
        velocityX = -math.abs(velocityX)
    end

    body:SetLinearVelocity(Vector3(velocityX, velocityY, 0))

    -- 添加旋转
    local angularVel = Vector3(
        (math.random() - 0.5) * CONFIG.FruitAngularSpeed * 2,
        (math.random() - 0.5) * CONFIG.FruitAngularSpeed * 2,
        (math.random() - 0.5) * CONFIG.FruitAngularSpeed * 2
    )
    body:SetAngularVelocity(angularVel)

    -- 记录水果数据
    local fruit = {
        node = node,
        body = body,
        fruitType = fruitType,
        isBomb = false,
        radius = radius,  -- 使用水果自己的大小
    }
    table.insert(fruits_, fruit)
end

function SpawnBomb()
    -- 随机位置 (在底部区域)
    local x = (math.random() - 0.5) * CONFIG.AreaWidth * 0.8
    local y = CONFIG.SpawnY
    local z = 0

    -- 创建炸弹节点
    local node = scene_:CreateChild("Bomb")
    node.position = Vector3(x, y, z)

    -- 创建炸弹主体 (优化: 金属质感黑色炸弹)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.05, 0.05, 0.08, 1.0)))  -- 深黑色
    mat:SetShaderParameter("Metallic", Variant(0.85))   -- 高金属度
    mat:SetShaderParameter("Roughness", Variant(0.25))  -- 光滑金属表面
    model:SetMaterial(mat)
    model.castShadows = true

    node.scale = Vector3(CONFIG.BombRadius * 2, CONFIG.BombRadius * 2, CONFIG.BombRadius * 2)

    -- 创建引信 (优化: 发光的燃烧引信)
    local fuseNode = node:CreateChild("Fuse")
    fuseNode.position = Vector3(0, 0.6, 0)
    fuseNode.scale = Vector3(0.12, 0.35, 0.12)

    local fuseModel = fuseNode:CreateComponent("StaticModel")
    fuseModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))

    local fuseMat = Material:new()
    fuseMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    fuseMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.25, 0.1, 1.0)))  -- 棕色绳子
    fuseMat:SetShaderParameter("Metallic", Variant(0.0))
    fuseMat:SetShaderParameter("Roughness", Variant(0.85))
    fuseModel:SetMaterial(fuseMat)

    -- 创建引信火焰 (小球体，发光效果)
    local sparkNode = node:CreateChild("Spark")
    sparkNode.position = Vector3(0, 0.85, 0)
    sparkNode.scale = Vector3(0.15, 0.15, 0.15)

    local sparkModel = sparkNode:CreateComponent("StaticModel")
    sparkModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

    local sparkMat = Material:new()
    sparkMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    sparkMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.6, 0.1, 1.0)))  -- 橙色火焰
    sparkMat:SetShaderParameter("Metallic", Variant(0.0))
    sparkMat:SetShaderParameter("Roughness", Variant(0.5))
    sparkMat:SetShaderParameter("MatEmissiveColor", Variant(Color(3.0, 1.2, 0.0)))  -- 强烈发光 (颜色值 * 强度)
    sparkModel:SetMaterial(sparkMat)

    -- 添加物理刚体
    local body = node:CreateComponent("RigidBody")
    body:SetMass(0.3)
    body:SetFriction(0.5)
    body:SetRestitution(0.2)
    body:SetCollisionLayer(1)
    body:SetCollisionMask(0)

    local shape = node:CreateComponent("CollisionShape")
    shape:SetSphere(CONFIG.BombRadius * 2)

    -- 计算初速度
    local velocityY = CONFIG.FruitMinVelocityY + math.random() * (CONFIG.FruitMaxVelocityY - CONFIG.FruitMinVelocityY)
    local velocityX = (math.random() - 0.5) * CONFIG.FruitMaxVelocityX * 2
    if x < 0 then
        velocityX = math.abs(velocityX)
    else
        velocityX = -math.abs(velocityX)
    end

    body:SetLinearVelocity(Vector3(velocityX, velocityY, 0))
    body:SetAngularVelocity(Vector3(
        (math.random() - 0.5) * CONFIG.FruitAngularSpeed,
        (math.random() - 0.5) * CONFIG.FruitAngularSpeed,
        (math.random() - 0.5) * CONFIG.FruitAngularSpeed
    ))

    local bomb = {
        node = node,
        body = body,
        fruitType = { name = "Bomb", color = Color(0.1, 0.1, 0.1, 1.0), innerColor = Color(0.3, 0.3, 0.3, 1.0) },
        isBomb = true,
        radius = CONFIG.BombRadius,
    }
    table.insert(fruits_, bomb)
end

function UpdateFruits(dt)
    local toRemove = {}

    for i, fruit in ipairs(fruits_) do
        if fruit.node then
            local pos = fruit.node.position

            -- 检查是否超出边界 (掉落)
            if pos.y < CONFIG.DestroyY then
                table.insert(toRemove, i)
                fruit.node:Remove()

                -- 漏掉水果扣生命 (炸弹除外)
                if not fruit.isBomb then
                    lives_ = lives_ - 1
                    combo_ = 0

                    if lives_ <= 0 then
                        GameOver()
                    end
                end
            end
        else
            table.insert(toRemove, i)
        end
    end

    -- 移除已销毁的水果
    for i = #toRemove, 1, -1 do
        table.remove(fruits_, toRemove[i])
    end
end

function UpdateFruitHalves(dt)
    local toRemove = {}

    for i, half in ipairs(fruitHalves_) do
        if half.node then
            local pos = half.node.position
            half.lifetime = half.lifetime + dt

            -- 超出边界或存在时间过长则删除
            if pos.y < CONFIG.DestroyY - 2 or half.lifetime > 3.0 then
                table.insert(toRemove, i)
                half.node:Remove()
            end
        else
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(fruitHalves_, toRemove[i])
    end
end

-- ============================================================================
-- 8. 切割系统
-- ============================================================================

function StartSlash(x, y)
    isSlashing_ = true
    slashPoints_ = {{ x = x, y = y, time = 0 }}
    slashedFruits_ = {}
end

function EndSlash()
    isSlashing_ = false
end

function UpdateSlash(x, y)
    -- 添加新的轨迹点
    table.insert(slashPoints_, { x = x, y = y, time = 0 })

    -- 限制轨迹点数量
    while #slashPoints_ > CONFIG.SlashTrailLength do
        table.remove(slashPoints_, 1)
    end

    -- 检测切割
    if #slashPoints_ >= 2 then
        local p1 = slashPoints_[#slashPoints_ - 1]
        local p2 = slashPoints_[#slashPoints_]

        -- 计算滑动距离
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > CONFIG.SlashMinDistance / 10 then
            CheckSlashCollision(p1.x, p1.y, p2.x, p2.y)
        end
    end
end

function CheckSlashCollision(x1, y1, x2, y2)
    -- 遍历所有水果，检测是否被切割
    for i, fruit in ipairs(fruits_) do
        if fruit.node and not slashedFruits_[fruit.node] then
            -- 将水果的3D位置转换为屏幕坐标
            local worldPos = fruit.node.position
            local screenPos = camera_:WorldToScreenPoint(worldPos)

            -- 转换为像素坐标
            local fruitScreenX = screenPos.x * screenWidth_
            local fruitScreenY = screenPos.y * screenHeight_

            -- 计算水果在屏幕上的半径 (近似)
            local distance = (worldPos - cameraNode_.position):Length()
            local screenRadius = (fruit.radius / distance) * screenHeight_ * 0.8

            -- 检测线段与圆的碰撞
            if LineCircleIntersection(x1, y1, x2, y2, fruitScreenX, fruitScreenY, screenRadius) then
                slashedFruits_[fruit.node] = true

                if fruit.isBomb then
                    -- 切到炸弹
                    ExplodeBomb(fruit, i)
                else
                    -- 切割水果
                    SliceFruit(fruit, i, x2 - x1, y2 - y1)
                end
            end
        end
    end
end

function LineCircleIntersection(x1, y1, x2, y2, cx, cy, r)
    -- 线段与圆的碰撞检测
    local dx = x2 - x1
    local dy = y2 - y1
    local fx = x1 - cx
    local fy = y1 - cy

    local a = dx * dx + dy * dy
    local b = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - r * r

    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return false
    end

    discriminant = math.sqrt(discriminant)
    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)

    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
end

-- ============================================================================
-- 9. 水果分裂效果 (CustomGeometry 半球)
-- ============================================================================

function SliceFruit(fruit, index, slashDirX, slashDirY)
    local pos = fruit.node.position
    local vel = fruit.body:GetLinearVelocity()
    local angVel = fruit.body:GetAngularVelocity()
    local fruitType = fruit.fruitType
    local radius = fruit.radius

    -- 移除原水果
    fruit.node:Remove()
    table.remove(fruits_, index)

    -- 计算切割方向 (在3D空间中)
    local slashLen = math.sqrt(slashDirX * slashDirX + slashDirY * slashDirY)
    if slashLen < 0.001 then slashLen = 1 end
    local slashNormX = slashDirX / slashLen
    local slashNormY = slashDirY / slashLen

    -- 将屏幕方向转换为3D空间的分离方向
    -- 屏幕X → 世界X, 屏幕Y → 世界Y
    local separationDir = Vector3(-slashNormY, slashNormX, 0):Normalized()
    local separationSpeed = 3.0

    -- 创建两个半球
    CreateFruitHalf(pos, vel, angVel, fruitType, radius, separationDir * separationSpeed, true)
    CreateFruitHalf(pos, vel, angVel, fruitType, radius, separationDir * (-separationSpeed), false)

    -- 更新分数
    combo_ = combo_ + 1
    comboTimer_ = 0
    local scoreGain = math.floor(CONFIG.ScorePerFruit * (1 + (combo_ - 1) * 0.5))
    score_ = score_ + scoreGain

    -- 添加分数弹出动画
    AddScorePopup(pos, scoreGain, combo_)

    print("Sliced " .. fruitType.name .. "! +" .. scoreGain .. " (Combo x" .. combo_ .. ")")
end

function CreateFruitHalf(pos, vel, angVel, fruitType, radius, extraVel, isTop)
    local node = scene_:CreateChild("FruitHalf")
    node.position = pos

    -- 使用 Primitives 库创建半球（替代原来 100+ 行的 CreateHemisphereGeometry）
    local geom = Primitives.Hemisphere(node, {
        radius = radius,
        segments = 12,
        isUpper = isTop,
        outerColor = fruitType.color,
        innerColor = fruitType.innerColor,
    })

    -- 添加物理
    local body = node:CreateComponent("RigidBody")
    body:SetMass(0.1)
    body:SetFriction(0.5)
    body:SetRestitution(0.2)
    body:SetCollisionLayer(2)
    body:SetCollisionMask(0)

    local shape = node:CreateComponent("CollisionShape")
    shape:SetSphere(radius)

    -- 设置速度
    body:SetLinearVelocity(vel + extraVel)
    body:SetAngularVelocity(angVel + Vector3(
        (math.random() - 0.5) * 10,
        (math.random() - 0.5) * 10,
        (math.random() - 0.5) * 10
    ))

    local half = {
        node = node,
        body = body,
        lifetime = 0,
    }
    table.insert(fruitHalves_, half)
end

-- 注：CreateHemisphereGeometry 已被 Primitives.Hemisphere 替代
-- 详见 urhox-libs/Geometry/Primitives.lua

-- ============================================================================
-- 10. 炸弹爆炸
-- ============================================================================

function ExplodeBomb(bomb, index)
    local pos = bomb.node.position

    -- 移除炸弹
    bomb.node:Remove()
    table.remove(fruits_, index)

    -- 游戏结束
    print("BOOM! You hit a bomb!")
    GameOver()
end

-- ============================================================================
-- 11. 特效系统
-- ============================================================================

function AddScorePopup(worldPos, score, combo)
    -- 将3D位置转换为屏幕坐标
    local screenPos = camera_:WorldToScreenPoint(worldPos)

    table.insert(scorePopups_, {
        x = screenPos.x * screenWidth_,
        y = screenPos.y * screenHeight_,
        score = score,
        combo = combo,
        lifetime = 0,
        maxLifetime = 1.0,
    })
end

function UpdateEffects(dt)
    -- 更新轨迹点时间
    for _, point in ipairs(slashPoints_) do
        point.time = point.time + dt
    end

    -- 移除过期的轨迹点
    while #slashPoints_ > 0 and slashPoints_[1].time > 0.15 do
        table.remove(slashPoints_, 1)
    end

    -- 更新分数弹出
    local toRemove = {}
    for i, popup in ipairs(scorePopups_) do
        popup.lifetime = popup.lifetime + dt
        popup.y = popup.y - 50 * dt  -- 向上飘动

        if popup.lifetime >= popup.maxLifetime then
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(scorePopups_, toRemove[i])
    end
end

-- ============================================================================
-- 12. NanoVG UI 渲染
-- ============================================================================

function HandleRenderUI(eventType, eventData)
    if not nvg_ then return end

    nvgBeginFrame(nvg_, screenWidth_, screenHeight_, 1.0)

    -- 绘制切割轨迹
    DrawSlashTrail()

    -- 绘制分数弹出
    DrawScorePopups()

    -- 绘制UI
    if gameState_ == GameState.MENU then
        DrawMenuUI()
    elseif gameState_ == GameState.PLAYING then
        DrawGameUI()
    elseif gameState_ == GameState.GAMEOVER then
        DrawGameOverUI()
    end

    nvgEndFrame(nvg_)
end

function DrawSlashTrail()
    if #slashPoints_ < 2 then return end

    -- 构建路径
    local function buildPath()
        nvgBeginPath(nvg_)
        nvgMoveTo(nvg_, slashPoints_[1].x, slashPoints_[1].y)
        for i = 2, #slashPoints_ do
            nvgLineTo(nvg_, slashPoints_[i].x, slashPoints_[i].y)
        end
    end

    nvgLineCap(nvg_, NVG_ROUND)
    nvgLineJoin(nvg_, NVG_ROUND)

    -- 多层光晕，从外到内，透明度渐增，间隔更密
    local layers = {
        { width = 28, alpha = 8 },
        { width = 24, alpha = 12 },
        { width = 20, alpha = 18 },
        { width = 16, alpha = 28 },
        { width = 12, alpha = 45 },
        { width = 9,  alpha = 70 },
        { width = 6,  alpha = 120 },
        { width = 4,  alpha = 200 },
    }

    for _, layer in ipairs(layers) do
        buildPath()
        nvgStrokeColor(nvg_, nvgRGBA(200, 230, 255, layer.alpha))
        nvgStrokeWidth(nvg_, layer.width)
        nvgStroke(nvg_)
    end

    -- 核心亮线
    buildPath()
    nvgStrokeColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(nvg_, 2.5)
    nvgStroke(nvg_)
end

function DrawScorePopups()
    nvgFontFace(nvg_, "sans")

    for _, popup in ipairs(scorePopups_) do
        local alpha = 1 - (popup.lifetime / popup.maxLifetime)
        local scale = 1 + popup.lifetime * 0.5

        nvgFontSize(nvg_, 30 * scale)
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 阴影
        nvgFillColor(nvg_, nvgRGBA(0, 0, 0, math.floor(150 * alpha)))
        nvgText(nvg_, popup.x + 2, popup.y + 2, "+" .. popup.score)

        -- 文字
        if popup.combo > 1 then
            nvgFillColor(nvg_, nvgRGBA(255, 200, 50, math.floor(255 * alpha)))
        else
            nvgFillColor(nvg_, nvgRGBA(255, 255, 255, math.floor(255 * alpha)))
        end
        nvgText(nvg_, popup.x, popup.y, "+" .. popup.score)

        -- 连击显示
        if popup.combo > 1 then
            nvgFontSize(nvg_, 20 * scale)
            nvgFillColor(nvg_, nvgRGBA(255, 150, 50, math.floor(255 * alpha)))
            nvgText(nvg_, popup.x, popup.y + 25, "x" .. popup.combo)
        end
    end
end

function DrawMenuUI()
    nvgFontFace(nvg_, "sans")

    -- 标题
    nvgFontSize(nvg_, 72)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 阴影
    nvgFillColor(nvg_, nvgRGBA(0, 0, 0, 150))
    nvgText(nvg_, screenWidth_ / 2 + 4, screenHeight_ / 3 + 4, "FRUIT NINJA")

    -- 标题文字
    nvgFillColor(nvg_, nvgRGBA(255, 100, 50, 255))
    nvgText(nvg_, screenWidth_ / 2, screenHeight_ / 3, "FRUIT NINJA")

    -- 副标题
    nvgFontSize(nvg_, 36)
    nvgFillColor(nvg_, nvgRGBA(255, 200, 100, 255))
    nvgText(nvg_, screenWidth_ / 2, screenHeight_ / 3 + 60, "3D Edition")

    -- 开始提示
    nvgFontSize(nvg_, 28)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 200))
    nvgText(nvg_, screenWidth_ / 2, screenHeight_ * 2 / 3, "Click or Tap to Start")
end

function DrawGameUI()
    nvgFontFace(nvg_, "sans")
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    -- 分数
    nvgFontSize(nvg_, 36)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, 20, 20, "Score: " .. score_)

    -- 生命值 (用心形表示)
    nvgFontSize(nvg_, 32)
    local livesText = ""
    for i = 1, CONFIG.MaxLives do
        if i <= lives_ then
            livesText = livesText .. "O "  -- 满心
        else
            livesText = livesText .. "X "  -- 空心
        end
    end
    nvgFillColor(nvg_, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg_, 20, 60, "Lives: " .. livesText)

    -- 连击
    if combo_ > 1 then
        nvgFontSize(nvg_, 28)
        nvgFillColor(nvg_, nvgRGBA(255, 200, 50, 255))
        nvgText(nvg_, 20, 100, "Combo: x" .. combo_)
    end
end

function DrawGameOverUI()
    nvgFontFace(nvg_, "sans")
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 半透明背景
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, screenWidth_, screenHeight_)
    nvgFillColor(nvg_, nvgRGBA(0, 0, 0, 150))
    nvgFill(nvg_)

    -- Game Over 标题
    nvgFontSize(nvg_, 64)
    nvgFillColor(nvg_, nvgRGBA(255, 50, 50, 255))
    nvgText(nvg_, screenWidth_ / 2, screenHeight_ / 3, "GAME OVER")

    -- 最终分数
    nvgFontSize(nvg_, 42)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, screenWidth_ / 2, screenHeight_ / 2, "Final Score: " .. score_)

    -- 重新开始提示
    nvgFontSize(nvg_, 28)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 200))
    nvgText(nvg_, screenWidth_ / 2, screenHeight_ * 2 / 3, "Click or Tap to Restart")
end

-- ============================================================================
-- 完成
-- ============================================================================
