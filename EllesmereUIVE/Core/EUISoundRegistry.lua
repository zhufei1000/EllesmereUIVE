local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.EUISoundRegistry = NS.Core.EUISoundRegistry or {}
local Registry = NS.Core.EUISoundRegistry
NS.ResolvedSoundPaths = NS.ResolvedSoundPaths or {}
NS.ResolvedSoundKeysByPath = NS.ResolvedSoundKeysByPath or {}
NS.ResolvedSoundSpellIDs = NS.ResolvedSoundSpellIDs or {}

local function NowPrecise()
    return type(GetTimePreciseSec) == "function" and GetTimePreciseSec()
        or (type(GetTime) == "function" and GetTime()) or 0
end

local function TimingDebugEnabled()
    if NS.DEBUG_SOUND_TIMING == true then return true end
    local db = rawget(_G, "EllesmereUIVEDB")
    local settings = type(db) == "table" and db.settings or nil
    return type(settings) == "table" and (settings.developerMode == true or settings.debugSoundTiming == true)
end

local function Bridge()
    return NS.Core and NS.Core.BootstrapBridge
end

local function NormalizePath(path)
    local bridge = Bridge()
    if bridge then return bridge:NormalizePath(path) end
    return tostring(path or ""):match("^%s*(.-)%s*$"):gsub("/", "\\")
end

local function GetLSM()
    local libStub = rawget(_G, "LibStub")
    return type(libStub) == "table" and libStub:GetLibrary("LibSharedMedia-3.0", true) or nil
end

local function NormalizeSoundKey(soundKey)
    soundKey = tostring(soundKey or "")
    if soundKey == "" then return "" end
    return soundKey:match("^sm:") and soundKey or ("sm:" .. soundKey)
end

function Registry:CacheResolvedPath(soundKey, path)
    local normalizedKey = NormalizeSoundKey(soundKey)
    path = NormalizePath(path)
    if normalizedKey == "" or path == "" then return false end
    NS.ResolvedSoundPaths[normalizedKey] = path
    NS.ResolvedSoundPaths[normalizedKey:sub(4)] = path
    NS.ResolvedSoundKeysByPath[path:lower()] = normalizedKey
    return true
end

function Registry:GetCachedSoundPath(soundKey, spellID)
    local normalizedKey = NormalizeSoundKey(soundKey)
    local path = NS.ResolvedSoundPaths[normalizedKey] or NS.ResolvedSoundPaths[normalizedKey:sub(4)]
    if TimingDebugEnabled() then
        self:RecordSoundResolved(spellID, normalizedKey, NowPrecise())
    end
    return path
end

function Registry:ValidateEntry(entry)
    if type(entry) ~= "table" then return false, "invalid_path" end
    local source = tostring(entry.soundSource or "custom")
    if source == "tts" or tostring(entry.notifyMode or "") == "tts" then return false, "unsupported_tts" end
    local path = self:ResolveSoundPath(entry)
    if source == "sharedmedia" and path == "" then return false, "sharedmedia_missing" end
    local key = self:BuildStableSoundKey(entry)
    if path == "" or not key then return false, "invalid_path" end
    entry.soundKey = key
    return true, "valid"
end

function Registry:RecordCooldownStarted(spellID, soundKey, timestamp)
    if not TimingDebugEnabled() then return false end
    local key = NormalizeSoundKey(soundKey)
    self._timingBySoundKey = self._timingBySoundKey or {}
    local record = self._timingBySoundKey[key] or {}
    record.spellID, record.soundKey = tonumber(spellID) or 0, key
    record.cooldownStarted = tonumber(timestamp) or NowPrecise()
    self._timingBySoundKey[key] = record
    return true
end

function Registry:RecordEUIReady(spellID, soundKey, timestamp)
    if not TimingDebugEnabled() then return false end
    local key = NormalizeSoundKey(soundKey)
    self._timingBySoundKey = self._timingBySoundKey or {}
    local record = self._timingBySoundKey[key] or {}
    record.spellID, record.soundKey = tonumber(spellID) or record.spellID or 0, key
    record.euiReady = tonumber(timestamp) or NowPrecise()
    self._timingBySoundKey[key] = record
    return true
end

function Registry:RecordSoundResolved(spellID, soundKey, timestamp)
    if not TimingDebugEnabled() then return false end
    local key = NormalizeSoundKey(soundKey)
    self._timingBySoundKey = self._timingBySoundKey or {}
    local record = self._timingBySoundKey[key] or {}
    record.spellID, record.soundKey = tonumber(spellID) or record.spellID or 0, key
    record.soundResolved = tonumber(timestamp) or NowPrecise()
    self._timingBySoundKey[key] = record
    return true
end

function Registry:RecordPlayCalled(spellID, soundKey, timestamp)
    if not TimingDebugEnabled() then return false end
    local key = NormalizeSoundKey(soundKey)
    self._timingBySoundKey = self._timingBySoundKey or {}
    local record = self._timingBySoundKey[key] or {}
    record.spellID, record.soundKey = tonumber(spellID) or record.spellID or 0, key
    record.playCalled = tonumber(timestamp) or NowPrecise()
    self._timingBySoundKey[key] = record
    local resolveDelay = record.euiReady and record.soundResolved and (record.soundResolved - record.euiReady) or nil
    local totalDelay = record.euiReady and (record.playCalled - record.euiReady) or nil
    print(string.format(
        "[EUIVE DEBUG] spell=%d eui_ready=%s sound_resolved=%s play_called=%.3f resolve_delay=%s total_delay=%s",
        tonumber(record.spellID) or 0,
        record.euiReady and string.format("%.3f", record.euiReady) or "unavailable",
        record.soundResolved and string.format("%.3f", record.soundResolved) or "unavailable",
        record.playCalled,
        resolveDelay and string.format("%.3f", resolveDelay) or "unavailable",
        totalDelay and string.format("%.3f", totalDelay) or "unavailable"
    ))
    return true, record
end

function Registry:GetTimingRecord(soundKey)
    return self._timingBySoundKey and self._timingBySoundKey[NormalizeSoundKey(soundKey)] or nil
end

function Registry:EnsureTimingHook()
    if self._timingHookInstalled or not TimingDebugEnabled() or type(hooksecurefunc) ~= "function" then
        return self._timingHookInstalled == true
    end
    hooksecurefunc("PlaySoundFile", function(path)
        local resolvedAt = NowPrecise()
        local normalizedPath = NormalizePath(path)
        local key = NS.ResolvedSoundKeysByPath[normalizedPath:lower()]
        if key and TimingDebugEnabled() then
            local record = Registry:GetTimingRecord(key)
            local spellID = record and record.spellID or NS.ResolvedSoundSpellIDs[key] or 0
            Registry:RecordSoundResolved(spellID, key, resolvedAt)
            Registry:RecordPlayCalled(spellID, key, NowPrecise())
        end
    end)
    self._timingHookInstalled = true
    return true
end

function Registry:EnsureSharedMediaCallback()
    if self._sharedMediaCallbackInstalled then return true end
    local lsm = GetLSM()
    if not (lsm and type(lsm.RegisterCallback) == "function") then return false end
    self._sharedMediaCallbackOwner = self._sharedMediaCallbackOwner or {}
    lsm.RegisterCallback(self._sharedMediaCallbackOwner, "LibSharedMedia_Registered", function(_, mediaType, key)
        if tostring(mediaType or "") ~= "sound" then return end
        local path = lsm.Fetch and lsm:Fetch("sound", key, true) or nil
        if path then Registry:CacheResolvedPath(key, path) end
    end)
    self._sharedMediaCallbackInstalled = true
    return true
end

function Registry:ResolveSoundPath(entry)
    if type(entry) ~= "table" then return "" end
    local source = tostring(entry.soundSource or "custom")
    if source == "tts" or tostring(entry.notifyMode or "") == "tts" then return "" end
    if source == "sharedmedia" then
        local lsm = GetLSM()
        local key = tostring(entry.sharedMediaSound or "")
        local cached = NS.ResolvedSoundPaths[NormalizeSoundKey(key)]
        if cached then return cached end
        local path = lsm and lsm.Fetch and lsm:Fetch("sound", key, true) or nil
        path = NormalizePath(path)
        if path ~= "" then self:CacheResolvedPath(key, path) end
        return path
    end
    local path = source == "builtin" and (entry.builtinSoundPath or entry.soundPath or entry.customSoundPath)
        or (entry.customSoundPath or entry.soundPath or entry.builtinSoundPath)
    return NormalizePath(path)
end

function Registry:BuildStableSoundKey(entry)
    if type(entry) ~= "table" then return nil end
    local source = tostring(entry.soundSource or "custom")
    if source == "sharedmedia" then
        local name = tostring(entry.sharedMediaSound or "")
        return name ~= "" and name or nil
    end
    local path = self:ResolveSoundPath(entry)
    if path == "" then return nil end
    local bridge = Bridge()
    if source == "builtin" and bridge then
        local key = bridge:ResolveBundledSoundKey(path)
        if key then return key end
    end
    return bridge and bridge:ResolveCustomSoundKey(path) or nil
end

local function DirectRegister(key, path)
    local lsm = GetLSM()
    if not lsm then return false, false end
    local current = lsm.Fetch and lsm:Fetch("sound", key, true) or nil
    local changed = current ~= path
    if current == nil then
        local ok = pcall(lsm.Register, lsm, "sound", key, path)
        return ok, changed
    end
    if changed then
        local sounds = lsm.HashTable and lsm:HashTable("sound") or (lsm.MediaTable and lsm.MediaTable.sound)
        if type(sounds) ~= "table" then return false, false end
        sounds[key] = path
        if lsm.callbacks and lsm.callbacks.Fire then pcall(lsm.callbacks.Fire, lsm.callbacks, "LibSharedMedia_Registered", "sound", key) end
    end
    return true, changed
end

function Registry:RegisterEntry(entry)
    self:EnsureSharedMediaCallback()
    self:EnsureTimingHook()
    local key = self:BuildStableSoundKey(entry)
    local source = tostring(entry.soundSource or "custom")
    if source == "sharedmedia" then
        local readiness = self:IsSharedMediaReady(entry)
        if readiness ~= "sharedmedia_ready" then return nil, readiness, false, false end
        entry.soundKey = key
        entry.requiresReload = false
        self:CacheResolvedPath(key, self:ResolveSoundPath(entry))
        NS.ResolvedSoundSpellIDs[NormalizeSoundKey(key)] = tonumber(entry.spellId) or 0
        return "sm:" .. key, readiness, false, true
    end

    local path = self:ResolveSoundPath(entry)
    if not key or path == "" then return nil, "invalid_path", false, false end

    local bridge = Bridge()
    local bridgeStatus
    if bridge then
        local _, status = bridge:RegisterSavedEntry(entry)
        bridgeStatus = status
    end
    local ok, mediaChanged = DirectRegister(key, path)
    if not ok then return nil, "invalid_path", false, false end
    local registeredBeforeEUI = bridge and bridge:IsSoundRegisteredBeforeEUI(key) == true or false
    local cdmLoaded = bridge and bridge:IsCDMLoaded() == true or false
    local nativeReady = not cdmLoaded or registeredBeforeEUI
    local status
    if registeredBeforeEUI then status = "registered_before_eui"
    else status = cdmLoaded and "requires_reload" or (bridgeStatus or "registered_late") end
    if cdmLoaded and not registeredBeforeEUI then status, nativeReady = "requires_reload", false end
    entry.soundKey = key
    entry.registeredBeforeEUI = registeredBeforeEUI
    entry.requiresReload = not nativeReady
    self:CacheResolvedPath(key, path)
    NS.ResolvedSoundSpellIDs[NormalizeSoundKey(key)] = tonumber(entry.spellId) or 0
    return "sm:" .. key, status, mediaChanged, nativeReady
end

function Registry:IsSharedMediaReady(entry)
    local key = type(entry) == "table" and tostring(entry.sharedMediaSound or "") or ""
    if key == "" then return "sharedmedia_missing" end
    local path = NS.ResolvedSoundPaths[NormalizeSoundKey(key)]
    if not path then
        local lsm = GetLSM()
        path = lsm and lsm.Fetch and lsm:Fetch("sound", key, true) or nil
    end
    entry.bootstrapMediaMissing = path == nil or nil
    if not path then return "sharedmedia_missing" end
    entry.soundKey = key
    entry.requiresReload = false
    self:CacheResolvedPath(key, path)
    return "sharedmedia_ready"
end

function Registry:GetNativeReadiness(entry)
    if tostring(entry and entry.soundSource or "") == "sharedmedia" then
        return self:IsSharedMediaReady(entry) == "sharedmedia_ready" and "ready" or "sharedmedia_missing"
    end
    local _, status, _, nativeReady = self:RegisterEntry(entry)
    if status == "invalid_path" or status == "sharedmedia_missing" then return status end
    if not nativeReady then return "requires_reload" end
    local bridge = Bridge()
    if not (bridge and bridge:IsCDMLoaded()) then return "ready" end
    if entry.preseededBeforeCDM == true then return "ready" end
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local family = (trigger == "buffGain" or trigger == "buffLoss") and "buff" or "cd"
    if bridge:IsFamilyArmed(family) then return "ready" end
    return "requires_reload"
end

function Registry:RegisterAllSavedEntries()
    self:EnsureSharedMediaCallback()
    self:EnsureTimingHook()
    local bridge = Bridge()
    if bridge then bridge:RegisterAllSavedEntries() end
    local db = rawget(_G, "EllesmereUIVEDB")
    local registered, reloadRequired = 0, 0
    for _, classMap in pairs(type(db) == "table" and type(db.specConfigs) == "table" and db.specConfigs or {}) do
        for _, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                if type(entry) == "table" and entry.entryType == "euiVoice" and entry.voiceEnabled ~= false then
                    local value = self:RegisterEntry(entry)
                    if value then registered = registered + 1 end
                    if self:GetNativeReadiness(entry) == "requires_reload" then reloadRequired = reloadRequired + 1 end
                end
            end
        end
    end
    return registered, reloadRequired
end
