-- ====================================================================
-- ui/UIManager.lua
-- UI 管理器 - 统一管理游戏 UI 组件
-- 使用 urhox-libs/UI 系统
-- ====================================================================

local UI = require("urhox-libs/UI/init")

---@class UIManager
local UIManager = {}
UIManager.__index = UIManager

---创建 UI 管理器
---@return table UIManager实例
function UIManager.new()
    local self = setmetatable({}, UIManager)
    self.root = nil
    self.hotbar = nil
    self.debugOverlay = nil
    self.initialized = false
    self.gameMode = "Standalone"  -- 默认单机模式
    return self
end

---设置游戏模式
---@param mode string "Standalone" | "Client" | "Server"
function UIManager:setGameMode(mode)
    self.gameMode = mode
end

---初始化 UIManager
---注意: UI.Init() 已在 GameSystems:initUIFramework() 中调用（LoadingScreen 需要）
function UIManager:init()
    self.initialized = true
    print("[UIManager] UI manager initialized")
end

---设置物品栏组件
---@param hotbar table Hotbar实例
function UIManager:setHotbar(hotbar)
    self.hotbar = hotbar
end

---设置调试覆盖层组件
---@param debugOverlay table DebugOverlay实例
function UIManager:setDebugOverlay(debugOverlay)
    self.debugOverlay = debugOverlay
end

---构建 UI 树
function UIManager:build()
    if not self.initialized then
        error("[UIManager] Must call init() before build()")
    end

    -- 创建根容器（全屏）
    self.root = UI.Panel {
        id = "ui_root",
        width = "100%",
        height = "100%",
        position = "relative",
        pointerEvents = "box-none",  -- 允许点击穿透到游戏

        -- 准星 (屏幕中央) - 精致的十字准星
        UI.Panel {
            id = "crosshair_container",
            position = "absolute",
            top = 0,
            left = 0,
            right = 0,
            bottom = 0,
            justifyContent = "center",
            alignItems = "center",
            pointerEvents = "none",
            
            -- 准星容器
            UI.Panel {
                width = 20,
                height = 20,
                justifyContent = "center",
                alignItems = "center",
                
                -- 水平线
                UI.Panel {
                    position = "absolute",
                    width = 24,
                    height = 3,
                    backgroundColor = {200, 200, 200, 200},
                    borderRadius = 1,
                },
                
                -- 垂直线
                UI.Panel {
                    position = "absolute",
                    width = 3,
                    height = 24,
                    backgroundColor = {200, 200, 200, 200},
                    borderRadius = 1,
                },
                
                -- 中心点
                UI.Panel {
                    position = "absolute",
                    width = 4,
                    height = 4,
                    backgroundColor = {255, 255, 255, 255},
                    borderRadius = 2,
                },
            },
        },
        
        -- 说明文本 (右上角，半透明)
        UI.Panel {
            id = "instructions_container",
            position = "absolute",
            top = 12,
            right = 12,
            pointerEvents = "none",

            UI.Label {
                id = "instructions",
                text = "WASD: Move | Space: Jump | LMB: Destroy | RMB: Place",
                fontSize = 10,
                fontColor = {255, 255, 255, 140},
                textAlign = "right",
            },
        },

        -- 联机状态指示器 (左上角) - 仅联机模式显示
        -- 单机模式：不显示任何标记
        -- 联机客户端：绿色圆点（表示在线）
        -- 服务器：橙色圆点（表示托管中）
        self.gameMode ~= "Standalone" and UI.Panel {
            id = "online_indicator",
            position = "absolute",
            top = 14,
            left = 14,
            pointerEvents = "none",
            
            -- 外圈光晕（半透明）
            UI.Panel {
                position = "absolute",
                width = 16,
                height = 16,
                borderRadius = 8,
                backgroundColor = self.gameMode == "Client" 
                    and {80, 220, 120, 80}   -- 绿色光晕
                    or {255, 160, 80, 80},   -- 橙色光晕（服务器）
            },
            
            -- 内圈实心圆点
            UI.Panel {
                position = "absolute",
                top = 4,
                left = 4,
                width = 8,
                height = 8,
                borderRadius = 4,
                backgroundColor = self.gameMode == "Client"
                    and {80, 220, 120, 255}  -- 绿色实心
                    or {255, 160, 80, 255},  -- 橙色实心（服务器）
            },
        } or nil,
    }
    
    -- 添加调试覆盖层
    if self.debugOverlay then
        local debugWidget = self.debugOverlay:build()
        if debugWidget then
            self.root:AddChild(debugWidget)
        end
    end
    
    -- 添加物品栏
    if self.hotbar then
        local hotbarWidget = self.hotbar:build()
        if hotbarWidget then
            self.root:AddChild(hotbarWidget)
        end
    end
    
    -- 设置根 Widget
    UI.SetRoot(self.root)
    
    print("[UIManager] UI tree built successfully")
end

---更新 UI（每帧调用）
---@param timeStep number 时间步长
function UIManager:update(timeStep)
    -- 更新调试覆盖层
    if self.debugOverlay then
        self.debugOverlay:update()
    end

    -- 注意：UI.Update() 由 autoEvents 自动调用，无需手动调用
end

---显示/隐藏准星
---@param visible boolean
function UIManager:setCrosshairVisible(visible)
    local crosshair = self.root and self.root:FindById("crosshair_container")
    if crosshair then
        crosshair:SetVisible(visible)
    end
end

---显示/隐藏说明文本
---@param visible boolean
function UIManager:setInstructionsVisible(visible)
    local instructions = self.root and self.root:FindById("instructions_container")
    if instructions then
        instructions:SetVisible(visible)
    end
end

---获取根 Widget
---@return Widget|nil
function UIManager:getRoot()
    return self.root
end

---获取物品栏
---@return table|nil
function UIManager:getHotbar()
    return self.hotbar
end

---获取调试覆盖层
---@return table|nil
function UIManager:getDebugOverlay()
    return self.debugOverlay
end

---销毁 UI
function UIManager:destroy()
    if self.root then
        self.root:Destroy()
        self.root = nil
    end
    self.hotbar = nil
    self.debugOverlay = nil
    UI.Shutdown()
    self.initialized = false
    print("[UIManager] UI destroyed")
end

return UIManager
