-- ModelPainter example.
-- This sample demonstrates runtime painting of color, metallic and roughness on a model with UV1.

require "LuaScripts/Utilities/Sample"

local Paint = require("urhox-libs.Paint")
local UI = require("urhox-libs/UI")

local CHARACTER_PREFAB_URI = "uuid://DhnawSdRjjI6RiE18lnCW4iv"

local painter = nil
local paintNode = nil
local prefabPaintNode = nil
local paintTargets = {}
local currentPaintTargetIndex = 1
local targetButton = nil
local cameraNode = nil
local cameraFocus = Vector3(0.0, 1.5, 0.0)
local yaw = 0.0
local pitch = 0.0
local painting = false
local currentColor = Color(1.0, 0.1, 0.05, 1.0)
local currentMetallic = 0.0
local currentRoughness = 0.5
local currentRadiusPixels = 28.0
local statusText = nil
local radiusLabel = nil
local metallicLabel = nil
local roughnessLabel = nil
local pickedColorSwatch = nil
local crosshairRoot = nil
local crosshairSize = 34

local PALETTE = {
    Color(1.0, 0.1, 0.05, 1.0),
    Color(1.0, 0.75, 0.05, 1.0),
    Color(0.05, 0.65, 1.0, 1.0),
    Color(0.1, 0.9, 0.35, 1.0),
    Color(0.85, 0.15, 1.0, 1.0),
    Color(1.0, 1.0, 1.0, 1.0),
}

local function ColorToRGBA(color, alpha)
    return {
        math.floor(Clamp(color.r, 0.0, 1.0) * 255.0 + 0.5),
        math.floor(Clamp(color.g, 0.0, 1.0) * 255.0 + 0.5),
        math.floor(Clamp(color.b, 0.0, 1.0) * 255.0 + 0.5),
        alpha or math.floor(Clamp(color.a or 1.0, 0.0, 1.0) * 255.0 + 0.5),
    }
end

local function SetStatus(text)
    if statusText then
        statusText:SetText(text)
    end
end

function Start()
    SampleStart()
    CreateScene()
    CreateUI()
    SetupViewport()
    SampleInitMouseMode(MM_FREE)
    SubscribeToEvents()
end

local function WriteVertex(buffer, position, normal, uv)
    buffer:WriteVector3(position)
    buffer:WriteVector3(normal)
    buffer:WriteVector2(uv)
    buffer:WriteVector2(uv)
end

function CreatePaintTestModel()
    local width = 3.0
    local height = 3.0
    local segments = 32
    local vertexCount = (segments + 1) * (segments + 1)
    local indexCount = segments * segments * 6

    local model = Model:new()
    local vb = VertexBuffer:new()
    local ib = IndexBuffer:new()
    local geom = Geometry:new()

    vb.shadowed = true
    local elements = {
        VertexElement(TYPE_VECTOR3, SEM_POSITION),
        VertexElement(TYPE_VECTOR3, SEM_NORMAL),
        VertexElement(TYPE_VECTOR2, SEM_TEXCOORD, 0),
        VertexElement(TYPE_VECTOR2, SEM_TEXCOORD, 1)
    }
    vb:SetSize(vertexCount, elements)

    local vertexData = VectorBuffer()
    for y = 0, segments do
        local v = y / segments
        for x = 0, segments do
            local u = x / segments
            local px = (u - 0.5) * width
            local py = (v - 0.5) * height
            WriteVertex(vertexData, Vector3(px, py, 0.0), Vector3(0.0, 0.0, -1.0), Vector2(u, v))
        end
    end
    vb:SetData(vertexData)

    ib.shadowed = true
    ib:SetSize(indexCount, false)
    local indexData = VectorBuffer()
    for y = 0, segments - 1 do
        for x = 0, segments - 1 do
            local i0 = y * (segments + 1) + x
            local i1 = i0 + 1
            local i2 = i0 + segments + 1
            local i3 = i2 + 1

            indexData:WriteUShort(i0)
            indexData:WriteUShort(i2)
            indexData:WriteUShort(i1)
            indexData:WriteUShort(i1)
            indexData:WriteUShort(i2)
            indexData:WriteUShort(i3)
        end
    end
    ib:SetData(indexData)

    geom:SetVertexBuffer(0, vb)
    geom:SetIndexBuffer(ib)
    geom:SetDrawRange(TRIANGLE_LIST, 0, indexCount)

    model.numGeometries = 1
    model:SetGeometry(0, 0, geom)
    model.boundingBox = BoundingBox(Vector3(-width * 0.5, -height * 0.5, -0.05), Vector3(width * 0.5, height * 0.5, 0.05))

    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(0.75, 0.75, 0.75, 1.0)))
    material:SetShaderParameter("Roughness", Variant(0.7))
    material:SetShaderParameter("Metallic", Variant(0.0))
    material.cullMode = CULL_NONE

    paintNode = scene_:CreateChild("PaintSurface")
    paintNode.position = Vector3(0.0, 1.5, 0.0)
    local staticModel = paintNode:CreateComponent("StaticModel")
    staticModel.model = model
    staticModel.material = material
    staticModel.castShadows = true

    local paintable = paintNode:CreateComponent("Paintable")
    paintable.paintResolution = 2048
    table.insert(paintTargets, { name = "Static Model", node = paintNode, paintable = paintable, focus = paintNode.position })
end

function CreatePaintCharacterPrefab()
    prefabPaintNode = scene_:Instantiate(CHARACTER_PREFAB_URI, Vector3(0.0, 0.0, 0.0), Quaternion(0.0, 180.0, 0.0), REPLICATED)
    if prefabPaintNode == nil then
        print("Failed to instantiate paint character prefab: " .. CHARACTER_PREFAB_URI)
        return
    end

    prefabPaintNode.name = "PaintCharacter"
    local paintable = prefabPaintNode:GetComponent("Paintable")
    if paintable == nil then
        paintable = prefabPaintNode:CreateComponent("Paintable")
    end
    paintable.paintResolution = 2048
    table.insert(paintTargets, { name = "Character", node = prefabPaintNode, paintable = paintable, focus = prefabPaintNode.position + Vector3(0.0, 1.2, 0.0) })
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    CreatePaintTestModel()
    CreatePaintCharacterPrefab()

    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.18, 0.18, 0.2)

    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.35, -0.65, 0.65)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.castShadows = true

    cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(0.0, 1.5, -5.0)
    local camera = cameraNode:CreateComponent("Camera")
    camera.farClip = 100.0
    cameraNode:LookAt(paintNode.position)
    yaw = cameraNode.rotation:YawAngle()
    pitch = cameraNode.rotation:PitchAngle()

    painter = Paint.ModelPainter.new({
        camera = camera,
        node = paintNode,
        maxDistance = 50.0,
        paintResolution = 2048,
        brush = {
            radiusPixels = currentRadiusPixels,
            strength = 1.0,
            color = currentColor,
            colorOpacity = 1.0,
            metallic = currentMetallic,
            roughness = currentRoughness,
            metallicOpacity = 1.0,
            roughnessOpacity = 1.0,
            blendMode = PAINT_BLEND_ADD,
        }
    })
    ApplyPaintTarget(1, false)
end

function CreateUI()
    UI.Init({
        theme = "default-dark",
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
    })

    local root = UI.Panel {
        id = "modelPainterRoot",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
    }

    local panel = UI.Panel {
        position = "absolute",
        left = 16,
        top = 16,
        width = 320,
        padding = 14,
        gap = 10,
        backgroundColor = { 18, 22, 30, 218 },
        borderColor = { 255, 255, 255, 28 },
        borderWidth = 1,
        borderRadius = 8,
        pointerEvents = "auto",
    }
    root:AddChild(panel)

    panel:AddChild(UI.Label {
        text = "Model Painter",
        fontSize = 18,
        fontWeight = "bold",
        fontColor = { 245, 247, 250, 255 },
    })

    panel:AddChild(UI.Label {
        text = "Palette",
        fontSize = 12,
        fontColor = { 185, 192, 204, 255 },
    })

    local paletteRow = UI.Row { gap = 8, flexWrap = "wrap" }
    panel:AddChild(paletteRow)
    for i, color in ipairs(PALETTE) do
        paletteRow:AddChild(UI.Button {
            text = "",
            width = 34,
            height = 30,
            minWidth = 34,
            borderRadius = 6,
            backgroundColor = ColorToRGBA(color),
            hoverBackgroundColor = ColorToRGBA(color, 230),
            pressedBackgroundColor = ColorToRGBA(color, 190),
            borderColor = { 255, 255, 255, 88 },
            borderWidth = 1,
            padding = 0,
            onClick = function()
                currentColor = PALETTE[i] or currentColor
                pickedColorSwatch:SetBackgroundColor(ColorToRGBA(currentColor))
                UpdateBrush()
            end,
        })
    end

    radiusLabel = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 210, 215, 224, 255 },
        marginTop = 4,
    }
    panel:AddChild(radiusLabel)

    panel:AddChild(UI.Slider {
        width = "100%",
        value = currentRadiusPixels,
        min = 4.0,
        max = 128.0,
        onChange = function(_, value)
            currentRadiusPixels = value
            UpdateBrush()
        end,
    })

    metallicLabel = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 210, 215, 224, 255 },
    }
    panel:AddChild(metallicLabel)

    panel:AddChild(UI.Slider {
        width = "100%",
        value = currentMetallic,
        min = 0.0,
        max = 1.0,
        onChange = function(_, value)
            currentMetallic = value
            UpdateBrush()
        end,
    })

    roughnessLabel = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 210, 215, 224, 255 },
        marginTop = 4,
    }
    panel:AddChild(roughnessLabel)

    panel:AddChild(UI.Slider {
        width = "100%",
        value = currentRoughness,
        min = 0.0,
        max = 1.0,
        onChange = function(_, value)
            currentRoughness = value
            UpdateBrush()
        end,
    })

    targetButton = UI.Button {
        text = "",
        width = "100%",
        height = 34,
        variant = "secondary",
        marginTop = 6,
        onClick = function()
            TogglePaintTarget()
        end,
    }
    panel:AddChild(targetButton)

    local commandRow = UI.Row { gap = 8, alignItems = "center", marginTop = 6 }
    panel:AddChild(commandRow)

    commandRow:AddChild(UI.Button {
        text = "Clear",
        width = 88,
        height = 34,
        variant = "secondary",
        onClick = function()
            ClearCurrentPaintTarget()
        end,
    })

    commandRow:AddChild(UI.Button {
        text = "Pick Screen",
        width = 128,
        height = 34,
        variant = "secondary",
        onClick = function()
            PickCurrentScreenColor()
        end,
    })

    pickedColorSwatch = UI.Panel {
        width = 36,
        height = 34,
        backgroundColor = ColorToRGBA(currentColor),
        borderColor = { 255, 255, 255, 96 },
        borderWidth = 1,
        borderRadius = 6,
    }
    commandRow:AddChild(pickedColorSwatch)

    statusText = UI.Label {
        text =
        "LMB: Paint model\n" ..
        "RMB + mouse: Orbit camera\n" ..
        "W/S: Dolly camera\n" ..
        "Space: Pick screen color",
        fontSize = 12,
        fontColor = { 170, 178, 190, 255 },
        marginTop = 4,
        lineHeight = 1.25,
    }
    panel:AddChild(statusText)

    crosshairRoot = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = crosshairSize,
        height = crosshairSize,
        pointerEvents = "none",
        visible = false,
    }
    root:AddChild(crosshairRoot)

    crosshairRoot:AddChild(UI.Panel {
        position = "absolute",
        left = math.floor(crosshairSize * 0.5) - 1,
        top = 0,
        width = 2,
        height = crosshairSize,
        backgroundColor = { 255, 255, 255, 230 },
        borderRadius = 1,
    })
    crosshairRoot:AddChild(UI.Panel {
        position = "absolute",
        left = 0,
        top = math.floor(crosshairSize * 0.5) - 1,
        width = crosshairSize,
        height = 2,
        backgroundColor = { 255, 255, 255, 230 },
        borderRadius = 1,
    })
    crosshairRoot:AddChild(UI.Panel {
        position = "absolute",
        left = math.floor(crosshairSize * 0.5) - 4,
        top = math.floor(crosshairSize * 0.5) - 4,
        width = 8,
        height = 8,
        backgroundColor = { 0, 0, 0, 0 },
        borderColor = { 0, 0, 0, 180 },
        borderWidth = 1,
        borderRadius = 4,
    })

    UI.SetRoot(root)

    ApplyPaintTarget(currentPaintTargetIndex, false)
    UpdateBrush()
end

function UpdateBrush()
    painter:SetBrush({
        radiusPixels = currentRadiusPixels,
        strength = 1.0,
        color = currentColor,
        colorOpacity = 1.0,
        metallic = currentMetallic,
        roughness = currentRoughness,
        metallicOpacity = 1.0,
        roughnessOpacity = 1.0,
        blendMode = PAINT_BLEND_ADD,
    })

    if radiusLabel then
        radiusLabel:SetText(string.format("Brush Radius: %d px", math.floor(currentRadiusPixels + 0.5)))
    end
    metallicLabel:SetText(string.format("Metallic: %.2f", currentMetallic))
    roughnessLabel:SetText(string.format("Roughness: %.2f", currentRoughness))
end

function SetupViewport()
    renderer.hdrRendering = true
    renderer:SetViewport(0, Viewport:new(scene_, cameraNode:GetComponent("Camera")))
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
end

function PickCurrentScreenColor()
    local pos = input.mousePosition
    local color = Paint.ScreenColorPicker.Pick(pos.x, pos.y)
    if color then
        currentColor = Color(color.r, color.g, color.b, 1.0)
        pickedColorSwatch:SetBackgroundColor(ColorToRGBA(currentColor))
        UpdateBrush()
        SetStatus(string.format("Picked color: %.2f %.2f %.2f", currentColor.r, currentColor.g, currentColor.b))
    else
        SetStatus("Screen pick failed")
    end
end

function GetCurrentPaintTarget()
    return paintTargets[currentPaintTargetIndex]
end

function ApplyPaintTarget(index, showStatus)
    if #paintTargets == 0 or not painter then
        return
    end

    if painting then
        painter:EndStroke()
        painting = false
    end

    currentPaintTargetIndex = ((index - 1) % #paintTargets) + 1
    local currentTarget = paintTargets[currentPaintTargetIndex]
    for i, target in ipairs(paintTargets) do
        if target.node then
            target.node.enabled = i == currentPaintTargetIndex
        end
    end

    painter:SetTarget(currentTarget.paintable)
    cameraFocus = currentTarget.focus or Vector3(0.0, 1.5, 0.0)
    if targetButton then
        targetButton:SetText("Target: " .. currentTarget.name)
    end
    if showStatus then
        SetStatus("Brush target: " .. currentTarget.name)
    end
end

function TogglePaintTarget()
    ApplyPaintTarget(currentPaintTargetIndex + 1, true)
end

function ClearCurrentPaintTarget()
    local target = GetCurrentPaintTarget()
    if target and target.paintable then
        target.paintable:ClearPaint()
    end
end

function UpdatePickHud()
    local show = input:GetKeyDown(KEY_SPACE)
    if crosshairRoot then
        crosshairRoot:SetVisible(show)
        if show then
            local pos = input.mousePosition
            crosshairRoot:SetStyle({
                left = pos.x - crosshairSize * 0.5,
                top = pos.y - crosshairSize * 0.5,
            })
        end
    end

    if input:GetKeyPress(KEY_SPACE) then
        PickCurrentScreenColor()
    end
end

function OrbitCamera(timeStep)
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local mouseMove = input.mouseMove
        yaw = yaw + mouseMove.x * 0.1
        pitch = Clamp(pitch + mouseMove.y * 0.1, -80.0, 80.0)
    end

    local distanceDelta = 0.0
    if input:GetKeyDown(KEY_W) then
        distanceDelta = distanceDelta - 3.0 * timeStep
    end
    if input:GetKeyDown(KEY_S) then
        distanceDelta = distanceDelta + 3.0 * timeStep
    end

    local target = cameraFocus
    local currentOffset = cameraNode.position - target
    local distance = Clamp(currentOffset:Length() + distanceDelta, 2.0, 8.0)
    local rotation = Quaternion(pitch, yaw, 0.0)
    cameraNode.position = target + rotation * Vector3(0.0, 0.0, -distance)
    cameraNode:LookAt(target)
end

function UpdatePainting()
    if UI.IsPointerOverUI() or input:GetKeyDown(KEY_SPACE) then
        if painting then
            painter:EndStroke()
            painting = false
        end
        return
    end

    local pos = input.mousePosition
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local command = painter:BeginStroke(pos.x, pos.y)
        painting = command ~= nil
        if not painting then
            painter:EndStroke()
        end
    elseif input:GetMouseButtonDown(MOUSEB_LEFT) and painting then
        painter:UpdateStroke(pos.x, pos.y)
    elseif input:GetMouseButtonRelease(MOUSEB_LEFT) and painting then
        painter:EndStroke()
        painting = false
    end
end

function UpdateBrushPreview()
    if not painter then
        return
    end

    -- 悬在 UI 上或取色时隐藏笔刷 HUD；否则交给 Paint 库在命中表面上渲染 3D 圆环。
    if UI.IsPointerOverUI() or input:GetKeyDown(KEY_SPACE) then
        painter:HideBrushCursor()
        return
    end

    local pos = input.mousePosition
    painter:UpdateBrushCursor(pos.x, pos.y)
end

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    UpdatePickHud()
    OrbitCamera(timeStep)
    UpdatePainting()
    UpdateBrushPreview()
end
