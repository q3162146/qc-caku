-- ====================================================================
-- player/PlayerScript.lua
-- 网络玩家生命周期管理（ScriptObject）
-- 职责：角色判定 + 创建 Player/PlayerController 实例
-- ====================================================================

---@class _G
---@field world World|nil 单机模式全局 World 实例

local Player = require("player.Player")
local PlayerController = require("player.PlayerController")

-- 变量名常量（与 network/Shared.lua 保持一致）
local VARS = {
    PLAYER_ID = "PlayerId",
}

---@class PlayerScript : LuaScriptObject
---@field player Player|nil
---@field controller PlayerController|nil
---@field isLocal boolean
---@field world World|nil
PlayerScript = ScriptObject()

function PlayerScript:Start()
    self.player = nil
    self.controller = nil
    self.isLocal = false
    self.world = nil
end

function PlayerScript:DelayedStart()
    -- 判断角色
    self.isLocal = self:DetermineIsLocal()

    -- 创建 Player 实例
    self.player = Player.fromNode(self.node, self.isLocal)

    -- 需要控制器的情况：服务器、单机、联网客户端本地玩家
    local needController = IsServerMode() or not IsNetworkMode() or self.isLocal
    if needController then
        -- 获取 world 引用
        self.world = self:GetWorld()
        if self.world then
            self.controller = PlayerController.new(self.player, self.world)
        end
    end

    -- 本地玩家：设置主相机（仅单机模式）
    -- 网络模式下，Client.lua 已经创建并管理相机，不需要在这里设置
    if self.isLocal and not IsNetworkMode() and self.player:getCamera() then
        local viewport = renderer:GetViewport(0)
        if viewport then
            viewport.camera = self.player:getCamera()
        end
    end

    print("[PlayerScript] Created: isLocal=" .. tostring(self.isLocal) ..
          ", hasController=" .. tostring(self.controller ~= nil))
end

---判断是否为本地玩家
---@return boolean
function PlayerScript:DetermineIsLocal()
    if IsServerMode() then
        return false  -- 服务器没有"本地玩家"
    elseif not IsNetworkMode() then
        return true   -- 单机：唯一玩家就是本地
    else
        -- 联网客户端：比较 PlayerID
        local playerIdVar = self.node:GetVar(VARS.PLAYER_ID)
        local localIdVar = self.node.scene:GetVar("LocalPlayerID")

        if playerIdVar:IsEmpty() or localIdVar:IsEmpty() then
            print("[PlayerScript] Warning: PlayerID or LocalPlayerID not set")
            return false
        end

        return playerIdVar:GetInt() == localIdVar:GetInt()
    end
end

---获取 World 引用
---@return table|nil
function PlayerScript:GetWorld()
    -- 优先从场景变量获取
    local worldVar = self.node.scene:GetVar("World")
    if worldVar and not worldVar:IsEmpty() then
        return worldVar:GetPtr()
    end

    -- 单机模式：尝试从全局获取（兼容现有代码）
    if not IsNetworkMode() and _G.world then
        return _G.world
    end

    print("[PlayerScript] Warning: World not found")
    return nil
end

function PlayerScript:Update(timeStep)
    if self.player then
        self.player:update(timeStep)
    end
end

function PlayerScript:FixedUpdate(timeStep)
    if self.controller then
        self.controller:updateMovement(timeStep)
    end
end

---获取 Player 实例
---@return table|nil
function PlayerScript:GetPlayer()
    return self.player
end

---获取 PlayerController 实例
---@return table|nil
function PlayerScript:GetController()
    return self.controller
end
