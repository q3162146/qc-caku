-- ============================================================================
-- Settings.lua - ServerScoreDemo Configuration
-- ============================================================================

local Settings = {}

-- Network
Settings.Network = {
    MaxPlayers = 4,
}

-- Score keys
Settings.ScoreKeys = {
    COINS = "coins",          -- int score: coin count
    KILLS = "kills",          -- int score: kill count
    PLAY_TIME = "play_time",  -- int score: seconds played
}

-- Network events
Settings.EVENTS = {
    CLIENT_READY     = "ClientReady",
    SCORE_UPDATE     = "ScoreUpdate",      -- server -> client: single player score changed
    LEADERBOARD      = "Leaderboard",      -- server -> client: full rank list
    REQUEST_SCORES   = "RequestScores",    -- client -> server: ask for current scores
    TEST_RESULTS     = "TestResults",       -- server -> client: API test results
    ADD_COIN         = "AddCoin",          -- client -> server: add 1 coin
    ADD_KILL         = "AddKill",          -- client -> server: add 1 kill
}

-- Test keys (namespaced with "test_" to avoid collision with game data)
Settings.TestKeys = {
    SCORE   = "test_score",
    INT     = "test_int",
    STR     = "test_str",
    MONEY   = "test_money",
    LIST    = "test_list",
    MESSAGE = "test_msg",
    WLIMIT  = "test_wlimit",
}

return Settings
