-- InputManager.lua
-- 项目输入抽象：统一初始化平台触摸输入，并封装键盘、鼠标和按键查询。

local PlatformInputManager = require "urhox-libs.Platform.InputManager"

local InputManager = {}

---@type boolean
local initialized_ = false

---@param options? table
function InputManager.Initialize(options)
    if initialized_ then
        return
    end
    PlatformInputManager.Initialize(options or {})
    initialized_ = true
    print("[InputManager] 输入抽象已初始化")
end

function InputManager.Shutdown()
    if not initialized_ then
        return
    end
    PlatformInputManager.DisableTouchInput()
    initialized_ = false
    print("[InputManager] 输入抽象已关闭")
end

---@param key Key
---@return boolean
function InputManager.IsKeyDown(key)
    return input:GetKeyDown(key)
end

---@param key Key
---@return boolean
function InputManager.IsKeyPress(key)
    return input:GetKeyPress(key)
end

---@return number x, number y
function InputManager.GetMouseDelta()
    return input.mouseMoveX, input.mouseMoveY
end

function InputManager.SetRelativeMouseMode()
    input:SetMouseMode(MM_RELATIVE)
end

---@param button MouseButton
---@return boolean
function InputManager.IsMouseButtonDown(button)
    return input:GetMouseButtonDown(button)
end

return InputManager
