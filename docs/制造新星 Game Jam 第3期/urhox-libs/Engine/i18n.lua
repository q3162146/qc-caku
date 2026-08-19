-- i18n - Internationalization runtime support
--
-- Provides global _tr() function for translated string lookup with
-- automatic rendering hook injection. All text that reaches the screen
-- passes through _tr(), which translates hash keys (t_xxx) to localized text.
--
-- Build tool injects _tr() calls in Lua source:
--   _tr("t_1710742800_x3f2")              -- simple lookup
--   _tr("t_1710742801_a8d1", count, name) -- with {0}{1} placeholders
--
-- JSON/XML values are replaced with hash keys directly (t_xxx).
-- Rendering hooks (nvgText, Text3D:SetText) call _tr() transparently,
-- so hash keys from data files are translated at display time.
--
-- Config file: i18n.json (render-blocking, minimal subset of build config)
--   { "source_lang": "zh_CN", "target_langs": ["en", "ja"] }
--
-- Translation files: i18n/{lang}.json (not render-blocking, loaded on demand)
--
-- Language preference: {project_root}/user_lang (plain text, via C++ Localization)
--
-- Language resolution:
--   actualLang cache > user_lang file > system language

local i18n = {}

-- Translation table: hash_key -> translated text
local translations_ = {}

-- Dedup input for SetLanguage (prevents redundant reload)
local requestLang_ = nil

-- Resolved language currently in effect
local actualLang_ = nil


-- ============================================================
-- Core: _tr()
-- ============================================================

local function format_placeholders(text, ...)
    local args = {...}
    if #args == 0 then
        return text
    end
    return (text:gsub("{(%d+)}", function(idx)
        local arg = args[tonumber(idx) + 1]
        return arg ~= nil and tostring(arg) or ""
    end))
end

--- Global translation function.
-- @param key string Hash key (e.g. "t_VEeXsa8AyD") or plain text
-- @param ... any Format arguments for {0}, {1}, ... placeholders
-- @return string Translated and formatted text
local function _tr_impl(key, ...)
    if not key then return "" end
    local text = translations_[key] or key
    if select('#', ...) > 0 then
        return format_placeholders(text, ...)
    end
    return text
end

-- Default: passthrough, switched to _tr_impl when i18nConfig_ exists
function _tr(key) return key or "" end

--- Passthrough — marks text as "do not translate".
-- Also serves as safety net: if i18n is disabled after a build that
-- injected _raw() calls, the function still exists.
-- @param text string
-- @return string
function _raw(text)
    return text
end

-- ============================================================
-- Rendering hooks
-- ============================================================

local function installHooks()
    _tr = _tr_impl

    local _orig_nvgText = nvgText
    if _orig_nvgText then
        nvgText = function(ctx, x, y, text, e)
            return _orig_nvgText(ctx, x, y, _tr(text), e)
        end
    end

    local _orig_nvgTextBox = nvgTextBox
    if _orig_nvgTextBox then
        nvgTextBox = function(ctx, x, y, breakRowWidth, text, e)
            return _orig_nvgTextBox(ctx, x, y, breakRowWidth, _tr(text), e)
        end
    end

    local _orig_nvgTextBounds = nvgTextBounds
    if _orig_nvgTextBounds then
        nvgTextBounds = function(ctx, x, y, text)
            return _orig_nvgTextBounds(ctx, x, y, _tr(text))
        end
    end

    local _orig_nvgTextBoxBounds = nvgTextBoxBounds
    if _orig_nvgTextBoxBounds then
        nvgTextBoxBounds = function(ctx, x, y, breakRowWidth, text)
            return _orig_nvgTextBoxBounds(ctx, x, y, breakRowWidth, _tr(text))
        end
    end

    local _orig_string_format = string.format
    if _orig_string_format then
        string.format = function(fmt, ...)
            return _orig_string_format(_tr(fmt), ...)
        end
    end

    if Text3D then
        -- Hook method call: text3d:SetText("t_xxx")
        local _orig_SetText = Text3D.SetText
        Text3D.SetText = function(self, text)
            return _orig_SetText(self, _tr(text))
        end

        -- Hook property assignment: text3d.text = "t_xxx"
        -- tolua stores property setters in .set table
        local setTable = Text3D[".set"]
        if setTable and setTable.text then
            local _orig_set_text = setTable.text
            setTable.text = function(self, value)
                return _orig_set_text(self, _tr(value))
            end
        end
    end
end

-- ============================================================
-- i18n config + language resolution
-- KEEP IN SYNC with engine-startup/main.lua — 直接复制粘贴同步
-- ============================================================

local NONE = {}
local i18nConfig_ = nil

-- UUID 来自 engine-res-project 的 .meta 文件，重新生成 meta 后需同步更新
local ENGINE_I18N_CONFIG_UUID = "Q4M3GntfTmiNZCdTeiz5Kg"  -- .project/i18n.json.meta
local ENGINE_I18N_FALLBACK_LANG_URIS = {
    zh_CN = "uuid://-73mcwx1QB6NyLrwJxv8Kg",  -- i18n/zh_CN.json.meta
    en    = "uuid://u05oYbz5RtecsyHB9-bmKQ",   -- i18n/en.json.meta
}

local function engineLangUri(lang)
    local schemeUri = "engine-res://i18n/" .. lang .. ".json"
    if cache:Exists(schemeUri) then
        return schemeUri
    end
    return ENGINE_I18N_FALLBACK_LANG_URIS[lang]
end

local function loadConfig()
    if i18nConfig_ ~= nil then
        return i18nConfig_ ~= NONE and i18nConfig_ or nil
    end
    if not cache:Exists("i18n.json") then
        log:Write(LOG_INFO, "[i18n] loadConfig: i18n.json not found, i18n disabled")
        i18nConfig_ = NONE
        return nil
    end
    local file = cache:GetFile("i18n.json")
    if not file then
        i18nConfig_ = NONE
        return nil
    end
    local content = file:ReadString()
    file:Close()
    if not content or content == "" then
        i18nConfig_ = NONE
        return nil
    end
    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then
        i18nConfig_ = NONE
        return nil
    end

    -- engine-res 增加了多语言能力，非多语言项目会 fallback 到引擎的 i18n.json，
    -- 通过 GetResUuid 与引擎已知 UUID 比较来检测，fallback 时 support_langs 限制为 source_lang。
    if cache.GetResUuid then
        local uuid = cache:GetResUuid("i18n.json")
        log:Write(LOG_INFO, "[i18n] loadConfig: uuid='" .. tostring(uuid) .. "' engine='" .. ENGINE_I18N_CONFIG_UUID .. "' match=" .. tostring(uuid == ENGINE_I18N_CONFIG_UUID))
        if uuid == ENGINE_I18N_CONFIG_UUID and data.source_lang then
            data.support_langs = { data.source_lang }
            data.support_langs_str = data.source_lang
            log:Write(LOG_INFO, "[i18n] loadConfig: engine fallback, support_langs='" .. data.support_langs_str .. "'")
        end
    end

    if not data.support_langs then
        local langs = {}
        if data.source_lang and data.source_lang ~= "" then
            langs[#langs + 1] = data.source_lang
        end
        if data.target_langs then
            for _, lang in ipairs(data.target_langs) do
                langs[#langs + 1] = lang
            end
        end
        data.support_langs = langs
        data.support_langs_str = #langs > 0 and table.concat(langs, ",") or ""
    end

    i18nConfig_ = data
    return i18nConfig_
end

--- Resolve language: user pref > -lang > system > source_lang.
local function resolveI18nLanguage()
    local cfg = loadConfig()
    if not cfg then return nil, nil end
    local supportLangs = cfg.support_langs_str

    if localization.ReadUserPrefLanguage then
        local pref = localization:ReadUserPrefLanguage()
        if pref and pref ~= "" then
            local matched = pref
            if supportLangs ~= "" and localization.MatchLanguage then
                matched = localization:MatchLanguage(pref, supportLangs)
            end
            if matched and matched ~= "" then
                return matched, cfg
            end
        end
    end

    local argLang = GetAppArgv and GetAppArgv("lang") or ""
    if argLang ~= "" then
        local matched = argLang
        if supportLangs ~= "" and localization.MatchLanguage then
            matched = localization:MatchLanguage(argLang, supportLangs)
        end
        if matched and matched ~= "" then
            log:Write(LOG_INFO, "[i18n] -lang='" .. argLang .. "' matched='" .. matched .. "'")
            return matched, cfg
        end
        log:Write(LOG_WARNING, "[i18n] -lang='" .. argLang .. "' not in support_langs='" .. supportLangs .. "', falling through")
    end

    local sysLang = localization.GetSystemLanguage and localization:GetSystemLanguage() or ""
    if sysLang ~= "" then
        local matched = sysLang
        if supportLangs ~= "" and localization.MatchLanguage then
            matched = localization:MatchLanguage(sysLang, supportLangs)
        end
        if matched and matched ~= "" then
            return matched, cfg
        end
    end

    if cfg.source_lang and cfg.source_lang ~= "" then
        return cfg.source_lang, cfg
    end

    return nil, cfg
end

-- ============================================================
-- END SYNC BLOCK
-- ============================================================

-- ============================================================
-- Built-in confirm dialog (independent NVG render target)
-- Mirrors engine-startup/loading_ui.lua dialog style.
-- No dependency on urhox-libs/UI — works in any project.
-- Uses ScriptObject + self:SubscribeToEvent for local events.
-- ============================================================

-- Layout constants (logical pixels, same as loading_ui)
local DLG_TITLE_SIZE   = 18
local DLG_MSG_SIZE     = 14
local DLG_BTN_SIZE     = 15
local DLG_WIDTH        = 400
local DLG_RADIUS       = 16
local DLG_BTN_RADIUS   = 10
local DLG_BTN_H        = 44
local DLG_BTN_GAP      = 12
local DLG_FADE_DUR     = 0.25
local DLG_PC_REF       = 720

-- Singleton dialog instance (lazy-created)
local dlgInstance = nil

---@class i18n_DialogReceiver : LuaScriptObject
i18n_DialogReceiver = ScriptObject()

function i18n_DialogReceiver:Start()
    -- NVG resources
    self.vg = nvgCreate(1)
    if not self.vg then
        log:Write(LOG_WARNING, "[i18n] Failed to create dialog NVG context")
        return
    end
    nvgSetRenderOrder(self.vg, 999998)  -- render on top

    self.font = nvgCreateFont(self.vg, "sans", "Fonts/MiSans-Regular.ttf")
    if self.font < 0 then
        self.font = nvgCreateFont(self.vg, "sans", "Fonts/Anonymous Pro.ttf")
    end

    -- State
    self.visible = false
    self.opacity = 0.0
    self.fading = false
    self.fadeIn = false
    self.fadeProg = 0.0
    self.title = ""
    self.message = ""
    self.confirmText = "OK"
    self.cancelText = ""
    self.callback = nil
    self.confirmRect = { x = 0, y = 0, w = 0, h = 0 }
    self.cancelRect  = { x = 0, y = 0, w = 0, h = 0 }
    self.pressConfirm = false
    self.pressCancel = false
    self.logW = 0
    self.logH = 0
    self.dpr = 1.0

    self:RecalcLayout()

    -- Subscribe events via self (local, auto-cleanup)
    self:SubscribeToEvent(self.vg, "NanoVGRender", function(_, et, ed) self:HandleRender() end)
    self:SubscribeToEvent("Update", function(_, et, ed) self:HandleUpdate(ed["TimeStep"]:GetFloat()) end)
    self:SubscribeToEvent("MouseButtonDown", function(_, et, ed) self:HandleMouseDown(et, ed) end)
    self:SubscribeToEvent("MouseButtonUp", function(_, et, ed) self:HandleMouseUp(et, ed) end)
    self:SubscribeToEvent("TouchEnd", function(_, et, ed) self:HandleTouchEnd(et, ed) end)
end

function i18n_DialogReceiver:RecalcLayout()
    local rawDpr = graphics:GetDPR()
    local shortSide = math.min(graphics:GetWidth(), graphics:GetHeight()) / rawDpr
    local densityFactor = math.max(0.625, math.min(math.sqrt(shortSide / DLG_PC_REF), 1.0))
    self.dpr = rawDpr * densityFactor
    self.logW = graphics:GetWidth() / self.dpr
    self.logH = graphics:GetHeight() / self.dpr
end

function i18n_DialogReceiver:PointInRect(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function i18n_DialogReceiver:Dismiss(confirmed)
    if not self.visible then return end
    self.fading = true
    self.fadeIn = false
    self.fadeProg = 0
    if self.callback then
        local cb = self.callback
        self.callback = nil
        cb(confirmed)
    end
end

function i18n_DialogReceiver:HandleUpdate(dt)
    if not self.fading then return end
    self.fadeProg = self.fadeProg + dt / DLG_FADE_DUR
    if self.fadeProg >= 1.0 then
        self.fadeProg = 1.0
        self.fading = false
        self.opacity = self.fadeIn and 1.0 or 0.0
        if not self.fadeIn then
            self.visible = false
        end
    else
        self.opacity = self.fadeIn and self.fadeProg or (1.0 - self.fadeProg)
    end
end

function i18n_DialogReceiver:HandleRender()
    if not self.vg or self.opacity <= 0 then return end

    self:RecalcLayout()
    local vg = self.vg
    local da = self.opacity
    local logW, logH = self.logW, self.logH
    local padX, padTop, padBot = 28, 32, 24

    nvgBeginFrame(vg, logW, logH, self.dpr)

    -- Overlay
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, logW, logH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(153 * da)))
    nvgFill(vg)

    -- Dialog dimensions
    local dw = math.min(DLG_WIDTH, logW * 0.85)
    local titleH = DLG_TITLE_SIZE + 4
    local msgH = DLG_MSG_SIZE * 2.5
    local contentH = padTop + titleH + 16 + msgH + 24 + DLG_BTN_H + padBot
    local dx = (logW - dw) / 2
    local dy = (logH - contentH) / 2

    -- Card shadow + background + border
    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx - 2, dy - 2, dw + 4, contentH + 4, DLG_RADIUS + 1)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(80 * da)))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx, dy, dw, contentH, DLG_RADIUS)
    nvgFillColor(vg, nvgRGBA(30, 30, 45, math.floor(242 * da)))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx, dy, dw, contentH, DLG_RADIUS)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, math.floor(20 * da)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local curY = dy + padTop

    -- Title
    if self.font >= 0 and self.title ~= "" then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, DLG_TITLE_SIZE)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(242 * da)))
        nvgText(vg, logW / 2, curY, self.title, nil)
        curY = curY + titleH + 16
    end

    -- Message
    if self.font >= 0 and self.message ~= "" then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, DLG_MSG_SIZE)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(153 * da)))
        nvgTextBox(vg, dx + padX, curY, dw - padX * 2, self.message, nil)
        curY = curY + msgH + 24
    end

    -- Buttons
    local hasCancelBtn = self.cancelText ~= ""
    local btnAreaX = dx + padX
    local btnAreaW = dw - padX * 2

    if hasCancelBtn then
        local btnW = (btnAreaW - DLG_BTN_GAP) / 2

        -- Cancel button
        self.cancelRect = { x = btnAreaX, y = curY, w = btnW, h = DLG_BTN_H }
        nvgBeginPath(vg)
        nvgRoundedRect(vg, self.cancelRect.x, self.cancelRect.y, self.cancelRect.w, self.cancelRect.h, DLG_BTN_RADIUS)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor((self.pressCancel and 30 or 20) * da)))
        nvgFill(vg)
        if self.font >= 0 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, DLG_BTN_SIZE)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(178 * da)))
            nvgText(vg, self.cancelRect.x + self.cancelRect.w / 2, self.cancelRect.y + self.cancelRect.h / 2, self.cancelText, nil)
        end

        -- Confirm button
        local cA = self.pressConfirm and 217 or 255
        self.confirmRect = { x = btnAreaX + btnW + DLG_BTN_GAP, y = curY, w = btnW, h = DLG_BTN_H }
        nvgBeginPath(vg)
        nvgRoundedRect(vg, self.confirmRect.x, self.confirmRect.y, self.confirmRect.w, self.confirmRect.h, DLG_BTN_RADIUS)
        local grad = nvgLinearGradient(vg,
            self.confirmRect.x, self.confirmRect.y,
            self.confirmRect.x + self.confirmRect.w, self.confirmRect.y + self.confirmRect.h,
            nvgRGBA(91, 106, 240, math.floor(cA * da)),
            nvgRGBA(124, 91, 240, math.floor(cA * da)))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
        if self.font >= 0 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, DLG_BTN_SIZE)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(255 * da)))
            nvgText(vg, self.confirmRect.x + self.confirmRect.w / 2, self.confirmRect.y + self.confirmRect.h / 2, self.confirmText, nil)
        end
    else
        -- Single confirm button (full width)
        local cA = self.pressConfirm and 217 or 255
        self.confirmRect = { x = btnAreaX, y = curY, w = btnAreaW, h = DLG_BTN_H }
        nvgBeginPath(vg)
        nvgRoundedRect(vg, self.confirmRect.x, self.confirmRect.y, self.confirmRect.w, self.confirmRect.h, DLG_BTN_RADIUS)
        local grad = nvgLinearGradient(vg,
            self.confirmRect.x, self.confirmRect.y,
            self.confirmRect.x + self.confirmRect.w, self.confirmRect.y + self.confirmRect.h,
            nvgRGBA(91, 106, 240, math.floor(cA * da)),
            nvgRGBA(124, 91, 240, math.floor(cA * da)))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
        if self.font >= 0 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, DLG_BTN_SIZE)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(255 * da)))
            nvgText(vg, self.confirmRect.x + self.confirmRect.w / 2, self.confirmRect.y + self.confirmRect.h / 2, self.confirmText, nil)
        end
        self.cancelRect = { x = 0, y = 0, w = 0, h = 0 }
    end

    nvgEndFrame(vg)
end

function i18n_DialogReceiver:HandleMouseDown(eventType, eventData)
    if not self.visible or self.opacity <= 0 then return end
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    local mx = eventData["X"]:GetInt() / self.dpr
    local my = eventData["Y"]:GetInt() / self.dpr
    self.pressConfirm = self:PointInRect(mx, my, self.confirmRect)
    self.pressCancel  = self:PointInRect(mx, my, self.cancelRect)
end

function i18n_DialogReceiver:HandleMouseUp(eventType, eventData)
    if not self.visible or self.opacity <= 0 then return end
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    local mx = eventData["X"]:GetInt() / self.dpr
    local my = eventData["Y"]:GetInt() / self.dpr
    self.pressConfirm = false
    self.pressCancel = false
    if self:PointInRect(mx, my, self.confirmRect) then
        self:Dismiss(true)
    elseif self:PointInRect(mx, my, self.cancelRect) then
        self:Dismiss(false)
    end
end

function i18n_DialogReceiver:HandleTouchEnd(eventType, eventData)
    if not self.visible or self.opacity <= 0 then return end
    local tx = eventData["X"]:GetInt() / self.dpr
    local ty = eventData["Y"]:GetInt() / self.dpr
    if self:PointInRect(tx, ty, self.confirmRect) then
        self:Dismiss(true)
    elseif self:PointInRect(tx, ty, self.cancelRect) then
        self:Dismiss(false)
    end
end

function i18n_DialogReceiver:ShowConfirm(title, message, confirmText, cancelText, callback)
    self.title = title or ""
    self.message = message or ""
    self.confirmText = confirmText or "OK"
    self.cancelText = cancelText or ""
    self.callback = callback
    self.visible = true
    self.fading = true
    self.fadeIn = true
    self.fadeProg = 0
    self.pressConfirm = false
    self.pressCancel = false
end

function i18n_DialogReceiver:ShowAlert(title, message, buttonText, callback)
    self:ShowConfirm(title, message, buttonText, nil, function()
        if callback then callback() end
    end)
end

--- Get or create the singleton dialog instance
local function getDialog()
    if dlgInstance and dlgInstance.vg then return dlgInstance end
    local node = Node()
    dlgInstance = node:CreateScriptObject("i18n_DialogReceiver")
    if not dlgInstance or not dlgInstance.vg then
        log:Write(LOG_WARNING, "[i18n] Failed to create dialog ScriptObject")
        dlgInstance = nil
        return nil
    end
    return dlgInstance
end

-- ============================================================
-- Public API
-- ============================================================

function i18n.AddTranslations(uri)
    -- Target lang file may be absent pre-restart on language switch; relies on
    -- post-restart PreloadI18nStep to fetch. Skip silently to avoid ERROR noise.
    if not cache:Exists(uri) then
        log:Write(LOG_INFO, "[i18n] AddTranslations: '" .. uri .. "' not loaded yet, will take effect after restart")
        return false
    end

    local file = cache:GetFile(uri)
    if not file then
        log:Write(LOG_WARNING, "[i18n] AddTranslations: '" .. uri .. "' not found")
        return false
    end

    local content = file:ReadString()
    file:Close()

    if not content or content == "" then
        log:Write(LOG_WARNING, "[i18n] AddTranslations: '" .. uri .. "' is empty")
        return false
    end

    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then
        log:Write(LOG_WARNING, "[i18n] AddTranslations: '" .. uri .. "' parse failed")
        return false
    end

    for key, text in pairs(data) do
        translations_[key] = text
    end
    return true
end

--- Get current language.
-- Resolution: actualLang cache > user_lang file > system language
-- @return string
function i18n.GetLanguage()
    if actualLang_ then return actualLang_ end

    local lang = resolveI18nLanguage()

    if lang then
        log:Write(LOG_INFO, "[i18n] GetLanguage: resolved='" .. lang .. "'")
        actualLang_ = lang
        return lang
    end

    log:Write(LOG_INFO, "[i18n] GetLanguage: no language resolved")
    return ""
end

--- Switch language. If lang is nil/empty, resolves via GetLanguage().
-- Falls back to source_lang if lang is not supported.
-- @param lang string|nil Language code (nil = auto-resolve, won't persist to user_lang)
function i18n.SetLanguage(lang)
    -- Track whether caller explicitly picked a language. Auto-resolve (nil/empty input)
    -- happens at module load and shouldn't persist -lang/system pick to user pref —
    -- otherwise -lang=xx becomes sticky across boots and stale pref overrides future -lang.
    local explicit = lang and lang ~= ""

    -- Resolve language if not provided
    if not explicit then
        lang = i18n.GetLanguage()
    end

    local cfg = loadConfig()
    if cfg and lang and lang ~= "" then
        local supportLangs = cfg.support_langs_str
        if supportLangs and supportLangs ~= "" and localization.MatchLanguage then
            local matched = localization:MatchLanguage(lang, supportLangs)
            if matched and matched ~= "" then
                if matched ~= lang then
                    log:Write(LOG_INFO, "[i18n] SetLanguage: '" .. lang .. "' matched to '" .. matched .. "'")
                end
                lang = matched
            else
                -- C++ MatchLanguage step 5 already returns "en" when supported; reaching here
                -- means even en is unavailable → use source_lang as last resort.
                log:Write(LOG_WARNING, "[i18n] Language '" .. lang .. "' not supported, fallback to source_lang='" .. (cfg.source_lang or "") .. "'")
                lang = cfg.source_lang
            end
        end
    end

    -- Final fallback to source_lang
    if (not lang or lang == "") and cfg then
        lang = cfg.source_lang
    end

    if not lang or lang == "" then
        return
    end

    -- Persist user pref BEFORE dedup: if explicit caller re-picks the same lang as a
    -- prior auto-resolve (which didn't persist), dedup would otherwise drop the write.
    if explicit and localization.SaveUserPrefLanguage then
        localization:SaveUserPrefLanguage(lang)
    end

    -- Skip translation table reload if already on this language
    if lang == requestLang_ then
        log:Write(LOG_INFO, "[i18n] SetLanguage: lang='" .. lang .. "' explicit=" .. tostring(explicit) .. " (dedup, reload skipped)")
        return
    end
    requestLang_ = lang

    actualLang_ = lang
    log:Write(LOG_INFO, "[i18n] SetLanguage: actualLang='" .. lang .. "' explicit=" .. tostring(explicit))

    -- Set resource variant tag for locale-specific assets (@en, @ja, etc.)
    if cache.SetVariantTag then
        local variantLang = lang
        -- Source language uses default resources (no variant tag)
        if cfg and lang == cfg.source_lang then
            variantLang = ""
        end
        log:Write(LOG_INFO, "[i18n] SetVariantTag: priority=2000, tag='" .. variantLang .. "'")
        cache:SetVariantTag(2000, variantLang)
    else
        log:Write(LOG_WARNING, "[i18n] cache.SetVariantTag not available")
    end

    translations_ = {}
    local engineUri = engineLangUri(lang)
    if engineUri then i18n.AddTranslations(engineUri) end
    i18n.AddTranslations("i18n/" .. lang .. ".json")
end

--- Get supported language list (array of language codes).
-- @return table Array of language codes, e.g. {"zh_CN", "en", "ja"}
function i18n.GetSupportLanguages()
    local cfg = loadConfig()
    if cfg and cfg.support_langs then
        return cfg.support_langs
    end
    return {}
end

--- Request language change with confirm dialog.
-- On confirm: applies SetLanguage and restarts (new engine) or prompts manual restart (old engine).
-- SetLanguage is only called after user confirms.
-- @param lang string Target language code
function i18n.RequestChangeLanguage(lang)
    if not lang or lang == "" then return end
    if lang == actualLang_ then return end

    -- Feature detection: SetVariantTag exists = new binary with safe restart
    local canAutoRestart = (cache.SetVariantTag and true) or false

    local l10n = localization
    local function Tr(key) return l10n and l10n:Get(key) or key end

    local dlg = getDialog()
    if not dlg then
        -- Fallback: apply directly (best effort)
        log:Write(LOG_WARNING, "[i18n] RequestChangeLanguage: dialog unavailable, applying directly")
        i18n.SetLanguage(lang)
        return
    end

    local message = canAutoRestart
        and Tr("Switching language requires restarting. Continue?")
        or  Tr("Current engine version does not support language switching.")

    dlg:ShowConfirm(
        Tr("Switch Language"),
        message,
        Tr("OK"),
        Tr("Cancel"),
        function(confirmed)
            if not confirmed then return end
            i18n.SetLanguage(lang)
            if canAutoRestart then
                SendEvent("RequestRestartGame", VariantMap())
            end
        end
    )
end

--- Get display name for a language code.
-- Uses lang_to_display mapping from i18n.json if available,
-- otherwise falls back to built-in defaults.
-- @param lang string|nil Language code (nil = current language)
-- @return string Display name (e.g. "简体中文", "English")
function i18n.GetLanguageDisplay(lang)
    lang = lang or actualLang_ or ""
    if lang == "" then return "" end
    local cfg = loadConfig()
    if cfg and cfg.lang_to_display and cfg.lang_to_display[lang] then
        return cfg.lang_to_display[lang]
    end
    return lang
end

--- Get config table (for debugging).
function i18n.GetConfig()
    return i18nConfig_
end

--- Get raw translations_ table (for debugging).
function i18n.GetTranslations()
    return translations_
end


-- ============================================================
-- Auto-initialize on require
-- ============================================================

i18n.SetLanguage()
if i18nConfig_ and i18nConfig_ ~= NONE then
    installHooks()
    log:Write(LOG_INFO, "[i18n] init: lang='" .. tostring(actualLang_) .. "' translations=" .. tostring(next(translations_) ~= nil) .. " hooks=true")
else
    log:Write(LOG_INFO, "[i18n] init: no config found, hooks NOT installed")
end

-- Register as global
_G.i18n = i18n

return i18n
