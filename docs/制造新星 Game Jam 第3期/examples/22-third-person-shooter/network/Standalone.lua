-- ============================================================================
-- Standalone.lua - Single Player Mode
-- ============================================================================

local Standalone = {}

require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/Touch"
require "urhox-libs.UI.GameHUD"

local Settings = require("config.Settings")
local Character = require("game.Character")
local StateMachine = require("game.StateMachine")

-- ============================================================================
-- Variables
-- ============================================================================

local scene_ = nil
local cameraNode_ = nil
local playerData_ = nil

-- State
local isAiming_ = false

-- Camera state
local currentCameraDistance_ = 5.0
local currentCameraOffset_ = Vector3(0, 1.7, 0)
local currentCameraFOV_ = 45.0

-- NanoVG for crosshair
local nvgContext_ = nil

-- ============================================================================
-- Entry
-- ============================================================================

function Standalone.Start()
    SampleStart()

    CreateScene()
    CreatePlayer()
    CreateInstructions()
    CreateGameHUD()
    SubscribeToEvents()

    SampleInitMouseMode(MM_RELATIVE)
    print("=== Third Person Shooter - Standalone Mode ===")
end

function Standalone.Stop()
    if nvgContext_ ~= nil then
        nvgDelete(nvgContext_)
        nvgContext_ = nil
    end
end

-- ============================================================================
-- Scene Creation
-- ============================================================================

function CreateScene()
    scene_ = Scene:new()

    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")
    scene_:CreateComponent("DebugRenderer")

    -- Camera
    cameraNode_ = Node()
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = Settings.Camera.farClip
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- Lighting
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    if lightGroupFile then
        local lightGroup = scene_:CreateChild("LightGroup")
        lightGroup:LoadXML(lightGroupFile:GetRoot())
    end

    -- Create simple ground
    CreateGround()
end

function CreateGround()
    -- Main floor
    local floor = scene_:CreateChild("Floor")
    floor.position = Vector3(0, -0.5, 0)
    floor.scale = Vector3(50, 1, 50)

    local model = floor:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))

    local body = floor:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = floor:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)

    -- Some obstacles
    CreateBox(Vector3(5, 0.5, 5), Vector3(2, 1, 2))
    CreateBox(Vector3(-5, 1, -5), Vector3(3, 2, 3))
    CreateBox(Vector3(10, 0.75, -8), Vector3(4, 1.5, 2))
end

function CreateBox(position, size)
    local box = scene_:CreateChild("Box")
    box.position = position
    box.scale = size

    local model = box:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))
    model.castShadows = true

    local body = box:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = box:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

-- ============================================================================
-- Player Creation
-- ============================================================================

function CreatePlayer()
    playerData_ = Character.Create(scene_, Vector3(0, 1, 0), true)
    Character.UpdateRotationMode(playerData_)
end

-- ============================================================================
-- UI Creation
-- ============================================================================

function CreateInstructions()
    local instructionText = ui.root:CreateChild("Text")
    instructionText.text =
        "WASD: Move | Shift: Run | Space: Jump | Q: Toggle Rifle\n" ..
        "C: Crouch | 1: Dance | 2: Sad | 3: Die\n" ..
        "Rifle Mode: LMB=Shoot | R=Reload | RMB=Aim"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 15)
    instructionText.textAlignment = HA_CENTER
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(0, 10)
end

function CreateGameHUD()
    GameHUD.Initialize()
    GameHUD.SetControls(playerData_.character.controls)

    GameHUD.Create({
        enableJump = true,
        enableRun = true,
        enableCrouch = true,
        enableShooter = true,
        onArm = function(isArmed)
            Character.CycleFSM(playerData_)
        end,
        onShoot = function()
            StateMachine.TriggerShoot(playerData_.fsmManager)
        end,
        onReload = function()
            StateMachine.TriggerReload(playerData_.fsmManager)
        end,
        onAimChange = function(isAiming)
            isAiming_ = isAiming
        end,
        onCrouch = function(isCrouching)
            Character.ToggleCrouch(playerData_)
        end,
    })

    GameHUD.EnableTouchLook({
        camera = cameraNode_,
    })

    -- Create NanoVG context for crosshair
    nvgContext_ = nvgCreate(1)
    if nvgContext_ then
        SubscribeToEvent(nvgContext_, "NanoVGRender", "HandleCrosshairRender")
    end
end

-- ============================================================================
-- Event Handling
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    UnsubscribeFromEvent("SceneUpdate")
end

function HandleUpdate(eventType, eventData)
    if playerData_ == nil then return end

    local dt = eventData["TimeStep"]:GetFloat()
    local character = playerData_.character

    -- Update shoot state and recovery timer
    StateMachine.UpdateShootState(playerData_.fsmManager, dt)

    -- Clear previous controls
    character.controls:Set(CTRL_FORWARD + CTRL_BACK + CTRL_LEFT + CTRL_RIGHT + CTRL_JUMP + CTRL_RUN, false)

    if touchEnabled then UpdateTouches(character.controls) end

    if ui.focusElement == nil then
        -- Keyboard input
        if not touchEnabled or not useGyroscope then
            if input:GetKeyDown(KEY_W) then character.controls:Set(CTRL_FORWARD, true) end
            if input:GetKeyDown(KEY_S) then character.controls:Set(CTRL_BACK, true) end
            if input:GetKeyDown(KEY_A) then character.controls:Set(CTRL_LEFT, true) end
            if input:GetKeyDown(KEY_D) then character.controls:Set(CTRL_RIGHT, true) end
        end
        if input:GetKeyDown(KEY_SPACE) then character.controls:Set(CTRL_JUMP, true) end
        if input:GetKeyDown(KEY_SHIFT) then
            -- Disable running while shooting (force walk mode)
            if not StateMachine.IsShooting(playerData_.fsmManager) then
                character.controls:Set(CTRL_RUN, true)
            end
        end

        -- Mouse look
        if not touchEnabled then
            character.controls.yaw = character.controls.yaw + input.mouseMoveX * Settings.Input.MouseSensitivity
            character.controls.pitch = character.controls.pitch + input.mouseMoveY * Settings.Input.MouseSensitivity
        end
        character.controls.pitch = Clamp(character.controls.pitch, -80.0, 80.0)

        -- Q: Toggle FSM is handled by GameHUD.onArm callback

        -- C: Toggle crouch is handled by GameHUD.onCrouch callback

        -- Emotes (Normal only)
        if not StateMachine.IsArmedMode(playerData_.fsmManager) then
            if input:GetKeyPress(KEY_1) then
                StateMachine.TriggerDance(playerData_.fsmManager)
            end
            if input:GetKeyPress(KEY_2) then
                StateMachine.TriggerSad(playerData_.fsmManager)
            end
            if input:GetKeyPress(KEY_3) then
                StateMachine.TriggerDie(playerData_.fsmManager)
            end
        end

        -- Shoot (Armed modes only)
        if StateMachine.IsArmedMode(playerData_.fsmManager) then
            if input:GetMouseButtonPress(MOUSEB_LEFT) then
                StateMachine.TriggerShoot(playerData_.fsmManager)
            end
            if input:GetKeyPress(KEY_R) then
                StateMachine.TriggerReload(playerData_.fsmManager)
            end
            isAiming_ = input:GetMouseButtonDown(MOUSEB_RIGHT)
        else
            isAiming_ = false
        end

        -- Update rotation mode
        Character.UpdateRotationMode(playerData_)

        -- Debug keys
        if input:GetKeyPress(KEY_F5) and playerData_.fsmManager.fsm then
            playerData_.fsmManager.fsm:DebugPrintState()
        end

        -- Force disable running while shooting (handles GameHUD touch controls too)
        if StateMachine.IsShooting(playerData_.fsmManager) then
            character.controls:Set(CTRL_RUN, false)
        end
    end
end

function HandlePostUpdate(eventType, eventData)
    if playerData_ == nil then return end

    local timeStep = eventData["TimeStep"]:GetFloat()

    -- Update FSM parameters
    Character.UpdateFSM(playerData_)

    -- Update AimOffset
    local cameraPitch = cameraNode_.worldRotation:PitchAngle()
    local cameraYaw = cameraNode_.worldRotation:YawAngle()
    Character.UpdateAimOffset(playerData_, cameraPitch, cameraYaw)

    -- Update camera
    UpdateCamera(timeStep)
end

function UpdateCamera(timeStep)
    local character = playerData_.character
    local characterNode = playerData_.node

    -- Select target camera config
    local targetConfig
    if isAiming_ then
        targetConfig = Settings.Camera.aiming
    elseif playerData_.isArmed then
        targetConfig = Settings.Camera.armed
    else
        targetConfig = Settings.Camera.normal
    end

    -- Smooth transition
    local lerpFactor = 1.0 - math.exp(-Settings.Camera.transitionSpeed * timeStep)
    currentCameraDistance_ = Lerp(currentCameraDistance_, targetConfig.distance, lerpFactor)
    currentCameraOffset_ = currentCameraOffset_:Lerp(targetConfig.offset, lerpFactor)
    currentCameraFOV_ = Lerp(currentCameraFOV_, targetConfig.fov, lerpFactor)

    -- Apply FOV
    local camera = cameraNode_:GetComponent("Camera")
    if camera then
        camera.fov = currentCameraFOV_
    end

    -- Calculate camera position
    local rot = Quaternion(character.controls.yaw, Vector3.UP)
    local dir = rot * Quaternion(character.controls.pitch, Vector3.RIGHT)
    local aimPoint = characterNode.position + rot * currentCameraOffset_
    local rayDir = dir * Vector3(0.0, 0.0, -1.0)
    local rayDistance = currentCameraDistance_

    -- Wall collision
    local physicsWorld = scene_:GetComponent("PhysicsWorld")
    if physicsWorld then
        local result = physicsWorld:RaycastSingle(Ray(aimPoint, rayDir), rayDistance, CollisionMaskCamera)
        if result.body ~= nil then
            rayDistance = Min(rayDistance, result.distance)
        end
    end
    rayDistance = Clamp(rayDistance, CAMERA_MIN_DIST, currentCameraDistance_)

    cameraNode_.position = aimPoint + rayDir * rayDistance
    cameraNode_.rotation = dir
end

-- ============================================================================
-- Crosshair Rendering
-- ============================================================================

function HandleCrosshairRender(eventType, eventData)
    if not playerData_.isArmed or nvgContext_ == nil then
        return
    end

    local gfx = GetGraphics()
    local width = gfx:GetWidth()
    local height = gfx:GetHeight()

    nvgBeginFrame(nvgContext_, width, height, 1.0)
    DrawCrosshair(nvgContext_, width / 2, height / 2)
    nvgEndFrame(nvgContext_)
end

function DrawCrosshair(ctx, cx, cy)
    local size = isAiming_ and 8 or 12
    local gap = isAiming_ and 3 or 4
    local thickness = 2
    local r, g, b, a = 255, 255, 255, 200
    if isAiming_ then
        r, g, b, a = 255, 50, 50, 255
    end

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

return Standalone
