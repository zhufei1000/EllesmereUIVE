local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

local Store = NS.CollectionStore or {}
NS.CollectionStore = Store

local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local DEFAULT_COLLECTION_ICON = CONST.DEFAULT_COLLECTION_ICON or "Interface\\Icons\\INV_Misc_Note_01"

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end
Store.TrimText = TrimText

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
Store.NormalizeIconID = NormalizeIconID

function Store.ResolveCollectionIcon(value)
    local iconID = NormalizeIconID(value)
    if iconID then
        return iconID
    end

    local text = TrimText(value)
    if text ~= "" then
        if text:find("\\", 1, true) or text:find("/", 1, true) then
            if Utils.CanonicalPath then
                return Utils.CanonicalPath(text)
            end
            return text:gsub("/", "\\")
        end
    end

    return DEFAULT_COLLECTION_ICON
end

function Store.BuildEntryKey(classID, specID, index)
    return string.format("%d:%d:%d", tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0)
end

function Store.ParseEntryKey(key)
    local classID, specID, index = tostring(key or ""):match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
    return tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0
end

function Store.BuildGroupKey(classID, specID, groupID)
    return string.format("group:%d:%d:%s", tonumber(classID) or 0, tonumber(specID) or 0, tostring(groupID or ""))
end

function Store.ParseGroupKey(key)
    local classID, specID, groupID = tostring(key or ""):match("^group:(%-?%d+):(%-?%d+):(.+)$")
    return tonumber(classID) or 0, tonumber(specID) or 0, tostring(groupID or "")
end

function Store.GroupRefToKey(scopeClassID, scopeSpecID, ref)
    scopeClassID = tonumber(scopeClassID) or 0
    scopeSpecID = tonumber(scopeSpecID) or 0

    if type(ref) == "table" and tostring(ref.type or "") == "group" then
        local groupID = tostring(ref.id or ref.groupID or "")
        if groupID ~= "" then
            return Store.BuildGroupKey(scopeClassID, scopeSpecID, groupID), scopeClassID, scopeSpecID, groupID
        end
        return nil
    end

    local value = TrimText(ref)
    if value == "" then
        return nil
    end

    local classID, specID, groupID = Store.ParseGroupKey(value)
    if groupID ~= "" and classID >= 0 and specID >= 0 then
        return Store.BuildGroupKey(classID, specID, groupID), classID, specID, groupID
    end

    return nil
end

function Store.IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    local key, classID, specID, groupID = Store.GroupRefToKey(scopeClassID, scopeSpecID, ref)
    if key and classID == tonumber(scopeClassID) and specID == tonumber(scopeSpecID) and groupID ~= "" then
        return key, groupID
    end
    return nil
end

function Store.EntryRefToKey(scopeClassID, scopeSpecID, ref)
    scopeClassID = tonumber(scopeClassID) or 0
    scopeSpecID = tonumber(scopeSpecID) or 0

    if type(ref) == "number" then
        local index = tonumber(ref) or 0
        if scopeClassID >= 0 and scopeSpecID >= 0 and index > 0 then
            return Store.BuildEntryKey(scopeClassID, scopeSpecID, index), scopeClassID, scopeSpecID, index
        end
        return nil
    end

    local value = TrimText(ref)
    if value == "" then
        return nil
    end

    local classID, specID, index = Store.ParseEntryKey(value)
    if classID >= 0 and specID >= 0 and index > 0 then
        return Store.BuildEntryKey(classID, specID, index), classID, specID, index
    end

    index = tonumber(value) or 0
    if scopeClassID >= 0 and scopeSpecID >= 0 and index > 0 then
        return Store.BuildEntryKey(scopeClassID, scopeSpecID, index), scopeClassID, scopeSpecID, index
    end

    return nil
end

function Store.EnsureRootDB()
    if type(EllesmereUIVEDB) ~= "table" then
        EllesmereUIVEDB = {}
    end
    if type(EllesmereUIVEDB.collectionData) ~= "table" then
        EllesmereUIVEDB.collectionData = {}
    end
    if type(EllesmereUIVEDB.collectionSerial) ~= "number" then
        EllesmereUIVEDB.collectionSerial = 0
    end
    if type(EllesmereUIVEDB.deletedEntries) ~= "table" then
        EllesmereUIVEDB.deletedEntries = {}
    end
    return EllesmereUIVEDB
end

function Store.EnsureCollectionScope(classID, specID)
    local db = Store.EnsureRootDB()
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    if classID < 0 or specID < 0 then
        return nil
    end
    if type(db.collectionData[classID]) ~= "table" then
        db.collectionData[classID] = {}
    end
    if type(db.collectionData[classID][specID]) ~= "table" then
        db.collectionData[classID][specID] = {}
    end
    local scope = db.collectionData[classID][specID]
    if type(scope.root) ~= "table" then
        scope.root = {}
    end
    if type(scope.groups) ~= "table" then
        scope.groups = {}
    end
    return scope
end

local function MakeValidEntrySet(api, entryMap)
    local valid = {}
    if not api or type(entryMap) ~= "table" then
        return valid
    end
    local indices = type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(entryMap) or {}
    for _, index in ipairs(indices) do
        valid[tonumber(index) or 0] = true
    end
    return valid
end
Store.MakeValidEntrySet = MakeValidEntrySet

local function EntryKeyExists(api, key)
    if not api then
        return false
    end

    local classID, specID, index = Store.ParseEntryKey(key)
    if classID < 0 or specID < 0 or index <= 0 then
        return false
    end

    local map = api.GetStoredEntryMap(classID, specID)
    if type(map) ~= "table" then
        return false
    end
    return api.GetEntry(map, index) ~= nil
end
Store.EntryKeyExists = EntryKeyExists

function Store.NormalizeGroupBasics(group)
    if type(group) ~= "table" then
        return false
    end
    group.name = TrimText(group.name)
    if group.name == "" then
        group.name = L("COLLECTION_UNNAMED")
    end
    group.iconID = NormalizeIconID(group.iconID)
    if type(group.entries) ~= "table" then
        group.entries = {}
    end
    return true
end

function Store.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, api)
    if type(scope) ~= "table" then
        return nil
    end
    if type(scope.root) ~= "table" then
        scope.root = {}
    end
    if type(scope.groups) ~= "table" then
        scope.groups = {}
    end

    scopeClassID = tonumber(scopeClassID) or 0
    scopeSpecID = tonumber(scopeSpecID) or 0

    local valid = MakeValidEntrySet(api, entryMap)
    local seenEntryKeys = {}
    local nestedGroupIDs = {}
    local cleanedGroups = {}

    local function cleanGroup(groupID, stack)
        groupID = tostring(groupID or "")
        local group = scope.groups[groupID]
        if groupID == "" or type(group) ~= "table" then
            return false
        end
        if cleanedGroups[groupID] then
            return true
        end

        Store.NormalizeGroupBasics(group)
        stack = stack or {}
        if stack[groupID] then
            return false
        end
        stack[groupID] = true

        local cleaned = {}
        for _, value in ipairs(group.entries or {}) do
            local groupKey, childGroupID = Store.IsSameScopeGroupRef(scopeClassID, scopeSpecID, value)
            if groupKey and childGroupID ~= groupID and type(scope.groups[childGroupID]) == "table" and not stack[childGroupID] and not nestedGroupIDs[childGroupID] then
                if cleanGroup(childGroupID, stack) then
                    cleaned[#cleaned + 1] = groupKey
                    nestedGroupIDs[childGroupID] = true
                end
            else
                local entryKey, entryClassID, entrySpecID, entryIndex = Store.EntryRefToKey(scopeClassID, scopeSpecID, value)
                if entryKey and entryClassID >= 0 and entrySpecID >= 0 and entryIndex > 0 and EntryKeyExists(api, entryKey) and not seenEntryKeys[entryKey] then
                    cleaned[#cleaned + 1] = entryKey
                    seenEntryKeys[entryKey] = true
                end
            end
        end

        group.entries = cleaned
        stack[groupID] = nil
        cleanedGroups[groupID] = true
        return true
    end

    for groupID, group in pairs(scope.groups) do
        groupID = tostring(groupID or "")
        if groupID == "" or type(group) ~= "table" then
            scope.groups[groupID] = nil
        else
            Store.NormalizeGroupBasics(group)
        end
    end

    for _, item in ipairs(scope.root or {}) do
        if type(item) == "table" and item.type == "group" then
            local groupID = tostring(item.id or "")
            if groupID ~= "" and type(scope.groups[groupID]) == "table" then
                cleanGroup(groupID, {})
            end
        end
    end

    for groupID in pairs(scope.groups) do
        cleanGroup(groupID, {})
    end

    local seenRootGroups = {}
    local newRoot = {}

    for _, item in ipairs(scope.root or {}) do
        if type(item) == "table" then
            if item.type == "entry" then
                local index = tonumber(item.index) or 0
                local key = Store.BuildEntryKey(scopeClassID, scopeSpecID, index)
                if index > 0 and valid[index] and not seenEntryKeys[key] then
                    newRoot[#newRoot + 1] = { type = "entry", index = index }
                    seenEntryKeys[key] = true
                end
            elseif item.type == "group" then
                local groupID = tostring(item.id or "")
                if groupID ~= "" and type(scope.groups[groupID]) == "table" and not nestedGroupIDs[groupID] and not seenRootGroups[groupID] then
                    newRoot[#newRoot + 1] = { type = "group", id = groupID }
                    seenRootGroups[groupID] = true
                end
            end
        end
    end

    for groupID, group in pairs(scope.groups) do
        groupID = tostring(groupID or "")
        if groupID ~= "" and type(group) == "table" and not nestedGroupIDs[groupID] and not seenRootGroups[groupID] then
            newRoot[#newRoot + 1] = { type = "group", id = groupID }
            seenRootGroups[groupID] = true
        end
    end

    local ordered = api and type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(entryMap) or {}
    for _, index in ipairs(ordered) do
        index = tonumber(index) or 0
        local key = Store.BuildEntryKey(scopeClassID, scopeSpecID, index)
        if index > 0 and valid[index] and not seenEntryKeys[key] then
            newRoot[#newRoot + 1] = { type = "entry", index = index }
            seenEntryKeys[key] = true
        end
    end

    scope.root = newRoot
    return scope
end

function Store.RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
    local key, classID, specID, index = Store.EntryRefToKey(scopeClassID, scopeSpecID, entryKey)
    if type(scope) ~= "table" or not key or index <= 0 then
        return nil
    end

    if classID == tonumber(scopeClassID) and specID == tonumber(scopeSpecID) then
        for i = #scope.root, 1, -1 do
            local item = scope.root[i]
            if type(item) == "table" and item.type == "entry" and tonumber(item.index) == index then
                table.remove(scope.root, i)
                return { container = "root", position = i }
            end
        end
    end

    for groupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and type(group.entries) == "table" then
            for i = #group.entries, 1, -1 do
                local groupEntryKey = Store.EntryRefToKey(scopeClassID, scopeSpecID, group.entries[i])
                if groupEntryKey == key then
                    table.remove(group.entries, i)
                    return { container = "group", groupID = tostring(groupID), position = i }
                end
            end
        end
    end
    return nil
end

function Store.RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
    local key, classID, specID, groupID = Store.GroupRefToKey(scopeClassID, scopeSpecID, groupKey)
    if type(scope) ~= "table" or not key or groupID == "" or classID ~= tonumber(scopeClassID) or specID ~= tonumber(scopeSpecID) then
        return nil
    end

    for i = #scope.root, 1, -1 do
        local item = scope.root[i]
        if type(item) == "table" and item.type == "group" and tostring(item.id or "") == groupID then
            table.remove(scope.root, i)
            return { container = "root", position = i }
        end
    end

    for parentGroupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and type(group.entries) == "table" then
            for i = #group.entries, 1, -1 do
                local childGroupKey, childGroupID = Store.IsSameScopeGroupRef(scopeClassID, scopeSpecID, group.entries[i])
                if childGroupKey == key and childGroupID == groupID then
                    table.remove(group.entries, i)
                    return { container = "group", groupID = tostring(parentGroupID), position = i }
                end
            end
        end
    end
    return nil
end

function Store.FindGroupKeyLocation(scope, groupKey, scopeClassID, scopeSpecID)
    local key, classID, specID, groupID = Store.GroupRefToKey(scopeClassID, scopeSpecID, groupKey)
    if type(scope) ~= "table" or not key or groupID == "" or classID ~= tonumber(scopeClassID) or specID ~= tonumber(scopeSpecID) then
        return nil
    end

    for i, item in ipairs(scope.root or {}) do
        if type(item) == "table" and item.type == "group" and tostring(item.id or "") == groupID then
            return { container = "root", position = i }
        end
    end

    for parentGroupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and type(group.entries) == "table" then
            for i, value in ipairs(group.entries) do
                local childGroupKey, childGroupID = Store.IsSameScopeGroupRef(scopeClassID, scopeSpecID, value)
                if childGroupKey == key and childGroupID == groupID then
                    return { container = "group", groupID = tostring(parentGroupID), position = i }
                end
            end
        end
    end
    return nil
end

function Store.GroupContainsGroup(scope, parentGroupID, childGroupID, scopeClassID, scopeSpecID, seen)
    if type(scope) ~= "table" then
        return false
    end
    parentGroupID = tostring(parentGroupID or "")
    childGroupID = tostring(childGroupID or "")
    if parentGroupID == "" or childGroupID == "" then
        return false
    end
    if parentGroupID == childGroupID then
        return true
    end
    seen = seen or {}
    if seen[parentGroupID] then
        return false
    end
    seen[parentGroupID] = true

    local group = scope.groups and scope.groups[parentGroupID]
    if type(group) ~= "table" or type(group.entries) ~= "table" then
        return false
    end

    for _, value in ipairs(group.entries) do
        local _, nestedGroupID = Store.IsSameScopeGroupRef(scopeClassID, scopeSpecID, value)
        if nestedGroupID and (nestedGroupID == childGroupID or Store.GroupContainsGroup(scope, nestedGroupID, childGroupID, scopeClassID, scopeSpecID, seen)) then
            return true
        end
    end
    return false
end

function Store.InsertGroupIntoRoot(scope, groupID, position)
    if type(scope) ~= "table" or tostring(groupID or "") == "" then
        return false
    end
    if type(scope.root) ~= "table" then
        scope.root = {}
    end
    local item = { type = "group", id = tostring(groupID) }
    position = tonumber(position) or (#scope.root + 1)
    table.insert(scope.root, math.max(1, math.min(position, #scope.root + 1)), item)
    return true
end

function Store.InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
    if type(scope) ~= "table" then
        return false
    end
    local group = scope.groups and scope.groups[tostring(parentGroupID or "")]
    if type(group) ~= "table" then
        return false
    end
    if type(group.entries) ~= "table" then
        group.entries = {}
    end
    position = tonumber(position) or (#group.entries + 1)
    table.insert(group.entries, math.max(1, math.min(position, #group.entries + 1)), tostring(childGroupKey))
    return true
end

function Store.RemoveEntryKeyFromAllCollectionScopes(entryKey)
    entryKey = TrimText(entryKey)
    if entryKey == "" then
        return 0
    end
    local db = Store.EnsureRootDB()
    local removed = 0
    for classIDKey, classMap in pairs(db.collectionData or {}) do
        local scopeClassID = tonumber(classIDKey)
        if scopeClassID and scopeClassID >= 0 and type(classMap) == "table" then
            for specIDKey, scope in pairs(classMap) do
                local scopeSpecID = tonumber(specIDKey)
                if scopeSpecID and scopeSpecID >= 0 and type(scope) == "table" then
                    while Store.RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID) do
                        removed = removed + 1
                    end
                end
            end
        end
    end
    return removed
end
