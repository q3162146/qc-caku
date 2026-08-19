-- ============================================================================
-- CSS Enhancement Test
-- Demonstrates Phase 0~3 features: Transition, Opacity, Transform,
-- Visibility, Aspect-Ratio, Gradient, Shadow, Keyframe Animation,
-- z-index, SimpleGrid, Sticky, Clip-Path, Text Props, BlendMode,
-- Scroll Snap, Position Fixed, Multiline Typewriter (regression),
-- CJK nvgTextBox Line-Break Width (regression)
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- Shared State
-- ============================================================================

local state = {
    animWidgets = {},     -- Widgets with demo animations
    toggleState = {},     -- Toggle states for interactive demos
}

-- ============================================================================
-- Create Main Layout
-- ============================================================================

local root = UI.Panel {
    id = "root",
    width = "100%",
    height = "100%",
    padding = 20,
    flexDirection = "column",
    backgroundColor = UI.Theme.Color("background"),
}

-- Title
root:AddChild(UI.Label {
    text = "CSS Enhancement Test (Phase 0~3)",
    fontSize = UI.Theme.FontSizeOf("headline"),
    fontWeight = "bold",
    color = UI.Theme.Color("text"),
    marginBottom = 20,
})

-- ScrollView
local scrollView = UI.ScrollView {
    width = "100%",
    flexGrow = 1,
    flexBasis = 0,
    scrollY = true,
    showScrollbar = true,
    scrollbarInteractive = true,
}
root:AddChild(scrollView)

-- Content container
local content = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 24,
    paddingBottom = 40,
}
scrollView:AddChild(content)

-- ============================================================================
-- Helper: Create Section
-- ============================================================================

local function createSection(title, subtitle)
    local section = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 12,
        padding = 16,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
    }

    section:AddChild(UI.Label {
        text = title,
        fontSize = UI.Theme.FontSizeOf("bodyLarge"),
        fontWeight = "bold",
        color = UI.Theme.Color("text"),
    })

    if subtitle then
        section:AddChild(UI.Label {
            text = subtitle,
            fontSize = UI.Theme.FontSizeOf("bodySmall"),
            color = UI.Theme.Color("textSecondary"),
        })
    end

    content:AddChild(section)
    return section
end

local function createLabel(text)
    return UI.Label {
        text = text,
        fontSize = UI.Theme.FontSizeOf("bodySmall"),
        color = UI.Theme.Color("textSecondary"),
        marginTop = 4,
    }
end

-- ============================================================================
-- Phase 0: Transition System
-- ============================================================================
do
    local section = createSection(
        "Phase 0-1: Transition System",
        "Hover/click buttons to see smooth property transitions"
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap", alignItems = "center" }
    section:AddChild(row)

    -- Button with color transition on hover (variant color, 0.3s)
    row:AddChild(UI.Button {
        text = "Hover 0.3s",
        variant = "primary",
        transition = "all 0.3s easeOut",
    })

    -- Button with custom colors + slower transition (0.5s)
    row:AddChild(UI.Button {
        text = "Hover 0.5s",
        backgroundColor = { 34, 197, 94, 255 },
        hoverBackgroundColor = { 239, 68, 68, 255 },
        pressedBackgroundColor = { 168, 85, 247, 255 },
        transition = {
            properties = { "backgroundColor" },
            duration = 0.5,
            easing = "easeInOut",
        },
    })

    -- Button with easeOutBack (bouncy feel)
    row:AddChild(UI.Button {
        text = "Bouncy",
        backgroundColor = { 168, 85, 247, 255 },
        hoverBackgroundColor = { 245, 158, 11, 255 },
        transition = "all 0.4s easeOutBack",
    })

    -- Button with comma-separated per-property transitions (CSS format)
    local commaBtn = UI.Button {
        text = "Comma Sep",
        backgroundColor = { 59, 130, 246, 255 },
        hoverBackgroundColor = { 239, 68, 68, 255 },
        transition = "backgroundColor 0.8s easeInOut, scale 0.3s easeOutBack, opacity 0.5s linear",
    }
    commaBtn:OnEvent("pointerenter", function()
        commaBtn:SetStyle({ scale = 1.1, opacity = 0.7 })
    end)
    commaBtn:OnEvent("pointerleave", function()
        commaBtn:SetStyle({ scale = 1.0, opacity = 1.0 })
    end)
    row:AddChild(commaBtn)

    -- Button with no transition (control group)
    row:AddChild(UI.Button {
        text = "No Transition",
        variant = "secondary",
    })

    section:AddChild(createLabel("Hover each button: 0.3s easeOut / 0.5s easeInOut / 0.4s easeOutBack / comma-sep (bg 0.8s, scale 0.3s, opacity 0.5s) / instant"))
end

-- ============================================================================
-- Phase 0: Opacity
-- ============================================================================
do
    local section = createSection(
        "Phase 0-2: Opacity",
        "Parent opacity multiplies with children (0.5 x 0.5 = 0.25)"
    )

    local row = UI.Row { gap = 16, alignItems = "flex-end", flexWrap = "wrap" }
    section:AddChild(row)

    -- Different opacity levels
    local opacities = { 1.0, 0.8, 0.6, 0.4, 0.2 }
    for _, alpha in ipairs(opacities) do
        local box = UI.Panel {
            width = 80,
            height = 60,
            backgroundColor = { 59, 130, 246, 255 },
            borderRadius = 6,
            opacity = alpha,
            justifyContent = "center",
            alignItems = "center",
        }
        box:AddChild(UI.Label {
            text = tostring(alpha),
            fontSize = 14,
            color = { 255, 255, 255, 255 },
        })
        row:AddChild(box)
    end

    -- Nested opacity demo
    section:AddChild(createLabel("Nested opacity inheritance:"))
    local parentBox = UI.Panel {
        width = 200,
        height = 80,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 8,
        opacity = 0.5,
        padding = 10,
        justifyContent = "center",
        alignItems = "center",
    }
    parentBox:AddChild(UI.Panel {
        width = 80,
        height = 40,
        backgroundColor = { 255, 255, 255, 255 },
        borderRadius = 4,
        opacity = 0.5,
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label {
        text = "0.25",
        fontSize = 12,
        color = { 0, 0, 0, 255 },
    }))
    section:AddChild(parentBox)
end

-- ============================================================================
-- Phase 0: Transform
-- ============================================================================
do
    local section = createSection(
        "Phase 0-3: Transform (scale / rotate / translate)",
        "Visual transforms applied via NanoVG, layout unchanged"
    )

    local row = UI.Row { gap = 40, alignItems = "center", flexWrap = "wrap", padding = 20 }
    section:AddChild(row)

    -- Scale
    local scaleBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = 8,
        scale = 1.3,
        justifyContent = "center",
        alignItems = "center",
    }
    scaleBox:AddChild(UI.Label { text = "1.3x", fontSize = 11, color = { 255, 255, 255, 255 } })
    row:AddChild(scaleBox)

    -- Rotate
    local rotateBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 168, 85, 247, 255 },
        borderRadius = 8,
        rotate = 15,
        justifyContent = "center",
        alignItems = "center",
    }
    rotateBox:AddChild(UI.Label { text = "15deg", fontSize = 11, color = { 255, 255, 255, 255 } })
    row:AddChild(rotateBox)

    -- Translate
    local translateBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 245, 158, 11, 255 },
        borderRadius = 8,
        translateX = 10,
        translateY = -10,
        justifyContent = "center",
        alignItems = "center",
    }
    translateBox:AddChild(UI.Label { text = "tx+10", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(translateBox)

    -- Combined
    local combinedBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 236, 72, 153, 255 },
        borderRadius = 8,
        scale = 1.1,
        rotate = -10,
        translateY = 5,
        transformOrigin = "center",
        justifyContent = "center",
        alignItems = "center",
    }
    combinedBox:AddChild(UI.Label { text = "combo", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(combinedBox)

    section:AddChild(createLabel("scale = 1.3 | rotate = 15 | translateX/Y | transformOrigin = \"center\""))
end

-- ============================================================================
-- Phase 0: Visibility
-- ============================================================================
do
    local section = createSection(
        "Phase 0-4: Visibility",
        "visibility=\"hidden\" keeps layout space, visible=false collapses"
    )

    local row = UI.Row { gap = 8, alignItems = "center" }
    section:AddChild(row)

    row:AddChild(UI.Panel {
        width = 60, height = 40,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = 4,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "A", fontSize = 14, color = { 255, 255, 255, 255 } }))

    row:AddChild(UI.Panel {
        width = 60, height = 40,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 4,
        visibility = "hidden",  -- Hidden but takes space
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "B", fontSize = 14, color = { 255, 255, 255, 255 } }))

    row:AddChild(UI.Panel {
        width = 60, height = 40,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = 4,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "C", fontSize = 14, color = { 255, 255, 255, 255 } }))

    section:AddChild(createLabel("A [B hidden] C — B is visibility=\"hidden\" (gap preserved between A and C)"))
end

-- ============================================================================
-- Phase 1: Aspect Ratio
-- ============================================================================
do
    local section = createSection(
        "Phase 1-1: Aspect Ratio",
        "YGNodeStyleSetAspectRatio — height auto-calculated from width"
    )

    local row = UI.Row { gap = 16, alignItems = "flex-end", flexWrap = "wrap" }
    section:AddChild(row)

    local ratios = { { 1, "1:1" }, { 16/9, "16:9" }, { 4/3, "4:3" }, { 2/1, "2:1" } }
    for _, info in ipairs(ratios) do
        local ratio, label = info[1], info[2]
        local box = UI.Panel {
            width = 100,
            aspectRatio = ratio,
            backgroundColor = { 59, 130, 246, 255 },
            borderRadius = 6,
            justifyContent = "center",
            alignItems = "center",
        }
        box:AddChild(UI.Label {
            text = label,
            fontSize = 13,
            color = { 255, 255, 255, 255 },
        })
        row:AddChild(box)
    end

    section:AddChild(createLabel("width = 100, aspectRatio = 16/9 → height auto 56.25"))
end

-- ============================================================================
-- Phase 1: Per-Corner Border Radius
-- ============================================================================
do
    local section = createSection(
        "Phase 1-2: Per-Corner Border Radius",
        "borderRadius = {TL, TR, BR, BL} or borderRadiusTopLeft etc."
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row)

    -- Table format
    row:AddChild(UI.Panel {
        width = 80, height = 60,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = { 20, 0, 20, 0 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{20,0,20,0}", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Individual props
    row:AddChild(UI.Panel {
        width = 80, height = 60,
        backgroundColor = { 168, 85, 247, 255 },
        borderRadiusTopLeft = 20,
        borderRadiusBottomRight = 20,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "TL+BR", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Tab-like top only
    row:AddChild(UI.Panel {
        width = 80, height = 60,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = { 12, 12, 0, 0 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Tab top", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Pill shape
    row:AddChild(UI.Panel {
        width = 120, height = 40,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 20,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Pill", fontSize = 12, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 1: Gradient Background
-- ============================================================================
do
    local section = createSection(
        "Phase 1-3: Gradient Background",
        "backgroundGradient with linear/radial, direction presets and angles"
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row)

    -- Linear gradient to-bottom
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 59, 130, 246, 255 },
            to = { 147, 51, 234, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "to-bottom", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Linear gradient to-right
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = { 34, 197, 94, 255 },
            to = { 59, 130, 246, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "to-right", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Diagonal gradient (45 degrees)
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "linear",
            direction = 45,
            from = { 245, 158, 11, 255 },
            to = { 239, 68, 68, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "45deg", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Radial gradient
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "radial",
            from = { 255, 255, 255, 255 },
            to = { 59, 130, 246, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "radial", fontSize = 10, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 1: Per-Side Borders
-- ============================================================================
do
    local section = createSection(
        "Phase 1-4: Per-Side Borders",
        "borderTopWidth/Color, borderBottomWidth/Color etc."
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row)

    -- Bottom border only (underline style)
    row:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderBottomWidth = 3,
        borderBottomColor = { 59, 130, 246, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "bottom", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Left border (accent line)
    row:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderLeftWidth = 4,
        borderLeftColor = { 34, 197, 94, 255 },
        paddingLeft = 8,
        justifyContent = "center",
    }:AddChild(UI.Label { text = "left", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Top + Bottom
    row:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderTopWidth = 2,
        borderTopColor = { 239, 68, 68, 255 },
        borderBottomWidth = 2,
        borderBottomColor = { 239, 68, 68, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "top+btm", fontSize = 12, color = UI.Theme.Color("text") }))

    -- borderWidth table shorthand examples
    section:AddChild(createLabel("borderWidth table shorthand:"))
    local row2 = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row2)

    -- CSS shorthand: {vert, horiz}
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { 1, 3 },
        borderColor = { 168, 85, 247, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{1, 3}", fontSize = 12, color = UI.Theme.Color("text") }))

    -- CSS shorthand: {top, horiz, bottom}
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { 4, 1, 2 },
        borderColor = { 245, 158, 11, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{4, 1, 2}", fontSize = 12, color = UI.Theme.Color("text") }))

    -- CSS shorthand: {top, right, bottom, left}
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { 1, 2, 3, 4 },
        borderColor = { 34, 197, 94, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{1,2,3,4}", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Named keys: { top=N, left=N }
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { top = 3, left = 3 },
        borderColor = { 59, 130, 246, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "top+left", fontSize = 12, color = UI.Theme.Color("text") }))
end

-- ============================================================================
-- Phase 1: Enhanced Box Shadow
-- ============================================================================
do
    local section = createSection(
        "Phase 1-5: Enhanced Box Shadow",
        "boxShadow = { {x=0, y=4, blur=12, spread=0, color={0,0,0,60}, inset=false} } — named fields, multiple shadows supported"
    )

    local row = UI.Row { gap = 24, flexWrap = "wrap", padding = 16 }
    section:AddChild(row)

    -- Simple drop shadow
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 60 } },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Drop", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Elevated shadow (multiple layers)
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 2, blur = 4, spread = 0, color = { 0, 0, 0, 30 } },
            { x = 0, y = 8, blur = 24, spread = -4, color = { 0, 0, 0, 40 } },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Elevated", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Inset shadow
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 2, blur = 8, spread = 0, color = { 0, 0, 0, 50 }, inset = true },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Inset", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Glow effect
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 0, blur = 20, spread = 4, color = { 59, 130, 246, 100 } },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Glow", fontSize = 12, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 1: Backdrop Blur
-- ============================================================================
do
    local section = createSection(
        "Phase 1-6: Backdrop Blur (Visual Approximation)",
        "backdropBlur = N — layered semi-transparent overlay"
    )

    -- Background with content behind the blur panels
    local bgContainer = UI.Panel {
        width = "100%",
        height = 120,
        flexDirection = "row",
        gap = 16,
        padding = 10,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = { 59, 130, 246, 255 },
            to = { 147, 51, 234, 255 },
        },
        borderRadius = 8,
        alignItems = "center",
    }
    section:AddChild(bgContainer)

    -- Blur panel overlaid
    bgContainer:AddChild(UI.Panel {
        width = 140,
        height = 80,
        backdropBlur = 10,
        backgroundColor = { 255, 255, 255, 80 },
        borderRadius = 12,
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "blur=10", fontSize = 13, color = { 255, 255, 255, 255 } }))

    bgContainer:AddChild(UI.Panel {
        width = 140,
        height = 80,
        backdropBlur = 30,
        backgroundColor = { 255, 255, 255, 80 },
        borderRadius = 12,
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "blur=30", fontSize = 13, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 2: z-index
-- ============================================================================
do
    local section = createSection(
        "Phase 2-1: z-index",
        "Higher zIndex renders on top among siblings"
    )

    -- Container with overlapping children
    local container = UI.Panel {
        width = 400,
        height = 100,
        flexDirection = "row",
    }
    section:AddChild(container)

    -- Three overlapping panels (using negative margins to overlap)
    local colors = {
        { 239, 68, 68, 220 },   -- red
        { 34, 197, 94, 220 },   -- green
        { 59, 130, 246, 220 },  -- blue
    }
    local names = { "R", "G", "B" }
    local zIndices = { 1, 3, 2 }  -- Green (3) should be on top
    local labels = { "R z=1", "G z=3", "B z=2" }

    for i = 1, 3 do
        local label = UI.Label { text = labels[i], fontSize = 12, color = { 255, 255, 255, 255 } }
        local panel = UI.Panel {
            width = 100,
            height = 80,
            backgroundColor = colors[i],
            borderRadius = 8,
            zIndex = zIndices[i],
            marginLeft = i > 1 and -20 or 0,
            justifyContent = "center",
            alignItems = "center",
            cursor = "pointer",
        }
        panel:AddChild(label)

        -- Capture loop variables
        local defaultText = labels[i]
        local name = names[i]
        panel.props.onPointerEnter = function()
            label:SetStyle({ text = name .. " hover" })
        end
        panel.props.onPointerLeave = function()
            label:SetStyle({ text = defaultText })
        end
        panel.props.onPointerDown = function()
            label:SetStyle({ text = name .. " click!" })
        end
        panel.props.onPointerUp = function()
            label:SetStyle({ text = name .. " hover" })
        end

        container:AddChild(panel)
    end

    section:AddChild(createLabel("Red(z=1) Green(z=3) Blue(z=2) — Green renders on top, hover/click to verify hit test"))
end

-- ============================================================================
-- Phase 2: SimpleGrid
-- ============================================================================
do
    local section = createSection(
        "Phase 2-2: SimpleGrid",
        "Equal-width column grid via flex wrap"
    )

    -- Fixed 4 columns
    section:AddChild(createLabel("columns = 4, gap = 8:"))
    local grid = UI.SimpleGrid {
        columns = 4,
        gap = 8,
        width = "100%",
    }
    section:AddChild(grid)

    for i = 1, 8 do
        local hue = (i - 1) * 40
        -- Approximate HSL-like colors
        local r = math.floor(128 + 80 * math.cos(math.rad(hue)))
        local g = math.floor(128 + 80 * math.cos(math.rad(hue + 120)))
        local b = math.floor(128 + 80 * math.cos(math.rad(hue + 240)))
        grid:AddChild(UI.Panel {
            height = 50,
            backgroundColor = { r, g, b, 255 },
            borderRadius = 6,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = tostring(i), fontSize = 14, color = { 255, 255, 255, 255 } }))
    end

    -- Responsive grid
    section:AddChild(createLabel("minColumnWidth = 120 (responsive):"))
    local gridResponsive = UI.SimpleGrid {
        minColumnWidth = 120,
        gap = 8,
        width = "100%",
    }
    section:AddChild(gridResponsive)

    for i = 1, 6 do
        gridResponsive:AddChild(UI.Panel {
            height = 40,
            backgroundColor = { 59, 130, 246, 200 },
            borderRadius = 6,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = "Item " .. i, fontSize = 12, color = { 255, 255, 255, 255 } }))
    end
end

-- ============================================================================
-- Phase 2: Cursor Style
-- ============================================================================
do
    local section = createSection(
        "Phase 2-3: Cursor Style",
        "cursor = \"pointer\" | \"text\" | \"move\" | \"not-allowed\" — hover to see"
    )

    local row = UI.Row { gap = 12, flexWrap = "wrap" }
    section:AddChild(row)

    local cursors = { "default", "pointer", "text", "move", "not-allowed", "crosshair" }
    for _, cursorName in ipairs(cursors) do
        row:AddChild(UI.Panel {
            width = 90,
            height = 50,
            backgroundColor = UI.Theme.Color("surfaceAlt"),
            borderRadius = 6,
            borderWidth = 1,
            borderColor = UI.Theme.Color("border"),
            cursor = cursorName,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = cursorName, fontSize = 11, color = UI.Theme.Color("text") }))
    end
end

-- ============================================================================
-- Phase 2: Sticky Position
-- ============================================================================
do
    local section = createSection(
        "Phase 2-4: Sticky Position (in ScrollView)",
        "position=\"sticky\" pins header to scroll viewport top"
    )

    -- Inner ScrollView to demo sticky
    local innerScroll = UI.ScrollView {
        width = "100%",
        height = 200,
        scrollY = true,
        showScrollbar = true,
        backgroundColor = UI.Theme.Color("surfaceAlt"),
        borderRadius = 8,
    }
    section:AddChild(innerScroll)

    local innerContent = UI.Panel {
        width = "100%",
        flexDirection = "column",
    }
    innerScroll:AddChild(innerContent)

    -- Sticky header
    innerContent:AddChild(UI.Panel {
        width = "100%",
        height = 40,
        position = "sticky",
        stickyOffset = 0,
        backgroundColor = { 59, 130, 246, 240 },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 10,
    }:AddChild(UI.Label {
        text = "Sticky Header — scroll down!",
        fontSize = 13,
        fontWeight = "bold",
        color = { 255, 255, 255, 255 },
    }))

    -- Many items to scroll through
    for i = 1, 15 do
        innerContent:AddChild(UI.Panel {
            width = "100%",
            height = 44,
            paddingHorizontal = 16,
            borderBottomWidth = 1,
            borderBottomColor = UI.Theme.Color("border"),
            justifyContent = "center",
        }:AddChild(UI.Label {
            text = "List item " .. i,
            fontSize = 13,
            color = UI.Theme.Color("text"),
        }))
    end
end

-- ============================================================================
-- Phase 2: Keyframe Animation
-- ============================================================================
do
    local section = createSection(
        "Phase 2-5: Keyframe Animation",
        "widget:Animate({ keyframes, duration, loop, direction })"
    )

    local row = UI.Row { gap = 24, alignItems = "center", flexWrap = "wrap", padding = 16 }
    section:AddChild(row)

    -- Pulse animation (loop)
    local pulseBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 30,
        justifyContent = "center",
        alignItems = "center",
    }
    pulseBox:AddChild(UI.Label { text = "Pulse", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(pulseBox)
    state.animWidgets.pulse = pulseBox

    -- Fade in/out animation (alternate)
    local fadeBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    fadeBox:AddChild(UI.Label { text = "Fade", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(fadeBox)
    state.animWidgets.fade = fadeBox

    -- Slide animation (alternate)
    local slideBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    slideBox:AddChild(UI.Label { text = "Slide", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(slideBox)
    state.animWidgets.slide = slideBox

    -- Spin animation
    local spinBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 168, 85, 247, 255 },
        borderRadius = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    spinBox:AddChild(UI.Label { text = "Spin", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(spinBox)
    state.animWidgets.spin = spinBox

    -- Button to start/stop animations
    local btnRow = UI.Row { gap = 8 }
    section:AddChild(btnRow)

    btnRow:AddChild(UI.Button {
        text = "Start Animations",
        variant = "primary",
        onClick = function()
            -- Pulse: scale 1.0 → 1.2 → 1.0
            state.animWidgets.pulse:Animate({
                keyframes = {
                    [0]   = { scale = 1.0 },
                    [0.5] = { scale = 1.3 },
                    [1]   = { scale = 1.0 },
                },
                duration = 0.8,
                easing = "easeInOut",
                loop = true,
            })

            -- Fade: opacity 1.0 → 0.2 → 1.0
            state.animWidgets.fade:Animate({
                keyframes = {
                    [0] = { opacity = 1.0 },
                    [1] = { opacity = 0.2 },
                },
                duration = 1.0,
                easing = "easeInOut",
                loop = true,
                direction = "alternate",
            })

            -- Slide: translateX 0 → 30 → 0
            state.animWidgets.slide:Animate({
                keyframes = {
                    [0] = { translateX = 0 },
                    [1] = { translateX = 40 },
                },
                duration = 1.2,
                easing = "easeInOutCubic",
                loop = true,
                direction = "alternate",
            })

            -- Spin: rotate 0 → 360
            state.animWidgets.spin:Animate({
                keyframes = {
                    [0] = { rotate = 0 },
                    [1] = { rotate = 360 },
                },
                duration = 2.0,
                easing = "linear",
                loop = true,
            })
        end,
    })

    btnRow:AddChild(UI.Button {
        text = "Stop All",
        variant = "secondary",
        onClick = function()
            for _, w in pairs(state.animWidgets) do
                w:StopAnimation()
            end
        end,
    })
end

-- ============================================================================
-- Phase 2: Clip-Path
-- ============================================================================
do
    local section = createSection(
        "Phase 2-6: Clip-Path (Basic Shapes)",
        "clipPath = \"circle\" | \"ellipse\" — clips widget content to shape"
    )

    local row = UI.Row { gap = 24, alignItems = "center", flexWrap = "wrap" }
    section:AddChild(row)

    -- Circle clip
    row:AddChild(UI.Panel {
        width = 80,
        height = 80,
        clipPath = "circle",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom-right",
            from = { 59, 130, 246, 255 },
            to = { 147, 51, 234, 255 },
        },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "Circle", fontSize = 11, color = { 255, 255, 255, 255 } }))

    -- Ellipse clip
    row:AddChild(UI.Panel {
        width = 120,
        height = 70,
        clipPath = "ellipse",
        backgroundGradient = {
            type = "radial",
            from = { 245, 158, 11, 255 },
            to = { 239, 68, 68, 255 },
        },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "Ellipse", fontSize = 11, color = { 255, 255, 255, 255 } }))

    -- Circle with custom radius
    row:AddChild(UI.Panel {
        width = 100,
        height = 100,
        clipPath = { type = "circle", radius = 40 },
        backgroundColor = { 34, 197, 94, 255 },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "r=40", fontSize = 11, color = { 255, 255, 255, 255 } }))

    -- Ellipse with image (if available)
    row:AddChild(UI.Panel {
        width = 80,
        height = 80,
        clipPath = "circle",
        backgroundColor = { 236, 72, 153, 255 },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "Avatar", fontSize = 11, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Combined Demo: Animated Card
-- ============================================================================
do
    local section = createSection(
        "Combined Demo: Interactive Card",
        "Transition + Gradient + Shadow + Transform + Opacity"
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap", padding = 8 }
    section:AddChild(row)

    -- Interactive card that responds to hover
    for i = 1, 3 do
        local colors = {
            { { 59, 130, 246, 255 }, { 147, 51, 234, 255 } },
            { { 34, 197, 94, 255 }, { 16, 185, 129, 255 } },
            { { 239, 68, 68, 255 }, { 245, 158, 11, 255 } },
        }

        local card = UI.Panel {
            width = 160,
            height = 100,
            borderRadius = 12,
            backgroundGradient = {
                type = "linear",
                direction = "to-bottom-right",
                from = colors[i][1],
                to = colors[i][2],
            },
            boxShadow = {
                { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 40 } },
            },
            scale = 1.0,
            translateY = 0,
            transition = "all 0.3s easeOut",
            cursor = "pointer",
            justifyContent = "center",
            alignItems = "center",
            flexDirection = "column",
            gap = 4,
        }
        card:AddChild(UI.Label {
            text = "Card " .. i,
            fontSize = 16,
            fontWeight = "bold",
            color = { 255, 255, 255, 255 },
        })
        card:AddChild(UI.Label {
            text = "Click to animate",
            fontSize = 11,
            color = { 255, 255, 255, 180 },
        })

        -- Toggle animation on click
        state.toggleState["card" .. i] = false
        card.props.onPointerDown = function()
            state.toggleState["card" .. i] = not state.toggleState["card" .. i]
            if state.toggleState["card" .. i] then
                card:SetStyle({ scale = 1.05, translateY = -4 })
            else
                card:SetStyle({ scale = 1.0, translateY = 0 })
            end
        end

        row:AddChild(card)
    end
end

-- ============================================================================
-- Phase 3: Text Properties
-- ============================================================================
do
    local section = createSection(
        "Phase 3-1~6: Text Properties",
        "lineHeight, letterSpacing, textDecoration, textTransform, whiteSpace, wordBreak"
    )

    -- lineHeight
    section:AddChild(createLabel("lineHeight (1.0 vs 2.0):"))
    local lhRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(lhRow)

    lhRow:AddChild(UI.Label {
        text = "lineHeight=1.0",
        fontSize = 14,
        lineHeight = 1.0,
        backgroundColor = { 59, 130, 246, 40 },
        padding = 4,
        borderRadius = 4,
    })
    lhRow:AddChild(UI.Label {
        text = "lineHeight=2.0",
        fontSize = 14,
        lineHeight = 2.0,
        backgroundColor = { 59, 130, 246, 40 },
        padding = 4,
        borderRadius = 4,
    })

    -- letterSpacing
    section:AddChild(createLabel("letterSpacing (0, 2, 5):"))
    local lsRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(lsRow)

    for _, spacing in ipairs({ 0, 2, 5 }) do
        lsRow:AddChild(UI.Label {
            text = "Space=" .. spacing,
            fontSize = 14,
            letterSpacing = spacing,
            backgroundColor = { 34, 197, 94, 40 },
            padding = 4,
            borderRadius = 4,
        })
    end

    -- textDecoration
    section:AddChild(createLabel("textDecoration:"))
    local tdRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(tdRow)

    tdRow:AddChild(UI.Label {
        text = "underline",
        fontSize = 14,
        textDecoration = "underline",
        fontColor = { 59, 130, 246, 255 },
    })
    tdRow:AddChild(UI.Label {
        text = "line-through",
        fontSize = 14,
        textDecoration = "line-through",
        fontColor = { 239, 68, 68, 255 },
    })
    tdRow:AddChild(UI.Label {
        text = "none (default)",
        fontSize = 14,
        textDecoration = "none",
    })

    -- textTransform
    section:AddChild(createLabel("textTransform:"))
    local ttRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(ttRow)

    ttRow:AddChild(UI.Label {
        text = "uppercase text",
        fontSize = 14,
        textTransform = "uppercase",
        fontColor = { 168, 85, 247, 255 },
    })
    ttRow:AddChild(UI.Label {
        text = "LOWERCASE TEXT",
        fontSize = 14,
        textTransform = "lowercase",
        fontColor = { 245, 158, 11, 255 },
    })
    ttRow:AddChild(UI.Label {
        text = "capitalize words",
        fontSize = 14,
        textTransform = "capitalize",
        fontColor = { 34, 197, 94, 255 },
    })

    -- whiteSpace + wordBreak
    section:AddChild(createLabel("whiteSpace=\"normal\" (auto-wrap) + wordBreak:"))
    local wsRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(wsRow)

    wsRow:AddChild(UI.Panel {
        width = 160, flexShrink = 0,
        backgroundColor = { 59, 130, 246, 30 },
        borderRadius = 6,
        padding = 8,
        borderWidth = 1,
        borderColor = { 59, 130, 246, 80 },
    }:AddChild(UI.Label {
        text = "This is a long text that should wrap automatically within the container width.",
        fontSize = 12,
        whiteSpace = "normal",
        width = "100%",
    }))

    wsRow:AddChild(UI.Panel {
        width = 160, flexShrink = 0,
        backgroundColor = { 239, 68, 68, 30 },
        borderRadius = 6,
        padding = 8,
        borderWidth = 1,
        borderColor = { 239, 68, 68, 80 },
    }:AddChild(UI.Label {
        text = "Superlongwordthatcannotbreakeasily breaks here.",
        fontSize = 12,
        whiteSpace = "normal",
        wordBreak = "break-word",
        width = "100%",
    }))
end

-- ============================================================================
-- Phase 3: Blend Mode
-- ============================================================================
do
    local section = createSection(
        "Phase 3-7: Blend Mode",
        "blendMode = \"lighter\" | \"xor\" | \"destination-over\" etc."
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap", padding = 8 }
    section:AddChild(row)

    -- Base blue panel with overlapping blend mode panels
    local modes = { "normal", "lighter", "xor", "destination-over" }
    for _, mode in ipairs(modes) do
        local container = UI.Panel {
            width = 100, height = 80,
            backgroundColor = { 59, 130, 246, 200 },
            borderRadius = 8,
            justifyContent = "flex-end",
            alignItems = "flex-end",
        }
        -- Overlapping red panel with blend mode
        container:AddChild(UI.Panel {
            width = 60, height = 50,
            backgroundColor = { 239, 68, 68, 200 },
            borderRadius = 6,
            blendMode = mode,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = mode, fontSize = 9, color = { 255, 255, 255, 255 } }))
        row:AddChild(container)
    end
end

-- ============================================================================
-- Phase 3: Scroll Snap
-- ============================================================================
do
    local section = createSection(
        "Phase 3-8: Scroll Snap",
        "scrollSnapType=\"y mandatory\" + scrollSnapAlign=\"start\" on children"
    )

    local snapScroll = UI.ScrollView {
        width = "100%",
        height = 180,
        scrollY = true,
        showScrollbar = true,
        backgroundColor = UI.Theme.Color("surfaceAlt"),
        borderRadius = 8,
        scrollSnapType = "y mandatory",
    }
    section:AddChild(snapScroll)

    local snapContent = UI.Panel {
        width = "100%",
        flexDirection = "column",
    }
    snapScroll:AddChild(snapContent)

    local snapColors = {
        { 59, 130, 246, 255 },
        { 34, 197, 94, 255 },
        { 239, 68, 68, 255 },
        { 168, 85, 247, 255 },
        { 245, 158, 11, 255 },
    }

    for i = 1, 5 do
        snapContent:AddChild(UI.Panel {
            width = "100%",
            height = 180,
            backgroundColor = snapColors[i],
            scrollSnapAlign = "start",
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label {
            text = "Snap Page " .. i,
            fontSize = 18,
            fontWeight = "bold",
            color = { 255, 255, 255, 255 },
        }))
    end

    section:AddChild(createLabel("Scroll up/down — snaps to each page boundary (mandatory)"))
end

-- ============================================================================
-- Phase 3: Position Fixed (floating button)
-- ============================================================================
do
    -- Fixed button at bottom-right of viewport (outside ScrollView)
    local fixedBtn = UI.Button {
        text = "Fixed!",
        variant = "primary",
        position = "fixed",
        bottom = 30,
        right = 30,
        width = 80,
        height = 40,
        borderRadius = 20,
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 60 } },
        },
        onClick = function(self)
            print("[Fixed Button] Clicked!")
        end,
    }
    root:AddChild(fixedBtn)
end

-- ============================================================================
-- Baseline Alignment
-- ============================================================================
do
    local section = createSection(
        "Baseline Alignment",
        "alignItems=\"baseline\" — different font sizes align on text baseline"
    )

    -- Row 1: different font sizes
    local row1 = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "baseline",
        gap = 12,
        padding = 12,
        backgroundColor = { 40, 45, 65, 180 },
        borderRadius = 8,
    }
    row1:AddChild(UI.Label { text = "24px", fontSize = 24, fontColor = { 255, 200, 100, 255 } })
    row1:AddChild(UI.Label { text = "16px", fontSize = 16, fontColor = { 150, 220, 255, 255 } })
    row1:AddChild(UI.Label { text = "12px", fontSize = 12, fontColor = { 180, 255, 180, 255 } })
    row1:AddChild(UI.Label { text = "32px", fontSize = 32, fontColor = { 255, 150, 200, 255 } })
    section:AddChild(createLabel("Different font sizes — text baselines should align"))
    section:AddChild(row1)

    -- Row 2: labels with padding
    local row2 = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "baseline",
        gap = 12,
        padding = 12,
        backgroundColor = { 40, 45, 65, 180 },
        borderRadius = 8,
    }
    row2:AddChild(UI.Label { text = "No pad", fontSize = 20, fontColor = { 255, 200, 100, 255 } })
    row2:AddChild(UI.Label { text = "Pad 8", fontSize = 20, fontColor = { 150, 220, 255, 255 }, padding = 8, backgroundColor = { 60, 50, 80, 180 } })
    row2:AddChild(UI.Label { text = "Pad 16", fontSize = 20, fontColor = { 180, 255, 180, 255 }, padding = 16, backgroundColor = { 60, 50, 80, 180 } })
    section:AddChild(createLabel("Same font size, different padding — baselines still aligned"))
    section:AddChild(row2)

    -- Row 3: contrast with center alignment
    local row3 = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 12,
        padding = 12,
        backgroundColor = { 40, 45, 65, 180 },
        borderRadius = 8,
    }
    row3:AddChild(UI.Label { text = "24px", fontSize = 24, fontColor = { 255, 200, 100, 255 } })
    row3:AddChild(UI.Label { text = "16px", fontSize = 16, fontColor = { 150, 220, 255, 255 } })
    row3:AddChild(UI.Label { text = "12px", fontSize = 12, fontColor = { 180, 255, 180, 255 } })
    row3:AddChild(UI.Label { text = "32px", fontSize = 32, fontColor = { 255, 150, 200, 255 } })
    section:AddChild(createLabel("Contrast: alignItems=\"center\" — vertical centers aligned instead"))
    section:AddChild(row3)
end

-- ============================================================================
-- Regression: Multiline Label Typewriter (auto-height jitter fix)
-- ============================================================================
-- Bug: When a multiline Label (whiteSpace="normal") receives text char-by-char
-- (typewriter effect), the text visibly jitters on the frame where line count
-- changes (e.g., 1→2 lines). Root cause: Yoga layout height updates one frame
-- late, so vertical alignment used stale contentH with fresh textH, producing
-- a negative y-offset for one frame.
-- Fix: When autoHeight_ is true, use measured textH for vertical alignment
-- instead of Yoga's stale contentH.
-- ============================================================================
do
    local section = createSection(
        "Regression: Multiline Typewriter",
        "autoHeight Label with per-frame SetText — no jitter on line wrap"
    )

    local fullText = "这是一段用来测试打字机效果的文字。当文本从一行变成两行时，不应该出现任何抖动或闪烁。每个字逐帧追加，验证 autoHeight 的垂直对齐在行数变化时保持稳定。"
    local charIndex = 0
    local typeTimer = 0
    local typeSpeed = 0.04  -- seconds per character
    local isTyping = false

    -- Dialog-like container (fixed height, like AVG game dialog box)
    local dialogContainer = UI.Panel {
        width = "100%",
        height = 120,
        padding = 16,
        backgroundColor = { 0, 0, 0, 160 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 255, 255, 255, 30 },
    }
    section:AddChild(dialogContainer)

    local typewriterLabel = UI.Label {
        id = "typewriterLabel",
        text = "",
        fontSize = 15,
        fontColor = { 230, 230, 230, 255 },
        whiteSpace = "normal",
        lineHeight = 1.6,
        width = "100%",
    }
    dialogContainer:AddChild(typewriterLabel)

    -- UTF-8 helpers (local to this block)
    local function utf8Len(str)
        local len = 0
        local i = 1
        while i <= #str do
            local b = string.byte(str, i)
            if b < 128 then i = i + 1
            elseif b < 224 then i = i + 2
            elseif b < 240 then i = i + 3
            else i = i + 4 end
            len = len + 1
        end
        return len
    end

    local function utf8Sub(str, s, e)
        local bs, cc = 1, 0
        while cc < s - 1 and bs <= #str do
            local b = string.byte(str, bs)
            if b < 128 then bs = bs + 1
            elseif b < 224 then bs = bs + 2
            elseif b < 240 then bs = bs + 3
            else bs = bs + 4 end
            cc = cc + 1
        end
        local be, ec = bs, 0
        while ec < (e - s + 1) and be <= #str do
            local b = string.byte(str, be)
            if b < 128 then be = be + 1
            elseif b < 224 then be = be + 2
            elseif b < 240 then be = be + 3
            else be = be + 4 end
            ec = ec + 1
        end
        return string.sub(str, bs, be - 1)
    end

    local totalChars = utf8Len(fullText)

    -- Control buttons
    local btnRow = UI.Row { gap = 12, marginTop = 12 }
    section:AddChild(btnRow)

    btnRow:AddChild(UI.Button {
        text = "Start Typewriter",
        variant = "primary",
        onClick = function()
            charIndex = 0
            typeTimer = 0
            isTyping = true
            typewriterLabel:SetText("")
        end,
    })

    btnRow:AddChild(UI.Button {
        text = "Show All",
        variant = "outlined",
        onClick = function()
            isTyping = false
            charIndex = totalChars
            typewriterLabel:SetText(fullText)
        end,
    })

    btnRow:AddChild(UI.Button {
        text = "Reset",
        variant = "outlined",
        onClick = function()
            isTyping = false
            charIndex = 0
            typewriterLabel:SetText("")
        end,
    })

    -- Store for Update handler
    state.typewriter = {
        label = typewriterLabel,
        fullText = fullText,
        totalChars = totalChars,
        getCharIndex = function() return charIndex end,
        setCharIndex = function(v) charIndex = v end,
        getTimer = function() return typeTimer end,
        setTimer = function(v) typeTimer = v end,
        isTyping = function() return isTyping end,
        setTyping = function(v) isTyping = v end,
        speed = typeSpeed,
        utf8Sub = utf8Sub,
    }
end

-- ============================================================================
-- Text Effects: textStroke & textShadow
-- ============================================================================
do
    local section = createSection(
        "Text Effects: textStroke & textShadow",
        "Text outline and shadow effects on Label"
    )

    -- textStroke demos
    section:AddChild(createLabel("textStroke: white text with black outline"))
    section:AddChild(UI.Label {
        text = "Stroked Text",
        fontSize = 24,
        fontColor = {255, 255, 255, 255},
        textStroke = { width = 2, color = {0, 0, 0, 255} },
    })

    section:AddChild(createLabel("textStroke: gold text with dark red outline"))
    section:AddChild(UI.Label {
        text = "Gold Outlined",
        fontSize = 28,
        fontColor = {255, 215, 0, 255},
        textStroke = { width = 3, color = "#8B0000" },
    })

    -- textShadow demos
    section:AddChild(createLabel("textShadow: blur shadow"))
    section:AddChild(UI.Label {
        text = "Shadow Text",
        fontSize = 24,
        fontColor = UI.Theme.Color("text"),
        textShadow = { offsetX = 2, offsetY = 3, blur = 4, color = {0, 0, 0, 128} },
    })

    section:AddChild(createLabel("textShadow: hard shadow (blur=0)"))
    section:AddChild(UI.Label {
        text = "Hard Shadow",
        fontSize = 24,
        fontColor = {255, 255, 255, 255},
        textShadow = { offsetX = 2, offsetY = 2, blur = 0, color = {0, 0, 0, 200} },
    })

    -- Combined: textStroke + textShadow
    section:AddChild(createLabel("textStroke + textShadow combined"))
    section:AddChild(UI.Label {
        text = "Stroke + Shadow",
        fontSize = 28,
        fontColor = {255, 255, 255, 255},
        textStroke = { width = 2, color = {40, 40, 40, 255} },
        textShadow = { offsetX = 3, offsetY = 3, blur = 5, color = {0, 0, 0, 160} },
    })
end

-- ============================================================================
-- ProgressBar: fillColor & fillGradient
-- ============================================================================
do
    local section = createSection(
        "ProgressBar: fillColor & fillGradient",
        "Custom fill color and gradient for ProgressBar"
    )

    -- fillColor demos
    section:AddChild(createLabel("fillColor: custom red"))
    section:AddChild(UI.ProgressBar {
        value = 0.7,
        width = "100%",
        height = 12,
        fillColor = {220, 50, 50, 255},
    })

    section:AddChild(createLabel("fillColor: custom blue"))
    section:AddChild(UI.ProgressBar {
        value = 0.5,
        width = "100%",
        height = 12,
        fillColor = "#3366FF",
    })

    -- fillGradient demos
    section:AddChild(createLabel("fillGradient: left-to-right gradient"))
    section:AddChild(UI.ProgressBar {
        value = 0.8,
        width = "100%",
        height = 16,
        fillGradient = {
            direction = "to-right",
            from = {76, 175, 80, 255},
            to = {139, 195, 74, 255},
        },
    })

    section:AddChild(createLabel("fillGradient: warm gradient"))
    section:AddChild(UI.ProgressBar {
        value = 0.6,
        width = "100%",
        height = 16,
        fillGradient = {
            direction = "to-right",
            from = "#FF6B35",
            to = "#FFD700",
        },
    })

    -- transition: value (animated progress)
    section:AddChild(createLabel("transition: click button to animate value change"))

    local animBar = UI.ProgressBar {
        value = 0.2,
        width = "100%",
        height = 16,
        fillGradient = {
            direction = "to-right",
            from = {76, 175, 80, 255},
            to = {139, 195, 74, 255},
        },
        transition = "value 0.5s easeOut",
    }
    section:AddChild(animBar)

    local toggleHigh = false
    section:AddChild(UI.Button {
        text = "Toggle 20% / 90%",
        marginTop = 4,
        onClick = function()
            toggleHigh = not toggleHigh
            animBar:SetValue(toggleHigh and 0.9 or 0.2)
        end,
    })
end

-- ============================================================================
-- Padding Shorthand Expansion
-- ============================================================================
do
    local section = createSection(
        "Padding Shorthand Expansion",
        "Verifies padding table/axis/number shorthand is correctly expanded to per-side props"
    )

    -- Helper: create a colored box and return its layout after Yoga compute
    local function paddingBox(label, props)
        props.width = props.width or 200
        props.height = props.height or 60
        props.backgroundColor = props.backgroundColor or { 60, 50, 80, 180 }
        local panel = UI.Panel(props)
        panel:AddChild(UI.Label {
            text = label,
            fontSize = 12,
            fontColor = { 200, 200, 200, 255 },
        })
        return panel
    end

    local row = UI.Row { gap = 12, flexWrap = "wrap", padding = 8 }
    section:AddChild(row)

    -- Case 1: padding = {10, 20} — table 2-value shorthand
    row:AddChild(paddingBox("T2: {10,20}", { padding = {10, 20} }))

    -- Case 2: padding = {5, 10, 15, 20} — table 4-value
    row:AddChild(paddingBox("T4: {5,10,15,20}", { padding = {5, 10, 15, 20} }))

    -- Case 3: padding = {10, 20} + paddingLeft override
    row:AddChild(paddingBox("T2+pL=5", { padding = {10, 20}, paddingLeft = 5 }))

    -- Case 4: padding = {10, 20} + paddingHorizontal override
    row:AddChild(paddingBox("T2+pH=15", { padding = {10, 20}, paddingHorizontal = 15 }))

    -- Case 5: padding = 10 + paddingVertical = 20 + paddingTop = 5
    row:AddChild(paddingBox("p10+pV20+pT5", { padding = 10, paddingVertical = 20, paddingTop = 5 }))

    -- Case 6: padding = 10 (number, uniform)
    row:AddChild(paddingBox("p=10", { padding = 10 }))

    -- Case 7: padding = "5%" (percentage)
    row:AddChild(paddingBox("p=5%", { padding = "5%" }))

    -- Verification labels
    section:AddChild(createLabel(
        "Expected: T2→T10/R20/B10/L20 | T4→T5/R10/B15/L20 | T2+pL→L5 | T2+pH→L15/R15 | p+pV+pT→T5/R10/B20/L10 | p10→all 10 | 5%→all 5%"
    ))

    -- Component-specific tests: verify each modified widget reads expanded padding correctly
    section:AddChild(createLabel("— Component regression tests —"))
    local row2 = UI.Row { gap = 12, flexWrap = "wrap", padding = 8 }
    section:AddChild(row2)

    -- Label: padding table should position text correctly (not break rendering)
    row2:AddChild(UI.Label {
        text = "Label pad={8,16}",
        fontSize = 14,
        fontColor = { 200, 220, 255, 255 },
        padding = { 8, 16 },
        backgroundColor = { 60, 50, 80, 180 },
    })

    -- Label: paddingHorizontal should expand and render text with correct inset
    row2:AddChild(UI.Label {
        text = "Label pH=20",
        fontSize = 14,
        fontColor = { 180, 255, 180, 255 },
        paddingHorizontal = 20,
        paddingVertical = 4,
        backgroundColor = { 60, 50, 80, 180 },
    })

    -- Button: paddingHorizontal default (16) should expand; width auto-calculated correctly
    row2:AddChild(UI.Button { text = "Btn default" })

    -- Button: explicit paddingHorizontal should expand and affect width
    row2:AddChild(UI.Button { text = "Btn pH=30", paddingHorizontal = 30 })

    -- Button: asymmetric padding — paddingLeft/paddingRight override
    row2:AddChild(UI.Button { text = "Btn pL5/pR25", paddingLeft = 5, paddingRight = 25 })

    -- TextField: paddingHorizontal default (12) should expand; text area correctly inset
    row2:AddChild(UI.TextField { placeholder = "TF default", width = 140 })

    -- TextField: explicit paddingHorizontal
    row2:AddChild(UI.TextField { placeholder = "TF pH=24", width = 140, paddingHorizontal = 24 })

    -- Card: ClearCardPadding should clear per-side padding (not leave stale values)
    local card = UI.Card { width = 180, padding = { 12, 16 } }
    card:SetHeader("Card hdr")
    card:AddBody(UI.Label { text = "Card body", fontSize = 12, fontColor = { 200, 200, 200, 255 } })
    row2:AddChild(card)

    section:AddChild(createLabel(
        "Labels/Buttons should show correct text inset. TextField text area aligned. Card header/body should have no extra padding."
    ))
end

-- ============================================================================
-- Regression: CJK nvgTextBox Line-Break Width
-- ============================================================================
-- Bug: nvgTextBreakLines() updates rowWidth (includes current char) BEFORE
-- recording breakWidth, but breakEnd = charStart means "break before this char".
-- So breakWidth is one CJK char wider than the actual line content.
-- This inflates nvgTextBoxBounds → adjustForOverhang detects false overhang
-- → narrows renderBreakWidth → each line shows ~2 fewer CJK characters.
-- English is unaffected (break at SPACE, which doesn't update rowWidth).
-- See: docs/fix-nanovg-cjk-line-break-width.md
-- ============================================================================
do
    local section = createSection(
        "Regression: CJK nvgTextBox Line-Break Width",
        "nvgTextBox auto-wrap vs nvgTextBounds-measured reference"
    )

    -- Split text into lines using nvgTextBounds (single-line measurement).
    -- This bypasses nvgTextBreakLines entirely, giving the correct char count per line.
    local function measureSplitCJK(text, maxWidth, nvgFontSize, fontFace)
        local lines = {}
        local remaining = text
        while #remaining > 0 do
            local charCount = utf8.len(remaining)
            local fitChars = charCount
            for i = 1, charCount do
                local bytePos = utf8.offset(remaining, i + 1)
                local sub = bytePos and string.sub(remaining, 1, bytePos - 1) or remaining
                local w = UI.MeasureTextWidth(sub, nvgFontSize, fontFace)
                if w > maxWidth then
                    fitChars = math.max(1, i - 1)
                    break
                end
            end
            local byteEnd = utf8.offset(remaining, fitChars + 1)
            table.insert(lines, byteEnd and string.sub(remaining, 1, byteEnd - 1) or remaining)
            remaining = byteEnd and string.sub(remaining, byteEnd) or ""
        end
        return lines
    end

    -- Split English text at word boundaries using nvgTextBounds measurement.
    local function measureSplitWords(text, maxWidth, nvgFontSize, fontFace)
        local lines = {}
        local words = {}
        for w in text:gmatch("%S+") do table.insert(words, w) end
        local line = ""
        for _, word in ipairs(words) do
            local candidate = line == "" and word or (line .. " " .. word)
            local w = UI.MeasureTextWidth(candidate, nvgFontSize, fontFace)
            if w > maxWidth and line ~= "" then
                table.insert(lines, line)
                line = word
            else
                line = candidate
            end
        end
        if line ~= "" then table.insert(lines, line) end
        return lines
    end

    -- ---- C: 250px bubble, CJK ----
    local cjkText = "哥，你最近忙吗？好几天没回我消息了。"
    local cjkFontSize = 14
    local cContainerW = 250
    local cPadding = 10
    local cContentW = cContainerW - 2 * cPadding
    local cNvgFS = UI.Theme.FontSize(cjkFontSize)
    local cFontFace = UI.Theme.FontFace(nil, nil)
    local cLines = measureSplitCJK(cjkText, cContentW, cNvgFS, cFontFace)

    section:AddChild(createLabel(string.format(
        "C: %dpx bubble (padding=%d, content=%dpx), fontSize=%d, %d chars → measured %d lines",
        cContainerW, cPadding, cContentW, cjkFontSize,
        utf8.len(cjkText), #cLines
    )))

    local cRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(cRow)

    -- C1: nvgTextBox (affected by bug → fewer chars per line)
    local c1Wrap = UI.Panel { flexDirection = "column", gap = 2 }
    c1Wrap:AddChild(UI.Label {
        text = "C1: nvgTextBox",
        fontSize = 11,
        fontColor = { 160, 160, 160, 255 },
    })
    c1Wrap:AddChild(UI.Panel {
        width = cContainerW, flexShrink = 0,
        padding = cPadding,
        backgroundColor = { 149, 236, 105, 255 },
        borderRadius = 8,
    }:AddChild(UI.Label {
        text = cjkText,
        fontSize = cjkFontSize,
        fontColor = { 0, 0, 0, 255 },
        whiteSpace = "normal",
        width = "100%",
    }))
    cRow:AddChild(c1Wrap)

    -- C2: measured single-line Labels (correct reference, bypasses nvgTextBreakLines)
    local c2Wrap = UI.Panel { flexDirection = "column", gap = 2 }
    c2Wrap:AddChild(UI.Label {
        text = "C2: measured lines",
        fontSize = 11,
        fontColor = { 160, 160, 160, 255 },
    })
    local c2Bubble = UI.Panel {
        width = cContainerW, flexShrink = 0,
        padding = cPadding,
        backgroundColor = { 149, 236, 105, 255 },
        borderRadius = 8,
        flexDirection = "column",
    }
    for _, line in ipairs(cLines) do
        c2Bubble:AddChild(UI.Label {
            text = line,
            fontSize = cjkFontSize,
            fontColor = { 0, 0, 0, 255 },
        })
    end
    c2Wrap:AddChild(c2Bubble)
    cRow:AddChild(c2Wrap)

    -- ---- D: 200px, English ----
    local engText = "Hello world this is a test for label wrapping behavior"
    local engFontSize = 14
    local dContainerW = 200
    local dPadding = 10
    local dContentW = dContainerW - 2 * dPadding
    local dNvgFS = UI.Theme.FontSize(engFontSize)
    local dFontFace = UI.Theme.FontFace(nil, nil)
    local dLines = measureSplitWords(engText, dContentW, dNvgFS, dFontFace)

    section:AddChild(createLabel(string.format(
        "D: %dpx bubble (padding=%d, content=%dpx), fontSize=%d, English → measured %d lines",
        dContainerW, dPadding, dContentW, engFontSize, #dLines
    )))

    local dRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(dRow)

    -- D1: nvgTextBox (English unaffected by bug)
    local d1Wrap = UI.Panel { flexDirection = "column", gap = 2 }
    d1Wrap:AddChild(UI.Label {
        text = "D1: nvgTextBox",
        fontSize = 11,
        fontColor = { 160, 160, 160, 255 },
    })
    d1Wrap:AddChild(UI.Panel {
        width = dContainerW, flexShrink = 0,
        padding = dPadding,
        backgroundColor = { 220, 240, 255, 255 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 100, 180, 255, 80 },
    }:AddChild(UI.Label {
        text = engText,
        fontSize = engFontSize,
        fontColor = { 0, 0, 0, 255 },
        whiteSpace = "normal",
        width = "100%",
    }))
    dRow:AddChild(d1Wrap)

    -- D2: measured word-boundary Labels (reference)
    local d2Wrap = UI.Panel { flexDirection = "column", gap = 2 }
    d2Wrap:AddChild(UI.Label {
        text = "D2: measured lines",
        fontSize = 11,
        fontColor = { 160, 160, 160, 255 },
    })
    local d2Bubble = UI.Panel {
        width = dContainerW, flexShrink = 0,
        padding = dPadding,
        backgroundColor = { 220, 240, 255, 255 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 100, 180, 255, 80 },
        flexDirection = "column",
    }
    for _, line in ipairs(dLines) do
        d2Bubble:AddChild(UI.Label {
            text = line,
            fontSize = engFontSize,
            fontColor = { 0, 0, 0, 255 },
        })
    end
    d2Wrap:AddChild(d2Bubble)
    dRow:AddChild(d2Wrap)

    section:AddChild(createLabel(
        "C2/D2 use nvgTextBounds to measure and split text (no nvgTextBreakLines). "
        .. "If CJK bug is present: C1 shows fewer chars per line than C2. "
        .. "English (D1 vs D2) should match."
    ))
end

-- ============================================================================
-- Set Root
-- ============================================================================

UI.SetRoot(root)

-- ============================================================================
-- Auto-start keyframe animations after a short delay
-- ============================================================================

local eventNode = Node()
local eventHandler = eventNode:CreateScriptObject("LuaScriptObject")
local startTimer = 0.5  -- Start animations after 0.5s

eventHandler:SubscribeToEvent("Update", function(self, eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if startTimer > 0 then
        startTimer = startTimer - dt
        if startTimer <= 0 then
            -- Auto-start the keyframe animations
            if state.animWidgets.pulse then
                state.animWidgets.pulse:Animate({
                    keyframes = {
                        [0]   = { scale = 1.0 },
                        [0.5] = { scale = 1.3 },
                        [1]   = { scale = 1.0 },
                    },
                    duration = 0.8,
                    easing = "easeInOut",
                    loop = true,
                })
            end
            if state.animWidgets.fade then
                state.animWidgets.fade:Animate({
                    keyframes = {
                        [0] = { opacity = 1.0 },
                        [1] = { opacity = 0.2 },
                    },
                    duration = 1.0,
                    easing = "easeInOut",
                    loop = true,
                    direction = "alternate",
                })
            end
            if state.animWidgets.slide then
                state.animWidgets.slide:Animate({
                    keyframes = {
                        [0] = { translateX = 0 },
                        [1] = { translateX = 40 },
                    },
                    duration = 1.2,
                    easing = "easeInOutCubic",
                    loop = true,
                    direction = "alternate",
                })
            end
            if state.animWidgets.spin then
                state.animWidgets.spin:Animate({
                    keyframes = {
                        [0] = { rotate = 0 },
                        [1] = { rotate = 360 },
                    },
                    duration = 2.0,
                    easing = "linear",
                    loop = true,
                })
            end
        end
    end

    -- Typewriter update
    local tw = state.typewriter
    if tw and tw.isTyping() then
        local t = tw.getTimer() + dt
        local ci = tw.getCharIndex()
        while t >= tw.speed and ci < tw.totalChars do
            ci = ci + 1
            t = t - tw.speed
        end
        tw.setTimer(t)
        tw.setCharIndex(ci)
        tw.label:SetText(tw.utf8Sub(tw.fullText, 1, ci))
        if ci >= tw.totalChars then
            tw.setTyping(false)
        end
    end
end)
