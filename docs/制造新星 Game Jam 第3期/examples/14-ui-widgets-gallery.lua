-- UI Widgets Gallery with Yoga + NanoVG
-- A comprehensive showcase of all 41 UI widgets in the UrhoX UI library
-- Features: Flexbox layout (Yoga), vector rendering (NanoVG), auto event subscription, touch/mouse support

require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")

function Start()
    SampleStart()

    -- Initialize UI system (autoEvents enabled by default)
    UI.Init({
        theme = "dark",
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
        -- 推荐! DPR 缩放 + 小屏密度自适应（见 ui.md §10）
        -- 1 基准像素 ≈ 1 CSS 像素，尺寸遵循 CSS/Web 常识
        scale = UI.Scale.DEFAULT,
    })

    -- Load the widgets gallery
    require("urhox-libs/UI/Examples/WidgetsGallery")

    -- Set mouse mode
    SampleInitMouseMode(MM_FREE)

    print("===========================================")
    print("  UrhoX UI Widget Gallery")
    print("  Total Widgets: 41")
    print("===========================================")
end

function Stop()
    UI.Shutdown()
end
