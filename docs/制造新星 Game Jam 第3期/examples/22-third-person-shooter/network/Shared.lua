-- ============================================================================
-- Shared.lua - Shared Code for Server and Client
-- ============================================================================

local Shared = {}
local Settings = require("config.Settings")

-- Re-export settings for convenience
Shared.Settings = Settings
Shared.CTRL = Settings.CTRL
Shared.EVENTS = Settings.EVENTS
Shared.VARS = Settings.VARS

-- ============================================================================
-- Utility Functions
-- ============================================================================

function Shared.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Shared.GetRandomSpawnPoint()
    local index = math.random(1, #Settings.SpawnPoints)
    return Settings.SpawnPoints[index]
end

function Shared.GetSpawnPointByIndex(index)
    local i = ((index - 1) % #Settings.SpawnPoints) + 1
    return Settings.SpawnPoints[i]
end

-- ============================================================================
-- Material Creation
-- ============================================================================

function Shared.CreatePBRMaterial(color, metallic, roughness)
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(color.r, color.g, color.b, 1.0)))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    return material
end

-- ============================================================================
-- Scene Creation
-- ============================================================================

function Shared.CreateScene(isServer)
    local scene = Scene()

    scene:CreateComponent("Octree", LOCAL)
    scene:CreateComponent("DebugRenderer", LOCAL)

    local physicsWorld = scene:CreateComponent("PhysicsWorld", LOCAL)
    physicsWorld:SetGravity(Vector3(0, -20.0, 0))

    -- Lighting (client only)
    if not isServer then
        scene:InstantiateXML("LightGroup/Daytime.xml", Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
    end

    -- Create map
    Shared.CreateMap(scene, isServer)

    return scene
end

-- ============================================================================
-- Map Creation
-- ============================================================================

function Shared.CreateMap(scene, isServer)
    local mapSize = 40
    local halfSize = mapSize / 2
    local wallHeight = 3.0

    -- Ground
    local floor = scene:CreateChild("Floor", LOCAL)
    floor.position = Vector3(0, -0.5, 0)
    floor.scale = Vector3(mapSize, 1, mapSize)
    if not isServer then
        local floorModel = floor:CreateComponent("StaticModel", LOCAL)
        floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        floorModel:SetMaterial(Shared.CreatePBRMaterial(Color(0.3, 0.3, 0.35), 0.0, 0.8))
    end

    local floorBody = floor:CreateComponent("RigidBody", LOCAL)
    floorBody:SetCollisionLayer(1)
    local floorShape = floor:CreateComponent("CollisionShape", LOCAL)
    floorShape:SetBox(Vector3(1, 1, 1))

    -- Walls
    Shared.CreateWall(scene, Vector3(0, wallHeight / 2, -halfSize), Vector3(mapSize, wallHeight, 1), isServer)
    Shared.CreateWall(scene, Vector3(0, wallHeight / 2, halfSize), Vector3(mapSize, wallHeight, 1), isServer)
    Shared.CreateWall(scene, Vector3(-halfSize, wallHeight / 2, 0), Vector3(1, wallHeight, mapSize), isServer)
    Shared.CreateWall(scene, Vector3(halfSize, wallHeight / 2, 0), Vector3(1, wallHeight, mapSize), isServer)

    -- Cover
    Shared.CreateCover(scene, Vector3(0, 1, 0), Vector3(4, 2, 4), Color(0.5, 0.4, 0.3), isServer)
    Shared.CreateCover(scene, Vector3(-12, 0.75, -12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
    Shared.CreateCover(scene, Vector3(12, 0.75, -12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
    Shared.CreateCover(scene, Vector3(-12, 0.75, 12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
    Shared.CreateCover(scene, Vector3(12, 0.75, 12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
end

function Shared.CreateWall(scene, position, size, isServer)
    local wall = scene:CreateChild("Wall", LOCAL)
    wall.position = position
    wall.scale = size

    if not isServer then
        local model = wall:CreateComponent("StaticModel", LOCAL)
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Shared.CreatePBRMaterial(Color(0.4, 0.4, 0.45), 0.0, 0.7))
    end

    local body = wall:CreateComponent("RigidBody", LOCAL)
    body:SetCollisionLayer(1)
    local shape = wall:CreateComponent("CollisionShape", LOCAL)
    shape:SetBox(Vector3(1, 1, 1))
end

function Shared.CreateCover(scene, position, size, color, isServer)
    local cover = scene:CreateChild("Cover", LOCAL)
    cover.position = position
    cover.scale = size

    if not isServer then
        local model = cover:CreateComponent("StaticModel", LOCAL)
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Shared.CreatePBRMaterial(color, 0.1, 0.6))
        model.castShadows = true
    end

    local body = cover:CreateComponent("RigidBody", LOCAL)
    body:SetCollisionLayer(1)
    local shape = cover:CreateComponent("CollisionShape", LOCAL)
    shape:SetBox(Vector3(1, 1, 1))
end

-- ============================================================================
-- Register Remote Events
-- ============================================================================

function Shared.RegisterEvents()
    for _, eventName in pairs(Settings.EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

return Shared
