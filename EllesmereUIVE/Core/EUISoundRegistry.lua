local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.EUISoundRegistry = NS.Core.EUISoundRegistry or {}
local Registry = NS.Core.EUISoundRegistry

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

function Registry:ResolveSoundPath(entry)
    if type(entry) ~= "table" then return "" end
    local source = tostring(entry.soundSource or "custom")
    if source == "tts" or tostring(entry.notifyMode or "") == "tts" then return "" end
    if source == "sharedmedia" then
        local lsm = GetLSM()
        local key = tostring(entry.sharedMediaSound or "")
        local path = lsm and lsm.Fetch and lsm:Fetch("sound", key, true) or nil
        return NormalizePath(path)
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
    local key = self:BuildStableSoundKey(entry)
    local source = tostring(entry.soundSource or "custom")
    if source == "sharedmedia" then
        local readiness = self:IsSharedMediaReady(entry)
        if readiness ~= "sharedmedia_ready" then return nil, readiness, false, false end
        entry.soundKey = key
        entry.requiresReload = false
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
    return "sm:" .. key, status, mediaChanged, nativeReady
end

function Registry:IsSharedMediaReady(entry)
    local key = type(entry) == "table" and tostring(entry.sharedMediaSound or "") or ""
    if key == "" then return "sharedmedia_missing" end
    local lsm = GetLSM()
    local path = lsm and lsm.Fetch and lsm:Fetch("sound", key, true) or nil
    entry.bootstrapMediaMissing = path == nil or nil
    if not path then return "sharedmedia_missing" end
    entry.soundKey = key
    entry.requiresReload = false
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
