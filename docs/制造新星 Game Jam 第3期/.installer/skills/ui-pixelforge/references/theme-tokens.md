# PixelForge Theme Token Table

## Color Tokens

Usage: `UI.Theme.Color("tokenName")` -> `{R, G, B, A}`

### Core Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `primary` | `{33, 189, 174, 255}` | #21BDAE | Teal — primary buttons, links, active states |
| `primaryHover` | `{61, 208, 193, 255}` | #3DD0C1 | Primary hover |
| `primaryPressed` | `{25, 168, 153, 255}` | #19A899 | Primary pressed |
| `secondary` | `{108, 92, 231, 255}` | #6C5CE7 | Purple — secondary buttons, magic/arcane accents |
| `secondaryHover` | `{133, 119, 237, 255}` | #8577ED | Secondary hover |
| `secondaryPressed` | `{90, 75, 214, 255}` | #5A4BD6 | Secondary pressed |

### Background Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `background` | `{15, 15, 35, 255}` | #0F0F23 | Deep dark navy |
| `surface` | `{27, 27, 58, 255}` | #1B1B3A | Dark panel |
| `surfaceHover` | `{37, 37, 80, 255}` | #252550 | Panel hover |
| `disabled` | `{42, 42, 74, 255}` | #2A2A4A | Disabled background |

### Text Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `text` | `{240, 240, 240, 255}` | #F0F0F0 | Primary text (near-white) |
| `textSecondary` | `{160, 160, 192, 255}` | #A0A0C0 | Secondary text (muted lavender) |
| `textDisabled` | `{80, 80, 112, 255}` | #505070 | Disabled text |

### Border & Overlay

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `border` | `{58, 58, 106, 255}` | #3A3A6A | Default border (indigo) |
| `borderFocus` | `{33, 189, 174, 255}` | #21BDAE | Focus state border (= primary teal) |
| `overlay` | `{0, 0, 0, 180}` | #000000B4 | Modal/drawer backdrop |

### Semantic Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `success` | `{80, 200, 120, 255}` | #50C878 | Bright green — success, healing |
| `successHover` | `{102, 216, 142, 255}` | #66D88E | Success hover |
| `warning` | `{255, 217, 61, 255}` | #FFD93D | Bright yellow — warning, gold |
| `warningHover` | `{255, 224, 102, 255}` | #FFE066 | Warning hover |
| `error` | `{255, 71, 87, 255}` | #FF4757 | Bright red — error, danger, fire |
| `errorHover` | `{255, 107, 122, 255}` | #FF6B7A | Error hover |
| `info` | `{69, 170, 242, 255}` | #45AAF2 | Bright blue — info, mana, water |

---

## Shadow Profiles

Different components use different hard shadows — all assigned by the theme.

| Name | Value | Components |
|------|-------|------------|
| PIXEL_SHADOW (3px + bevel) | `{{x=3,y=3,blur=0,color={10,10,26,204}}, {x=-1,y=-1,blur=0,color={255,255,255,48}}}` | Button |
| Drop 3px | `{{x=3,y=3,blur=0,color={10,10,26,204}}}` | Menu, Dropdown, Toast, Popover |
| Drop 2px | `{{x=2,y=2,blur=0,color={10,10,26,204}}}` | Tooltip |
| Drop 4px | `{{x=4,y=4,blur=0,color={10,10,26,204}}}` | Card (elevated) |
| Dark 4px | `{{x=4,y=4,blur=0,color={0,0,0,204}}}` | Modal |
| Horiz 4px | `{{x=4,y=0,blur=0,color={10,10,26,204}}}` | Drawer |

### Button Inset Stroke Colors

Each button variant uses a border ~20% darker than its fill:

| Variant | Fill (token) | Stroke Color |
|---------|-------------|--------------|
| Primary | `primary` | `{25, 168, 153, 255}` (#19A899 = primaryPressed) |
| Primary hover | `primaryHover` | `{27, 176, 161, 255}` (#1BB0A1) |
| Secondary | `secondary` | `{74, 61, 176, 255}` (#4A3DB0) |
| Secondary hover | `secondaryHover` | `{74, 61, 176, 255}` (#4A3DB0) |
| Danger | `error` | `{184, 50, 63, 255}` (#B8323F) |
| Danger hover | `errorHover` | `{184, 50, 63, 255}` (#B8323F) |
| Success | `success` | `{56, 144, 90, 255}` (#38905A) |
| Disabled (all) | `disabled` | `border` token |

---

## Component State Tokens

### Checkbox

| Token | Value | Usage |
|-------|-------|-------|
| `checkedBgColor` | `{33, 189, 174, 255}` | Box fill when checked (= primary) |
| `checkedBorderColor` | `{27, 176, 161, 255}` | Box border when checked (#1BB0A1) |
| `checkmarkColor` | `{255, 255, 255, 255}` | Checkmark icon (white) |
| `hoverBorderColor` | `{33, 189, 174, 255}` | Box border on hover (= primary) |

### Toggle

| Token | Value | Usage |
|-------|-------|-------|
| `thumbColor` | `{160, 160, 192, 255}` | Thumb when off (gray, textSecondary) |
| `thumbCheckedColor` | `{255, 255, 255, 255}` | Thumb when on (white) |
| `thumbHoverColor` | `{240, 240, 240, 255}` | Thumb on hover (brighter, text) |
| `trackHoverBgColor` | `{37, 37, 80, 255}` | Track bg on hover (surfaceHover) |
| `trackHoverBorderColor` | `{33, 189, 174, 255}` | Track border on hover (primary) |

### Slider

| Token | Value | Usage |
|-------|-------|-------|
| `trackBgColor` | `{27, 27, 58, 255}` | Track background (surface) |
| `trackFillColor` | `{33, 189, 174, 255}` | Filled track portion (primary) |
| `thumbColor` | `{33, 189, 174, 255}` | Thumb fill (primary) |
| `thumbBorderWidth` | `2` | Thumb border width |
| `thumbBorderColor` | `{27, 176, 161, 255}` | Thumb border (#1BB0A1) |

### Tabs

| Token | Value | Usage |
|-------|-------|-------|
| `activeBorderColor` | `{33, 189, 174, 255}` | Line indicator + pills active border (primary) |
| `activeFontWeight` | `"700"` | Bold active tab text (all variants) |
| `inactiveTextColor` | `{160, 160, 192, 255}` | Inactive tab text (textSecondary) |
| `tabGap` | `8` | Gap between pills tabs |
| `enclosedPadding` | `0` | No internal padding in enclosed container |
| `variantActiveBgColor.enclosed` | `{37, 37, 80, 255}` | Enclosed active tab bg (surfaceHover) |
| `variantActiveBorderColor.pills` | `{27, 176, 161, 255}` | Pills active border (#1BB0A1, darker primary) |
| `variantBoxShadow.pills` | `{{x=2,y=2,blur=0,color={10,10,26,204}}}` | Pills active tab drop shadow |

### Accordion

| Token | Value | Usage |
|-------|-------|-------|
| `headerExpandedBgColor` | `{37, 37, 80, 255}` | Expanded header bg (surfaceHover) |
| `collapsedTextColor` | `{160, 160, 192, 255}` | Collapsed header text (textSecondary) |
| `contentBgColor` | `{15, 15, 35, 32}` | Content area bg (background 12% alpha) |

### Table

| Token | Value | Usage |
|-------|-------|-------|
| `headerBgColor` | `{37, 37, 80, 255}` | Header row bg (surfaceHover) |
| `rowOddBgColor` | `{27, 27, 58, 255}` | Odd row bg (surface) |
| `rowEvenBgColor` | `{27, 27, 58, 128}` | Even row bg (surface 50% alpha) |
| `rowHoverBgColor` | `{37, 213, 194, 16}` | Hover row bg (primary-ish 6% alpha) |

### Menu

| Token | Value | Usage |
|-------|-------|-------|
| `itemHoverBgColor` | `{37, 213, 194, 24}` | Item hover bg (primary-ish 9% alpha) |
| `itemHoverTextColor` | `{33, 189, 174, 255}` | Item hover text (primary) |
| `itemHoverFontWeight` | `"600"` | Semi-bold on hover |
| `itemHoverInset` | `0` | No inset on hover highlight |
| `itemHoverRadius` | `0` | Sharp corners on hover highlight |
| `itemVerticalInset` | `0` | Flush to top/bottom edges |

### List

| Token | Value | Usage |
|-------|-------|-------|
| `itemSelectedBgColor` | `{37, 213, 194, 16}` | Selected item bg (primary-ish 6% alpha) |
| `itemSelectedTextColor` | `{33, 189, 174, 255}` | Selected item text (primary) |

### Pagination

| Token | Value | Usage |
|-------|-------|-------|
| `buttonBorderWidth` | `2` | Per-button border (not container) |
| `hoverBorderColor` | `{33, 189, 174, 255}` | Hover border (primary) |
| `activeBgColor` | `{33, 189, 174, 255}` | Active page bg (primary) |
| `activeBorderColor` | `{25, 168, 153, 255}` | Active page border (primaryPressed) |

### Modal

| Token | Value | Usage |
|-------|-------|-------|
| `headerBgColor` | `{20, 20, 46, 255}` | Header bg (#14142E, darker than surface) |
| `headerBorderWidth` | `2` | Header bottom separator |
| `headerFullWidthBorder` | `true` | Separator extends full width |
| `footerBorderWidth` | `2` | Footer top separator |
| `footerFullWidthBorder` | `true` | Separator extends full width |
| `contentPadding` | `16` | Content area padding |
| `footerPadding` | `{10, 16}` | Footer padding (vert 10px, horiz 16px) |

### Drawer

| Token | Value | Usage |
|-------|-------|-------|
| `contentPadding` | `12` | Content area padding |
| `headerPadding` | `{0, 16}` | Header padding (no top/bottom, 16px sides) |

### FileUpload

| Token | Value | Usage |
|-------|-------|-------|
| `dropzoneBgColor` | `{27, 27, 59, 255}` | Dropzone background (#1B1B3B) |
| `iconColor` | `{69, 170, 242, 255}` | Upload icon color (info blue) |

### Toast

| Token | Value | Usage |
|-------|-------|-------|
| `accentBarHeight` | `32` | Severity color bar height |
| `accentBarWidth` | `4` | Severity color bar width (thin vertical) |
| `accentBarInset` | `12` | Bar inset from edge (= padding) |
| `showIcon` | `false` | No severity icon |

### Tooltip

| Token | Value | Usage |
|-------|-------|-------|
| `tooltipBgColor` | `{30, 30, 58, 240}` | Background (#1E1E3AF0, semi-transparent) |

### Calendar / DatePicker / TimePicker / ColorPicker

Shared picker tokens:

| Token | Value | Usage |
|-------|-------|-------|
| `primaryColor` | `{33, 189, 174, 255}` | Active/selected accent (primary) |
| `selectedBgColor` | `{33, 189, 174, 32}` | Selected cell bg (primary 12% alpha) |
| `selectedBorderColor` | `{33, 189, 174, 255}` | Selected cell border (primary) |
| `selectedBorderWidth` | `2` | Selected cell border width |
| `selectedTextColor` | `{69, 170, 242, 255}` | Selected text (info blue, Calendar/DatePicker) |
| `navBtnBgColor` | `{30, 50, 75, 255}` | Nav button bg (dark blue tint) |
| `navBtnRadius` | `2` | Nav button corner radius |
| `popupBgColor` | `{27, 27, 58, 255}` | Popup/panel bg (surface) |
| `fieldBorderColor` | `{58, 58, 107, 255}` | Field border when closed (~border) |
| `fieldBgColor` | `{27, 27, 58, 255}` | Field bg when closed (surface) |

### Dropdown

| Token | Value | Usage |
|-------|-------|-------|
| `arrowColor` | `{33, 189, 174, 255}` | Arrow ▼ color (primary) |
| `itemHoverBgColor` | `{37, 213, 194, 24}` | Item hover bg (primary-ish 9% alpha) |
| `itemHoverTextColor` | `{33, 189, 174, 255}` | Item hover text (primary) |
| `itemSelectedTextColor` | `{33, 189, 174, 255}` | Selected item text (primary) |
| `selectedFontWeight` | `"600"` | Semi-bold selected item |
| `itemHoverInset` | `0` | No inset on hover highlight |
| `itemHoverRadius` | `0` | Sharp corners on hover highlight |
| `itemVerticalInset` | `0` | Flush to top/bottom edges |

### Carousel

| Token | Value | Usage |
|-------|-------|-------|
| `arrowBgColor` | `{49, 49, 99, 255}` | Arrow button bg (#313163) |
| `arrowHoverBgColor` | `{50, 50, 126, 255}` | Arrow button hover bg (#32327E) |
| `dotColor` | `{108, 114, 135, 255}` | Inactive dot color (#6C7287) |

### Timeline

| Token | Value | Usage |
|-------|-------|-------|
| `dotColor` | `{32, 189, 174, 255}` | Timeline dot (primary) |
| `lineColor` | `{38, 178, 167, 255}` | Connector line (#26B2A7) |
| `hoverTitleColor` | `{32, 189, 174, 255}` | Hover title color (primary) |

### Tree

| Token | Value | Usage |
|-------|-------|-------|
| `backgroundColor` | `{27, 27, 58, 255}` | Container bg (surface) |
| `padding` | `{18, 22}` | Container padding (vert 18, horiz 22) |
| `nodeGap` | `16` | Gap between tree nodes |
| `indent` | `22` | Child node left indent |
| `hoverBgColor` | `{47, 47, 88, 255}` | Row hover bg (#2F2F58) |
| `iconColor` | `{108, 92, 231, 255}` | Folder icon color (secondary/purple) |
| `iconSize` | `22` | Icon font size |
| `folderIcon` | `"📁"` | Collapsed folder emoji |
| `folderOpenIcon` | `"📂"` | Expanded folder emoji |
| `leafIcon` | `"📄"` | Leaf node emoji |
| `hoverRadius` | `2` | Hover highlight corner radius |

### Breadcrumb

| Token | Value | Usage |
|-------|-------|-------|
| `linkColor` | `{33, 189, 174, 255}` | Link text color (primary) |
| `separatorColor` | `{160, 160, 192, 255}` | Separator "/" color (textSecondary) |
| `currentColor` | `{240, 240, 240, 255}` | Current page text color (text) |

### ColorPicker (additional)

| Token | Value | Usage |
|-------|-------|-------|
| `sliderRadius` | `0` | Hue/alpha slider track radius (sharp) |
| `presetRadius` | `2` | Preset color swatch radius |

---

## Spacing Tokens

Usage: `UI.Theme.Spacing("name")` -> `number`

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4 | Icon-text gap, tight spacing |
| `sm` | 8 | Component internal padding, list item gap |
| `md` | 12 | Standard gap within sections |
| `lg` | 16 | Section padding |
| `xl` | 24 | Section-to-section spacing |
| `xxl` | 32 | Page-level spacing |

---

## Radius Tokens

Usage: `UI.Theme.Radius("name")` -> `number`

Most components use `borderRadius = 0` (sharp corners via `componentDefaults`). Radius tokens are for picker/calendar sub-elements only.

| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 2 | Calendar nav buttons, selected date cells |
| `md` | 2 | Picker handles, color swatches |
| `lg` | 4 | Avatar rounded variant |
| `xl` | 4 | Larger rounded elements |
| `full` | 0 | Pill shapes not used in pixel-art |

---

## Font Sizes

Usage: `UI.Theme.FontSizeOf("name")` -> `number` (returns converted render value)

| Token | pt Value | Design px | Usage |
|-------|----------|-----------|-------|
| `display` | 21 | 28px | Display headings (pixel font, large) |
| `headline` | 16.5 | 22px | Page titles |
| `title` | 13.5 | 18px | Section titles |
| `subtitle` | 12 | 16px | Subtitles |
| `body` | 10.5 | 14px | Standard body text, button text |
| `bodySmall` | 9 | 12px | Small body text |
| `caption` | 7.5 | 10px | Captions, auxiliary text |

**Custom font size conversion:** `pt = px * 0.75` (i.e., `px * 72/96`)

### Font Families

| Family | Font | Usage |
|--------|------|-------|
| `"sans"` | Fusion Pixel 12px Proportional | Body text, buttons, labels — all general use |
| `"mono"` | Fusion Pixel 12px Monospaced | Code, numerical data, coordinates, timers |

**Note:** Pixel fonts have no bold variant. `fontWeight = "bold"` uses the same font file. Use `fontWeight = "bold"` for semantic emphasis (renders identically but conveys intent).

---

## HUD Colors (hardcoded)

| Name | Value | Usage |
|------|-------|-------|
| HP | `{255, 71, 87, 255}` | Health bar (bright red) |
| MP | `{69, 170, 242, 255}` | Mana bar (bright blue) |
| Stamina | `{255, 217, 61, 255}` | Stamina bar (bright yellow) |
| XP | `{80, 200, 120, 255}` | Experience bar (bright green) |

## Rarity Colors (hardcoded)

| Rarity | Value | Usage |
|--------|-------|-------|
| Common | `{96, 96, 128, 255}` | Gray — default item border |
| Uncommon | `{80, 200, 120, 255}` | Green |
| Rare | `{69, 170, 242, 255}` | Blue |
| Epic | `{108, 92, 231, 255}` | Purple |
| Legendary | `{255, 159, 67, 255}` | Orange |
