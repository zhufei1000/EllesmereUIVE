local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.ImportExport = NS.Core.ImportExport or {}
local ImportExport = NS.Core.ImportExport
local PREFIX = "!EUIVE:2!"

local function Libraries()
    local libStub = rawget(_G, "LibStub")
    if type(libStub) ~= "table" then return nil, nil end
    return libStub:GetLibrary("AceSerializer-3.0", true), libStub:GetLibrary("LibDeflate", true)
end

local function Copy(value)
    return NS.Core.Database.DeepCopy(value)
end

local function ExportEntry(entry, classID, specID)
    local item = {
        entryUID = entry.entryUID,
        entryType = entry.entryType,
        spellId = entry.spellId,
        triggerSpellID = entry.triggerSpellID,
        spellName = entry.spellName,
        objectType = entry.objectType,
        euiTriggerType = entry.euiTriggerType,
        euiTargetMode = entry.euiTargetMode,
        euiTargetFamily = entry.euiTargetFamily,
        soundSource = entry.soundSource,
        soundPath = entry.soundPath,
        builtinSoundPath = entry.builtinSoundPath,
        customSoundPath = entry.customSoundPath,
        sharedMediaSound = entry.sharedMediaSound,
        soundKey = entry.soundKey,
        notifyMode = entry.notifyMode,
        ttsText = entry.ttsText,
        ttsRate = entry.ttsRate,
        enabled = entry.enabled,
        voiceEnabled = entry.voiceEnabled,
        delayEnabled = entry.delayEnabled,
        delaySeconds = entry.delaySeconds,
        alertClassIDs = Copy(entry.alertClassIDs),
        alertSpecIDs = Copy(entry.alertSpecIDs),
        classID = tonumber(classID) or 0,
        specID = tonumber(specID) or 0,
    }
    return item
end

function ImportExport:BuildPayload()
    local db = EllesmereUIVEDB
    local eui, cast = {}, {}
    for classID, classMap in pairs(db.specConfigs or {}) do
        for specID, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                if entry.entryType == "euiVoice" then eui[#eui + 1] = ExportEntry(entry, classID, specID)
                elseif entry.entryType == "cast" then cast[#cast + 1] = ExportEntry(entry, classID, specID) end
            end
        end
    end
    return {
        schemaVersion = 2,
        addon = "EllesmereUIVE",
        exportMode = "full",
        euiVoiceEntries = eui,
        castEntries = cast,
        bloodlust = Copy(db.bloodlust or {}),
        settings = Copy(db.settings or {}),
        collectionData = Copy(db.collectionData or {}),
        savedListOrder = Copy(db.savedListOrder or {}),
    }
end

local function EmptyPayload(mode)
    return {
        schemaVersion = 2, addon = "EllesmereUIVE", exportMode = mode,
        euiVoiceEntries = {}, castEntries = {}, bloodlust = {}, settings = {}, collectionData = {}, savedListOrder = {},
    }
end

function ImportExport:BuildEntryPayload(entry)
    if type(entry) ~= "table" then return nil, "entry is unavailable" end
    local classID, specID = NS:FindEntryScope(entry)
    if classID == nil then return nil, "entry scope is unavailable" end
    local payload = EmptyPayload("single")
    local exported = ExportEntry(entry, classID, specID)
    if entry.entryType == "euiVoice" then payload.euiVoiceEntries[1] = exported
    elseif entry.entryType == "cast" then payload.castEntries[1] = exported
    else return nil, "unsupported entry type" end
    return payload
end

function ImportExport:BuildCollectionPayload(classID, specID)
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    local payload = EmptyPayload("collection")
    for _, entry in pairs(NS:GetScopeList(classID, specID, false)) do
        if type(entry) == "table" then
            local exported = ExportEntry(entry, classID, specID)
            if entry.entryType == "euiVoice" then payload.euiVoiceEntries[#payload.euiVoiceEntries + 1] = exported
            elseif entry.entryType == "cast" then payload.castEntries[#payload.castEntries + 1] = exported end
        end
    end
    local classCollections = EllesmereUIVEDB.collectionData and EllesmereUIVEDB.collectionData[classID]
    local scopeCollection = type(classCollections) == "table" and classCollections[specID] or nil
    if scopeCollection then
        payload.collectionData[classID] = { [specID] = Copy(scopeCollection) }
    end
    return payload
end

function ImportExport:Encode(payload)
    local serializer, deflate = Libraries()
    if not serializer or not deflate then return nil, "AceSerializer or LibDeflate is unavailable" end
    local serialized = serializer:Serialize(payload or self:BuildPayload())
    local compressed = deflate:CompressDeflate(serialized, { level = 9 })
    if type(compressed) ~= "string" then return nil, "compression failed" end
    return PREFIX .. deflate:EncodeForPrint(compressed)
end

function ImportExport:Decode(text)
    text = tostring(text or ""):gsub("%s+", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "unknown export prefix" end
    local serializer, deflate = Libraries()
    if not serializer or not deflate then return nil, "AceSerializer or LibDeflate is unavailable" end
    local compressed = deflate:DecodeForPrint(text:sub(#PREFIX + 1))
    if type(compressed) ~= "string" then return nil, "decode failed" end
    local serialized = deflate:DecompressDeflate(compressed)
    if type(serialized) ~= "string" then return nil, "decompression failed" end
    local ok, payload = serializer:Deserialize(serialized)
    if not ok or type(payload) ~= "table" then return nil, "invalid serialized payload" end
    return payload
end

local function ImportEntry(source, forcedType)
    if type(source) ~= "table" then return nil end
    local spellID = tonumber(source.spellId)
    if not spellID or spellID <= 0 then return nil end
    local entry = ExportEntry(source, nil, nil)
    entry.classID, entry.specID = nil, nil
    entry.entryUID = nil -- imports always receive a new local permanent identity
    entry.entryType = forcedType
    entry.spellId = spellID
    entry.objectType = tostring(source.objectType or "spell")
    entry.enabled = source.enabled ~= false and source.voiceEnabled ~= false
    entry.voiceEnabled = entry.enabled
    if forcedType == "euiVoice" then
        local trigger = tostring(source.euiTriggerType or "cdReady")
        if trigger ~= "cdReady" and trigger ~= "buffGain" and trigger ~= "buffLoss" then return nil end
        if source.soundSource == "tts" or source.notifyMode == "tts" then return nil end
        entry.euiTriggerType = trigger
        local sourceMode = tostring(source.euiTargetMode or "")
        local sourceFamily = tostring(source.euiTargetFamily or "")
        if sourceMode == "" then
            if sourceFamily == "custom" then
                entry.euiTargetMode, entry.euiTargetFamily = "forced", "custom"
            else
                entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto"
            end
        elseif sourceMode == "forced" and (sourceFamily == "cd" or sourceFamily == "buff" or sourceFamily == "custom") then
            entry.euiTargetMode, entry.euiTargetFamily = "forced", sourceFamily
        elseif sourceMode == "auto" and sourceFamily == "auto" then
            entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto"
        else
            entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto"
        end
        NS.Core.Database:NormalizeEUITarget(entry)
    else
        entry.triggerSpellID = tonumber(source.triggerSpellID) or spellID
        entry.delayEnabled = source.delayEnabled == true
        entry.delaySeconds = math.max(0, tonumber(source.delaySeconds) or 0)
    end
    return entry
end

function ImportExport:ImportPayload(payload)
    if type(payload) ~= "table" or payload.addon ~= "EllesmereUIVE" or tonumber(payload.schemaVersion) ~= 2 then
        return false, "unsupported schema"
    end
    local integration = NS.Integrations and NS.Integrations.EllesmereUI
    local removalChanged = false
    local mode = tostring(payload.exportMode or "full")
    if mode ~= "full" and mode ~= "single" and mode ~= "collection" then return false, "unsupported export mode" end
    local replaceAll = mode == "full"
    if replaceAll then
        for _, classMap in pairs(EllesmereUIVEDB.specConfigs or {}) do
            for _, entries in pairs(type(classMap) == "table" and classMap or {}) do
                for _, entry in pairs(type(entries) == "table" and entries or {}) do
                    if type(entry) == "table" and entry.entryType == "euiVoice" then
                        local snapshot = NS.SnapshotEntry(entry)
                        local removed, removeStatus, changed = integration:RemoveEntry(snapshot, true)
                        removalChanged = changed == true or removalChanged
                        if not removed and removeStatus ~= "removed" and removeStatus ~= "waiting_combat" then NS:QueueEUIRemoval(snapshot) end
                    end
                end
            end
        end
        EllesmereUIVEDB.specConfigs = {}
    end
    local added = 0
    for _, source in ipairs(type(payload.euiVoiceEntries) == "table" and payload.euiVoiceEntries or {}) do
        local entry = ImportEntry(source, "euiVoice")
        if entry and NS:AddEntry(tonumber(source.classID) or 0, tonumber(source.specID) or 0, entry) then added = added + 1 end
    end
    for _, source in ipairs(type(payload.castEntries) == "table" and payload.castEntries or {}) do
        local entry = ImportEntry(source, "cast")
        if entry and NS:AddEntry(tonumber(source.classID) or 0, tonumber(source.specID) or 0, entry) then added = added + 1 end
    end
    if replaceAll and type(payload.bloodlust) == "table" then
        EllesmereUIVEDB.bloodlust = Copy(payload.bloodlust)
        local paths = EllesmereUIVEDB.bloodlust.customSoundPaths
        if type(paths) ~= "table" then paths = { EllesmereUIVEDB.bloodlust.customSoundPath or EllesmereUIVEDB.bloodlust.soundPath or "" }; EllesmereUIVEDB.bloodlust.customSoundPaths = paths end
        for i = 1, 5 do paths[i] = tostring(paths[i] or "") end
        for i = #paths, 6, -1 do paths[i] = nil end
    end
    if replaceAll and type(payload.settings) == "table" then
        for key, value in pairs(payload.settings) do EllesmereUIVEDB.settings[key] = Copy(value) end
    end
    if replaceAll then
        EllesmereUIVEDB.collectionData = Copy(payload.collectionData or {})
        EllesmereUIVEDB.savedListOrder = Copy(payload.savedListOrder or {})
    elseif mode == "collection" and type(payload.collectionData) == "table" then
        for classID, classMap in pairs(payload.collectionData) do
            EllesmereUIVEDB.collectionData[classID] = EllesmereUIVEDB.collectionData[classID] or {}
            for specID, scope in pairs(type(classMap) == "table" and classMap or {}) do
                EllesmereUIVEDB.collectionData[classID][specID] = Copy(scope)
            end
        end
    end
    local _, reloadRequired = NS.Core.EUISoundRegistry:RegisterAllSavedEntries()
    local bridge = NS.Core and NS.Core.BootstrapBridge
    if bridge and not (InCombatLockdown and InCombatLockdown()) then bridge:PreseedCurrentScope() end
    NS:RebuildVoiceRuntime()
    NS.pendingEUIRefresh = removalChanged or NS.pendingEUIRefresh
    NS:RequestEUISync("IMPORT")
    if (tonumber(reloadRequired) or 0) > 0 then
        if NS.NotifyReloadRequiredOnce then NS:NotifyReloadRequiredOnce() end
        return true, added, "requires_reload"
    end
    return true, added, "native_ready"
end

function ImportExport:ImportText(text)
    local payload, err = self:Decode(text)
    if not payload then return false, err end
    return self:ImportPayload(payload)
end
