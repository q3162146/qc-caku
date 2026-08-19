-- ============================================================================
-- SimpleGrid + ScrollView Test
-- Verify SimpleGrid renders correct column count inside ScrollView
-- ============================================================================

local UI = require("urhox-libs/UI")

-- Initialize UI
UI.Init({
    theme = "dark",
    fonts = {
        { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
    },
})

-- Color palette for grid items
local colors = {
    "#e74c3c", "#e67e22", "#f1c40f", "#2ecc71", "#1abc9c",
    "#3498db", "#9b59b6", "#e91e63", "#00bcd4", "#8bc34a",
    "#ff9800", "#795548",
}

local function itemColor(i)
    return colors[((i - 1) % #colors) + 1]
end

-- ============================================================================
-- Root
-- ============================================================================

local root = UI.Panel {
    id = "root",
    width = "100%",
    height = "100%",
    padding = 16,
    gap = 16,
    backgroundColor = "#1a1a2e",
}

root:AddChild(UI.Label {
    text = "SimpleGrid + ScrollView Test",
    fontSize = 22,
    fontColor = "#ffffff",
})

-- ============================================================================
-- Two-column comparison layout
-- ============================================================================

local compareRow = UI.Panel {
    flexDirection = "row",
    flexGrow = 1,
    gap = 16,
}
root:AddChild(compareRow)

-- ============================================================================
-- Left: SimpleGrid OUTSIDE ScrollView (reference)
-- ============================================================================

local leftCol = UI.Panel {
    flex = 1,
    gap = 8,
}
compareRow:AddChild(leftCol)

leftCol:AddChild(UI.Label {
    text = "Outside ScrollView (reference)",
    fontSize = 14,
    fontColor = "#aaaaaa",
})

-- columns=3, no gap
leftCol:AddChild(UI.Label {
    text = "columns=3, no gap",
    fontSize = 12,
    fontColor = "#888888",
})

local gridRef1 = UI.SimpleGrid { columns = 3 }
for i = 1, 9 do
    gridRef1:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
leftCol:AddChild(gridRef1)

-- columns=3, gap=8
leftCol:AddChild(UI.Label {
    text = "columns=3, gap=8",
    fontSize = 12,
    fontColor = "#888888",
    marginTop = 8,
})

local gridRef2 = UI.SimpleGrid { columns = 3, gap = 8 }
for i = 1, 9 do
    gridRef2:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
leftCol:AddChild(gridRef2)

-- columns=3, margin=4 on children (regression test: margin must not break column count)
leftCol:AddChild(UI.Label {
    text = "columns=3, margin=4 on children",
    fontSize = 12,
    fontColor = "#888888",
    marginTop = 8,
})

local gridRef2b = UI.SimpleGrid { columns = 3 }
for i = 1, 9 do
    gridRef2b:AddChild(UI.Panel {
        height = 40,
        margin = 4,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
leftCol:AddChild(gridRef2b)

-- columns=4, gap=4
leftCol:AddChild(UI.Label {
    text = "columns=4, gap=4",
    fontSize = 12,
    fontColor = "#888888",
    marginTop = 8,
})

local gridRef3 = UI.SimpleGrid { columns = 4, gap = 4 }
for i = 1, 12 do
    gridRef3:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
leftCol:AddChild(gridRef3)

-- ============================================================================
-- Right: SimpleGrid INSIDE ScrollView (the bug scenario)
-- ============================================================================

local rightCol = UI.Panel {
    flex = 1,
    gap = 8,
}
compareRow:AddChild(rightCol)

rightCol:AddChild(UI.Label {
    text = "Inside ScrollView (was buggy)",
    fontSize = 14,
    fontColor = "#aaaaaa",
})

local scrollView = UI.ScrollView {
    scrollY = true,
    flexGrow = 1,
}
rightCol:AddChild(scrollView)

local svContent = UI.Panel {
    gap = 16,
}
scrollView:AddChild(svContent)

-- columns=3, no gap
svContent:AddChild(UI.Label {
    text = "columns=3, no gap",
    fontSize = 12,
    fontColor = "#888888",
})

local gridSV1 = UI.SimpleGrid { columns = 3 }
for i = 1, 9 do
    gridSV1:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
svContent:AddChild(gridSV1)

-- columns=3, gap=8
svContent:AddChild(UI.Label {
    text = "columns=3, gap=8",
    fontSize = 12,
    fontColor = "#888888",
})

local gridSV2 = UI.SimpleGrid { columns = 3, gap = 8 }
for i = 1, 9 do
    gridSV2:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
svContent:AddChild(gridSV2)

-- columns=3, margin=4 on children (regression test)
svContent:AddChild(UI.Label {
    text = "columns=3, margin=4 on children",
    fontSize = 12,
    fontColor = "#888888",
})

local gridSV2b = UI.SimpleGrid { columns = 3 }
for i = 1, 9 do
    gridSV2b:AddChild(UI.Panel {
        height = 40,
        margin = 4,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
svContent:AddChild(gridSV2b)

-- columns=4, gap=4
svContent:AddChild(UI.Label {
    text = "columns=4, gap=4",
    fontSize = 12,
    fontColor = "#888888",
})

local gridSV3 = UI.SimpleGrid { columns = 4, gap = 4 }
for i = 1, 12 do
    gridSV3:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
svContent:AddChild(gridSV3)

-- columns=5, gap=6 (stress test: odd division)
svContent:AddChild(UI.Label {
    text = "columns=5, gap=6 (odd division)",
    fontSize = 12,
    fontColor = "#888888",
})

local gridSV4 = UI.SimpleGrid { columns = 5, gap = 6 }
for i = 1, 15 do
    gridSV4:AddChild(UI.Panel {
        height = 40,
        backgroundColor = itemColor(i),
        borderRadius = 4,
    })
end
svContent:AddChild(gridSV4)

-- columns=2, gap=12, with Label children
svContent:AddChild(UI.Label {
    text = "columns=2, gap=12, Label children",
    fontSize = 12,
    fontColor = "#888888",
})

local gridSV5 = UI.SimpleGrid { columns = 2, gap = 12 }
for i = 1, 6 do
    local cell = UI.Panel {
        height = 60,
        backgroundColor = itemColor(i),
        borderRadius = 8,
        padding = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    cell:AddChild(UI.Label {
        text = "Item " .. i,
        fontSize = 14,
        fontColor = "#ffffff",
    })
    gridSV5:AddChild(cell)
end
svContent:AddChild(gridSV5)

-- ============================================================================
-- Bottom: result label
-- ============================================================================

root:AddChild(UI.Label {
    text = "Left and right should show identical column counts.",
    fontSize = 13,
    fontColor = "#666666",
})

-- Set root
UI.SetRoot(root)
