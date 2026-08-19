-- ============================================================================
-- Character.lua - Character Creation and Management
-- ============================================================================

local Settings = require("config.Settings")
local StateMachine = require("game.StateMachine")

local Character = {}

-- Create a player character
function Character.Create(scene, position, isLocal)
    local objectNode = scene:CreateChild("Player")
    objectNode:SetPosition(position or Settings.Player.StartPos or Vector3(0, 2, 0))

    -- Create model node
    local modelNode = objectNode:CreateChild("ModelNode")

    -- Load prefab
    local prefabFile = cache:GetResource("XMLFile", Settings.Player.Prefab)
    if prefabFile then
        local success = modelNode:LoadXML(prefabFile:GetRoot())
        if success then
            print("Character prefab loaded: " .. Settings.Player.Prefab)
        else
            print("ERROR: Failed to load prefab")
        end
    else
        print("ERROR: Prefab not found: " .. Settings.Player.Prefab)
    end

    -- Create RigidBody
    local body = objectNode:CreateComponent("RigidBody")
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body:SetMass(1)
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- Create CollisionShape (capsule)
    local shape = objectNode:CreateComponent("CollisionShape")
    shape:SetCapsule(Settings.Player.Radius * 2, Settings.Player.Height,
                     Vector3(0.0, Settings.Player.Height / 2, 0.0))

    -- Create KinematicCharacterController
    local kinematicController = objectNode:CreateComponent("KinematicCharacterController")
    kinematicController:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
    kinematicController:SetJumpSpeed(8.0)

    -- Create CharacterComponent
    local character = objectNode:CreateComponent("CharacterComponent")
    character:SetAirControlFactor(Settings.Player.AirControlFactor)
    character:SetEnableWalkMode(Settings.Player.EnableWalkMode)

    -- Create FSM manager
    local fsmManager = StateMachine.Create(modelNode)

    return {
        node = objectNode,
        modelNode = modelNode,
        character = character,
        fsmManager = fsmManager,
        isCrouching = false,
        isArmed = false,
    }
end

-- Update character rotation mode based on FSM type
function Character.UpdateRotationMode(playerData)
    local isArmed = StateMachine.IsArmedMode(playerData.fsmManager)
    playerData.isArmed = isArmed

    -- Always face camera direction (third person shooter style)
    playerData.character.autoRotateToMoveDir = false
    playerData.character.rotationSpeed = 1440.0
end

-- Force character to face camera direction
function Character.FaceCameraDirection(playerData)
    local yaw = playerData.character.controls.yaw
    playerData.node.worldRotation = Quaternion(0, yaw, 0)
end

-- Toggle crouch
function Character.ToggleCrouch(playerData)
    playerData.isCrouching = not playerData.isCrouching
    StateMachine.SetCrouching(playerData.fsmManager, playerData.isCrouching)
end

-- Cycle weapon type
function Character.CycleWeapon(playerData)
    StateMachine.CycleWeapon(playerData.fsmManager)
    Character.UpdateRotationMode(playerData)

    -- When switching to armed mode, face camera direction
    if StateMachine.IsArmedMode(playerData.fsmManager) then
        Character.FaceCameraDirection(playerData)
    end
end

-- Alias for backwards compatibility
Character.CycleFSM = Character.CycleWeapon

-- Update FSM parameters
function Character.UpdateFSM(playerData)
    local characterYaw = playerData.node.worldRotation:YawAngle()
    StateMachine.UpdateFromCharacter(playerData.fsmManager, playerData.character, characterYaw)
    StateMachine.SetCrouching(playerData.fsmManager, playerData.isCrouching)
end

-- Update AimOffset
function Character.UpdateAimOffset(playerData, cameraPitch, cameraYaw)
    if not playerData.isArmed then return end

    local characterYaw = playerData.node.worldRotation:YawAngle()
    StateMachine.UpdateAimOffset(playerData.fsmManager, cameraPitch, cameraYaw, characterYaw)
end

return Character
