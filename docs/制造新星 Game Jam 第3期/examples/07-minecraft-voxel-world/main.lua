-- ====================================================================
-- Main.lua
-- 游戏入口 - 判断 Server/Client/Standalone 模式并加载对应模块
-- ====================================================================

local Module = nil

function Start()
    if IsServerMode() then
        -- 服务器模式（启动时带 -server 参数）
        print("[Main] Starting in SERVER mode")
        Module = require("network.Server")
    elseif IsNetworkMode() then
        -- 联网客户端模式（IsNetworkMode() = true 且 IsClientMode() = true）
        print("[Main] Starting in CLIENT mode")
        Module = require("network.Client")
    else
        -- 单机模式（IsNetworkMode() = false）
        print("[Main] Starting in STANDALONE mode")
        Module = require("network.Standalone")
    end
    Module.Start()
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end
