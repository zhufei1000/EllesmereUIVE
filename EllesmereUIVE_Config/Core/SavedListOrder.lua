local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.SavedListOrder = NS.Core.SavedListOrder or {}
NS.SavedListOrder = NS.Core.SavedListOrder

local Order = NS.Core.SavedListOrder
local CollectionStore = NS.CollectionStore or {}

local function EnsureRootDB()
    if CollectionStore and type(CollectionStore.EnsureRootDB) == "function" then
        return CollectionStore.EnsureRootDB()
    end

    local db = EllesmereUIVEDB
    if type(db) ~= "table" then
        db = {}
        EllesmereUIVEDB = db
    end
    return db
end

function Order:EnsureSavedListOrderDB()
    local db = EnsureRootDB()
    if type(db.savedListOrder) ~= "table" then
        db.savedListOrder = {}
    end
    if type(db.savedListOrder.loaded) ~= "table" then
        db.savedListOrder.loaded = {}
    end
    if type(db.savedListOrder.unloaded) ~= "table" then
        db.savedListOrder.unloaded = {}
    end
    return db.savedListOrder
end

function Order:StripDropSuffix(key)
    key = tostring(key or "")
    key = key:gsub(":after$", "")
    key = key:gsub(":inside$", "")
    key = key:gsub(":empty$", "")
    return key
end

function Order:RemoveKeyFromSavedListOrders(key)
    key = self:StripDropSuffix(key)
    if key == "" then
        return
    end

    local orderDB = self:EnsureSavedListOrderDB()
    for _, section in ipairs({ "loaded", "unloaded" }) do
        local list = orderDB[section]
        for i = #list, 1, -1 do
            if tostring(list[i] or "") == key then
                table.remove(list, i)
            end
        end
    end
end

function Order:RecordSavedListDisplayMove(sourceKey, targetKey, targetSection, insertAfter)
    sourceKey = self:StripDropSuffix(sourceKey)
    targetKey = self:StripDropSuffix(targetKey)
    targetSection = tostring(targetSection or "")
    if sourceKey == "" or targetKey == "" or sourceKey == targetKey then
        return false
    end
    if targetSection ~= "unloaded" then
        targetSection = "loaded"
    end

    local orderDB = self:EnsureSavedListOrderDB()
    self:RemoveKeyFromSavedListOrders(sourceKey)
    local list = orderDB[targetSection]
    local targetPos = nil
    for i, key in ipairs(list) do
        if tostring(key or "") == targetKey then
            targetPos = i
            break
        end
    end
    if not targetPos then
        list[#list + 1] = sourceKey
        return true
    end

    local insertPos = targetPos + (insertAfter and 1 or 0)
    table.insert(list, math.max(1, math.min(insertPos, #list + 1)), sourceKey)
    return true
end
