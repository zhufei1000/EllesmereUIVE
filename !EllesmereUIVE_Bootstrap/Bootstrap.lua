local NS = _G.EllesmereUIVEBootstrapNS or {}
_G.EllesmereUIVEBootstrapNS = NS

local API = _G.EllesmereUIVEBootstrapAPI or {}
_G.EllesmereUIVEBootstrapAPI = API

NS.Runtime = NS.Runtime or {
    soundsRegisteredBeforeEUI = false,
    databasePreseededBeforeCDM = false,
    cdmLoaded = false,
    armedFamilies = { cd = false, buff = false },
}
NS.RegisteredBeforeEUI = NS.RegisteredBeforeEUI or {}
NS.ManifestByPath = NS.ManifestByPath or {}
NS.ManifestByKey = NS.ManifestByKey or {}

local function AddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) == true end
    local legacy = rawget(_G, "IsAddOnLoaded")
    return type(legacy) == "function" and legacy(name) == true
end

local function NormalizePath(path)
    path = tostring(path or ""):match("^%s*(.-)%s*$") or ""
    path = path:gsub("/", "\\"):gsub("\\+", "\\")
    return path
end

local function HashPath(path)
    local normalized = NormalizePath(path):lower()
    local hash = 5381
    for index = 1, #normalized do
        hash = (hash * 33 + normalized:byte(index)) % 4294967296
    end
    return string.format("%08X", hash)
end

local function GetLSM()
    local libStub = rawget(_G, "LibStub")
    return type(libStub) == "table" and libStub:GetLibrary("LibSharedMedia-3.0", true) or nil
end

for _, item in ipairs(NS.SoundManifest or {}) do
    if type(item) == "table" and type(item.key) == "string" and type(item.path) == "string" then
        NS.ManifestByPath[NormalizePath(item.path):lower()] = item
        NS.ManifestByKey[item.key] = item
    end
end

local function ResolveBundledSound(path)
    return NS.ManifestByPath[NormalizePath(path):lower()]
end

local function RegisterMedia(key, path, beforeEUI)
    local lsm = GetLSM()
    if not lsm or type(key) ~= "string" or key == "" or type(path) ~= "string" or path == "" then return false end
    local current = lsm.Fetch and lsm:Fetch("sound", key, true) or nil
    local ok = current == path or pcall(lsm.Register, lsm, "sound", key, path)
    if ok and beforeEUI then NS.RegisteredBeforeEUI[key] = true end
    return ok
end

local function ResolveEntryPath(entry)
    local source = tostring(entry and entry.soundSource or "custom")
    if source == "builtin" then
        return NormalizePath(entry.builtinSoundPath or entry.soundPath or entry.customSoundPath)
    end
    return NormalizePath(entry and (entry.customSoundPath or entry.soundPath or entry.builtinSoundPath) or "")
end

local function RegisterBundledSounds()
    local beforeEUI = not AddOnLoaded("EllesmereUICooldownManager")
    local count = 0
    for _, item in ipairs(NS.SoundManifest or {}) do
        if RegisterMedia(item.key, item.path, beforeEUI) then count = count + 1 end
    end
    if beforeEUI and count > 0 then NS.Runtime.soundsRegisteredBeforeEUI = true end
    return count
end

local function RegisterSavedEntry(entry)
    if type(entry) ~= "table" or entry.entryType ~= "euiVoice" or entry.enabled == false or entry.voiceEnabled == false then
        return nil, "disabled"
    end
    local source = tostring(entry.soundSource or "custom")
    if source == "sharedmedia" then
        local key = tostring(entry.sharedMediaSound or "")
        local lsm = GetLSM()
        local path = lsm and lsm.Fetch and lsm:Fetch("sound", key, true) or nil
        entry.bootstrapMediaMissing = path == nil
        if not path then return nil, "sharedmedia_missing" end
        entry.soundKey = key
        entry.registeredBeforeEUI = not AddOnLoaded("EllesmereUICooldownManager")
        if entry.registeredBeforeEUI then NS.RegisteredBeforeEUI[key] = true end
        return key, "sharedmedia_ready"
    end

    local path = ResolveEntryPath(entry)
    if path == "" then return nil, "invalid_path" end
    local manifest = source == "builtin" and ResolveBundledSound(path) or nil
    local key = manifest and manifest.key or ("EUIVE_CUSTOM_" .. HashPath(path))
    local beforeEUI = not AddOnLoaded("EllesmereUICooldownManager")
    if not RegisterMedia(key, manifest and manifest.path or path, beforeEUI) then return nil, "invalid_path" end
    entry.soundKey = key
    entry.registeredBeforeEUI = beforeEUI
    entry.bootstrapMediaMissing = nil
    return key, beforeEUI and "registered_before_eui" or "registered_late"
end

local function RegisterSavedCustomSounds()
    local db = rawget(_G, "EllesmereUIVEDB")
    local count = 0
    for _, classMap in pairs(type(db) == "table" and type(db.specConfigs) == "table" and db.specConfigs or {}) do
        for _, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                if RegisterSavedEntry(entry) then count = count + 1 end
            end
        end
    end
    return count
end

function API.IsSoundRegisteredBeforeEUI(soundKey)
    soundKey = tostring(soundKey or ""):gsub("^sm:", "")
    return NS.RegisteredBeforeEUI[soundKey] == true
end

function API.ResolveBundledSoundKey(path)
    local item = ResolveBundledSound(path)
    return item and item.key or nil
end

function API.ResolveCustomSoundKey(path)
    path = NormalizePath(path)
    return path ~= "" and ("EUIVE_CUSTOM_" .. HashPath(path)) or nil
end

function API.RegisterSavedEntry(entry)
    return RegisterSavedEntry(entry)
end

function API.RegisterAllSavedEntries()
    return RegisterSavedCustomSounds()
end

function API.IsCDMLoaded() return NS.Runtime.cdmLoaded == true end
function API.WasDatabasePreseededBeforeCDM() return NS.Runtime.databasePreseededBeforeCDM == true end
function API.IsFamilyArmed(family) return NS.Runtime.armedFamilies[tostring(family or "")] == true end
function API.NormalizePath(path) return NormalizePath(path) end
function API.HashPath(path) return HashPath(path) end
function API.GetRuntimeStatus() return NS.Runtime end

NS.Runtime.cdmLoaded = AddOnLoaded("EllesmereUICooldownManager")
RegisterBundledSounds()
RegisterSavedCustomSounds()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "EllesmereUICooldownManager" then NS.Runtime.cdmLoaded = true end
end)
