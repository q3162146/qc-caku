-- ============================================================================
-- audio/GameAudio.lua
-- 配音 / UI 音效 / 环境音 / BGM：统一 SoundSource，先停再播，缺文件静默跳过。
-- BGM 音乐通道：SOUND_MUSIC 源 + 常驻低音量 + 换曲淡入淡出（Tick(dt) 驱动）。
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
---@type SoundSource|nil
local musicSrc_ = nil
---@type string|nil
local lastSfx_ = nil
---@type number
local lastSfxFrame_ = -1
---@type number
local frame_ = 0

-- ---- BGM 通道状态 ----
local MUSIC_VOLUME_DEFAULT = 0.4   -- 常驻低音量（不盖配音）
local FADE_OUT_TIME = 0.8          -- 换曲淡出秒数
local FADE_IN_TIME = 1.6           -- 换曲淡入秒数
---@type string|nil 当前在播/在淡入的曲目路径
local musicPath_ = nil
---@type string|nil 淡出完成后待播的曲目
local pendingMusicPath_ = nil
---@type "idle"|"fadingOut"|"fadingIn"
local musicFade_ = "idle"
---@type number
local musicFadeT_ = 0
---@type number
local musicVolume_ = MUSIC_VOLUME_DEFAULT

--- 前向声明（定义在下方 BGM 段；Tick 先引用须有 upvalue 占位，否则落全局 nil）
---@type fun(dt: number)
local UpdateMusicFade

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
    musicSrc_ = node_:CreateComponent("SoundSource")
    musicSrc_:SetSoundType(SOUND_MUSIC)
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

--- 每帧驱动（frame 计数供 sfx 去重；dt 驱动 BGM 淡入淡出）
---@param dt number|nil
function GameAudio.Tick(dt)
    frame_ = frame_ + 1
    if dt ~= nil and dt > 0 then
        UpdateMusicFade(dt)
    end
end

-- ============================================================================
-- BGM 音乐通道
-- ============================================================================

--- 真正开始播放一首曲（looped，从 0 音量起步淡入）
---@param path string
local function StartMusicNow(path)
    if musicSrc_ == nil then return end
    local sound = load(path)
    if sound == nil then
        print("[GameAudio] BGM 缺失，静默 | " .. tostring(path))
        musicPath_ = nil
        musicFade_ = "idle"
        return
    end
    pcall(function()
        sound.looped = true
    end)
    musicSrc_:Play(sound, 0, 0)
    musicPath_ = path
    musicFade_ = "fadingIn"
    musicFadeT_ = 0
    print("[GameAudio] BGM 播放（淡入） " .. path)
end

--- 换曲淡入淡出状态机（GameAudio.Tick 驱动；赋给上方前向声明的 upvalue）
---@param dt number
UpdateMusicFade = function(dt)
    if musicSrc_ == nil then return end
    if musicFade_ == "fadingOut" then
        musicFadeT_ = musicFadeT_ + dt
        local k = math.min(1, musicFadeT_ / FADE_OUT_TIME)
        musicSrc_:SetGain(musicVolume_ * (1 - k))
        if k >= 1 then
            musicSrc_:Stop()
            musicFade_ = "idle"
            local nextPath = pendingMusicPath_
            pendingMusicPath_ = nil
            musicPath_ = nil
            if nextPath ~= nil then
                StartMusicNow(nextPath)
            end
        end
    elseif musicFade_ == "fadingIn" then
        musicFadeT_ = musicFadeT_ + dt
        local k = math.min(1, musicFadeT_ / FADE_IN_TIME)
        musicSrc_:SetGain(musicVolume_ * k)
        if k >= 1 then
            musicFade_ = "idle"
        end
    end
end

--- 播放/切换 BGM（相同曲目不重启；换曲先淡出再淡入；缺文件静默）
---@param path string|nil
function GameAudio.PlayMusic(path)
    ensure()
    if musicSrc_ == nil then return end
    if path == nil or path == "" then
        GameAudio.StopMusic()
        return
    end
    if path == musicPath_ then return end            -- 同曲不重启
    if musicFade_ == "fadingOut" then
        pendingMusicPath_ = path                      -- 已在淡出，替换待播曲
        return
    end
    if musicSrc_:IsPlaying() or musicFade_ == "fadingIn" then
        pendingMusicPath_ = path
        musicFade_ = "fadingOut"
        musicFadeT_ = 0
    else
        StartMusicNow(path)
    end
end

--- 停止 BGM（快速淡出）
function GameAudio.StopMusic()
    if musicSrc_ == nil then return end
    pendingMusicPath_ = nil
    if musicSrc_:IsPlaying() or musicFade_ == "fadingIn" then
        musicFade_ = "fadingOut"
        musicFadeT_ = 0
    end
end

--- 设置 BGM 音量（0~1；当前淡入淡出中则下一帧平滑生效）
---@param vol number
function GameAudio.SetMusicVolume(vol)
    musicVolume_ = math.max(0, math.min(1, vol))
    if musicSrc_ ~= nil and musicFade_ == "idle" and musicSrc_:IsPlaying() then
        musicSrc_:SetGain(musicVolume_)
    end
end

---@return string|nil 当前曲目路径
function GameAudio.GetMusicPath()
    return musicPath_
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
    GameAudio.StopMusic()
end

return GameAudio
