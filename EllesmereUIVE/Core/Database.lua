local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.Database = NS.Core.Database or {}
local Database = NS.Core.Database

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, child in pairs(value) do result[DeepCopy(key, seen)] = DeepCopy(child, seen) end
    return result
end

function Database:NormalizeEUITarget(entry)
    if type(entry) ~= "table" or entry.entryType ~= "euiVoice" then return end
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local family = tostring(entry.euiTargetFamily or "")
    local mode = tostring(entry.euiTargetMode or "")
    if mode == "forced" then
        if family ~= "cd" and family ~= "buff" and family ~= "custom" then
            entry.euiTargetMode = "auto"
            entry.euiTargetFamily = "auto"
        end
        entry.euiTriggerType = trigger
        return
    end
    -- In 1.0.1 only imported/internal data could deliberately select custom.
    if family == "custom" then
        entry.euiTargetMode = "forced"
        entry.euiTargetFamily = "custom"
        entry.euiTriggerType = trigger
        return
    end
    -- 1.0.1 UI-authored cd/buff values were defaults, not user overrides.
    entry.euiTargetMode = "auto"
    entry.euiTargetFamily = "auto"
    entry.euiTriggerType = trigger
end

function Database:NextEntryUID()
    EllesmereUIVEDB.entrySerial = math.max(0, tonumber(EllesmereUIVEDB.entrySerial) or 0) + 1
    return string.format("%08d", EllesmereUIVEDB.entrySerial)
end

local function CleanTransientEntryFields(entry)
    if type(entry) ~= "table" then return end
    entry.injected = nil
    entry.injectionStatus = nil
    entry.injectionStats = nil
    entry.requiresReload = nil
    if entry.entryUID then
        EllesmereUIVEDB.entrySerial = math.max(EllesmereUIVEDB.entrySerial, tonumber(entry.entryUID) or 0)
    else
        entry.entryUID = Database:NextEntryUID()
    end
    entry.entryUID = tostring(entry.entryUID)
    entry.objectType = tostring(entry.objectType or "spell")
    if entry.entryType == "euiVoice" and entry.objectType == "item" then
        local itemID = tonumber(entry.itemID or entry.inputID or entry.spellId)
        entry.itemID = itemID and itemID > 0 and math.floor(itemID) or nil
        entry.triggerSpellID = nil
        entry.triggerSpellId = nil
        entry.triggerSpellName = nil
        entry.resolvedSpellID = nil
        entry.resolvedSpellName = nil
    end
    entry.enabled = entry.enabled ~= false and entry.voiceEnabled ~= false
    entry.voiceEnabled = entry.enabled
    Database:NormalizeEUITarget(entry)
end

function Database:Initialize()
    EllesmereUIVEDB = type(EllesmereUIVEDB) == "table" and EllesmereUIVEDB or {}
    local db = EllesmereUIVEDB
    db.schemaVersion = 2
    db.addon = "EllesmereUIVE"
    db.entrySerial = math.max(0, tonumber(db.entrySerial) or 0)
    db.specConfigs = type(db.specConfigs) == "table" and db.specConfigs or {}
    db.collectionData = type(db.collectionData) == "table" and db.collectionData or {}
    db.savedListOrder = type(db.savedListOrder) == "table" and db.savedListOrder or {}
    for _, classMap in pairs(db.specConfigs) do
        if type(classMap) == "table" then
            for _, entries in pairs(classMap) do
                if type(entries) == "table" then
                    for _, entry in pairs(entries) do CleanTransientEntryFields(entry) end
                end
            end
        end
    end
    db.bloodlust = type(db.bloodlust) == "table" and db.bloodlust or {}
    local bloodlust = db.bloodlust
    bloodlust.enabled = bloodlust.enabled ~= false
    bloodlust.voiceEnabled = bloodlust.voiceEnabled ~= false
    bloodlust.soundSource = tostring(bloodlust.soundSource or "custom")
    bloodlust.notifyMode = tostring(bloodlust.notifyMode or "sound")
    bloodlust.soundPath = tostring(bloodlust.soundPath or NS.Constants.DEFAULT_SOUND)
    bloodlust.customSoundPath = tostring(bloodlust.customSoundPath or bloodlust.soundPath)
    bloodlust.customSoundPaths = type(bloodlust.customSoundPaths) == "table" and bloodlust.customSoundPaths or { bloodlust.customSoundPath, "", "", "", "" }
    for i = 1, 5 do bloodlust.customSoundPaths[i] = tostring(bloodlust.customSoundPaths[i] or "") end
    for i = #bloodlust.customSoundPaths, 6, -1 do bloodlust.customSoundPaths[i] = nil end
    bloodlust.ttsText = tostring(bloodlust.ttsText or "Bloodlust")
    bloodlust.ttsRate = math.max(-10, math.min(10, tonumber(bloodlust.ttsRate) or 0))
    db.settings = type(db.settings) == "table" and db.settings or {}
    local settings = db.settings
    if settings.autoSyncSpec == nil then settings.autoSyncSpec = true end
    if settings.syncOnLogin == nil then settings.syncOnLogin = true end
    if settings.autoInjectOnSave == nil then settings.autoInjectOnSave = true end
    if settings.overwriteEUI == nil then settings.overwriteEUI = false end
    settings.soundChannel = tostring(settings.soundChannel or "Master")
    settings.showLoadMessage = settings.showLoadMessage ~= false
    db.minimap = type(db.minimap) == "table" and db.minimap or { hide = false, minimapPos = 225 }
    db.euiInjectionRecords = type(db.euiInjectionRecords) == "table" and db.euiInjectionRecords or {}
    return db
end

Database.DeepCopy = DeepCopy
