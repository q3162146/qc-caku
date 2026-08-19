-- ============================================================================
-- Client.lua - Multiplayer Client Logic
-- ============================================================================

local Client = {}
local Shared = require("network.Shared")

require "LuaScripts/Utilities/Sample"
require "urhox-libs.UI.GameHUD"

local Settings = Shared.Settings
local EVENTS = Shared.EVENTS
local CTRL = Shared.CTRL
local VARS = Shared.VARS

-- ============================================================================
-- Variables
-- ============================================================================

local scene_ = nil
local cameraNode_ = nil
local myRoleNode_ = nil

-- Camera control
local yaw_ = 0.0
local pitch_ = 0.0

-- Camera state
local currentCameraDistance_ = 5.0
local currentCameraOffset_ = Vector3(0, 1.7, 0)
local currentCameraFOV_ = 45.0

-- Player state
local health_ = Settings.Combat.MaxHealth
local maxHealth_ = Settings.Combat.MaxHealth
local isDead_ = false
local isAiming_ = false

-- Animation management
local playerAnimData_ = {}

-- Hit effects
local hitEffects_ = {}

-- Shoot cooldown
local shootCooldown_ = 0.0

-- Shoot recovery (from Settings)
local SHOOT_RECOVERY_TIME = Settings.Combat.ShootRecoveryTime
local shootRecoveryTimer_ = 0.0
local wasShootingAnim_ = false

-- NanoVG
local nvgCtx_ = nil
local fontNormal_ = -1

-- GameHUD
local hudComponents_ = nil

-- State
local pendingNodeId_ = 0
local pendingRoleNodes_ = {}
local needSendReady_ = false
local needBindControls_ = true
local pendingCallbacks_ = {}

-- ============================================================================
-- Entry
-- ============================================================================

function Client.Start()
    SampleStart()

    Shared.RegisterEvents()
    scene_ = Shared.CreateScene(false)

    SetupNanoVG()
    SetupCamera()
    SetupGameHUD()

    input.mouseMode = MM_RELATIVE

    SubscribeToEvent(EVENTS.ASSIGN_ROLE, "HandleAssignRole")
    SubscribeToEvent(EVENTS.HEALTH_UPDATE, "HandleHealthUpdate")
    SubscribeToEvent(EVENTS.PLAYER_DIED, "HandlePlayerDied")
    SubscribeToEvent(EVENTS.PLAYER_RESPAWN, "HandlePlayerRespawn")
    SubscribeToEvent(EVENTS.SHOOT_HIT, "HandleShootHit")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    SubscribeToEvent(scene_, "NodeAdded", "HandleNodeAdded")

    local serverConn = network:GetServerConnection()
    if serverConn then
        serverConn.scene = scene_
    end

    needSendReady_ = true
    print("[Client] Started")
end

function Client.Stop()
    if nvgCtx_ ~= nil then
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end
end

-- ============================================================================
-- Setup
-- ============================================================================

function SetupNanoVG()
    nvgCtx_ = nvgCreate(1)
    if nvgCtx_ == nil then
        print("[Client] ERROR: Failed to create NanoVG context")
        return
    end

    fontNormal_ = nvgCreateFont(nvgCtx_, "sans", "Fonts/MiSans-Regular.ttf")
    SubscribeToEvent(nvgCtx_, "NanoVGRender", "HandleNanoVGRender")
end

function SetupCamera()
    cameraNode_ = Node()
    local camera = cameraNode_:CreateComponent("Camera", LOCAL)
    camera.nearClip = 0.1
    camera.farClip = 500.0
    camera.fov = Settings.Camera.normal.fov

    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true
end

function SetupGameHUD()
    GameHUD.Initialize()

    hudComponents_ = GameHUD.Create({
        enableJump = true,
        enableRun = true,
        enableCrouch = true,
        enableShooter = true,

        onArm = function(armed)
            local serverConn = network:GetServerConnection()
            if serverConn then
                serverConn:SendRemoteEvent(EVENTS.CYCLE_WEAPON, true)
            end
        end,

        onCrouch = function(crouching)
            if myRoleNode_ == nil then return end
            local nodeId = myRoleNode_.ID
            local data = playerAnimData_[nodeId]
            if data and data.fsm then
                local current = data.fsm:GetBool("isCrouching")
                data.fsm:SetBool("isCrouching", not current)
            end
        end,

        onShoot = function()
            if myRoleNode_ == nil then return end
            local nodeId = myRoleNode_.ID
            local data = playerAnimData_[nodeId]
            if data and data.fsm then
                data.fsm:SetTrigger("shoot")
            end
        end,

        onReload = function()
            if myRoleNode_ == nil then return end
            local nodeId = myRoleNode_.ID
            local data = playerAnimData_[nodeId]
            if data and data.fsm then
                data.fsm:SetTrigger("reload")
            end
        end,

        onAimChange = function(aiming)
            isAiming_ = aiming
        end,
    })

    GameHUD.EnableTouchLook({
        camera = cameraNode_,
        onLook = function(deltaYaw, deltaPitch)
            yaw_ = yaw_ + deltaYaw
            pitch_ = pitch_ + deltaPitch
            pitch_ = Shared.Clamp(pitch_, -89.0, 89.0)
        end,
    })
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function HandleAssignRole(eventType, eventData)
    local nodeId = eventData["NodeId"]:GetUInt()
    local roleNode = scene_:GetNode(nodeId)
    if roleNode then
        BindToRole(roleNode)
    else
        pendingNodeId_ = nodeId
    end
end

function BindToRole(roleNode)
    myRoleNode_ = roleNode
    yaw_ = roleNode.rotation:YawAngle()
    print("[Client] Bound to role: " .. roleNode.name)
end

function HandleNodeAdded(eventType, eventData)
    local node = eventData["Node"]:GetPtr("Node")
    if node and node.replicated then
        table.insert(pendingRoleNodes_, node.ID)
    end
end

function HandleHealthUpdate(eventType, eventData)
    local nodeId = eventData["NodeId"]:GetUInt()
    local currentHealth = eventData["Health"]:GetInt()
    local maxHealthVal = eventData["MaxHealth"]:GetInt()

    if myRoleNode_ and nodeId == myRoleNode_.ID then
        health_ = currentHealth
        maxHealth_ = maxHealthVal
        if health_ <= 0 then isDead_ = true end
    end
end

function HandlePlayerDied(eventType, eventData)
    local victimId = eventData["VictimId"]:GetUInt()

    if myRoleNode_ and victimId == myRoleNode_.ID then
        isDead_ = true
        isAiming_ = false
    end
end

function HandlePlayerRespawn(eventType, eventData)
    local nodeId = eventData["NodeId"]:GetUInt()
    local currentHealth = eventData["Health"]:GetInt()
    local maxHealthVal = eventData["MaxHealth"]:GetInt()

    if myRoleNode_ and nodeId == myRoleNode_.ID then
        isDead_ = false
        health_ = currentHealth
        maxHealth_ = maxHealthVal
    end
end

function HandleShootHit(eventType, eventData)
    local hitX = eventData["HitX"]:GetFloat()
    local hitY = eventData["HitY"]:GetFloat()
    local hitZ = eventData["HitZ"]:GetFloat()
    SpawnHitEffect(Vector3(hitX, hitY, hitZ))
end

-- Convert network weapon type string to int (0=normal, 1=rifle, 2=pistol, 3=dagger)
function GetNodeWeaponType(node)
    local weaponVar = node:GetVar(VARS.WEAPON_TYPE)
    if weaponVar:IsEmpty() then return 0 end
    local weaponStr = weaponVar:GetString()
    if weaponStr == "rifle" then return 1 end
    if weaponStr == "pistol" then return 2 end
    if weaponStr == "dagger" then return 3 end
    return 0
end

function IsNodeArmed(node)
    return GetNodeWeaponType(node) > 0
end

-- Check if node has a ranged weapon (rifle or pistol)
function IsNodeRanged(node)
    local wt = GetNodeWeaponType(node)
    return wt == 1 or wt == 2
end

-- ============================================================================
-- Animation Setup
-- ============================================================================

function SetupPlayerAnimation(roleNode)
    local nodeId = roleNode.ID
    if playerAnimData_[nodeId] then return true end

    local modelNode = roleNode:GetChild("ModelNode")
    if modelNode == nil then
        modelNode = scene_:InstantiateXML(Settings.Player.Prefab, Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
        if modelNode then
            modelNode.name = "ModelNode"
            modelNode.parent = roleNode
            modelNode.position = Vector3.ZERO
            modelNode.rotation = Quaternion.IDENTITY
        else
            print("[Client] ERROR: Failed to load prefab")
            return false
        end
    end

    modelNode:GetOrCreateComponent("AnimationController", LOCAL)

    local stateMachine = modelNode:CreateComponent("AnimationStateMachine", LOCAL)
    local unifiedFile = cache:GetResource("JSONFile", Settings.FSM.Unified)

    if unifiedFile then
        stateMachine:LoadFromJSONFile(unifiedFile)
        stateMachine:Start()
    else
        print("[Client] ERROR: Unified FSM not found: " .. Settings.FSM.Unified)
    end

    local aimOffset = modelNode:CreateComponent("AimOffset", LOCAL)
    aimOffset:AddBone("Bip001 Spine", 0.40, 0.40)
    aimOffset:AddBone("Bip001 Spine1", 0.35, 0.35)
    aimOffset:AddBone("Bip001 Spine2", 0.25, 0.25)
    aimOffset:SetMaxPitch(50)
    aimOffset:SetMaxYaw(30)
    aimOffset:SetSmoothSpeed(12)
    aimOffset:SetEnabled(false)

    playerAnimData_[nodeId] = {
        fsm = stateMachine,
        weaponType = 0,  -- 0=normal, 1=rifle, 3=dagger
        aimOffset = aimOffset,
        modelNode = modelNode,
        lastYaw = 0,  -- For turn detection
    }

    print("[Client] SetupPlayerAnimation: " .. roleNode.name)
    return true
end

function SetPlayerWeaponType(nodeId, weaponType)
    local data = playerAnimData_[nodeId]
    if data == nil then return end

    if data.weaponType == weaponType then return end

    data.weaponType = weaponType

    if data.fsm then
        data.fsm:SetInt("weaponType", weaponType)
    end

    -- Enable AimOffset only when armed
    local isArmed = (weaponType > 0)
    if data.aimOffset then
        data.aimOffset:SetEnabled(isArmed)
    end
end

-- ============================================================================
-- Update Loop
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    ProcessPendingCallbacks()
    UpdateHitEffects(dt)
    UpdateShootRecovery(dt)

    -- Process pending replicated nodes
    if #pendingRoleNodes_ > 0 then
        local nodesToCheck = pendingRoleNodes_
        pendingRoleNodes_ = {}
        for _, nodeId in ipairs(nodesToCheck) do
            local node = scene_:GetNode(nodeId)
            if node then
                local isRoleVar = node:GetVar(VARS.IS_ROLE)
                if not isRoleVar:IsEmpty() and isRoleVar:GetBool() then
                    if not playerAnimData_[nodeId] then
                        SetupPlayerAnimation(node)
                    end
                end
            end
        end
    end

    -- Check pending node
    if pendingNodeId_ ~= 0 then
        local roleNode = scene_:GetNode(pendingNodeId_)
        if roleNode then
            pendingNodeId_ = 0
            BindToRole(roleNode)
        end
    end

    local serverConn = network:GetServerConnection()

    -- Bind GameHUD to network controls
    if needBindControls_ and serverConn then
        needBindControls_ = false
        GameHUD.SetControls(serverConn.controls)
    end

    -- Send Ready event
    if needSendReady_ then
        needSendReady_ = false
        if serverConn then
            serverConn:SendRemoteEvent(EVENTS.CLIENT_READY, true)
        end
    end

    if myRoleNode_ == nil then return end
    if isDead_ then return end

    UpdateMouseLook(dt)
    UpdateMovement(dt)
end

function HandlePostUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    UpdateCamera(dt)
    UpdateAllAnimations()
end

function UpdateMouseLook(dt)
    -- Skip mouse look in touch mode (handled by GameHUD.EnableTouchLook)
    if touchEnabled then return end

    local mouseMove = input.mouseMove
    yaw_ = yaw_ + mouseMove.x * Settings.Input.MouseSensitivity
    pitch_ = pitch_ + mouseMove.y * Settings.Input.MouseSensitivity
    pitch_ = Shared.Clamp(pitch_, -89.0, 89.0)
end

function UpdateMovement(dt)
    if myRoleNode_ == nil then return end

    local serverConn = network:GetServerConnection()
    if serverConn == nil then return end

    local controls = serverConn.controls
    controls.yaw = yaw_
    controls.pitch = pitch_

    local isShooting = false
    if IsMyRoleRanged() then  -- Only rifle sends CTRL.SHOOT to server
        isShooting = input:GetMouseButtonDown(MOUSEB_LEFT)
        if hudComponents_ and hudComponents_.shootButton then
            isShooting = isShooting or hudComponents_.shootButton.isPressed
        end
    end
    controls:Set(CTRL.SHOOT, isShooting)

    -- Disable running while shooting (force walk mode)
    if IsMyRoleCurrentlyShooting() then
        controls:Set(CTRL.RUN, false)
    end

    if shootCooldown_ > 0 then
        shootCooldown_ = shootCooldown_ - dt
    end

    if IsMyRoleArmed() and input:GetMouseButtonPress(MOUSEB_LEFT) and shootCooldown_ <= 0 then
        shootCooldown_ = Settings.Combat.ShootInterval
        local nodeId = myRoleNode_.ID
        local data = playerAnimData_[nodeId]
        if data and data.fsm then
            data.fsm:SetTrigger("shoot")
        end
    end
end

function IsMyRoleArmed()
    if myRoleNode_ == nil then return false end
    return IsNodeArmed(myRoleNode_)
end

function IsMyRoleRanged()
    if myRoleNode_ == nil then return false end
    return IsNodeRanged(myRoleNode_)
end

-- Check if UpperBody layer is currently in a shoot animation state
-- Unified.fsm: Base=0, LowerBody=1, UpperBody=2, FullBody=3
function IsInShootAnimation()
    if myRoleNode_ == nil then return false end

    local nodeId = myRoleNode_.ID
    local data = playerAnimData_[nodeId]
    if data == nil or data.fsm == nil then return false end

    local upperBodyState = data.fsm:GetCurrentState(2)

    return upperBodyState == "RifleShoot" or
           upperBodyState == "RifleCrouchShoot" or
           upperBodyState == "PistolShoot" or
           upperBodyState == "PistolCrouchShoot"
end

-- Update shoot state and recovery timer
function UpdateShootRecovery(dt)
    local currentlyShooting = IsInShootAnimation()

    -- Detect shoot animation end -> start recovery timer
    if wasShootingAnim_ and not currentlyShooting then
        shootRecoveryTimer_ = SHOOT_RECOVERY_TIME
    end

    wasShootingAnim_ = currentlyShooting

    -- Count down recovery timer
    if shootRecoveryTimer_ > 0 then
        shootRecoveryTimer_ = shootRecoveryTimer_ - dt
    end
end

-- Check if currently shooting OR in post-shoot recovery (should disable running)
function IsMyRoleCurrentlyShooting()
    -- In shoot animation
    if IsInShootAnimation() then
        return true
    end

    -- In post-shoot recovery
    if shootRecoveryTimer_ > 0 then
        return true
    end

    return false
end

function UpdateCamera(dt)
    if myRoleNode_ == nil or cameraNode_ == nil then return end

    local targetConfig
    if isAiming_ then
        targetConfig = Settings.Camera.aiming
    elseif IsMyRoleArmed() then
        targetConfig = Settings.Camera.armed
    else
        targetConfig = Settings.Camera.normal
    end

    local lerpFactor = 1.0 - math.exp(-Settings.Camera.transitionSpeed * dt)
    currentCameraDistance_ = Lerp(currentCameraDistance_, targetConfig.distance, lerpFactor)
    currentCameraOffset_ = currentCameraOffset_:Lerp(targetConfig.offset, lerpFactor)
    currentCameraFOV_ = Lerp(currentCameraFOV_, targetConfig.fov, lerpFactor)

    local camera = cameraNode_:GetComponent("Camera")
    if camera then
        camera.fov = currentCameraFOV_
    end

    local rot = Quaternion(yaw_, Vector3.UP)
    local dir = rot * Quaternion(pitch_, Vector3.RIGHT)
    local aimPoint = myRoleNode_.position + rot * currentCameraOffset_
    local rayDir = dir * Vector3(0, 0, -1)
    local distance = currentCameraDistance_

    local physicsWorld = scene_:GetComponent("PhysicsWorld")
    if physicsWorld then
        local result = physicsWorld:RaycastSingle(Ray(aimPoint, rayDir), distance, 1)
        if result.body then
            distance = math.max(1.0, result.distance - 0.2)
        end
    end

    cameraNode_.position = aimPoint + rayDir * distance
    cameraNode_.rotation = dir
end

function UpdateAllAnimations()
    for nodeId, data in pairs(playerAnimData_) do
        local roleNode = scene_:GetNode(nodeId)
        if roleNode then
            local character = roleNode:GetComponent("CharacterComponent")
            if character and data.fsm then
                -- Sync weapon type from network variable
                local weaponType = GetNodeWeaponType(roleNode)
                if data.weaponType ~= weaponType then
                    SetPlayerWeaponType(nodeId, weaponType)
                end

                local isArmed = (weaponType > 0)

                -- moveSpeed and moveDirection are synced via CharacterComponent attributes
                local moveSpeed = character.moveSpeed
                data.fsm:SetFloat("moveSpeed", moveSpeed)
                data.fsm:SetFloat("direction", character:GetMoveDirection())
                data.fsm:SetBool("isGrounded", character.onGround)

                -- Turn detection using character yaw delta
                local characterYaw = roleNode.worldRotation:YawAngle()
                local yawDelta = characterYaw - data.lastYaw
                -- Handle -180/180 wrap
                if yawDelta > 180 then yawDelta = yawDelta - 360 end
                if yawDelta < -180 then yawDelta = yawDelta + 360 end
                local isTurning = moveSpeed < 0.1 and math.abs(yawDelta) > 0.5
                data.fsm:SetBool("isTurning", isTurning)
                data.lastYaw = characterYaw

                if character.jumpStarted then
                    data.fsm:SetTrigger("jump")
                end

                if data.aimOffset then
                    data.aimOffset:SetEnabled(isArmed)
                    if isArmed and myRoleNode_ and roleNode.ID == myRoleNode_.ID then
                        data.aimOffset:SetTargetPitch(pitch_)
                        local characterYaw = roleNode.worldRotation:YawAngle()
                        local relativeYaw = yaw_ - characterYaw
                        while relativeYaw > 180 do relativeYaw = relativeYaw - 360 end
                        while relativeYaw < -180 do relativeYaw = relativeYaw + 360 end
                        data.aimOffset:SetTargetYaw(relativeYaw)
                    end
                end
            end
        else
            playerAnimData_[nodeId] = nil
        end
    end
end

-- ============================================================================
-- Hit Effects
-- ============================================================================

function SpawnHitEffect(position)
    local effectNode = scene_:CreateChild("HitEffect", LOCAL)
    effectNode.position = position

    local model = effectNode:CreateComponent("StaticModel", LOCAL)
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    effectNode.scale = Vector3(0.1, 0.1, 0.1)

    local material = Shared.CreatePBRMaterial(Color(1, 0.8, 0), 0.9, 0.2)
    material:SetShaderParameter("MatEmissiveColor", Variant(Color(2, 1.5, 0)))
    model:SetMaterial(material)

    table.insert(hitEffects_, { node = effectNode, lifeTime = 0.3, elapsed = 0 })
end

function UpdateHitEffects(dt)
    local i = 1
    while i <= #hitEffects_ do
        local effect = hitEffects_[i]
        effect.elapsed = effect.elapsed + dt

        local scale = 0.1 * (1 - effect.elapsed / effect.lifeTime)
        if scale <= 0 or effect.elapsed >= effect.lifeTime then
            effect.node:Remove()
            table.remove(hitEffects_, i)
        else
            effect.node.scale = Vector3(scale, scale, scale)
            i = i + 1
        end
    end
end

-- ============================================================================
-- NanoVG UI
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if nvgCtx_ == nil then return end

    local gfx = GetGraphics()
    local width = gfx:GetWidth()
    local height = gfx:GetHeight()

    nvgBeginFrame(nvgCtx_, width, height, 1.0)

    DrawHealthBar(nvgCtx_, width, height)
    if IsMyRoleRanged() then  -- Only rifle shows crosshair
        DrawCrosshair(nvgCtx_, width / 2, height / 2)
    end
    if isDead_ then
        DrawDeathScreen(nvgCtx_, width, height)
    end

    nvgEndFrame(nvgCtx_)
end

function DrawHealthBar(ctx, width, height)
    local barWidth, barHeight = 200, 20
    local x, y = 20, height - 50
    local healthPercent = health_ / maxHealth_

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, barWidth, barHeight, 4)
    nvgFillColor(ctx, nvgRGBA(50, 50, 50, 180))
    nvgFill(ctx)

    local r, g, b = 200, 50, 50
    if healthPercent > 0.5 then r, g, b = 50, 200, 50
    elseif healthPercent > 0.25 then r, g, b = 200, 200, 50 end

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 2, y + 2, (barWidth - 4) * healthPercent, barHeight - 4, 2)
    nvgFillColor(ctx, nvgRGBA(r, g, b, 220))
    nvgFill(ctx)

    if fontNormal_ ~= -1 then
        nvgFontFaceId(ctx, fontNormal_)
        nvgFontSize(ctx, 16)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(ctx, x + barWidth / 2, y + barHeight / 2, health_ .. " / " .. maxHealth_)
    end
end

function DrawCrosshair(ctx, cx, cy)
    local size = isAiming_ and 8 or 12
    local gap = isAiming_ and 3 or 4
    local thickness = 2
    local r, g, b, a = 255, 255, 255, 200
    if isAiming_ then r, g, b, a = 255, 50, 50, 255 end

    nvgStrokeColor(ctx, nvgRGBA(r, g, b, a))
    nvgStrokeWidth(ctx, thickness)
    nvgFillColor(ctx, nvgRGBA(r, g, b, a))

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx, cy - gap - size)
    nvgLineTo(ctx, cx, cy - gap)
    nvgMoveTo(ctx, cx, cy + gap)
    nvgLineTo(ctx, cx, cy + gap + size)
    nvgMoveTo(ctx, cx - gap - size, cy)
    nvgLineTo(ctx, cx - gap, cy)
    nvgMoveTo(ctx, cx + gap, cy)
    nvgLineTo(ctx, cx + gap + size, cy)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, isAiming_ and 1.5 or 2)
    nvgFill(ctx)
end

function DrawDeathScreen(ctx, width, height)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(100, 0, 0, 150))
    nvgFill(ctx)

    if fontNormal_ ~= -1 then
        nvgFontFaceId(ctx, fontNormal_)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        nvgFontSize(ctx, 48)
        nvgFillColor(ctx, nvgRGBA(255, 50, 50, 255))
        nvgText(ctx, width / 2, height / 2 - 30, "YOU DIED")

        nvgFontSize(ctx, 24)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgText(ctx, width / 2, height / 2 + 30, "Waiting for respawn...")
    end
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

return Client
