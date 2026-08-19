local UI = require("urhox-libs/UI")

---@type Scene|nil
local scene_ = nil
---@type Zone|nil
local zone_ = nil
---@type Node|nil
local cameraNode_ = nil
---@type Light|nil
local directionalLight_ = nil
---@type Light|nil
local pointLight_ = nil
---@type Light|nil
local spotLight_ = nil

local yaw_ = 32.0
local pitch_ = -24.0
local elapsedTime_ = 0.0

local MOVE_SPEED = 10.0
local MOUSE_SENSITIVITY = 0.12
local SURFACE_SHADER = "Shaders/BLGL/SurfaceCustomLightScene.shader"
local UI_PANEL_WIDTH = 340.0
local AMBIENT_SOURCE_OPTIONS = {
    { value = AMBIENT_COLOR, label = "AMBIENT_COLOR" },
    { value = AMBIENT_SKYBOX, label = "AMBIENT_SKYBOX" },
    { value = AMBIENT_PREBAKED, label = "AMBIENT_PREBAKED" },
}

function Start()
    graphics.windowTitle = "SurfaceShader Custom Light Scene"
    renderer.hdrRendering = true

    CreateScene()
    CreateFloor()
    CreateMeshes()
    CreateLights()
    SetupCamera()
    CreateUI()

    SubscribeToEvent("Update", "HandleUpdate")

    print("Surface custom light scene started")
    print("Shader: " .. SURFACE_SHADER)
    print("Lights: PointLight, SpotLight, DirectionalLight")
end

function Stop()
    UI.Shutdown()
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    local zoneNode = scene_:CreateChild("Zone")
    zone_ = zoneNode:CreateComponent("Zone")
    zone_.boundingBox = BoundingBox(Vector3(-80.0, -20.0, -80.0), Vector3(80.0, 60.0, 80.0))
    zone_.ambientSource = AMBIENT_COLOR
    zone_.ambientColor = Color(0.10, 0.12, 0.15, 1.0)
    zone_.fogColor = Color(0.045, 0.052, 0.065, 1.0)
    zone_.fogStart = 42.0
    zone_.fogEnd = 90.0
end

function CreateSurfaceMaterial(color, roughness, metallic, emission, checkerScale)
    local material = Material:new()
    if not material:SetSurfaceShader(SURFACE_SHADER) then
        print("ERROR: failed to load " .. SURFACE_SHADER)
        return nil
    end

    material:SetShaderParameter("base_color", Variant(color))
    material:SetShaderParameter("roughness_value", Variant(roughness))
    material:SetShaderParameter("metallic_value", Variant(metallic))
    material:SetShaderParameter("emission_color", Variant(emission or Vector3(0.0, 0.0, 0.0)))
    material:SetShaderParameter("checker_scale", Variant(checkerScale or 0.0))
    return material
end

function CreateStaticMesh(name, modelName, position, scale, rotation, color, roughness, metallic, emission)
    local node = scene_:CreateChild(name)
    node.position = position
    node.scale = scale
    if rotation ~= nil then
        node.rotation = rotation
    end

    local model = cache:GetResource("Model", modelName)
    if model == nil then
        print("WARN: missing model " .. modelName .. ", fallback to Models/Box.mdl")
        model = cache:GetResource("Model", "Models/Box.mdl")
    end

    local staticModel = node:CreateComponent("StaticModel")
    staticModel.model = model
    staticModel.material = CreateSurfaceMaterial(color, roughness, metallic, emission, 0.0)
    staticModel.castShadows = true
    return node
end

function CreateFloor()
    local floorNode = scene_:CreateChild("LargeSurfaceShaderFloor")
    floorNode.position = Vector3(0.0, 0.0, 0.0)
    floorNode.scale = Vector3(32.0, 1.0, 32.0)

    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Plane.mdl")
    floorModel.material = CreateSurfaceMaterial(Color(0.46, 0.50, 0.54, 1.0), 0.78, 0.0, Vector3(0.0, 0.0, 0.0), 12.0)
    floorModel.castShadows = false
end

function CreateMeshes()
    CreateStaticMesh("Box", "Models/Box.mdl", Vector3(-5.5, 0.75, 0.0), Vector3(1.5, 1.5, 1.5),
        Quaternion(0.0, 25.0, 0.0), Color(0.92, 0.28, 0.20, 1.0), 0.52, 0.0)
    CreateStaticMesh("Sphere", "Models/Sphere.mdl", Vector3(-2.7, 1.0, 0.2), Vector3(1.15, 1.15, 1.15),
        nil, Color(0.18, 0.54, 0.95, 1.0), 0.34, 0.0)
    CreateStaticMesh("Cylinder", "Models/Cylinder.mdl", Vector3(0.0, 1.0, -0.15), Vector3(1.15, 1.65, 1.15),
        Quaternion(0.0, -18.0, 0.0), Color(0.20, 0.86, 0.48, 1.0), 0.62, 0.0)
    CreateStaticMesh("Cone", "Models/Cone.mdl", Vector3(2.8, 0.95, 0.1), Vector3(1.35, 1.35, 1.35),
        Quaternion(0.0, 35.0, 0.0), Color(0.98, 0.68, 0.18, 1.0), 0.46, 0.0)
    CreateStaticMesh("Torus", "Models/Torus.mdl", Vector3(5.6, 1.2, 0.0), Vector3(1.35, 1.35, 1.35),
        Quaternion(70.0, 0.0, 0.0), Color(0.82, 0.45, 1.0, 1.0), 0.28, 0.15)

    CreateStaticMesh("Pyramid", "Models/Pyramid.mdl", Vector3(-3.8, 0.9, 3.6), Vector3(1.35, 1.35, 1.35),
        Quaternion(0.0, 45.0, 0.0), Color(0.86, 0.86, 0.88, 1.0), 0.22, 0.55)
    CreateStaticMesh("Teapot", "Models/TeaPot.mdl", Vector3(0.2, 0.85, 3.9), Vector3(0.9, 0.9, 0.9),
        Quaternion(0.0, -35.0, 0.0), Color(0.98, 0.92, 0.72, 1.0), 0.18, 0.75)
    CreateStaticMesh("BackBox", "Models/Box.mdl", Vector3(4.2, 0.5, 3.7), Vector3(1.4, 1.0, 1.4),
        Quaternion(0.0, -18.0, 0.0), Color(0.30, 0.95, 0.88, 1.0), 0.70, 0.0)
end

function CreateLights()
    local directionalNode = scene_:CreateChild("DirectionalLight")
    directionalNode.direction = Vector3(0.35, -1.0, 0.25)
    directionalLight_ = directionalNode:CreateComponent("Light")
    directionalLight_.lightType = LIGHT_DIRECTIONAL
    directionalLight_.color = Color(1.0, 0.92, 0.78, 1.0)
    directionalLight_.brightness = 0.75
    directionalLight_.castShadows = true

    local pointNode = scene_:CreateChild("PointLight")
    pointNode.position = Vector3(-4.0, 3.0, -3.2)
    pointLight_ = pointNode:CreateComponent("Light")
    pointLight_.lightType = LIGHT_POINT
    pointLight_.color = Color(0.25, 0.52, 1.0, 1.0)
    pointLight_.range = 9.0
    pointLight_.brightness = 3.8
    pointLight_.castShadows = true

    local spotNode = scene_:CreateChild("SpotLight")
    spotNode.position = Vector3(4.5, 5.2, -4.5)
    spotNode:LookAt(Vector3(1.1, 0.6, 0.6))
    spotLight_ = spotNode:CreateComponent("Light")
    spotLight_.lightType = LIGHT_SPOT
    spotLight_.color = Color(1.0, 0.38, 0.18, 1.0)
    spotLight_.range = 13.0
    spotLight_.fov = 36.0
    spotLight_.brightness = 5.2
    spotLight_.castShadows = true
end

function CreateUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                top = 16,
                left = 16,
                width = UI_PANEL_WIDTH,
                padding = 16,
                gap = 10,
                borderRadius = 8,
                backgroundColor = { 16, 18, 22, 216 },
                children = {
                    UI.Label {
                        text = "灯光开关",
                        fontSize = 18,
                        fontWeight = "bold",
                        fontColor = { 255, 255, 255, 255 },
                    },
                    UI.Label {
                        text = "切换场景中的四类光源。",
                        fontSize = 12,
                        fontColor = { 180, 188, 198, 255 },
                    },
                    UI.Toggle {
                        label = "平行光",
                        value = directionalLight_ ~= nil and directionalLight_.enabled == true,
                        onChange = function(_, value)
                            if directionalLight_ then
                                directionalLight_.enabled = value
                            end
                        end,
                    },
                    UI.Toggle {
                        label = "PointLight",
                        value = pointLight_ ~= nil and pointLight_.enabled == true,
                        onChange = function(_, value)
                            if pointLight_ then
                                pointLight_.enabled = value
                            end
                        end,
                    },
                    UI.Toggle {
                        label = "SpotLight",
                        value = spotLight_ ~= nil and spotLight_.enabled == true,
                        onChange = function(_, value)
                            if spotLight_ then
                                spotLight_.enabled = value
                            end
                        end,
                    },
                    UI.Label {
                        text = "Ambient Source",
                        fontSize = 12,
                        fontColor = { 180, 188, 198, 255 },
                        marginTop = 6,
                    },
                    UI.Dropdown {
                        value = zone_ ~= nil and zone_.ambientSource or AMBIENT_COLOR,
                        options = AMBIENT_SOURCE_OPTIONS,
                        width = "100%",
                        maxVisibleItems = 3,
                        onChange = function(_, value)
                            if zone_ then
                                zone_.ambientSource = value
                            end
                        end,
                    },
                },
            },
        },
    })
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0.0, 4.8, -11.5)
    cameraNode_:LookAt(Vector3(0.0, 1.15, 1.4))
    yaw_ = cameraNode_.rotation:YawAngle()
    pitch_ = cameraNode_.rotation:PitchAngle()

    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 120.0
    camera.fov = 58.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    elapsedTime_ = elapsedTime_ + dt

    MoveCamera(dt)
end

function MoveCamera(dt)
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        yaw_ = yaw_ + input.mouseMoveX * MOUSE_SENSITIVITY
        pitch_ = Clamp(pitch_ + input.mouseMoveY * MOUSE_SENSITIVITY, -82.0, 82.0)
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0.0)
    end

    local speed = MOVE_SPEED
    if input:GetKeyDown(KEY_SHIFT) then
        speed = speed * 2.0
    end

    if input:GetKeyDown(KEY_W) then
        cameraNode_:Translate(Vector3(0.0, 0.0, 1.0) * speed * dt)
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode_:Translate(Vector3(0.0, 0.0, -1.0) * speed * dt)
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode_:Translate(Vector3(-1.0, 0.0, 0.0) * speed * dt)
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode_:Translate(Vector3(1.0, 0.0, 0.0) * speed * dt)
    end
    if input:GetKeyDown(KEY_Q) then
        cameraNode_:Translate(Vector3(0.0, -1.0, 0.0) * speed * dt, TS_WORLD)
    end
    if input:GetKeyDown(KEY_E) then
        cameraNode_:Translate(Vector3(0.0, 1.0, 0.0) * speed * dt, TS_WORLD)
    end
end
