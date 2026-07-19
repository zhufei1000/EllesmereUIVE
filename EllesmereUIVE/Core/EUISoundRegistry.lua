local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.EUISoundRegistry = NS.Core.EUISoundRegistry or {}
local Registry = NS.Core.EUISoundRegistry

local PREFIX = { cdReady = "CD", buffGain = "GAIN", buffLoss = "LOSS" }

function Registry:BuildStableSoundKey(entry)
    if type(entry) ~= "table" or not entry.entryUID then return nil end
    local prefix = PREFIX[entry.euiTriggerType]
    if not prefix then return nil end
    return string.format("EUIVE_%s_%s", prefix, tostring(entry.entryUID):gsub("[^%w]", ""))
end

function Registry:ResolveSoundPath(entry)
    if type(entry) ~= "table" then return "" end
    local source = tostring(entry.soundSource or "custom")
    if source == "tts" or tostring(entry.notifyMode or "") == "tts" then return "" end
    local player = NS.Core and NS.Core.VoicePlayer
    return player and player:ResolvePath(entry) or ""
end

function Registry:RegisterEntry(entry)
    local key = self:BuildStableSoundKey(entry)
    local path = self:ResolveSoundPath(entry)
    if not key or path == "" then return nil, "invalid_path" end
    local libStub = rawget(_G, "LibStub")
    local lsm = type(libStub) == "table" and libStub:GetLibrary("LibSharedMedia-3.0", true) or nil
    if not lsm then return nil, "invalid_path" end
    local current = lsm.Fetch and lsm:Fetch("sound", key, true) or nil
    local mediaChanged = current ~= path
    local ok
    if current ~= nil then
        local sounds = lsm.HashTable and lsm:HashTable("sound") or (lsm.MediaTable and lsm.MediaTable.sound)
        if type(sounds) ~= "table" then return nil, "invalid_path" end
        sounds[key] = path
        if mediaChanged and lsm.callbacks and lsm.callbacks.Fire then
            pcall(lsm.callbacks.Fire, lsm.callbacks, "LibSharedMedia_Registered", "sound", key)
        end
        ok = true
    else
        ok = pcall(lsm.Register, lsm, "sound", key, path)
    end
    if not ok then return nil, "invalid_path" end
    entry.soundKey = key
    return "sm:" .. key, mediaChanged and "registered" or "up_to_date", mediaChanged
end

function Registry:RegisterAllSavedEntries()
    local db = rawget(_G, "EllesmereUIVEDB")
    local registered = 0
    for _, classMap in pairs(type(db) == "table" and type(db.specConfigs) == "table" and db.specConfigs or {}) do
        for _, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                if type(entry) == "table" and entry.entryType == "euiVoice" and entry.voiceEnabled ~= false then
                    if self:RegisterEntry(entry) then registered = registered + 1 end
                end
            end
        end
    end
    return registered
end
