-- ============================================================================
-- Settings.lua - Game Configuration
-- ============================================================================
-- All resource paths are relative to assets/ directory

local Settings = {}

-- Player configuration
Settings.Player = {
    Prefab = "uuid://DEkZaUTQvLlCdjdIzpnHa4n-",
    Height = 1.8,
    Radius = 0.35,
    WalkSpeed = 0.025,
    RunSpeed = 0.1,
    AirControlFactor = 0.6,
    EnableWalkMode = true,
}

-- FSM configuration (relative to assets/)
Settings.FSM = {
    Unified = "FSM/Unified.fsm",
}

-- Camera configuration
Settings.Camera = {
    normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
    armed = { distance = 4.0, offset = Vector3(0.6, 1.6, 0), fov = 45.0 },
    aiming = { distance = 2.0, offset = Vector3(0.4, 1.5, 0), fov = 32.0 },
    transitionSpeed = 8.0,
    farClip = 300.0,
}

-- Combat configuration
Settings.Combat = {
    MaxHealth = 100,
    ShootInterval = 0.15,
    DamagePerHit = 25,
    ShootRecoveryTime = 0.35,  -- Post-shoot delay before running is allowed
}

-- Input sensitivity
Settings.Input = {
    MouseSensitivity = 0.1,
    TouchSensitivity = 0.15,
}

-- Network configuration
Settings.Network = {
    MaxPlayers = 4,
}

-- Spawn points
Settings.SpawnPoints = {
    Vector3(-15, 1.0, -15),
    Vector3(15, 1.0, -15),
    Vector3(-15, 1.0, 15),
    Vector3(15, 1.0, 15),
}

-- Control button flags (match C++ CTRL_* constants)
Settings.CTRL = {
    FORWARD = 1,
    BACK = 2,
    LEFT = 4,
    RIGHT = 8,
    JUMP = 16,
    RUN = 32,
    SHOOT = 64,
}

-- Network events
Settings.EVENTS = {
    CLIENT_READY = "ClientReady",
    ASSIGN_ROLE = "AssignRole",
    HEALTH_UPDATE = "HealthUpdate",
    PLAYER_DIED = "PlayerDied",
    PLAYER_RESPAWN = "PlayerRespawn",
    CYCLE_WEAPON = "CycleWeapon",
    SHOOT_HIT = "ShootHit",
}

-- Node variables for network sync
Settings.VARS = {
    IS_ROLE = "IsRole",
    WEAPON_TYPE = "WeaponType",
}

return Settings
