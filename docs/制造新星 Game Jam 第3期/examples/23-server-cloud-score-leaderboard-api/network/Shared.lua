-- ============================================================================
-- Shared.lua - Shared Code for Server and Client
-- ============================================================================

local Shared = {}
local Settings = require("config.Settings")

Shared.Settings = Settings
Shared.EVENTS = Settings.EVENTS

-- ============================================================================
-- Register Remote Events
-- ============================================================================

function Shared.RegisterEvents()
    for _, eventName in pairs(Settings.EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

return Shared
