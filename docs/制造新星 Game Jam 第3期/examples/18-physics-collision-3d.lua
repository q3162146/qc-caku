-- ============================================================================
-- 3D Physics Collision Best Practice - 3D 物理碰撞最佳实践
-- ============================================================================
--
-- PURPOSE: 演示如何高效处理 3D 物理碰撞事件
--
-- COVERS:
--   1. 地面检测 (Ground Detection) - 使用 contactNormal 判断
--   2. 触发区域 (Trigger Zone) - 使用 trigger=true 的 RigidBody
--   3. 收集物品 (Collectibles) - 触发器 + 移除节点
--   4. 伤害判定 (Damage Detection) - 碰撞开始事件
--
-- CONTROLS:
--   - WASD / Arrow Keys: Move player
--   - Space: Jump
--   - ESC: Exit
--
-- ============================================================================
--
-- 【碰撞事件速查表】
--
-- ┌─────────────────────┬──────────────────┬─────────────────────────────┐
-- │ Event               │ When Fired       │ Use Case                    │
-- ├─────────────────────┼──────────────────┼─────────────────────────────┤
-- │ NodeCollision       │ Every frame      │ Continuous contact (ground) │
-- │ NodeCollisionStart  │ Contact begins   │ One-time triggers, damage   │
-- │ NodeCollisionEnd    │ Contact ends     │ Exit trigger zone           │
-- ├─────────────────────┼──────────────────┼─────────────────────────────┤
-- │ PhysicsCollision    │ Every frame      │ Global collision manager    │
-- │ PhysicsCollisionStart│ Contact begins  │ Global one-time events      │
-- │ PhysicsCollisionEnd │ Contact ends     │ Global exit events          │
-- └─────────────────────┴──────────────────┴─────────────────────────────┘
--
-- 【订阅模式】
--
-- 节点级别订阅 (推荐用于 ScriptObject):
--   self:SubscribeToEvent(self.node, "NodeCollision", "HandleCollision")
--
-- 全局订阅 (用于游戏管理器):
--   SubscribeToEvent("PhysicsCollisionStart", "HandleGlobalCollision")
--
-- ============================================================================
--
-- 【常见错误及解决方案】
--
-- ❌ 错误 #1: 在 NodeCollision 中处理一次性事件
--    问题: NodeCollision 每帧触发，会导致重复执行（如硬币被收集多次）
--    解决: 使用 NodeCollisionStart 处理一次性事件
--
-- ❌ 错误 #2: 只读取部分 Contacts 数据
--    问题: 只读 position 和 normal，不读 distance 和 impulse，导致下次循环数据错位
--    解决: 必须按顺序读取全部 4 个值（position, normal, distance, impulse）
--
-- ❌ 错误 #3: 地面检测只用位置判断
--    问题: if contactPosition.y < playerPos.y then ... （撞墙也会触发！）
--    解决: 使用法向量判断 if contactNormal.y > 0.75 then ...
--
-- ❌ 错误 #4: 触发器和物理碰撞混淆
--    问题: 不检查 Trigger 字段，把所有碰撞都当触发器处理
--    解决: 通过 eventData["Trigger"]:GetBool() 区分
--
-- ❌ 错误 #5: 静止时收不到碰撞事件
--    问题: 默认情况下静止的刚体不触发碰撞事件
--    解决: 设置 body.collisionEventMode = COLLISION_ALWAYS
--
-- ============================================================================

require "LuaScripts/Utilities/Sample"
require "urhox-libs.UI.GameHUD"
local UI = require("urhox-libs/UI")

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Collision layers (bitmask for collision filtering)
local COLLISION_LAYER_GROUND = 1      -- bit 0: Ground and platforms
local COLLISION_LAYER_PLAYER = 2      -- bit 1: Player
local COLLISION_LAYER_TRIGGER = 4     -- bit 2: Triggers (coins, zones)

-- Physics constants
local MOVE_FORCE = 0.15       -- Impulse force per frame (keep low for controllable movement)
local JUMP_FORCE = 5.0
local PLAYER_RADIUS = 0.5

-- Game constants
local COIN_COUNT = 5
local COIN_ROTATION_SPEED = 90.0      -- degrees per second

-- ============================================================================
-- GLOBAL VARIABLES
-- ============================================================================

local scene_ = nil
local cameraNode_ = nil
local playerNode_ = nil
local physicsWorld_ = nil

-- Game state
local coinsCollected_ = 0
local playerHealth_ = 100
local isInTriggerZone_ = false
local isInDamageZone_ = false
local damageTimer_ = 0
local totalCollisions_ = 0        -- Tracked by global PhysicsCollisionStart

-- UI: 每行一个 Label, 保留引用动态更新 (见 recipes/ui.md §11 模式 A)
-- 拆分原因: UI.Label 用 nvgText 渲染, 单 Label 多行 \n 行为不可靠, 用多个 Label 更稳
local healthLabel_, coinsLabel_, triggerLabel_, damageLabel_, collisionsLabel_ = nil, nil, nil, nil, nil

-- Coin nodes for rotation animation
local coinNodes_ = {}

-- ============================================================================
-- MATERIAL CREATION HELPERS
-- ============================================================================

-- Create a bright unlit material (for coins, glowing objects)
function CreateUnlitMaterial(color)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    return mat
end

-- Create a transparent material (for trigger zones)
function CreateTransparentMaterial(color)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 16)))
    return mat
end

-- ============================================================================
-- MAIN FUNCTIONS
-- ============================================================================

function Start()
    SampleStart()
    graphics.windowTitle = "3D Physics Collision Best Practice"

    CreateScene()
    CreatePlayer()
    CreateGround()
    CreateCoins()
    CreateTriggerZone()
    CreateDamageZone()
    SetupCamera()
    CreateUI()
    CreateGameHUD()
    SubscribeToEvents()

    print("=== 3D Physics Collision Best Practice ===")
    print("WASD to move, Space to jump")
    print("Collect coins, enter trigger zone, avoid damage zone")
end

-- ============================================================================
-- SCENE SETUP
-- ============================================================================

function CreateScene()
    scene_ = Scene()

    -- Required components
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    -- Create physics world
    physicsWorld_ = scene_:CreateComponent("PhysicsWorld")
    physicsWorld_:SetGravity(Vector3(0, -9.81, 0))

    -- Create zone for ambient lighting
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-100.0, 100.0)
    zone.ambientColor = Color(0.3, 0.3, 0.3)
    zone.fogColor = Color(0.7, 0.8, 0.9)
    zone.fogStart = 50.0
    zone.fogEnd = 100.0

    -- Create directional light
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(1.0, 1.0, 1.0)
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 15, -20)
    cameraNode_:LookAt(Vector3(0, 0, 0))

    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 300.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))
end

-- ============================================================================
-- GROUND CREATION
-- ============================================================================

function CreateGround()
    local groundNode = scene_:CreateChild("Ground")
    groundNode.position = Vector3(0, -0.5, 0)
    groundNode.scale = Vector3(30, 1, 30)

    local model = groundNode:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")
    model.material = cache:GetResource("Material", "Materials/StoneTiled.xml")

    -- Static rigid body (mass = 0)
    local body = groundNode:CreateComponent("RigidBody")
    body.collisionLayer = COLLISION_LAYER_GROUND

    local shape = groundNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3(1, 1, 1))  -- Will be scaled by node scale

    -- Create boundary walls (0.5m height)
    CreateBoundaryWalls()
end

function CreateBoundaryWalls()
    local groundSize = 30
    local wallHeight = 3.0
    local wallThickness = 0.5

    -- Wall positions: {x, z, sizeX, sizeZ}
    local walls = {
        { 0, groundSize / 2, groundSize, wallThickness },    -- North (+Z)
        { 0, -groundSize / 2, groundSize, wallThickness },   -- South (-Z)
        { groundSize / 2, 0, wallThickness, groundSize },    -- East (+X)
        { -groundSize / 2, 0, wallThickness, groundSize },   -- West (-X)
    }

    for i, w in ipairs(walls) do
        local wallNode = scene_:CreateChild("Wall")
        wallNode.position = Vector3(w[1], wallHeight / 2, w[2])
        wallNode.scale = Vector3(w[3], wallHeight, w[4])

        local model = wallNode:CreateComponent("StaticModel")
        model.model = cache:GetResource("Model", "Models/Box.mdl")
        model.material = cache:GetResource("Material", "Materials/Stone.xml")

        local body = wallNode:CreateComponent("RigidBody")
        body.collisionLayer = COLLISION_LAYER_GROUND

        local shape = wallNode:CreateComponent("CollisionShape")
        shape:SetBox(Vector3(1, 1, 1))
    end
end

-- ============================================================================
-- PLAYER CREATION
-- ============================================================================

--[[
BEST PRACTICE #1: Player Setup
─────────────────────────────────────────────────────────────────────────────
- Use capsule or sphere collision shape (avoids getting stuck on edges)
- Set angularFactor to zero (prevents unwanted rotation)
- Set collisionEventMode = COLLISION_ALWAYS (ensures events even when resting)
]]

function CreatePlayer()
    playerNode_ = scene_:CreateChild("Player")
    playerNode_.position = Vector3(0, 2, 0)

    -- Visual model (sphere)
    local model = playerNode_:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Sphere.mdl")
    model.material = cache:GetResource("Material", "Materials/StoneSmall.xml")
    model.castShadows = true
    playerNode_.scale = Vector3(PLAYER_RADIUS * 2, PLAYER_RADIUS * 2, PLAYER_RADIUS * 2)

    -- Dynamic rigid body
    local body = playerNode_:CreateComponent("RigidBody")
    body.mass = 1.0
    body.friction = 0.75
    body.linearDamping = 0.3     -- Low damping for natural falling
    body.collisionLayer = COLLISION_LAYER_PLAYER
    body.collisionMask = 0xFFFF  -- Collide with everything

    -- Prevent rotation (player always upright)
    body.angularFactor = Vector3(0, 0, 0)

    -- IMPORTANT: Ensure collision events are triggered even when at rest
    body.collisionEventMode = COLLISION_ALWAYS

    -- Collision shape
    local shape = playerNode_:CreateComponent("CollisionShape")
    shape:SetSphere(1.0)  -- Diameter 1, will be scaled

    -- Attach script object for collision handling
    playerNode_:CreateScriptObject("Player")
end

-- ============================================================================
-- COLLECTIBLES (COINS)
-- ============================================================================

--[[
BEST PRACTICE #2: Trigger Setup
─────────────────────────────────────────────────────────────────────────────
Triggers detect collision but don't produce physical response.

Setup method: body.trigger = true
Characteristics: Does not block movement, only triggers events
Use cases: Collectibles, zone detection, invisible walls
]]

function CreateCoins()
    local positions = {
        Vector3(-5, 1, 3),
        Vector3(0, 1, 5),
        Vector3(5, 1, 3),
        Vector3(-3, 1, -3),
        Vector3(3, 1, -3),
    }

    for i, pos in ipairs(positions) do
        local node = scene_:CreateChild("Coin")
        node.position = pos

        -- Visual model (cylinder as coin)
        local model = node:CreateComponent("StaticModel")
        model.model = cache:GetResource("Model", "Models/Cylinder.mdl")
        model.material = CreateUnlitMaterial(Color(1, 0.9, 0, 1))  -- Bright yellow
        model.castShadows = true
        node.scale = Vector3(0.5, 0.1, 0.5)

        -- Trigger rigid body (does not block physics)
        local body = node:CreateComponent("RigidBody")
        body.trigger = true  -- KEY: Set as trigger
        body.collisionLayer = COLLISION_LAYER_TRIGGER
        body.collisionMask = COLLISION_LAYER_PLAYER  -- Only collide with player

        local shape = node:CreateComponent("CollisionShape")
        shape:SetCylinder(1.0, 1.0)  -- Will be scaled

        table.insert(coinNodes_, node)
    end
end

-- ============================================================================
-- TRIGGER ZONE
-- ============================================================================

function CreateTriggerZone()
    local node = scene_:CreateChild("TriggerZone")
    node.position = Vector3(8, 1.5, 0)

    -- Semi-transparent visual
    local model = node:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")
    model.material = CreateTransparentMaterial(Color(0, 1, 0, 0.25))  -- Green transparent
    node.scale = Vector3(3, 3, 3)

    -- Trigger rigid body
    local body = node:CreateComponent("RigidBody")
    body.trigger = true
    body.collisionLayer = COLLISION_LAYER_TRIGGER
    body.collisionMask = COLLISION_LAYER_PLAYER

    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3(1, 1, 1))
end

-- ============================================================================
-- DAMAGE ZONE
-- ============================================================================

function CreateDamageZone()
    local node = scene_:CreateChild("DamageZone")
    node.position = Vector3(-8, 0.5, 0)

    -- Red visual indicating danger
    local model = node:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")
    model.material = CreateTransparentMaterial(Color(1, 0, 0, 0.25))  -- Red transparent
    node.scale = Vector3(3, 1, 3)

    -- Trigger rigid body
    local body = node:CreateComponent("RigidBody")
    body.trigger = true
    body.collisionLayer = COLLISION_LAYER_TRIGGER
    body.collisionMask = COLLISION_LAYER_PLAYER

    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3(1, 1, 1))
end

-- ============================================================================
-- UI
-- ============================================================================

function CreateUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 每个动态 Label 保留 local 引用, UpdateUI 中直接 :SetText (recipes/ui.md §11 模式 A)
    healthLabel_     = UI.Label { text = "", fontSize = 18, fontColor = { 255, 255, 255, 255 } }
    coinsLabel_      = UI.Label { text = "", fontSize = 18, fontColor = { 255, 255, 255, 255 } }
    triggerLabel_    = UI.Label { text = "", fontSize = 18, fontColor = { 255, 255, 255, 255 } }
    damageLabel_     = UI.Label { text = "", fontSize = 18, fontColor = { 255, 255, 255, 255 } }
    collisionsLabel_ = UI.Label { text = "", fontSize = 18, fontColor = { 255, 255, 255, 255 } }

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            -- 左上角 stats 面板, 用 flexDirection=column 垂直排列
            UI.Panel {
                position = "absolute",
                top = 20, left = 20,
                flexDirection = "column",
                children = {
                    UI.Label { text = "=== 3D Physics Collision Demo ===", fontSize = 18, fontColor = { 255, 255, 255, 255 } },
                    healthLabel_,
                    coinsLabel_,
                    triggerLabel_,
                    damageLabel_,
                    collisionsLabel_,
                    UI.Label { text = " ", fontSize = 18 },  -- spacer
                    UI.Label { text = "[WASD] Move  [Space] Jump", fontSize = 18, fontColor = { 255, 255, 255, 255 } },
                },
            },
        },
    })

    UpdateUI()
end

function Stop()
    UI.Shutdown()
end

function UpdateUI()
    local zoneStatus = isInTriggerZone_ and "YES (Green Zone)" or "No"
    local damageStatus = isInDamageZone_ and "YES (Taking Damage!)" or "No"

    healthLabel_:SetText(string.format("Health: %d", playerHealth_))
    coinsLabel_:SetText(string.format("Coins: %d / %d", coinsCollected_, COIN_COUNT))
    triggerLabel_:SetText("In Trigger Zone: " .. zoneStatus)
    damageLabel_:SetText("In Damage Zone: " .. damageStatus)
    collisionsLabel_:SetText(string.format("Total Collisions: %d (via PhysicsCollisionStart)", totalCollisions_))
end

-- ============================================================================
-- VIRTUAL CONTROLS (Mobile Support)
-- ============================================================================

local joystick_ = nil
local jumpButton_ = nil

function CreateGameHUD()
    GameHUD.Initialize()
    
    -- PhysicsCollision3D: 第三人称游戏，需要摇杆 + 跳跃
    local hud = GameHUD.Create({
        enableJump = true,  -- 跳跃按钮
    })
    
    joystick_ = hud.joystick
    jumpButton_ = hud.jumpButton
    
    print("Virtual controls created (joystick + jump)")
end

-- ============================================================================
-- EVENT SUBSCRIPTION
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    -- Global collision events (for game manager style handling)
    -- Compare with node-level subscription in Player:Start()
    SubscribeToEvent("PhysicsCollisionStart", "HandleGlobalCollisionStart")
end

-- ============================================================================
-- GLOBAL COLLISION HANDLER (PhysicsCollisionStart)
-- ============================================================================

--[[
BEST PRACTICE #7: Global Collision Subscription
─────────────────────────────────────────────────────────────────────────────
Use PhysicsCollisionStart for centralized collision handling.
Useful for: game managers, audio systems, particle effects, analytics.

Event data contains:
  - World: PhysicsWorld component
  - NodeA: First collision node
  - NodeB: Second collision node
  - BodyA: First RigidBody
  - BodyB: Second RigidBody
  - Trigger: Boolean, true if trigger collision

NOTE: Unlike NodeCollision, global events don't have Contacts buffer.
      Use NodeCollision if you need contact points/normals.
]]

function HandleGlobalCollisionStart(eventType, eventData)
    local nodeA = eventData["NodeA"]:GetPtr("Node")
    local nodeB = eventData["NodeB"]:GetPtr("Node")
    local isTrigger = eventData["Trigger"]:GetBool()

    -- Count all non-trigger collisions (for demonstration)
    if not isTrigger then
        totalCollisions_ = totalCollisions_ + 1
        UpdateUI()
    end

    -- Example: Centralized collision logging
    -- Useful for debugging or analytics
    -- print(string.format("Collision: %s <-> %s (trigger=%s)",
    --     nodeA.name, nodeB.name, tostring(isTrigger)))

    -- Example: Play sound effect on any physical collision
    -- if not isTrigger and IsPlayerInvolved(nodeA, nodeB) then
    --     PlayCollisionSound()
    -- end
end

-- Helper: Check if player is involved in collision
function IsPlayerInvolved(nodeA, nodeB)
    return nodeA == playerNode_ or nodeB == playerNode_
end

-- ============================================================================
-- UPDATE HANDLERS
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- Player movement
    HandlePlayerInput(timeStep)

    -- Rotate coins
    RotateCoins(timeStep)

    -- Handle damage zone (continuous damage)
    if isInDamageZone_ then
        damageTimer_ = damageTimer_ + timeStep
        if damageTimer_ >= 0.5 then  -- Damage every 0.5 seconds
            damageTimer_ = 0
            playerHealth_ = math.max(0, playerHealth_ - 5)
            print("Taking damage! Health: " .. playerHealth_)
            UpdateUI()
        end
    end
end

function HandlePostUpdate(eventType, eventData)
    -- Camera follow player
    if playerNode_ ~= nil and cameraNode_ ~= nil then
        local playerPos = playerNode_.position
        cameraNode_.position = Vector3(playerPos.x, playerPos.y + 15, playerPos.z - 20)
        cameraNode_:LookAt(playerPos)
    end
end

function HandlePlayerInput(timeStep)
    if playerNode_ == nil then return end

    local body = playerNode_:GetComponent("RigidBody")
    if body == nil then return end

    local moveDir = Vector3(0, 0, 0)

    -- ============================================================
    -- 输入处理：统一使用摇杆的 getMovement() 方法
    -- ============================================================
    -- GameHUD 摇杆会自动将键盘 WASD 转换为摇杆方向：
    --   - PC端：keyBinding="WASD" 自动生效
    --   - 移动端：触摸虚拟摇杆
    --
    -- getMovement() 默认 invertY=true，返回：
    --   - x: 左右移动 (-1 到 +1)
    --   - y: 前后移动 (向上推返回 +1，向下推返回 -1)
    -- ============================================================
    if joystick_ then
        local moveX, moveY = joystick_:getMovement()
        moveDir.x = moveX  -- 左右移动
        moveDir.z = moveY  -- 前后移动（已自动处理 Y 轴反转）
    end

    if moveDir:LengthSquared() > 0 then
        moveDir:Normalize()
        body:ApplyImpulse(moveDir * MOVE_FORCE)
    end

    -- Jump (keyboard or virtual button, only when on ground)
    local player = playerNode_:GetScriptObject()
    if player ~= nil and player.onGround then
        local jumpPressed = input:GetKeyPress(KEY_SPACE)
        if jumpButton_ and jumpButton_.isPressed then
            jumpPressed = true
        end
        if jumpPressed then
            body:ApplyImpulse(Vector3(0, JUMP_FORCE, 0))
        end
    end
end

function RotateCoins(timeStep)
    for _, node in ipairs(coinNodes_) do
        if node ~= nil then
            node:Rotate(Quaternion(0, COIN_ROTATION_SPEED * timeStep, 0))
        end
    end
end

-- ============================================================================
-- PLAYER SCRIPT OBJECT (COLLISION HANDLING)
-- ============================================================================

--[[
================================================================================
COLLISION EVENT DATA STRUCTURE (3D Physics)
================================================================================

eventData fields:
  - Body: Current node's RigidBody component
  - OtherNode: The other colliding node
  - OtherBody: The other RigidBody
  - Trigger: Boolean, true if this is a trigger collision
  - Contacts: Buffer containing contact point data

CONTACTS BUFFER FORMAT:
  Each contact point contains 4 values that MUST be read in order:
    1. contactPosition (Vector3) - World position of contact point
    2. contactNormal (Vector3)   - Surface normal (points toward current body)
    3. contactDistance (float)   - Penetration depth (negative = penetrating)
    4. contactImpulse (float)    - Collision impulse magnitude

================================================================================
]]

Player = ScriptObject()

function Player:Start()
    self.onGround = false

    --[[
    BEST PRACTICE #3: Event Subscription
    ─────────────────────────────────────────────────────────────────────────
    For ScriptObjects, use node-level subscription.
    This ensures you only receive events for YOUR node's collisions.

    Pattern: self:SubscribeToEvent(self.node, "EventName", "Handler")
    ]]

    -- NodeCollision: Fires every frame while contact persists
    -- Use for: Ground detection (need continuous checking)
    self:SubscribeToEvent(self.node, "NodeCollision", "Player:HandleCollision")

    -- NodeCollisionStart: Fires once when contact begins
    -- Use for: Collectibles, enter trigger zone, take damage
    self:SubscribeToEvent(self.node, "NodeCollisionStart", "Player:HandleCollisionStart")

    -- NodeCollisionEnd: Fires once when contact ends
    -- Use for: Exit trigger zone
    self:SubscribeToEvent(self.node, "NodeCollisionEnd", "Player:HandleCollisionEnd")
end

--[[
BEST PRACTICE #4: Ground Detection
─────────────────────────────────────────────────────────────────────────────
Use NodeCollision (fires every frame) for ground detection.
Check contactNormal.y > 0.75 to determine if surface is "ground-like".

Why 0.75? This corresponds to ~41 degrees from horizontal.
Surfaces steeper than this are considered walls, not ground.

IMPORTANT: Reset onGround each frame, then set it if ground contact found.
]]

function Player:HandleCollision(eventType, eventData)
    -- Skip trigger collisions for ground detection
    if eventData["Trigger"]:GetBool() then
        return
    end

    local contacts = eventData["Contacts"]:GetBuffer()
    self.onGround = false  -- Reset each frame

    while not contacts.eof do
        -- CRITICAL: Must read ALL 4 values in order!
        -- Skipping any value will corrupt subsequent reads.
        local contactPosition = contacts:ReadVector3()
        local contactNormal = contacts:ReadVector3()
        local contactDistance = contacts:ReadFloat()  -- Don't skip!
        local contactImpulse = contacts:ReadFloat()   -- Don't skip!

        -- Ground detection: Normal pointing upward = ground
        -- 0.75 = cos(41 degrees), allows slight slopes
        if contactNormal.y > 0.75 then
            self.onGround = true
        end
    end
end

--[[
BEST PRACTICE #5: One-Time Events (Collectibles, Enter Zone)
─────────────────────────────────────────────────────────────────────────────
Use NodeCollisionStart for events that should only happen once.

Common pattern:
  1. Check if it's a trigger collision (eventData["Trigger"]:GetBool())
  2. Get the other node (eventData["OtherNode"]:GetPtr("Node"))
  3. Check node name or tag to determine action
  4. Perform action (collect item, enter zone, etc.)

WARNING: Do NOT use NodeCollision for collectibles!
         NodeCollision fires every frame, causing items to be "collected" multiple times.
]]

function Player:HandleCollisionStart(eventType, eventData)
    local otherNode = eventData["OtherNode"]:GetPtr("Node")
    local isTrigger = eventData["Trigger"]:GetBool()

    -- Only process trigger collisions here
    if not isTrigger then
        return
    end

    local nodeName = otherNode.name

    -- Collect coin
    if nodeName == "Coin" then
        coinsCollected_ = coinsCollected_ + 1
        print("Coin collected! Total: " .. coinsCollected_ .. "/" .. COIN_COUNT)

        -- Remove coin from tracking list
        for i, node in ipairs(coinNodes_) do
            if node == otherNode then
                table.remove(coinNodes_, i)
                break
            end
        end

        -- Remove the coin node
        otherNode:Remove()
        UpdateUI()

        -- Check win condition
        if coinsCollected_ >= COIN_COUNT then
            print("*** ALL COINS COLLECTED! ***")
        end
    end

    -- Enter trigger zone
    if nodeName == "TriggerZone" then
        isInTriggerZone_ = true
        print("Entered trigger zone!")
        UpdateUI()
    end

    -- Enter damage zone
    if nodeName == "DamageZone" then
        isInDamageZone_ = true
        damageTimer_ = 0
        print("WARNING: Entered damage zone!")
        UpdateUI()
    end
end

--[[
BEST PRACTICE #6: Exit Events
─────────────────────────────────────────────────────────────────────────────
Use NodeCollisionEnd for handling zone exits.
]]

function Player:HandleCollisionEnd(eventType, eventData)
    local otherNode = eventData["OtherNode"]:GetPtr("Node")
    local nodeName = otherNode.name

    -- Exit trigger zone
    if nodeName == "TriggerZone" then
        isInTriggerZone_ = false
        print("Left trigger zone")
        UpdateUI()
    end

    -- Exit damage zone
    if nodeName == "DamageZone" then
        isInDamageZone_ = false
        damageTimer_ = 0
        print("Left damage zone - safe now")
        UpdateUI()
    end
end

-- ============================================================================
-- SUMMARY: WHEN TO USE EACH EVENT
-- ============================================================================

--[[
┌─────────────────────┬─────────────────────────────────────────────────────┐
│ Scenario            │ Recommended Event + Notes                           │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Ground Detection    │ NodeCollision                                       │
│                     │ - Check contactNormal.y > 0.75                      │
│                     │ - Reset flag each frame, set if contact found       │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Collect Item        │ NodeCollisionStart                                  │
│                     │ - Item uses trigger=true                            │
│                     │ - Remove item on collision start                    │
│                     │ - NEVER use NodeCollision (fires every frame!)      │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Enter Zone          │ NodeCollisionStart                                  │
│                     │ - Zone uses trigger=true                            │
│                     │ - Set flag / trigger action                         │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Exit Zone           │ NodeCollisionEnd                                    │
│                     │ - Clear flag / stop action                          │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Continuous Damage   │ Track state in Update()                             │
│                     │ - Use Enter/Exit to set damage flag                 │
│                     │ - Apply damage over time in Update loop             │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Impact Damage       │ NodeCollisionStart                                  │
│                     │ - Check contactImpulse for damage amount            │
│                     │ - Higher impulse = harder hit                       │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Global Manager      │ PhysicsCollisionStart (global subscription)         │
│                     │ - When you need to handle ALL collisions            │
│                     │ - Check NodeA and NodeB to determine participants   │
│                     │ - See HandleGlobalCollisionStart() in this file     │
│                     │ - NOTE: No Contacts buffer in global events!        │
└─────────────────────┴─────────────────────────────────────────────────────┘

COMPARISON: Node-Level vs Global Subscription
─────────────────────────────────────────────────────────────────────────────
┌──────────────────────┬─────────────────────────┬─────────────────────────┐
│ Feature              │ Node-Level              │ Global                  │
│                      │ (NodeCollisionStart)    │ (PhysicsCollisionStart) │
├──────────────────────┼─────────────────────────┼─────────────────────────┤
│ Subscription         │ self:SubscribeToEvent(  │ SubscribeToEvent(       │
│                      │   self.node, "Event",   │   "Event", "Handler")   │
│                      │   "Handler")            │                         │
├──────────────────────┼─────────────────────────┼─────────────────────────┤
│ Receives events for  │ Only this node          │ ALL nodes in scene      │
├──────────────────────┼─────────────────────────┼─────────────────────────┤
│ Event data           │ OtherNode, OtherBody,   │ NodeA, NodeB,           │
│                      │ Contacts buffer         │ BodyA, BodyB            │
├──────────────────────┼─────────────────────────┼─────────────────────────┤
│ Has Contacts?        │ YES                     │ NO                      │
├──────────────────────┼─────────────────────────┼─────────────────────────┤
│ Best for             │ ScriptObject components │ Game managers,          │
│                      │                         │ Audio, Analytics        │
└──────────────────────┴─────────────────────────┴─────────────────────────┘
]]

-- ============================================================================
-- END OF FILE
-- ============================================================================
