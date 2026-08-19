-- ============================================================================
-- Server.lua - ServerScoreDemo Server Logic (Simplified)
--
-- On Start():
--   1. Runs all serverCloud API tests immediately (no client needed)
--   2. Listens for client connections to serve test results + handle score ops
--
-- Client interactions:
--   - AddCoin / AddKill: increment player scores via serverCloud:Add()
--   - RequestScores: send current scores + leaderboard
--   - ClientReady: send cached test results + initial scores
-- ============================================================================

local Server = {}
local Shared = require("network.Shared")

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- Mock graphics for headless mode
-- ============================================================================

if GetGraphics() == nil then
    local mockGraphics = {
        SetWindowIcon = function() end,
        SetWindowTitleAndIcon = function() end,
        GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end,
    }
    function GetGraphics() return mockGraphics end
    graphics = mockGraphics
    console = { background = {} }
    function GetConsole() return console end
    debugHud = {}
    function GetDebugHud() return debugHud end
end

-- ============================================================================
-- Variables
-- ============================================================================

local Settings = Shared.Settings
local EVENTS = Shared.EVENTS
local TK = Settings.TestKeys

-- Connections
local serverConnections_ = {}  -- connKey -> connection
local connectionUserIds_ = {}  -- connKey -> userId

-- Score cache per userId
local playerScores_ = {}       -- userId -> { coins = N, kills = N }

-- Test results (cached to send to late-joining clients)
local testResults_ = {}        -- array of { group, name, pass, detail }
local testsDone_ = false
local testResultsEncoded_ = "" -- pre-encoded string for network

-- ============================================================================
-- Entry
-- ============================================================================

function Server.Start()
    SampleStart()
    Shared.RegisterEvents()

    SubscribeToEvent(EVENTS.CLIENT_READY, "HandleClientReady")
    SubscribeToEvent(EVENTS.REQUEST_SCORES, "HandleRequestScores")
    SubscribeToEvent(EVENTS.ADD_COIN, "HandleAddCoin")
    SubscribeToEvent(EVENTS.ADD_KILL, "HandleAddKill")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

    -- Determine test userId
    local testUserId = 10001  -- dev mode fallback (matches UrhoXServer auto-assign)
    if SERVER_PLAYER_AUTH_INFOS then
        for uid, _ in pairs(SERVER_PLAYER_AUTH_INFOS) do
            testUserId = uid
            break
        end
    end

    print("[Server] ServerScoreDemo started")
    print("[Server] serverCloud available: " .. tostring(serverCloud ~= nil))
    print("[Server] testUserId=" .. tostring(testUserId))

    -- Run tests immediately (no client connection needed)
    if serverCloud then
        RunTests(testUserId)
    else
        print("[Server] WARNING: serverCloud is nil, skipping tests")
    end
end

function Server.Stop()
end

-- ============================================================================
-- Connection Handling
-- ============================================================================

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)

    -- Get userId from identity
    local userId = 10001
    local identityUid = connection.identity["user_id"]
    if identityUid then
        userId = identityUid:GetInt64()
    end

    serverConnections_[connKey] = connection
    connectionUserIds_[connKey] = userId

    -- Init score cache
    if not playerScores_[userId] then
        playerScores_[userId] = { coins = 0, kills = 0 }
    end

    print("[Server] ClientReady userId=" .. tostring(userId))

    -- Load scores from serverCloud
    LoadPlayerScores(userId, connKey)

    -- Send cached test results if available
    if testsDone_ then
        SendTestResultsTo(connection)
    end
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData:GetPtr("Connection", "Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]

    serverConnections_[connKey] = nil
    connectionUserIds_[connKey] = nil

    print("[Server] Client disconnected userId=" .. tostring(userId))
end

-- ============================================================================
-- Score Loading
-- ============================================================================

function LoadPlayerScores(userId, connKey)
    if serverCloud == nil then
        SendScoreUpdateTo(connKey)
        return
    end

    serverCloud:BatchGet(userId)
        :Key(Settings.ScoreKeys.COINS)
        :Key(Settings.ScoreKeys.KILLS)
        :Fetch({
            ok = function(scores, iscores, sscores)
                if iscores then
                    if iscores[Settings.ScoreKeys.COINS] then
                        playerScores_[userId].coins = iscores[Settings.ScoreKeys.COINS]
                    end
                    if iscores[Settings.ScoreKeys.KILLS] then
                        playerScores_[userId].kills = iscores[Settings.ScoreKeys.KILLS]
                    end
                end
                print("[Server] Loaded scores for userId=" .. tostring(userId)
                    .. " coins=" .. playerScores_[userId].coins
                    .. " kills=" .. playerScores_[userId].kills)
                SendScoreUpdateTo(connKey)
            end,
            error = function(code, reason)
                print("[Server] BatchGet ERROR: " .. tostring(code) .. " " .. tostring(reason))
                SendScoreUpdateTo(connKey)
            end,
        })
end

-- ============================================================================
-- AddCoin / AddKill Handlers
-- ============================================================================

function HandleAddCoin(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end

    if not playerScores_[userId] then
        playerScores_[userId] = { coins = 0, kills = 0 }
    end
    playerScores_[userId].coins = playerScores_[userId].coins + 1

    if serverCloud then
        serverCloud:Add(userId, Settings.ScoreKeys.COINS, 1, {
            ok = function()
                print("[Server] +1 coin for userId=" .. tostring(userId))
            end,
            error = function(code, reason)
                print("[Server] AddCoin ERROR: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    BroadcastScoreUpdate(userId)
    BroadcastLeaderboard()
end

function HandleAddKill(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end

    if not playerScores_[userId] then
        playerScores_[userId] = { coins = 0, kills = 0 }
    end
    playerScores_[userId].kills = playerScores_[userId].kills + 1

    if serverCloud then
        serverCloud:Add(userId, Settings.ScoreKeys.KILLS, 1, {
            ok = function()
                print("[Server] +1 kill for userId=" .. tostring(userId))
            end,
            error = function(code, reason)
                print("[Server] AddKill ERROR: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    BroadcastScoreUpdate(userId)
    BroadcastLeaderboard()
end

function HandleRequestScores(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    SendScoreUpdateTo(connKey)
    BroadcastLeaderboard()
end

-- ============================================================================
-- Score Broadcasting
-- ============================================================================

function SendScoreUpdateTo(connKey)
    local conn = serverConnections_[connKey]
    local userId = connectionUserIds_[connKey]
    if not conn or not userId then return end

    local scores = playerScores_[userId]
    if not scores then return end

    local data = VariantMap()
    data["UserId"] = Variant(userId)
    data["Coins"] = Variant(scores.coins)
    data["Kills"] = Variant(scores.kills)

    conn:SendRemoteEvent(EVENTS.SCORE_UPDATE, true, data)
end

function BroadcastScoreUpdate(userId)
    local scores = playerScores_[userId]
    if not scores then return end

    local data = VariantMap()
    data["UserId"] = Variant(userId)
    data["Coins"] = Variant(scores.coins)
    data["Kills"] = Variant(scores.kills)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.SCORE_UPDATE, true, data)
    end
end

function BroadcastLeaderboard()
    -- Build leaderboard from connected players
    local entries = {}
    for connKey, userId in pairs(connectionUserIds_) do
        local scores = playerScores_[userId]
        if scores then
            table.insert(entries, {
                userId = userId,
                coins = scores.coins,
            })
        end
    end
    table.sort(entries, function(a, b) return a.coins > b.coins end)

    -- Encode: "userId:coins,userId:coins,..."
    local parts = {}
    for _, entry in ipairs(entries) do
        table.insert(parts, entry.userId .. ":" .. entry.coins)
    end
    local encoded = table.concat(parts, ",")

    local data = VariantMap()
    data["Board"] = Variant(encoded)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.LEADERBOARD, true, data)
    end
end

-- ============================================================================
-- Test Results Broadcasting
-- ============================================================================

function SendTestResultsTo(connection)
    if testResultsEncoded_ == "" then return end
    local data = VariantMap()
    data["Results"] = Variant(testResultsEncoded_)
    connection:SendRemoteEvent(EVENTS.TEST_RESULTS, true, data)
end

function BroadcastTestResults()
    if testResultsEncoded_ == "" then return end
    local data = VariantMap()
    data["Results"] = Variant(testResultsEncoded_)
    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.TEST_RESULTS, true, data)
    end
end

-- ============================================================================
-- ============================================================================
-- TEST RUNNER (merged from ServerScoreTests.lua)
-- ============================================================================
-- ============================================================================

local testUserId_ = 0
local savedListId_ = 0
local savedWLKey_ = ""

-- Forward declarations
local RunGroup1_CoreCRUD
local RunGroup2_BatchOps
local RunGroup3_Ranking
local RunGroup4_Commit
local RunGroup5_Money
local RunGroup6_List
local RunGroup8_Message
local RunGroup9_Misc
local RunGroup10_MultiGet
local FinishTests
local TestIsOldPlayer

-- ============================================================================
-- Test Helpers
-- ============================================================================

local function Pass(group, name, detail)
    table.insert(testResults_, { group = group, name = name, pass = true, detail = detail or "" })
    print("[Tests] PASS: " .. group .. "." .. name .. (detail and (" - " .. detail) or ""))
end

local function Fail(group, name, detail)
    table.insert(testResults_, { group = group, name = name, pass = false, detail = detail or "" })
    print("[Tests] FAIL: " .. group .. "." .. name .. (detail and (" - " .. detail) or ""))
end

local function ErrStr(code, reason)
    return tostring(code) .. " " .. tostring(reason)
end

-- ============================================================================
-- Run Tests
-- ============================================================================

function RunTests(userId)
    testUserId_ = userId
    testResults_ = {}
    savedListId_ = 0
    savedWLKey_ = ""
    print("[Tests] ============================================")
    print("[Tests] Starting API tests for userId=" .. tostring(userId))
    print("[Tests] ============================================")
    RunGroup1_CoreCRUD()
end

-- ============================================================================
-- G1: Core CRUD -- Set, Get, Delete
-- ============================================================================

RunGroup1_CoreCRUD = function()
    local G = "CoreCRUD"
    local uid = testUserId_

    serverCloud:Set(uid, TK.SCORE, {score = 42, tag = "test"}, {
        ok = function()
            Pass(G, "Set")
            serverCloud:Get(uid, TK.SCORE, {
                ok = function(scores, iscores, sscores)
                    if scores and scores[TK.SCORE] ~= nil then
                        Pass(G, "Get", "value found")
                    else
                        Fail(G, "Get", "key not found in scores")
                    end
                    serverCloud:Delete(uid, TK.SCORE, {
                        ok = function()
                            Pass(G, "Delete")
                            RunGroup2_BatchOps()
                        end,
                        error = function(code, reason)
                            Fail(G, "Delete", ErrStr(code, reason))
                            RunGroup2_BatchOps()
                        end,
                    })
                end,
                error = function(code, reason)
                    Fail(G, "Get", ErrStr(code, reason))
                    RunGroup2_BatchOps()
                end,
            })
        end,
        error = function(code, reason)
            Fail(G, "Set", ErrStr(code, reason))
            RunGroup2_BatchOps()
        end,
    })
end

-- ============================================================================
-- G2: Batch Operations -- BatchSet, BatchGet
-- ============================================================================

RunGroup2_BatchOps = function()
    local G = "BatchOps"
    local uid = testUserId_

    serverCloud:BatchSet(uid)
        :Set("test_bk1", {a = 1})
        :SetInt("test_bk2", 100)
        :Add("test_bk2", 5)
        :Save("batch test", {
            ok = function()
                Pass(G, "BatchSet.Save")
                serverCloud:BatchGet(uid)
                    :Key("test_bk1")
                    :Key("test_bk2")
                    :Fetch({
                        ok = function(scores, iscores, sscores)
                            if scores and scores["test_bk1"] ~= nil then
                                Pass(G, "BatchGet.score", "bk1 found")
                            else
                                Fail(G, "BatchGet.score", "bk1 not found")
                            end
                            if iscores and iscores["test_bk2"] then
                                Pass(G, "BatchGet.iscore", "bk2=" .. tostring(iscores["test_bk2"]))
                            else
                                Fail(G, "BatchGet.iscore", "bk2 not found")
                            end
                            serverCloud:BatchSet(uid)
                                :Delete("test_bk1")
                                :Delete("test_bk2")
                                :Save("cleanup", {
                                    ok = function() RunGroup3_Ranking() end,
                                    error = function() RunGroup3_Ranking() end,
                                })
                        end,
                        error = function(code, reason)
                            Fail(G, "BatchGet.Fetch", ErrStr(code, reason))
                            RunGroup3_Ranking()
                        end,
                    })
            end,
            error = function(code, reason)
                Fail(G, "BatchSet.Save", ErrStr(code, reason))
                RunGroup3_Ranking()
            end,
        })
end

-- ============================================================================
-- G3: Ranking -- GetUserRank, GetRankTotal
-- ============================================================================

RunGroup3_Ranking = function()
    local G = "Ranking"
    local uid = testUserId_

    serverCloud:SetInt(uid, TK.INT, 999, {
        ok = function()
            Pass(G, "SetInt_prep")
            serverCloud:GetUserRank(uid, TK.INT, {
                ok = function(rank, score)
                    Pass(G, "GetUserRank", "rank=" .. tostring(rank) .. " score=" .. tostring(score))
                    serverCloud:GetRankTotal(TK.INT, {
                        ok = function(total)
                            Pass(G, "GetRankTotal", "total=" .. tostring(total))
                            RunGroup4_Commit()
                        end,
                        error = function(code, reason)
                            Fail(G, "GetRankTotal", ErrStr(code, reason))
                            RunGroup4_Commit()
                        end,
                    })
                end,
                error = function(code, reason)
                    Fail(G, "GetUserRank", ErrStr(code, reason))
                    RunGroup4_Commit()
                end,
            })
        end,
        error = function(code, reason)
            Fail(G, "SetInt_prep", ErrStr(code, reason))
            RunGroup4_Commit()
        end,
    })
end

-- ============================================================================
-- G4: Commit -- BatchCommit + all commit operations
-- ============================================================================

RunGroup4_Commit = function()
    local G = "Commit"
    local uid = testUserId_

    local c = serverCloud:BatchCommit("API test commit")
    c:ScoreSet(uid, "test_c_score", {data = "hello"})
    c:ScoreSetInt(uid, "test_c_iscore", 50)
    c:ScoreAddInt(uid, "test_c_iscore", 10)
    c:ScoreSetStr(uid, "test_c_sscore", "test_string_value")
    c:ScoreDelete(uid, "test_c_score")
    c:ScoreDeleteInt(uid, "test_c_iscore_del")
    c:ScoreDeleteStr(uid, "test_c_sscore_del")
    c:MoneyAdd(uid, TK.MONEY, 1000)
    c:MoneyCost(uid, TK.MONEY, 200)
    local _, listId = c:ListAdd(uid, TK.LIST, {entry = "first_item", ts = 12345})
    savedListId_ = listId
    c:Commit({
        ok = function()
            Pass(G, "ScoreMoneyList", "listId=" .. tostring(savedListId_))
            savedWLKey_ = TK.WLIMIT
            local cr = serverCloud:BatchCommit("quota reset before add")
            cr:QuotaReset(uid, savedWLKey_)
            cr:Commit({
                ok = function()
                    local cw = serverCloud:BatchCommit("quota test")
                    cw:QuotaAdd(uid, savedWLKey_, 1, 10, "day", 1)
                    cw:Commit({
                        ok = function()
                            Pass(G, "QuotaAdd")
                            RunGroup5_Money()
                        end,
                        error = function(code, reason)
                            Fail(G, "QuotaAdd", ErrStr(code, reason))
                            RunGroup5_Money()
                        end,
                    })
                end,
                error = function(code, reason)
                    Fail(G, "QuotaAdd", "reset failed: " .. ErrStr(code, reason))
                    RunGroup5_Money()
                end,
            })
        end,
        error = function(code, reason)
            Fail(G, "ScoreMoneyList", ErrStr(code, reason))
            RunGroup5_Money()
        end,
    })
end

-- ============================================================================
-- G5: Money -- money:Get
-- ============================================================================

RunGroup5_Money = function()
    local G = "Money"
    local uid = testUserId_

    serverCloud.money:Get(uid, {
        ok = function(moneys)
            if moneys and moneys[TK.MONEY] then
                Pass(G, "MoneyGet", TK.MONEY .. "=" .. tostring(moneys[TK.MONEY]))
            else
                Pass(G, "MoneyGet", "returned OK (empty or no key)")
            end
            RunGroup6_List()
        end,
        error = function(code, reason)
            Fail(G, "MoneyGet", ErrStr(code, reason))
            RunGroup6_List()
        end,
    })
end

-- ============================================================================
-- G6: List -- list:Get, list:GetById, ListModify/ListModifyKey/ListDelete (via Commit)
-- ============================================================================

RunGroup6_List = function()
    local G = "List"
    local uid = testUserId_

    serverCloud.list:Get(uid, TK.LIST, {
        ok = function(list)
            if list and #list > 0 then
                Pass(G, "ListGet", "found " .. #list .. " item(s)")
                local queryListId = list[1].list_id
                serverCloud.list:GetById(queryListId, {
                    ok = function(items)
                        Pass(G, "ListGetById", "found " .. #items .. " item(s)")
                        local c2 = serverCloud:BatchCommit("list ops test")
                        c2:ListModify(queryListId, {entry = "modified_item"})
                        c2:ListModifyKey(queryListId, TK.LIST .. "_renamed")
                        c2:ListDelete(queryListId)
                        c2:Commit({
                            ok = function()
                                Pass(G, "ListModify+Key+Delete")
                                RunGroup8_Message()
                            end,
                            error = function(code, reason)
                                Fail(G, "ListModify+Key+Delete", ErrStr(code, reason))
                                RunGroup8_Message()
                            end,
                        })
                    end,
                    error = function(code, reason)
                        Fail(G, "ListGetById", ErrStr(code, reason))
                        RunGroup8_Message()
                    end,
                })
            else
                Pass(G, "ListGet", "returned OK (empty)")
                RunGroup8_Message()
            end
        end,
        error = function(code, reason)
            Fail(G, "ListGet", ErrStr(code, reason))
            RunGroup8_Message()
        end,
    })
end

-- ============================================================================
-- G8: Message -- message:Send, message:Get, message:MarkRead, message:Delete
-- ============================================================================

RunGroup8_Message = function()
    local G = "Message"
    local uid = testUserId_

    serverCloud.message:Send(uid, TK.MESSAGE, uid, {text = "hello from test"}, {
        ok = function(errorCode, errorDesc)
            if errorCode == 0 or errorCode == nil then
                Pass(G, "MessageSend")
            else
                Fail(G, "MessageSend", "code=" .. tostring(errorCode) .. " " .. tostring(errorDesc))
            end
            serverCloud.message:Get(uid, TK.MESSAGE, false, {
                ok = function(messages)
                    if messages and #messages > 0 then
                        Pass(G, "MessageGet", "found " .. #messages .. " msg(s)")
                        local msgId = messages[1].message_id
                        serverCloud.message:MarkRead(msgId, {
                            ok = function(errCode, errDesc)
                                Pass(G, "MessageMarkRead")
                                serverCloud.message:Delete(msgId, {
                                    ok = function(result, errCode2, errDesc2)
                                        Pass(G, "MessageDelete", "result=" .. tostring(result))
                                        RunGroup9_Misc()
                                    end,
                                    error = function(code, reason)
                                        Fail(G, "MessageDelete", ErrStr(code, reason))
                                        RunGroup9_Misc()
                                    end,
                                })
                            end,
                            error = function(code, reason)
                                Fail(G, "MessageMarkRead", ErrStr(code, reason))
                                RunGroup9_Misc()
                            end,
                        })
                    else
                        Pass(G, "MessageGet", "returned OK (empty)")
                        RunGroup9_Misc()
                    end
                end,
                error = function(code, reason)
                    Fail(G, "MessageGet", ErrStr(code, reason))
                    RunGroup9_Misc()
                end,
            })
        end,
        error = function(code, reason)
            Fail(G, "MessageSend", ErrStr(code, reason))
            RunGroup9_Misc()
        end,
    })
end

-- ============================================================================
-- G9: Quota + IsOldPlayer
-- ============================================================================

RunGroup9_Misc = function()
    local G = "Misc"
    local uid = testUserId_

    local wlKey = savedWLKey_ ~= "" and savedWLKey_ or TK.WLIMIT
    serverCloud.quota:Get(uid, wlKey, {
        ok = function(datas)
            if datas and #datas > 0 then
                Pass(G, "QuotaGet", "found " .. #datas .. " entry(ies)")
            else
                Pass(G, "QuotaGet", "returned OK (empty)")
            end
            local c5 = serverCloud:BatchCommit("quota reset")
            c5:QuotaReset(uid, wlKey)
            c5:Commit({
                ok = function()
                    Pass(G, "QuotaReset")
                    TestIsOldPlayer(G)
                end,
                error = function(code, reason)
                    Fail(G, "QuotaReset", ErrStr(code, reason))
                    TestIsOldPlayer(G)
                end,
            })
        end,
        error = function(code, reason)
            Fail(G, "QuotaGet", ErrStr(code, reason))
            TestIsOldPlayer(G)
        end,
    })
end

TestIsOldPlayer = function(G)
    local uid = testUserId_
    serverCloud:IsOldPlayer(uid, {
        ok = function(isOld)
            Pass(G, "IsOldPlayer", "result=" .. tostring(isOld))
            RunGroup10_MultiGet()
        end,
        error = function(code, reason)
            Fail(G, "IsOldPlayer", ErrStr(code, reason))
            RunGroup10_MultiGet()
        end,
    })
end

-- ============================================================================
-- G10: BatchGet:Player() -- multi-player batch query
-- ============================================================================

RunGroup10_MultiGet = function()
    local G = "BatchGetPlayer"
    local uid = testUserId_

    serverCloud:SetInt(uid, TK.INT, 777, {
        ok = function()
            Pass(G, "SetInt_prep")
            serverCloud:BatchGet()
                :Player(uid)
                :Player(uid)
                :Key(TK.INT)
                :Fetch({
                    ok = function(results)
                        if results and #results > 0 then
                            local entry = results[1]
                            if entry.userId == uid then
                                Pass(G, "Player", "userId=" .. tostring(entry.userId))
                            else
                                Fail(G, "Player", "expected=" .. tostring(uid) .. " got=" .. tostring(entry.userId))
                            end
                            if entry.iscore and entry.iscore[TK.INT] then
                                Pass(G, "Player.iscore", TK.INT .. "=" .. tostring(entry.iscore[TK.INT]))
                            else
                                Fail(G, "Player.iscore", "key not found")
                            end
                        else
                            Fail(G, "Player", "empty results")
                        end
                        FinishTests()
                    end,
                    error = function(code, reason)
                        Fail(G, "Player", ErrStr(code, reason))
                        FinishTests()
                    end,
                })
        end,
        error = function(code, reason)
            Fail(G, "SetInt_prep", ErrStr(code, reason))
            FinishTests()
        end,
    })
end

-- ============================================================================
-- Finish Tests
-- ============================================================================

FinishTests = function()
    local passed = 0
    local failed = 0
    for _, r in ipairs(testResults_) do
        if r.pass then passed = passed + 1 else failed = failed + 1 end
    end
    print("[Tests] ============================================")
    print("[Tests] ALL TESTS COMPLETE: " .. passed .. " passed, " .. failed .. " failed, " .. #testResults_ .. " total")
    print("[Tests] ============================================")

    testsDone_ = true

    -- Encode results for network: "group|name|P/F|detail;..."
    local parts = {}
    for _, r in ipairs(testResults_) do
        local status = r.pass and "P" or "F"
        local detail = (r.detail or ""):gsub("|", "/"):gsub(";", "/")
        table.insert(parts, r.group .. "|" .. r.name .. "|" .. status .. "|" .. detail)
    end
    testResultsEncoded_ = table.concat(parts, ";")

    -- Broadcast to any connected clients
    BroadcastTestResults()
end

return Server
