local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.CollectionController = NS.CollectionController or {}

local Controller = NS.CollectionController
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local CollectionStore = NS.CollectionStore or {}

local DEFAULT_COLLECTION_ICON = CONST.DEFAULT_COLLECTION_ICON or "Interface\\Icons\\INV_Misc_Note_01"
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"

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

local function RequestNativeUIRefresh(reason)
    if NS.UI and NS.UI.MainFrame then
        if type(NS.UI.MainFrame.RequestRefresh) == "function" then
            NS.UI.MainFrame:RequestRefresh(reason or "list")
            return true
        elseif type(NS.UI.MainFrame.Refresh) == "function" then
            NS.UI.MainFrame:Refresh()
            return true
        end
    end
    return false
end

local function BuildEntryKey(classID, specID, index)
    return CollectionStore.BuildEntryKey(classID, specID, index)
end

local function BuildGroupKey(classID, specID, groupID)
    return CollectionStore.BuildGroupKey(classID, specID, groupID)
end

local function ParseGroupKey(key)
    return CollectionStore.ParseGroupKey(key)
end

local function IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    return CollectionStore.IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
end

local function EntryRefToKey(scopeClassID, scopeSpecID, ref)
    return CollectionStore.EntryRefToKey(scopeClassID, scopeSpecID, ref)
end

local function EnsureRootDB()
    return CollectionStore.EnsureRootDB()
end

local function EnsureCollectionScope(classID, specID)
    return CollectionStore.EnsureCollectionScope(classID, specID)
end

local function NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    return CollectionStore.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, GetApi())
end

local function RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
    return CollectionStore.RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
end

local function RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
    return CollectionStore.RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
end

local function InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
    return CollectionStore.InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
end

local function RemoveEntryKeyFromAllCollectionScopes(entryKey)
    return CollectionStore.RemoveEntryKeyFromAllCollectionScopes(entryKey)
end

local function NormalizeEntryTypeValue(value)
    value = tostring(value or "euiVoice")
    if value == "cast" then
        return value
    end
    return "euiVoice"
end

local function NormalizeObjectTypeValue(value)
    value = tostring(value or OBJECT_TYPE_SPELL):lower()
    if value ~= OBJECT_TYPE_ITEM then
        value = OBJECT_TYPE_SPELL
    end
    return value
end

local function SameEntryIdentity(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    local leftID = tonumber(left.spellId or left.itemID) or 0
    local rightID = tonumber(right.spellId or right.itemID) or 0
    if leftID <= 0 or rightID <= 0 or math.floor(leftID) ~= math.floor(rightID) then
        return false
    end
    if NormalizeEntryTypeValue(left.entryType) ~= NormalizeEntryTypeValue(right.entryType) then
        return false
    end
    if NormalizeObjectTypeValue(left.objectType) ~= NormalizeObjectTypeValue(right.objectType) then
        return false
    end
    if NormalizeEntryTypeValue(left.entryType) == "euiVoice"
        and tostring(left.euiTriggerType or "cdReady") ~= tostring(right.euiTriggerType or "cdReady") then
        return false
    end
    return true
end

local function RemoveEUIInjection(entry)
    if type(entry) ~= "table" or entry.entryType ~= "euiVoice" then return end
    local integration = NS.Integrations and NS.Integrations.EllesmereUI
    if not integration then return end
    local snapshot = type(NS.SnapshotEntry) == "function" and NS.SnapshotEntry(entry) or entry
    local removed, status = integration:RemoveEntry(snapshot)
    if not removed and status ~= "removed" and status ~= "waiting_combat" and type(NS.QueueEUIRemoval) == "function" then
        NS:QueueEUIRemoval(snapshot)
    end
end

local function DeleteMatchingEntriesFromMap(map, entry, classID, specID)
    if type(map) ~= "table" or type(entry) ~= "table" then
        return 0
    end
    local api = GetApi()
    local removed = 0
    for index, candidate in pairs(map) do
        local entryIndex = tonumber(index) or 0
        if entryIndex > 0 and SameEntryIdentity(candidate, entry) then
            RemoveEUIInjection(candidate)
            if api and type(api.MarkEntryDeleted) == "function" then
                api.MarkEntryDeleted(classID, specID, candidate, entryIndex)
            end
            map[index] = nil
            RemoveEntryKeyFromAllCollectionScopes(BuildEntryKey(classID, specID, entryIndex))
            removed = removed + 1
        end
    end
    return removed
end

local function DeleteMatchingLegacyCastEntries(classID, specID, entry)
    if type(entry) ~= "table" or NormalizeEntryTypeValue(entry.entryType) ~= "cast" then
        return 0
    end
    local db = EnsureRootDB()
    local classMap = db.castSuccessConfigs and db.castSuccessConfigs[classID]
    local legacyMap = type(classMap) == "table" and classMap[specID] or nil
    if type(legacyMap) ~= "table" then
        return 0
    end
    local legacyProbe = {}
    for k, v in pairs(entry) do
        legacyProbe[k] = v
    end
    legacyProbe.entryType = "cast"
    return DeleteMatchingEntriesFromMap(legacyMap, legacyProbe, classID, specID)
end

function Controller:ResolveCollectionIcon(value)
    if NS.CollectionStore and type(NS.CollectionStore.ResolveCollectionIcon) == "function" then
        return NS.CollectionStore.ResolveCollectionIcon(value)
    end

    local iconID = NormalizeIconID(value)
    if iconID then
        return iconID
    end

    local text = TrimText(value)
    if text ~= "" and (text:find("\\", 1, true) or text:find("/", 1, true)) then
        if Utils.CanonicalPath then
            return Utils.CanonicalPath(text)
        end
        return text:gsub("/", "\\")
    end

    return DEFAULT_COLLECTION_ICON
end

function Controller:CreateCollection(aceOptions, name, iconID, explicitParentGroupKey, suppressRefresh)
    local api = GetApi()
    local state = aceOptions:GetState()
    if not api then
        return false
    end

    local classID = tonumber(state.classID) or 0
    local specID = tonumber(state.specID) or 0
    local parentGroupKey = tostring(explicitParentGroupKey or state.selectedCollectionKey or "")
    if parentGroupKey == "" and tostring(state.selectedKey or ""):match("^group:") then
        parentGroupKey = tostring(state.selectedKey or "")
    end
    local parentClassID, parentSpecID, parentGroupID = ParseGroupKey(parentGroupKey)
    if parentGroupID ~= "" and parentClassID >= 0 and parentSpecID >= 0 then
        classID = parentClassID
        specID = parentSpecID
    end
    if classID < 0 or specID < 0 then
        print("[EUIVE] " .. L("MSG_INVALID_SCOPE"))
        return false
    end

    name = TrimText(name)
    if name == "" then
        print("[EUIVE] " .. L("MSG_COLLECTION_NAME_EMPTY"))
        return false
    end

    iconID = NormalizeIconID(iconID)

    local scope = EnsureCollectionScope(classID, specID)
    if not scope then
        return false
    end
    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)

    local db = EnsureRootDB()
    db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
    local groupID = "g" .. tostring(db.collectionSerial)
    scope.groups[groupID] = {
        name = name,
        iconID = iconID,
        entries = {},
    }

    if parentGroupID ~= "" and parentClassID == classID and parentSpecID == specID and type(scope.groups[parentGroupID]) == "table" then
        local childGroupKey = BuildGroupKey(classID, specID, groupID)
        scope.groups[parentGroupID].collapsed = false
        InsertGroupIntoGroup(scope, parentGroupID, childGroupKey)
        state.selectedCollectionKey = BuildGroupKey(classID, specID, parentGroupID)
        state.selectedKey = state.selectedCollectionKey
    else
        scope.root[#scope.root + 1] = {
            type = "group",
            id = groupID,
        }
        state.selectedCollectionKey = BuildGroupKey(classID, specID, groupID)
        state.selectedKey = state.selectedCollectionKey
    end

    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)

    if not suppressRefresh then
        if not RequestNativeUIRefresh("list") and type(api.RefreshPanel) == "function" then
            api.RefreshPanel()
        end
    end
    print("[EUIVE] " .. L("MSG_COLLECTION_ADDED", name))
    return true
end

function Controller:GetCollectionInfo(groupKey)
    local api = GetApi()
    if not api then
        return nil
    end

    local classID, specID, groupID = ParseGroupKey(groupKey)
    if classID < 0 or specID < 0 or groupID == "" then
        return nil
    end

    local scope = EnsureCollectionScope(classID, specID)
    if not scope then
        return nil
    end
    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)

    local group = scope.groups[groupID]
    if type(group) ~= "table" then
        return nil
    end

    return {
        key = BuildGroupKey(classID, specID, groupID),
        classID = classID,
        specID = specID,
        groupID = groupID,
        name = TrimText(group.name) ~= "" and TrimText(group.name) or L("COLLECTION_UNNAMED"),
        iconID = NormalizeIconID(group.iconID),
        icon = NormalizeIconID(group.iconID) or DEFAULT_COLLECTION_ICON,
        count = #(group.entries or {}),
    }
end

function Controller:RenameCollection(groupKey, name, iconID, suppressRefresh)
    local api = GetApi()
    if not api then
        return false
    end

    local classID, specID, groupID = ParseGroupKey(groupKey)
    if classID < 0 or specID < 0 or groupID == "" then
        return false
    end

    name = TrimText(name)
    if name == "" then
        print("[EUIVE] " .. L("MSG_COLLECTION_NAME_EMPTY"))
        return false
    end

    local scope = EnsureCollectionScope(classID, specID)
    if not scope then
        return false
    end
    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)

    local group = scope.groups[groupID]
    if type(group) ~= "table" then
        return false
    end

    group.name = name
    group.iconID = NormalizeIconID(iconID)

    if not suppressRefresh then
        if not RequestNativeUIRefresh("list") and type(api.RefreshPanel) == "function" then
            api.RefreshPanel()
        end
    end
    print("[EUIVE] " .. L("MSG_COLLECTION_RENAMED", name))
    return true
end

function Controller:DeleteCollection(aceOptions, groupKey, suppressRefresh)
    local api = GetApi()
    if not api then
        return false
    end
    local classID, specID, groupID = ParseGroupKey(groupKey)
    if classID < 0 or specID < 0 or groupID == "" then
        return false
    end
    local scope = EnsureCollectionScope(classID, specID)
    if not scope or type(scope.groups[groupID]) ~= "table" then
        return false
    end

    local map = api.EnsureEntryMap(classID, specID)
    if type(map) ~= "table" then
        return false
    end

    NormalizeCollectionScope(scope, map, classID, specID)

    local deleted = {}
    local deletedGroups = {}
    local deletedCount = 0

    local function collectGroup(gid, seen)
        gid = tostring(gid or "")
        local group = scope.groups[gid]
        if gid == "" or type(group) ~= "table" then
            return
        end
        seen = seen or {}
        if seen[gid] then
            return
        end
        seen[gid] = true
        deletedGroups[gid] = true

        local refs = {}
        for _, entryRef in ipairs(group.entries or {}) do
            refs[#refs + 1] = entryRef
        end
        for _, entryRef in ipairs(refs) do
            local childGroupKey, childGroupID = IsSameScopeGroupRef(classID, specID, entryRef)
            if childGroupKey and childGroupID then
                collectGroup(childGroupID, seen)
            else
                local entryKey, entryClassID, entrySpecID, entryIndex = EntryRefToKey(classID, specID, entryRef)
                if entryKey and entryIndex > 0 and not deleted[entryKey] then
                    local entryMap = api.EnsureEntryMap(entryClassID, entrySpecID)
                    if type(entryMap) == "table" then
                        local deletedEntry = api.GetEntry(entryMap, entryIndex)
                        if deletedEntry and type(api.MarkEntryDeleted) == "function" then
                            api.MarkEntryDeleted(entryClassID, entrySpecID, deletedEntry, entryIndex)
                        end
                        RemoveEUIInjection(deletedEntry)
                        deleted[entryKey] = true
                        deletedCount = deletedCount + 1
                        entryMap[entryIndex] = nil
                        if entryClassID == classID and entrySpecID == specID then
                            while RemoveEntryKeyFromCollectionScope(scope, entryKey, classID, specID) do end
                        else
                            RemoveEntryKeyFromAllCollectionScopes(entryKey)
                        end
                        DeleteMatchingLegacyCastEntries(entryClassID, entrySpecID, deletedEntry)
                    end
                end
            end
        end
    end

    collectGroup(groupID, {})

    for gid in pairs(deletedGroups) do
        RemoveGroupKeyFromCollectionScope(scope, BuildGroupKey(classID, specID, gid), classID, specID)
    end
    for gid in pairs(deletedGroups) do
        scope.groups[gid] = nil
    end

    NormalizeCollectionScope(scope, map, classID, specID)

    local state = aceOptions:GetState()
    local _, _, selectedGroupID = ParseGroupKey(state.selectedKey)
    if deleted[tostring(state.selectedKey or "")] or deletedGroups[tostring(selectedGroupID or "")] then
        aceOptions:ClearEditorFields()
        state.selectedCollectionKey = nil
    end

    if deletedCount > 0 then
        api.RebuildRuntimeConfig()
        if type(api.RebuildCastSuccessConfig) == "function" then
            api.RebuildCastSuccessConfig()
        end
        api.RefreshRuntimeCooldowns()
    end
    if not suppressRefresh then
        if not RequestNativeUIRefresh("list") and type(api.RefreshPanel) == "function" then
            api.RefreshPanel()
        end
    end
    print("[EUIVE] " .. L("MSG_COLLECTION_DELETED", deletedCount))
    return true
end
