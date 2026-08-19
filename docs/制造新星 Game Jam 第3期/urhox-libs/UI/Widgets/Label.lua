-- ============================================================================
-- Label Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Text display widget
-- 
-- IMPORTANT: Yoga uses border-box model!
-- When setting explicit width, padding is INSIDE the width (like CSS box-sizing: border-box).
-- So width must = textWidth + paddingLeft + paddingRight
-- Reference: 3rd/yoga/website/docs/styling/width-height.mdx
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")
local UI = require("urhox-libs/UI/Core/UI")

---@class LabelProps : WidgetProps
---@field text? string Text content
---@field fontSize? number Font size
---@field fontColor? table RGBA color
---@field fontFamily? string Font name (base family, e.g. "sans")
---@field fontWeight? string "normal" | "bold" | "100"-"900"
---@field textAlign? string "left" | "center" | "right"
---@field verticalAlign? string "top" | "middle" | "bottom"
---@field maxLines? number Maximum lines (truncate with ...)
---@field pointerEvents? string "auto" | "none" (default: "none")
---@field color? table Alias for fontColor
---@field lineHeight? number Line height multiplier (default: 1.4)
---@field letterSpacing? number Letter spacing in pixels
---@field textDecoration? string "none" | "underline" | "line-through"
---@field textTransform? string "none" | "uppercase" | "lowercase" | "capitalize"
---@field whiteSpace? string "nowrap" (default) | "normal" (auto-wrap)
---@field wordBreak? string "normal" | "break-word"
---@field textStroke? table Text outline { width: number, color: string|table(RGBA) }
---@field textShadow? table Text shadow { offsetX: number, offsetY: number, blur: number, color: string|table(RGBA) }

---@class Label : Widget
---@overload fun(props?: LabelProps): Label
---@field props LabelProps
---@field new fun(self, props?: LabelProps): Label
local Label = Widget:Extend("Label")

-- ============================================================================
-- Helper: Calculate total padding
-- ============================================================================

---Calculate horizontal padding (left + right)
---Note: padding/paddingHorizontal/paddingVertical are already expanded to
---per-side props by Widget.expandPaddingShorthand at Init/SetStyle time.
---@param props table
---@return number paddingLeft, number paddingRight
local function getHorizontalPadding(props)
    return props.paddingLeft or 0, props.paddingRight or 0
end

---Calculate vertical padding (top + bottom)
---@param props table
---@return number paddingTop, number paddingBottom
local function getVerticalPadding(props)
    return props.paddingTop or 0, props.paddingBottom or 0
end

---Apply textTransform to text string (pure, no side effects)
---@param text string
---@param transform string|nil
---@return string
local function applyTextTransform(text, transform)
    if not transform or transform == "none" then return text end
    if transform == "uppercase" then return string.upper(text) end
    if transform == "lowercase" then return string.lower(text) end
    if transform == "capitalize" then
        return text:gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. b end)
    end
    return text
end

--- Compute single-line content min height (CSS min-height:auto equivalent).
--- Same formula as the default height calculation in Init.
---@param props table Label props (needs fontSize, lineHeight, padding)
---@return number Single-line content height including vertical padding
local function computeSingleLineMinHeight(props)
    local basePxSize = Theme.FontSize(props.fontSize)
    local lh = props.lineHeight or 1.4
    local pt, pb = getVerticalPadding(props)
    return math.ceil(basePxSize * lh) + pt + pb
end

--- Adjust breakWidth and renderX to keep glyph visuals within parent clip.
--- Decorative fonts have strokes extending beyond advance width; even standard
--- fonts can have small negative left bearings. When the parent container clips
--- (e.g. ScrollView via nvgIntersectScissor), edge characters get visually clipped.
---
--- Strategy: measure glyph bounds, detect overhang beyond layout area, then
--- narrow breakWidth so text wraps in a tighter area and overhang stays within
--- the parent's clip region. When actual overhang is detected, an extra 1px
--- safety margin covers NanoVG's AA fringe (fringeWidth ~1px beyond path bounds).
---
--- One re-verification pass after narrowing catches new overhang from changed
--- line wrapping (different characters at line edges). Convergence is guaranteed:
--- glyph overhang is bounded (~2-3px per side), so each pass subtracts a small
--- bounded amount from an already-narrowed width.
---
---@param nvg NVGContextWrapper
---@param breakWidth number Available width for text wrapping
---@param contentX number Left edge of content area
---@param text string Text to measure
---@param boxHAlign number NanoVG horizontal alignment (NVG_ALIGN_LEFT/CENTER/RIGHT)
---@return number renderBreakWidth Adjusted break width
---@return number renderX Adjusted left edge for nvgTextBox
---@return table renderBounds Final measured bounds {x1,y1,x2,y2}
local function adjustForOverhang(nvg, breakWidth, contentX, text, boxHAlign)
    nvgTextAlign(nvg, boxHAlign + NVG_ALIGN_TOP)
    local bounds = nvgTextBoxBounds(nvg, 0, 0, breakWidth, text)

    -- Detect overhang: bounds[1] < 0 = left overhang, bounds[3] > breakWidth = right.
    -- Only add 1px AA fringe margin when actual overhang is detected, to avoid
    -- unnecessary narrowing for standard fonts with no overhang (bounds[1] ≈ 0).
    local leftOH, rightOH = 0, 0
    if bounds and bounds[1] and bounds[3] then
        leftOH = math.max(0, -bounds[1])
        rightOH = math.max(0, bounds[3] - breakWidth)
        if leftOH > 0 then leftOH = leftOH + 1 end
        if rightOH > 0 then rightOH = rightOH + 1 end
    end

    -- Narrow breakWidth so overhang stays within parent clip.
    -- Expanding Label's own scissor doesn't help: nvgIntersectScissor takes
    -- intersection with parent (e.g. ScrollView) — parent's clip wins.
    local renderBreakWidth = breakWidth
    local renderX = contentX
    if leftOH > 0 or rightOH > 0 then
        renderBreakWidth = math.max(1, breakWidth - leftOH - rightOH)
        renderX = contentX + leftOH
    end

    -- Re-verify: narrowing changes line wrapping, new line-start characters
    -- may have different overhang. Apply one correction pass.
    local renderBounds = (renderBreakWidth ~= breakWidth)
        and nvgTextBoxBounds(nvg, 0, 0, renderBreakWidth, text)
        or bounds
    if renderBounds and renderBreakWidth ~= breakWidth then
        local newLeftOH = math.max(0, -renderBounds[1])
        local newRightOH = math.max(0, renderBounds[3] - renderBreakWidth)
        if newLeftOH > 0 then newLeftOH = newLeftOH + 1 end
        if newRightOH > 0 then newRightOH = newRightOH + 1 end
        if newLeftOH > 0 or newRightOH > 0 then
            renderBreakWidth = math.max(1, renderBreakWidth - newLeftOH - newRightOH)
            renderX = renderX + newLeftOH
            renderBounds = nvgTextBoxBounds(nvg, 0, 0, renderBreakWidth, text)
        end
    end

    return renderBreakWidth, renderX, renderBounds
end

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props LabelProps?
function Label:Init(props)
    props = props or {}

    -- Label defaults to not intercepting pointer events (like iOS UILabel)
    -- This prevents Label from stealing hover/click from parent Button
    -- Set pointerEvents = "auto" explicitly if you need clickable text
    props.pointerEvents = props.pointerEvents or "none"

    -- Apply typography defaults
    local typography = Theme.Typography("body")
    props.fontSize = props.fontSize or typography.fontSize
    props.fontFamily = props.fontFamily or Theme.FontFamily()
    props.fontColor = props.fontColor or props.color or Theme.Color("text")
    props.textAlign = props.textAlign or "left"
    props.verticalAlign = props.verticalAlign or "middle"

    local basePxSize = Theme.FontSize(props.fontSize)

    -- Expand padding shorthand before reading padding values
    -- (Widget.Init calls this again, but it's idempotent)
    Widget.ExpandPaddingShorthand(props)

    -- Calculate padding
    local pl, pr = getHorizontalPadding(props)
    local pt, pb = getVerticalPadding(props)

    -- Track user intent before applying defaults
    local userSetHeight = props.height ~= nil

    -- Set default height based on font size (with line height) + vertical padding
    -- IMPORTANT: Yoga uses border-box, so height must include padding
    if not props.height then
        local lh = props.lineHeight or 1.4
        props.height = math.ceil(basePxSize * lh) + pt + pb
    end

    -- Labels adapt to available space (text is clipped if shrunk below text width)
    props.flexShrink = props.flexShrink or 1

    -- CSS min-height:auto protection: prevent Yoga from shrinking Label below
    -- its single-line text height when flexShrink=1. Without this, tight containers
    -- can collapse the Label to near-zero height, clipping text vertically.
    -- User-provided minHeight takes precedence (including explicit 0 to opt out).
    if props.minHeight == nil then
        props.minHeight = computeSingleLineMinHeight(props)
        self.autoMinHeight_ = true
    else
        self.autoMinHeight_ = false
    end

    -- Track whether width was explicitly set by user or auto-calculated from text.
    -- SetText() only recalculates width when autoWidth is true.
    self.autoWidth_ = not props.width

    -- Multiline mode: width from parent, height from content
    -- Auto-detect: text containing \n enables multiline when whiteSpace not explicitly set
    self.multiline_ = props.whiteSpace == "normal"
        or (props.whiteSpace == nil and props.text ~= nil and string.find(props.text, "\n", 1, true) ~= nil)
    if self.multiline_ then
        if self.autoWidth_ then
            -- No explicit width → stretch to fill parent (like CSS block element)
            props.alignSelf = props.alignSelf or "stretch"
            self.autoWidth_ = false  -- Don't measure single-line text width
        end
        -- Mark for auto-height (Render will calculate via nvgTextBoxBounds)
        if not userSetHeight then
            self.autoHeight_ = true
            -- Keep the initial single-line height from above; Render will correct it
        end
    end

    -- Cache display text (with textTransform applied) to avoid per-frame recomputation
    if props.text then
        self.displayText_ = applyTextTransform(props.text, props.textTransform)
    end

    -- Record font version at measurement time for DWP reload detection
    self.fontVersion_ = UI.GetFontVersion()

    -- Set initial width using precise measurement + horizontal padding
    -- IMPORTANT: Yoga uses border-box, so width must include padding
    if self.autoWidth_ and self.displayText_ then
        local nvgFontSize = Theme.FontSize(props.fontSize)
        local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
        local measuredWidth = UI.MeasureTextWidth(self.displayText_, nvgFontSize, fontFace, props.letterSpacing)
        if measuredWidth > 0 then
            -- width = content (text) + padding (border-box model)
            props.width = measuredWidth + pl + pr
            -- Cache measured text width for Render auto-wrap detection.
            -- Comparing against cached value (not live nvgTextBounds) avoids false positives
            -- from floating-point differences between Init measurement and Render measurement.
            self.measuredTextWidth_ = measuredWidth
            -- Cap auto-width to parent's available width (like CSS behavior).
            -- Without this, text with explicit pixel width bypasses Yoga's parent constraint,
            -- causing overflow when alignItems="center" (parent doesn't limit child width).
            -- Only when measuredWidth>0 to avoid affecting emoji labels (measurement returns 0).
            if not props.maxWidth then
                props.maxWidth = "100%"
            end
        end
    end

    -- Parse nested color fields before Widget.Init
    -- (NormalizeColorProps only auto-parses top-level *Color props, not nested tables)
    if props.textStroke and type(props.textStroke.color) == "string" then
        props.textStroke.color = Style.ParseColor(props.textStroke.color)
    end
    if props.textShadow and type(props.textShadow.color) == "string" then
        props.textShadow.color = Style.ParseColor(props.textShadow.color)
    end

    Widget.Init(self, props)

    -- Cache the effective props used by Render and all derived measurements.
    -- Render refreshes this with the latest parent overrides every frame.
    self.props_override = self.props

    -- Set baseline value for Yoga alignItems="baseline" alignment
    -- Baseline = paddingTop + text ascender (distance from node top to text baseline)
    local nvgFontSize = Theme.FontSize(props.fontSize)
    local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
    local ascender = UI.MeasureTextBaseline(nvgFontSize, fontFace)
    YGNodeSetBaselineValue(self.node, pt + ascender)
end

--- Return the effective props cached by Render.
--- Before the first Render, fall back to the Label's own props.
---@return LabelProps
function Label:GetProps()
    return self.props_override or self.props
end

-- ============================================================================
-- Text Effects Helper
-- ============================================================================

-- 8-direction offsets for text stroke (N, NE, E, SE, S, SW, W, NW)
local STROKE_OFFSETS = {
    { 0, -1}, { 1, -1}, { 1,  0}, { 1,  1},
    { 0,  1}, {-1,  1}, {-1,  0}, {-1, -1},
}

--- Draw text at (x+dx, y+dy) using the appropriate NanoVG call.
---@param nvg NVGContextWrapper
---@param x number Base X
---@param y number Base Y
---@param dx number X offset
---@param dy number Y offset
---@param text string Text to draw
---@param boxWidth number|nil If non-nil, use nvgTextBox with this width; otherwise nvgText
local function drawTextAt(nvg, x, y, dx, dy, text, boxWidth)
    if boxWidth then
        nvgTextBox(nvg, x + dx, y + dy, boxWidth, text, nil)
    else
        nvgText(nvg, x + dx, y + dy, text, nil)
    end
end

--- Draw text with optional shadow and stroke effects (no per-frame closure).
---@param nvg NVGContextWrapper
---@param props table Label props (textShadow, textStroke)
---@param fillColor table RGBA fill color
---@param x number Base X position
---@param y number Base Y position
---@param text string Text to draw
---@param boxWidth number|nil If non-nil, use nvgTextBox; otherwise nvgText
local function drawTextWithEffects(nvg, props, fillColor, x, y, text, boxWidth)
    local shadow = props.textShadow
    local stroke = props.textStroke

    -- Layer 1: Shadow (behind everything)
    if shadow then
        local sc = shadow.color or {0, 0, 0, 128}
        nvgFontBlur(nvg, shadow.blur or 0)
        nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4] or 255))
        drawTextAt(nvg, x, y, shadow.offsetX or 0, shadow.offsetY or 0, text, boxWidth)
        nvgFontBlur(nvg, 0)
    end

    -- Layer 2: Stroke (8-direction offset)
    if stroke and stroke.width and stroke.width > 0 then
        local sc = stroke.color or {0, 0, 0, 255}
        nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4] or 255))
        local w = stroke.width
        for i = 1, 8 do
            local off = STROKE_OFFSETS[i]
            drawTextAt(nvg, x, y, off[1] * w, off[2] * w, text, boxWidth)
        end
    end

    -- Layer 3: Fill text (on top)
    nvgFillColor(nvg, nvgRGBA(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 255))
    drawTextAt(nvg, x, y, 0, 0, text, boxWidth)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Label:Render(nvg)
    local l = self:GetAbsoluteLayout()

    -- Refresh the effective props once per frame. Non-render measurement paths use
    -- the same cached table so their layout matches what is actually drawn.
    local previousProps = self:GetProps()
    self.props_override = Widget.GetParentOverride(self, self.props)
    local props = self:GetProps()
    if previousProps.fontSize ~= props.fontSize then
        self:RefreshFontLayout(props)
    end

    -- Render background if set (shadow + color + image + border)
    -- Yoga returns border-box dimensions, so background covers the full area including padding
    if props.backgroundColor or props.backgroundImage or props.borderColor then
        self:RenderFullBackground(nvg)
    end

    local text = self.displayText_ or props.text or ""
    if text == "" then
        return
    end

    -- DWP font reload: re-measure cached text dimensions when font version changes
    local curFontVer = UI.GetFontVersion()
    if self.fontVersion_ ~= curFontVer then
        self.fontVersion_ = curFontVer
        local nvgFS = Theme.FontSize(props.fontSize)
        local ff = Theme.FontFace(props.fontFamily, props.fontWeight)
        -- Re-measure width (same logic as SetText)
        if self.autoWidth_ and self.displayText_ then
            local textWidth = UI.MeasureTextWidth(self.displayText_, nvgFS, ff, props.letterSpacing)
            if textWidth > 0 and textWidth ~= self.measuredTextWidth_ then
                self.measuredTextWidth_ = textWidth
                local pl, pr = getHorizontalPadding(props)
                Widget.SetWidth(self, textWidth + pl + pr)
            end
        end
        -- Re-measure min height
        if self.autoMinHeight_ then
            Widget.SetMinHeight(self, computeSingleLineMinHeight(props))
        end
        -- Re-measure baseline
        local ascender = UI.MeasureTextBaseline(nvgFS, ff)
        local pt = props.paddingTop or 0
        YGNodeSetBaselineValue(self.node, pt + ascender)
        -- Clear multiline cache to trigger height recalc
        if self.multiline_ or self.autoHeight_ then
            self.lastMultilineWidth_ = nil
        end
    end

    -- Set font (convert pt to px for NanoVG)
    local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
    nvgFontFace(nvg, fontFace)
    nvgFontSize(nvg, Theme.FontSize(props.fontSize))

    -- Always reset line height and letter spacing to prevent state leak
    -- between sibling widgets (NanoVG state persists across Render calls)
    nvgTextLineHeight(nvg, props.lineHeight or 1.0)
    nvgTextLetterSpacing(nvg, props.letterSpacing or 0)

    -- Set color
    local color = props.fontColor
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))

    -- Calculate content area (border-box minus padding)
    -- Since Yoga returns border-box, we need to inset for text positioning
    local pl, pr = getHorizontalPadding(props)
    local pt, pb = getVerticalPadding(props)

    local contentX = l.x + pl
    local contentY = l.y + pt
    local contentW = l.w - pl - pr
    local contentH = l.h - pt - pb

    -- Determine if we should use multiline rendering
    local useMultiline = self.multiline_
    local breakWidth = contentW

    -- Calculate position based on alignment within content area
    local x, y
    local hAlign, vAlign

    -- Horizontal align
    if props.textAlign == "center" then
        x = contentX + contentW / 2
        hAlign = NVG_ALIGN_CENTER_VISUAL
    elseif props.textAlign == "right" then
        x = contentX + contentW
        hAlign = NVG_ALIGN_RIGHT
    else
        x = contentX
        hAlign = NVG_ALIGN_LEFT
    end

    if useMultiline then
        -- nvgTextBox only recognizes NVG_ALIGN_LEFT/CENTER/RIGHT in its internal mask.
        -- NVG_ALIGN_CENTER_VISUAL (bit 7) is not included, causing text to not render.
        -- Map it to standard NVG_ALIGN_CENTER for multiline.
        local boxHAlign = hAlign
        if hAlign == NVG_ALIGN_CENTER_VISUAL then
            boxHAlign = NVG_ALIGN_CENTER
        end

        -- breakWidth safety: ensure at least 1px to prevent nvgTextBox rendering nothing
        breakWidth = math.max(1, contentW)

        -- Detect glyph overhang and adjust breakWidth/renderX to keep text
        -- within parent clip (see adjustForOverhang doc comment for details)
        local renderBreakWidth, renderX, renderBounds
            = adjustForOverhang(nvg, breakWidth, contentX, text, boxHAlign)
        local textH = renderBounds and (renderBounds[4] - renderBounds[2]) or contentH

        -- Auto-height: recalculate when width changes (like RichText pattern)
        if self.autoHeight_ and contentW > 0 then
            if contentW ~= self.lastMultilineWidth_ then
                self.lastMultilineWidth_ = contentW
                if textH > 0 then
                    local mpt, mpb = getVerticalPadding(props)
                    local newHeight = math.ceil(textH) + mpt + mpb
                    if math.abs(newHeight - l.h) > 1 then
                        Widget.SetHeight(self, newHeight)
                    end
                end
            end
        end

        -- Vertical align
        -- When autoHeight_ is true, use measured textH instead of stale Yoga contentH.
        -- Yoga height updates one frame late, so contentH may lag behind actual text height
        -- (e.g., during typewriter effects when line count changes mid-frame).
        local alignH = self.autoHeight_ and textH or contentH
        if props.verticalAlign == "top" then
            y = contentY
        elseif props.verticalAlign == "bottom" then
            y = contentY + alignH - textH
        else
            y = contentY + (alignH - textH) / 2
        end

        -- Draw multiline text
        -- IMPORTANT: nvgTextBox x is always the LEFT edge of the text box.
        -- Alignment (center/right) is handled internally by NanoVG within breakWidth.
        -- This differs from nvgText where x is the alignment anchor point.
        if not self.autoWidth_ then
            nvgSave(nvg)
            nvgIntersectScissor(nvg, contentX, l.y, contentW, l.h)
        end
        if props.textShadow or props.textStroke then
            drawTextWithEffects(nvg, props, color, renderX, y, text, renderBreakWidth)
        else
            nvgTextBox(nvg, renderX, y, renderBreakWidth, text, nil)
        end
        if not self.autoWidth_ then
            nvgRestore(nvg)
        end
    else
        -- Single-line rendering (default: whiteSpace = "nowrap")

        -- Auto-wrap: when maxWidth constrains layout width significantly below text measurement,
        -- switch to multiline rendering (like CSS white-space: normal).
        -- Uses cached measuredTextWidth_ from Init (not live nvgTextBounds) to avoid
        -- false positives from float precision / Yoga rounding differences.
        -- Auto-wrap tolerance: Yoga rounds layout values with PointScaleFactor (= UI scale).
        -- Max rounding error = 0.5 / scale. With small scale (large designSize on small screen),
        -- the error can exceed a fixed pixel threshold. Use scale-aware tolerance.
        local wrapTolerance = math.ceil(0.5 / (Theme.GetScale() or 1)) + 0.5
        if self.autoWidth_ and self.measuredTextWidth_ and contentW > 0
            and contentW < self.measuredTextWidth_ - wrapTolerance then
            local boxHAlign = hAlign
            if hAlign == NVG_ALIGN_CENTER_VISUAL then
                boxHAlign = NVG_ALIGN_CENTER
            end

            local wrapWidth = math.max(1, contentW)
            local renderWrapWidth, renderWrapX, renderBounds
                = adjustForOverhang(nvg, wrapWidth, contentX, text, boxHAlign)
            local textH = renderBounds and (renderBounds[4] - renderBounds[2]) or contentH

            -- Auto-adjust height for wrapped text (same pattern as multiline autoHeight_)
            if contentW ~= self.lastMultilineWidth_ then
                self.lastMultilineWidth_ = contentW
                if textH > 0 then
                    local mpt, mpb = getVerticalPadding(props)
                    local newHeight = math.ceil(textH) + mpt + mpb
                    if math.abs(newHeight - l.h) > 1 then
                        Widget.SetHeight(self, newHeight)
                    end
                end
            end

            -- Vertical align within content area (use textH when auto-height)
            local wrapAlignH = self.autoHeight_ and textH or contentH
            if props.verticalAlign == "top" then
                y = contentY
            elseif props.verticalAlign == "bottom" then
                y = contentY + wrapAlignH - textH
            else
                y = contentY + (wrapAlignH - textH) / 2
            end

            if props.textShadow or props.textStroke then
                drawTextWithEffects(nvg, props, color, renderWrapX, y, text, renderWrapWidth)
            else
                nvgTextBox(nvg, renderWrapX, y, renderWrapWidth, text, nil)
            end
            return
        end

        -- Normal single-line path (text fits in layout width)
        -- Vertical align
        if props.verticalAlign == "top" then
            y = contentY
            vAlign = NVG_ALIGN_TOP
        elseif props.verticalAlign == "bottom" then
            y = contentY + contentH
            vAlign = NVG_ALIGN_BOTTOM
        else
            y = contentY + contentH / 2
            vAlign = NVG_ALIGN_MIDDLE
        end

        nvgTextAlign(nvg, hAlign + vAlign)

        -- Draw text: only clip when user set an explicit width (autoWidth_ = false).
        -- Auto-width labels are sized from text measurement; clipping them
        -- causes regressions (emoji measurement inaccuracy, sub-pixel rounding).
        local needClip = not self.autoWidth_
        if needClip then
            nvgSave(nvg)
            nvgIntersectScissor(nvg, contentX, l.y, contentW, l.h)
        end
        if props.textShadow or props.textStroke then
            drawTextWithEffects(nvg, props, color, x, y, text, nil)
        else
            nvgText(nvg, x, y, text, nil)
        end

        -- Draw text decoration (underline / line-through)
        local decoration = props.textDecoration
        if decoration and decoration ~= "none" then
            -- Get text metrics for line positioning
            local asc, desc, lineH = nvgTextMetrics(nvg)
            local textW2 = nvgTextBounds(nvg, x, y, text)

            -- Calculate text start X based on alignment
            local lineStartX
            if props.textAlign == "center" then
                lineStartX = x - textW2 / 2
            elseif props.textAlign == "right" then
                lineStartX = x - textW2
            else
                lineStartX = x
            end

            -- Draw the line
            nvgBeginPath(nvg)
            nvgStrokeWidth(nvg, 1)
            nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))

            if decoration == "underline" then
                -- Underline: below the baseline
                local lineY = y + desc * 0.5 + 1
                if vAlign == NVG_ALIGN_MIDDLE then
                    lineY = y + asc * 0.3 + 1
                elseif vAlign == NVG_ALIGN_TOP then
                    lineY = y + asc + 2
                end
                nvgMoveTo(nvg, lineStartX, lineY)
                nvgLineTo(nvg, lineStartX + textW2, lineY)
            elseif decoration == "line-through" then
                -- Strikethrough: middle of text
                local lineY = y
                if vAlign == NVG_ALIGN_MIDDLE then
                    lineY = y - asc * 0.15
                elseif vAlign == NVG_ALIGN_TOP then
                    lineY = y + asc * 0.4
                elseif vAlign == NVG_ALIGN_BOTTOM then
                    lineY = y - asc * 0.4
                end
                nvgMoveTo(nvg, lineStartX, lineY)
                nvgLineTo(nvg, lineStartX + textW2, lineY)
            end

            nvgStroke(nvg)
        end

        if needClip then
            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- SetStyle Override
-- ============================================================================

--- Override SetStyle to update derived state when text, textTransform, or fontSize changes.
--- Widget:SetStyle merges props directly (bypasses setter methods), so caches would go stale.
---@param style table
---@return Label self
function Label:SetStyle(style)
    local needFontUpdate = style.fontSize ~= nil
    local needTextUpdate = style.text ~= nil or style.textTransform ~= nil

    -- Parse nested color fields in textStroke/textShadow before merging
    if style.textStroke and type(style.textStroke.color) == "string" then
        style.textStroke.color = Style.ParseColor(style.textStroke.color)
    end
    if style.textShadow and type(style.textShadow.color) == "string" then
        style.textShadow.color = Style.ParseColor(style.textShadow.color)
    end

    if needFontUpdate or needTextUpdate then
        -- Let base SetStyle handle all props (yoga, transitions, merge)
        Widget.SetStyle(self, style)

        -- Update font-derived layout (baseline + auto min-height); shared with the
        -- Render parent-override path via RefreshFontLayout.
        if needFontUpdate then
            self:RefreshFontLayout(self:GetProps())
        end

        -- Update text display state
        if needTextUpdate then
            self.displayText_ = applyTextTransform(self.props.text or "", self.props.textTransform)
            if self.multiline_ then
                self.lastMultilineWidth_ = nil
                return self
            end
            if self.autoWidth_ and self.displayText_ ~= "" then
                local props = self:GetProps()
                local nvgFontSize = Theme.FontSize(props.fontSize)
                local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
                local textWidth = UI.MeasureTextWidth(self.displayText_, nvgFontSize, fontFace, props.letterSpacing)
                if textWidth > 0 then
                    self.measuredTextWidth_ = textWidth
                    local pl, pr = getHorizontalPadding(props)
                    Widget.SetWidth(self, textWidth + pl + pr)
                end
            end
        end

        return self
    end
    return Widget.SetStyle(self, style)
end

-- ============================================================================
-- Text Manipulation
-- ============================================================================

--- Set text content
---@param text string
---@return Label self
function Label:SetText(text)
    -- Skip if text hasn't changed
    if self.props.text == text then
        return self
    end
    self.props.text = text

    -- Update cached display text
    self.displayText_ = applyTextTransform(text, self.props.textTransform)

    -- Multiline: reset cache to trigger height recalc in next Render
    if self.multiline_ then
        self.lastMultilineWidth_ = nil
        return self
    end

    -- Only recalculate width if it was auto-sized (no explicit width set by user).
    -- If user set width="100%" or width=200, we respect that and let text clip.
    if self.autoWidth_ then
        local props = self:GetProps()
        local nvgFontSize = Theme.FontSize(props.fontSize)
        local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
        local textWidth = UI.MeasureTextWidth(self.displayText_, nvgFontSize, fontFace, props.letterSpacing)

        if textWidth > 0 then
            self.measuredTextWidth_ = textWidth
            self.fontVersion_ = UI.GetFontVersion()
            local pl, pr = getHorizontalPadding(props)
            -- Use Widget.SetWidth directly to avoid triggering autoWidth_ = false
            Widget.SetWidth(self, textWidth + pl + pr)
        end
    end

    return self
end

--- Override SetWidth to disable auto-width recalculation in SetText
---@param width number Width in base pixels
---@return Label self
function Label:SetWidth(width)
    self.autoWidth_ = false
    if self.multiline_ then
        self.lastMultilineWidth_ = nil  -- Trigger height recalc
    end
    return Widget.SetWidth(self, width)
end

--- Override SetHeight to disable auto-height recalculation in multiline Render
---@param height number Height in base pixels
---@return Label self
function Label:SetHeight(height)
    self.autoHeight_ = false
    return Widget.SetHeight(self, height)
end

--- Override SetMinHeight to disable auto-computation when user explicitly sets minHeight
---@param minHeight number|string
---@return Label self
function Label:SetMinHeight(minHeight)
    self.autoMinHeight_ = false
    return Widget.SetMinHeight(self, minHeight)
end

--- Get text content
---@return string
function Label:GetText()
    return self.props.text or ""
end

--- Set font size
---@param size number
---@return Label self
function Label:SetFontSize(size)
    self.props.fontSize = size

    self:RefreshFontLayout(self:GetProps())

    return self
end

--- Update font-derived layout (baseline + auto min-height) from the effective props
--- (self.props with any parent overrides applied), without mutating self.props.
--- Called from Render and font-size setters. Uses Widget.* base setters so the
--- auto min-height flag is preserved.
---@param props table Effective props (fontSize already resolved)
function Label:RefreshFontLayout(props)
    local nvgFS = Theme.FontSize(props.fontSize)
    local ff = Theme.FontFace(props.fontFamily, props.fontWeight)

    YGNodeSetBaselineValue(self.node, (props.paddingTop or 0) + UI.MeasureTextBaseline(nvgFS, ff))
    if self.autoMinHeight_ then
        Widget.SetMinHeight(self, computeSingleLineMinHeight(props))
    end
end

--- Set font color
--- Supports multiple formats: RGBA table, hex string, or CSS rgb/rgba
---@param color table|string RGBA table or color string (e.g., "#ff0000", "rgba(255,0,0,1)")
---@return Label self
function Label:SetFontColor(color)
    self.props.fontColor = Style.ParseColor(color) or color
    return self
end

-- ============================================================================
-- Stateless
-- ============================================================================

function Label:IsStateful()
    return false
end

return Label
