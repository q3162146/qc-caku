# PixelForge Component Index

## Built-in Widgets

All built-in Widget APIs (Button, Checkbox, Toggle, Slider, TextField, Card, Badge, Chip, Alert, Avatar, ProgressBar, Tabs, Menu, Stepper, Breadcrumb, Pagination, Toast, Tooltip, Modal, Drawer, Popover, Dropdown, Table, List, Accordion, Rating, Calendar, DatePicker, TimePicker, ColorPicker, Carousel, Timeline, Tree, etc.) are documented in the engine source code via EmmyLua annotations.

Read the Widget source files in `urhox-libs/UI/Widgets/` for props reference.

All visual properties (borderRadius, borderWidth, boxShadow) are configured via theme, NOT per-component. Do NOT hand-write these props.

### Component-Specific Notes

| Component | Notes |
|-----------|-------|
| Avatar | Default `shape = "square"` via theme. Use `shape = "circle"` for round avatars. |
| Pagination | Use `shape = "square"` to match pixel-art style. |
| Card | Elevated variant has shadow, no border. Outlined has border, no shadow. Theme handles both. |
| Table | Default `variant = "striped"` via theme. Alternating row colors automatic. |
| Toast | No icon, thin 4px vertical accent bar on left. |
| Calendar/DatePicker | Selected date uses outlined style (tinted bg + border). Nav buttons have subtle 2px radius. |
| Tabs | Line variant uses bottom border indicator. Enclosed variant uses surfaceHover active bg. |

## Game Composition Components

Game-specific composition components (StatBar, ItemSlot, InventoryGrid, DialogBox, QuestTracker, etc.) are planned for future expansion. These are composed from built-in Widgets and will be documented here when ready.
