-- ============================================================================
-- Client.lua - ServerScoreDemo Client (urhox-libs/UI)
--
-- Pure UI client:
--   - Displays score panel, leaderboard, and API test results
--   - Buttons to add coins/kills via remote events
--   - No 3D scene, no movement, no camera
-- ============================================================================

local Client = {}
local Shared = require("network.Shared")
local UI = require("urhox-libs/UI")

require "LuaScripts/Utilities/Sample"

local Settings = Shared.Settings
local EVENTS = Shared.EVENTS

-- ============================================================================
-- State
-- ============================================================================

local myScores_ = { coins = 0, kills = 0 }
local myUserId_ = 0

-- UI widget references (for dynamic updates)
local coinsLabel_ = nil
local killsLabel_ = nil
local leaderboardPanel_ = nil
local testSummaryLabel_ = nil
local testResultsPanel_ = nil

-- ============================================================================
-- Entry
-- ============================================================================

function Client.Start()
    SampleStart()

    -- Minimal scene for network connection
    local scene = Scene()
    scene:CreateComponent("Octree", LOCAL)
    local serverConn = network:GetServerConnection()
    if serverConn then
        serverConn.scene = scene
    end

    -- Init UI
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    local root = BuildUI()
    UI.SetRoot(root)

    -- Register network events
    Shared.RegisterEvents()
    SubscribeToEvent(EVENTS.SCORE_UPDATE, "HandleScoreUpdate")
    SubscribeToEvent(EVENTS.LEADERBOARD, "HandleLeaderboard")
    SubscribeToEvent(EVENTS.TEST_RESULTS, "HandleTestResults")

    -- Tell server we're ready
    if serverConn then
        serverConn:SendRemoteEvent(EVENTS.CLIENT_READY, true)
    end

    print("[Client] ServerScoreDemo client started (UI mode)")
end

function Client.Stop()
    UI.Shutdown()
end

-- ============================================================================
-- UI Construction
-- ============================================================================

function BuildUI()
    -- Score labels (saved for dynamic updates)
    coinsLabel_ = UI.Label {
        text = "Coins: 0",
        fontSize = 16,
        fontColor = { 255, 215, 0, 255 },
    }

    killsLabel_ = UI.Label {
        text = "Kills: 0",
        fontSize = 16,
        fontColor = { 255, 100, 100, 255 },
    }

    -- Leaderboard container (children added dynamically)
    leaderboardPanel_ = UI.Panel {
        gap = 4,
        flexGrow = 1,
    }

    -- Test results
    testSummaryLabel_ = UI.Label {
        text = "Waiting for test results...",
        fontSize = 14,
        fontColor = { 180, 220, 255, 255 },
    }

    testResultsPanel_ = UI.Panel {
        gap = 2,
    }

    -- Root layout
    return UI.Panel {
        width = "100%",
        height = "100%",
        padding = 16,
        gap = 12,
        backgroundColor = { 30, 30, 40, 255 },
        children = {
            -- Title
            UI.Label {
                text = "ServerScore API Demo",
                fontSize = 22,
                fontWeight = "bold",
                fontColor = { 100, 200, 255, 255 },
                alignSelf = "center",
            },

            -- Middle area: scores (left) + leaderboard (right)
            UI.Panel {
                flexDirection = "row",
                flexGrow = 1,
                gap = 16,
                children = {
                    -- Left: My Scores + Buttons
                    UI.Panel {
                        width = "40%",
                        padding = 16,
                        gap = 10,
                        borderRadius = 8,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderWidth = 1,
                        borderColor = { 100, 200, 255, 100 },
                        children = {
                            UI.Label {
                                text = "MY SCORES",
                                fontSize = 16,
                                fontWeight = "bold",
                                fontColor = { 100, 200, 255, 255 },
                            },
                            coinsLabel_,
                            killsLabel_,
                            -- Buttons row
                            UI.Panel {
                                flexDirection = "row",
                                gap = 8,
                                marginTop = 8,
                                children = {
                                    UI.Button {
                                        text = "+Coin",
                                        variant = "primary",
                                        onClick = function(self)
                                            SendRemoteEvent(EVENTS.ADD_COIN)
                                        end,
                                    },
                                    UI.Button {
                                        text = "+Kill",
                                        variant = "danger",
                                        onClick = function(self)
                                            SendRemoteEvent(EVENTS.ADD_KILL)
                                        end,
                                    },
                                },
                            },
                            UI.Button {
                                text = "Refresh Board",
                                variant = "secondary",
                                onClick = function(self)
                                    SendRemoteEvent(EVENTS.REQUEST_SCORES)
                                end,
                            },
                        },
                    },

                    -- Right: Leaderboard
                    UI.Panel {
                        flexGrow = 1,
                        padding = 16,
                        gap = 8,
                        borderRadius = 8,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderWidth = 1,
                        borderColor = { 255, 215, 0, 100 },
                        children = {
                            UI.Label {
                                text = "LEADERBOARD",
                                fontSize = 16,
                                fontWeight = "bold",
                                fontColor = { 255, 215, 0, 255 },
                                alignSelf = "center",
                            },
                            leaderboardPanel_,
                        },
                    },
                },
            },

            -- Bottom: Test Results
            UI.Panel {
                padding = 12,
                gap = 6,
                borderRadius = 8,
                backgroundColor = { 0, 0, 0, 160 },
                borderWidth = 1,
                borderColor = { 100, 200, 100, 100 },
                maxHeight = 250,
                children = {
                    -- Header row
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = "API TEST RESULTS",
                                fontSize = 14,
                                fontWeight = "bold",
                                fontColor = { 180, 220, 255, 255 },
                            },
                            testSummaryLabel_,
                        },
                    },
                    -- Scrollable results list
                    UI.ScrollView {
                        flexGrow = 1,
                        flexShrink = 1,
                        children = {
                            testResultsPanel_,
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- Network Send
-- ============================================================================

function SendRemoteEvent(eventName)
    local serverConn = network:GetServerConnection()
    if serverConn then
        serverConn:SendRemoteEvent(eventName, true)
    end
end

-- ============================================================================
-- Network Event Handlers
-- ============================================================================

function HandleScoreUpdate(eventType, eventData)
    local userId = eventData["UserId"]:GetInt64()

    -- Dev mode: userId is auto-assigned by server (10001, 10002, ...),
    -- client doesn't know its own userId upfront, so we capture it from
    -- the first ScoreUpdate received (which the server sends on ClientReady).
    -- In production, userId would come from login/auth before connecting.
    if myUserId_ == 0 then
        myUserId_ = userId
    elseif userId ~= myUserId_ then
        return
    end

    myScores_.coins = eventData["Coins"]:GetInt()
    myScores_.kills = eventData["Kills"]:GetInt()

    if coinsLabel_ then
        coinsLabel_:SetText("Coins: " .. myScores_.coins)
    end
    if killsLabel_ then
        killsLabel_:SetText("Kills: " .. myScores_.kills)
    end
end

function HandleLeaderboard(eventType, eventData)
    local encoded = eventData["Board"]:GetString()

    if not leaderboardPanel_ then return end
    leaderboardPanel_:ClearChildren()

    if encoded == "" then
        leaderboardPanel_:AddChild(UI.Label {
            text = "No players yet...",
            fontSize = 13,
            fontColor = { 150, 150, 150, 200 },
        })
        return
    end

    local rank = 0
    for entry in string.gmatch(encoded, "([^,]+)") do
        local userId, coins = string.match(entry, "(%d+):(%d+)")
        if userId and coins then
            rank = rank + 1
            local rankColor = { 180, 180, 180, 200 }
            if rank == 1 then rankColor = { 255, 215, 0, 255 }      -- Gold
            elseif rank == 2 then rankColor = { 192, 192, 192, 255 } -- Silver
            elseif rank == 3 then rankColor = { 205, 127, 50, 255 }  -- Bronze
            end

            leaderboardPanel_:AddChild(UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                paddingHorizontal = 4,
                children = {
                    UI.Label {
                        text = "#" .. rank .. "  Player_" .. userId,
                        fontSize = 14,
                        fontColor = rankColor,
                    },
                    UI.Label {
                        text = coins,
                        fontSize = 14,
                        fontColor = { 255, 215, 0, 255 },
                    },
                },
            })
        end
    end
end

function HandleTestResults(eventType, eventData)
    local encoded = eventData["Results"]:GetString()

    if not testResultsPanel_ then return end
    testResultsPanel_:ClearChildren()

    if encoded == "" then return end

    local passed = 0
    local failed = 0

    for entry in string.gmatch(encoded, "([^;]+)") do
        local group, name, status, detail = string.match(entry, "([^|]+)|([^|]+)|([^|]+)|?(.*)")
        if group and name and status then
            local isPass = (status == "P")
            if isPass then passed = passed + 1 else failed = failed + 1 end

            local icon = isPass and "+" or "X"
            local color = isPass and { 0, 200, 0, 255 } or { 255, 60, 60, 255 }

            testResultsPanel_:AddChild(UI.Label {
                text = icon .. " " .. group .. "." .. name,
                fontSize = 12,
                fontColor = color,
            })
        end
    end

    local total = passed + failed
    if testSummaryLabel_ then
        if failed == 0 then
            testSummaryLabel_:SetText(passed .. "/" .. total .. " PASSED")
            testSummaryLabel_.fontColor = { 0, 220, 0, 255 }
        else
            testSummaryLabel_:SetText(passed .. "/" .. total .. " passed, " .. failed .. " FAILED")
            testSummaryLabel_.fontColor = { 255, 100, 100, 255 }
        end
    end

    print("[Client] Received " .. total .. " test results")
end

return Client
