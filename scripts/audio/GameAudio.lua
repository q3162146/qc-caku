-- ============================================================================
-- audio/GameAudio.lua
-- 配音 / UI 音效 / 环境音：统一 SoundSource，先停再播，缺文件静默跳过。
-- ============================================================================

local GameAudio = {}

---@type Node|nil
local node_ = nil
---@type SoundSource|nil
local voiceSrc_ = nil
---@type SoundSource|nil
local sfxSrc_ = nil
---@type SoundSource|nil
local ambSrc_ = nil
---@type string|nil
local lastSfx_ = nil
---@type number
local lastSfxFrame_ = -1
---@type number
local frame_ = 0

---@type Scene|nil
local sceneRef_ = nil

local function ensure()
    if node_ ~= nil then return end
    if sceneRef_ == nil then return end
    node_ = sceneRef_:CreateChild("GameAudio")
    voiceSrc_ = node_:CreateComponent("SoundSource")
    voiceSrc_:SetSoundType(SOUND_VOICE)
    sfxSrc_ = node_:CreateComponent("SoundSource")
    sfxSrc_:SetSoundType(SOUND_EFFECT)
    ambSrc_ = node_:CreateComponent("SoundSource")
    ambSrc_:SetSoundType(SOUND_AMBIENT)
end

---@param path string
---@return Sound|nil
local function load(path)
    if path == nil or path == "" then return nil end
    local ok, sound = pcall(function()
        return cache:GetResource("Sound", path)
    end)
    if not ok or sound == nil then
        return nil
    end
    return sound
end

---@param scene Scene
function GameAudio.Init(scene)
    sceneRef_ = scene
    ensure()
end

function GameAudio.Tick()
    frame_ = frame_ + 1
end

function GameAudio.StopVoice()
    if voiceSrc_ ~= nil then
        voiceSrc_:Stop()
    end
end

---@param path string|nil
function GameAudio.PlayVoice(path)
    ensure()
    if voiceSrc_ == nil then return end
    GameAudio.StopVoice()
    if path == nil or path == "" then return end
    local sound = load(path)
    if sound == nil then
        print("[GameAudio] 配音缺失，静默 | " .. tostring(path))
        return
    end
    voiceSrc_:Play(sound, 0, 1.0)
    print("[GameAudio] 配音 " .. path)
end

---@param path string|nil
---@param gain number|nil
function GameAudio.PlaySfx(path, gain)
    ensure()
    if sfxSrc_ == nil then return end
    if path == nil or path == "" then return end
    if lastSfx_ == path and lastSfxFrame_ == frame_ then return end
    local sound = load(path)
    if sound == nil then
        print("[GameAudio] 音效缺失，静默 | " .. tostring(path))
        return
    end
    sfxSrc_:Play(sound, 0, gain or 0.8)
    lastSfx_ = path
    lastSfxFrame_ = frame_
end

---@param path string|nil
function GameAudio.PlayAmbient(path)
    ensure()
    if ambSrc_ ~= nil then
        ambSrc_:Stop()
    end
    if path == nil or path == "" then return end
    local sound = load(path)
    if sound == nil then return end
    pcall(function()
        sound.looped = true
    end)
    ambSrc_:Play(sound, 0, 0.35)
end

function GameAudio.StopAll()
    GameAudio.StopVoice()
    if sfxSrc_ ~= nil then sfxSrc_:Stop() end
    if ambSrc_ ~= nil then ambSrc_:Stop() end
end

return GameAudio
