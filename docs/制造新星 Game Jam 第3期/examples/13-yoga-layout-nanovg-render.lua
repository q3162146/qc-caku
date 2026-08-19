-- ============================================================================
-- UrhoX Yoga + NanoVG UI Scaffold (Flexbox UI 脚手架)
-- 版本: 1.1
-- 用途: 使用 Yoga Flexbox 布局 + NanoVG 渲染的现代 UI 系统
-- 特性: 支持 Hover 效果和点击交互
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 1. 全局变量
-- ============================================================================

---@type NVGContextWrapper
local nvg_ = nil
---@type YGNodeRef
local rootLayout_ = nil

-- 交互状态
local mouseX_, mouseY_ = 0, 0
local mousePressed_ = false
local hoveredButton_ = nil   -- 当前 hover 的按钮索引
local pressedButton_ = nil   -- 当前按下的按钮索引

-- 按钮数据 (用于交互检测)
local buttons_ = {}

-- UI 配置
local UI_CONFIG = {
    -- 颜色定义 (RGBA)
    Colors = {
        Background = { 30, 30, 40, 255 },
        Panel = { 50, 55, 70, 230 },
        Button = { 70, 130, 180, 255 },
        ButtonHover = { 90, 150, 200, 255 },
        ButtonPressed = { 50, 110, 160, 255 },
        Text = { 255, 255, 255, 255 },
        Border = { 100, 100, 120, 255 },
    },
    -- 间距
    Padding = 16,
    Gap = 12,
    BorderRadius = 8,
}

-- ============================================================================
-- 2. 生命周期
-- ============================================================================

function Start()
    SampleStart()
    graphics.windowTitle = "Yoga + NanoVG UI Demo"

    -- 初始化 NanoVG
    nvg_ = nvgCreate(1)
    nvgCreateFont(nvg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 创建 UI 布局
    CreateUILayout()

    -- 订阅事件
    SubscribeToEvent(nvg_, "NanoVGRender", "HandleRender")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
end

function Stop()
    -- 释放 Yoga 布局树
    if rootLayout_ then
        YGNodeFreeRecursive(rootLayout_)
        rootLayout_ = nil
    end
    -- 释放 NanoVG
    if nvg_ then
        nvgDelete(nvg_)
        nvg_ = nil
    end
end

-- ============================================================================
-- 3. Yoga 布局创建 (核心示例)
-- ============================================================================

function CreateUILayout()
    local W, H = graphics.width, graphics.height

    -- ========================================
    -- 根节点 (全屏容器)
    -- ========================================
    rootLayout_ = YGNodeNew()
    YGNodeStyleSetWidth(rootLayout_, W)
    YGNodeStyleSetHeight(rootLayout_, H)
    YGNodeStyleSetFlexDirection(rootLayout_, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(rootLayout_, YGJustifyCenter)
    YGNodeStyleSetAlignItems(rootLayout_, YGAlignCenter)
    YGNodeStyleSetGap(rootLayout_, YGGutterAll, UI_CONFIG.Gap)

    -- ========================================
    -- 示例面板 (垂直布局)
    -- ========================================
    local panel = YGNodeNew()
    YGNodeStyleSetWidth(panel, 400)
    YGNodeStyleSetPadding(panel, YGEdgeAll, UI_CONFIG.Padding)
    YGNodeStyleSetFlexDirection(panel, YGFlexDirectionColumn)
    YGNodeStyleSetGap(panel, YGGutterAll, UI_CONFIG.Gap)
    YGNodeInsertChild(rootLayout_, panel, 0)

    -- 标题
    local title = YGNodeNew()
    YGNodeStyleSetHeight(title, 40)
    YGNodeInsertChild(panel, title, 0)

    -- 按钮行 (水平布局)
    local buttonRow = YGNodeNew()
    YGNodeStyleSetFlexDirection(buttonRow, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(buttonRow, YGJustifySpaceBetween)
    YGNodeStyleSetGap(buttonRow, YGGutterAll, UI_CONFIG.Gap)
    YGNodeInsertChild(panel, buttonRow, 1)

    -- 三个按钮 (flex: 1 平分空间)
    for i = 1, 3 do
        local btn = YGNodeNew()
        YGNodeStyleSetFlexGrow(btn, 1)
        YGNodeStyleSetHeight(btn, 44)
        YGNodeInsertChild(buttonRow, btn, i - 1)
    end

    -- ========================================
    -- 计算布局 (必须调用!)
    -- ========================================
    YGNodeCalculateLayout(rootLayout_, W, H, YGDirectionLTR)
end

-- ============================================================================
-- 4. 鼠标事件处理
-- ============================================================================

function HandleMouseMove(eventType, eventData)
    mouseX_ = eventData["X"]:GetInt()
    mouseY_ = eventData["Y"]:GetInt()

    -- 更新 hover 状态
    hoveredButton_ = nil
    for i, btn in ipairs(buttons_) do
        if PointInRect(mouseX_, mouseY_, btn.x, btn.y, btn.w, btn.h) then
            hoveredButton_ = i
            break
        end
    end
end

function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        mousePressed_ = true
        -- 如果在按钮上按下，记录按下状态
        if hoveredButton_ then
            pressedButton_ = hoveredButton_
        end
    end
end

function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        mousePressed_ = false
        -- 如果在同一个按钮上释放，触发点击
        if pressedButton_ and pressedButton_ == hoveredButton_ then
            OnButtonClick(pressedButton_)
        end
        pressedButton_ = nil
    end
end

-- 按钮点击回调
function OnButtonClick(buttonIndex)
    local btn = buttons_[buttonIndex]
    if btn then
        print("Button clicked: " .. btn.label)
        -- 在这里添加你的按钮点击逻辑
    end
end

-- 点是否在矩形内
function PointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- ============================================================================
-- 5. NanoVG 渲染
-- ============================================================================

function HandleRender(eventType, eventData)
    if not nvg_ or not rootLayout_ then return end

    local W, H = graphics.width, graphics.height
    nvgBeginFrame(nvg_, W, H, 1.0)

    -- 渲染 UI 树
    RenderNode(rootLayout_, 0)

    nvgEndFrame(nvg_)
end

-- 递归渲染节点
function RenderNode(node, depth)
    local x = YGNodeLayoutGetLeft(node)
    local y = YGNodeLayoutGetTop(node)
    local w = YGNodeLayoutGetWidth(node)
    local h = YGNodeLayoutGetHeight(node)

    -- 根据深度选择不同的渲染样式
    if depth == 1 then
        -- 面板样式
        DrawPanel(x, y, w, h)
        DrawText(x + w/2, y + 20, "Yoga + NanoVG UI", 24, true)
    elseif depth == 3 then
        -- 按钮样式
        local btnIndex = GetNodeIndex(node)
        local labels = { "Button 1", "Button 2", "Button 3" }
        local label = labels[btnIndex + 1] or "Button"
        local buttonArrayIndex = btnIndex + 1

        -- 注册按钮数据用于交互检测
        buttons_[buttonArrayIndex] = { x = x, y = y, w = w, h = h, label = label }

        -- 确定按钮状态
        local state = "normal"
        if pressedButton_ == buttonArrayIndex then
            state = "pressed"
        elseif hoveredButton_ == buttonArrayIndex then
            state = "hover"
        end

        DrawButton(x, y, w, h, label, state)
    end

    -- 递归渲染子节点
    local childCount = YGNodeGetChildCount(node)
    for i = 0, childCount - 1 do
        local child = YGNodeGetChild(node, i)
        RenderNode(child, depth + 1)
    end
end

-- 获取节点在父节点中的索引
function GetNodeIndex(node)
    local parent = YGNodeGetParent(node)
    if not parent then return 0 end
    local count = YGNodeGetChildCount(parent)
    for i = 0, count - 1 do
        if YGNodeGetChild(parent, i) == node then
            return i
        end
    end
    return 0
end

-- ============================================================================
-- 6. UI 绘制辅助函数
-- ============================================================================

function DrawPanel(x, y, w, h)
    local c = UI_CONFIG.Colors.Panel
    local r = UI_CONFIG.BorderRadius

    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, x, y, w, h, r)
    nvgFillColor(nvg_, nvgRGBA(c[1], c[2], c[3], c[4]))
    nvgFill(nvg_)

    -- 边框
    local bc = UI_CONFIG.Colors.Border
    nvgStrokeColor(nvg_, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgStrokeWidth(nvg_, 1)
    nvgStroke(nvg_)
end

function DrawButton(x, y, w, h, label, state)
    -- 根据状态选择颜色
    local c
    if state == "pressed" then
        c = UI_CONFIG.Colors.ButtonPressed
    elseif state == "hover" then
        c = UI_CONFIG.Colors.ButtonHover
    else
        c = UI_CONFIG.Colors.Button
    end
    local r = UI_CONFIG.BorderRadius

    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, x, y, w, h, r)
    nvgFillColor(nvg_, nvgRGBA(c[1], c[2], c[3], c[4]))
    nvgFill(nvg_)

    -- 按钮文字
    DrawText(x + w/2, y + h/2, label, 16, true)
end

function DrawText(x, y, text, size, center)
    local c = UI_CONFIG.Colors.Text
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, size)
    nvgFillColor(nvg_, nvgRGBA(c[1], c[2], c[3], c[4]))
    if center then
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    else
        nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    end
    nvgText(nvg_, x, y, text, nil)
end

-- ============================================================================
-- 7. Yoga API 快速参考
-- ============================================================================
--[[

=== 节点管理 ===
YGNodeNew()                              -- 创建节点
YGNodeFree(node)                         -- 释放单个节点
YGNodeFreeRecursive(node)                -- 递归释放整棵树
YGNodeInsertChild(parent, child, index)  -- 插入子节点
YGNodeRemoveChild(parent, child)         -- 移除子节点
YGNodeGetChildCount(node)                -- 获取子节点数量
YGNodeGetChild(node, index)              -- 获取子节点
YGNodeGetParent(node)                    -- 获取父节点

=== 布局计算 ===
YGNodeCalculateLayout(node, width, height, direction)
-- direction: YGDirectionLTR, YGDirectionRTL, YGDirectionInherit

=== 布局结果 (计算后获取) ===
YGNodeLayoutGetLeft(node)
YGNodeLayoutGetTop(node)
YGNodeLayoutGetWidth(node)
YGNodeLayoutGetHeight(node)

=== 常用样式 ===
-- 尺寸
YGNodeStyleSetWidth(node, value)
YGNodeStyleSetHeight(node, value)
YGNodeStyleSetWidthPercent(node, percent)
YGNodeStyleSetHeightPercent(node, percent)
YGNodeStyleSetWidthAuto(node)
YGNodeStyleSetHeightAuto(node)

-- Flex 方向
YGNodeStyleSetFlexDirection(node, direction)
-- YGFlexDirectionColumn (默认), YGFlexDirectionRow
-- YGFlexDirectionColumnReverse, YGFlexDirectionRowReverse

-- 主轴对齐 (JustifyContent)
YGNodeStyleSetJustifyContent(node, justify)
-- YGJustifyFlexStart (默认), YGJustifyCenter, YGJustifyFlexEnd
-- YGJustifySpaceBetween, YGJustifySpaceAround, YGJustifySpaceEvenly

-- 交叉轴对齐 (AlignItems)
YGNodeStyleSetAlignItems(node, align)
-- YGAlignStretch (默认), YGAlignFlexStart, YGAlignCenter
-- YGAlignFlexEnd, YGAlignBaseline

-- Flex 属性
YGNodeStyleSetFlexGrow(node, grow)       -- 放大比例 (默认 0)
YGNodeStyleSetFlexShrink(node, shrink)   -- 缩小比例 (默认 1)
YGNodeStyleSetFlex(node, flex)           -- 简写

-- 间距
YGNodeStyleSetGap(node, gutter, value)
-- gutter: YGGutterColumn, YGGutterRow, YGGutterAll

-- 边距 (Margin) / 内边距 (Padding)
YGNodeStyleSetMargin(node, edge, value)
YGNodeStyleSetPadding(node, edge, value)
-- edge: YGEdgeLeft, YGEdgeTop, YGEdgeRight, YGEdgeBottom
--       YGEdgeHorizontal, YGEdgeVertical, YGEdgeAll

-- 定位
YGNodeStyleSetPositionType(node, type)
-- YGPositionTypeRelative (默认), YGPositionTypeAbsolute

]]--
