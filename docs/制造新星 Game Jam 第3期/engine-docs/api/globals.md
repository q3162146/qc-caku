# Global Functions, Properties and Constants

## Global Properties

Available global objects (accessible without declaration):

```lua
---@type Audio
audio
---@type ResourceCache
cache
---@type Console
console
---@type Context
context
---@type Engine
engine
---@type FileSystem
fileSystem
---@type Graphics
graphics
---@type Input
input
---@type Localization
localization
---@type Log
log
---@type Network
network
---@type Renderer
renderer
---@type Time
time
---@type UI
ui
```

---

各全局对象的类型定义在对应的 `.d.lua` 文件底部（如 `.emmylua/Audio.d.lua` 声明 `audio`，`.emmylua/Input.d.lua` 声明 `input`）。
