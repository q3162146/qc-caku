-- ============================================================================
-- UI Inspector Test
-- Press F9 to enter inspect mode, click any widget, type a description,
-- then press Enter to copy the report to clipboard.
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- Build a sample UI to inspect
-- ============================================================================

local root = UI.Panel {
    id = "root",
    width = "100%",
    height = "100%",
    padding = 20,
    gap = 16,
    flexDirection = "column",
    backgroundColor = UI.Theme.Color("background"),
}

-- Header
root:AddChild(UI.Label {
    id = "title",
    text = "UI Inspector Test",
    fontSize = UI.Theme.FontSizeOf("headline"),
    fontWeight = "bold",
    color = UI.Theme.Color("text"),
})

root:AddChild(UI.Label {
    text = "Press F9 to enter inspect mode. Click any widget to select it.",
    fontSize = UI.Theme.FontSizeOf("body"),
    color = UI.Theme.Color("textSecondary"),
})

root:AddChild(UI.Divider {})

-- A row of buttons
local buttonRow = UI.Panel {
    id = "buttonRow",
    flexDirection = "row",
    gap = 12,
    alignItems = "center",
}
root:AddChild(buttonRow)

buttonRow:AddChild(UI.Button {
    id = "btnPrimary",
    text = "Primary Button",
    variant = "primary",
    margin = 8,
    onClick = function() print("Primary clicked") end,
})

buttonRow:AddChild(UI.Button {
    id = "btnSecondary",
    text = "Secondary",
    variant = "secondary",
    onClick = function() print("Secondary clicked") end,
})

buttonRow:AddChild(UI.Button {
    id = "btnSmall",
    text = "Small",
    onClick = function() print("Small clicked") end,
})

-- A card with nested content
local card = UI.Card {
    id = "infoCard",
    width = 350,
}
root:AddChild(card)

card:AddChild(UI.Label {
    text = "Sample Card",
    fontSize = UI.Theme.FontSizeOf("title"),
    fontWeight = "bold",
    color = UI.Theme.Color("text"),
})

card:AddChild(UI.Label {
    text = "This is a card with some content inside. Try selecting this text in inspect mode.",
    fontSize = UI.Theme.FontSizeOf("body"),
    color = UI.Theme.Color("textSecondary"),
    whiteSpace = "normal",
})

local cardButtons = UI.Panel {
    flexDirection = "row",
    gap = 8,
    marginTop = 8,
}
card:AddChild(cardButtons)

cardButtons:AddChild(UI.Button {
    text = "Action 1",
    variant = "primary",
})

cardButtons:AddChild(UI.Button {
    text = "Action 2",
    variant = "secondary",
})

-- Form section
local form = UI.Panel {
    id = "formSection",
    gap = 12,
    padding = 16,
    backgroundColor = UI.Theme.Color("surface"),
    borderRadius = 8,
}
root:AddChild(form)

form:AddChild(UI.Label {
    text = "Form Example",
    fontSize = UI.Theme.FontSizeOf("title"),
    fontWeight = "bold",
    color = UI.Theme.Color("text"),
})

form:AddChild(UI.TextField {
    id = "nameInput",
    placeholder = "Enter your name",
})

local sliderRow = UI.Panel {
    flexDirection = "row",
    gap = 12,
    alignItems = "center",
}
form:AddChild(sliderRow)

sliderRow:AddChild(UI.Label {
    text = "Volume:",
    fontSize = UI.Theme.FontSizeOf("body"),
    color = UI.Theme.Color("text"),
})

sliderRow:AddChild(UI.Slider {
    id = "volumeSlider",
    width = 200,
    value = 70,
})

local checkRow = UI.Panel {
    flexDirection = "row",
    gap = 16,
    alignItems = "center",
}
form:AddChild(checkRow)

checkRow:AddChild(UI.Checkbox {
    id = "checkbox1",
    label = "Enable notifications",
})

checkRow:AddChild(UI.Toggle {
    id = "toggle1",
    value = true,
})

-- ScrollView case: inspector frames should follow the visual scrolled position.
local scrollCase = UI.ScrollView {
    id = "scrollInspectorCase",
    width = 360,
    height = 120,
    bounces = false,
    showScrollbar = true,
    backgroundColor = UI.Theme.Color("surface"),
    borderColor = UI.Theme.Color("border"),
    borderWidth = 1,
    borderRadius = 8,
}
root:AddChild(scrollCase)

local scrollContent = UI.Panel {
    gap = 10,
    padding = 12,
}
scrollCase:AddChild(scrollContent)

scrollContent:AddChild(UI.Label {
    text = "ScrollView Inspector Case",
    fontSize = UI.Theme.FontSizeOf("body"),
    fontWeight = "bold",
    fontColor = UI.Theme.Color("text"),
})

scrollContent:AddChild(UI.Panel {
    height = 48,
})

scrollContent:AddChild(UI.Panel {
    id = "scrolledTarget",
    padding = 10,
    gap = 4,
    backgroundColor = UI.Theme.Color("surfaceHover"),
    borderColor = UI.Theme.Color("borderFocus"),
    borderWidth = 1,
    borderRadius = 6,
    children = {
        UI.Label {
            text = "Scrolled Target",
            fontSize = UI.Theme.FontSizeOf("caption"),
            fontWeight = "bold",
            fontColor = UI.Theme.Color("text"),
        },
        UI.Label {
            text = "Scroll offset should not move the inspector frame away.",
            fontSize = UI.Theme.FontSizeOf("caption"),
            fontColor = UI.Theme.Color("textSecondary"),
            whiteSpace = "normal",
        },
    },
})

scrollContent:AddChild(UI.Panel {
    height = 60,
})

scrollCase:SetScrollDirect(0, 46)

-- Free-move case: explicit absolute offsets so selection-box movement can apply left/top.
root:AddChild(UI.Panel {
    id = "freeMoveCase",
    position = "absolute",
    left = 430,
    top = 118,
    width = 220,
    padding = 12,
    gap = 6,
    backgroundColor = UI.Theme.Color("surfaceHover"),
    borderColor = UI.Theme.Color("borderFocus"),
    borderWidth = 1,
    borderRadius = 8,
    children = {
        UI.Label {
            text = "Free Move Case",
            fontSize = UI.Theme.FontSizeOf("body"),
            fontWeight = "bold",
            fontColor = UI.Theme.Color("text"),
        },
        UI.Label {
            text = "Select this panel, then drag its empty area.",
            fontSize = UI.Theme.FontSizeOf("caption"),
            fontColor = UI.Theme.Color("textSecondary"),
            whiteSpace = "normal",
        },
    },
})

-- Footer
root:AddChild(UI.Spacer())

root:AddChild(UI.Label {
    text = "Tip: After selecting a widget, the report includes widget path, source locations, and props.",
    fontSize = UI.Theme.FontSizeOf("caption"),
    color = UI.Theme.Color("textSecondary"),
})

-- ============================================================================
-- Set root
-- ============================================================================

UI.SetRoot(root)

return root
