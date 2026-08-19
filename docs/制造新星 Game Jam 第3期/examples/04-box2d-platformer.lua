-- ====================================================================
-- 2D平台跳跃游戏 - 最佳实践示例
-- ====================================================================
-- 
-- 本示例展示如何正确使用引擎的Box2D物理系统避免常见BUG
-- 
-- 【常见错误及解决方案】:
-- 
-- ❌ 错误 #1: 混合使用物理系统和直接位移
--    问题: 同时使用 body:ApplyForce() 和 node:Translate() 会导致物理系统混乱
--    解决: 统一使用物理系统控制移动，或者使用 Kinematic 类型的刚体
-- 
-- ❌ 错误 #2: 手动AABB查询检测地面
--    问题: GetRigidBodies() 查询不准确，容易漏检或误检
--    解决: 使用Contact监听器 + 脚底传感器 (Sensor) 正确检测地面
-- 
-- ❌ 错误 #3: 直接设置速度后刚体不响应
--    问题: 设置 linearVelocity 后没有唤醒刚体
--    解决: 设置速度后确保调用 body.awake = true
-- 
-- ❌ 错误 #4: 角色卡在墙上或无法移动
--    问题: 摩擦力过大，或者碰撞形状不合适
--    解决: 使用圆形/胶囊形碰撞体 + 零摩擦力 + 固定旋转
-- 
-- ✅ 本示例使用的最佳实践:
--    1. 使用 Box2D 的 Contact 监听器检测地面
--    2. 使用 Sensor (传感器) 检测脚底接触，使用 center 属性偏移
--    3. 使用速度控制而非力控制 (更精确)
--    4. 圆形碰撞体 + 固定旋转 + 零摩擦 (简洁且不卡墙)
--    5. 使用 NanoVG 渲染，物理和渲染分离
--    6. 边缘二次弹跳是 Box2D 的正常物理特性，可以接受
--    7. 使用 NanoVGRender 事件渲染，让 NanoVGAdapter 管理渲染顺序
--       虚拟摇杆使用 renderOrder=999999，确保始终在画面最上层
-- 
-- ====================================================================

require "LuaScripts/Utilities/Sample"
require "urhox-libs.UI.GameHUD"
local UI = require("urhox-libs/UI")

-- ====================================================================
-- 游戏常量
-- ====================================================================
local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720

-- 物理常量
local GRAVITY = 20.0              -- 重力加速度
local PLAYER_SPEED = 5.0          -- 玩家移动速度
local PLAYER_JUMP_SPEED = 12.0    -- 玩家跳跃速度
local PLAYER_RADIUS = 0.5         -- 玩家半径 (物理单位)

-- 世界常量
local GROUND_Y = -3.0             -- 地面Y坐标

-- 渲染常量 (像素单位)
local PIXELS_PER_UNIT = 50        -- 1物理单位 = 50像素

-- ====================================================================
-- 碰撞分组说明
-- ====================================================================
-- Box2D 使用 categoryBits 和 maskBits 进行碰撞过滤：
-- - categoryBits: 自己属于哪些组（可以是多个组的组合）
-- - maskBits: 愿意与哪些组碰撞（位运算 AND）
-- - 只有当 (shapeA.categoryBits & shapeB.maskBits) != 0 且
--        (shapeB.categoryBits & shapeA.maskBits) != 0 时才会碰撞
--
-- 本示例的分组：
-- - 第1组 (bit 0): 地面和平台
-- - 第2组 (bit 1): 玩家主碰撞体
-- - 第4组 (bit 2): 脚底传感器

-- ====================================================================
-- 全局变量
-- ====================================================================
local scene_ = nil
local cameraNode_ = nil
local physicsWorld_ = nil
local nvg_ = nil

-- 玩家相关
local playerNode_ = nil
local playerBody_ = nil
local onGround_ = false           -- 是否在地面上 (通过Contact监听器设置)
local groundContactCount_ = 0     -- 地面接触计数

-- 平台列表
local platforms_ = {}

-- 调试显示
local debugDraw_ = false

-- 虚拟控制（移动端使用）
local joystick_ = nil
local jumpButton_ = nil

-- ====================================================================
-- 工具函数: 物理坐标转屏幕坐标
-- ====================================================================
function PhysicsToScreen(physicsX, physicsY)
    local screenX = SCREEN_WIDTH / 2 + physicsX * PIXELS_PER_UNIT
    local screenY = SCREEN_HEIGHT / 2 - physicsY * PIXELS_PER_UNIT
    return screenX, screenY
end

-- ====================================================================
-- 主函数
-- ====================================================================
function Start()
    -- 初始化Sample
    SampleStart()
    
    -- 创建NanoVG上下文
    nvg_ = nvgCreate(1)
    if nvg_ == nil then
        print("ERROR: 无法创建NanoVG上下文")
        return
    end
    
    -- 创建字体（用于调试信息显示）
    nvgCreateFont(nvg_, "sans", "Fonts/MiSans-Regular.ttf")
    
    -- 创建场景
    CreateScene()
    
    -- 创建世界
    CreateWorld()
    
    -- 创建玩家
    CreatePlayer()
    
    -- 创建UI说明
    CreateInstructions()
    
    -- 创建虚拟控制（移动端）
    CreateGameHUD()
    
    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    -- 通过 NanoVGRender 事件渲染，让 NanoVGAdapter 管理渲染顺序
    -- 这样可以确保虚拟摇杆（renderOrder=999999）始终在游戏画面上方
    SubscribeToEvent(nvg_, "NanoVGRender", "HandleRender")
    SubscribeToEvent("PhysicsBeginContact2D", "HandlePhysicsBeginContact")
    SubscribeToEvent("PhysicsEndContact2D", "HandlePhysicsEndContact")
    
    print("=== 2D平台跳跃游戏 - 最佳实践示例 ===")
    print("使用方向键/WASD移动，空格跳跃")
    print("按 Z 键切换物理调试显示")
end

function Stop()
    -- 清理虚拟控制
    GameHUD.Shutdown()
    UI.Shutdown()

    if nvg_ ~= nil then
        nvgDelete(nvg_)
    end
end

-- ====================================================================
-- 场景创建
-- ====================================================================
function CreateScene()
    scene_ = Scene()
    
    -- 必需组件
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")
    
    -- 创建物理世界
    physicsWorld_ = scene_:CreateComponent("PhysicsWorld2D")
    physicsWorld_.gravity = Vector2(0, -GRAVITY)
    physicsWorld_.autoClearForces = true
    
    -- 创建相机 (2D正交相机)
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = SCREEN_HEIGHT / 2
    
    -- 设置视口
    renderer:SetViewport(0, Viewport:new(scene_, camera))
end

-- ====================================================================
-- 创建世界 (地面和平台)
-- ====================================================================
function CreateWorld()
    -- 1. 创建地面 (静态刚体)
    local groundNode = scene_:CreateChild("Ground")
    groundNode:SetPosition2D(0, GROUND_Y)
    
    local groundBody = groundNode:CreateComponent("RigidBody2D")
    groundBody.bodyType = BT_STATIC  -- 静态刚体
    
    local groundShape = groundNode:CreateComponent("CollisionBox2D")
    groundShape:SetSize(30, 1)  -- 宽30米，高1米
    groundShape.friction = 0.3
    groundShape.restitution = 0.0  -- 无弹性
    groundShape.categoryBits = 1   -- 分组: 地面
    
    table.insert(platforms_, {
        x = 0,
        y = GROUND_Y,
        width = 30,
        height = 1,
        node = groundNode
    })
    
    -- 2. 创建多个平台
    local platformData = {
        {x = -5, y = 0, width = 3, height = 0.5},
        {x = -2, y = 2, width = 2, height = 0.5},
        {x = 2, y = 4, width = 3, height = 0.5},
        {x = 6, y = 2, width = 2.5, height = 0.5},
        {x = 10, y = 3, width = 3, height = 0.5},
    }
    
    for i, data in ipairs(platformData) do
        local platformNode = scene_:CreateChild("Platform")
        platformNode:SetPosition2D(data.x, data.y)
        
        local platformBody = platformNode:CreateComponent("RigidBody2D")
        platformBody.bodyType = BT_STATIC
        
        local platformShape = platformNode:CreateComponent("CollisionBox2D")
        platformShape:SetSize(data.width, data.height)
        platformShape.friction = 0.3
        platformShape.restitution = 0.0  -- 无弹性
        platformShape.categoryBits = 1   -- 分组: 地面
        
        table.insert(platforms_, {
            x = data.x,
            y = data.y,
            width = data.width,
            height = data.height,
            node = platformNode
        })
    end
end

-- ====================================================================
-- 创建玩家 (关键: 正确配置物理属性)
-- ====================================================================
function CreatePlayer()
    playerNode_ = scene_:CreateChild("Player")
    playerNode_:SetPosition2D(0, 2)  -- 起始位置
    
    -- ✅ 最佳实践 #1: 创建动态刚体
    playerBody_ = playerNode_:CreateComponent("RigidBody2D")
    playerBody_.bodyType = BT_DYNAMIC
    
    -- ✅ 最佳实践 #2: 固定旋转 (防止角色翻滚)
    playerBody_.fixedRotation = true
    
    -- ✅ 最佳实践 #3: 设置合理的物理参数
    playerBody_.linearDamping = 0.0   -- 无线性阻尼 (我们自己控制)
    playerBody_.angularDamping = 0.0
    playerBody_.gravityScale = 1.0
    playerBody_.bullet = false        -- 不需要CCD (角色移动不是很快)
    
    -- ✅ 最佳实践 #4: 使用圆形碰撞体 (简洁且永不卡墙)
    --    圆形是最简单可靠的选择，边缘二次弹跳是 Box2D 的正常物理特性
    local bodyShape = playerNode_:CreateComponent("CollisionCircle2D")
    bodyShape.radius = PLAYER_RADIUS
    bodyShape.density = 1.0
    bodyShape.friction = 0.0          -- ✅ 零摩擦力 (防止卡墙)
    bodyShape.restitution = 0.0       -- ✅ 无弹性 (不会弹跳)
    -- 碰撞分组（用于过滤碰撞）
    bodyShape.categoryBits = 2        -- 自己是第2组（玩家）
    bodyShape.maskBits = 0xFFFF       -- 与所有组碰撞（0xFFFF = 所有位都是1）
    
    -- ✅ 最佳实践 #5: 创建脚底传感器 (用于检测地面)
    --    重要: 传感器必须附加在同一个刚体上，不能作为子节点
    --    使用 center 属性来调整传感器位置到脚底
    local footSensorShape = playerNode_:CreateComponent("CollisionCircle2D")
    footSensorShape.radius = PLAYER_RADIUS * 0.7  -- 比身体略小
    footSensorShape.center = Vector2(0, -PLAYER_RADIUS * 0.9)  -- 偏移到脚底
    footSensorShape.trigger = true    -- ✅ 设置为触发器(传感器)，不产生物理响应
    -- 碰撞分组
    footSensorShape.categoryBits = 4  -- 自己是第4组（传感器）
    footSensorShape.maskBits = 1      -- 只与第1组碰撞（地面/平台）
    
    print("玩家创建完成 (身体碰撞体 + 脚底传感器)")
end

-- ====================================================================
-- 虚拟控制 (移动端)
-- ====================================================================
function CreateGameHUD()
    -- 初始化 GameHUD
    GameHUD.Initialize()
    
    -- 创建基础 HUD（摇杆 + 跳跃按钮）
    -- 这个游戏速度固定，不需要跑步和射击功能
    local hud = GameHUD.Create({
        enableJump = true,  -- 平台跳跃游戏需要跳跃
    })
    
    -- 保存引用
    joystick_ = hud.joystick
    jumpButton_ = hud.jumpButton
    
    print("虚拟控制创建完成 (摇杆 + 跳跃按钮)")
end

-- ====================================================================
-- 物理碰撞回调 (关键: 正确检测地面)
-- ====================================================================

-- 辅助函数: 从碰撞事件中获取与玩家碰撞的另一个节点
local function GetOtherNode(nodeA, nodeB)
    if playerNode_ == nil then
        return nil
    end
    
    if nodeA == playerNode_ then
        return nodeB
    elseif nodeB == playerNode_ then
        return nodeA
    end
    
    return nil
end

-- 辅助函数: 检查节点是否是地面或平台
local function IsGroundOrPlatform(node)
    if node == nil then
        return false
    end
    return node.name == "Ground" or node.name:find("Platform", 1, true) ~= nil
end

-- ✅ 最佳实践 #6: 使用Contact监听器检测地面
--    不要使用手动AABB查询，容易出错
function HandlePhysicsBeginContact(eventType, eventData)
    local nodeA = eventData["NodeA"]:GetPtr("Node")
    local nodeB = eventData["NodeB"]:GetPtr("Node")
    
    local hitNode = GetOtherNode(nodeA, nodeB)
    if IsGroundOrPlatform(hitNode) then
        groundContactCount_ = groundContactCount_ + 1
        onGround_ = true
    end
end

function HandlePhysicsEndContact(eventType, eventData)
    local nodeA = eventData["NodeA"]:GetPtr("Node")
    local nodeB = eventData["NodeB"]:GetPtr("Node")
    
    local hitNode = GetOtherNode(nodeA, nodeB)
    if IsGroundOrPlatform(hitNode) then
        groundContactCount_ = groundContactCount_ - 1
        if groundContactCount_ <= 0 then
            groundContactCount_ = 0
            onGround_ = false
        end
    end
end

-- ====================================================================
-- 更新逻辑
-- ====================================================================
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    
    if playerBody_ == nil then
        return
    end
    
    -- 切换调试显示
    if input:GetKeyPress(KEY_Z) then
        debugDraw_ = not debugDraw_
    end
    
    -- ✅ 最佳实践 #7: 使用速度控制而非力控制 (更精确可控)
    local currentVel = playerBody_.linearVelocity
    local desiredVelX = 0
    
    -- ============================================================
    -- 输入处理：统一使用摇杆的 getMovement() 方法
    -- ============================================================
    -- GameHUD 摇杆会自动将键盘 A/D 转换为摇杆 X 方向：
    --   - PC端：keyBinding="WASD" 自动生效
    --   - 移动端：触摸虚拟摇杆
    --
    -- 对于 2D 横版游戏，只需使用 X 分量
    -- 注意：只取方向，不取力度，保持与键盘输入一致（无加速）
    -- ============================================================
    if joystick_ then
        local moveX, _ = joystick_:getMovement()
        if moveX < -0.1 then
            desiredVelX = -PLAYER_SPEED
        elseif moveX > 0.1 then
            desiredVelX = PLAYER_SPEED
        end
    end
    
    -- ✅ 最佳实践 #8: 直接设置水平速度，保持垂直速度
    --    这样可以精确控制移动，不会受摩擦力影响
    playerBody_.linearVelocity = Vector2(desiredVelX, currentVel.y)
    
    -- 跳跃检测（虚拟按钮）
    local jumpPressed = input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_SPACE)
    if jumpButton_ and jumpButton_.isPressed then
        jumpPressed = true
    end
    
    -- ✅ 最佳实践 #9: 只有在地面上才能跳跃
    --    使用传感器检测的 onGround_ 标志，非常可靠
    if onGround_ and jumpPressed then
        -- 设置向上的速度（保持当前水平速度）
        playerBody_.linearVelocity = Vector2(desiredVelX, PLAYER_JUMP_SPEED)
        
        -- ✅ 最佳实践 #10: 设置速度后确保刚体是唤醒的
        playerBody_.awake = true
    end
end

-- ====================================================================
-- 后更新逻辑 (相机跟随)
-- ====================================================================
function HandlePostUpdate(eventType, eventData)
    -- 相机跟随玩家（在 PostUpdate 中，确保跟随物理步骤后的最终位置）
    if playerNode_ ~= nil and cameraNode_ ~= nil then
        local playerPos = playerNode_.position2D
        cameraNode_:SetPosition(Vector3(playerPos.x, playerPos.y, -10))
    end
end

-- ====================================================================
-- NanoVG渲染
-- ====================================================================
function HandleRender(eventType, eventData)
    if nvg_ == nil then
        return
    end
    
    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()
    
    nvgBeginFrame(nvg_, width, height, 1.0)
    
    -- 绘制背景
    DrawBackground(nvg_, width, height)
    
    -- 绘制世界
    DrawWorld(nvg_, width, height)
    
    -- 绘制玩家
    DrawPlayer(nvg_, width, height)
    
    -- 绘制调试信息
    if debugDraw_ then
        DrawDebugInfo(nvg_, width, height)
    end
    
    nvgEndFrame(nvg_)
    
    -- 绘制物理调试
    if debugDraw_ and physicsWorld_ ~= nil then
        physicsWorld_:DrawDebugGeometry()
    end
end

function DrawBackground(vg, width, height)
    -- 天空渐变
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, width, height)
    local bg = nvgLinearGradient(vg, 0, 0, 0, height,
        nvgRGBA(135, 206, 235, 255),  -- 天蓝色
        nvgRGBA(200, 230, 255, 255))  -- 浅蓝色
    nvgFillPaint(vg, bg)
    nvgFill(vg)
end

function DrawWorld(vg, width, height)
    -- 绘制所有平台
    for _, platform in ipairs(platforms_) do
        local screenX, screenY = PhysicsToScreen(platform.x, platform.y)
        local screenW = platform.width * PIXELS_PER_UNIT
        local screenH = platform.height * PIXELS_PER_UNIT
        
        -- 平台阴影
        nvgBeginPath(vg)
        nvgRect(vg, screenX - screenW/2 + 3, screenY - screenH/2 + 3, screenW, screenH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 50))
        nvgFill(vg)
        
        -- 平台主体 (渐变)
        nvgBeginPath(vg)
        nvgRect(vg, screenX - screenW/2, screenY - screenH/2, screenW, screenH)
        local platformGrad = nvgLinearGradient(vg, 
            screenX - screenW/2, screenY - screenH/2,
            screenX - screenW/2, screenY + screenH/2,
            nvgRGBA(100, 200, 100, 255),
            nvgRGBA(60, 140, 60, 255))
        nvgFillPaint(vg, platformGrad)
        nvgFill(vg)
        
        -- 平台边框
        nvgBeginPath(vg)
        nvgRect(vg, screenX - screenW/2, screenY - screenH/2, screenW, screenH)
        nvgStrokeWidth(vg, 2)
        nvgStrokeColor(vg, nvgRGBA(40, 100, 40, 255))
        nvgStroke(vg)
    end
end

function DrawPlayer(vg, width, height)
    if playerNode_ == nil then
        return
    end
    
    local pos = playerNode_.position2D
    local screenX, screenY = PhysicsToScreen(pos.x, pos.y)
    local radius = PLAYER_RADIUS * PIXELS_PER_UNIT
    
    -- 玩家阴影
    nvgBeginPath(vg)
    nvgCircle(vg, screenX + 3, screenY + 3, radius)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80))
    nvgFill(vg)
    
    -- 玩家身体 (渐变)
    nvgBeginPath(vg)
    nvgCircle(vg, screenX, screenY, radius)
    local bodyGrad = nvgRadialGradient(vg, screenX - 10, screenY - 10, 5, radius + 5,
        nvgRGBA(100, 150, 255, 255),
        nvgRGBA(50, 100, 200, 255))
    nvgFillPaint(vg, bodyGrad)
    nvgFill(vg)
    
    -- 玩家高光
    nvgBeginPath(vg)
    nvgCircle(vg, screenX - 8, screenY - 8, 10)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 150))
    nvgFill(vg)
    
    -- 玩家眼睛
    nvgBeginPath(vg)
    nvgCircle(vg, screenX - 8, screenY - 3, 4)
    nvgCircle(vg, screenX + 8, screenY - 3, 4)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    
    nvgBeginPath(vg)
    nvgCircle(vg, screenX - 7, screenY - 2, 2)
    nvgCircle(vg, screenX + 9, screenY - 2, 2)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)
    
    -- 玩家边框
    nvgBeginPath(vg)
    nvgCircle(vg, screenX, screenY, radius)
    nvgStrokeWidth(vg, 2)
    nvgStrokeColor(vg, nvgRGBA(30, 60, 150, 255))
    nvgStroke(vg)
    
    -- 如果在地面上，绘制指示器
    if onGround_ then
        nvgBeginPath(vg)
        nvgCircle(vg, screenX, screenY + radius + 10, 3)
        nvgFillColor(vg, nvgRGBA(0, 255, 0, 200))
        nvgFill(vg)
    end
end

function DrawDebugInfo(vg, width, height)
    if playerNode_ == nil or playerBody_ == nil then
        return
    end
    
    -- 绘制调试文本背景
    nvgBeginPath(vg)
    nvgRect(vg, 10, 80, 300, 150)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)
    
    -- 调试文本
    nvgFontSize(vg, 16)
    nvgFontFace(vg, "sans")
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    
    local pos = playerNode_.position2D
    local vel = playerBody_.linearVelocity
    local mass = playerBody_.mass
    
    local debugText = string.format(
        "=== 调试信息 ===\n" ..
        "位置: (%.2f, %.2f)\n" ..
        "速度: (%.2f, %.2f)\n" ..
        "质量: %.2f\n" ..
        "在地面: %s\n" ..
        "接触计数: %d\n" ..
        "刚体唤醒: %s",
        pos.x, pos.y,
        vel.x, vel.y,
        mass,
        onGround_ and "是" or "否",
        groundContactCount_,
        playerBody_.awake and "是" or "否"
    )
    
    nvgText(vg, 20, 90, debugText, nil)
end

-- ====================================================================
-- UI说明
-- ====================================================================
function CreateInstructions()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        paddingTop = 10,
        alignItems = "center",
        children = {
            UI.Label {
                text = "2D平台跳跃 - 最佳实践示例 | 方向键/WASD移动 | 空格跳跃 | Z键切换调试",
                fontSize = 15,
                fontColor = { 255, 255, 255, 255 },
            },
        }
    })
end

