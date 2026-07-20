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

local function ExportEntry(entry, classID, specID, originalIndex)
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
        originalIndex = tonumber(originalIndex),
    }
    return item
end

function ImportExport:BuildPayload()
    local db = EllesmereUIVEDB
    local eui, cast = {}, {}
    for classID, classMap in pairs(db.specConfigs or {}) do
        for specID, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for index, entry in pairs(type(entries) == "table" and entries or {}) do
                if entry.entryType == "euiVoice" then eui[#eui + 1] = ExportEntry(entry, classID, specID, index)
                elseif entry.entryType == "cast" then cast[#cast + 1] = ExportEntry(entry, classID, specID, index) end
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
    local originalIndex
    for index, current in pairs(NS:GetScopeList(classID, specID, false)) do
        if current == entry then originalIndex = index break end
    end
    local exported = ExportEntry(entry, classID, specID, originalIndex)
    if entry.entryType == "euiVoice" then payload.euiVoiceEntries[1] = exported
    elseif entry.entryType == "cast" then payload.castEntries[1] = exported
    else return nil, "unsupported entry type" end
    return payload
end

function ImportExport:BuildCollectionPayload(classID, specID, groupID)
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    groupID = tostring(groupID or "")
    local payload = EmptyPayload("collection")
    local classCollections = EllesmereUIVEDB.collectionData and EllesmereUIVEDB.collectionData[classID]
    local scopeCollection = type(classCollections) == "table" and classCollections[specID] or nil
    local groups = type(scopeCollection) == "table" and scopeCollection.groups or nil
    if groupID == "" or type(groups) ~= "table" or type(groups[groupID]) ~= "table" then
        return nil, "collection is unavailable"
    end

    payload.collectionClassID = classID
    payload.collectionSpecID = specID
    payload.collectionRootGroupID = groupID
    payload.collectionGroups = {}
    local exportedEntryKeys = {}
    local entryMap = NS:GetScopeList(classID, specID, false)

    local function collectGroup(currentID, seen)
        currentID = tostring(currentID or "")
        if seen[currentID] or type(groups[currentID]) ~= "table" then return end
        seen[currentID] = true
        local group = groups[currentID]
        payload.collectionGroups[currentID] = Copy(group)
        for _, ref in ipairs(type(group.entries) == "table" and group.entries or {}) do
            local childID = tostring(ref or ""):match("^group:%-?%d+:%-?%d+:(.+)$")
            if childID and type(groups[childID]) == "table" then
                collectGroup(childID, seen)
            else
                local refClass, refSpec, refIndex = tostring(ref or ""):match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
                refClass, refSpec, refIndex = tonumber(refClass), tonumber(refSpec), tonumber(refIndex)
                if not refIndex and tonumber(ref) then
                    refClass, refSpec, refIndex = classID, specID, tonumber(ref)
                end
                local key = refIndex and string.format("%d:%d:%d", refClass or classID, refSpec or specID, refIndex) or nil
                local entry = refIndex and entryMap[refIndex] or nil
                if key and type(entry) == "table" and not exportedEntryKeys[key] then
                    local exported = ExportEntry(entry, classID, specID, refIndex)
                    exported.originalKey = key
                    if entry.entryType == "euiVoice" then payload.euiVoiceEntries[#payload.euiVoiceEntries + 1] = exported
                    elseif entry.entryType == "cast" then payload.castEntries[#payload.castEntries + 1] = exported end
                    exportedEntryKeys[key] = true
                end
            end
        end
    end

    collectGroup(groupID, {})
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

local function EntryKey(classID, specID, index)
    return string.format("%d:%d:%d", tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0)
end

local function FindEntryIndex(classID, specID, wanted)
    for index, entry in pairs(NS:GetScopeList(classID, specID, false)) do
        if entry == wanted then return tonumber(index) end
    end
end

local function StoreImportedEntry(source, forcedType, preferOriginalIndex, reuseDuplicate)
    local entry = ImportEntry(source, forcedType)
    if not entry then return nil end
    local classID, specID = tonumber(source.classID) or 0, tonumber(source.specID) or 0
    if reuseDuplicate and type(NS.FindDuplicate) == "function" then
        local duplicate = NS:FindDuplicate(classID, specID, entry)
        if duplicate then
            local duplicateClass, duplicateSpec = NS:FindEntryScope(duplicate)
            local duplicateIndex = FindEntryIndex(duplicateClass, duplicateSpec, duplicate)
            return duplicate, duplicateClass, duplicateSpec, duplicateIndex, false
        end
    end
    local list = NS:GetScopeList(classID, specID, true)
    local index = preferOriginalIndex and tonumber(source.originalIndex) or nil
    if not index or index <= 0 or list[index] ~= nil then
        index = 1
        while list[index] ~= nil do index = index + 1 end
    end
    entry.entryUID = NS.Core.Database:NextEntryUID()
    entry.entryUID = tostring(entry.entryUID)
    entry.classID, entry.specID = classID, specID
    entry.injected, entry.injectionStatus = nil, nil
    list[index] = entry
    return entry, classID, specID, index, true
end

local function FindGroupByName(scope, name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return nil end
    for groupID, group in pairs(type(scope) == "table" and scope.groups or {}) do
        if type(group) == "table" and tostring(group.name or ""):match("^%s*(.-)%s*$") == name then
            return tostring(groupID)
        end
    end
end

local function ImportCollectionGroups(payload, keyMap)
    local classID = tonumber(payload.collectionClassID) or 0
    local specID = tonumber(payload.collectionSpecID) or 0
    local oldRootID = tostring(payload.collectionRootGroupID or "")
    local sourceGroups = type(payload.collectionGroups) == "table" and payload.collectionGroups or nil
    if not sourceGroups or oldRootID == "" or type(sourceGroups[oldRootID]) ~= "table" then return false end

    EllesmereUIVEDB.collectionData[classID] = EllesmereUIVEDB.collectionData[classID] or {}
    local scope = EllesmereUIVEDB.collectionData[classID][specID]
    if type(scope) ~= "table" then scope = { root = {}, groups = {} }; EllesmereUIVEDB.collectionData[classID][specID] = scope end
    scope.root = type(scope.root) == "table" and scope.root or {}
    scope.groups = type(scope.groups) == "table" and scope.groups or {}

    local groupIDMap = {}
    for oldID, group in pairs(sourceGroups) do
        if type(group) == "table" then
            oldID = tostring(oldID)
            local newID
            if oldID == oldRootID then newID = FindGroupByName(scope, group.name) end
            if not newID then
                EllesmereUIVEDB.collectionSerial = math.max(0, tonumber(EllesmereUIVEDB.collectionSerial) or 0) + 1
                newID = "g" .. tostring(EllesmereUIVEDB.collectionSerial)
            end
            groupIDMap[oldID] = newID
        end
    end

    for oldID, group in pairs(sourceGroups) do
        local newID = groupIDMap[tostring(oldID)]
        if newID and type(group) == "table" then
            local refs = {}
            for _, oldRef in ipairs(type(group.entries) == "table" and group.entries or {}) do
                local childID = tostring(oldRef or ""):match("^group:%-?%d+:%-?%d+:(.+)$")
                if childID and groupIDMap[childID] then
                    refs[#refs + 1] = string.format("group:%d:%d:%s", classID, specID, groupIDMap[childID])
                else
                    local oldClass, oldSpec, oldIndex = tostring(oldRef or ""):match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
                    local oldKey = oldIndex and EntryKey(oldClass, oldSpec, oldIndex) or nil
                    local newKey = oldKey and keyMap[oldKey] or nil
                    if newKey then refs[#refs + 1] = newKey end
                end
            end
            scope.groups[newID] = {
                name = tostring(group.name or "Imported Collection"),
                iconID = tonumber(group.iconID),
                collapsed = group.collapsed == true,
                entries = refs,
            }
        end
    end

    local newRootID = groupIDMap[oldRootID]
    if newRootID then
        local present = false
        for _, item in ipairs(scope.root) do
            if type(item) == "table" and item.type == "group" and tostring(item.id) == newRootID then present = true break end
        end
        if not present then scope.root[#scope.root + 1] = { type = "group", id = newRootID } end
    end
    local store = NS.CollectionStore
    if store and type(store.NormalizeCollectionScope) == "function" and NS.API then
        store.NormalizeCollectionScope(scope, NS:GetScopeList(classID, specID, false), classID, specID, NS.API)
    end
    return true
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
    local added, keyMap = 0, {}
    local function importList(list, forcedType)
        for _, source in ipairs(type(list) == "table" and list or {}) do
            local _, newClass, newSpec, newIndex, wasAdded = StoreImportedEntry(source, forcedType, replaceAll, not replaceAll)
            if newIndex then
                local oldKey = tostring(source.originalKey or "")
                if oldKey == "" and tonumber(source.originalIndex) then
                    oldKey = EntryKey(source.classID, source.specID, source.originalIndex)
                end
                if oldKey ~= "" then keyMap[oldKey] = EntryKey(newClass, newSpec, newIndex) end
                if wasAdded then added = added + 1 end
            end
        end
    end
    importList(payload.euiVoiceEntries, "euiVoice")
    importList(payload.castEntries, "cast")
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
    elseif mode == "collection" and type(payload.collectionGroups) == "table" then
        ImportCollectionGroups(payload, keyMap)
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
    -- Imported EUI voices stay visible in the shared saved-list immediately,
    -- but synchronization remains an explicit toolbar action.
    NS.pendingEUISync = false
    if ((type(NS.pendingEUIRemovals) == "table" and #NS.pendingEUIRemovals > 0) or NS.pendingEUIRefresh == true)
        and type(NS.ProcessPendingEUISync) == "function" then
        NS:ProcessPendingEUISync()
    end
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
