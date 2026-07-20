local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.ImportCollectionProcessor = NS.ImportCollectionProcessor or {}

local Processor = NS.ImportCollectionProcessor
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local CollectionStore = NS.CollectionStore or {}
local ImportEntryProcessor = NS.ImportEntryProcessor or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function NormalizeIconID(value)
    if Utils.NormalizeIconID then
        return Utils.NormalizeIconID(value)
    end
    local iconID = tonumber(TrimText(value))
    if iconID and iconID > 0 then
        return math.floor(iconID)
    end
    return nil
end

local function GetApi()
    return NS.API
end

local function BuildEntryKey(classID, specID, index)
    if CollectionStore.BuildEntryKey then
        return CollectionStore.BuildEntryKey(classID, specID, index)
    end
    return string.format("%d:%d:%d", tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0)
end

local function BuildGroupKey(classID, specID, groupID)
    if CollectionStore.BuildGroupKey then
        return CollectionStore.BuildGroupKey(classID, specID, groupID)
    end
    return string.format("group:%d:%d:%s", tonumber(classID) or 0, tonumber(specID) or 0, tostring(groupID or ""))
end

local function GroupRefToKey(scopeClassID, scopeSpecID, ref)
    if CollectionStore.GroupRefToKey then
        return CollectionStore.GroupRefToKey(scopeClassID, scopeSpecID, ref)
    end
    return nil
end

local function EntryRefToKey(scopeClassID, scopeSpecID, ref)
    if CollectionStore.EntryRefToKey then
        return CollectionStore.EntryRefToKey(scopeClassID, scopeSpecID, ref)
    end
    return nil
end

local function EnsureRootDB()
    if CollectionStore.EnsureRootDB then
        return CollectionStore.EnsureRootDB()
    end
    if type(EllesmereUIVEDB) ~= "table" then
        EllesmereUIVEDB = {}
    end
    return EllesmereUIVEDB
end

local function EnsureCollectionScope(classID, specID)
    if CollectionStore.EnsureCollectionScope then
        return CollectionStore.EnsureCollectionScope(classID, specID)
    end
    return nil
end

local function NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    if CollectionStore.NormalizeCollectionScope then
        return CollectionStore.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, GetApi())
    end
    return scope
end

local function ImportEntryRecord(record, preferImportedIndex)
    if ImportEntryProcessor and type(ImportEntryProcessor.ImportEntryRecord) == "function" then
        return ImportEntryProcessor:ImportEntryRecord(record, preferImportedIndex)
    end
    return nil
end

local function FindGroupByName(scope, name)
    name = TrimText(name)
    if name == "" or type(scope) ~= "table" then
        return nil
    end
    for groupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and TrimText(group.name) == name then
            return tostring(groupID)
        end
    end
    return nil
end

local function EnsureGroupInRoot(scope, groupID)
    if type(scope) ~= "table" or tostring(groupID or "") == "" then
        return
    end
    for _, item in ipairs(scope.root or {}) do
        if type(item) == "table" and item.type == "group" and tostring(item.id or "") == tostring(groupID) then
            return
        end
    end
    scope.root[#scope.root + 1] = { type = "group", id = tostring(groupID) }
end

function Processor:Import(payload)
    local api = GetApi()
    if not api or type(payload.group) ~= "table" then
        return false, 0
    end
    local classID = tonumber(payload.classID) or 0
    local specID = tonumber(payload.specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    if classID < 0 or specID < 0 then
        return false, 0
    end

    local keyMap = {}
    local imported = 0
    for _, record in ipairs(payload.entries or {}) do
        local newKey = ImportEntryRecord(record, true)
        if newKey then
            imported = imported + 1
            if record.originalKey then
                keyMap[tostring(record.originalKey)] = newKey
            end
            local oldKey = BuildEntryKey(record.classID, record.specID, record.index)
            keyMap[tostring(oldKey)] = newKey
        end
    end

    local scope = EnsureCollectionScope(classID, specID)
    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)
    local db = EnsureRootDB()

    local payloadGroups = type(payload.groups) == "table" and payload.groups or nil
    if payloadGroups then
        local rootOldID = tostring(payload.rootGroupID or "")
        if rootOldID == "" then
            rootOldID = "root"
            payloadGroups[rootOldID] = payload.group
        end

        local groupIDMap = {}
        for oldID, group in pairs(payloadGroups) do
            if type(group) == "table" then
                oldID = tostring(oldID)
                local newID
                if oldID == rootOldID then
                    local name = TrimText(group.name)
                    if name == "" then
                        name = L("IMPORT_COLLECTION_NAME")
                    end
                    newID = FindGroupByName(scope, name)
                end
                if not newID then
                    db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
                    newID = "g" .. tostring(db.collectionSerial)
                end
                groupIDMap[oldID] = newID
            end
        end

        for oldID, group in pairs(payloadGroups) do
            if type(group) == "table" then
                oldID = tostring(oldID)
                local newID = groupIDMap[oldID]
                if newID then
                    local remappedEntries = {}
                    for _, oldRef in ipairs(group.entries or {}) do
                        local oldGroupKey, oldGroupClassID, oldGroupSpecID, oldGroupID = GroupRefToKey(classID, specID, oldRef)
                        if oldGroupKey and oldGroupID ~= "" then
                            local mappedGroupID = groupIDMap[tostring(oldGroupID)]
                            if mappedGroupID then
                                remappedEntries[#remappedEntries + 1] = BuildGroupKey(classID, specID, mappedGroupID)
                            end
                        else
                            local oldKey = EntryRefToKey(classID, specID, oldRef)
                            local newKey = oldKey and keyMap[tostring(oldKey)] or nil
                            if newKey then
                                remappedEntries[#remappedEntries + 1] = newKey
                            end
                        end
                    end
                    scope.groups[newID] = {
                        name = TrimText(group.name) ~= "" and TrimText(group.name) or L("IMPORT_COLLECTION_NAME"),
                        iconID = NormalizeIconID(group.iconID),
                        collapsed = group.collapsed == true,
                        entries = remappedEntries,
                    }
                end
            end
        end

        local rootNewID = groupIDMap[rootOldID]
        if rootNewID then
            EnsureGroupInRoot(scope, rootNewID)
        end
        NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)
        return true, imported
    end

    local name = TrimText(payload.group.name)
    if name == "" then
        name = L("IMPORT_COLLECTION_NAME")
    end
    local groupID = FindGroupByName(scope, name)
    if not groupID then
        db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
        groupID = "g" .. tostring(db.collectionSerial)
    end

    local groupEntries = {}
    for _, oldRef in ipairs(payload.group.entries or {}) do
        local oldKey = EntryRefToKey(classID, specID, oldRef)
        local newKey = oldKey and keyMap[tostring(oldKey)] or nil
        if newKey then
            groupEntries[#groupEntries + 1] = newKey
        end
    end

    scope.groups[groupID] = {
        name = name,
        iconID = NormalizeIconID(payload.group.iconID),
        collapsed = payload.group.collapsed == true,
        entries = groupEntries,
    }
    EnsureGroupInRoot(scope, groupID)
    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)
    return true, imported
end
