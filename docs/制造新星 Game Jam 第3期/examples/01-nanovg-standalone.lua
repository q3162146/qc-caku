-- NanoVG Basic Example
-- This sample demonstrates:
--     - Creating a NanoVG context with automatic BGFX ViewId management
--     - Drawing basic shapes (rectangles, circles, rounded rectangles)
--     - Using gradients and colors
--     - Rendering text with custom fonts
--     - Using the native NanoVG C API from Lua

require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")

local nvgContext = nil
local fontId = -1

function Start()
    -- Execute the common startup for samples
    SampleStart()

    -- Create the NanoVG context
    -- Parameter: edgeAntiAlias (1=on, 0=off)
    nvgContext = nvgCreate(1)

    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    print("NanoVG context created successfully")

    -- Create font from TTF file
    fontId = nvgCreateFont(nvgContext, "misans", "Fonts/MiSans-Regular.ttf")

    if fontId == -1 then
        print("ERROR: Failed to create font from Fonts/MiSans-Regular.ttf")
    else
        print("Font loaded successfully, fontId = " .. fontId)
    end

    -- Create instructions text
    CreateInstructions()

    -- Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_FREE)

    -- Subscribe to render event
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
end

function Stop()
    UI.Shutdown()
    -- Clean up NanoVG context
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
        print("NanoVG context deleted")
    end
end

function CreateInstructions()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 多行内容拆成多个 Label + flexDirection="column" (recipes/ui.md §11 模式 A)
    -- 单 Label 多行 \n 行为不可靠, 见 scaffold-3d-scene 与 PhysicsCollision3D 的范式
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        paddingTop = 10,
        alignItems = "center",
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                children = {
                    UI.Label { text = "NanoVG Basic Example", fontSize = 15, fontColor = { 255, 255, 255, 255 } },
                    UI.Label { text = "Drawing vector graphics with native NanoVG API", fontSize = 15, fontColor = { 255, 255, 255, 255 } },
                },
            },
        }
    })
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then
        print("ERROR: nvgContext is nil")
        return
    end

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    -- Begin NanoVG frame (ViewId is automatically managed)
    nvgBeginFrame(nvgContext, width, height, 1.0)

    -- Draw demo graphics
    DrawDemo(nvgContext, width, height)

    -- End NanoVG frame
    nvgEndFrame(nvgContext)
end

function DrawDemo(ctx, width, height)
    local time = GetTime():GetElapsedTime()

    -- Draw background gradient
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    local bg = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(20, 30, 40, 255),
        nvgRGBA(10, 15, 20, 255))
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    -- Draw some shapes
    -- Circle
    nvgBeginPath(ctx)
    local cx = width * 0.25
    local cy = height * 0.3
    local radius = 80 + math.sin(time * 2) * 20
    nvgCircle(ctx, cx, cy, radius)
    nvgFillColor(ctx, nvgRGBA(255, 100, 50, 200))
    nvgFill(ctx)

    -- Rounded rectangle
    nvgBeginPath(ctx)
    local rx = width * 0.6
    local ry = height * 0.3
    local rw = 150
    local rh = 100
    nvgRoundedRect(ctx, rx, ry, rw, rh, 10)
    nvgFillColor(ctx, nvgRGBA(50, 150, 255, 200))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- Render text if font is loaded
    if fontId ~= -1 then
        -- Title text
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 48)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, width * 0.5, height * 0.15, "NanoVG 字体渲染测试", nil)

        -- Subtitle text
        nvgFontSize(ctx, 24)
        nvgFillColor(ctx, nvgRGBA(200, 200, 200, 255))
        nvgText(ctx, width * 0.5, height * 0.15 + 50, "使用 MiSans 字体", nil)

        -- Animated text
        nvgFontSize(ctx, 32)
        local alpha = math.floor(128 + 127 * math.sin(time * 3))
        nvgFillColor(ctx, nvgRGBA(100, 255, 100, alpha))
        nvgText(ctx, width * 0.5, height * 0.65, "动态文字效果", nil)

        -- Info text with different sizes
        nvgFontSize(ctx, 18)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 200, 100, 255))
        nvgText(ctx, 20, height - 100, "左侧圆形 - 动态半径", nil)
        nvgText(ctx, 20, height - 70, "右侧矩形 - 圆角边框", nil)
        nvgText(ctx, 20, height - 40, "中文字体渲染 - MiSans", nil)
    end
end

-- Create XML patch instructions for screen joystick layout specific to this sample app
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
