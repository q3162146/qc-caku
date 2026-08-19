# BrawlForge Theme Token Table

## Color Tokens

Usage: `UI.Theme.Color("tokenName")` -> `{R, G, B, A}`

### Core Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `primary` | `{31, 162, 255, 255}` | #1FA2FF | Bright cyan-blue — primary buttons, active states, links |
| `primaryHover` | `{70, 183, 255, 255}` | #46B7FF | Primary hover |
| `primaryPressed` | `{13, 126, 230, 255}` | #0D7EE6 | Primary pressed |
| `secondary` | `{214, 53, 255, 255}` | #D635FF | Vivid purple — secondary buttons, accents |
| `secondaryHover` | `{224, 97, 255, 255}` | #E061FF | Secondary hover |
| `secondaryPressed` | `{181, 35, 232, 255}` | #B523E8 | Secondary pressed |

### Background Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `background` | `{34, 89, 183, 255}` | #2259B7 | Page background (deep blue) |
| `surface` | `{33, 69, 138, 255}` | #21458A | Card/panel surface (darker blue) |
| `surfaceHover` | `{45, 102, 200, 255}` | #2D66C8 | Panel hover state |
| `disabled` | `{57, 71, 107, 255}` | #39476B | Disabled background |

### Text Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `text` | `{255, 255, 255, 255}` | #FFFFFF | Primary text (white) |
| `textSecondary` | `{213, 226, 255, 255}` | #D5E2FF | Secondary/description text (pale blue-white) |
| `textDisabled` | `{157, 166, 198, 255}` | #9DA6C6 | Disabled text |
| `disabledText` | `{139, 150, 184, 255}` | #8B96B8 | Disabled text (alias) |

### Border & Overlay

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `border` | `{10, 16, 32, 255}` | #0A1020 | Default border (deep black-blue) |
| `borderFocus` | `{111, 231, 255, 255}` | #6FE7FF | Focus state border (bright cyan glow) |
| `overlay` | `{7, 16, 28, 187}` | #07101CBB | Modal/drawer backdrop |

### Semantic Colors

| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `success` | `{67, 213, 44, 255}` | #43D52C | Bright green — success, healing, confirm |
| `successHover` | `{98, 232, 78, 255}` | #62E84E | Success hover |
| `warning` | `{255, 198, 26, 255}` | #FFC61A | Bright yellow — warning, caution, gold |
| `warningHover` | `{255, 215, 85, 255}` | #FFD755 | Warning hover |
| `error` | `{245, 50, 45, 255}` | #F5322D | Vivid red — error, danger, HP loss |
| `errorHover` | `{255, 90, 71, 255}` | #FF5A47 | Error hover |
| `info` | `{70, 199, 255, 255}` | #46C7FF | Light cyan — info, mana, hints |

### Accent Colors (hardcoded, not in Theme)

| Name | Value | Hex | Usage |
|------|-------|-----|-------|
| Accent (cyan) | `{61, 214, 232, 255}` | #3DD6E8 | Highlight accents, UI emphasis |
| Highlight | `{255, 255, 255, 85}` | #FFFFFF55 | Selection/hover highlight glow |
| Shadow | `{0, 0, 0, 64}` | #00000040 | Standard drop shadow |

### Button Bottom Accent Colors (hardcoded, per-variant)

Each button variant has a darker bottom accent bar:

| Variant | Default Accent | Hover Accent | Pressed Accent |
|---------|---------------|--------------|----------------|
| Primary | `{27, 115, 227}` | `{43, 143, 240}` | `{8, 79, 146}` |
| Secondary | `{142, 45, 226}` | `{163, 71, 244}` | `{101, 16, 171}` |
| Danger | `{169, 27, 23}` | `{196, 42, 38}` | `{132, 17, 14}` |
| Success | `{35, 116, 24}` | `{53, 181, 33}` | `{22, 111, 9}` |

### HUD Colors (hardcoded)

| Name | Value | Hex | Usage |
|------|-------|-----|-------|
| HP | `{255, 77, 77, 255}` | #FF4D4D | Health bar (vivid red) |
| MP | `{52, 185, 255, 255}` | #34B9FF | Mana bar (bright blue) |
| Stamina | `{255, 211, 56, 255}` | #FFD338 | Stamina bar (gold) |
| XP | `{73, 217, 75, 255}` | #49D94B | Experience bar (green) |

### Rarity Colors (hardcoded)

| Rarity | Value | Hex | Usage |
|--------|-------|-----|-------|
| Common | `{111, 120, 151, 255}` | #6F7897 | Gray-blue — default items |
| Uncommon | `{72, 217, 57, 255}` | #48D939 | Green — improved items |
| Rare | `{38, 182, 255, 255}` | #26B6FF | Blue — rare items |
| Epic | `{193, 60, 255, 255}` | #C13CFF | Purple — epic items |
| Legendary | `{255, 163, 24, 255}` | #FFA318 | Orange-gold — legendary items |

---

## Spacing Tokens

Usage: `UI.Theme.Spacing("name")` -> `number`

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4 | Icon-text gap, tight spacing |
| `sm` | 8 | Component internal padding |
| `md` | 12 | Standard gap within sections |
| `lg` | 16 | Section padding |
| `xl` | 24 | Section-to-section spacing |
| `xxl` | 32 | Page-level spacing |

---

## Radius Tokens

Usage: `UI.Theme.Radius("name")` -> `number`

| Token | Value | Usage |
|-------|-------|-------|
| `none` | 0 | **Default for all controls** — sharp HUD edges |
| `sm` | 4 | Subtle rounding (slider tracks, color picker elements) |
| `md` | 6 | Medium rounding |
| `lg` | 10 | Larger panels (rarely used) |
| `xl` | 14 | Extra large panels |
| `full` | 9999 | Pill/circle shapes (avatars, color cursors) |

**Key design rule:** Interactive controls (buttons, text fields, toggles, checkboxes) always use `borderRadius = 0`. Only decorative elements (avatars, color picker cursors) use non-zero radius.

---

## Font Sizes

Usage: `UI.Theme.FontSizeOf("name")` -> `number` (returns converted render value)

| Token | pt Value | Design px | Usage |
|-------|----------|-----------|-------|
| `display` | 18 | 24px | Large display headings |
| `headline` | 15 | 20px | Page titles, button text |
| `title` | 13.5 | 18px | Section titles, nav tabs |
| `subtitle` | 12 | 16px | Subtitles, card titles |
| `bodyLarge` | 12 | 16px | Large body, labels |
| `body` | 10.5 | 14px | Standard body text |
| `bodySmall` | 9 | 12px | Small body, captions |
| `small` | 9 | 12px | Small text |
| `caption` | 7.5 | 10px | Tiny text, badges |

**Custom font size conversion:** `pt = px * 0.75` (i.e., `px * 72/96`)

### Font Families

| Family | Font | Usage |
|--------|------|-------|
| `"sans"` | Noto Sans SC | All UI text — always used with bold weight |

**Important:** All text in BrawlForge uses bold weight. There is no light or regular weight text in this theme.
