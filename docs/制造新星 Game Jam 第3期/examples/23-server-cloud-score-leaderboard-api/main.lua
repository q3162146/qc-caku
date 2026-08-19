-- ============================================================================
-- ServerScoreDemo - Main Entry
-- Demonstrates serverScore API: auto-tests on server, UI dashboard on client
-- Supports: Client / Server modes
-- ============================================================================

local Module = nil

function Start()
    if IsServerMode() then
        print("[Main] Starting in SERVER mode")
        Module = require("network.Server")
    elseif IsNetworkMode() then
        print("[Main] Starting in CLIENT mode")
        Module = require("network.Client")
    else
        print("[Main] ERROR: This demo requires network mode (server + client)")
        print("  Server: UrhoXServer.exe -headless -port=5053 -config=dev.json -game_url=...")
        print("  Client: UrhoXRuntime.exe NetworkMain.lua -server_address=127.0.0.1 -server_port=5053 ...")
    end

    if Module then
        Module.Start()
    end
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end
