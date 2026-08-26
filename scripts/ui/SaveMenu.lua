-- ============================================================================
-- ui/SaveMenu.lua
-- 存档/读档菜单：把 F8/F9 调试键做成正式界面（保存到 slot1 / 读档续播）。
-- 白模阶段：单槽 slot1；后续可扩展多槽。S9 前随调试入口一并清理或并入正式存档系统。
-- ============================================================================

local UI = require "urhox-libs/UI"
local PlayerData = require "config.PlayerData"
local FlowController = require "flow.FlowController"
local MediaPlayer = require "media.MediaPlayer"

local SaveMenu = {}

---@type table|nil
local panel_ = nil
---@type table|nil
local statusLabel_ = nil
---@type function|nil
local onLoaded_ = nil   -- 读档成功后的回调（供 main 记住，避免与 MediaPlayer 相互依赖）

--- 读取存档并返回描述（用于状态显示）
---@return string
local function slotDescription()
    local loaded = PlayerData.Load()
    if loaded ~= nil and type(loaded.mediaPos) == "table"
        and loaded.mediaPos.node ~= nil and loaded.mediaPos.node ~= "" then
        local node = tostring(loaded.mediaPos.node)
        local t = loaded.mediaPos.timeSec
        if type(t) == "number" and t > 0 then
            return "存档：段落 " .. node .. " @ " .. string.format("%.1f", t) .. "s"
        end
        return "存档：段落 " .. node
    end
    return "暂无存档"
end

local function refreshStatus()
    if statusLabel_ ~= nil then
        statusLabel_:SetText(slotDescription())
    end
end

local function doSave()
    FlowController.Persist()
    print("[SaveMenu] 已保存当前进度到 slot1")
    refreshStatus()
end

local function doLoad()
    local loaded = PlayerData.Load()
    if loaded == nil then
        print("[SaveMenu] 读档失败：无本地存档")
        return
    end
    -- 与 F9 一致：停媒体会话 → 重建流程数据 → 尝试续档，失败则新开
    MediaPlayer.Stop(true)
    FlowController.Init(loaded)
    if not FlowController.Resume() then
        FlowController.Start()
    end
    print("[SaveMenu] 已读档并续播")
    SaveMenu.Close()
    if onLoaded_ ~= nil then
        onLoaded_()
    end
end

---@return boolean 是否已创建
function SaveMenu.Create(root)
    if panel_ ~= nil then return true end
    if root == nil then return false end

    -- 菜单入口按钮（右上偏下，避开 TapTap 浮层与左上角调试按钮；S9 前保留）
    local menuBtn = UI.Button {
        text = "菜单",
        variant = "secondary",
        position = "absolute",
        top = 120,
        right = 12,
        width = 64,
        height = 36,
        fontSize = 14,
        onClick = function() SaveMenu.Open() end,
    }
    root:AddChild(menuBtn)

    -- 存档面板（居中，带遮罩）
    panel_ = UI.Panel {
        id = "saveMenuPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 10, 10, 14, 180 },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 95,
        visible = false,
    }
    local card = UI.Panel {
        width = "82%",
        maxWidth = 420,
        backgroundColor = { 28, 28, 38, 245 },
        borderRadius = 14,
        paddingH = 18,
        paddingV = 18,
        flexDirection = "column",
        gap = 12,
    }
    card:AddChild(UI.Label { text = "存档 / 读档", fontSize = 20, fontColor = { 246, 241, 231, 255 } })

    statusLabel_ = UI.Label {
        text = "暂无存档",
        fontSize = 14,
        fontColor = { 200, 200, 210, 255 },
    }
    card:AddChild(statusLabel_)

    card:AddChild(UI.Button {
        text = "保存",
        variant = "primary",
        width = "100%",
        height = 48,
        onClick = function() doSave() end,
    })
    card:AddChild(UI.Button {
        text = "读档",
        variant = "secondary",
        width = "100%",
        height = 48,
        onClick = function() doLoad() end,
    })
    card:AddChild(UI.Button {
        text = "返回",
        variant = "ghost",
        width = "100%",
        height = 40,
        onClick = function() SaveMenu.Close() end,
    })
    panel_:AddChild(card)
    root:AddChild(panel_)

    print("[SaveMenu] 已创建存档/读档菜单（S9 前保留）")
    return true
end

function SaveMenu.Open()
    if panel_ == nil then return end
    refreshStatus()
    panel_:SetVisible(true)
end

function SaveMenu.Close()
    if panel_ ~= nil then
        panel_:SetVisible(false)
    end
end

--- 读档成功回调（main 可选注入，用于关闭对话/场景等）
---@param cb function|nil
function SaveMenu.SetOnLoaded(cb)
    onLoaded_ = cb
end

---@return boolean
function SaveMenu.IsOpen()
    return panel_ ~= nil and panel_:GetVisible() == true
end

return SaveMenu