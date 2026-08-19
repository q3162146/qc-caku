# Astroon Component Index

## Built-in Widgets

All built-in Widget APIs (Button, Checkbox, Toggle, Slider, TextField, Card, Badge, Chip, Alert, Avatar, ProgressBar, Tabs, Menu, Stepper, Breadcrumb, Pagination, Toast, Tooltip, Modal, Drawer, Popover, Dropdown, Table, List, Accordion, Rating, etc.) are documented in the engine source code via EmmyLua annotations.

Read the Widget source files in `urhox-libs/UI/Widgets/` for props reference.

All visual properties (borderRadius, borderWidth, boxShadow) are configured via theme, NOT per-component. Do NOT hand-write these props.

**Exception**: Button `backgroundGradient` and `textColor` must be set per-variant for the full Astroon cosmic look. See SKILL.md "Button Gradient Formula" section.

## Game Composition Components

Game-specific composition components (StatBar, ItemSlot, InventoryGrid, DialogBox, QuestTracker, etc.) are planned for future expansion. These are composed from built-in Widgets and will be documented here when ready.
