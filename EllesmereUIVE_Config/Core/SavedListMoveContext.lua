local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.SavedListMoveContext = NS.SavedListMoveContext or {}

local Context = NS.SavedListMoveContext
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local CollectionStore = NS.CollectionStore or {}
local SavedListOrder = NS.SavedListOrder or (NS.Core and NS.Core.SavedListOrder) or {}
local DropKey = NS.SavedListDropKey or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

function Context:TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Context:NormalizeIconID(value)
    if Utils.NormalizeIconID then
        return Utils.NormalizeIconID(value)
    end
    local iconID = tonumber(self:TrimText(value))
    if iconID and iconID > 0 then
        return math.floor(iconID)
    end
    return nil
end

function Context:GetApi()
    return NS.API
end

function Context:RequestNativeUIRefresh(reason)
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

function Context:IsLoadedScope(api, classID, specID, currentClassID, currentSpecID)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    currentClassID = tonumber(currentClassID) or 0
    currentSpecID = tonumber(currentSpecID) or 0
    if api and type(api.IsActiveScopeLoaded) == "function" then
        return api.IsActiveScopeLoaded(classID, specID, currentClassID, currentSpecID)
    end
    if classID == ALL_CLASSES_ID then
        return true
    end
    return classID == currentClassID and (specID == currentSpecID or specID == ALL_SPECS_ID)
end

function Context:EnsureRootDB()
    return CollectionStore.EnsureRootDB()
end

function Context:BuildEntryKey(classID, specID, index)
    return CollectionStore.BuildEntryKey(classID, specID, index)
end

function Context:ParseEntryKey(key)
    return CollectionStore.ParseEntryKey(key)
end

function Context:BuildGroupKey(classID, specID, groupID)
    return CollectionStore.BuildGroupKey(classID, specID, groupID)
end

function Context:ParseGroupKey(key)
    return CollectionStore.ParseGroupKey(key)
end

function Context:ParseRootKey(key)
    if DropKey and type(DropKey.ParseRootKey) == "function" then
        return DropKey:ParseRootKey(key)
    end
    local classID, specID = tostring(key or ""):match("^root:(%-?%d+):(%-?%d+)$")
    return tonumber(classID) or -1, tonumber(specID) or -1
end

function Context:EntryRefToKey(scopeClassID, scopeSpecID, ref)
    return CollectionStore.EntryRefToKey(scopeClassID, scopeSpecID, ref)
end

function Context:IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    return CollectionStore.IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
end

function Context:EnsureCollectionScope(classID, specID)
    return CollectionStore.EnsureCollectionScope(classID, specID)
end

function Context:NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    return CollectionStore.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, self:GetApi())
end

function Context:RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
    return CollectionStore.RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
end

function Context:RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
    return CollectionStore.RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
end

function Context:FindGroupKeyLocation(scope, groupKey, scopeClassID, scopeSpecID)
    return CollectionStore.FindGroupKeyLocation(scope, groupKey, scopeClassID, scopeSpecID)
end

function Context:GroupContainsGroup(scope, parentGroupID, childGroupID, scopeClassID, scopeSpecID, seen)
    return CollectionStore.GroupContainsGroup(scope, parentGroupID, childGroupID, scopeClassID, scopeSpecID, seen)
end

function Context:InsertGroupIntoRoot(scope, groupID, position)
    return CollectionStore.InsertGroupIntoRoot(scope, groupID, position)
end

function Context:InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
    return CollectionStore.InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
end

function Context:RemoveEntryKeyFromAllCollectionScopes(entryKey)
    return CollectionStore.RemoveEntryKeyFromAllCollectionScopes(entryKey)
end

function Context:RecordSavedListDisplayMove(sourceKey, targetKey, targetSection, insertAfter)
    return SavedListOrder:RecordSavedListDisplayMove(sourceKey, targetKey, targetSection, insertAfter)
end

function Context:FindEntryKeyLocation(scope, entryKey, scopeClassID, scopeSpecID)
    local key, classID, specID, index = self:EntryRefToKey(scopeClassID, scopeSpecID, entryKey)
    if type(scope) ~= "table" or not key or index <= 0 then
        return nil
    end

    if classID == tonumber(scopeClassID) and specID == tonumber(scopeSpecID) then
        for i, item in ipairs(scope.root or {}) do
            if type(item) == "table" and item.type == "entry" and tonumber(item.index) == index then
                return { container = "root", position = i }
            end
        end
    end

    for groupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and type(group.entries) == "table" then
            for i, value in ipairs(group.entries) do
                local groupEntryKey = self:EntryRefToKey(scopeClassID, scopeSpecID, value)
                if groupEntryKey == key then
                    return { container = "group", groupID = tostring(groupID), position = i }
                end
            end
        end
    end
    return nil
end

function Context:InsertEntryKeyAtCollectionLocation(scope, sourceEntryKey, sourceIndex, loc, insertAfter, sameScope)
    if type(scope) ~= "table" or not loc then
        return false
    end
    local pos = math.max(1, (tonumber(loc.position) or 1) + (insertAfter and 1 or 0))

    if loc.container == "group" and loc.groupID and type(scope.groups) == "table" then
        local group = scope.groups[tostring(loc.groupID or "")]
        if type(group) ~= "table" then
            return false
        end
        if type(group.entries) ~= "table" then
            group.entries = {}
        end
        table.insert(group.entries, math.min(pos, #group.entries + 1), tostring(sourceEntryKey or ""))
        return true
    end

    if loc.container == "root" then
        if not sameScope then
            return false
        end
        if type(scope.root) ~= "table" then
            scope.root = {}
        end
        sourceIndex = tonumber(sourceIndex) or 0
        if sourceIndex <= 0 then
            return false
        end
        table.insert(scope.root, math.min(pos, #scope.root + 1), { type = "entry", index = sourceIndex })
        return true
    end

    return false
end
