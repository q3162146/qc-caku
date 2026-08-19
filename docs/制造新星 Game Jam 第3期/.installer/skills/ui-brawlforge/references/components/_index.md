# BrawlForge Component Index

## Built-in Widgets

All built-in Widget APIs (Button, Checkbox, Toggle, Slider, TextField, Card, Badge, Chip, Alert, Avatar, ProgressBar, Tabs, Menu, Stepper, Breadcrumb, Pagination, Toast, Tooltip, Modal, Drawer, Popover, Dropdown, Table, List, Accordion, Rating, DatePicker, TimePicker, Calendar, ColorPicker, Timeline, Tree, Carousel, FileUpload, etc.) are documented in the engine source code via EmmyLua annotations.

Read the Widget source files in `urhox-libs/UI/Widgets/` for props reference.

All visual properties (borderRadius, borderWidth, boxShadow) are configured via theme, NOT per-component. Do NOT hand-write these props.

## BrawlForge-Specific Visual Notes

### Bottom Accent Bars
Buttons and panel headers (Modal, Accordion, Toast) feature a darker bottom accent border — a signature BrawlForge visual. This is handled automatically by the theme via decorations (Button) and headerBorderWidth (Modal/Table).

### Tooltip Special Color
Tooltips use a gold/orange background (`{254,160,2}`) with an orange-red bottom border — the only component that breaks from the blue surface palette.

### Accordion Purple Headers
Expanded accordion headers use vivid purple (`{157,0,198}`) from the secondary color family, creating visual contrast against the blue surface stack.

### List Warm Selection
Selected list items use warm orange (`{255,146,3}`) — styled for RPG inventory item highlighting.

## Game Composition Components

Game-specific composition components (StatBar, ItemSlot, InventoryGrid, DialogBox, QuestTracker, etc.) are planned for future expansion. These are composed from built-in Widgets and will be documented here when ready.
