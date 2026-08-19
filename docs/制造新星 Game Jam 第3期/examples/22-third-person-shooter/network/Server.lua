-- ============================================================================
-- Server.lua - Multiplayer Server Logic
-- ============================================================================

local Server = {}
local Shared = require("network.Shared")

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- Mock graphics for headless mode
-- ============================================================================

if GetGraphics() == nil then
    local mockGraphics = {
        SetWindowIcon = function() end,
        SetWindowTitleAndIcon = function() end,
        GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end,
    }
    function GetGraphics() return mockGraphics end
    graphics = mockGraphics
    console = { background = {} }
    function GetConsole() return console end
    debugHud = {}
    function GetDebugHud() return debugHud end
end

-- ============================================================================
-- Variables
-- ============================================================================

local scene_ = nil
local maxPlayers_ = Shared.Settings.Network.MaxPlayers

-- Role pool (pre-created)
local rolePool_ = {}
local roleAssignments_ = {}

-- Connection data
local connectionRoles_ = {}
local serverConnections_ = {}

-- Game data (indexed by roleId)
local serverHealth_ = {}
local serverShootCooldown_ = {}
local serverWeaponType_ = {}  -- "normal", "pistol", "rifle"

-- Delayed callbacks
local pendingCallbacks_ = {}
local delayedCallbacks_ = {}

-- Shortcuts
local Settings = Shared.Settings
local EVENTS = Shared.EVENTS
local CTRL = Shared.CTRL
local VARS = Shared.VARS

-- ============================================================================
-- Entry
-- ============================================================================

function Server.Start()
    SampleStart()

    Shared.RegisterEvents()
    scene_ = Shared.CreateScene(true)

    CreateRolePool()

    SubscribeToEvent(EVENTS.CLIENT_READY, "HandleClientReady")
    SubscribeToEvent(EVENTS.CYCLE_WEAPON, "HandleCycleWeapon")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent("Update", "HandleUpdate")

    print("[Server] Started with " .. maxPlayers_ .. " max players")
end

function Server.Stop()
end

-- ============================================================================
-- Role Pool
-- ============================================================================

function CreateRolePool()
    for roleId = 1, maxPlayers_ do
        local spawnPos = Shared.GetSpawnPointByIndex(roleId)
        local roleNode = CreatePlayerRole(scene_, roleId, spawnPos)

        rolePool_[roleId] = roleNode
        roleAssignments_[roleId] = nil

        serverHealth_[roleId] = { current = Settings.Combat.MaxHealth, max = Settings.Combat.MaxHealth }
        serverShootCooldown_[roleId] = 0
        serverWeaponType_[roleId] = "normal"

        print("[Server] Created Role_" .. roleId .. " (ID: " .. roleNode.ID .. ")")
    end
end

function CreatePlayerRole(scene, roleId, spawnPos)
    local roleNode = scene:CreateChild("Role_" .. roleId, REPLICATED)
    roleNode.position = spawnPos

    local body = roleNode:CreateComponent("RigidBody", REPLICATED)
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body.mass = 1.0
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    local shape = roleNode:CreateComponent("CollisionShape", REPLICATED)
    shape:SetCapsule(Settings.Player.Radius * 2, Settings.Player.Height,
                     Vector3(0, Settings.Player.Height / 2, 0))

    local kcc = roleNode:CreateComponent("KinematicCharacterController", LOCAL)
    kcc:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
    kcc:SetJumpSpeed(8.0)

    local character = roleNode:CreateComponent("CharacterComponent", REPLICATED)
    character:SetWalkSpeed(Settings.Player.WalkSpeed)
    character:SetRunSpeed(Settings.Player.RunSpeed)
    character:SetEnableWalkMode(true)
    character.autoRotateToMoveDir = false

    roleNode:SetVar(VARS.IS_ROLE, Variant(true))
    roleNode:SetVar(VARS.WEAPON_TYPE, Variant("normal"))

    return roleNode
end

function FindFreeRole()
    for roleId = 1, maxPlayers_ do
        if roleAssignments_[roleId] == nil then
            return roleId
        end
    end
    return nil
end

function ResetRoleState(roleId)
    local roleNode = rolePool_[roleId]
    if roleNode == nil then return end

    roleNode.position = Shared.GetSpawnPointByIndex(roleId)

    serverHealth_[roleId] = { current = Settings.Combat.MaxHealth, max = Settings.Combat.MaxHealth }
    serverShootCooldown_[roleId] = 0
    serverWeaponType_[roleId] = "normal"

    roleNode:SetVar(VARS.WEAPON_TYPE, Variant("normal"))

    local character = roleNode:GetComponent("CharacterComponent")
    if character then
        character.autoRotateToMoveDir = false
        character.rotationSpeed = 1440.0
    end
end

-- ============================================================================
-- Connection Handling
-- ============================================================================

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    print("[Server] ClientReady received")

    connection.scene = scene_

    local connKey = tostring(connection)
    local roleId = FindFreeRole()

    if roleId == nil then
        print("[Server] Server full, rejecting connection")
        connection:Disconnect()
        return
    end

    local roleNode = rolePool_[roleId]
    print("[Server] Assigning Role_" .. roleId .. " (ID: " .. roleNode.ID .. ")")

    roleAssignments_[roleId] = connKey
    connectionRoles_[connKey] = roleId
    serverConnections_[connKey] = connection

    roleNode:SetOwner(connection)
    ResetRoleState(roleId)

    local nodeId = roleNode.ID
    local conn = connection
    DelayOneFrame(function()
        local assignData = VariantMap()
        assignData["NodeId"] = Variant(nodeId)
        conn:SendRemoteEvent(EVENTS.ASSIGN_ROLE, true, assignData)
        print("[Server] Sent ASSIGN_ROLE, NodeId: " .. nodeId)
    end)
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData:GetPtr("Connection", "Connection")
    local connKey = tostring(connection)

    local roleId = connectionRoles_[connKey]
    if roleId then
        roleAssignments_[roleId] = nil
        local roleNode = rolePool_[roleId]
        if roleNode then
            roleNode:SetOwner(nil)
        end
        ResetRoleState(roleId)
    end

    connectionRoles_[connKey] = nil
    serverConnections_[connKey] = nil
    print("[Server] Client disconnected")
end

-- ============================================================================
-- Weapon State
-- ============================================================================

function HandleCycleWeapon(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local roleId = connectionRoles_[connKey]

    if roleId == nil then return end

    local roleNode = rolePool_[roleId]
    if roleNode == nil then return end

    -- Cycle: normal -> rifle -> pistol -> dagger -> normal
    local currentType = serverWeaponType_[roleId] or "normal"
    local newType
    if currentType == "normal" then
        newType = "rifle"
    elseif currentType == "rifle" then
        newType = "pistol"
    elseif currentType == "pistol" then
        newType = "dagger"
    else
        newType = "normal"
    end

    serverWeaponType_[roleId] = newType
    local isArmed = (newType ~= "normal")

    local character = roleNode:GetComponent("CharacterComponent")
    if character then
        character.autoRotateToMoveDir = false
        character.rotationSpeed = 1440.0
    end

    roleNode:SetVar(VARS.WEAPON_TYPE, Variant(newType))
    print("[Server] Role_" .. roleId .. " weapon: " .. newType)
end

-- ============================================================================
-- Update Loop
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    ProcessPendingCallbacks()
    ProcessDelayedCallbacks()

    for roleId, connKey in pairs(roleAssignments_) do
        if connKey then
            local roleNode = rolePool_[roleId]
            local connection = serverConnections_[connKey]

            if connection and roleNode then
                if serverShootCooldown_[roleId] > 0 then
                    serverShootCooldown_[roleId] = serverShootCooldown_[roleId] - dt
                end

                MoveRole(roleNode, connection, roleId, dt)
                HandleShoot(roleNode, connection, roleId, dt)
            end
        end
    end
end

function MoveRole(roleNode, connection, roleId, dt)
    local character = roleNode:GetComponent("CharacterComponent")
    if character == nil then return end

    local controls = connection.controls
    local buttons = controls.buttons

    character.controls:Set(CTRL_FORWARD, (buttons & CTRL.FORWARD) ~= 0)
    character.controls:Set(CTRL_BACK, (buttons & CTRL.BACK) ~= 0)
    character.controls:Set(CTRL_LEFT, (buttons & CTRL.LEFT) ~= 0)
    character.controls:Set(CTRL_RIGHT, (buttons & CTRL.RIGHT) ~= 0)
    character.controls:Set(CTRL_JUMP, (buttons & CTRL.JUMP) ~= 0)
    character.controls:Set(CTRL_RUN, (buttons & CTRL.RUN) ~= 0)

    character.controls.yaw = controls.yaw
    character.controls.pitch = controls.pitch
end

function HandleShoot(roleNode, connection, roleId, dt)
    local controls = connection.controls
    local buttons = controls.buttons

    if (buttons & CTRL.SHOOT) == 0 then return end
    if serverShootCooldown_[roleId] > 0 then return end

    local health = serverHealth_[roleId]
    if health == nil or health.current <= 0 then return end
    local weaponType = serverWeaponType_[roleId] or "normal"
    if weaponType ~= "rifle" and weaponType ~= "pistol" then return end  -- Only ranged weapons can shoot

    serverShootCooldown_[roleId] = Settings.Combat.ShootInterval

    local yaw = controls.yaw
    local pitch = controls.pitch

    local rot = Quaternion(yaw, Vector3.UP)
    local eyePos = roleNode.position + rot * Settings.Camera.armed.offset

    local yawRot = Quaternion(yaw, Vector3.UP)
    local pitchRot = Quaternion(pitch, Vector3.RIGHT)
    local shootDir = yawRot * pitchRot * Vector3.FORWARD

    local physicsWorld = scene_:GetComponent("PhysicsWorld")
    local result = physicsWorld:RaycastSingle(Ray(eyePos, shootDir), 100.0)

    if result.body ~= nil then
        local hitNode = result.body:GetNode()
        local hitPos = result.position

        BroadcastShootHit(hitPos)

        if hitNode ~= roleNode and string.find(hitNode.name, "Role_") then
            for hitRoleId, node in pairs(rolePool_) do
                if node == hitNode then
                    ApplyDamage(hitRoleId, Settings.Combat.DamagePerHit, roleId)
                    break
                end
            end
        end
    end
end

function BroadcastShootHit(hitPos)
    local eventData = VariantMap()
    eventData["HitX"] = Variant(hitPos.x)
    eventData["HitY"] = Variant(hitPos.y)
    eventData["HitZ"] = Variant(hitPos.z)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.SHOOT_HIT, true, eventData)
    end
end

-- ============================================================================
-- Damage System
-- ============================================================================

function ApplyDamage(victimRoleId, damage, attackerRoleId)
    local health = serverHealth_[victimRoleId]
    if health == nil or health.current <= 0 then return end

    health.current = health.current - damage
    if health.current < 0 then health.current = 0 end

    local victimNode = rolePool_[victimRoleId]
    local nodeId = victimNode and victimNode.ID or 0

    BroadcastHealthUpdate(nodeId, health.current, health.max)

    if health.current <= 0 then
        PlayerDied(victimRoleId, attackerRoleId)
    end
end

function BroadcastHealthUpdate(nodeId, current, max)
    local eventData = VariantMap()
    eventData["NodeId"] = Variant(nodeId)
    eventData["Health"] = Variant(current)
    eventData["MaxHealth"] = Variant(max)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.HEALTH_UPDATE, true, eventData)
    end
end

function PlayerDied(victimRoleId, attackerRoleId)
    local victimNode = rolePool_[victimRoleId]
    if victimNode == nil then return end

    local modelNode = victimNode:GetChild("ModelNode")
    if modelNode then
        modelNode.enabled = false
    end

    local eventData = VariantMap()
    eventData["VictimId"] = Variant(victimNode.ID)
    eventData["AttackerId"] = Variant(0)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.PLAYER_DIED, true, eventData)
    end

    local roleId = victimRoleId
    DelayFrames(180, function() RespawnPlayer(roleId) end)
end

function RespawnPlayer(roleId)
    local roleNode = rolePool_[roleId]
    local health = serverHealth_[roleId]

    if roleNode == nil or health == nil then return end

    health.current = health.max
    roleNode.position = Shared.GetRandomSpawnPoint()

    local modelNode = roleNode:GetChild("ModelNode")
    if modelNode then
        modelNode.enabled = true
    end

    local nodeId = roleNode.ID

    local eventData = VariantMap()
    eventData["NodeId"] = Variant(nodeId)
    eventData["Health"] = Variant(health.current)
    eventData["MaxHealth"] = Variant(health.max)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.PLAYER_RESPAWN, true, eventData)
    end

    BroadcastHealthUpdate(nodeId, health.current, health.max)
end

-- ============================================================================
-- Delayed Execution
-- ============================================================================

function DelayOneFrame(callback)
    table.insert(pendingCallbacks_, callback)
end

function ProcessPendingCallbacks()
    if #pendingCallbacks_ > 0 then
        local callbacks = pendingCallbacks_
        pendingCallbacks_ = {}
        for _, cb in ipairs(callbacks) do cb() end
    end
end

function DelayFrames(frames, callback)
    table.insert(delayedCallbacks_, { frames = frames, callback = callback })
end

function ProcessDelayedCallbacks()
    local i = 1
    while i <= #delayedCallbacks_ do
        local item = delayedCallbacks_[i]
        item.frames = item.frames - 1
        if item.frames <= 0 then
            item.callback()
            table.remove(delayedCallbacks_, i)
        else
            i = i + 1
        end
    end
end

return Server
